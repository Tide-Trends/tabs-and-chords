#!/bin/zsh
set -euo pipefail

APP_NAME="Tabs & Chords"
EXECUTABLE_NAME="TabsAndChords"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
INSTALL_DIR="$HOME/Applications/$APP_NAME.app"

# Generate Info.plist first so it can be embedded
cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>TabsAndChords</string>
    <key>CFBundleIdentifier</key>
    <string>com.lukaah.tabsandchords</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Tabs &amp; Chords</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Tabs &amp; Chords reads the current song, inspects supported browser tabs, and controls Music so it can search for tabs and play songs.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

# Build and embed Info.plist
swift build -c release -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$CONTENTS_DIR/Info.plist"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"

# Copy app icon into Resources/
mkdir -p "$CONTENTS_DIR/Resources"
cp "$ROOT_DIR/assets/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"

xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose "$APP_DIR"

mkdir -p "$HOME/Applications"
rm -rf "$INSTALL_DIR"
cp -R "$APP_DIR" "$INSTALL_DIR"

open "$INSTALL_DIR"

echo "Installed to $INSTALL_DIR"