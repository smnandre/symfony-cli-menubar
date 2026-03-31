#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# bump-version.sh — Optional local tool to preview version bump changes
# =============================================================================
#
# Called by:
#   - Developers manually, before pushing a release tag, to preview and
#     commit the file changes that CI will otherwise apply automatically.
#   - NOT called by CI. CI performs the same updates inline in release.yml
#     on tag push, so running this script before tagging is never required.
#
# What it does:
#   1. Validates the version argument (must be X.Y.Z semver)
#   2. Writes MARKETING_VERSION and BUILD_NUMBER to config/version.env
#   3. Promotes [Unreleased] → [VERSION] - DATE in CHANGELOG.md (awk, portable)
#   4. Updates softwareVersion, downloadUrl, version badge, and download
#      button href in docs/web/index.html
#
# Usage:
#   ./scripts/bump-version.sh <VERSION> [BUILD_NUMBER]
#
#   VERSION       New marketing version in X.Y.Z format (e.g. 1.2.0)
#   BUILD_NUMBER  Optional build number (default: 1)
#
# After running, review the diff, fill in release notes under the new
# [VERSION] section in CHANGELOG.md, commit, then push the tag:
#   git tag v<VERSION> && git push origin v<VERSION>
# =============================================================================
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Argument validation ---
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version> [build-number]"
  echo "  Example: $0 0.11.0"
  echo "  Example: $0 0.11.0 2"
  exit 1
fi

NEW_VERSION="$1"
NEW_BUILD="${2:-1}"

# Validate semver format (X.Y.Z)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must be in X.Y.Z format (got: '$NEW_VERSION')"
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
REPO="smnandre/symfony-cli-menubar"
DMG_URL="https://github.com/${REPO}/releases/download/v${NEW_VERSION}/SymfonyCLIMenuBar-${NEW_VERSION}.dmg"

echo "Bumping to v${NEW_VERSION} (build ${NEW_BUILD})..."

# --- 1. config/version.env ---
VERSION_ENV="$ROOT/config/version.env"
cat > "$VERSION_ENV" <<EOF
MARKETING_VERSION=${NEW_VERSION}
BUILD_NUMBER=${NEW_BUILD}
EOF
echo "  ✓ config/version.env"

# --- 2. CHANGELOG.md ---
CHANGELOG="$ROOT/CHANGELOG.md"
if [[ -f "$CHANGELOG" ]]; then
  # Insert a dated version header right after [Unreleased]
  if grep -q "## \[Unreleased\]" "$CHANGELOG"; then
    awk -v ver="${NEW_VERSION}" -v date="${TODAY}" '
      /^## \[Unreleased\]$/ && !done { print; print ""; print "## [" ver "] - " date; done=1; next }
      { print }
    ' "$CHANGELOG" > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"
    echo "  ✓ CHANGELOG.md  ([${NEW_VERSION}] - ${TODAY} section added)"
  else
    echo "  ⚠  CHANGELOG.md: no [Unreleased] section found — update manually"
  fi
fi

# --- 3. docs/web/index.html ---
WEB_INDEX="$ROOT/docs/web/index.html"
if [[ -f "$WEB_INDEX" ]]; then
  sed -i '' "s/\"softwareVersion\": \"[^\"]*\"/\"softwareVersion\": \"${NEW_VERSION}\"/" "$WEB_INDEX"
  sed -i '' "s|\"downloadUrl\": \"[^\"]*\"|\"downloadUrl\": \"${DMG_URL}\"|" "$WEB_INDEX"
  sed -i '' "s|<strong>v[^<]*</strong>|<strong>v${NEW_VERSION}</strong>|" "$WEB_INDEX"
  sed -i '' '/btn--primary/s|href="[^"]*"|href="'"${DMG_URL}"'"|' "$WEB_INDEX"
  echo "  ✓ docs/web/index.html"
fi

echo ""
echo "Done. Next steps:"
echo "  1. Fill in release notes under [${NEW_VERSION}] in CHANGELOG.md"
echo "  2. git add config/version.env CHANGELOG.md docs/web/index.html"
echo "  3. git commit -m 'chore: bump to v${NEW_VERSION}'"
echo "  4. Push tag to release: git tag v${NEW_VERSION} && git push origin v${NEW_VERSION}"
echo ""
echo "  Note: CI will also sync these files automatically on tag push."
echo "        This script is only needed if you want to preview changes locally first."
