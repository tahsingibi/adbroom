<p align="center">
  <img src="Resources/icon-1024.png" width="128" alt="ADBroom icon">
</p>

<h1 align="center">ADBroom</h1>

<p align="center">
  ADBroom: Debloat (clean up) your Android TV from your Mac<br>
  <b>English</b> · <a href="README.tr.md">Türkçe</a>
</p>

> [!NOTE]
> ADBroom is the app version of [Mert Çobanov](https://cobanov.dev)'s [Clean up your Android TV](https://tv.cobanov.dev/). If you prefer the terminal to an app, the guide and its prompts get you to the same result.

## Features

- **Remote:** navigation, volume, channels, Input, Settings, media keys, text input, power on/off.
- **Screen:** watch the TV with video and audio (via [scrcpy](https://github.com/Genymobile/scrcpy)), screenshots.
- **Apps:** list, open and force-stop apps.
- **Packages:** disable and re-enable packages. Never uninstalls. Critical packages are locked.
- **System:** RAM and storage info, clear caches, animation speed, reboot.
- Türkçe / English.

Works with Android TV, Google TV and Fire TV.

## Install

Requires macOS 14+ (Apple Silicon or Intel).

1. Install the tools:
   ```sh
   brew install android-platform-tools scrcpy
   ```
2. Download the DMG from [Releases](../../releases) and drag **ADBroom** to **Applications**.
3. The app isn't notarized. On first launch: **System Settings → Privacy & Security → Open Anyway**.

## Prepare your TV (one time)

1. **Settings → Device Preferences → About:** press **Build** 7 times.
2. **Developer options:** turn on **USB debugging** (or **Network / Wireless debugging**).
3. **Settings → Network & Internet:** note the TV's IP. The Mac and TV must be on the same network.
4. In ADBroom, enter the IP and press **Connect**. On the TV, choose **Always allow** and **Allow**.

If the TV asks for a pairing code (Android 11+ Wireless debugging), use **Pair…** in ADBroom with the `IP:port` and code shown on the TV, then connect with the `IP:port` from the Wireless debugging screen.

## Packages

- ADBroom only uses `pm disable-user --user 0`. Everything can be restored with `pm enable`.
- The home screen, keyboard, TV inputs, Input key, remote and Play Services are locked.
- Disable a few packages at a time and test the TV. If something breaks, press **Enable** or **Revert all**.

To undo without the app:

```sh
adb connect <TV-IP>:5555
adb shell pm enable <package>
```

## Limitations

- Antenna, HDMI and DRM content (Netflix, Prime…) appear black in the viewer.
- TVs without a hardware video encoder may stutter while watching. Use Low quality.
- Powering on from deep sleep requires Wake-on-LAN support.

## Build

```sh
./build.sh          # build/ADBroom.app
./build.sh --dmg    # build/ADBroom-x.y.z.dmg
```

Requires Xcode or the Command Line Tools.

## Credits

- [Mert Çobanov](https://cobanov.dev): [Clean up your Android TV](https://tv.cobanov.dev/)
- [scrcpy](https://github.com/Genymobile/scrcpy)

## License

[MIT](LICENSE). Use at your own risk. Not affiliated with Google or any TV manufacturer. Android is a trademark of Google LLC. The Android robot is reproduced or modified from work created and shared by Google and used according to terms described in the [Creative Commons 3.0 Attribution License](https://creativecommons.org/licenses/by/3.0/).
