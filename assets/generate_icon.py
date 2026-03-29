#!/usr/bin/env python3
"""
Generate app icon for SymfonyCLIMenuBar
Creates an .icns file with the Symfony-inspired logo
"""

import subprocess
import os
from pathlib import Path

def create_svg_icon():
    """Create an SVG icon inspired by Symfony's visual identity"""
    svg = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1a2e"/>
      <stop offset="100%" style="stop-color:#16213e"/>
    </linearGradient>
    <linearGradient id="accentGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#00d4aa"/>
      <stop offset="100%" style="stop-color:#00b894"/>
    </linearGradient>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="8" result="coloredBlur"/>
      <feMerge>
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <!-- Background rounded square -->
  <rect x="64" y="64" width="896" height="896" rx="180" ry="180" fill="url(#bgGrad)"/>

  <!-- Subtle border -->
  <rect x="64" y="64" width="896" height="896" rx="180" ry="180"
        fill="none" stroke="#2d3748" stroke-width="3"/>

  <!-- Server stack representation -->
  <!-- Bottom server -->
  <rect x="232" y="620" width="560" height="120" rx="20" ry="20"
        fill="#2d3748" stroke="#4a5568" stroke-width="2"/>
  <circle cx="312" cy="680" r="20" fill="#00d4aa" filter="url(#glow)"/>
  <rect x="360" y="660" width="180" height="12" rx="6" fill="#4a5568"/>
  <rect x="360" y="688" width="120" height="12" rx="6" fill="#4a5568"/>

  <!-- Middle server -->
  <rect x="232" y="460" width="560" height="120" rx="20" ry="20"
        fill="#2d3748" stroke="#4a5568" stroke-width="2"/>
  <circle cx="312" cy="520" r="20" fill="#00d4aa" filter="url(#glow)"/>
  <rect x="360" y="500" width="180" height="12" rx="6" fill="#4a5568"/>
  <rect x="360" y="528" width="140" height="12" rx="6" fill="#4a5568"/>

  <!-- Top server (active/highlighted) -->
  <rect x="232" y="300" width="560" height="120" rx="20" ry="20"
        fill="#374151" stroke="url(#accentGrad)" stroke-width="3"/>
  <circle cx="312" cy="360" r="20" fill="#00d4aa" filter="url(#glow)"/>
  <rect x="360" y="340" width="200" height="12" rx="6" fill="#00d4aa"/>
  <rect x="360" y="368" width="160" height="12" rx="6" fill="#4a5568"/>

  <!-- Symfony-inspired 'S' curve accent -->
  <path d="M680 320 Q740 360 700 400 Q660 440 720 480 Q780 520 740 560 Q700 600 760 640"
        fill="none" stroke="url(#accentGrad)" stroke-width="8" stroke-linecap="round"
        opacity="0.8"/>

  <!-- Connection dots -->
  <circle cx="720" cy="320" r="8" fill="#00d4aa"/>
  <circle cx="720" cy="480" r="8" fill="#00d4aa"/>
  <circle cx="720" cy="640" r="8" fill="#00d4aa"/>
</svg>'''
    return svg

def create_iconset(output_dir):
    """Create iconset with all required sizes"""
    iconset_dir = output_dir / "AppIcon.iconset"
    iconset_dir.mkdir(exist_ok=True)

    # Required icon sizes for macOS
    sizes = [
        (16, "16x16"),
        (32, "16x16@2x"),
        (32, "32x32"),
        (64, "32x32@2x"),
        (128, "128x128"),
        (256, "128x128@2x"),
        (256, "256x256"),
        (512, "256x256@2x"),
        (512, "512x512"),
        (1024, "512x512@2x"),
    ]

    # Save SVG
    svg_path = output_dir / "icon.svg"
    svg_path.write_text(create_svg_icon())

    print(f"Created SVG at {svg_path}")
    print("To complete the icon generation, run these commands on macOS:")
    print()
    print("# Install rsvg-convert if needed:")
    print("# brew install librsvg")
    print()
    print("# Or use Inkscape:")
    print("# brew install inkscape")
    print()

    # Generate shell commands for icon creation
    script_content = '''#!/bin/bash
# Icon generation script for SymfonyCLIMenuBar
# Run this on macOS with librsvg or Inkscape installed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICONSET_DIR="$SCRIPT_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

SVG="$SCRIPT_DIR/icon.svg"

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
iconutil -c icns "$ICONSET_DIR" -o "$SCRIPT_DIR/AppIcon.icns"

if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    echo "✓ Created AppIcon.icns successfully!"
    echo "  Copy it to your app bundle:"
    echo "  cp AppIcon.icns SymfonyCLIMenuBar.app/Contents/Resources/"
else
    echo "✗ Failed to create .icns file"
fi
'''

    script_path = output_dir / "generate_icns.sh"
    script_path.write_text(script_content)
    os.chmod(script_path, 0o755)

    print(f"Created generation script at {script_path}")
    print()
    print("Run: ./generate_icns.sh")

if __name__ == "__main__":
    output_dir = Path(__file__).parent
    create_iconset(output_dir)
    print("\n✓ Icon files created!")
