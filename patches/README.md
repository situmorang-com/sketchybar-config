# Local SketchyBar patches

Homebrew's `sketchybar` binary is replaced with a build carrying the patches in
this directory. `brew upgrade sketchybar` (or `brew reinstall`) puts the stock
binary back, so re-run `build.sh` afterwards. The stock binary is kept next to
the patched one as `sketchybar.orig` in the Cellar.

## menubar-agent-level.patch

macOS 27 hosts the menu bar in a `MenuBarAgent` process that keeps an
invisible full-width 44pt window across the top of every display, even while
the menu bar is set to auto-hide. That window sits at window level 25
(`kCGStatusWindowLevel`) and swallows every click on anything underneath it,
so a SketchyBar with `topmost=off` draws fine but no item ever receives a
click (FelixKratz/SketchyBar#852).

Stock `topmost=on` uses that same level 25, and on macOS 27.2 the agent
recreates its window within seconds of any bar rebuild -- whichever window was
created last wins, so the bar ends up underneath again. The patch raises
`topmost=on` by one level, so the bar is always above the agent, whichever of
the two is recreated. The system's own dropdown menus draw at level 101, so
they still appear over the bar.

Trade-off: with the bar above the agent, moving the pointer to the top edge no
longer reveals the auto-hidden native menu bar. The system refuses to slide it
in while any window sits at that level, even one parked off-screen by
`hidden=on`, so the bar has to be lowered as well to get at it.

The same patch therefore also changes what `topmost` does at runtime. Stock
sketchybar tears every bar down and recreates it on any `topmost` change
(`bar_manager_reset`), which with a few hundred items keeps it at ~50% CPU for
about ten seconds; the patch re-levels the existing windows in place instead,
so a toggle takes about 10ms. `helpers/menubar_hotcorner` relies on that: park
the pointer in the top-right corner and it runs `topmost=off hidden=on`, which
lets the native menu bar slide in, then restores `hidden=off topmost=on` once
the pointer has left the menu-bar band and no menu is open.

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
Settings keeps working. If the certificate is ever deleted from the keychain,
the next build creates a new one and macOS asks once more.

## Undo

```bash
ver=$(ls /opt/homebrew/Cellar/sketchybar | tail -1)
cp /opt/homebrew/Cellar/sketchybar/$ver/bin/sketchybar.orig /opt/homebrew/Cellar/sketchybar/$ver/bin/sketchybar
launchctl kickstart -k gui/$(id -u)/sh.brew.sketchybar
```
