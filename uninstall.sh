#!/bin/bash
# Removes input-toggled completely.
set -uo pipefail

LABEL="com.input-toggled"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/.local/bin/input-toggled" \
      "$HOME/Library/LaunchAgents/$LABEL.plist" \
      "$HOME/.local/share/input-toggled.log"

echo "Removed. To get the old macOS behavior back, re-enable the shortcut in:"
echo "System Settings > Keyboard > Keyboard Shortcuts > Input Sources"
echo "  > 'Select the previous input source'"
echo "You may also remove input-toggled from Privacy & Security > Accessibility."
