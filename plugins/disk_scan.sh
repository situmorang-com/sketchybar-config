#!/bin/bash
# Folder sizes for the Storage card, cached so the card opens instantly.
#
#   disk_scan.sh pinned [--force]   WhatsApp media, Downloads, DEV (max every 15 min)
#   disk_scan.sh top    [--force]   largest folders in ~ and ~/Library (max every 6 h)
#
# Scans run at background priority (taskpolicy -b throttles disk I/O, nice 20
# yields CPU), so a full scan (~2 min) never slows the Mac down. Each writes
# "<epoch>" then "<kb>|<path>" lines to ~/Library/Caches/sketchybar/, then
# triggers `disk_scan_done` so the card can redraw.

MODE="$1"
FORCE="$2"
CACHE_DIR="$HOME/Library/Caches/sketchybar"
mkdir -p "$CACHE_DIR"

PINNED=(
  "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media"
  "$HOME/Downloads"
  "$HOME/DEV"
)

case "$MODE" in
  pinned) MAX_AGE=$((15 * 60)) ;;
  top)    MAX_AGE=$((6 * 60 * 60)) ;;
  *) echo "usage: $0 pinned|top [--force]" >&2; exit 1 ;;
esac

OUT="$CACHE_DIR/disk_$MODE.txt"
LOCK="$CACHE_DIR/disk_$MODE.lock"

# Fresh enough? Nothing to do.
if [ "$FORCE" != "--force" ] && [ -s "$OUT" ]; then
  last=$(head -1 "$OUT")
  if [ $(( $(date +%s) - ${last:-0} )) -lt $MAX_AGE ]; then
    exit 0
  fi
fi

# One scan of each kind at a time; clear a lock left by a crash after 15 min.
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +15 2>/dev/null)" ]; then
    rm -rf "$LOCK"; mkdir "$LOCK" || exit 0
  else
    exit 0
  fi
fi
trap 'rm -rf "$LOCK"' EXIT

measure() { taskpolicy -b nice -n 20 du -skx "$@" 2>/dev/null; }

TMP="$OUT.tmp"
date +%s > "$TMP"

if [ "$MODE" = pinned ]; then
  for p in "${PINNED[@]}"; do
    # -1 = macOS refused access (app containers need Full Disk Access for
    # sketchybar), -2 = folder doesn't exist.
    if [ ! -e "$p" ] && ! ls -d "$p" 2>&1 | grep -q "not permitted"; then
      kb=-2
    elif ! ls "$p" >/dev/null 2>&1; then
      kb=-1
    else
      kb=$(measure "$p" | awk '{print $1}')
    fi
    echo "${kb:-0}|$p" >> "$TMP"
  done
else
  shopt -s nullglob dotglob
  # Children of ~ (except Library itself) and of ~/Library, minus the pinned
  # folders, which are already shown above.
  candidates=()
  for p in "$HOME"/* "$HOME"/Library/*; do
    [ -d "$p" ] && [ ! -L "$p" ] || continue
    [ "$p" = "$HOME/Library" ] && continue
    [ "$p" = "$HOME/.Trash" ] && continue
    skip=0
    for q in "${PINNED[@]}"; do
      [ "$(echo "$p" | tr '[:upper:]' '[:lower:]')" = "$(echo "$q" | tr '[:upper:]' '[:lower:]')" ] && skip=1
    done
    [ $skip = 1 ] || candidates+=("$p")
  done
  measure "${candidates[@]}" | sort -rn | head -6 | while IFS=$'\t' read -r kb path; do
    echo "$kb|$path"
  done >> "$TMP"
fi

mv "$TMP" "$OUT"
/opt/homebrew/bin/sketchybar --trigger disk_scan_done >/dev/null 2>&1
