<p align="center"><img src="assets/branding/adbroom-icon.png" width="128" alt="ADBroom"></p>
<h1 align="center">ADBroom</h1>
<p align="center">A native Mac companion and an independent Android TV launcher.<br><b>English</b> · <a href="README.tr.md">Türkçe</a></p>

## Choose your download

| Product | Platform | Download | Needs the other app? |
| --- | --- | --- | --- |
| **ADBroom for Mac** | macOS 14+, Apple Silicon / Intel | [Mac releases](https://github.com/tahsingibi/adbroom/releases?q=macos-v) — `ADBroom-<version>.dmg` | No |
| **ADBroom Launcher** | Android TV / Google TV / Fire TV, Android 6+ | [Launcher releases](https://github.com/tahsingibi/adbroom/releases?q=launcher-v) — `ADBroomLauncher-<version>.apk` | No |

The products have independent versions and releases. Download only the APK if you just want a TV home screen. The Mac app can download the optional launcher afterward, but its DMG contains no APK. Published GitHub Releases carry the files and their SHA-256 checksums; source code alone is not an installer.

## Mac companion

The interface uses a shared system of page headers, cards and connection controls. Remote is a dedicated control workspace; Apps includes name/package search and per-row action menus; Launcher provides a focused ordering editor. Appearance can follow macOS or be set to Light/Dark in General → About.

- Remote: navigation, volume, channels, Input, media, text and power controls.
- Screen: video/audio viewing with scrcpy and screenshots; DRM/HDMI capture depends on the TV.
- Apps: APK/split-APK installation, launch/stop, default home selection and app settings.
- Launcher editor: app ordering, favorites, aliases, collections, hiding, appearance/modules and JSON backup.
- Packages: disable/re-enable with recovery records and protected critical packages; never uninstalls.
- **General:** one page showing About, System and Updates blocks in that order.
- Türkçe / English.

The sidebar keeps navigation and TV connection controls together. Its toolbar button hides or shows the sidebar. In Launcher, use drag and drop or the arrow buttons to reorder apps, open the sliders button for each app's preferences, then choose **Save to TV**. **Settings** edits the launcher profile; **Backup** imports/exports JSON. Loading and saving states prevent changes while TV data is being refreshed.

Install the DMG by dragging ADBroom to Applications. It is ad-hoc signed, not notarized; macOS may require **System Settings → Privacy & Security → Open Anyway**. TV features use external tools:

```sh
brew install android-platform-tools scrcpy
```

Enable developer options/USB or wireless debugging on the TV, put it on the same network as your Mac, enter its IP in ADBroom and approve the debugging prompt on TV. If it requires wireless pairing, use Pair with the TV's IP:port/code before connecting to its connection IP:port.

## Independent TV launcher

Native recycled grid/horizontal row, favorites, custom names, collections, hiding, wallpaper, clock, modules and optional parental PIN. No INTERNET permission, ads, WebView or third-party runtime. TV settings and preferences work without the Mac companion.

Download the APK from Launcher releases and transfer/install it using your TV's APK installer or ADB on **any** supported computer:

```sh
adb connect <TV-IP>:5555
adb -s <TV-IP>:5555 install -r ADBroomLauncher-1.2.1.apk
```

Choose ADBroom under the TV's default home settings. OK opens apps; hold OK for app options; Menu enters rearranging; arrows move, OK saves and Back cancels. Hidden apps remain manageable from launcher settings. Some manufacturers restrict Home selection; the optional Home routing service is explained in settings and must be enabled manually. Media access is also optional. PIN protects launcher entry points, not the whole Android system.

From Mac, **General → About → Download launcher APK** saves the standalone file even without a TV connection. When connected, **Launcher → Install/Update** downloads the separate GitHub package, verifies its checksum and installs it over ADB. For a local file use **Apps → Install APK**. Existing Android installs require the same APK signing identity for updates.

## Updates and history

**ADBroom → About ADBroom** opens General. Its Updates block supports manual checking and optional once-daily checks on launch/activation. **ADBroom → Check for Updates** opens General and checks immediately. Stable Mac and launcher channels are filtered separately, so a new APK is never offered as a Mac update. No TV data is sent to GitHub; downloads/installation are user initiated.

**Mac 1.1.0 (unreleased):** General with About/System/Updates, independent packages, verified launcher download, corrected Launcher/sidebar layout and the new shared icon. **v1.0.0** is the previously published Mac baseline. **Launcher 1.2.1 (unreleased):** independent versioned APK/checksum distribution and matching icon/banner. Local builds do not publish a GitHub release.

[Full Mac/project changelog](CHANGELOG.md) · [Launcher changelog](apps/launcher/CHANGELOG.md) · [Publishing guide](docs/RELEASING.md)

## Source layout and builds

```text
apps/
  macos/       Sources/, Resources/, Tests/, VERSION, BUILD_NUMBER, build.sh
  launcher/    src/, res/, tests/, AndroidManifest.xml, build.sh
assets/branding/ shared transparent icon and original artwork
scripts/       release-notes.py, release.sh
docs/          release and development notes
build/
  macos/       ADBroom.app
  ADBroom.app  compatibility symlink to macos/ADBroom.app
  launcher/    development APK
dist/
  macos/       versioned DMG + SHA-256
  launcher/    versioned APK + SHA-256
```

```sh
./build.sh                 # Mac app only; Xcode/Command Line Tools
./build.sh --dmg           # Mac app + dist/macos DMG/checksum
./build.sh --launcher      # Standalone APK; JDK 17+, Python 3, Android SDK
./build.sh --all --dmg     # Both products, still separate packages
./scripts/release.sh macos # Build and create a GitHub draft release
./scripts/release.sh launcher
```

A Mac build does not need JDK/Android SDK. A launcher build does not need Swift/Xcode. See [Mac development](apps/macos/README.md) and [launcher build/signing/tests](apps/launcher/README.md). Failed builds preserve the previous verified app. Signing keys, user data and generated outputs are not committed.

After building, open **`build/macos/ADBroom.app`**. The old `build/ADBroom.app` path links to the same current app. The Swift module cache stays in `build/macos/.module-cache`. If a copy is already running from Applications, quit it before replacing it with the new build.

## App artwork

The Mac icon, standalone launcher icon, TV banner and README headers use the same Android TV / magic wand artwork. The transparent master preserves the supplied rounded silhouette; platform sizes are derived without stretching it. See [branding assets](assets/branding/README.md).

GitHub publishing requires `brew install gh` and `gh auth login`. The release script defaults to a draft; use `--publish` only to publish immediately. See the [release guide](docs/RELEASING.md).

## Limits and credits

DRM-protected, live TV and HDMI content may appear black in the viewer. TVs without hardware video encoding may stutter; reduce quality. Deep standby wake-up needs Wake-on-LAN support. HDMI/media/Home modules depend on the TV/OEM APIs.

The original TV clean-up workflow comes from [Mert Çobanov's guide](https://tv.cobanov.dev/). Screen viewing uses [scrcpy](https://github.com/Genymobile/scrcpy).

[MIT](LICENSE). Use at your own risk. Not affiliated with Google or any TV manufacturer. Android is a trademark of Google LLC. The Android robot is reproduced or modified from work created and shared by Google under the [Creative Commons 3.0 Attribution License](https://creativecommons.org/licenses/by/3.0/).
