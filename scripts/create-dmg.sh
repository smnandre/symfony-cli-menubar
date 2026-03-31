#!/bin/bash
# =============================================================================
# create-dmg.sh — Create a signed DMG installer for SymfonyCLIMenuBar
# =============================================================================
#
# Called by:
#   - CI (.github/workflows/release.yml, "Create DMG" step) after package.sh
#     has produced SymfonyCLIMenuBar.app
#   - Developers locally to produce a distributable DMG: ./scripts/create-dmg.sh [version]
#
# What it does:
#   1. Reads the version from the argument or falls back to config/version.env
#   2. Creates a staging directory with the .app and an /Applications symlink
#   3. Builds a read-write HFS+ DMG, mounts it, and configures window layout
#      via AppleScript (icon positions, window bounds, icon size)
#   4. Converts to a compressed (UDZO) final DMG
#   The resulting DMG is then signed and notarized by the CI workflow.
#
# Usage:
#   ./scripts/create-dmg.sh [VERSION]
#
#   VERSION   Marketing version string (e.g. 1.2.0). Falls back to
#             MARKETING_VERSION from config/version.env if not provided.
#
# Output: SymfonyCLIMenuBar-<VERSION>.dmg in the current directory
# Prerequisites: SymfonyCLIMenuBar.app must already exist in the current directory
# =============================================================================

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    if [ -f "$ROOT/config/version.env" ]; then
        source "$ROOT/config/version.env"
        VERSION="$MARKETING_VERSION"
    else
        echo "Error: No version specified and config/version.env not found." >&2
        exit 1
    fi
fi
APP_NAME="SymfonyCLIMenuBar"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="${APP_NAME}-temp.dmg"
VOLUME_NAME="Symfony CLI MenuBar"
APP_BUNDLE="${APP_NAME}.app"

echo "📦 Creating DMG for ${APP_NAME} v${VERSION}..."

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ Error: $APP_BUNDLE not found. Run ./build.sh first."
    exit 1
fi

# Create a temporary directory for DMG contents
DMG_DIR=$(mktemp -d)
trap "rm -rf $DMG_DIR" EXIT

# Copy app to temp directory
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Calculate size needed (app size + 10MB buffer)
APP_SIZE=$(du -sm "$APP_BUNDLE" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20))

echo "📐 App size: ${APP_SIZE}MB, DMG size: ${DMG_SIZE}MB"

# Remove old DMG if exists
rm -f "$DMG_NAME" "$DMG_TEMP"

# Create temporary DMG
hdiutil create -srcfolder "$DMG_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "$DMG_TEMP"

# Mount the temporary DMG
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | \
    grep -E '^/dev/' | tail -1 | cut -f 3-)

echo "📂 Mounted at: $MOUNT_DIR"

# Set window properties using AppleScript
echo "🎨 Configuring DMG window..."
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 920, 430}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "$APP_BUNDLE" of container window to {130, 150}
        set position of item "Applications" of container window to {390, 150}
        update without registering applications
        close
    end tell
end tell
EOF

# Wait a bit for Finder to update
sleep 2

# Clean up filesystem artifacts created during the read-write mount
rm -rf "$MOUNT_DIR/.fseventsd" "$MOUNT_DIR/.Trashes" "$MOUNT_DIR/.background"
mkdir -p "$MOUNT_DIR/.fseventsd"
touch "$MOUNT_DIR/.fseventsd/no_log"
chflags hidden "$MOUNT_DIR/.fseventsd"

# Unmount
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
echo "🗜️ Compressing DMG..."
hdiutil convert "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_NAME"

# Clean up
rm -f "$DMG_TEMP"

# Verify
if [ -f "$DMG_NAME" ]; then
    DMG_FINAL_SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo ""
    echo "✅ Created: $DMG_NAME ($DMG_FINAL_SIZE)"
    echo ""
    echo "To test:"
    echo "  open $DMG_NAME"
else
    echo "❌ Failed to create DMG"
    exit 1
fi
