#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
[[ $# == 1 ]] || { echo 'Usage: validate-linux-release.sh ARCHIVE' >&2; exit 2; }
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
tar -xzf "$1" -C "$TEMP_DIR"
SOURCE="$TEMP_DIR/Markman-linux"
for entry in LICENSE THIRD_PARTY_NOTICES.md linux/markman.py vendor/marked-18.0.13/src/marked.ts vendor/DOMPurify-3.2.7/src/purify.ts; do
  [[ -s "$SOURCE/$entry" ]]
done
# Exercise the installer and launcher outside a source checkout, with spaces.
PREFIX="$TEMP_DIR/user installation" bash "$SOURCE/scripts/install-linux.sh"
"$TEMP_DIR/user installation/bin/markman" --help
"$TEMP_DIR/user installation/bin/markman" --validate-only "$SOURCE/tests/fixtures/rendering.md"
desktop-file-validate "$TEMP_DIR/user installation/share/applications/io.github.dchersey.Markman.desktop"
# Exercise rendering from installed assets, as well as the archived frontend.
MARKMAN_TEST_MODULE="$TEMP_DIR/user installation/share/markman/linux/markman.py" \
  bash "$SOURCE/scripts/test-linux.sh"
printf 'Validated Linux archive, installation, corresponding source and rendering.\n'
