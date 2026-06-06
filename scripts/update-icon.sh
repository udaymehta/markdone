#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ICON_DIR="$PROJECT_DIR/assets/icon"

check_deps() {
  command -v rsvg-convert &>/dev/null || { echo "rsvg-convert not found. Install: sudo apt install librsvg2-bin"; exit 1; }
}

convert_svgs() {
  rsvg-convert -w 1024 -h 1024 "$ICON_DIR/combined.svg" -o "$ICON_DIR/combined.png"
  rsvg-convert -w 432 -h 432 "$ICON_DIR/foreground.svg" -o "$ICON_DIR/foreground.png"
}

run_icons() {
  (cd "$PROJECT_DIR" && dart run flutter_launcher_icons)
}

clean_splash() {
  find "$PROJECT_DIR/android/app/src/main/res" \( -name "background.png" -o -name "branding.png" -o -name "splash.png" \) -delete 2>/dev/null || true
}

clean_cache() {
  (cd "$PROJECT_DIR" && flutter clean &>/dev/null && flutter pub get &>/dev/null)
}

check_deps
convert_svgs
run_icons
clean_splash
clean_cache
