#!/usr/bin/env bash
set -e

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.pranay.keyboard-remap.plist"
LEGACY_PLIST_NAME="com.pranay.lenovo-key-remap.plist"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications"

echo "==> Stopping LaunchAgents..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl unload "$LAUNCH_AGENTS_DIR/$LEGACY_PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME" "$LAUNCH_AGENTS_DIR/$LEGACY_PLIST_NAME"

echo "==> Removing installed binaries and app..."
rm -f "$BIN_DIR/keyboard-remap-daemon"
rm -f "$BIN_DIR/lenovo-key-remap"
rm -f "$BIN_DIR/keyboard-remap-ui"
rm -rf "$APP_DIR/Keyboard Remap.app"

echo ""
echo "✅ Uninstalled successfully."
echo "Note: Your config in ~/.config/keyboard-remap and logs in ~/Library/Logs were preserved."
