#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# embed_sparkle.sh — Embed and sign Sparkle framework into an .app bundle
# =============================================================================
#
# Called by:
#   - scripts/package.sh (never called directly by CI)
#
# What it does:
#   1. Locates Sparkle.xcframework from the SPM binary artifact cache
#      (.build/artifacts/sparkle/Sparkle/Sparkle.xcframework)
#      — requires `swift build` to have already run so SPM has resolved it
#   2. Copies Sparkle.framework into APP_BUNDLE/Contents/Frameworks/
#   3. Copies XPC services into APP_BUNDLE/Contents/XPCServices/
#   4. Code-signs all Sparkle components inside-out when an identity is given:
#        XPC services at the app level
#        → Updater.app inside the framework
#        → Autoupdate binary inside the framework
#        → XPC services inside the framework
#        → Sparkle.framework itself
#      This inside-out order is required by codesign — signing an outer bundle
#      before its inner components produces an invalid signature.
#
# Usage:
#   ./scripts/embed_sparkle.sh <APP_BUNDLE_PATH> [SIGNING_IDENTITY]
#
#   APP_BUNDLE_PATH   Path to the .app bundle (e.g. SymfonyCLIMenuBar.app)
#   SIGNING_IDENTITY  Optional codesign identity; if omitted, skips signing
# =============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="${1:?Usage: embed_sparkle.sh <APP_BUNDLE_PATH> [SIGNING_IDENTITY]}"
IDENTITY="${2:-}"

# SPM downloads Sparkle as a binary artifact; locate the macOS slice
XCFRAMEWORK="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework"
SPARKLE_FRAMEWORK="$XCFRAMEWORK/macos-arm64_x86_64/Sparkle.framework"

if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
    echo "ERROR: Sparkle.framework not found at $SPARKLE_FRAMEWORK" >&2
    echo "       Run 'swift build' first to fetch SPM dependencies." >&2
    exit 1
fi

# Embed framework
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
rm -rf "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"

# Embed XPC services (must also live at the app level)
XPC_SRC="$SPARKLE_FRAMEWORK/Versions/B/XPCServices"
if [[ -d "$XPC_SRC" ]]; then
    mkdir -p "$APP_BUNDLE/Contents/XPCServices"
    for xpc in "$XPC_SRC"/*.xpc; do
        [[ -e "$xpc" ]] || continue
        xpc_name="$(basename "$xpc")"
        rm -rf "$APP_BUNDLE/Contents/XPCServices/$xpc_name"
        cp -R "$xpc" "$APP_BUNDLE/Contents/XPCServices/"
    done
fi

# Code sign all Sparkle components (inside-out: XPC services first, then framework)
if [[ -n "$IDENTITY" ]]; then
    echo "Signing Sparkle components with: $IDENTITY"
    SIGN_ARGS=(--force --timestamp --options runtime --sign "$IDENTITY")

    # Sign inside-out: deepest nested code first, then the framework

    for xpc in "$APP_BUNDLE/Contents/XPCServices/"*.xpc; do
        [[ -e "$xpc" ]] || continue
        codesign "${SIGN_ARGS[@]}" "$xpc"
    done

    # Sign Updater.app inside the framework
    UPDATER_APP="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
    if [[ -d "$UPDATER_APP" ]]; then
        codesign "${SIGN_ARGS[@]}" "$UPDATER_APP"
    fi

    # Sign Autoupdate binary inside the framework
    AUTOUPDATE_BIN="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
    if [[ -f "$AUTOUPDATE_BIN" ]]; then
        codesign "${SIGN_ARGS[@]}" "$AUTOUPDATE_BIN"
    fi

    # Sign XPC services inside the framework itself
    FW_XPC_DIR="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices"
    if [[ -d "$FW_XPC_DIR" ]]; then
        for xpc in "$FW_XPC_DIR"/*.xpc; do
            [[ -e "$xpc" ]] || continue
            codesign "${SIGN_ARGS[@]}" "$xpc"
        done
    fi

    codesign "${SIGN_ARGS[@]}" \
        "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
fi

echo "Sparkle embedded into $(basename "$APP_BUNDLE")"
