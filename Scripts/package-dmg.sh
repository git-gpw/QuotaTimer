#!/usr/bin/env bash
set -euo pipefail

# Create a DMG from the signed QuotaTimer.app
#
# Usage: ./Scripts/package-dmg.sh
# Output: build/QuotaTimer-{version}.dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/build/QuotaTimer.app"

if [[ ! -d "$APP_DIR" ]]; then
    echo "ERROR: $APP_DIR not found. Run ./Scripts/bundle.sh first."
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist")
DMG_NAME="QuotaTimer-${VERSION}.dmg"
DMG_PATH="$PROJECT_DIR/build/$DMG_NAME"
STAGING="$PROJECT_DIR/build/dmg-staging"

echo "==> Creating DMG: $DMG_NAME"

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"

# Create a symlink to /Applications for drag-install
ln -s /Applications "$STAGING/Applications"

# Create DMG
hdiutil create -volname "QuotaTimer" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo "==> DMG created: $DMG_PATH"
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"
