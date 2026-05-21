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
        guard let raw = resolveIcon() else { return }
        NSApp.applicationIconImage = padded(raw)
    }

    // Artwork auf 80 % des Canvas verkleinern (10 % Rand auf jeder Seite),
    // damit das Icon optisch mit anderen macOS-App-Icons übereinstimmt.
    private func padded(_ source: NSImage) -> NSImage {
        let pt: CGFloat = 512       // Standard-Dock-Icon-Größe in Punkten
        let inset = pt * 0.10
        source.size = NSSize(width: pt, height: pt)
        let result = NSImage(size: NSSize(width: pt, height: pt))
        result.lockFocus()
        source.draw(in: NSRect(x: inset, y: inset,
                               width: pt - 2 * inset,
                               height: pt - 2 * inset),
                    from: NSRect(origin: .zero, size: source.size),
                    operation: .sourceOver,
                    fraction: 1.0)
        result.unlockFocus()
        return result
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
