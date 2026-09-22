#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/build.sh
BIN="$ROOT/.build/Markman.app/Contents/MacOS/markman"
PLIST="$ROOT/.build/Markman.app/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" == "${MARKMAN_VERSION:-0.1.3}" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")" == "${MARKMAN_VERSION:-0.1.3}" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" == org.hersey.markman ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PLIST")" == Markman.icns ]]
[[ -s "$ROOT/.build/Markman.app/Contents/Resources/Markman.icns" ]]
if MARKMAN_VERSION=invalid ./scripts/build.sh 2>/dev/null; then exit 1; fi
cmp LICENSE .build/Markman.app/Contents/Resources/LICENSE
cmp THIRD_PARTY_NOTICES.md .build/Markman.app/Contents/Resources/THIRD_PARTY_NOTICES.md
cmp Sources/Markman/Resources/marked-LICENSE .build/Markman.app/Contents/Resources/Resources/marked-LICENSE
cmp Sources/Markman/Resources/DOMPurify-LICENSE .build/Markman.app/Contents/Resources/Resources/DOMPurify-LICENSE
"$BIN" --help
if "$BIN" --validate-only --theme invalid 2>/dev/null; then exit 1; fi
if "$BIN" --validate-only /nonexistent/markman-test.md 2>/dev/null; then exit 1; fi
if "$BIN" --validate-only --css 2>/dev/null; then exit 1; fi
"$BIN" --validate-only --theme light examples/wide-table.md
# Test the launcher as shipped, outside a checkout and with a path containing spaces.
LAUNCHER_TEST="$(mktemp -d)"
trap 'rm -rf "$LAUNCHER_TEST"' EXIT
mkdir -p "$LAUNCHER_TEST/Release Test/bin"
cp bin/markman "$LAUNCHER_TEST/Release Test/bin/markman"
ditto "$ROOT/.build/Markman.app" "$LAUNCHER_TEST/Release Test/Markman.app"
CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache" swift scripts/check-icon.swift   "$LAUNCHER_TEST/Release Test/Markman.app" /tmp/markman-icon-check.png
"$LAUNCHER_TEST/Release Test/bin/markman" --help
MARKMAN_APP="$ROOT/.build/Markman.app" "$LAUNCHER_TEST/Release Test/bin/markman" --help
if MARKMAN_APP="$LAUNCHER_TEST/missing.app" "$LAUNCHER_TEST/Release Test/bin/markman" --help 2>/dev/null; then exit 1; fi
CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache" swiftc -parse-as-library   Sources/Markman/DocumentWatcher.swift tests/watcher/main.swift -o .build/test-watcher
.build/test-watcher
"$BIN" --reload-test
"$BIN" --smoke-test --theme light tests/fixtures/rendering.md
"$BIN" --smoke-test --theme dark tests/fixtures/rendering.md
printf 'All checks passed. Screenshot: /tmp/markman-smoke.png\n'
