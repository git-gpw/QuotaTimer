#!/usr/bin/env bash
set -euo pipefail

# Full release pipeline: build → bundle → sign → DMG
#
# Usage:
#   ./Scripts/release.sh                           # unsigned debug build
#   ./Scripts/release.sh --identity "Developer ID Application: ..."
#   ./Scripts/release.sh --identity "..." --notarize
#
# Sparkle appcast generation (run after uploading DMG to GitHub Releases):
#   generate_appcast build/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================="
echo "  QuotaTimer Release Build"
echo "========================================="
echo ""

# Step 1: Bundle (release mode)
"$SCRIPT_DIR/bundle.sh" --release

# Step 2: Sign
"$SCRIPT_DIR/sign.sh" "$@"

# Step 3: DMG
"$SCRIPT_DIR/package-dmg.sh"

echo ""
echo "========================================="
echo "  Release complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Upload build/QuotaTimer-*.dmg to GitHub Releases"
echo "  2. Run: generate_appcast build/"
echo "  3. Upload the appcast.xml to your release"
echo "  4. Update the Homebrew cask sha256"
