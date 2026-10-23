#!/usr/bin/env bash
# Build one product and create its GitHub Release. Draft is the safe default.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "Usage: ./scripts/release.sh macos|launcher [--draft|--publish]" >&2
  exit 2
}
ensure_tag_free() {
  if git ls-remote --exit-code --tags origin "refs/tags/$1" >/dev/null 2>&1; then
    echo "GitHub tag already exists: $1" >&2
    exit 1
  fi
}
[[ $# -ge 1 && $# -le 2 ]] || usage
component="$1"
mode="${2:---draft}"
[[ "$component" == macos || "$component" == launcher ]] || usage
[[ "$mode" == --draft || "$mode" == --publish ]] || usage

command -v gh >/dev/null || { echo "GitHub CLI missing. Install with: brew install gh" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Python 3 is required." >&2; exit 1; }
gh auth status >/dev/null
[[ -z "$(git status --porcelain)" ]] || { echo "Commit or stash all changes before releasing." >&2; exit 1; }

upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')"
head_commit="$(git rev-parse HEAD)"
git fetch origin "${upstream#origin/}"
remote_commit="$(git rev-parse "$upstream")"
[[ "$head_commit" == "$remote_commit" ]] || {
  echo "Push the current commit first; HEAD and $upstream differ." >&2
  exit 1
}

if [[ "$component" == macos ]]; then
  version="$(cat apps/macos/VERSION)"
  tag="macos-v$version"
  ensure_tag_free "$tag"
  artifact="dist/macos/ADBroom-$version.dmg"
  checksum="$artifact.sha256"
  title="ADBroom for macOS $version"
  ./build.sh --macos --dmg
  notes="${TMPDIR:-/tmp}/adbroom-release-notes-macos-$version.md"
  python3 scripts/release-notes.py "$version" --component macos > "$notes"
else
  version="$(python3 -c 'import xml.etree.ElementTree as E; print(E.parse("apps/launcher/AndroidManifest.xml").getroot().get("{http://schemas.android.com/apk/res/android}versionName"))')"
  tag="launcher-v$version"
  ensure_tag_free "$tag"
  artifact="dist/launcher/ADBroomLauncher-$version.apk"
  checksum="$artifact.sha256"
  title="ADBroom Launcher $version"
  ./build.sh --launcher
  notes="${TMPDIR:-/tmp}/adbroom-release-notes-launcher-$version.md"
  python3 scripts/release-notes.py "$version" --component launcher > "$notes"
fi

[[ -f "$artifact" && -f "$checksum" ]] || { echo "Expected release assets were not built." >&2; exit 1; }

args=("$tag" "$artifact" "$checksum" --title "$title" --notes-file "$notes" --target "$head_commit")
[[ "$mode" == --draft ]] && args+=(--draft)
gh release create "${args[@]}"
echo "✓ GitHub release created: $tag ($mode)"
