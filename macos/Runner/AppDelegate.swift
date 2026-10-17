import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    killDaemonIfNeeded()
  }

  private func killDaemonIfNeeded() {
    let supportPath = (NSHomeDirectory() as NSString)
      .appendingPathComponent("Library/Application Support/beenut")
    let pidPath = (supportPath as NSString).appendingPathComponent("beenutd.pid")
    let configPath = (supportPath as NSString).appendingPathComponent("config.json")
    let pidFile = URL(fileURLWithPath: pidPath)
    if let pidText = try? String(contentsOf: pidFile, encoding: .utf8),
       let pid = Int(pidText.trimmingCharacters(in: .whitespacesAndNewlines)) {
      runProcess("/bin/kill", arguments: ["-TERM", "\(pid)"])
      try? FileManager.default.removeItem(at: pidFile)
    }

    let bundledDaemonPath = Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/beenutd")
      .path
    let copiedDaemonPath = (supportPath as NSString).appendingPathComponent("bin/beenutd")

    // Send SIGTERM to both daemon types to trigger graceful shutdown simultaneously
    sendSignalToDaemons(signal: "-TERM", paths: [bundledDaemonPath, copiedDaemonPath], configPath: configPath)

    // Small grace period of 50ms to let them process SIGTERM
    usleep(50_000)

    // Force kill if they are still running
    sendSignalToDaemons(signal: "-KILL", paths: [bundledDaemonPath, copiedDaemonPath], configPath: configPath)

    for path in [
      "/tmp/beenutd.sock",
      "/tmp/beenut-preview.sock",
      "/tmp/beenut-preview.sock.dmabuf",
    ] {
      try? FileManager.default.removeItem(atPath: path)
    }
  }

  private func sendSignalToDaemons(signal: String, paths: [String], configPath: String) {
    for daemonPath in paths {
      let pattern = "\(NSRegularExpression.escapedPattern(for: daemonPath)).*--config \(NSRegularExpression.escapedPattern(for: configPath))"
      runProcess("/usr/bin/pkill", arguments: [signal, "-f", pattern])
    }
  }

  private func runProcess(_ executablePath: String, arguments: [String]) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executablePath)
    task.arguments = arguments
    try? task.run()
    task.waitUntilExit()
  }
}
