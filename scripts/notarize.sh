#!/bin/bash
#
# Notarize the app for distribution outside the App Store
#
# Prerequisites:
# 1. Apple Developer account
# 2. App-specific password stored in keychain:
#    xcrun notarytool store-credentials "AC_PASSWORD" \
#      --apple-id "your@email.com" \
#      --team-id "TEAMID" \
#      --password "app-specific-password"
#
# Usage: ./scripts/notarize.sh [path-to-dmg-or-zip]
#

set -e

ARTIFACT="$1"
KEYCHAIN_PROFILE="AC_PASSWORD"
BUNDLE_ID="com.simonandre.SymfonyCLIMenuBar"

if [ -z "$ARTIFACT" ]; then
    echo "Usage: $0 <path-to-dmg-or-zip>"
    echo ""
    echo "Prerequisites:"
    echo "  1. Store credentials in keychain:"
    echo "     xcrun notarytool store-credentials \"AC_PASSWORD\" \\"
    echo "       --apple-id \"your@email.com\" \\"
    echo "       --team-id \"TEAMID\" \\"
    echo "       --password \"app-specific-password\""
    echo ""
    echo "  2. Code sign the app before creating DMG:"
    echo "     codesign --force --deep --sign \"Developer ID Application: Your Name (TEAMID)\" SymfonyCLIMenuBar.app"
    exit 1
fi

if [ ! -f "$ARTIFACT" ]; then
    echo "❌ File not found: $ARTIFACT"
    exit 1
fi

echo "📤 Submitting for notarization: $ARTIFACT"

# Submit for notarization
xcrun notarytool submit "$ARTIFACT" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo ""
echo "✅ Notarization complete!"
echo ""

# If it's a DMG, staple the ticket
if [[ "$ARTIFACT" == *.dmg ]]; then
    echo "📎 Stapling ticket to DMG..."
    xcrun stapler staple "$ARTIFACT"
    echo "✅ Stapled successfully!"
fi

echo ""
echo "🎉 Ready for distribution!"
