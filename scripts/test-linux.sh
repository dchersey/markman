#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n bin/markman scripts/install-linux.sh scripts/test-linux.sh packaging/arch/PKGBUILD
./bin/markman --help >/dev/null
./bin/markman --validate-only tests/fixtures/rendering.md
if ./bin/markman --theme invalid >/dev/null 2>&1; then exit 1; fi
if ./bin/markman --validate-only /nonexistent/markman.md >/dev/null 2>&1; then exit 1; fi
# Require a normal error exit (1), not a signal or a successful launch.
status=0
env GDK_BACKEND=x11 DISPLAY= WAYLAND_DISPLAY= ./bin/markman tests/fixtures/rendering.md >/dev/null 2>&1 || status=$?
[[ "$status" == 1 ]]
desktop-file-validate linux/io.github.dchersey.Markman.desktop
export GDK_BACKEND=x11
export GDK_SCALE=1
export GDK_DPI_SCALE=1
export GSK_RENDERER=cairo
exec xvfb-run -a -s '-screen 0 1600x1200x24' /usr/bin/python3 tests/linux_smoke.py
