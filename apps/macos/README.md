<p align="center"><img src="../../assets/branding/adbroom-icon.png" width="112" alt="ADBroom"></p>

# ADBroom for macOS

Native SwiftUI remote control and app management for Android TV. Requires macOS 14+ (Apple Silicon or Intel). The TV launcher is a separate, optional product.

## Download and use

The redesigned workspace uses a persistent device panel, consistent page headers and cards, searchable app rows, a segmented remote panel and a simplified launcher editor. Stop/settings actions are in each app row’s menu; default-app controls expand in place. Launcher installation/default actions are in its overflow menu, and **Appearance & modules** opens the profile sheet. General → About offers System/Light/Dark appearance; key feedback respects Reduce Motion.

Download the Mac DMG from [Mac releases](https://github.com/tahsingibi/adbroom/releases?q=macos-v), open it and drag ADBroom to Applications. Install ADB tools if you want to connect to a TV:

```sh
brew install android-platform-tools scrcpy
```

**General** is one page with About, System and Updates blocks, in that order. It includes Tahsin Sungur, X/tahsingibi, sungur.dev and the GitHub repository. About and update/download controls work without a TV connection. Connected TV system information and maintenance tools appear in System.

The sidebar contains Remote, Screen, Apps, Launcher, Packages and General, with connection/pairing and language controls at the bottom. The toolbar toggles sidebar visibility. Both columns are bounded by the window size so loading the launcher does not invalidate sidebar layout.

**Launcher** loads the TV's current order and preferences. Drag rows or use the up/down buttons, edit per-app preferences with the sliders button, and choose **Save to TV**. **Settings** opens profile options; **Backup** imports/exports JSON. Refresh asks before discarding local edits. TV requests run asynchronously with time limits; loading does not count as a local edit.

**General → About → Download launcher APK** saves the independent APK to your Mac. With a TV connected, **Apps/Launcher → Yes, install and try** or **Update launcher** downloads the stable launcher from GitHub, verifies its SHA-256, then installs it over ADB. A local APK can always be installed with **Apps → Install APK**. The Mac app never bundles an APK or requires the launcher to run.

## Build

Only Xcode or Command Line Tools are needed; no JDK or Android SDK is involved.

```sh
./apps/macos/build.sh          # build/macos/ADBroom.app
./apps/macos/build.sh --dmg    # dist/macos/ADBroom-<version>.dmg + .sha256
# Equivalent root commands:
./build.sh
./build.sh --dmg
```

Version: `apps/macos/VERSION`; incrementing bundle build: `apps/macos/BUILD_NUMBER`. The build publishes a verified complete bundle and preserves the previous app on failure.

The Swift module cache is stored in `build/macos/.module-cache`, so building does not require write access to the user's global cache. Open `build/macos/ADBroom.app` after building. The legacy `build/ADBroom.app` path links to the current build so it cannot open an outdated copy.

## Update channel

Stable tags use `macos-v<version>` and include `ADBroom-<version>.dmg`. Legacy `v<version>` Mac releases are also recognized. The client reads GitHub release metadata and filters by tag and DMG asset; a newer launcher release cannot become a Mac update. Automatic checks run on launch/activation at most once per day and can be disabled in About. Checks do not install updates or send TV data.

## Source and tests

- `Sources/`: native app, About blocks, ADB transport, GitHub channels and launcher download bridge.
- `Resources/`: app icon and Mac resources.
- `Tests/`: Swift protocol and update/download tests.

`Resources/icon-1024.png` is derived from the [shared transparent master](../../assets/branding/README.md). The build produces all ICNS sizes from 16 to 1024 pixels. Finder, Dock, About and the DMG installation use that bundled icon.

```sh
mkdir -p build/macos/.module-cache
swiftc -swift-version 5 -module-cache-path build/macos/.module-cache apps/macos/Sources/L10n.swift apps/macos/Sources/UpdateClient.swift apps/macos/Sources/UpdateModel.swift apps/macos/Sources/LauncherDownload.swift apps/macos/Tests/UpdatesTests.swift -o /tmp/adbroom-updates-tests
/tmp/adbroom-updates-tests
/tmp/adbroom-updates-tests --live
```

[Changelog](../../CHANGELOG.md) · [Release guide](../../docs/RELEASING.md) · [Launcher](../launcher/README.md)
