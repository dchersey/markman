#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${MARKMAN_VERSION:-0.1.3}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid MARKMAN_VERSION: use MAJOR.MINOR.PATCH\n' >&2
  exit 1
fi
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/module-cache"
swift build -c release --disable-sandbox -debug-info-format none
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$ROOT/.build/Markman.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/markman" "$APP/Contents/MacOS/markman"
cp -R Sources/Markman/Resources "$APP/Contents/Resources/"
./scripts/build-icon.sh
cp .build/IconResources/Markman.icns .build/IconResources/Assets.car "$APP/Contents/Resources/"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>markman</string>
<key>CFBundleIdentifier</key><string>org.hersey.markman</string>
<key>CFBundleName</key><string>Markman</string>
<key>CFBundleIconFile</key><string>Markman.icns</string>
<key>CFBundleIconName</key><string>Markman</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>__VERSION__</string>
<key>CFBundleVersion</key><string>__VERSION__</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>Markdown document</string>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSHandlerRank</key><string>Alternate</string>
<key>CFBundleTypeExtensions</key><array><string>md</string><string>markdown</string><string>mdown</string></array>
</dict></array>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
# Local builds use an ad-hoc signature. CI replaces it with the imported
# Developer ID and hardened runtime. An empty identity skips this signing step.
SIGN_IDENTITY="${SIGN_IDENTITY--}"
if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" "$APP"
fi
printf 'Built %s\n' "$APP"
