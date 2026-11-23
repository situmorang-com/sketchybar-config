#!/bin/bash
# Print the current VPN state as "<state>|<label>" for the sketchybar vpn widget.
#   state: on | connecting | off
#
# Cloudflare WARP is checked first via warp-cli, then NordVPN, then macOS's
# built-in VPN services. utun interfaces alone prove nothing: macOS keeps
# several up at all times (iCloud, Continuity), so they are not used.

warp="/usr/local/bin/warp-cli"

if [[ -x "$warp" ]]; then
  status="$("$warp" --accept-tos status 2>/dev/null | sed -n 's/^Status update: //p' | head -n1)"
  case "$status" in
    Connected)
      echo "on|WARP"
      exit 0
      ;;
    Connecting*)
      echo "connecting|WARP"
      exit 0
      ;;
  esac
fi

# NordVPN registers its tunnel as a Network Extension; its app process alone is
# not proof of a connection, so ask scutil for a connected service.
connected="$(scutil --nc list 2>/dev/null | grep '(Connected)' | head -n1)"
if [[ -n "$connected" ]]; then
  name="$(sed -n 's/.*"\([^"]*\)".*/\1/p' <<<"$connected")"
  echo "on|${name:-VPN}"
  exit 0
fi

echo "off|"
