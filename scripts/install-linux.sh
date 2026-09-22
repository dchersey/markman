#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
DESTDIR="${DESTDIR:-}"
TARGET="$DESTDIR$PREFIX"
install -Dm755 "$ROOT/bin/markman" "$TARGET/bin/markman"
install -Dm644 "$ROOT/linux/markman.py" "$TARGET/share/markman/linux/markman.py"
for asset in viewer.js viewer.css marked.js purify.js marked-LICENSE DOMPurify-LICENSE; do
  install -Dm644 "$ROOT/Sources/Markman/Resources/$asset" "$TARGET/share/markman/Sources/Markman/Resources/$asset"
done
install -Dm644 "$ROOT/assets/Markman.png" "$TARGET/share/pixmaps/io.github.dchersey.Markman.png"
install -Dm644 "$ROOT/linux/io.github.dchersey.Markman.desktop" "$TARGET/share/applications/io.github.dchersey.Markman.desktop"
install -Dm644 "$ROOT/LICENSE" "$TARGET/share/licenses/markman/LICENSE"
install -Dm644 "$ROOT/THIRD_PARTY_NOTICES.md" "$TARGET/share/licenses/markman/THIRD_PARTY_NOTICES.md"
if [[ -z "$DESTDIR" ]]; then
  # Use an absolute executable path so launchers need no shell PATH setup.
  /usr/bin/python3 - "$TARGET/share/applications/io.github.dchersey.Markman.desktop" "$PREFIX/bin/markman" <<'PY'
from pathlib import Path
import sys
desktop, executable = sys.argv[1:]
escaped = executable.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
path = Path(desktop)
path.write_text(path.read_text().replace('Exec=markman %F', 'Exec="' + escaped + '" %F'))
PY
  if command -v update-desktop-database >/dev/null; then update-desktop-database "$TARGET/share/applications"; fi
fi
printf 'Installed Markman to %s\n' "$TARGET"
