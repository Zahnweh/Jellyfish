import Cocoa

// MARK: - Individual result row

private final class SearchResultCellView: NSView {
    static let height: CGFloat = 44

    var onSelect: (() -> Void)?

    private let selectionBg: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .selection
        v.state    = .active
        v.isEmphasized = true
        return v
    }()
    private let titleLabel   = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")

    init(snippet: Snippet) {
        super.init(frame: NSRect(x: 0, y: 0, width: SearchPanel.panelWidth, height: Self.height))

        let title: String
        if snippet.name.isEmpty {
            title = snippet.trigger.isEmpty ? "(kein Name)" : snippet.trigger
        } else if !snippet.trigger.isEmpty {
            title = "\(snippet.name)  ·  \(snippet.trigger)"
        } else {
            title = snippet.name
        }
        let preview = snippet.expansion
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "  ")

        selectionBg.frame = bounds
        selectionBg.autoresizingMask = [.width, .height]
        selectionBg.isHidden = true
        addSubview(selectionBg)

        titleLabel.stringValue    = title
        titleLabel.font           = .systemFont(ofSize: 13)
        titleLabel.lineBreakMode  = .byTruncatingTail
        titleLabel.frame          = NSRect(x: 12, y: 24, width: SearchPanel.panelWidth - 24, height: 16)
        addSubview(titleLabel)

        previewLabel.stringValue   = preview
        previewLabel.font          = .systemFont(ofSize: 11)
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.frame         = NSRect(x: 12, y: 6, width: SearchPanel.panelWidth - 24, height: 14)
        addSubview(previewLabel)

        setHighlighted(false)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        ))
    }

    required init?(coder: NSCoder) { fatalError() }

    func setHighlighted(_ on: Bool) {
        selectionBg.isHidden = !on
        titleLabel.textColor   = on ? .selectedMenuItemTextColor : .labelColor
        previewLabel.textColor = on
            ? .selectedMenuItemTextColor.withAlphaComponent(0.8)
            : .secondaryLabelColor
    }

    override func mouseEntered(with event: NSEvent) { setHighlighted(true) }
    override func mouseExited(with event: NSEvent)  { setHighlighted(false) }
    override func mouseUp(with event: NSEvent)      { onSelect?() }
}

// MARK: - Search field (intercepts ↓ ↑ Enter Esc before the text cell sees them)

private final class PanelSearchField: NSSearchField {
    var onArrowDown: (() -> Void)?
    var onArrowUp:   (() -> Void)?
    var onEnter:     (() -> Void)?
    var onEscape:    (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: onArrowDown?()           // ↓
        case 126: onArrowUp?()             // ↑
        case 36, 76: onEnter?()            // Return / numpad Enter
        case 53:  onEscape?()              // Esc
        default:  super.keyDown(with: event)
        }
    }
}

// MARK: - Search Panel

// NSPanel with .nonactivatingPanel: clicking the panel does NOT activate Jellyfish,
// so the previously focused app keeps keyboard focus → paste lands in the right window.
// canBecomeKey = true gives the search field a standard blue focus ring and cursor.
final class SearchPanel: NSPanel {
    static  let panelWidth:   CGFloat = 260
    private static let fieldH:     CGFloat = 22
    private static let padV:       CGFloat = 11
    private static let searchRowH: CGFloat = padV + fieldH + padV   // 44
    private static let resultRowH: CGFloat = SearchResultCellView.height
    private static let maxResults           = 8

    var onSelect: ((Snippet) -> Void)?

    private let searchField    = PanelSearchField()
    private let resultContainer = NSView()
    private var snippets:       [Snippet] = []
    private var selectedIndex   = -1
    private var clickMonitor:   Any?

    // MARK: Init

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.searchRowH),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        level               = .popUpMenu
        isOpaque            = false
        backgroundColor     = .clear
        hasShadow           = true
        isMovable           = false
        collectionBehavior  = [.transient, .ignoresCycle]
        buildContent()
    }

    override var canBecomeKey: Bool { true }

    // MARK: Content setup

    private func buildContent() {
        // Root container (rounded corners via layer)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.searchRowH))
        root.wantsLayer = true
        root.layer?.cornerRadius = 10
        root.layer?.masksToBounds = true

        let bg = NSVisualEffectView(frame: root.bounds)
        bg.material = .menu
        bg.state    = .active
        bg.autoresizingMask = [.width, .height]
        root.addSubview(bg)

        // Result container (empty, filled dynamically)
        resultContainer.frame = NSRect(x: 0, y: 0, width: Self.panelWidth, height: 0)
        root.addSubview(resultContainer)

        // Search field
        searchField.placeholderString = "Snippet suchen…"
        searchField.frame = NSRect(
            x: 10, y: Self.padV,
            width: Self.panelWidth - 20, height: Self.fieldH
        )
        searchField.delegate   = self
        searchField.onArrowDown = { [weak self] in self?.moveSelection(by: +1) }
        searchField.onArrowUp   = { [weak self] in self?.moveSelection(by: -1) }
        searchField.onEnter     = { [weak self] in self?.confirmSelection() }
        searchField.onEscape    = { [weak self] in self?.dismiss() }
        root.addSubview(searchField)

        contentView = root
    }

    // MARK: Show / Dismiss

    func show(near button: NSButton) {
        guard let win = button.window else { return }
        let btnScreen = win.convertToScreen(button.convert(button.bounds, to: nil))

        searchField.stringValue = ""
        updateResults(query: "")

        let maxX = (NSScreen.main?.frame.maxX ?? 1920) - Self.panelWidth - 4
        let x = max(4, min(btnScreen.midX - Self.panelWidth / 2, maxX))
        setFrameOrigin(NSPoint(x: x, y: btnScreen.minY - Self.searchRowH - 6))

        makeKeyAndOrderFront(nil)
        makeFirstResponder(searchField)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in self?.dismiss() }
    }

    func dismiss() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        orderOut(nil)
    }

    // MARK: Results

    private func updateResults(query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        snippets = q.isEmpty ? [] : Array(
            SnippetManager.shared.snippets.filter {
                let ql = q.lowercased()
                return $0.name.lowercased().contains(ql) || $0.expansion.lowercased().contains(ql)
            }.prefix(Self.maxResults)
        )
        selectedIndex = -1
        rebuildResultViews()
        resize()
    }

    private func rebuildResultViews() {
        resultContainer.subviews.forEach { $0.removeFromSuperview() }
        for (i, snippet) in snippets.enumerated() {
            let cell = SearchResultCellView(snippet: snippet)
            // In AppKit y=0 is at the bottom; first result at top → highest y value.
            let y = CGFloat(snippets.count - 1 - i) * Self.resultRowH
            cell.frame = NSRect(x: 0, y: y, width: Self.panelWidth, height: Self.resultRowH)
            cell.onSelect = { [weak self] in
                self?.dismiss()
                self?.onSelect?(snippet)
            }
            resultContainer.addSubview(cell)
        }
    }

    private func resize() {
        let resultH = CGFloat(snippets.count) * Self.resultRowH
        let sepH: CGFloat = snippets.isEmpty ? 0 : 1
        let newH = Self.searchRowH + sepH + resultH

        // Anchor the panel's TOP edge to the status bar button: adjust origin as height grows.
        var pf = frame
        pf.origin.y   -= (newH - pf.height)
        pf.size.height = newH
        setFrame(pf, display: true)

        guard let root = contentView else { return }

        // Update root + background to fill the new window size.
        root.frame = NSRect(x: 0, y: 0, width: Self.panelWidth, height: newH)
        root.subviews.first?.frame = root.bounds   // NSVisualEffectView background

        // Search field stays visually at the TOP (high y in AppKit coords).
        searchField.frame = NSRect(
            x: 10, y: newH - Self.padV - Self.fieldH,
            width: Self.panelWidth - 20, height: Self.fieldH
        )

        // Result container fills everything below the search field.
        resultContainer.frame = NSRect(x: 0, y: sepH, width: Self.panelWidth, height: resultH)

        // Separator between results and search row.
        root.layer?.sublayers = root.layer?.sublayers?.filter { $0.name != "sep" }
        if !snippets.isEmpty {
            let sep = CALayer()
            sep.name            = "sep"
            sep.frame           = CGRect(x: 0, y: resultH, width: Self.panelWidth, height: 1)
            sep.backgroundColor = NSColor.separatorColor.cgColor
            root.layer?.addSublayer(sep)
        }
    }

    // MARK: Keyboard navigation

    private func moveSelection(by delta: Int) {
        guard !snippets.isEmpty else { return }
        let newIndex = max(0, min(snippets.count - 1, selectedIndex + delta))
        highlightIndex(newIndex)
    }

    private func highlightIndex(_ index: Int) {
        // Clear previous
        resultContainer.subviews.compactMap { $0 as? SearchResultCellView }
            .forEach { $0.setHighlighted(false) }
        selectedIndex = index
        let cell = resultContainer.subviews[snippets.count - 1 - index] as? SearchResultCellView
        cell?.setHighlighted(true)
    }

    private func confirmSelection() {
        guard selectedIndex >= 0, selectedIndex < snippets.count else { return }
        let snippet = snippets[selectedIndex]
        dismiss()
        onSelect?(snippet)
    }

    override func close() {
        dismiss()
        super.close()
    }
}

// MARK: - SearchPanel: NSSearchFieldDelegate

extension SearchPanel: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let f = obj.object as? NSSearchField else { return }
        updateResults(query: f.stringValue)
    }
}

// MARK: - StatusBarController

class StatusBarController: NSObject {
    private var statusItem:  NSStatusItem!
    private var menu:        NSMenu!
    private var searchPanel: SearchPanel!

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image  = menuBarIcon()
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        buildMenu()
        searchPanel = SearchPanel()
        searchPanel.onSelect = { [weak self] snippet in
            self?.expandSnippet(snippet)
        }
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

        let quitItem = NSMenuItem(title: "Jellyfish beenden",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // Temporarily attach the menu so macOS shows it with native status-bar styling.
            // When statusItem.menu is set, performClick shows the menu (not the action).
            statusItem.menu = menu
            sender.performClick(nil)   // blocks until menu is dismissed
            statusItem.menu = nil      // clear so left-click still opens the panel
        } else {
            if searchPanel.isVisible {
                searchPanel.dismiss()
            } else {
                searchPanel.show(near: sender)
            }
        }
    }

    private func expandSnippet(_ snippet: Snippet) {
        // .nonactivatingPanel means the previously focused app never lost focus.
        // A brief delay lets the panel fully close before Cmd+V fires.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            AppDelegate.shared?.keyboardMonitor.pasteSnippet(snippet)
        }
    }

    func rebuild() {
        searchPanel?.dismiss()
        buildMenu()
    }

    // MARK: - Menu bar icon

    private func menuBarIcon() -> NSImage {
        let targetSize = NSSize(width: 19, height: 19)
        let fallback = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Jellyfish")!

        guard let url = Bundle.main.url(forResource: "StatusBarTemplate@2x", withExtension: "png"),
              let source = NSImage(contentsOf: url) else { return fallback }

        let srcW  = source.size.width
        let srcH  = source.size.height
        let scale = targetSize.height / srcH
        let drawW = srcW * scale
        let drawRect = NSRect(
            x: (targetSize.width - drawW) / 2,
            y: 0, width: drawW, height: targetSize.height
        )

        let icon = NSImage(size: targetSize)
        icon.lockFocus()
        source.draw(in: drawRect, from: NSRect(origin: .zero, size: source.size),
                    operation: .sourceOver, fraction: 1.0)
        icon.unlockFocus()
        icon.isTemplate = true
        return icon
    }

    // MARK: - Actions

    @objc private func openApp()         { SnippetEditorWindowController.shared.showManageMode() }
    @objc private func addSnippet()      { SnippetEditorWindowController.shared.showAddMode() }
    @objc private func manageSnippets()  { SnippetEditorWindowController.shared.showManageMode() }
    @objc private func checkForUpdates() { Updater.checkManually() }
}
