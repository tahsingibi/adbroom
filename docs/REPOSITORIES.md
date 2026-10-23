# Repository setup

## Current workspace

The current `tahsingibi/adbroom` repository contains both products. Each product already builds independently; they currently share the Git repository and GitHub Releases.

| Folder | Contents | Committed? |
| --- | --- | --- |
| `apps/macos/` | Mac source, resources, tests and version | Yes |
| `apps/launcher/` | TV launcher source, resources and tests | Yes, until the repository split |
| `assets/branding/` | Shared artwork | Yes |
| `scripts/`, `docs/` | Build/release helpers and documentation | Yes |
| `build/` | Local apps, development APK and compiler cache | No |
| `dist/` | DMG/APK release packages and checksums | No; upload as release assets |
| `apps/launcher/.signing/` | Existing local APK signing key | No; retain privately for compatible TV updates |

The Mac app to open is `/Applications/ADBroom.app` or `build/macos/ADBroom.app`. The launcher installer is `dist/launcher/ADBroomLauncher-1.2.1.apk`.

## Save and push the existing work

From the repository root:

```sh
git status
git add -A
git diff --cached --check
git commit -m "feat: redesign macOS app and add standalone TV launcher"
git push origin main
```

Only run the commit command when changes have not already been committed. Check `git log -1 --oneline` first.

## Create the separate launcher repository

Create an **empty public** GitHub repository named `adbroom-launcher` under `tahsingibi`. Leave automatic README, .gitignore and license creation unchecked. Public releases allow the companion's existing unauthenticated GitHub download flow to fetch APKs.

Expected repository URL: `https://github.com/tahsingibi/adbroom-launcher`.

Creating that repository does not yet move the launcher or change download addresses. Complete the following migration after the actual URL is confirmed:

1. Move launcher source to a standalone repository layout and adapt its build/test scripts, which currently resolve paths relative to this workspace.
2. Include the license, branding resources and standalone README. Keep generated APKs and signing keys outside Git.
3. Retain the existing local signing identity so previously installed TVs can update without removing the launcher.
4. Update the Mac client's launcher release/download URL and validation rules, its tests, release helpers and documentation to the new repository. Keep Mac updates pointed at `tahsingibi/adbroom`.
5. Build and verify the standalone APK; publish it and its SHA-256 file as a launcher GitHub Release.
6. Verify that the Mac app can download the APK from that release, then remove the migrated launcher source from the Mac repository.

Do not upload only the current `apps/launcher` folder and assume it is ready: its scripts and README links still rely on the parent repository. Do not publish an APK from a different signing key over the installed version.
