<p align="center"><img src="../../assets/branding/adbroom-icon.png" width="112" alt="ADBroom Launcher"></p>

# ADBroom Launcher for Android TV

Independent native Android TV home screen, Android 6.0/API 23+. **The Mac app is not required.** Java + platform views; no WebView, third-party runtime, INTERNET permission, ads or analytics.

## Download and install without the Mac app

1. Open [Launcher releases](https://github.com/tahsingibi/adbroom/releases?q=launcher-v) on GitHub and download `ADBroomLauncher-<version>.apk` from Assets. The `.sha256` asset is the checksum.
2. Transfer the APK to the TV and open it with its APK installer, allowing installation from the source you chose when Android asks. Alternatively, use ADB from macOS, Windows or Linux:

   ```sh
   adb connect <TV-IP>:5555
   adb -s <TV-IP>:5555 install -r ADBroomLauncher-1.2.1.apk
   adb -s <TV-IP>:5555 shell am start -n io.github.adbroom.launcher/.HomeActivity
   ```

3. Open Launcher settings → Home screen → Default home app to select ADBroom. The original home app stays installed. Some TVs restrict the default picker; optional Home routing is explained in launcher settings and must be enabled manually in Android Accessibility settings.

The launcher works on its own after installation. App ordering, favorites, collections, appearance and parental controls are managed with the TV remote. Using the optional Mac companion provides remote control, installation and an additional editor.

In the Mac companion, **Launcher** edits order and per-app preferences, **Settings** edits the profile, and **Backup** imports/exports JSON. Choose **Save to TV** to apply local changes. The TV stores the order and profile; the Mac app is not needed afterward. **General → About → Download launcher APK** also downloads the standalone installer without a TV connection.

## Controls and settings

OK opens an app; hold OK for move, favorite, rename, collection, hide/show, PIN lock and app info. Menu enters rearranging; arrows move, OK saves and Back cancels. Hidden apps remain available from Settings → Applications. Collections are flat filters alongside All.

Settings include grid/horizontal row, 4–8 columns, icon/banner cards, themes, colors, photo wallpaper, labels, 12/24-hour clock, date, profile name and English/Türkçe/system language. Modules cover favorites, connection status, Live TV/HDMI and optional media. HDMI behavior depends on the TV's input service.

Media requires user-enabled notification access; notification text is never stored. Only the most recent media title/source are retained locally and can be cleared in Settings. The optional accessibility service routes Home and recognizes other home activities, with window-content retrieval disabled. Neither service is enabled automatically. Android sideload restrictions can limit availability.

PIN uses a native remote keypad, salted PBKDF2 and a delay after repeated failures. It protects launcher entry points, not Android globally. PIN material and wallpaper files are excluded from the Mac JSON backup. User preferences remain on the TV across updates signed with the same key.

## Build independently

Requires JDK 17+, Python 3 and Android SDK platform/build-tools 35+. Set `JAVA_HOME` and `ANDROID_SDK_ROOT` if needed. macOS defaults to `~/Library/Android/sdk`; on other systems set the SDK path explicitly. No Mac compiler, Swift or companion app is needed.

```sh
./apps/launcher/build.sh
# Or:
./build.sh --launcher
```

Outputs:

```text
dist/launcher/ADBroomLauncher-<version>.apk
dist/launcher/ADBroomLauncher-<version>.apk.sha256
build/launcher/ADBroomLauncher.apk   # unversioned development/test copy
```

Version and versionCode come from `AndroidManifest.xml`. `ANDROID_BUILD_TOOLS`/`ANDROID_PLATFORM` can select SDK directories. A local signing identity is kept in ignored `.signing/development.jks`; the reorganization preserves the existing key. Keep it for updates. Distribution can use `LAUNCHER_KEYSTORE`, `LAUNCHER_KEY_ALIAS` and `LAUNCHER_STORE_PASSWORD`; different build machines must share the release identity. The build verifies the signed APK before replacing the output.

## Icon and TV banner

The launcher uses the same rounded Android TV / magic wand artwork as the Mac companion. Density-specific transparent icons live in `res/drawable-*`; `res/drawable/banner.xml` centers the icon on a TV banner without stretching or clipping its corners. The manifest and fallback app-card drawable reference these resources. See the [shared artwork and source](../../assets/branding/README.md).

## Tests

The build runs `tests/OrderLogicTest.java`. With a disposable emulator on port 5580:

```sh
python3 apps/launcher/tests/smoke.py --adb "$ANDROID_SDK_ROOT/platform-tools/adb"
python3 apps/launcher/tests/features.py --adb "$ANDROID_SDK_ROOT/platform-tools/adb"
bash apps/launcher/tests/focus.sh emulator-5580
```

These tests change only the specified disposable emulator's home/profile. They cover persistence, conflicts, D-pad ordering, configuration, hidden-app recovery and PIN flows. Physical HDMI inputs and OEM Home routing require testing on the actual TV.

The focus regression builds a separate instrumentation APK with the same signing key and inspects each drawn frame during grid/row navigation, scrolling, toolbar focus changes and reordering. It checks that the selected card is the only highlighted card. Test code is never included in the production launcher APK.

[Launcher changelog](CHANGELOG.md) · [Mac companion](../macos/README.md) · [Release guide](../../docs/RELEASING.md) · [License](../../LICENSE)
