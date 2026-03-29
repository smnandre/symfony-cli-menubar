#!/bin/bash
#
# Create a DMG installer for Symfony CLI Menu Bar
# Usage: ./scripts/create-dmg.sh [version]
#

set -e

VERSION="${1:-1.0.0}"
APP_NAME="SymfonyCLIMenuBar"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="${APP_NAME}-temp.dmg"
VOLUME_NAME="Symfony CLI Menu Bar"
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

# Create a background image directory (optional, for custom backgrounds)
mkdir -p "$DMG_DIR/.background"

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
    grep -E '^/dev/' | tail -1 | awk '{print $NF}')

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
        set bounds of container window to {400, 100, 900, 400}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "$APP_BUNDLE" of container window to {120, 140}
        set position of item "Applications" of container window to {380, 140}
        update without registering applications
        close
    end tell
end tell
EOF

# Wait a bit for Finder to update
sleep 2

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
