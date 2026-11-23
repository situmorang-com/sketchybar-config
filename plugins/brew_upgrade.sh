#!/bin/zsh -l
# Run by the Homebrew card's "Upgrade" button inside a new Ghostty window:
# upgrades everything, then tells SketchyBar to recount.
print -P "%B==> brew update%b"
brew update
print -P "\n%B==> brew upgrade%b"
brew upgrade
status=$?
/opt/homebrew/bin/sketchybar --trigger brew_refresh
print
if (( status == 0 )); then
  print -P "%F{green}Done.%f Press any key to close."
else
  print -P "%F{red}brew upgrade exited with $status.%f Press any key to close."
fi
read -k1 -s
