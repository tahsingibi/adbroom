# Two independent repositories

| Product | Repository | Local folder | Build | Release assets |
| --- | --- | --- | --- | --- |
| Mac companion | [tahsingibi/adbroom](https://github.com/tahsingibi/adbroom) | `~/Desktop/adbroom` | `./build.sh --dmg` | `dist/ADBroom-<version>.dmg` and `.dmg.sha256` |
| TV launcher | [tahsingibi/adbroom-launcher](https://github.com/tahsingibi/adbroom-launcher) | `~/Desktop/adbroom-launcher` | `./build.sh` | `dist/ADBroomLauncher-<version>.apk` and `.apk.sha256` |

Each folder is its own Git repository. Mac source is directly in `Sources/`; launcher source is directly in its own `src/` and `res/`. Neither build reads source or resources from the sibling checkout.

`build/` and `dist/` are generated and ignored. APK signing material stays privately in the launcher checkout's ignored `.signing/` directory. Its signing identity is the same as before the split, so installed TVs can update.

The companion queries Mac releases from `tahsingibi/adbroom` and launcher releases from `tahsingibi/adbroom-launcher`. Download and checksum URLs are validated against the corresponding repository. Publishing a source commit alone does not provide installers; publish the versioned package and checksum under the product's release tag.

In either checkout:

```sh
git status
git add -A
git commit -m "Describe the change"
git push origin main
```

The Mac app to open is `/Applications/ADBroom.app` or `~/Desktop/adbroom/build/ADBroom.app`. A launcher APK is installed on the TV, not opened on the Mac.
