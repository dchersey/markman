#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Compile the native icon and its legacy fallback using Xcode 26 or newer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCUMENT="$ROOT/.build/Markman.icon"
OUTPUT="$ROOT/.build/IconResources"
mkdir -p "$DOCUMENT/Assets" "$OUTPUT"
cp "$ROOT/assets/icon-composer.json" "$DOCUMENT/icon.json"
sips -z 1024 1024 "$ROOT/assets/Markman.png" --out "$DOCUMENT/Assets/Artwork.png" > /dev/null
xcrun actool "$DOCUMENT" --compile "$OUTPUT" --platform macosx \
  --minimum-deployment-target 13.0 --app-icon Markman \
  --output-partial-info-plist "$ROOT/.build/icon-info.plist" > /dev/null
