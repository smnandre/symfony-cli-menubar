#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# bump-version.sh - Optional local tool to preview version bump changes
# =============================================================================
#
# Called by:
#   - Developers manually before pushing a release tag.
#   - NOT called by CI. The prepared changelog must be committed before the tag.
#
# What it does:
#   1. Validates the version argument (must be X.Y.Z semver)
#   2. Promotes [Unreleased] to [VERSION] - DATE in CHANGELOG.md
#
# Usage:
#   ./scripts/bump-version.sh VERSION
#
#   VERSION   New stable version in X.Y.Z format (e.g. 1.2.0)
#
# After running, review the diff, fill in release notes under the new
# [VERSION] section in CHANGELOG.md, commit, then push the tag:
#   git tag v<VERSION> && git push origin v<VERSION>
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Argument validation ---
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 VERSION"
  echo "  Example: $0 1.0.0"
  exit 1
fi

NEW_VERSION="$1"

# Validate semver format (X.Y.Z)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must be in X.Y.Z format (got: '$NEW_VERSION')"
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
echo "Preparing changelog for v${NEW_VERSION}..."

/usr/libexec/PlistBuddy -c "Set :Version ${NEW_VERSION}" "$ROOT/config/Version.plist"

# --- CHANGELOG.md ---
CHANGELOG="$ROOT/CHANGELOG.md"
if [[ -f "$CHANGELOG" ]]; then
  # Insert a dated version header right after [Unreleased]
  if grep -q "^## \[${NEW_VERSION}\]" "$CHANGELOG"; then
    echo "  CHANGELOG.md already contains [${NEW_VERSION}]"
  elif grep -q "## \[Unreleased\]" "$CHANGELOG"; then
    awk -v ver="${NEW_VERSION}" -v date="${TODAY}" '
      /^## \[Unreleased\]$/ && !done { print; print ""; print "## [" ver "] - " date; done=1; next }
      { print }
    ' "$CHANGELOG" > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"
    echo "  Updated CHANGELOG.md ([${NEW_VERSION}] - ${TODAY} section added)"
  else
    echo "  WARNING: CHANGELOG.md has no [Unreleased] section; update it manually"
  fi
fi

echo ""
echo "Done. Next steps:"
echo "  1. Fill in release notes under [${NEW_VERSION}] in CHANGELOG.md"
echo "  2. git add CHANGELOG.md config/Version.plist"
echo "  3. git commit -m 'chore: bump to v${NEW_VERSION}'"
echo "  4. Push tag to release: git tag v${NEW_VERSION} && git push origin v${NEW_VERSION}"
