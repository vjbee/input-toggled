#!/bin/bash
# input-toggled installer — instant Thai/EN switch on cmd+space.
# Compiles the daemon locally, installs a LaunchAgent, and disables the
# system "Select previous input source" hotkey so cmd+space is free.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin/input-toggled"
LABEL="com.input-toggled"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/.local/share/input-toggled.log"

echo "==> Checking Swift compiler (Xcode Command Line Tools)..."
if ! xcrun swiftc --version >/dev/null 2>&1; then
    echo "Swift compiler not found. Run:  xcode-select --install  then re-run this script."
    exit 1
fi

echo "==> Compiling..."
mkdir -p "$HOME/.local/bin" "$HOME/.local/share"
xcrun swiftc -O "$DIR/hotkeyd.swift" -o "$BIN"

echo "==> Installing LaunchAgent..."
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
EOF

echo "==> Disabling system input-switch hotkey (Select previous input source)..."
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
    "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array></dict></dict>"
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true

echo "==> Starting daemon..."
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "==> Opening System Settings (Accessibility) and the binary folder..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
sleep 1
open "$HOME/.local/bin"

cat <<'MSG'

DONE — one manual step left (macOS requires it):

  In the System Settings window that just opened (Accessibility /
  "Device Control and Data Access"), DRAG the file `input-toggled`
  from the Finder window into the list and switch it ON.

  Within ~3 seconds cmd+space will toggle Thai/EN instantly.
  Check status:  tail ~/.local/share/input-toggled.log
  (should say "event tap active")

NOTE: if you use cmd+space for Spotlight, that shortcut is now taken
by the language toggle. Move Spotlight to another key first in
System Settings > Keyboard > Keyboard Shortcuts > Spotlight.
MSG
