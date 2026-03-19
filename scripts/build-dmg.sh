#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_DIR="$BUILD_DIR/TravisShot.app"
DMG_PATH="$BUILD_DIR/TravisShot.dmg"
RELEASE_BIN="$PROJECT_ROOT/.build/release/TravisShot"

# --- Code Signing & Notarization config ---
SIGNING_IDENTITY="Developer ID Application: Traivend L.L.C-FZ (47DXSS665W)"
TEAM_ID="47DXSS665W"
BUNDLE_ID="com.travisshot.app"

# --- Auto-bump patch version ---
NEW_VERSION=$("$PROJECT_ROOT/scripts/bump-version.sh" patch)
SEMVER="${NEW_VERSION%%-*}"          # e.g. 1.0.1
BUILD_NUM="${NEW_VERSION##*-}"       # e.g. 1
SHORT_VERSION="${SEMVER%.*}"         # e.g. 1.0 (major.minor for CFBundleShortVersionString)
echo "Version: $NEW_VERSION (CFBundleVersion=$SEMVER, CFBundleShortVersionString=$SHORT_VERSION, Build=$BUILD_NUM)"

# Icon source: prefer repo asset, fall back to installed app
ICON_SOURCE="$PROJECT_ROOT/assets/AppIcon.icns"
if [ ! -f "$ICON_SOURCE" ]; then
    ICON_SOURCE="/Applications/TravisShot.app/Contents/Resources/AppIcon.icns"
fi

# --- Release build ---
echo "Building release..."
swift build -c release --package-path "$PROJECT_ROOT"

# Patch SPM's generated bundle accessors to use Bundle.main.resourceURL
# (CLI swift-build generates Bundle.main.bundleURL which points to .app root,
#  but codesign requires resources inside Contents/Resources/)
echo "Patching resource bundle accessors for .app layout..."
find "$PROJECT_ROOT/.build" -name "resource_bundle_accessor.swift" -path "*/release/*" | while read accessor; do
    if grep -q 'Bundle.main.bundleURL' "$accessor"; then
        sed -i '' 's/Bundle\.main\.bundleURL/Bundle.main.resourceURL!/' "$accessor"
        echo "  Patched: $(basename "$(dirname "$(dirname "$accessor")")")"
    fi
done

echo "Rebuilding with patched accessors..."
swift build -c release --package-path "$PROJECT_ROOT"

if [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: release binary not found at $RELEASE_BIN" >&2
    exit 1
fi

# --- Assemble .app bundle ---
echo "Assembling TravisShot.app..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$RELEASE_BIN" "$APP_DIR/Contents/MacOS/TravisShot"

# Info.plist (versions injected from VERSION file)
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>TravisShot needs screen recording permission to capture screenshots.</string>
    <key>CFBundleName</key>
    <string>TravisShot</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$SEMVER</string>
    <key>CFBundleShortVersionString</key>
    <string>$SHORT_VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

# Icon
if [ -f "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "Warning: AppIcon.icns not found, DMG will have no app icon" >&2
fi

# Resource bundles from SPM build → Contents/Resources/ (required for codesign)
RELEASE_DIR="$PROJECT_ROOT/.build/release"
for bundle in Defaults_Defaults.bundle KeyboardShortcuts_KeyboardShortcuts.bundle TravisShot_TravisShot.bundle; do
    if [ -d "$RELEASE_DIR/$bundle" ]; then
        cp -R "$RELEASE_DIR/$bundle" "$APP_DIR/"
        cp -R "$RELEASE_DIR/$bundle" "$APP_DIR/Contents/Resources/"
    fi
done

# --- Code sign the app ---
echo "Signing app with Developer ID..."
codesign --deep --force --options runtime \
    --sign "$SIGNING_IDENTITY" \
    --timestamp \
    "$APP_DIR"
echo "Verifying signature..."
codesign --verify --deep --strict "$APP_DIR"
echo "Signature valid (notarization check deferred until after submission)."

# --- Create DMG with volume icon ---
echo "Creating DMG..."
rm -f "$DMG_PATH"
STAGING=$(mktemp -d)
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Set volume icon so the DMG shows the app icon in Finder
if [ -f "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$STAGING/.VolumeIcon.icns"
    SetFile -a C "$STAGING" 2>/dev/null || true
fi

hdiutil create -volname "TravisShot" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING"

# --- Sign the DMG ---
echo "Signing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

# --- Notarize ---
echo "Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "notarytool-profile" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo ""
echo "Done: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
echo "Version: $NEW_VERSION"
echo "App is signed, notarized, and ready for distribution."
