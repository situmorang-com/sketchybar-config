#!/usr/bin/env bash
# Restart sketchybar after the machine wakes.
#
# Why this exists: on wake from a display-topology change (closing the lid drops
# the built-in display), sketchybar v2.24.0 can enter a runaway window-frame /
# CoreAnimation commit loop. That loop pins the main thread, which is also what
# services the mach port -- so the lua config stalls, `sketchybar --query`
# returns nothing, and the bar freezes until the service is restarted.
#
# The restart is driven by launchctl rather than by sketchybar itself, because
# once the loop is running sketchybar no longer processes messages.
#
# Guard: refuse to restart more than once per GUARD_SECONDS. Without this, a
# system_woke delivered to the freshly started instance would restart it again,
# and so on -- a restart loop would be far worse than the bug being worked
# around.

set -u

GUARD_SECONDS=60
GUARD_FILE="${TMPDIR:-/tmp}/sketchybar_wake_restart.stamp"
SERVICE="gui/$(id -u)/homebrew.mxcl.sketchybar"

# Let the display topology settle before restarting.
sleep 3

if [ -n "$(find "$GUARD_FILE" -newermt "-${GUARD_SECONDS} seconds" 2>/dev/null)" ]; then
  # Restarted very recently -- this is the echo of our own restart, not a new wake.
  exit 0
fi

touch "$GUARD_FILE"
exec launchctl kickstart -k "$SERVICE"
