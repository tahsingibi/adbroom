# Mac releases

This repository releases only ADBroom for Mac. [ADBroom Launcher](https://github.com/tahsingibi/adbroom-launcher) has a separate repository, release script and APK channel.

1. Update `VERSION` and increment `BUILD_NUMBER`; complete `CHANGELOG.md`.
2. Build `./build.sh --dmg` and verify the resulting universal app and DMG/checksum.
3. Commit and push `main`.
4. Create a release with tag `macos-v<version>` targeting that commit; attach `dist/ADBroom-<version>.dmg` and `dist/ADBroom-<version>.dmg.sha256`.

With authenticated GitHub CLI:

```sh
./scripts/release.sh             # Draft
./scripts/release.sh --publish   # Stable public release
```

GitHub → Releases → Draft a new release also works. The script requires a clean checkout whose HEAD matches pushed `main`; it builds only the Mac package and defaults to a draft. Local builds do not publish anything.

The Mac updater reads this repository's public stable releases. `macos-v…` and legacy `v…` tags are accepted when they carry an official Mac DMG. Drafts, prereleases and unrelated assets are ignored. Launcher downloads read the public releases of `tahsingibi/adbroom-launcher`, accept `launcher-v…` APKs and verify the GitHub SHA-256 digest or companion checksum asset before installation.

The Mac DMG has no APK or Android build dependency. It is ad-hoc signed; notarization requires a separate Apple signing identity. User preferences stay outside the application bundle. The launcher's private signing key must remain unchanged across APK updates and is never part of either repository.
