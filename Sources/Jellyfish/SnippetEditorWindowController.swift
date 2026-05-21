import Cocoa

class SnippetEditorWindowController: NSObject, NSWindowDelegate {
    static let shared = SnippetEditorWindowController()

    private var window: NSWindow?
    private var triggerField: NSTextField!
    private var expansionView: NSTextView!
    private var tableView: NSTableView!
    private var editingSnippet: Snippet?
    private var mode: Mode = .manage

    enum Mode { case add, manage }

    func showAddMode() {
        editingSnippet = nil
        mode = .add
        present()
    }

    func showManageMode() {
        editingSnippet = nil
        mode = .manage
        present()
    }

    private func present() {
        if window == nil { buildWindow() }
        updateUI()
        // Policy-Wechsel: Dock-Icon einblenden.
        // Icon und Tap danach setzen – macOS 26 deaktiviert beides beim Wechsel.
        NSApp.setActivationPolicy(.regular)
        AppIconManager.shared.update()
        installMainMenu()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Jellyfish beenden",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appItem.submenu = appMenu

        let fileItem = NSMenuItem(); mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "Ablage")
        fileMenu.addItem(NSMenuItem(title: "Schließen",
                                    action: #selector(NSWindow.performClose(_:)),
                                    keyEquivalent: "w"))
        fileItem.submenu = fileMenu

        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Jellyfish — Snippets"
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.center()
        w.contentView = buildContentView()
        window = w
    }

    private func buildContentView() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 420))

        // Left: table of snippets
        let scrollView = NSScrollView(frame: NSRect(x: 12, y: 60, width: 200, height: 348))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.height]

        tableView = NSTableView()
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("trigger"))
        col.title = "Trigger"
        col.width = 180
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(tableRowSelected)

        scrollView.documentView = tableView
        root.addSubview(scrollView)

        // Buttons below table
        let addBtn = NSButton(title: "+", target: self, action: #selector(addRow))
        addBtn.frame = NSRect(x: 12, y: 32, width: 36, height: 24)
        root.addSubview(addBtn)

        let delBtn = NSButton(title: "−", target: self, action: #selector(deleteRow))
        delBtn.frame = NSRect(x: 52, y: 32, width: 36, height: 24)
        root.addSubview(delBtn)

        // Right: editor
        let triggerLabel = NSTextField(labelWithString: "Trigger:")
        triggerLabel.frame = NSRect(x: 224, y: 368, width: 60, height: 20)
        root.addSubview(triggerLabel)

        triggerField = NSTextField(frame: NSRect(x: 290, y: 365, width: 218, height: 24))
        triggerField.placeholderString = "z. B. mfg#"
        root.addSubview(triggerField)

        let expansionLabel = NSTextField(labelWithString: "Text:")
        expansionLabel.frame = NSRect(x: 224, y: 330, width: 60, height: 20)
        root.addSubview(expansionLabel)

        let expScrollView = NSScrollView(frame: NSRect(x: 224, y: 100, width: 284, height: 220))
        expScrollView.hasVerticalScroller = true
        expScrollView.borderType = .bezelBorder
        expansionView = NSTextView(frame: expScrollView.bounds)
        expansionView.isEditable = true
        expansionView.autoresizingMask = [.width, .height]
        expansionView.font = NSFont.systemFont(ofSize: 13)
        expScrollView.documentView = expansionView
        root.addSubview(expScrollView)

        let saveBtn = NSButton(title: "Speichern", target: self, action: #selector(save))
        saveBtn.frame = NSRect(x: 390, y: 60, width: 118, height: 28)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        root.addSubview(saveBtn)

        return root
    }

    private func updateUI() {
        tableView.reloadData()
        triggerField.stringValue = editingSnippet?.trigger ?? ""
        expansionView.string = editingSnippet?.expansion ?? ""
    }

    @objc private func tableRowSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < SnippetManager.shared.snippets.count else { return }
        editingSnippet = SnippetManager.shared.snippets[row]
        triggerField.stringValue = editingSnippet!.trigger
        expansionView.string = editingSnippet!.expansion
    }

    @objc private func addRow() {
        editingSnippet = nil
        triggerField.stringValue = ""
        expansionView.string = ""
        triggerField.becomeFirstResponder()
    }

    @objc private func deleteRow() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        SnippetManager.shared.remove(at: row)
        tableView.reloadData()
        editingSnippet = nil
        triggerField.stringValue = ""
        expansionView.string = ""
        AppDelegate.shared?.statusBar.rebuild()
    }

    @objc private func save() {
        let trigger = triggerField.stringValue.trimmingCharacters(in: .whitespaces)
        let expansion = expansionView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trigger.isEmpty, !expansion.isEmpty else { return }

        if var existing = editingSnippet {
            existing.trigger = trigger
            existing.expansion = expansion
            SnippetManager.shared.update(existing)
        } else {
            SnippetManager.shared.add(Snippet(trigger: trigger, expansion: expansion))
        }
        tableView.reloadData()
        AppDelegate.shared?.statusBar.rebuild()
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
            AppDelegate.shared?.keyboardMonitor.ensureEnabled()
        }
    }
}

extension SnippetEditorWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        SnippetManager.shared.snippets.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: SnippetManager.shared.snippets[row].trigger)
        cell.identifier = NSUserInterfaceItemIdentifier("cell")
        return cell
    }
}
