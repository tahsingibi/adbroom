#!/bin/bash
# Builds a separate instrumentation APK; never adds test code to the launcher.
set -euo pipefail
cd "$(dirname "$0")/../../.."
SERIAL="${1:-emulator-5580}"
[[ "$SERIAL" =~ ^emulator-[0-9]+$ ]] || { echo 'Disposable emulators only.' >&2; exit 1; }
SDK="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
TOOLS="${ANDROID_BUILD_TOOLS:-$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)}"
PLATFORM="${ANDROID_PLATFORM:-$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)}"
JAVA_BIN="${JAVA_HOME:+$JAVA_HOME/bin/}"
ADB="$SDK/platform-tools/adb"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/adbroom-focus.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/classes" "$WORK/dex"
cat > "$WORK/AndroidManifest.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="io.github.adbroom.launcher.focustest">
  <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="35" />
  <application android:label="ADBroom focus regression" />
  <instrumentation android:name="io.github.adbroom.launcher.tests.FocusInstrumentation" android:targetPackage="io.github.adbroom.launcher" />
</manifest>
XML
"$TOOLS/aapt2" link -o "$WORK/base.apk" -I "$PLATFORM/android.jar" --manifest "$WORK/AndroidManifest.xml"
"${JAVA_BIN}javac" --release 8 -classpath "$PLATFORM/android.jar" -d "$WORK/classes" apps/launcher/tests/FocusInstrumentation.java
"${JAVA_BIN}jar" cf "$WORK/test.jar" -C "$WORK/classes" io
"$TOOLS/d8" --min-api 24 --lib "$PLATFORM/android.jar" --output "$WORK/dex" "$WORK/test.jar"
(cd "$WORK/dex" && zip -q -u "$WORK/base.apk" classes.dex)
"$TOOLS/zipalign" -f -p 4 "$WORK/base.apk" "$WORK/aligned.apk"
export LAUNCHER_STORE_PASSWORD="${LAUNCHER_STORE_PASSWORD:-android}"
"$TOOLS/apksigner" sign --ks "${LAUNCHER_KEYSTORE:-apps/launcher/.signing/development.jks}" \
  --ks-key-alias "${LAUNCHER_KEY_ALIAS:-adbroom}" --ks-pass env:LAUNCHER_STORE_PASSWORD \
  --out "$WORK/test.apk" "$WORK/aligned.apk"
"$ADB" -s "$SERIAL" install --no-incremental -r build/launcher/ADBroomLauncher.apk
"$ADB" -s "$SERIAL" install --no-incremental -r "$WORK/test.apk"
"$ADB" -s "$SERIAL" shell am force-stop io.github.adbroom.launcher
"$ADB" -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP
"$ADB" -s "$SERIAL" shell wm dismiss-keyguard
"$ADB" -s "$SERIAL" shell am instrument -w \
  io.github.adbroom.launcher.focustest/io.github.adbroom.launcher.tests.FocusInstrumentation > "$WORK/result.txt"
cat "$WORK/result.txt"
grep -q 'focus_status=PASS' "$WORK/result.txt"
