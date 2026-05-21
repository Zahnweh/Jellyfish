import Cocoa

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let url = Bundle.module.url(forResource: "StatusBarTemplate@2x", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                // Tell AppKit this is a @2x asset so it renders at half logical size
                image.size = NSSize(width: image.size.width / 2, height: image.size.height / 2)
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Jellyfish")
            }
        }
        buildMenu()
    }

    private func buildMenu() {
        menu = NSMenu()

        let header = NSMenuItem(title: "Jellyfish — Snippets", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
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

        let updateItem = NSMenuItem(title: "Nach Updates suchen…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let quitItem = NSMenuItem(title: "Jellyfish beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func rebuild() { buildMenu() }

    @objc private func addSnippet() { SnippetEditorWindowController.shared.showAddMode() }
    @objc private func manageSnippets() { SnippetEditorWindowController.shared.showManageMode() }
    @objc private func checkForUpdates() { AppDelegate.shared?.checkForUpdates() }
}
