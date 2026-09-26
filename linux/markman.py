#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""GTK4 shell for Markman's shared Markdown renderer."""
import argparse
import json
import mimetypes
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Sources/Markman/Resources"
MARKDOWN_SUFFIXES = {".md", ".markdown", ".mdown", ".mkd"}


def options(argv=None):
    parser = argparse.ArgumentParser(prog="markman", description="Markman: a full-width Markdown viewer")
    parser.add_argument("--theme", choices=("system", "light", "dark"), default="system")
    parser.add_argument("--css", type=Path, help="additional stylesheet")
    parser.add_argument("--validate-only", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("files", nargs="*", type=Path)
    args = parser.parse_args(argv)
    try:
        args.css = args.css.expanduser().read_text(encoding="utf-8") if args.css else ""
        args.files = [path.expanduser().absolute() for path in args.files]
        for path in args.files:
            path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        parser.error(str(error))
    return args


def load_gtk():
    global Gdk, Gio, GLib, Gtk, WebKit
    try:
        import gi
        gi.require_version("Gtk", "4.0")
        gi.require_version("Gdk", "4.0")
        gi.require_version("WebKit", "6.0")
        from gi.repository import Gdk, Gio, GLib, Gtk, WebKit
    except (ImportError, ValueError) as error:
        raise SystemExit("markman: install gtk4, python-gobject and webkitgtk-6.0\n" + str(error))


def application(args):
    """Create types after dependency checks, allowing --help without GTK."""
    class Document(Gtk.ApplicationWindow):
        def __init__(self, app, path):
            self.path = path
            self.markdown = path.read_text(encoding="utf-8")
            self.signature = self.file_signature()
            self.ready = False
            self.closed = False
            super().__init__(application=app, title=path.name, default_width=1160, default_height=800)
            self.set_size_request(360, 280)
            self.set_icon_name("io.github.dchersey.Markman")
            header = Gtk.HeaderBar()
            open_button = Gtk.Button(icon_name="document-open-symbolic", tooltip_text="Open (Ctrl+O)")
            open_button.connect("clicked", lambda *_: app.pick_files(self))
            header.pack_start(open_button)
            menu = Gio.Menu()
            for title, action in (("Copy path", "win.copy-path"), ("Reload", "win.reload"), ("Zoom in", "win.zoom-in"),
                                  ("Zoom out", "win.zoom-out"), ("Reset zoom", "win.zoom-reset")):
                menu.append(title, action)
            themes = Gio.Menu()
            for theme in ("system", "light", "dark"):
                themes.append(theme.title(), f"app.theme::{theme}")
            menu.append_section("Appearance", themes)
            header.pack_end(Gtk.MenuButton(icon_name="open-menu-symbolic", menu_model=menu))
            self.set_titlebar(header)
            manager = WebKit.UserContentManager()
            for name in ("marked.js", "purify.js", "viewer.js"):
                manager.add_script(WebKit.UserScript.new(
                    (RESOURCES / name).read_text(encoding="utf-8"),
                    WebKit.UserContentInjectedFrames.TOP_FRAME,
                    WebKit.UserScriptInjectionTime.END, None, None))
            self.web = WebKit.WebView(web_context=app.context, user_content_manager=manager)
            self.web.get_settings().set_enable_html5_database(False)
            self.web.get_settings().set_enable_html5_local_storage(False)
            self.web.connect("load-changed", self.loaded)
            self.web.connect("decide-policy", self.navigate)
            self.web.connect("permission-request", lambda _, request: (request.deny(), True)[1])
            self.web.connect("web-process-terminated", lambda *_: self.error("The web process stopped. Reopen this document."))
            self.set_child(self.web)
            # Mac keyboards have no Page keys; Option+arrow pages there, so
            # Alt+Up/Down page here. Plain arrows and Page keys are WebKit's own.
            keys = Gtk.EventControllerKey(propagation_phase=Gtk.PropagationPhase.CAPTURE)
            keys.connect("key-pressed", self.page_key)
            self.add_controller(keys)
            self.web.grab_focus()
            for name, callback in {
                "copy-path": lambda *_: self.copy_path(),
                "reload": lambda *_: self.reload(force=True),
                "close": lambda *_: self.close(),
                "zoom-in": lambda *_: self.zoom(1.1),
                "zoom-out": lambda *_: self.zoom(1 / 1.1),
                "zoom-reset": lambda *_: self.web.set_zoom_level(1),
            }.items():
                action = Gio.SimpleAction.new(name, None)
                action.connect("activate", callback)
                self.add_action(action)
            css = (RESOURCES / "viewer.css").read_text(encoding="utf-8") + "\n" + args.css
            # A user stylesheet avoids parsing custom CSS as HTML.
            manager.add_style_sheet(WebKit.UserStyleSheet.new(css,
                WebKit.UserContentInjectedFrames.TOP_FRAME, WebKit.UserStyleLevel.USER, None, None))
            self.base_uri = "markman-local://document" + path.parent.as_uri()[7:] + "/"
            self.web.load_html(
                '<!doctype html><html data-theme="' + app.theme + '"><head><meta charset="utf-8">'
                '<meta name="viewport" content="width=device-width,initial-scale=1">'
                '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; '
                'img-src markman-local: data: https: http:; style-src \'unsafe-inline\'; '
                'script-src \'none\'; base-uri \'none\'; form-action \'none\'">'
                '</head><body><main id="content"></main></body></html>', self.base_uri)
            self.timer = GLib.timeout_add(750, self.reload)
            self.connect("close-request", self.cleanup)

        def file_signature(self):
            stat = self.path.stat()
            return (stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns)

        def error(self, message):
            if self.closed:
                return
            dialog = Gtk.MessageDialog(transient_for=self, modal=True,
                message_type=Gtk.MessageType.ERROR, buttons=Gtk.ButtonsType.CLOSE,
                text="Markman", secondary_text=str(message))
            dialog.connect("response", lambda widget, *_: widget.destroy())
            dialog.present()

        def evaluate(self, script, callback=None):
            def finished(web, result, *_):
                try:
                    value = web.evaluate_javascript_finish(result)
                    if callback:
                        callback(value)
                except GLib.Error as error:
                    self.error(error.message)
            self.web.evaluate_javascript(script, -1, None, None, None, finished, None)

        def loaded(self, _, event):
            if event == WebKit.LoadEvent.FINISHED and not self.ready:
                self.ready = True
                self.render()

        def render(self):
            self.evaluate("window.renderMarkdown(" + json.dumps(self.markdown) + ")")

        def reload(self, force=False):
            try:
                signature = self.file_signature()
                if force or signature != self.signature:
                    text = self.path.read_text(encoding="utf-8")
                    self.signature = signature
                    if text != self.markdown or force:
                        self.markdown = text
                        if self.ready:
                            self.render()
            except (OSError, UnicodeError) as error:
                # Keep the last readable preview during atomic saves/deletion.
                if force:
                    self.error(error)
            return GLib.SOURCE_CONTINUE

        def copy_path(self):
            # An executable named markman-copy-path on PATH may rewrite the
            # path first (e.g. relative to a project); otherwise copy it as is.
            text = str(self.path)
            helper = shutil.which("markman-copy-path")
            if helper:
                try:
                    result = subprocess.run([helper, text], capture_output=True, text=True, timeout=2)
                    if result.returncode == 0 and result.stdout.strip():
                        text = result.stdout.strip()
                except (OSError, subprocess.SubprocessError):
                    pass
            self.get_clipboard().set(text)

        def page_key(self, _, keyval, _keycode, state):
            mods = state & Gtk.accelerator_get_default_mod_mask()
            if mods != Gdk.ModifierType.ALT_MASK or keyval not in (Gdk.KEY_Up, Gdk.KEY_Down):
                return False
            sign = "-" if keyval == Gdk.KEY_Up else ""
            self.evaluate(f"window.scrollBy(0, {sign}window.innerHeight * 0.9)")
            return True

        def zoom(self, factor):
            self.web.set_zoom_level(max(0.5, min(3, self.web.get_zoom_level() * factor)))

        def navigate(self, _, decision, kind):
            if kind not in (WebKit.PolicyDecisionType.NAVIGATION_ACTION, WebKit.PolicyDecisionType.NEW_WINDOW_ACTION):
                return False
            action = decision.get_navigation_action()
            uri = action.get_request().get_uri()
            if action.get_navigation_type() != WebKit.NavigationType.LINK_CLICKED:
                if not self.ready and uri == self.base_uri:
                    decision.use()
                else:
                    decision.ignore()
                return True
            decision.ignore()
            target = urlsplit(uri)
            base = urlsplit(self.base_uri)
            if target.fragment and (target.scheme, target.netloc, target.path) == (base.scheme, base.netloc, base.path):
                self.evaluate("document.getElementById(" + json.dumps(unquote(target.fragment)) + ")?.scrollIntoView()")
            elif target.scheme == "markman-local" and target.netloc == "document":
                path = Path(unquote(target.path))
                if path.suffix.lower() in MARKDOWN_SUFFIXES:
                    self.get_application().open_path(path, self)
            elif target.scheme in ("http", "https", "mailto"):
                Gio.AppInfo.launch_default_for_uri_async(uri, None, None, self.launched)
            return True

        def launched(self, _, result):
            try:
                Gio.AppInfo.launch_default_for_uri_finish(result)
            except GLib.Error as error:
                self.error(error.message)

        def cleanup(self, *_):
            self.closed = True
            GLib.source_remove(self.timer)
            return False

    class Markman(Gtk.Application):
        def __init__(self):
            super().__init__(application_id="io.github.dchersey.Markman", flags=Gio.ApplicationFlags.NON_UNIQUE)
            self.theme = args.theme

        def do_startup(self):
            Gtk.Application.do_startup(self)
            self.context = WebKit.WebContext.new()
            self.context.register_uri_scheme("markman-local", self.local_image)
            action = Gio.SimpleAction.new("open", None)
            action.connect("activate", lambda *_: self.pick_files(self.get_active_window()))
            self.add_action(action)
            action = Gio.SimpleAction.new_stateful("theme", GLib.VariantType.new("s"), GLib.Variant("s", self.theme))
            action.connect("activate", self.change_theme)
            self.add_action(action)
            # Alt+Shift+L matches Omarchy's Copy URL shortcut in Chromium.
            for name, keys in {"app.open": ["<Control>o"], "win.reload": ["<Control>r"],
                "win.copy-path": ["<Alt><Shift>l", "<Control><Shift>c"],
                "win.close": ["<Control>w"], "win.zoom-in": ["<Control>equal", "<Control>plus"],
                "win.zoom-out": ["<Control>minus"], "win.zoom-reset": ["<Control>0"]}.items():
                self.set_accels_for_action(name, keys)

        def local_image(self, request):
            try:
                uri = urlsplit(request.get_uri())
                path = Path(unquote(uri.path))
                mime = mimetypes.guess_type(path)[0]
                if uri.netloc != "document" or not mime or not mime.startswith("image/"):
                    raise ValueError("Only images may be embedded from local files")
                data = path.read_bytes()
                stream = Gio.MemoryInputStream.new_from_bytes(GLib.Bytes.new(data))
                request.finish(stream, len(data), mime)
            except (OSError, ValueError) as error:
                request.finish_error(GLib.Error.new_literal(Gio.io_error_quark(), str(error), Gio.IOErrorEnum.FAILED))

        def do_activate(self):
            if args.files:
                for path in args.files:
                    self.open_path(path)
            else:
                self.pick_files(None)

        def open_path(self, path, parent=None):
            try:
                window = Document(self, path)
                window.present()
                return window
            except (OSError, UnicodeError) as error:
                dialog = Gtk.MessageDialog(transient_for=parent, modal=True,
                    message_type=Gtk.MessageType.ERROR, buttons=Gtk.ButtonsType.CLOSE,
                    text="Unable to open document", secondary_text=str(error))
                self.hold()
                def dismiss(widget, *_):
                    widget.destroy()
                    self.release()
                dialog.connect("response", dismiss)
                dialog.present()

        def pick_files(self, parent):
            picker = Gtk.FileChooserNative.new("Open Markdown", parent, Gtk.FileChooserAction.OPEN, "Open", "Cancel")
            picker.set_select_multiple(True)
            markdown = Gtk.FileFilter(name="Markdown documents")
            for suffix in MARKDOWN_SUFFIXES:
                markdown.add_pattern("*" + suffix)
            picker.add_filter(markdown)
            all_files = Gtk.FileFilter(name="All files")
            all_files.add_pattern("*")
            picker.add_filter(all_files)
            self.hold()
            def response(widget, result):
                if result == Gtk.ResponseType.ACCEPT:
                    files = widget.get_files()
                    for index in range(files.get_n_items()):
                        path = files.get_item(index).get_path()
                        if path:
                            self.open_path(Path(path), parent)
                widget.destroy()
                self.release()
            picker.connect("response", response)
            picker.show()

        def change_theme(self, action, value):
            self.theme = value.get_string()
            action.set_state(value)
            for window in self.get_windows():
                if isinstance(window, Document):
                    window.evaluate("document.documentElement.dataset.theme = " + json.dumps(self.theme))

    return Markman()


def main():
    args = options()
    if args.validate_only:
        return 0
    load_gtk()
    if not Gtk.init_check() or Gdk.Display.get_default() is None:
        raise SystemExit("markman: no graphical display is available")
    return application(args).run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
