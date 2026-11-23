// Top-right hot corner that reveals the auto-hidden native macOS menu bar.
//
// SketchyBar runs above macOS 27's MenuBarAgent window (see bar.lua and
// patches/README.md); while anything sits at that level the system never slides
// its own menu bar in, so there is no way to reach it. Parking the pointer in
// the top-right corner lowers and hides the bar, which lets the menu bar
// appear; once the pointer has left the menu-bar band and no menu is open the
// bar is restored. Both steps are cheap because the patched build re-levels
// windows in place rather than rebuilding them.
import CoreGraphics
import Foundation

let pollInterval = 0.1
let cornerPolls = 2        // ~200ms in the corner before acting
let awayPolls = 12         // ~1.2s outside the band before restoring
let menuBarBand = 44.0     // MenuBarAgent's window height on a notched display
let popupMenuLevel = 101   // kCGPopUpMenuWindowLevel: app menus, Control Center

func sketchybar(_ args: String...) {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
  p.arguments = args
  try? p.run()
  p.waitUntilExit()
}

func pointer() -> CGPoint {
  CGEvent(source: nil)?.location ?? .zero
}

func displayBounds(containing point: CGPoint) -> CGRect {
  var display = CGMainDisplayID()
  var count: UInt32 = 0
  CGGetDisplaysWithPoint(point, 1, &display, &count)
  return CGDisplayBounds(display)
}

func inCorner(_ p: CGPoint, _ bounds: CGRect) -> Bool {
  p.x >= bounds.maxX - 2 && p.y <= bounds.minY + 1
}

func menuOpen() -> Bool {
  guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
  else { return false }
  return list.contains { w in
    (w[kCGWindowLayer as String] as? Int) == popupMenuLevel
      && (w[kCGWindowOwnerName as String] as? String) != "sketchybar"
  }
}

// The reveal needs a pointer movement at the edge; the one that brought the
// pointer into the corner happened before the bar got out of the way.
func nudge(_ p: CGPoint) {
  for dx in [-1.0, 0.0] {
    let q = CGPoint(x: p.x + dx, y: p.y)
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: q, mouseButton: .left)?
      .post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
  }
}

var revealed = false
var cornerStreak = 0
var awayStreak = 0

while true {
  let p = pointer()
  let bounds = displayBounds(containing: p)

  if !revealed {
    cornerStreak = inCorner(p, bounds) ? cornerStreak + 1 : 0
    if cornerStreak >= cornerPolls {
      sketchybar("--bar", "topmost=off", "hidden=on")
      nudge(p)
      revealed = true
      cornerStreak = 0
      awayStreak = 0
    }
  } else {
    let away = p.y > bounds.minY + menuBarBand
    awayStreak = (away && !menuOpen()) ? awayStreak + 1 : 0
    if awayStreak >= awayPolls {
      sketchybar("--bar", "hidden=off", "topmost=on")
      revealed = false
    }
  }

  Thread.sleep(forTimeInterval: pollInterval)
}
