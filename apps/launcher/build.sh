#!/bin/bash
# Small, dependency-free Android build. Requires JDK 17+ and Android SDK build tools.
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
COMPONENT="$ROOT/apps/launcher"
VERSION="$(python3 -c 'import xml.etree.ElementTree as E; print(E.parse("apps/launcher/AndroidManifest.xml").getroot().get("{http://schemas.android.com/apk/res/android}versionName"))')"
FINAL="$ROOT/dist/launcher/ADBroomLauncher-$VERSION.apk"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
JAVA_BIN="${JAVA_HOME:+$JAVA_HOME/bin/}"
TOOLS="${ANDROID_BUILD_TOOLS:-}"
PLATFORM="${ANDROID_PLATFORM:-}"
if [[ -z "$TOOLS" ]]; then TOOLS="$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)"; fi
if [[ -z "$PLATFORM" ]]; then PLATFORM="$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)"; fi
[[ -x "$TOOLS/aapt2" && -f "$PLATFORM/android.jar" ]] || { echo 'Android SDK build-tools/platform missing.' >&2; exit 1; }
"${JAVA_BIN}java" -version
WORK="$(mktemp -d "${TMPDIR:-/tmp}/adbroom-launcher.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/classes" "$WORK/generated" "$WORK/dex" "$ROOT/build/launcher" "$ROOT/dist/launcher"
"$TOOLS/aapt2" compile --dir apps/launcher/res -o "$WORK/resources.zip"
"$TOOLS/aapt2" link -o "$WORK/unsigned.apk" -I "$PLATFORM/android.jar" \
  --manifest apps/launcher/AndroidManifest.xml --java "$WORK/generated" "$WORK/resources.zip"
"${JAVA_BIN}javac" -encoding UTF-8 --release 8 -classpath "$PLATFORM/android.jar" \
  -d "$WORK/classes" apps/launcher/src/io/github/adbroom/launcher/*.java "$WORK/generated/io/github/adbroom/launcher/R.java"
"${JAVA_BIN}javac" --release 8 -classpath "$WORK/classes" -d "$WORK/classes" apps/launcher/tests/OrderLogicTest.java
"${JAVA_BIN}java" -cp "$WORK/classes" OrderLogicTest
# Exclude desktop test classes from the APK.
"${JAVA_BIN}jar" cf "$WORK/classes.jar" -C "$WORK/classes" io
"$TOOLS/d8" --release --min-api 23 --lib "$PLATFORM/android.jar" --output "$WORK/dex" "$WORK/classes.jar"
(cd "$WORK/dex" && zip -q -u "$WORK/unsigned.apk" classes*.dex)
"$TOOLS/zipalign" -f -p 4 "$WORK/unsigned.apk" "$WORK/aligned.apk"
# Keep the signing identity across builds, including builds that clean ./build.
KEYSTORE="${LAUNCHER_KEYSTORE:-$ROOT/apps/launcher/.signing/development.jks}"
export LAUNCHER_STORE_PASSWORD="${LAUNCHER_STORE_PASSWORD:-android}"
ALIAS="${LAUNCHER_KEY_ALIAS:-adbroom}"
if [[ ! -f "$KEYSTORE" ]]; then
  [[ -z "${LAUNCHER_KEYSTORE:-}" ]] || { echo 'Configured release keystore missing.' >&2; exit 1; }
  mkdir -p "$(dirname "$KEYSTORE")"
  "${JAVA_BIN}keytool" -genkeypair -noprompt -keystore "$KEYSTORE" -storepass:env LAUNCHER_STORE_PASSWORD \
    -keypass:env LAUNCHER_STORE_PASSWORD -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -dname 'CN=ADBroom Development'
  chmod 600 "$KEYSTORE"
fi
"$TOOLS/apksigner" sign --ks "$KEYSTORE" --ks-key-alias "$ALIAS" --ks-pass env:LAUNCHER_STORE_PASSWORD \
  --key-pass env:LAUNCHER_STORE_PASSWORD --out "$WORK/ADBroomLauncher.apk" "$WORK/aligned.apk"
"$TOOLS/apksigner" verify --verbose "$WORK/ADBroomLauncher.apk"
mv "$WORK/ADBroomLauncher.apk" "$FINAL"
cp "$FINAL" "$ROOT/build/launcher/ADBroomLauncher.apk"
(cd "$ROOT/dist/launcher" && shasum -a 256 "$(basename "$FINAL")" > "$(basename "$FINAL").sha256")
echo "✓ $FINAL"
