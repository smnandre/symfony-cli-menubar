#!/usr/bin/env bash
set -euo pipefail

# This script is adapted from the macos-spm-app-packaging skill
# It builds, bundles, and signs the SymfonyCLIMenuBar application.

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# --- App Configuration ---
# TODO: Review and update these values as needed.
APP_NAME="SymfonyCLIMenuBar"
APP_DISPLAY_NAME="Symfony CLI Menu Bar"
BUNDLE_ID="com.simonandre.SymfonyCLIMenuBar"
MACOS_MIN_VERSION="14.0"
MENU_BAR_APP="1" # Set to 1 for menu bar apps to set LSUIElement=true

# --- Signing Configuration ---
# TODO: Review and update these values as needed.
# By default, uses ad-hoc signing. For distribution, set SIGNING_MODE to "developer"
# and APP_IDENTITY to your "Developer ID Application: Your Name (TEAMID)" identity.
# You can find your identity with: security find-identity -v -p codesigning
SIGNING_MODE=${SIGNING_MODE:-"developer"} # "adhoc" or "developer"
APP_IDENTITY=${APP_IDENTITY:-"Apple Development: Simon André (F8726C7K8M)"} # e.g., "Developer ID Application: Your Name (TEAMID)"


# Sparkle public key — set once after running: vendor/Sparkle/bin/generate_keys
# The corresponding private key must be stored in SPARKLE_PRIVATE_KEY (GitHub secret).
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://smnandre.github.io/symfony-cli-menubar/appcast.xml}"

# Load version info from config/version.env
if [[ -f "$ROOT/config/version.env" ]]; then
  source "$ROOT/config/version.env"
else
  echo "config/version.env not found. Using default version numbers."
  MARKETING_VERSION=${MARKETING_VERSION:-1.0.0}
  BUILD_NUMBER=${BUILD_NUMBER:-1}
fi

echo " MBuilding $APP_NAME v$MARKETING_VERSION ($BUILD_NUMBER) for $CONF..."

# --- Build ---
ARCH_LIST=( ${ARCHES:-} )
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
echo "📦 Packaging into $APP_BUNDLE..."

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks"

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
    <key>CFBundleName</key><string>Symfony CLI Menu Bar</string>
    <key>CFBundleDisplayName</key><string>Symfony CLI Menu Bar</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSUIElement</key><${LSUI_VALUE}/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>${COPYRIGHT_NOTICE}</string>
    <key>NSAppleEventsUsageDescription</key><string>Symfony CLI Menu Bar needs permission to open Terminal for viewing logs and running commands.</string>
    <key>BuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
    <key>SUFeedURL</key><string>${SPARKLE_FEED_URL}</string>
    <key>SUPublicEDKey</key><string>${SPARKLE_PUBLIC_KEY}</string>
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
    echo "🎨 App icon installed"
fi

# Bundle app resources from Sources directory (if any)
APP_RESOURCES_DIR="$ROOT/Sources/$APP_NAME/Resources"
if [[ -d "$APP_RESOURCES_DIR" ]]; then
  cp -R "$APP_RESOURCES_DIR/." "$APP_BUNDLE/Contents/Resources/"
fi

# --- Embed Sparkle ---
echo "Embedding Sparkle..."
chmod +x "$ROOT/scripts/embed_sparkle.sh"
if [[ "$SIGNING_MODE" == "developer" && -n "$APP_IDENTITY" ]]; then
    "$ROOT/scripts/embed_sparkle.sh" "$APP_BUNDLE" "$APP_IDENTITY"
else
    "$ROOT/scripts/embed_sparkle.sh" "$APP_BUNDLE"
fi

# --- Code Signing ---
echo "🖋️ Signing application..."

ENTITLEMENTS_PATH="$ROOT/config/entitlements.plist"
if [[ ! -f "$ENTITLEMENTS_PATH" ]]; then
  echo "Creating default entitlements file at $ENTITLEMENTS_PATH"
  mkdir -p "$ROOT/config"
  cat > "$ENTITLEMENTS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.inherit</key>
    <true/>
</dict>
</plist>
PLIST
fi

if [[ "$SIGNING_MODE" == "adhoc" || -z "$APP_IDENTITY" ]]; then
  CODESIGN_ARGS=(--force --sign "-")
  echo "Using ad-hoc signing. App will not be notarized."
else
  CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
  echo "Using developer identity: $APP_IDENTITY"
fi

# Strip extended attributes before signing
xattr -cr "$APP_BUNDLE"

# Sign
codesign "${CODESIGN_ARGS[@]}" \
  --entitlements "$ENTITLEMENTS_PATH" \
  "$APP_BUNDLE"

echo "✅ Packaging complete: $APP_BUNDLE"
