#!/usr/bin/env bash
# Restart sketchybar when it stops answering, wherever the freeze comes from.
#
# Why: after a wake (and sometimes a display change) sketchybar 2.24.x can wedge
# its main thread inside a window-server call (SLSRemoveSurface / SLSOrderWindow
# / CA commit) while tearing down and recreating its windows. The process stays
# alive, `sketchybar --query` prints nothing, and the bar is blank until the
# process is killed. Upstream: FelixKratz/SketchyBar#776, draft fix #847.
#
# helpers/wake_restart.sh only fires once sketchybar delivers system_woke, which
# a wedged sketchybar delivers late or never (2026-11-27: two minutes late). This
# runs outside sketchybar, under its own LaunchAgent, so it doesn't depend on it.
#
# Every INTERVAL seconds it asks the service's process for `--query bar`. After
# FAILS_TO_RESTART silent answers in a row it kills the process and launchd
# starts a fresh one. It shares wake_restart.sh's stamp file, so the two never
# restart the bar twice for one freeze. Restarts go to the sketchybar log.

set -u

INTERVAL=5          # seconds between probes
PROBE_TIMEOUT=3     # seconds a single --query may take
FAILS_TO_RESTART=2  # consecutive silent probes before restarting (~10s)
STARTUP_GRACE=30    # seconds to leave a newly started process alone

SB=/opt/homebrew/bin/sketchybar
SERVICE="gui/$(id -u)/sh.brew.sketchybar"
TMP="${TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR)}"
GUARD_FILE="${TMP%/}/sketchybar_wake_restart.stamp"
LOG_DIR="$HOME/.local/state/sketchybar"
LOG="$LOG_DIR/sketchybar.log"

mkdir -p "$LOG_DIR"
log() { printf '%s [watchdog] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

service_pid() {
  launchctl print "$SERVICE" 2>/dev/null | awk '$1 == "pid" && $2 == "=" { print $3; exit }'
}

# A healthy bar answers with its JSON; a wedged one returns nothing (exit 0).
# perl's alarm bounds the wait in case a query blocks instead.
responds() {
  /usr/bin/perl -e 'alarm shift; exec @ARGV' "$PROBE_TIMEOUT" "$SB" --query bar 2>/dev/null |
    grep -q '"position"'
}

last_pid=""
seen_at=0
fails=0

while :; do
  sleep "$INTERVAL"

  pid=$(service_pid)
  if [ -z "$pid" ]; then
    # Not running: stopped on purpose, or launchd is already restarting it.
    last_pid=""
    fails=0
    continue
  fi

  now=$(date +%s)
  if [ "$pid" != "$last_pid" ]; then
    last_pid=$pid
    seen_at=$now
    fails=0
  fi
  (( now - seen_at < STARTUP_GRACE )) && continue

  if responds; then
    fails=0
    continue
  fi
  fails=$((fails + 1))
  (( fails < FAILS_TO_RESTART )) && continue

  # wake_restart.sh (or this script) restarted it moments ago; let that land.
  if [ -n "$(find "$GUARD_FILE" -newermt "-20 seconds" 2>/dev/null)" ]; then
    continue
  fi

  log "pid $pid gave no answer to $fails probes in a row; restarting"
  touch "$GUARD_FILE"
  # SIGKILL: a wedged main thread never gets to handle a polite signal. The
  # service has KeepAlive, and kickstart covers the case where launchd waits.
  kill -9 "$pid" 2>/dev/null
  sleep 1
  launchctl kickstart "$SERVICE" 2>/dev/null
  fails=0
done
