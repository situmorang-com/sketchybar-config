#!/usr/bin/env bash
# Rebuild Homebrew's sketchybar with every *.patch in this directory applied and
# install it over the Cellar binary. See README.md for why. Re-run after
# `brew upgrade sketchybar`, which restores the stock binary.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
formula=felixkratz/formulae/sketchybar

info=$(brew info --json=v2 "$formula")
installed=$(printf '%s' "$info" | python3 -c 'import json,sys;f=json.load(sys.stdin)["formulae"][0];print(f["installed"][0]["version"] if f["installed"] else "")')
stable=$(printf '%s' "$info" | python3 -c 'import json,sys;print(json.load(sys.stdin)["formulae"][0]["versions"]["stable"])')

if [[ -z "$installed" ]]; then
  echo "sketchybar is not installed via brew" >&2
  exit 1
fi
if [[ "$installed" != "$stable" ]]; then
  echo "installed $installed != formula stable $stable; run 'brew upgrade sketchybar' first" >&2
  exit 1
fi

cellar=/opt/homebrew/Cellar/sketchybar/$installed/bin
[[ -x "$cellar/sketchybar" ]] || { echo "no binary at $cellar/sketchybar" >&2; exit 1; }

# brew fetch downloads the source tarball into its cache and verifies the
# formula's checksum, so nothing here trusts the archive blindly.
brew fetch -s "$formula" >/dev/null
tarball=$(brew --cache -s "$formula")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tar -xzf "$tarball" -C "$work"
src=$work/SketchyBar-$installed
[[ -d "$src" ]] || { echo "unexpected tarball layout in $tarball" >&2; exit 1; }

for p in "$here"/*.patch; do
  echo "applying $(basename "$p")"
  patch -p1 -d "$src" < "$p"
done

make -C "$src" arm64 >/dev/null

# Keep the stock binary once, so the patch can be undone without a reinstall.
# brew installs it read-only, so replace the file rather than writing into it.
[[ -f "$cellar/sketchybar.orig" ]] || cp "$cellar/sketchybar" "$cellar/sketchybar.orig"
# Sign with the local certificate so the binary keeps one code identity across
# rebuilds; the Accessibility approval in System Settings is tied to it.
# Sign a copy and rename it over the old binary: the kernel caches a binary's
# signature per file, so rewriting the installed file in place gets the new
# process killed at launch with OS_REASON_CODESIGNING.
"$here/make-signing-cert.sh" sketchybar-local
install -m 755 "$src/bin/sketchybar" "$cellar/sketchybar.new"
codesign --force --sign sketchybar-local --identifier sketchybar "$cellar/sketchybar.new"
chmod 555 "$cellar/sketchybar.new"
mv -f "$cellar/sketchybar.new" "$cellar/sketchybar"

# kickstart only works while the service is loaded; after a `launchctl bootout`
# it has to be bootstrapped from the plist again.
service="gui/$(id -u)/sh.brew.sketchybar"
plist=$HOME/Library/LaunchAgents/sh.brew.sketchybar.plist
if ! launchctl kickstart -k "$service" 2>/dev/null; then
  launchctl bootstrap "gui/$(id -u)" "$plist"
fi
echo "installed patched sketchybar $installed and restarted the service"
