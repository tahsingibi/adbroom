#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) ADBroom.app into ./build
# Usage: ./build.sh            → build/ADBroom.app
#        ./build.sh --dmg      → also build/ADBroom-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.0.0"
BUILD_NUMBER="1"
BUNDLE_ID="io.github.adbroom.ADBroom"
MIN_MACOS="14.0"

APP="build/ADBroom.app"
rm -rf build && mkdir -p build/obj "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ Compiling (arm64 + x86_64)…"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library \
    -target "$arch-apple-macos$MIN_MACOS" \
    Sources/*.swift -o "build/obj/ADBroom-$arch"
done
lipo -create build/obj/ADBroom-arm64 build/obj/ADBroom-x86_64 -output "$APP/Contents/MacOS/ADBroom"

echo "→ Icon…"
ICONSET=build/obj/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ADBroom</string>
  <key>CFBundleDisplayName</key><string>ADBroom</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>ADBroom</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
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
rm -rf build/obj
echo "✓ $APP"

if [[ "${1:-}" == "--dmg" ]]; then
  DMG="build/ADBroom-$VERSION.dmg"
  STAGE=build/dmg
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "ADBroom $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  (cd build && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG").sha256")
  echo "✓ $DMG"
fi
