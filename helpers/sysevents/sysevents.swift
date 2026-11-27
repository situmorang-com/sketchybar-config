// Pushes system changes to SketchyBar as events, so widgets don't have to poll
// for them by spawning a process every few seconds.
//
//   mic_update    MUTED=0|1 VOLUME=0..100    the default input device's volume
//                                            or mute changed, or the default
//                                            input device itself changed
//   vpn_update                               the network configuration changed
//                                            (a VPN tunnel came up or went down,
//                                            Wi-Fi switched); the vpn widget
//                                            re-reads its state on this
//   notch_update  BUILTIN=<DirectDisplayID>  the displays changed; NOTCH_LEFT and
//                 NOTCH_LEFT=x NOTCH_RIGHT=x NOTCH_RIGHT are the notch's edges in
//                 DISPLAYS=n                 global x coordinates (both 0 when
//                                            there is no notched display)
//
// Every event is sent once at startup and again every 5 minutes, so a widget
// that missed one (a sketchybar reload, a race at login) catches up.
import AppKit
import CoreAudio
import SystemConfiguration

func sketchybar(_ args: [String]) {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
  p.arguments = args
  p.standardOutput = FileHandle.nullDevice
  p.standardError = FileHandle.nullDevice
  try? p.run()
  p.waitUntilExit()
}

func trigger(_ event: String, _ vars: [String: String] = [:]) {
  sketchybar(["--trigger", event] + vars.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" })
}

// Coalesces bursts (a VPN connecting changes a dozen keys at once) into one event.
final class Debouncer {
  private var work: DispatchWorkItem?
  private let delay: Double
  init(_ delay: Double) { self.delay = delay }
  func call(_ f: @escaping () -> Void) {
    work?.cancel()
    let w = DispatchWorkItem(block: f)
    work = w
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: w)
  }
}

// MARK: - Microphone

final class Mic {
  private var device = AudioObjectID(kAudioObjectUnknown)
  private var last: String?
  private let debounce = Debouncer(0.2)
  private lazy var deviceListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
    DispatchQueue.main.async { self?.bind() }
  }
  private lazy var valueListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
    self?.debounce.call { self?.report() }
  }

  private static func addr(_ sel: AudioObjectPropertySelector,
                           _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                           _ element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain)
    -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: element)
  }

  // Volume and mute live on the main element for most devices and on channel 1
  // for some (USB headsets); watch both.
  private static let watched: [AudioObjectPropertyAddress] = [
    addr(kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeInput, 0),
    addr(kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeInput, 1),
    addr(kAudioDevicePropertyMute, kAudioDevicePropertyScopeInput, 0),
    addr(kAudioDevicePropertyMute, kAudioDevicePropertyScopeInput, 1),
  ]

  func start() {
    var a = Mic.addr(kAudioHardwarePropertyDefaultInputDevice)
    AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, deviceListener)
    bind()
  }

  private func bind() {
    if device != kAudioObjectUnknown {
      for var a in Mic.watched where AudioObjectHasProperty(device, &a) {
        AudioObjectRemovePropertyListenerBlock(device, &a, .main, valueListener)
      }
    }
    var id = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var a = Mic.addr(kAudioHardwarePropertyDefaultInputDevice)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id)
    device = id
    for var a in Mic.watched where AudioObjectHasProperty(device, &a) {
      AudioObjectAddPropertyListenerBlock(device, &a, .main, valueListener)
    }
    report()
  }

  private func read<T>(_ a: AudioObjectPropertyAddress, _ zero: T) -> T? {
    var a = a
    guard AudioObjectHasProperty(device, &a) else { return nil }
    var value = zero
    var size = UInt32(MemoryLayout<T>.size)
    return AudioObjectGetPropertyData(device, &a, 0, nil, &size, &value) == noErr ? value : nil
  }

  func report(force: Bool = false) {
    guard device != kAudioObjectUnknown else { return }
    let vol = read(Mic.watched[0], Float32(0)) ?? read(Mic.watched[1], Float32(0))
    let mute = read(Mic.watched[2], UInt32(0)) ?? read(Mic.watched[3], UInt32(0))
    let volume = Int(((vol ?? 1) * 100).rounded())
    let muted = (mute ?? 0) != 0 || volume == 0
    let state = "\(muted ? 1 : 0)|\(volume)"
    if state == last && !force { return }
    last = state
    trigger("mic_update", ["MUTED": muted ? "1" : "0", "VOLUME": String(volume)])
  }
}

// MARK: - Network (VPN)

final class Network {
  private var store: SCDynamicStore?
  private let debounce = Debouncer(1.5)

  func start() {
    var ctx = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                    retain: nil, release: nil, copyDescription: nil)
    store = SCDynamicStoreCreate(nil, "sketchybar-sysevents" as CFString, { _, _, info in
      guard let info else { return }
      let me = Unmanaged<Network>.fromOpaque(info).takeUnretainedValue()
      me.debounce.call { trigger("vpn_update") }
    }, &ctx)
    guard let store else { return }
    let patterns = [
      "State:/Network/Global/IPv4",
      "State:/Network/Global/DNS",
      "State:/Network/Interface/.*/IPv4",
      "State:/Network/Service/.*/IPv4",
    ] as CFArray
    SCDynamicStoreSetNotificationKeys(store, nil, patterns)
    SCDynamicStoreSetDispatchQueue(store, .main)
  }
}

// MARK: - Displays and the notch

final class Displays {
  private let debounce = Debouncer(1.0)

  func start() {
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.debounce.call { self?.report() }
    }
  }

  func report() {
    var builtin: CGDirectDisplayID = 0
    var left = 0.0, right = 0.0
    for screen in NSScreen.screens {
      guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
      else { continue }
      if CGDisplayIsBuiltin(id) != 0 { builtin = id }
      if let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
        left = screen.frame.minX + l.maxX
        right = screen.frame.minX + r.minX
      }
    }
    trigger("notch_update", [
      "BUILTIN": String(builtin),
      "NOTCH_LEFT": String(format: "%.1f", left),
      "NOTCH_RIGHT": String(format: "%.1f", right),
      "DISPLAYS": String(NSScreen.screens.count),
    ])
  }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let mic = Mic()
let network = Network()
let displays = Displays()

for event in ["mic_update", "vpn_update", "notch_update"] {
  sketchybar(["--add", "event", event])
}

// Give sketchybar a moment to finish loading the config before the first
// round of events, so the widgets' subscriptions exist to receive them.
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
  mic.start()
  network.start()
  displays.start()
  displays.report()
  trigger("vpn_update")
}

Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
  mic.report(force: true)
  displays.report()
  trigger("vpn_update")
}

app.run()
