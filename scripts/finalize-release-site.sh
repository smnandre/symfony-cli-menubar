#!/usr/bin/env bash
set -euo pipefail

# Update the public website only after the release artifact and Homebrew cask
# are both publicly available.

VERSION="${1:?Usage: finalize-release-site.sh VERSION}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: VERSION must be a stable X.Y.Z version" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_INDEX="$ROOT/docs/web/index.html"
CASK_URL="https://raw.githubusercontent.com/smnandre/homebrew-tap/main/Casks/symfony-cli-menubar.rb"
DMG_URL="https://github.com/smnandre/symfony-cli-menubar/releases/download/v${VERSION}/SymfonyCLIMenuBar-${VERSION}.dmg"

CASK=$(curl --fail --silent --show-error --location "$CASK_URL")
if ! grep -Eq "^[[:space:]]*version \"${VERSION}\"[[:space:]]*$" <<< "$CASK"; then
    echo "ERROR: Homebrew cask v${VERSION} is not published on smnandre/tap" >&2
    exit 1
fi

if ! curl --fail --silent --show-error --location --head "$DMG_URL" > /dev/null; then
    echo "ERROR: GitHub release artifact v${VERSION} is not publicly available" >&2
    exit 1
fi

sed -i '' "s/\"softwareVersion\": \"[^\"]*\"/\"softwareVersion\": \"${VERSION}\"/" "$WEB_INDEX"
sed -i '' "s|\"downloadUrl\": \"[^\"]*\"|\"downloadUrl\": \"${DMG_URL}\"|" "$WEB_INDEX"
sed -i '' "s|<strong>v[^<]*</strong>|<strong>v${VERSION}</strong>|" "$WEB_INDEX"
sed -i '' '/btn--primary/s|href="[^"]*"|href="https://github.com/smnandre/symfony-cli-menubar#installation"|' "$WEB_INDEX"
sed -i '' '/btn--primary/s|title="[^"]*"|title="Install Symfony CLI Menu Bar with Homebrew"|' "$WEB_INDEX"
sed -i '' 's/>Download for macOS</>Install with Homebrew</' "$WEB_INDEX"
sed -i '' 's/>macOS 14+</>Apple Silicon - macOS 14+</' "$WEB_INDEX"

echo "Updated docs/web/index.html for v${VERSION}"
