// Tells SketchyBar when you click somewhere that isn't SketchyBar, so open
// popup cards can close like real macOS menus.
//
// SketchyBar has no "clicked outside" event of its own. This watches mouse
// downs globally (no Accessibility or Input Monitoring permission needed for
// mouse events), finds the topmost window under the pointer and, unless that
// window belongs to sketchybar, triggers `popup_click_outside`. Lua ignores the
// event when no card is open, so the cost of an idle click is one trigger.
import AppKit

func sketchybarTrigger() {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
  p.arguments = ["--trigger", "popup_click_outside"]
  try? p.run()
}

// Owner of the topmost visible window under a point (CG / top-left coords).
func ownerOfWindow(at point: CGPoint) -> String? {
  guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                              kCGNullWindowID) as? [[String: Any]] else { return nil }
  for w in list {
    guard let b = w[kCGWindowBounds as String] as? [String: CGFloat],
          let alpha = w[kCGWindowAlpha as String] as? CGFloat, alpha > 0.01 else { continue }
    let rect = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
    if rect.contains(point) { return w[kCGWindowOwnerName as String] as? String }
  }
  return nil
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
  let point = CGEvent(source: nil)?.location ?? .zero
  if ownerOfWindow(at: point)?.lowercased() != "sketchybar" {
    sketchybarTrigger()
  }
}

app.run()
