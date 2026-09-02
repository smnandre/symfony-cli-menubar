#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${1:?Usage: create-dmg.sh VERSION}
APP_NAME="SymfonyCLIMenuBar"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'ERROR: Version must use stable X.Y.Z format.\n' >&2
    exit 64
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
    printf 'ERROR: Missing app bundle: %s\n' "$APP_BUNDLE" >&2
    exit 66
fi

APP_VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$APP_BUNDLE/Contents/Info.plist")
if [[ "$APP_VERSION" != "$VERSION" ]]; then
    printf 'ERROR: DMG version %s does not match app version %s.\n' "$VERSION" "$APP_VERSION" >&2
    exit 65
fi

STAGING_DIRECTORY=$(mktemp -d -t symfony-cli-menubar-dmg)
trap 'rm -rf "$STAGING_DIRECTORY"' EXIT

/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIRECTORY/$APP_NAME.app"
ln -s /Applications "$STAGING_DIRECTORY/Applications"
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "Symfony CLI MenuBar" \
    -srcfolder "$STAGING_DIRECTORY" \
    -format UDZO \
    "$DMG_PATH"
hdiutil verify "$DMG_PATH"

printf '%s\n' "$DMG_PATH"
