#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) ADBroom.app into ./build
# Usage: ./build.sh            → build/ADBroom.app
#        ./build.sh --dmg      → also dist/ADBroom-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
for option in "$@"; do
  case "$option" in
    --macos|--dmg) ;;
    *) echo "Usage: ./build.sh [--dmg]. Launcher: https://github.com/tahsingibi/adbroom-launcher" >&2; exit 2 ;;
  esac
done
PACKAGE=false
for option in "$@"; do [[ "$option" != --dmg ]] || PACKAGE=true; done
COMPONENT="$ROOT"

VERSION="$(cat "$COMPONENT/VERSION")"
BUILD_NUMBER="$(cat "$COMPONENT/BUILD_NUMBER")"
BUNDLE_ID="io.github.adbroom.ADBroom"
MIN_MACOS="14.0"

# Publish only a complete, verified Mac bundle. Failed builds preserve the previous app.
mkdir -p build dist
mkdir -p build/.module-cache
WORK="$(mktemp -d build/.adbroom-build.XXXXXX)"
FINAL_APP="build/ADBroom.app"
APP="$WORK/ADBroom.app"
OBJ="$WORK/obj"
cleanup() {
  if [[ ( -e "$WORK/previous.app" || -L "$WORK/previous.app" ) && ! -e "$FINAL_APP" && ! -L "$FINAL_APP" ]]; then
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
    -module-cache-path "$ROOT/build/.module-cache" \
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
if [[ -e "$FINAL_APP" || -L "$FINAL_APP" ]]; then mv "$FINAL_APP" "$WORK/previous.app"; fi
mv "$APP" "$FINAL_APP"
APP="$FINAL_APP"
echo "✓ $APP"

if $PACKAGE; then
  DMG="$ROOT/dist/ADBroom-$VERSION.dmg"
  STAGE="$WORK/dmg"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "ADBroom $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$WORK/release.dmg" >/dev/null
  mv "$WORK/release.dmg" "$DMG"
  (cd "$ROOT/dist" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
  echo "✓ $DMG"
fi
