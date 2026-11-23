#!/bin/bash
# Toggle Cloudflare WARP from the sketchybar vpn widget, then refresh it.

warp="/usr/local/bin/warp-cli"

if "$warp" --accept-tos status 2>/dev/null | grep -q '^Status update: Connected'; then
  "$warp" --accept-tos disconnect >/dev/null 2>&1
else
  "$warp" --accept-tos connect >/dev/null 2>&1
fi

# Connecting takes a moment; refresh now and again once it has settled.
sketchybar --trigger vpn_update
sleep 3
sketchybar --trigger vpn_update
