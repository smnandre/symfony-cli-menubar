#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# update_appcast.sh — Prepend a new release entry into docs/appcast.xml
# =============================================================================
#
# Called by:
#   - CI (.github/workflows/release.yml, "Update appcast" step) after the ZIP
#     has been signed with sign_update and the EdDSA signature is available.
#   - Can be run locally if manually re-generating the appcast entry.
#
# What it does:
#   1. Reads the ZIP file size for the <enclosure length="..."> attribute
#   2. Computes the current UTC date for <pubDate>
#   3. Constructs a full Sparkle <item> XML block with version, download URL,
#      EdDSA signature, file size, and minimum system version
#   4. Inserts the new <item> block immediately before </channel> in appcast.xml
#      (so newest releases appear first in the feed)
#
# Usage:
#   ./scripts/update_appcast.sh <VERSION> <EDDSA_SIGNATURE> <ZIP_FILE>
#
#   VERSION          Marketing version (e.g. 1.2.0)
#   EDDSA_SIGNATURE  Output of: sign_update --ed-key-file <key> -p <zip>
#   ZIP_FILE         Path to the release ZIP (used for file size)
#
# Output: docs/appcast.xml updated in-place
# =============================================================================

VERSION="${1:?Missing VERSION}"
SIGNATURE="${2:?Missing EDDSA_SIGNATURE}"
ZIP_FILE="${3:?Missing ZIP_FILE}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPCAST="$ROOT/docs/appcast.xml"
VERSION_ENV="$ROOT/config/version.env"

# Load build number
BUILD_NUMBER=1
if [[ -f "$VERSION_ENV" ]]; then
    source "$VERSION_ENV"
fi

if [[ ! -f "$ZIP_FILE" ]]; then
    echo "ERROR: ZIP not found: $ZIP_FILE" >&2
    exit 1
fi

FILESIZE=$(wc -c < "$ZIP_FILE" | tr -d ' ')
PUBDATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
GITHUB_REPO="smnandre/symfony-cli-menubar"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/SymfonyCLIMenuBar-${VERSION}.zip"

NEW_ITEM=$(cat <<XML
        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${PUBDATE}</pubDate>
            <enclosure
                url="${DOWNLOAD_URL}"
                sparkle:version="${BUILD_NUMBER}"
                sparkle:shortVersionString="${VERSION}"
                sparkle:edSignature="${SIGNATURE}"
                length="${FILESIZE}"
                type="application/octet-stream" />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
XML
)

# Insert new item before </channel>
ITEM_FILE=$(mktemp)
TMP=$(mktemp)
printf '%s\n' "$NEW_ITEM" > "$ITEM_FILE"

LINE=$(grep -n '</channel>' "$APPCAST" | head -1 | cut -d: -f1)
head -n $((LINE - 1)) "$APPCAST" > "$TMP"
cat "$ITEM_FILE" >> "$TMP"
tail -n +"$LINE" "$APPCAST" >> "$TMP"

mv "$TMP" "$APPCAST"
rm -f "$ITEM_FILE"

echo "Appcast updated: v${VERSION} (build ${BUILD_NUMBER})"
