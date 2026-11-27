# Local SketchyBar patches

Homebrew's `sketchybar` binary is replaced with a build carrying the patches in
this directory. `brew upgrade sketchybar` (or `brew reinstall`) puts the stock
binary back, so re-run `build.sh` afterwards. The stock binary is kept next to
the patched one as `sketchybar.orig` in the Cellar.

## pr892-menubar-reveal.patch

macOS 27 hosts the menu bar in a `MenuBarAgent` process that keeps an
invisible full-width 44pt window across the top of the display at window level
25 (`kCGStatusWindowLevel`) while the menu bar is set to auto-hide. It swallows
every click on anything underneath, so a stock SketchyBar draws fine but no
item ever receives a click (FelixKratz/SketchyBar#852).

This is the diff of FelixKratz/SketchyBar#892 (head `527f407`, still open when
taken on 2026-11-27, applies cleanly to 2.24.1). With `topmost=off`, it lifts a
top bar to level 26 while the menu bar is hidden, drops it back to its normal
level when the window server posts the menu-bar reveal, and raises it again on
hide. The native menu bar therefore still slides in at the top edge, so no
hot-corner helper is needed. Refresh it with
`gh pr diff 892 -R FelixKratz/SketchyBar > pr892-menubar-reveal.patch`.

Once a release containing #892 is in Homebrew, delete this patch (and this
directory if nothing else is left), `brew upgrade sketchybar`, and keep
`topmost = "off"` in `bar.lua`.

## disabled/menubar-agent-level.patch

The earlier local fix, no longer applied (`build.sh` only picks up `*.patch`
in this directory, not in `disabled/`). It raised `topmost=on` one level above
the agent permanently, which blocked the native menu bar from ever sliding in,
so it needed `helpers/menubar_hotcorner` (top-right corner lowers the bar) and
made `topmost` changes re-level windows in place. To go back to it: move it
up a directory, remove `pr892-menubar-reveal.patch`, set `topmost = "on"` and
restore the `menubar_hotcorner` launch in `bar.lua` (see git history), and
re-run `build.sh`.

## Rebuild

```bash
~/.config/sketchybar/patches/build.sh
```

The script fetches the formula's tarball through Homebrew (which verifies its
checksum), applies every `*.patch` here, builds the arm64 binary and installs
it over the Cellar one, then restarts the `sh.brew.sketchybar` service.

## Code signing

macOS ties the "control this Mac" (Accessibility) approval to the binary's
code signature, and an ad-hoc signature changes with every build, so each
rebuild used to re-prompt on every click. `build.sh` therefore signs the
binary with a self-signed certificate named `sketchybar-local` in the login
keychain, created on first use by `make-signing-cert.sh`. The designated
requirement is then `identifier sketchybar and certificate leaf = H"…"`,
which every later build satisfies, so the approval granted once in System
Settings keeps working. The new binary is signed as a separate file and
renamed into place: rewriting the installed file in place leaves the kernel
with the old signature cached, and launchd's next start gets killed with
`OS_REASON_CODESIGNING`. If the certificate is ever deleted from the keychain,
the next build creates a new one and macOS asks once more.

## Undo

```bash
ver=$(ls /opt/homebrew/Cellar/sketchybar | tail -1)
cp /opt/homebrew/Cellar/sketchybar/$ver/bin/sketchybar.orig /opt/homebrew/Cellar/sketchybar/$ver/bin/sketchybar
launchctl kickstart -k gui/$(id -u)/sh.brew.sketchybar
```
