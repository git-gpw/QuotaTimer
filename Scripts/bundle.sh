#!/usr/bin/env bash
set -euo pipefail

# Build a proper .app bundle from the SPM executable.
# Usage: ./Scripts/bundle.sh [--release]
#
# Output: build/QuotaTimer.app

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

BUILD_CONFIG="debug"
SWIFT_FLAGS=""
if [[ "${1:-}" == "--release" ]]; then
    BUILD_CONFIG="release"
    SWIFT_FLAGS="-c release"
fi

BUNDLE_ID="com.gpw.QuotaTimer"
VERSION="0.1.0"
BUILD_NUMBER="1"

echo "==> Building QuotaTimer ($BUILD_CONFIG)..."
cd "$PROJECT_DIR"
swift build --product QuotaTimer $SWIFT_FLAGS

# Locate the built executable
BIN_PATH=".build/arm64-apple-macosx/$BUILD_CONFIG/QuotaTimer"
if [[ ! -f "$BIN_PATH" ]]; then
    BIN_PATH=$(swift build --product QuotaTimer $SWIFT_FLAGS --show-bin-path)/QuotaTimer
fi

if [[ ! -f "$BIN_PATH" ]]; then
    echo "ERROR: Cannot find built QuotaTimer executable"
    exit 1
fi

echo "==> Assembling .app bundle..."
APP_DIR="build/QuotaTimer.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy executable
cp "$BIN_PATH" "$MACOS/QuotaTimer"

# Write Info.plist (concrete values, no Xcode variables)
cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>QuotaTimer</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>QuotaTimer</string>
    <key>CFBundleDisplayName</key>
    <string>QuotaTimer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Gabriel Wood. All rights reserved.</string>
    <key>SUFeedURL</key>
    <string>https://github.com/gabriel-p-wood/QuotaTimer/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string></string>
</dict>
</plist>
PLIST

# Write entitlements
cat > "$CONTENTS/entitlements.plist" << 'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

# PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Embed Sparkle.framework
SPARKLE_SRC="$PROJECT_DIR/Frameworks/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ -d "$SPARKLE_SRC" ]]; then
    echo "==> Embedding Sparkle.framework..."
    FRAMEWORKS_DIR="$CONTENTS/Frameworks"
    mkdir -p "$FRAMEWORKS_DIR"
    ditto "$SPARKLE_SRC" "$FRAMEWORKS_DIR/Sparkle.framework"
    # Fix rpath so the executable finds the embedded framework
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/QuotaTimer" 2>/dev/null || true
else
    echo "WARNING: Sparkle.framework not found at $SPARKLE_SRC — update checking will not work"
fi

# Ad-hoc sign so macOS will run the bundle
echo "==> Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Bundle created: $APP_DIR"
echo "    Version: $VERSION ($BUILD_NUMBER)"
echo "    Bundle ID: $BUNDLE_ID"
echo ""
echo "To run:  open build/QuotaTimer.app"
echo "To sign for distribution: ./Scripts/sign.sh --identity \"Developer ID Application: ...\""
