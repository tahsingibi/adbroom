# Independent GitHub releases

For the current folder map and the planned move to a separate launcher repository, see [Repository setup](REPOSITORIES.md).

Two products share the repository, with independent tags, version sources and downloadable assets. Neither product must be rebuilt or published merely because the other changed.

| Product | Tag | Version source | Assets |
| --- | --- | --- | --- |
| Mac companion | `macos-v1.1.0` | `apps/macos/VERSION`, `BUILD_NUMBER` | `ADBroom-1.1.0.dmg`, `.dmg.sha256` |
| Android TV launcher | `launcher-v1.2.1` | `apps/launcher/AndroidManifest.xml` | `ADBroomLauncher-1.2.1.apk`, `.apk.sha256` |

## Mac

1. Increment VERSION and BUILD_NUMBER; finish the matching root CHANGELOG section.
2. Commit and push the release source to the tracked branch.
3. Run `./scripts/release.sh macos` to build and create a **draft** with the DMG and checksum attached. Review the draft in GitHub before publishing.
4. Use `./scripts/release.sh macos --publish` only when you want the script to publish immediately.

## Launcher

1. Increment Android versionName/versionCode and complete `apps/launcher/CHANGELOG.md`.
2. Keep the existing APK signing identity; use the same release key on every machine.
3. Commit and push the release source to the tracked branch.
4. Run `./scripts/release.sh launcher` to build and create a **draft** with the APK and checksum attached. Review and publish it in GitHub.
5. Use `./scripts/release.sh launcher --publish` only when you want the script to publish immediately. This release is directly usable without the Mac app.

Install and authenticate GitHub CLI once using `brew install gh` and `gh auth login`. The release script checks for a clean, pushed commit, builds only the requested product, generates notes and attaches its checksum. `./build.sh --all --dmg` prepares both products locally but does not publish anything.

## Channel behavior

The Mac updater reads GitHub's public releases list and selects stable `macos-v…` releases carrying an official DMG. Legacy `v…` Mac tags remain supported. Launcher install/download selects `launcher-v…` releases carrying an official APK. Drafts/prereleases and unrelated assets are skipped, including when the repository's most recent release belongs to the other product. The lookup examines up to five pages of 100 releases to find a matching channel.

Mac update checking shows notes and download links; the user installs the DMG. **General → About → Download launcher APK** saves the independent APK without requiring a TV. With a TV connected, **Launcher → Install/Update** downloads and installs it through ADB. The APK is verified using the GitHub SHA-256 digest or the matching checksum asset before ADB sees it. If a launcher has not yet been published, the app explains this; local APK installation stays available.

The source changes must be pushed and releases/assets actually published before public GitHub downloads can serve them. A git tag without a published Release and the expected assets is insufficient. Preferences stay in UserDefaults/Application Support on Mac and private storage on TV; replacing packages does not remove them. Keep APK signing keys private and unchanged across updates.
