#!/usr/bin/env bash
set -euo pipefail

# Sign and notarize QuotaTimer.app
#
# Prerequisites:
#   1. Apple Developer account with Developer ID Application certificate
#   2. App-specific password stored in Keychain:
#      xcrun notarytool store-credentials "QuotaTimer-Notarize" \
#        --apple-id "your@email.com" \
#        --team-id "YOURTEAMID" \
#        --password "app-specific-password"
#
# Usage:
#   ./Scripts/sign.sh                              # sign only (ad-hoc if no identity)
#   ./Scripts/sign.sh --identity "Developer ID Application: Your Name (TEAMID)"
#   ./Scripts/sign.sh --identity "..." --notarize  # sign + notarize
#
# Environment variables (alternative to flags):
#   SIGNING_IDENTITY  - codesign identity string
#   NOTARIZE_PROFILE  - notarytool keychain profile name (default: QuotaTimer-Notarize)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/build/QuotaTimer.app"
ENTITLEMENTS="$APP_DIR/Contents/entitlements.plist"

IDENTITY="${SIGNING_IDENTITY:-}"
NOTARIZE=false
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-QuotaTimer-Notarize}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --identity) IDENTITY="$2"; shift 2 ;;
        --notarize) NOTARIZE=true; shift ;;
        --profile) NOTARIZE_PROFILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ ! -d "$APP_DIR" ]]; then
    echo "ERROR: $APP_DIR not found. Run ./Scripts/bundle.sh first."
    exit 1
fi

echo "==> Signing QuotaTimer.app..."

if [[ -z "$IDENTITY" ]]; then
    echo "    No signing identity specified — using ad-hoc signing."
    echo "    For distribution, pass --identity \"Developer ID Application: ...\""
    codesign --force --deep --sign - \
        --entitlements "$ENTITLEMENTS" \
        "$APP_DIR"
else
    echo "    Identity: $IDENTITY"
    codesign --force --deep --sign "$IDENTITY" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        --timestamp \
        "$APP_DIR"
fi

echo "==> Verifying signature..."
codesign --verify --verbose=2 "$APP_DIR"
echo "    Signature OK"

if [[ "$NOTARIZE" == true ]]; then
    if [[ -z "$IDENTITY" || "$IDENTITY" == "-" ]]; then
        echo "ERROR: Notarization requires a Developer ID identity, not ad-hoc."
        exit 1
    fi

    echo "==> Creating ZIP for notarization..."
    ZIP_PATH="$PROJECT_DIR/build/QuotaTimer.zip"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

    echo "==> Submitting to Apple for notarization..."
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$APP_DIR"

    rm "$ZIP_PATH"
    echo "==> Notarization complete!"
fi

echo ""
echo "Done. App is at: $APP_DIR"
