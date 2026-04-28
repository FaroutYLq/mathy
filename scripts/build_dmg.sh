#!/bin/bash
set -euo pipefail

# Build Mathy.app and package it into a DMG for distribution.
# Usage: ./scripts/build_dmg.sh [version]
# Output: build/Mathy.dmg

VERSION="${1:-0.0.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
XCODE_PROJECT="$PROJECT_ROOT/Mathy/Mathy.xcodeproj"
ARCHIVE_PATH="$BUILD_DIR/Mathy.xcarchive"
APP_NAME="Mathy.app"
DMG_NAME="Mathy.dmg"

echo "==> Building Mathy v${VERSION}"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Regenerate Xcode project if xcodegen is available
if command -v xcodegen &>/dev/null; then
    echo "==> Regenerating Xcode project with xcodegen..."
    (cd "$PROJECT_ROOT/Mathy" && xcodegen generate)
fi

# Archive
echo "==> Archiving..."
xcodebuild archive \
    -project "$XCODE_PROJECT" \
    -scheme Mathy \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$VERSION" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    | tail -1

# Extract .app from archive
APP_SRC="$ARCHIVE_PATH/Products/Applications/$APP_NAME"
APP_DST="$BUILD_DIR/$APP_NAME"

if [ ! -d "$APP_SRC" ]; then
    echo "Error: Archive did not produce $APP_NAME"
    echo "Archive contents:"
    find "$ARCHIVE_PATH" -name "*.app" 2>/dev/null || true
    exit 1
fi

cp -R "$APP_SRC" "$APP_DST"

# Ad-hoc code sign
echo "==> Code signing..."
codesign --force --deep --sign - "$APP_DST"

# Verify bundled resources
echo "==> Verifying bundled resources..."
RESOURCES_DIR="$APP_DST/Contents/Resources"
MISSING=0
for resource in mathy_server.py requirements.txt latex_preview.html; do
    if [ ! -f "$RESOURCES_DIR/$resource" ]; then
        echo "  MISSING: $resource"
        MISSING=1
    else
        echo "  OK: $resource"
    fi
done
if [ ! -d "$RESOURCES_DIR/katex" ]; then
    echo "  MISSING: katex/"
    MISSING=1
else
    echo "  OK: katex/"
fi
if [ "$MISSING" -eq 1 ]; then
    echo "Error: Some resources are missing from the bundle."
    exit 1
fi

# Create DMG
echo "==> Creating DMG..."
DMG_STAGING="$BUILD_DIR/dmg_staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DST" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "Mathy" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

# Cleanup
rm -rf "$DMG_STAGING" "$ARCHIVE_PATH"

DMG_SIZE=$(du -h "$BUILD_DIR/$DMG_NAME" | cut -f1)
echo ""
echo "==> Done! Output: build/$DMG_NAME ($DMG_SIZE)"
echo "    To install: open the DMG and drag Mathy to Applications."
echo "    First launch: right-click > Open (to bypass Gatekeeper)."
