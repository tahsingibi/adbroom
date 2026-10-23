<p align="center"><img src="Resources/icon-1024.png" width="128" alt="ADBroom"></p>
<h1 align="center">ADBroom for Mac</h1>
<p align="center">A native workspace for your Android TV.<br><a href="README.md">Türkçe</a> · <b>English</b></p>

[Download the latest release](https://github.com/tahsingibi/adbroom/releases/latest) · [Independent TV launcher](https://github.com/tahsingibi/adbroom-launcher) · [Changelog](CHANGELOG.md)

## What you can do

- **Remote:** navigation, volume, channels, input, media, power and keyboard text, with keyboard shortcuts.
- **Screen:** view video/audio with scrcpy, take screenshots and save PNGs.
- **Apps:** install APK/split APKs, search by app name or package, open/stop apps and manage default home selection.
- **Launcher:** install the optional TV launcher from its own GitHub repository; edit order, favorites, labels, collections, hidden apps, appearance/modules and JSON backups.
- **Packages:** disable/re-enable unwanted packages with recovery records and critical-package protection.
- **General:** About, System and Updates in one page, in that order. Choose System/Light/Dark appearance and automatic update checking.
- Türkçe / English. Native SwiftUI, consistent cards/forms and a persistent device panel.

## Install and connect

Requires **macOS 14+**, Apple Silicon or Intel. Download `ADBroom-<version>.dmg` from the [latest release](https://github.com/tahsingibi/adbroom/releases/latest), open it and drag ADBroom to Applications. The local package is ad-hoc signed rather than notarized; macOS may offer **System Settings → Privacy & Security → Open Anyway**.

Install the external TV tools:

```sh
brew install android-platform-tools scrcpy
```

Enable developer options and USB/network/wireless debugging on the TV. Connect your Mac and TV to the same network, enter the TV IP in the device panel and approve debugging on the TV. If Android asks for a pairing code, use the link button with its pairing IP:port/code first, then connect to its connection IP:port.

## Independent launcher

The launcher has its own source repository, versions, signing identity and APK releases:

**[tahsingibi/adbroom-launcher](https://github.com/tahsingibi/adbroom-launcher)**

It works without this Mac app. Download just the APK if you only need a TV home screen. This repository builds only the Mac app; the DMG contains no APK and needs no JDK/Android SDK.

**General → About → Download launcher APK** saves the standalone installer even without a TV. With a TV connected, the Launcher installation action or **Launcher actions → Update launcher** downloads the stable APK and verifies its SHA-256 before installing over ADB. For local files use **Apps → Install APK**. In the editor, arrange apps, open per-app preferences, then **Save to TV**; **Appearance & modules** edits the profile and **Backup** imports/exports JSON. Default-home selection is in Apps or the Launcher actions menu.

## Source and builds

```text
Sources/          Mac SwiftUI app, ADB transport and launcher bridge
Resources/        Mac app icon
Tests/            Release/download and launcher protocol tests
scripts/          Mac release helpers
docs/             Publishing guide
VERSION           Mac version
BUILD_NUMBER      Mac bundle build number
build.sh          Mac-only universal build
build/            ADBroom.app and compiler cache (ignored)
dist/             DMG and SHA-256 (ignored)
```

```sh
./build.sh          # build/ADBroom.app
./build.sh --dmg    # also dist/ADBroom-<version>.dmg and .sha256
```

Only Xcode or Command Line Tools are required. A failed build preserves the previous verified app; the Swift module cache stays inside `build/.module-cache`. Open `build/ADBroom.app` or the installed `/Applications/ADBroom.app`.

Tests:

```sh
mkdir -p build/.module-cache
swiftc -swift-version 5 -module-cache-path build/.module-cache Sources/L10n.swift Sources/UpdateClient.swift Sources/UpdateModel.swift Sources/LauncherDownload.swift Tests/UpdatesTests.swift -o build/updates-tests
build/updates-tests          # build/updates-tests --live: checks against GitHub
```

[Publishing](docs/RELEASING.md)

## Releases and updates

Mac releases are served by `tahsingibi/adbroom`; launcher releases by `tahsingibi/adbroom-launcher`. The updater never treats an APK as a Mac update or accepts an installer from the wrong repository. Stable Mac tags use `macos-v<version>`; legacy `v<version>` Mac tags remain supported. **Mac 1.1.0** contains the redesigned workspace, APK/default-app management and independent launcher integration; see [release notes](CHANGELOG.md).

With authenticated GitHub CLI, `./scripts/release.sh` creates a draft; `./scripts/release.sh --publish` publishes the DMG/checksum. GitHub source commits alone are not installers. Daily checks can be disabled in General; downloads and installation are user initiated, and TV/app-list data is not sent to GitHub.

## Limits and credits

DRM, live TV and HDMI may appear black in screen viewing. Low-end TVs can need lower quality; audio requires Android 11+. Deep standby wake-up needs Wake-on-LAN support. Default-home, HDMI and media support depend on the TV/OEM APIs. APK updates must retain their signing identity.

Tahsin Sungur · [X/tahsingibi](https://x.com/tahsingibi) · [sungur.dev](https://sungur.dev)

The TV clean-up workflow draws on [Mert Çobanov's guide](https://tv.cobanov.dev/); screen viewing uses [scrcpy](https://github.com/Genymobile/scrcpy). [MIT](LICENSE). Not affiliated with Google or TV manufacturers. Android is a trademark of Google LLC. The Android robot is reproduced or modified from work shared by Google under the [Creative Commons 3.0 Attribution License](https://creativecommons.org/licenses/by/3.0/).
