#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:---draft}"
[[ $# -le 1 && ( "$MODE" == --draft || "$MODE" == --publish ) ]] || { echo 'Usage: ./scripts/release.sh [--draft|--publish]' >&2; exit 2; }
command -v gh >/dev/null || { echo 'Install GitHub CLI and authenticate: gh auth login' >&2; exit 1; }
gh auth status >/dev/null
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit all changes first.' >&2; exit 1; }
git fetch origin main
COMMIT="$(git rev-parse HEAD)"
[[ "$COMMIT" == "$(git rev-parse origin/main)" ]] || { echo 'Push main first.' >&2; exit 1; }
VERSION="$(cat VERSION)"
TAG="macos-v$VERSION"
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then echo "Tag exists: $TAG" >&2; exit 1; fi
./build.sh --dmg
NOTES="$(mktemp "${TMPDIR:-/tmp}/adbroom-mac-notes.XXXXXX")"
trap 'rm -f "$NOTES"' EXIT
python3 scripts/release-notes.py "$VERSION" > "$NOTES"
ARGS=("$TAG" "dist/ADBroom-$VERSION.dmg" "dist/ADBroom-$VERSION.dmg.sha256" --repo tahsingibi/adbroom --title "ADBroom for macOS $VERSION" --notes-file "$NOTES" --target "$COMMIT")
[[ "$MODE" == --draft ]] && ARGS+=(--draft)
gh release create "${ARGS[@]}"
