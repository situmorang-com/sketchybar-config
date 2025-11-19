#!/bin/bash

# Toggle Itsycal dropdown by simulating a click on its menu bar icon
osascript <<EOF
tell application "System Events"
    tell process "Itsycal"
        click menu bar item 1 of menu bar 2
    end tell
end tell
EOF
