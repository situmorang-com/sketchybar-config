#!/usr/bin/env bash
# Install (or reinstall) the sketchybar watchdog LaunchAgent. See watchdog.sh.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
label=com.edmundsitumorang.sketchybar-watchdog
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

chmod +x "$here/watchdog.sh"
launchctl bootout "$domain/$label" 2>/dev/null || true
cp "$here/$label.plist" "$plist"
launchctl bootstrap "$domain" "$plist"
echo "loaded $label"
