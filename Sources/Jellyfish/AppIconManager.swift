import Cocoa

class AppIconManager: NSObject {
    static let shared = AppIconManager()

    override private init() {
        super.init()

        // Dark ↔ Light
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        // macOS 26: Klar / Eingefärbt
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleColorPreferencesChangedNotification"),
            object: nil
        )
        // Fallback: effectiveAppearance auf NSApp per KVO
        NSApp.addObserver(self, forKeyPath: "effectiveAppearance", options: .new, context: nil)
    }

    deinit {
        NSApp.removeObserver(self, forKeyPath: "effectiveAppearance")
    }

    // Nach setActivationPolicy(.regular) aufrufen
    func update() {
        NSApp.applicationIconImage = resolveIcon()
    }

    @objc private func appearanceChanged() {
        DispatchQueue.main.async { self.update() }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "effectiveAppearance" {
            DispatchQueue.main.async { self.update() }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func resolveIcon() -> NSImage? {
        let theme = UserDefaults.standard.string(forKey: "AppleIconAppearanceTheme") ?? ""

        let name: String
        switch true {
        case theme.contains("Clear"), theme.contains("Tinted"), theme.contains("Mono"):
            name = "AppIconMono"
        case theme.contains("Dark"):
            name = "AppIconDark"
        default:
            name = "AppIcon"
        }

        guard let path = Bundle.main.path(forResource: name, ofType: "icns") else { return nil }
        return NSImage(contentsOfFile: path)
    }
}
