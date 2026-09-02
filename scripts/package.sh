#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="SymfonyCLIMenuBar"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
INFO_TEMPLATE="$ROOT_DIR/config/Info.plist"
VERSION_FILE="$ROOT_DIR/config/Version.plist"
CONFIGURATION=${1:-release}
SIGNING_MODE=${SIGNING_MODE:-adhoc}

case "$CONFIGURATION" in
    debug | release) ;;
    *)
        printf 'ERROR: Unsupported configuration: %s\n' "$CONFIGURATION" >&2
        exit 64
        ;;
esac

CONFIG_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :Version' "$VERSION_FILE")
VERSION=${VERSION:-$CONFIG_VERSION}
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :Build' "$VERSION_FILE")

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'ERROR: Version must use stable X.Y.Z format.\n' >&2
    exit 64
fi

if [[ "$VERSION" != "$CONFIG_VERSION" ]]; then
    printf 'ERROR: Requested version %s does not match configured version %s.\n' "$VERSION" "$CONFIG_VERSION" >&2
    exit 65
fi

BUILD_TIMESTAMP=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT=${GIT_COMMIT:-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')}
PRODUCT_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION"
BINARY="$PRODUCT_DIR/$APP_NAME"

swift build --package-path "$ROOT_DIR" --configuration "$CONFIGURATION" --arch arm64

if [[ ! -x "$BINARY" ]]; then
    printf 'ERROR: Missing executable: %s\n' "$BINARY" >&2
    exit 66
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
/usr/bin/ditto "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
/usr/bin/ditto "$ROOT_DIR/assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
/usr/bin/ditto "$ROOT_DIR/Sources/$APP_NAME/Resources" "$APP_BUNDLE/Contents/Resources"
/usr/bin/ditto "$INFO_TEMPLATE" "$APP_BUNDLE/Contents/Info.plist"

plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace BuildTimestamp -string "$BUILD_TIMESTAMP" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace GitCommit -string "$GIT_COMMIT" "$APP_BUNDLE/Contents/Info.plist"

chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
xattr -cr "$APP_BUNDLE"
find "$APP_BUNDLE" -name '._*' -delete

case "$SIGNING_MODE" in
    adhoc)
        SIGNING_ARGUMENTS=(--force --sign -)
        ;;
    release)
        : "${APP_IDENTITY:?APP_IDENTITY is required for release signing}"
        if [[ "$APP_IDENTITY" != "Developer ID Application:"* ]]; then
            printf 'ERROR: Release signing requires a Developer ID Application identity.\n' >&2
            exit 64
        fi
        SIGNING_ARGUMENTS=(--force --options runtime --timestamp --sign "$APP_IDENTITY")
        ;;
    *)
        printf 'ERROR: Unsupported signing mode: %s\n' "$SIGNING_MODE" >&2
        exit 64
        ;;
esac

codesign "${SIGNING_ARGUMENTS[@]}" --entitlements "$ROOT_DIR/config/entitlements.plist" "$APP_BUNDLE"
codesign --verify --deep --strict --all-architectures --verbose=2 "$APP_BUNDLE"

ARCHITECTURES=$(lipo -archs "$APP_BUNDLE/Contents/MacOS/$APP_NAME")
if [[ "$ARCHITECTURES" != "arm64" ]]; then
    printf 'ERROR: Expected arm64 executable, got: %s\n' "$ARCHITECTURES" >&2
    exit 65
fi

printf 'Built %s %s (%s), arm64.\n' "$APP_NAME" "$VERSION" "$BUILD"
