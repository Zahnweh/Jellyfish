import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let statusBar = StatusBarController()
    let keyboardMonitor = KeyboardMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        stripQuarantine()
        NSApp.setActivationPolicy(.accessory)
        statusBar.setup()
        keyboardMonitor.start()
        LoginItemManager.enable()
        Updater.checkOnLaunch()
    }

    // TCC persistiert Input-Monitoring-Grants nicht für quarantined Apps.
    // Sparkle hat das früher automatisch bereinigt; ohne Sparkle muss die App es selbst tun.
    private func stripQuarantine() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-dr", "com.apple.quarantine", Bundle.main.bundlePath]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }
}
