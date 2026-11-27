// Keeps sketchybar out of the post-wake window rebuild that wedges it.
//
// sketchybar 2.24.x tears down and recreates every bar and item window when the
// system wakes or the display set changes. Right after a wake, with external
// displays still coming back, that rebuild can block forever inside a window-
// server call (SLSRemoveSurface / SLSOrderWindow): the process stays alive,
// `--query` prints nothing and the bar is blank (FelixKratz/SketchyBar#776).
// A freshly started sketchybar on a settled display set doesn't hit it.
//
// So this agent stops the sketchybar service as the Mac or its screens go to
// sleep, and starts it again on wake once the display layout has stopped
// changing. The new process loads while the lock screen is still up, and never
// sees a wake to rebuild for. watchdog.sh stays as the backstop for anything
// this misses (a wake that came without a sleep notification, a monitor
// replugged while awake).
//
// It only restarts a service it stopped itself (marker file), so
// `brew services stop sketchybar` is respected.
//
// Build: make (see makefile). Runs under the LaunchAgent
// com.edmundsitumorang.sketchybar-sleep-guard; install.sh sets both up.
// Manual test: `sleep_guard park` / `sleep_guard unpark` run one step and exit.
import AppKit
import Foundation

let uid = getuid()
let service = "gui/\(uid)/sh.brew.sketchybar"
let plist = NSHomeDirectory() + "/Library/LaunchAgents/sh.brew.sketchybar.plist"
let stateDir = NSHomeDirectory() + "/.local/state/sketchybar"
let marker = stateDir + "/parked-by-sleep-guard"
let logFile = stateDir + "/sketchybar.log"
// Shared with wake_restart.sh and watchdog.sh: a fresh stamp tells them a
// restart is already under way.
let guardStamp = (ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory())
    .replacingOccurrences(of: "//", with: "/") + "/sketchybar_wake_restart.stamp"

// Display layout must be unchanged this long before sketchybar starts...
let settleSeconds: TimeInterval = 1.5
// ...but never wait longer than this after a wake (a monitor that keeps
// flapping would otherwise keep the bar off).
let maxWaitSeconds: TimeInterval = 10
let pollInterval: TimeInterval = 0.25

let queue = DispatchQueue(label: "sketchybar-sleep-guard")  // serialises state
var generation = 0  // bumped on every park, so a stale unpark gives up

func log(_ msg: String) {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let line = "\(f.string(from: Date())) [sleep_guard] \(msg)\n"
    if let h = FileHandle(forWritingAtPath: logFile) {
        h.seekToEndOfFile()
        h.write(line.data(using: .utf8)!)
        try? h.close()
    } else {
        FileManager.default.createFile(atPath: logFile, contents: line.data(using: .utf8))
    }
}

@discardableResult
func launchctl(_ args: [String]) -> (Int32, String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    task.arguments = args
    let out = Pipe()
    task.standardOutput = out
    task.standardError = out
    do { try task.run() } catch { return (-1, "\(error)") }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func serviceLoaded() -> Bool { launchctl(["print", service]).0 == 0 }

func touchStamp() {
    FileManager.default.createFile(atPath: guardStamp, contents: nil)
}

// Stop sketchybar before the sleep. Only if it is running: a service the user
// stopped stays stopped, because no marker gets written.
func park(_ reason: String) {
    generation += 1
    guard serviceLoaded() else { return }
    FileManager.default.createFile(atPath: marker, contents: nil)
    touchStamp()
    let (status, out) = launchctl(["bootout", service])
    log("\(reason): stopped sketchybar" + (status == 0 ? "" : " (bootout \(status): \(out.trimmingCharacters(in: .whitespacesAndNewlines)))"))
}

func start(_ reason: String) {
    guard FileManager.default.fileExists(atPath: marker) else { return }
    try? FileManager.default.removeItem(atPath: marker)
    guard FileManager.default.fileExists(atPath: plist) else {
        log("\(reason): \(plist) is gone; leaving sketchybar stopped")
        return
    }
    if serviceLoaded() {
        log("\(reason): sketchybar already running")
        return
    }
    touchStamp()
    let (status, out) = launchctl(["bootstrap", "gui/\(uid)", plist])
    log("\(reason): started sketchybar" + (status == 0 ? "" : " (bootstrap \(status): \(out.trimmingCharacters(in: .whitespacesAndNewlines)))"))
}

// Active displays and where they sit; changes while monitors reconnect.
func displayLayout() -> String {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return "error" }
    return ids.prefix(Int(count)).sorted().map { id -> String in
        let b = CGDisplayBounds(id)
        return "\(id):\(Int(b.origin.x)),\(Int(b.origin.y)),\(Int(b.width))x\(Int(b.height))"
    }.joined(separator: ";")
}

func screensAwake() -> Bool { CGDisplayIsAsleep(CGMainDisplayID()) == 0 }

// Start sketchybar once the screens are on and the layout has held still for
// settleSeconds (or maxWaitSeconds have passed since the wake).
func unparkWhenSettled(_ reason: String) {
    guard FileManager.default.fileExists(atPath: marker) else { return }
    let myGeneration = generation
    let began = Date()
    var layout = displayLayout()
    var stableSince = Date()

    func tick() {
        guard myGeneration == generation else { return }  // slept again meanwhile
        let now = Date()
        guard screensAwake() else {
            // Woke into a dark screen (DarkWake, or the guard started while the
            // display sleeps): check back slowly; screensDidWake also restarts this.
            stableSince = now
            queue.asyncAfter(deadline: .now() + 2, execute: tick)
            return
        }
        let current = displayLayout()
        if current != layout {
            layout = current
            stableSince = now
        }
        let waited = now.timeIntervalSince(began)
        if now.timeIntervalSince(stableSince) >= settleSeconds {
            start("\(reason), displays settled after \(String(format: "%.1f", waited))s")
        } else if waited >= maxWaitSeconds {
            start("\(reason), displays still changing after \(Int(maxWaitSeconds))s")
        } else {
            queue.asyncAfter(deadline: .now() + pollInterval, execute: tick)
        }
    }
    queue.asyncAfter(deadline: .now() + pollInterval, execute: tick)
}

try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)

// One-shot modes for testing.
if CommandLine.arguments.count > 1 {
    switch CommandLine.arguments[1] {
    case "park": park("manual"); exit(0)
    case "unpark": start("manual"); exit(0)
    default: print("usage: sleep_guard [park|unpark]"); exit(2)
    }
}

let center = NSWorkspace.shared.notificationCenter
let sleeps: [(NSNotification.Name, String)] = [
    (NSWorkspace.willSleepNotification, "system sleep"),
    (NSWorkspace.screensDidSleepNotification, "screens off"),
]
let wakes: [(NSNotification.Name, String)] = [
    (NSWorkspace.didWakeNotification, "system wake"),
    (NSWorkspace.screensDidWakeNotification, "screens on"),
]
for (name, reason) in sleeps {
    // Synchronous on purpose: willSleep gives the app a moment before the
    // system sleeps, and bootout returns once the process has exited.
    center.addObserver(forName: name, object: nil, queue: nil) { _ in
        queue.sync { park(reason) }
    }
}
for (name, reason) in wakes {
    center.addObserver(forName: name, object: nil, queue: nil) { _ in
        queue.async { unparkWhenSettled(reason) }
    }
}

// Restarted (crash, reinstall) while sketchybar was parked: bring it back.
queue.async { unparkWhenSettled("guard started") }

RunLoop.main.run()
