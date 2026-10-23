#!/bin/zsh
# Independent products: default = Mac only (no JDK/Android SDK required).
# ./build.sh --dmg | --launcher | --all [--dmg]
set -euo pipefail
cd "$(dirname "$0")"
product=macos
package=false
for option in "$@"; do
  case "$option" in
    --macos) product=macos ;;
    --launcher) product=launcher ;;
    --all) product=all ;;
    --dmg) package=true ;;
    *) echo "Usage: ./build.sh [--macos|--launcher|--all] [--dmg]" >&2; exit 2 ;;
  esac
done
if [[ "$product" == macos || "$product" == all ]]; then
  if $package; then ./apps/macos/build.sh --dmg; else ./apps/macos/build.sh; fi
fi
if [[ "$product" == launcher || "$product" == all ]]; then ./apps/launcher/build.sh; fi
