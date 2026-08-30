#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# package.sh - Build, bundle, and sign the SymfonyCLIMenuBar application
# =============================================================================
#
# Called by:
#   - CI (.github/workflows/release.yml, "Build and package" step) on every
#     tag push, with SIGNING_MODE=developer and VERSION set from the git tag.
#   - Developers locally for test builds: VERSION=0.0.0 ./scripts/package.sh [release|debug]
#
# What it does:
#   1. Validates the VERSION supplied by the caller
#   2. Compiles the Swift target for each architecture (arm64, x86_64, or host)
#   3. Lipo-merges multi-arch binaries into a universal binary if needed
#   4. Assembles the .app bundle (binary, Info.plist, PkgInfo, resources, icon)
#   5. Code-signs the bundle (ad-hoc locally, Developer ID in CI)
#
# Environment variables:
#   VERSION         Required stable version (e.g. 1.2.0)
#   SIGNING_MODE    "developer" or "adhoc" (default: developer)
#   APP_IDENTITY    Signing identity string from Keychain
#   ARCHES          Space-separated list of target architectures (default: host arch)
#
# Output: SymfonyCLIMenuBar.app in the repository root
# =============================================================================

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# --- App Configuration ---
APP_NAME="SymfonyCLIMenuBar"
APP_DISPLAY_NAME="Symfony CLI MenuBar"
BUNDLE_ID="dev.smnandre.symfony-cli-menubar"
MACOS_MIN_VERSION="14.0"
MENU_BAR_APP="1" # Set to 1 for menu bar apps to set LSUIElement=true

# --- Signing Configuration ---
# By default, uses the maintainer's Developer ID identity for stable local
# permissions. Contributors without that identity can set SIGNING_MODE=adhoc.
# You can find your identity with: security find-identity -v -p codesigning
SIGNING_MODE=${SIGNING_MODE:-"developer"} # "adhoc" or "developer"
APP_IDENTITY=${APP_IDENTITY:-"Developer ID Application: Simon André (3D8DYUPC57)"}

if [[ -z "${VERSION:-}" ]]; then
  echo "ERROR: VERSION is required (for example, VERSION=1.0.0)" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: VERSION must be a stable X.Y.Z version" >&2
  exit 1
fi

echo "Building $APP_NAME v$VERSION for $CONF..."

# --- Build ---
ARCH_LIST=()
if [[ -n "${ARCHES:-}" ]]; then
  read -r -a ARCH_LIST <<< "$ARCHES"
fi
if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  HOST_ARCH=$(uname -m)
  ARCH_LIST=("$HOST_ARCH")
fi

for ARCH in "${ARCH_LIST[@]}"; do
  echo "Building for arch: $ARCH..."
  swift build -c "$CONF" --arch "$ARCH"
done

# --- Packaging ---
APP_BUNDLE="$ROOT/${APP_NAME}.app"
echo "Packaging into $APP_BUNDLE..."

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

# --- Info.plist ---
LSUI_VALUE="false"
if [[ "$MENU_BAR_APP" == "1" ]]; then
  LSUI_VALUE="true"
fi

BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
COPYRIGHT_NOTICE="Copyright © $(date +'%Y') Simon André. All rights reserved."

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSUIElement</key><${LSUI_VALUE}/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>${COPYRIGHT_NOTICE}</string>
    <key>NSAppleEventsUsageDescription</key><string>Symfony CLI MenuBar needs permission to open Terminal for viewing logs and running commands.</string>
    <key>BuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# --- Install Binaries ---
build_product_path() {
  local name="$1"
  local arch="$2"
  case "$arch" in
    arm64|x86_64) echo ".build/${arch}-apple-macosx/$CONF/$name" ;; 
    *) echo ".build/$CONF/$name" ;; 
  esac
}

install_binary() {
  local name="$1"
  local dest="$2"
  local binaries=()
  for arch in "${ARCH_LIST[@]}"; do
    local src
    src=$(build_product_path "$name" "$arch")
    if [[ ! -f "$src" ]]; then
      echo "ERROR: Missing ${name} build for ${arch} at ${src}" >&2
      exit 1
    fi
    binaries+=("$src")
  done
  if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
    lipo -create "${binaries[@]}" -output "$dest"
  else
    cp "${binaries[0]}" "$dest"
  fi
  chmod +x "$dest"
}

install_binary "$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# --- Copy Resources ---
# Copy main app icon
if [ -f "assets/AppIcon.icns" ]; then
    cp assets/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
    echo "App icon installed"
fi

# Bundle app resources from Sources directory (if any)
APP_RESOURCES_DIR="$ROOT/Sources/$APP_NAME/Resources"
if [[ -d "$APP_RESOURCES_DIR" ]]; then
  cp -R "$APP_RESOURCES_DIR/." "$APP_BUNDLE/Contents/Resources/"
fi

# --- Code Signing ---
echo "Signing application..."

ENTITLEMENTS_PATH="$ROOT/config/entitlements.plist"
if [[ ! -f "$ENTITLEMENTS_PATH" ]]; then
  echo "ERROR: Entitlements file not found at $ENTITLEMENTS_PATH" >&2
  exit 1
fi

case "$SIGNING_MODE" in
  adhoc)
    CODESIGN_ARGS=(--force --sign "-")
    echo "Using ad hoc signing. App will not be notarized."
    ;;
  developer)
    if [[ -z "$APP_IDENTITY" ]]; then
      echo "ERROR: APP_IDENTITY is required for developer signing" >&2
      exit 1
    fi
    CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
    echo "Using developer identity: $APP_IDENTITY"
    ;;
  *)
    echo "ERROR: SIGNING_MODE must be 'adhoc' or 'developer'" >&2
    exit 1
    ;;
esac

# Strip extended attributes before signing
xattr -cr "$APP_BUNDLE"

# Sign the final bundle once so its executable, metadata, and entitlements share
# one sealed code requirement.
echo "Signing bundle..."
codesign "${CODESIGN_ARGS[@]}" \
  --entitlements "$ENTITLEMENTS_PATH" \
  "$APP_BUNDLE"

echo "Packaging complete: $APP_BUNDLE"
