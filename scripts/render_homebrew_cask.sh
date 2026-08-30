#!/usr/bin/env bash

# Render the Homebrew cask for an existing signed and notarized release.

set -euo pipefail

VERSION="${1:?Usage: render_homebrew_cask.sh VERSION SHA256 OUTPUT}"
SHA256="${2:?Usage: render_homebrew_cask.sh VERSION SHA256 OUTPUT}"
OUTPUT="${3:?Usage: render_homebrew_cask.sh VERSION SHA256 OUTPUT}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: VERSION must be a stable semantic version" >&2
    exit 1
fi

if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: SHA256 must contain 64 lowercase hexadecimal characters" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

sed \
    -e "s/__VERSION__/$VERSION/" \
    -e "s/__SHA256__/$SHA256/" \
    "$(cd "$(dirname "$0")/.." && pwd)/config/homebrew-cask.rb.template" > "$OUTPUT"

echo "Rendered $OUTPUT"
