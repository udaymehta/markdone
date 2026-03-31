#!/bin/bash
#
# update-icon.sh - Regenerates app icons from combined.svg
#
# Usage: ./scripts/update-icon.sh
#
# This script:
# 1. Converts combined.svg to PNGs (combined for iOS, foreground for Android)
# 2. Runs flutter_launcher_icons to generate all platform-specific icons
# 3. Removes old splash/launch resources (background.png, branding.png, splash.png)
# 4. Cleans Flutter build cache to ensure fresh build
#
# Requirements:
# - rsvg-convert (install via: sudo apt install librsvg2-bin)
# - Flutter SDK
#
# The only file you need to modify is: assets/icon/combined.svg
#

set -e

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if rsvg-convert is installed
if ! command -v rsvg-convert &> /dev/null; then
    echo "Error: rsvg-convert not found."
    echo "Install it with: sudo apt install librsvg2-bin"
    exit 1
fi

# Check if combined.svg exists
if [ ! -f "$PROJECT_DIR/assets/icon/combined.svg" ]; then
    echo "Error: assets/icon/combined.svg not found!"
    exit 1
fi

echo "=== Updating App Icon ==="
echo ""

# Step 1: Convert combined.svg to PNGs
echo "Step 1: Converting combined.svg to PNGs..."

# combined.png - Full icon (1024x1024) for iOS fallback
rsvg-convert -w 1024 -h 1024 "$PROJECT_DIR/assets/icon/combined.svg" -o "$PROJECT_DIR/assets/icon/combined.png"

# foreground.png - Checkmark only (432x432) with transparent background for Android adaptive icon
rsvg-convert -w 432 -h 432 "$PROJECT_DIR/assets/icon/combined.svg" -o "$PROJECT_DIR/assets/icon/foreground.png"

echo "  - created: assets/icon/combined.png (1024x1024)"
echo "  - created: assets/icon/foreground.png (432x432)"
echo ""

# Step 2: Regenerate all platform icons
echo "Step 2: Running flutter_launcher_icons..."
cd "$PROJECT_DIR"
flutter pub run flutter_launcher_icons
echo ""

# Step 3: Remove old splash/launch resources
echo "Step 3: Removing old splash/launch resources..."

# Remove old background.png and branding.png from all drawable folders
find "$PROJECT_DIR/android/app/src/main/res" -name "background.png" -delete 2>/dev/null || true
find "$PROJECT_DIR/android/app/src/main/res" -name "branding.png" -delete 2>/dev/null || true
find "$PROJECT_DIR/android/app/src/main/res" -name "splash.png" -delete 2>/dev/null || true

echo "  - removed old background.png, branding.png, splash.png"
echo ""

# Step 4: Clean build cache
echo "Step 4: Cleaning Flutter build cache..."
flutter clean
flutter pub get
echo ""

echo "=== Done! ==="
echo "Build your app with:"
echo "  flutter build apk"
echo ""
echo "For a complete build and install:"
echo "  flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols"
