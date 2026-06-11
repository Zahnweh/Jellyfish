import Cocoa

// Two-line menu item view: name on top, expansion preview below.
private final class SnippetResultView: NSView {
    static let itemWidth: CGFloat = 230
    static let itemHeight: CGFloat = 42

    private let selectionBg: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .selection
        v.state = .active
        v.isEmphasized = true
        return v
    }()
    private let titleLabel   = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")

    init(snippet: Snippet) {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.itemWidth, height: Self.itemHeight))

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

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 18, y: 22, width: Self.itemWidth - 26, height: 16)
        addSubview(titleLabel)

        previewLabel.stringValue = preview
        previewLabel.font = .systemFont(ofSize: 11)
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.frame = NSRect(x: 18, y: 5, width: Self.itemWidth - 26, height: 14)
        addSubview(previewLabel)

        applyColors(highlighted: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = enclosingMenuItem?.isHighlighted == true
        selectionBg.isHidden = !highlighted
        applyColors(highlighted: highlighted)
        super.draw(dirtyRect)
    }

    private func applyColors(highlighted: Bool) {
        titleLabel.textColor   = highlighted ? .selectedMenuItemTextColor : .labelColor
        previewLabel.textColor = highlighted
            ? .selectedMenuItemTextColor.withAlphaComponent(0.75)
            : .secondaryLabelColor
    }

    // Custom views don't fire the menu item's action on click automatically.
    override func mouseUp(with event: NSEvent) {
        guard let item = enclosingMenuItem,
              let action = item.action,
              let target = item.target else { return }
        NSApp.sendAction(action, to: target, from: item)
    }
}

// Custom container so the search field gets keyboard focus as soon as the menu opens.
private final class MenuSearchContainerView: NSView {
    weak var field: NSSearchField?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let w = window, let f = field else { return }
        w.makeFirstResponder(f)
        // Also async – menu window sometimes isn't key-ready on the first call.
        DispatchQueue.main.async { [weak w, weak f] in
            guard let w, let f else { return }
            w.makeFirstResponder(f)
        }
    }

    // Clicking anywhere in the container focuses the field.
    override func mouseDown(with event: NSEvent) {
        if let f = field { window?.makeFirstResponder(f) }
        super.mouseDown(with: event)
    }
}

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private weak var searchField: NSSearchField?

    // The search field item always lives at index 3 (header/open/sep/search).
    // Results are inserted immediately after it.
    private let searchItemIndex = 3
    private var resultItemCount = 0

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = menuBarIcon()
        }
        buildMenu()
    }

    private func buildMenu() {
        menu = NSMenu()
        menu.delegate = self
        resultItemCount = 0

        let header = NSMenuItem(title: "Jellyfish — Snippets", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let openItem = NSMenuItem(title: "Jellyfish öffnen", action: #selector(openApp), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let searchItem = makeSearchItem()
        searchItem.isEnabled = true
        menu.addItem(searchItem)   // index 3

        // Separator between results (dynamic) and action items below.
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

        statusItem.menu = menu
    }

    private func makeSearchItem() -> NSMenuItem {
        let containerWidth: CGFloat = 230
        let field = NSSearchField(frame: NSRect(x: 8, y: 4, width: containerWidth - 16, height: 22))
        field.placeholderString = "Snippet suchen…"
        field.delegate = self

        let container = MenuSearchContainerView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: 30))
        container.addSubview(field)
        container.field = field
        searchField = field

        let item = NSMenuItem()
        item.view = container
        return item
    }

    // MARK: - Search results

    private func updateResults(for query: String) {
        let insertionBase = searchItemIndex + 1

        // Remove previous results (always at insertionBase as items shift up after each removal).
        for _ in 0..<resultItemCount {
            menu.removeItem(at: insertionBase)
        }
        resultItemCount = 0

        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }

        let ql = q.lowercased()
        // Search by name and expansion text – the trigger is intentionally excluded
        // because the search is for when you don't remember (or don't want) the trigger.
        let matches = SnippetManager.shared.snippets.filter { s in
            s.name.lowercased().contains(ql) ||
            s.expansion.lowercased().contains(ql)
        }.prefix(8)

        if matches.isEmpty {
            let none = NSMenuItem(title: "Keine Treffer", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.insertItem(none, at: insertionBase)
            resultItemCount = 1
        } else {
            for (i, snippet) in matches.enumerated() {
                menu.insertItem(makeSnippetMenuItem(snippet), at: insertionBase + i)
            }
            resultItemCount = matches.count
        }
    }

    private func makeSnippetMenuItem(_ snippet: Snippet) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(useSnippet(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = snippet
        item.view = SnippetResultView(snippet: snippet)
        return item
    }

    // Behaves exactly like a keyboard-triggered expansion: dates, clipboard placeholder,
    // dropdowns, RTF – the full pipeline, just without deleting a trigger first.
    @objc private func useSnippet(_ sender: NSMenuItem) {
        guard let snippet = sender.representedObject as? Snippet else { return }
        menu.cancelTracking()
        // Give the previously focused app a moment to regain keyboard focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AppDelegate.shared?.keyboardMonitor.pasteSnippet(snippet)
        }
    }

    func rebuild() { buildMenu() }

    // MARK: - Menu bar icon

    private func menuBarIcon() -> NSImage {
        let targetSize = NSSize(width: 19, height: 19)
        let fallback = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Jellyfish")!

        guard let url = Bundle.main.url(forResource: "StatusBarTemplate@2x", withExtension: "png"),
              let source = NSImage(contentsOf: url) else { return fallback }

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

    // MARK: - Actions

    @objc private func openApp() { SnippetEditorWindowController.shared.showManageMode() }
    @objc private func addSnippet() { SnippetEditorWindowController.shared.showAddMode() }
    @objc private func manageSnippets() { SnippetEditorWindowController.shared.showManageMode() }
    @objc private func checkForUpdates() { Updater.checkManually() }
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        searchField?.stringValue = ""
        updateResults(for: "")
    }
}

// MARK: - NSSearchFieldDelegate

extension StatusBarController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        updateResults(for: field.stringValue)
    }
}
