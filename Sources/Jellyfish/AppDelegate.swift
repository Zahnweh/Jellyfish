import Cocoa
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let statusBar = StatusBarController()
    let keyboardMonitor = KeyboardMonitor()
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        statusBar.setup()
        keyboardMonitor.start()
        LoginItemManager.enable()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
