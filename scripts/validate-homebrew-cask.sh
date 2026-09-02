#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :Version' "$ROOT_DIR/config/Version.plist")
CASK_PATH="$ROOT_DIR/Casks/symfony-cli-menubar.rb"

cleanup() {
    rm -f "$CASK_PATH"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/render_homebrew_cask.sh" \
    "$VERSION" \
    "0000000000000000000000000000000000000000000000000000000000000000" \
    "$CASK_PATH"

brew style "$CASK_PATH"
