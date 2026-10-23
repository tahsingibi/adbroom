#!/bin/bash
# Resize the committed transparent master on macOS. Product builds consume the
# resulting committed PNGs and do not need this script or an image service.
set -euo pipefail
cd "$(dirname "$0")/.."
MASTER="assets/branding/adbroom-icon.png"
[[ -f "$MASTER" ]] || { echo "Missing branding master: $MASTER" >&2; exit 1; }
command -v sips >/dev/null || { echo 'Run asset preparation on macOS (sips required).' >&2; exit 1; }
mkdir -p Resources
sips -z 1024 1024 "$MASTER" --out Resources/icon-1024.png >/dev/null
echo '✓ Mac icon prepared from the shared master.'
