#!/bin/bash
# Icon generation script for SymfonyCLIMenuBar
# Run this on macOS with librsvg or Inkscape installed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR"
ICONSET_DIR="$ASSETS_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

SVG="$ASSETS_DIR/icon.svg"

# Check for rsvg-convert or Inkscape
if command -v rsvg-convert &> /dev/null; then
    CONVERTER="rsvg"
elif command -v inkscape &> /dev/null; then
    CONVERTER="inkscape"
elif command -v sips &> /dev/null; then
    echo "Note: sips can only resize, not convert SVG. Using alternate method..."
    CONVERTER="sips"
else
    echo "Error: No suitable converter found. Install librsvg or inkscape."
    exit 1
fi

convert_svg() {
    local size=$1
    local output=$2

    if [ "$CONVERTER" = "rsvg" ]; then
        rsvg-convert -w $size -h $size "$SVG" -o "$output"
    elif [ "$CONVERTER" = "inkscape" ]; then
        inkscape -w $size -h $size "$SVG" -o "$output" 2>/dev/null
    fi
}

echo "Generating icon sizes..."

convert_svg 16 "$ICONSET_DIR/icon_16x16.png"
convert_svg 32 "$ICONSET_DIR/icon_16x16@2x.png"
convert_svg 32 "$ICONSET_DIR/icon_32x32.png"
convert_svg 64 "$ICONSET_DIR/icon_32x32@2x.png"
convert_svg 128 "$ICONSET_DIR/icon_128x128.png"
convert_svg 256 "$ICONSET_DIR/icon_128x128@2x.png"
convert_svg 256 "$ICONSET_DIR/icon_256x256.png"
convert_svg 512 "$ICONSET_DIR/icon_256x256@2x.png"
convert_svg 512 "$ICONSET_DIR/icon_512x512.png"
convert_svg 1024 "$ICONSET_DIR/icon_512x512@2x.png"

echo "Creating .icns file..."
iconutil -c icns "$ICONSET_DIR" -o "$ASSETS_DIR/AppIcon.icns"

if [ -f "$ASSETS_DIR/AppIcon.icns" ]; then
    echo "✓ Created AppIcon.icns successfully!"
    echo "  Copy it to your app bundle:"
    echo "  cp assets/AppIcon.icns SymfonyCLIMenuBar.app/Contents/Resources/"
else
    echo "✗ Failed to create .icns file"
fi
