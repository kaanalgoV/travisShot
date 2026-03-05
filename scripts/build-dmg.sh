#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_DIR="$BUILD_DIR/TravisShot.app"
DMG_PATH="$BUILD_DIR/TravisShot.dmg"
RELEASE_BIN="$PROJECT_ROOT/.build/release/TravisShot"

# Icon source: prefer repo asset, fall back to installed app
ICON_SOURCE="$PROJECT_ROOT/assets/AppIcon.icns"
if [ ! -f "$ICON_SOURCE" ]; then
    ICON_SOURCE="/Applications/TravisShot.app/Contents/Resources/AppIcon.icns"
fi

# --- Release build ---
echo "Building release..."
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

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
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
    <string>com.travisshot.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
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

# Resource bundles from SPM build
# SPM's generated Bundle.module accessor looks for bundles at Bundle.main.bundleURL
# which is the .app root directory, NOT Contents/Resources/.
# We must place bundles at both locations for compatibility.
RELEASE_DIR="$PROJECT_ROOT/.build/release"
for bundle in Defaults_Defaults.bundle KeyboardShortcuts_KeyboardShortcuts.bundle TravisShot_TravisShot.bundle; do
    if [ -d "$RELEASE_DIR/$bundle" ]; then
        cp -R "$RELEASE_DIR/$bundle" "$APP_DIR/"
        cp -R "$RELEASE_DIR/$bundle" "$APP_DIR/Contents/Resources/"
    fi
done

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

echo ""
echo "Done: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
