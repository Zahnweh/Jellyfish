import Cocoa

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = menuBarIcon()
        }
        buildMenu()
    }

    private func buildMenu() {
        menu = NSMenu()

        let header = NSMenuItem(title: "Jellyfish — Snippets", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let openItem = NSMenuItem(title: "Jellyfish öffnen", action: #selector(openApp), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        for (i, snippet) in SnippetManager.shared.snippets.enumerated() {
            let preview = snippet.expansion.prefix(40).replacingOccurrences(of: "\n", with: " ")
            let item = NSMenuItem(title: "\(snippet.trigger)  →  \(preview)", action: nil, keyEquivalent: "")
            item.tag = i
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let addItem = NSMenuItem(title: "Snippet hinzufügen…", action: #selector(addSnippet), keyEquivalent: "n")
        addItem.target = self
        menu.addItem(addItem)

        let editItem = NSMenuItem(title: "Snippets verwalten…", action: #selector(manageSnippets), keyEquivalent: ",")
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: "Releases auf GitHub…", action: #selector(openReleases), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let quitItem = NSMenuItem(title: "Jellyfish beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func rebuild() { buildMenu() }

    // Jellyfish-Portrait zentriert in einem 22×22-Quadrat (Standard-Menüleisten-Größe)
    private func menuBarIcon() -> NSImage {
        let targetSize = NSSize(width: 19, height: 19)
        let fallback = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Jellyfish")!

        guard let url = Bundle.module.url(forResource: "StatusBarTemplate@2x", withExtension: "png"),
              let source = NSImage(contentsOf: url) else { return fallback }

        // Skaliere auf 22pt Höhe, zentriere horizontal
        let srcW = source.size.width
        let srcH = source.size.height
        let scale = targetSize.height / srcH
        let drawW = srcW * scale
        let drawRect = NSRect(
            x: (targetSize.width - drawW) / 2,
            y: 0,
            width: drawW,
            height: targetSize.height
        )

        let icon = NSImage(size: targetSize)
        icon.lockFocus()
        source.draw(in: drawRect, from: NSRect(origin: .zero, size: source.size),
                    operation: .sourceOver, fraction: 1.0)
        icon.unlockFocus()
        icon.isTemplate = true
        return icon
    }

    @objc private func openApp() { SnippetEditorWindowController.shared.showManageMode() }
    @objc private func addSnippet() { SnippetEditorWindowController.shared.showAddMode() }
    @objc private func manageSnippets() { SnippetEditorWindowController.shared.showManageMode() }
    @objc private func openReleases() {
        NSWorkspace.shared.open(URL(string: "https://github.com/Zahnweh/Jellyfish/releases")!)
    }
}
