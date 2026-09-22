#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/build.sh
BIN="$ROOT/.build/Markman.app/Contents/MacOS/markman"
cmp LICENSE .build/Markman.app/Contents/Resources/LICENSE
cmp THIRD_PARTY_NOTICES.md .build/Markman.app/Contents/Resources/THIRD_PARTY_NOTICES.md
cmp Sources/Markman/Resources/marked-LICENSE .build/Markman.app/Contents/Resources/Resources/marked-LICENSE
cmp Sources/Markman/Resources/DOMPurify-LICENSE .build/Markman.app/Contents/Resources/Resources/DOMPurify-LICENSE
"$BIN" --help
if "$BIN" --validate-only --theme invalid 2>/dev/null; then exit 1; fi
if "$BIN" --validate-only /nonexistent/markman-test.md 2>/dev/null; then exit 1; fi
if "$BIN" --validate-only --css 2>/dev/null; then exit 1; fi
"$BIN" --validate-only --theme light examples/wide-table.md
"$BIN" --smoke-test --theme light tests/fixtures/rendering.md
"$BIN" --smoke-test --theme dark tests/fixtures/rendering.md
printf 'All checks passed. Screenshot: /tmp/markman-smoke.png\n'
