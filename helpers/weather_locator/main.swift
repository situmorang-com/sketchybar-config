// WeatherLocator: one-shot location fix for the SketchyBar weather widget.
// With `--ssid <file>` it instead writes the current Wi-Fi network name
// (macOS only reveals it to apps that hold Location permission).
// Launched as a real app (open -g -j) so macOS can show the "Allow location"
// prompt; writes "lat,lon|accuracy_m|subLocality|locality" to the file given
// as the first argument, or "DENIED"/"ERROR" on failure, then quits.
import AppKit
import CoreLocation
import CoreWLAN

let ssidMode = CommandLine.arguments.dropFirst().first == "--ssid"
let args = Array(CommandLine.arguments.dropFirst(ssidMode ? 2 : 1))
let outPath = args.first ?? (NSTemporaryDirectory() + (ssidMode ? "sketchybar_wifi_ssid" : "sketchybar_weather_fix"))

func finish(_ s: String) {
  try? s.write(toFile: outPath, atomically: true, encoding: .utf8)
  exit(0)
}

final class Locator: NSObject, CLLocationManagerDelegate {
  let manager = CLLocationManager()
  var best: CLLocation?
  var started = false

  func start() {
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    check(manager.authorizationStatus)
  }

  func check(_ status: CLAuthorizationStatus) {
    switch status {
    case .notDetermined:
      NSApp.activate(ignoringOtherApps: true)
      manager.requestWhenInUseAuthorization()
    case .denied, .restricted:
      finish("DENIED")
    default:
      if ssidMode {
        finish(CWWiFiClient.shared().interface()?.ssid() ?? "")
      }
      guard !started else { return }
      started = true
      manager.startUpdatingLocation()
      // Take the best fix seen within 8 s; Wi-Fi fixes usually tighten fast.
      DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self.report() }
    }
  }

  func locationManagerDidChangeAuthorization(_ m: CLLocationManager) { check(m.authorizationStatus) }

  func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
    for l in locs where l.horizontalAccuracy >= 0 {
      if best == nil || l.horizontalAccuracy < best!.horizontalAccuracy { best = l }
    }
    if let b = best, b.horizontalAccuracy <= 50 { report() }
  }

  func locationManager(_ m: CLLocationManager, didFailWithError e: Error) {
    if (e as? CLError)?.code == .denied { finish("DENIED") }
  }

  var reported = false
  func report() {
    guard !reported else { return }
    reported = true
    manager.stopUpdatingLocation()
    guard let l = best else { finish("ERROR") ; return }
    let head = String(format: "%.5f,%.5f|%.0f", l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy)
    CLGeocoder().reverseGeocodeLocation(l) { marks, _ in
      let p = marks?.first
      finish("\(head)|\(p?.subLocality ?? "")|\(p?.locality ?? p?.subAdministrativeArea ?? "")")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { finish("\(head)||") }
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let locator = Locator()
DispatchQueue.main.async { locator.start() }
// Hard stop in case the permission prompt is left unanswered.
DispatchQueue.main.asyncAfter(deadline: .now() + 120) { finish("ERROR") }
app.run()
