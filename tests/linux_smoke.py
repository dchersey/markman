#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Exercise the real GTK/WebKit frontend, including saves and navigation."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import traceback

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("markman", os.environ.get("MARKMAN_TEST_MODULE", ROOT / "linux/markman.py"))
markman = importlib.util.module_from_spec(spec)
spec.loader.exec_module(markman)
markman.load_gtk()
from gi.repository import Gio, GLib


with tempfile.TemporaryDirectory(prefix="markman test # ") as directory:
    directory = Path(directory)
    document = directory / "document # ü.md"
    fixture = (ROOT / "tests/fixtures/rendering.md").read_text()
    fixture += '\n[Other](other%20file.md)\n\n' + '\n\n'.join('Paragraph ' + str(i) for i in range(100))
    document.write_text(fixture)
    (directory / "other file.md").write_text("# Other document")
    shutil.copy(ROOT / "tests/fixtures/pixel.svg", directory / "pixel.svg")
    app = markman.application(markman.options([str(document)]))
    state = {"failed": False, "step": 0, "window": None}

    def fail(error):
        state["failed"] = True
        print("FAIL:", error, file=sys.stderr)
        app.quit()

    def evaluate(script, callback):
        def finished(web, result, *_):
            try:
                value = web.evaluate_javascript_finish(result)
                callback(json.loads(value.to_json(0)))
            except Exception:
                fail(traceback.format_exc())
        state["window"].web.evaluate_javascript(script, -1, None, None, None, finished, None)

    def later(callback, delay=1000):
        def invoke():
            try:
                callback()
            except Exception:
                fail(traceback.format_exc())
            return False
        GLib.timeout_add(delay, invoke)

    def inspect():
        evaluate("""(() => {
            const rows = document.querySelectorAll('tbody tr');
            return {
              width: innerWidth, page: document.documentElement.scrollWidth,
              content: document.querySelector('main').getBoundingClientRect().width,
              rows: rows.length, image: document.querySelector('img')?.naturalWidth,
              striped: rows.length > 1 && getComputedStyle(rows[0]).backgroundColor !== getComputedStyle(rows[1]).backgroundColor,
              safe: !window.markmanInjected && !document.querySelector('#content script, #content iframe, #content [onerror], #content a[href^="javascript:"]'),
              theme: document.documentElement.dataset.theme,
              dark: getComputedStyle(document.documentElement).colorScheme === 'dark'
            };
        })()""", checked)

    cases = [(width, theme) for width in (1160, 720, 420) for theme in ("light", "dark")]

    def configure():
        window = state["window"]
        width, theme = cases[state["step"]]
        window.set_default_size(width, 800)
        app.activate_action("theme", GLib.Variant("s", theme))
        later(inspect, 600)

    def checked(values):
        width, theme = cases[state["step"]]
        # GTK themes can reserve a few pixels for the window border.
        assert width - 24 <= values["width"] <= width, values
        assert values["page"] <= values["width"] + 1 and values["content"] >= values["width"] - 80, values
        assert values["rows"] >= 2 and values["image"] > 0 and values["striped"] and values["safe"], values
        assert values["theme"] == theme and values["dark"] == (theme == "dark"), values
        print(f"PASS rendering {width}px {theme}", flush=True)
        state["step"] += 1
        if state["step"] < len(cases):
            configure()
        else:
            state["window"].web.set_zoom_level(1.1)
            evaluate("window.scrollTo(0,500); window.scrollY", scrolled)

    def scrolled(value):
        state["scroll"] = value
        document.write_text(fixture + "\n\nNORMAL-SAVE")
        later(check_save)

    def check_save():
        evaluate("({text:document.body.innerText, scroll:scrollY, theme:document.documentElement.dataset.theme})", saved)

    def saved(value):
        assert "NORMAL-SAVE" in value["text"], value
        assert abs(value["scroll"] - state["scroll"]) < 2, value
        assert value["theme"] == "dark", value
        assert state["window"].web.get_zoom_level() == 1.1
        replacement = document.with_suffix(".tmp")
        replacement.write_text(fixture + "\n\nATOMIC-SAVE")
        replacement.replace(document)
        later(lambda: evaluate("document.body.innerText.includes('ATOMIC-SAVE')", atomic_saved))

    def atomic_saved(value):
        assert value
        document.unlink()
        later(lambda: evaluate("document.body.innerText.includes('ATOMIC-SAVE')", deleted))

    def deleted(value):
        assert value
        document.write_text(fixture + "\n\nRECREATED")
        later(lambda: evaluate("document.body.innerText.includes('RECREATED')", recreated))

    def recreated(value):
        assert value
        print("PASS normal save, atomic save, deletion/recreation, scroll, zoom and theme retention", flush=True)
        evaluate("document.querySelector('a[href=\"#project-inventory\"]').click(); true", lambda _: later(check_anchor, 200))

    def check_anchor():
        evaluate("Math.abs(document.getElementById('project-inventory').getBoundingClientRect().top) < 2", anchor)

    def anchor(value):
        assert value
        evaluate("document.querySelector('a[href=\"other%20file.md\"]').click(); true", lambda _: later(linked))

    def linked():
        assert len(app.get_windows()) == 2
        assert any(w.path.name == "other file.md" for w in app.get_windows())
        print("PASS anchor and relative Markdown links", flush=True)
        for window in app.get_windows():
            window.close()
        app.quit()

    def started(*_):
        state["window"] = app.get_windows()[0]
        later(configure)

    app.connect_after("activate", started)
    GLib.timeout_add_seconds(30, lambda: (fail("timed out"), False)[1])
    app.run([sys.argv[0]])
    sys.exit(1 if state["failed"] else 0)
