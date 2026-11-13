#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications"
CONFIG_DIR="$HOME/.config/keyboard-remap"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.pranay.keyboard-remap.plist"
LEGACY_PLIST_NAME="com.pranay.lenovo-key-remap.plist"

echo "==> Building Keyboard Remap Daemon..."
mkdir -p "$BIN_DIR"
swiftc -O "$SCRIPT_DIR/src/daemon/main.swift" -o "$BIN_DIR/keyboard-remap-daemon"
ln -sf "$BIN_DIR/keyboard-remap-daemon" "$BIN_DIR/lenovo-key-remap"

echo "==> Building Keyboard Remap Settings UI..."
swiftc -framework SwiftUI -framework AppKit -framework IOKit -O "$SCRIPT_DIR/src/ui/main.swift" -o "$BIN_DIR/keyboard-remap-ui"

echo "==> Packaging Keyboard Remap.app..."
APP_BUNDLE="$APP_DIR/Keyboard Remap.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BIN_DIR/keyboard-remap-ui" "$APP_BUNDLE/Contents/MacOS/Keyboard Remap"
chmod +x "$APP_BUNDLE/Contents/MacOS/Keyboard Remap"

cat << EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Keyboard Remap</string>
    <key>CFBundleIdentifier</key>
    <string>com.pranay.keyboard-remap-ui</string>
    <key>CFBundleName</key>
    <string>Keyboard Remap</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.2-beta</string>
    <key>CFBundleVersion</key>
    <string>0.0.2-beta</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Setting up default config if missing..."
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    cp "$SCRIPT_DIR/config/config.example.json" "$CONFIG_DIR/config.json"
    echo "    Created $CONFIG_DIR/config.json"
else
    echo "    Existing config found at $CONFIG_DIR/config.json (preserved)"
fi

echo "==> Cleaning up any legacy LaunchAgent..."
launchctl unload "$LAUNCH_AGENTS_DIR/$LEGACY_PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$LEGACY_PLIST_NAME"

echo "==> Installing LaunchAgent..."
mkdir -p "$LAUNCH_AGENTS_DIR"
sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/launchd/$PLIST_NAME" > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "==> Starting service with launchctl..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo ""
echo "✅ Installation complete!"
echo "   Daemon running: $BIN_DIR/keyboard-remap-daemon"
echo "   Config file:    $CONFIG_DIR/config.json"
echo "   Settings UI:    $APP_DIR/Keyboard Remap.app (or run 'keyboard-remap-ui')"
echo "   Logs:           $HOME/Library/Logs/keyboard-remap.log"
