import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let statusBar = StatusBarController()
    let keyboardMonitor = KeyboardMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        statusBar.setup()
        keyboardMonitor.start()
        LoginItemManager.enable()
        Updater.checkOnLaunch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }
}
