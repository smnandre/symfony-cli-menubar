#!/usr/bin/env bash
set -euo pipefail

# Embeds Sparkle framework and XPC services into an .app bundle.
# Uses the Sparkle binary already downloaded by `swift build` via SPM —
# no separate download required.
#
# Usage: ./scripts/embed_sparkle.sh <APP_BUNDLE> [SIGNING_IDENTITY]

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

    for xpc in "$APP_BUNDLE/Contents/XPCServices/"*.xpc; do
        [[ -e "$xpc" ]] || continue
        codesign "${SIGN_ARGS[@]}" "$xpc"
    done

    codesign "${SIGN_ARGS[@]}" \
        "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
fi

echo "Sparkle embedded into $(basename "$APP_BUNDLE")"
