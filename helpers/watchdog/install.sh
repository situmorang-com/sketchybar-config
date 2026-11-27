#!/usr/bin/env bash
# Build and (re)install the sketchybar sleep guard and watchdog LaunchAgents.
# See sleep_guard.swift and watchdog.sh for what each does.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
domain="gui/$(id -u)"

make -C "$here" >/dev/null
chmod +x "$here/watchdog.sh"

for label in com.edmundsitumorang.sketchybar-sleep-guard com.edmundsitumorang.sketchybar-watchdog; do
  plist="$HOME/Library/LaunchAgents/$label.plist"
  launchctl bootout "$domain/$label" 2>/dev/null || true
  cp "$here/$label.plist" "$plist"
  launchctl bootstrap "$domain" "$plist"
  echo "loaded $label"
done
