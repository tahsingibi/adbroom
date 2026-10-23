#!/bin/bash
# Resize the committed transparent master on macOS. Product builds consume the
# resulting committed PNGs and do not need this script or an image service.
set -euo pipefail
cd "$(dirname "$0")/.."
MASTER="assets/branding/adbroom-icon.png"
[[ -f "$MASTER" ]] || { echo "Missing branding master: $MASTER" >&2; exit 1; }
command -v sips >/dev/null || { echo 'Run asset preparation on macOS (sips required).' >&2; exit 1; }
mkdir -p apps/macos/Resources
sips -z 1024 1024 "$MASTER" --out apps/macos/Resources/icon-1024.png >/dev/null
for spec in mdpi:96 hdpi:144 xhdpi:192 xxhdpi:288 xxxhdpi:384; do
  density="${spec%:*}"
  size="${spec#*:}"
  folder="apps/launcher/res/drawable-$density"
  mkdir -p "$folder"
  sips -z "$size" "$size" "$MASTER" --out "$folder/launcher_icon.png" >/dev/null
done
echo '✓ Mac and Android icon sizes prepared from the shared master.'
