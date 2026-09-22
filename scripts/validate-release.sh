#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Inspect a release in a temporary directory; never install it or change an app.
# Usage: validate-release.sh [vMAJOR.MINOR.PATCH]
#        validate-release.sh --local ASSET_DIRECTORY vMAJOR.MINOR.PATCH
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Validation requires macOS.' >&2; exit 2; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="dchersey/markman"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
if [[ "${1:-}" == --local ]]; then
  [[ $# == 3 ]] || { echo 'Expected --local ASSET_DIRECTORY TAG' >&2; exit 2; }
  ASSETS="$(cd "$2" && pwd)"
  TAG="$3"
else
  [[ $# -le 1 ]] || { echo 'Expected at most one tag' >&2; exit 2; }
  TAG="${1:-}"
  if [[ -z "$TAG" ]]; then
    TAG="$(gh release view --repo "$REPO" --json tagName --jq .tagName)"
  fi
  ASSETS="$TEMP_DIR/assets"
  mkdir -p "$ASSETS"
  gh release download "$TAG" --repo "$REPO" --dir "$ASSETS" \
    --pattern Markman-macos-arm64.zip --pattern "markman-${TAG#v}-source.tar.gz" --pattern SHA256SUMS
fi
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected vMAJOR.MINOR.PATCH' >&2; exit 2; }
VERSION="${TAG#v}"
(cd "$ASSETS" && shasum -a 256 -c SHA256SUMS)
ditto -x -k "$ASSETS/Markman-macos-arm64.zip" "$TEMP_DIR/unpacked"
APP="$TEMP_DIR/unpacked/Markman.app"
PLIST="$APP/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" == org.hersey.markman ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PLIST")" == Markman.icns ]]
[[ -s "$APP/Contents/Resources/Markman.icns" ]]
[[ -s "$APP/Contents/Resources/Assets.car" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$PLIST")" == Markman ]]
CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache" swift "$ROOT/scripts/check-icon.swift" "$APP"
[[ "$(lipo -archs "$APP/Contents/MacOS/markman")" == arm64 ]]
codesign --verify --deep --strict --verbose=2 "$APP"
SIGNATURE="$(codesign -dvvv "$APP" 2>&1)"
[[ "$SIGNATURE" == *'Authority=Developer ID Application:'* ]]
[[ "$SIGNATURE" == *'runtime)'* ]]
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
for notice in LICENSE THIRD_PARTY_NOTICES.md Resources/marked-LICENSE Resources/DOMPurify-LICENSE; do
  [[ -s "$APP/Contents/Resources/$notice" ]]
done
# Check the shipped launcher works outside the source checkout.
"$TEMP_DIR/unpacked/bin/markman" --help
"$APP/Contents/MacOS/markman" --validate-only "$ROOT/examples/wide-table.md"
# The explicit source asset must contain the app, build scripts, license, and
# editable upstream dependency sources, not only the generated JavaScript.
tar -tzf "$ASSETS/markman-$VERSION-source.tar.gz" > "$TEMP_DIR/source-files"
for entry in LICENSE Package.swift scripts/build.sh scripts/build-icon.sh scripts/check-icon.swift assets/Markman.png assets/icon-composer.json Sources/Markman/main.swift vendor/marked-18.0.13/src/marked.ts vendor/DOMPurify-3.2.7/src/purify.ts; do
  grep -Fx "markman-$VERSION/$entry" "$TEMP_DIR/source-files" > /dev/null
done
printf 'Validated %s: signed, notarized, stapled, Gatekeeper-accepted, with matching source and launcher.\n' "$TAG"
