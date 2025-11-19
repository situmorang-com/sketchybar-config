#!/bin/bash

# Check if NordVPN is running, if not start it
if ! pgrep -x "NordVPN" > /dev/null 2>&1; then
    open -a "NordVPN"
    sleep 2
fi

# Check if VPN is currently connected by looking for utun interface with inet address
if ifconfig | grep -A 3 'utun' | grep 'inet ' | head -n1 > /dev/null 2>&1; then
    # VPN is connected - just open the NordVPN app
    # User can manually disconnect if needed
    open -a "NordVPN"
else
    # VPN is not connected - connect to Singapore using URL scheme with country code
    open 'nordvpn://connect?country=sg'
    sleep 3
    sketchybar --trigger routine
fi
