#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Build all standard and Retina macOS icon sizes from the approved artwork.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/.build/Markman.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ROOT/assets/Markman.png" \
    --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$ROOT/assets/Markman.png" \
    --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/.build/Markman.icns"
