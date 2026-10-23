#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) ADBroom.app into ./build
# Usage: ./build.sh            → build/macos/ADBroom.app
#        ./build.sh --dmg      → also dist/macos/ADBroom-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
COMPONENT="$ROOT/apps/macos"

VERSION="$(cat "$COMPONENT/VERSION")"
BUILD_NUMBER="$(cat "$COMPONENT/BUILD_NUMBER")"
BUNDLE_ID="io.github.adbroom.ADBroom"
MIN_MACOS="14.0"

# Build privately and publish only a complete, verified bundle. A failed Android or
# Swift build must not delete the previous app or leave an empty .app in Finder.
mkdir -p build/macos dist/macos
mkdir -p build/macos/.module-cache
WORK="$(mktemp -d build/macos/.adbroom-build.XXXXXX)"
FINAL_APP="build/macos/ADBroom.app"
APP="$WORK/ADBroom.app"
OBJ="$WORK/obj"
cleanup() {
  if [[ -d "$WORK/previous.app" && ! -e "$FINAL_APP" ]]; then
    mv "$WORK/previous.app" "$FINAL_APP"
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT
mkdir -p "$OBJ" "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"

echo "→ Compiling (arm64 + x86_64)…"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library \
    -module-cache-path "$ROOT/build/macos/.module-cache" \
    -target "$arch-apple-macos$MIN_MACOS" \
    "$COMPONENT"/Sources/*.swift -o "$OBJ/ADBroom-$arch"
done
lipo -create "$OBJ/ADBroom-arm64" "$OBJ/ADBroom-x86_64" -output "$APP/Contents/MacOS/ADBroom"

echo "→ Icon…"
ICONSET="$OBJ/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$COMPONENT/Resources/icon-1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$COMPONENT/Resources/icon-1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/ADBroomIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ADBroom</string>
  <key>CFBundleDisplayName</key><string>ADBroom</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>ADBroom</string>
  <key>CFBundleIconFile</key><string>ADBroomIcon.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>tr</string></array>
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSLocalNetworkUsageDescription</key><string>ADBroom connects to your Android TV on the local network.</string>
</dict></plist>
PLIST

codesign --force --sign - "$APP"   # ad-hoc signature (see README → Gatekeeper)
plutil -lint "$APP/Contents/Info.plist"
[[ -x "$APP/Contents/MacOS/ADBroom" ]]
codesign --verify --deep --strict "$APP"
if [[ -e "$FINAL_APP" ]]; then mv "$FINAL_APP" "$WORK/previous.app"; fi
mv "$APP" "$FINAL_APP"
APP="$FINAL_APP"
# Keep the old development path pointing at the current product rather than
# leaving an older, independently launchable app behind after the folder move.
if [[ ! -L build/ADBroom.app ]]; then
  if [[ -e build/ADBroom.app ]]; then mv build/ADBroom.app "$WORK/legacy.app"; fi
  ln -s macos/ADBroom.app build/ADBroom.app
fi
echo "✓ $APP"

if [[ "${1:-}" == "--dmg" ]]; then
  DMG="$ROOT/dist/macos/ADBroom-$VERSION.dmg"
  STAGE="$WORK/dmg"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "ADBroom $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$WORK/release.dmg" >/dev/null
  mv "$WORK/release.dmg" "$DMG"
  (cd "$ROOT/dist/macos" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
  echo "✓ $DMG"
fi
