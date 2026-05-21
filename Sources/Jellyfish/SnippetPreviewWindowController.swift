import Cocoa

final class SnippetPreviewWindowController: NSObject, NSWindowDelegate {
    static let shared = SnippetPreviewWindowController()
    private override init() {}

    private var panel: NSPanel?
    private var completion: ((String) -> Void)?
    private var template: String = ""
    private var popups: [NSPopUpButton] = []
    private weak var previewText: NSTextView?

    // MARK: - Public API

    func show(expansion: String, completion: @escaping (String) -> Void) {
        panel?.close()
        self.completion = completion
        self.template = expansion
        self.popups = []

        let placeholders = DropdownPlaceholder.parse(in: expansion)
        let p = buildPanel(placeholders: placeholders)
        self.panel = p
        updatePreview()
        p.center()
        p.makeKeyAndOrderFront(nil)
    }

    // MARK: - Panel construction

    private func buildPanel(placeholders: [DropdownPlaceholder]) -> NSPanel {
        let pad: CGFloat = 20
        let innerWidth: CGFloat = 380
        let labelColumnWidth: CGFloat = 80

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = NSTextField(labelWithString: "Textbaustein ausfüllen")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(titleLabel)

        // Preview section header
        let previewHeader = NSTextField(labelWithString: "Vorschau:")
        previewHeader.font = NSFont.systemFont(ofSize: 11)
        previewHeader.textColor = .secondaryLabelColor
        previewHeader.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(previewHeader)

        // Preview scroll + text view
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.font = NSFont.systemFont(ofSize: 13)
        tv.textContainerInset = NSSize(width: 4, height: 4)
        previewText = tv

        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.borderType = .bezelBorder
        sv.documentView = tv
        sv.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sv)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            previewHeader.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            previewHeader.leadingAnchor.constraint(equalTo: content.leadingAnchor),

            sv.topAnchor.constraint(equalTo: previewHeader.bottomAnchor, constant: 4),
            sv.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            sv.heightAnchor.constraint(equalToConstant: 90),
        ])

        // Dropdown rows
        var prevAnchor = sv.bottomAnchor
        var prevGap: CGFloat = 14

        for (i, ph) in placeholders.enumerated() {
            let rowLabel = NSTextField(labelWithString: "Auswahl \(i + 1):")
            rowLabel.font = NSFont.systemFont(ofSize: 13)
            rowLabel.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(rowLabel)

            let popup = NSPopUpButton()
            popup.addItems(withTitles: ph.options)
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.target = self
            popup.action = #selector(popupChanged)
            content.addSubview(popup)
            popups.append(popup)

            NSLayoutConstraint.activate([
                rowLabel.topAnchor.constraint(equalTo: prevAnchor, constant: prevGap),
                rowLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                rowLabel.widthAnchor.constraint(equalToConstant: labelColumnWidth),

                popup.centerYAnchor.constraint(equalTo: rowLabel.centerYAnchor),
                popup.leadingAnchor.constraint(equalTo: rowLabel.trailingAnchor, constant: 8),
                popup.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            ])

            prevAnchor = rowLabel.bottomAnchor
            prevGap = 8
        }

        // Buttons
        let cancelBtn = NSButton(title: "Abbrechen", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1B}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(cancelBtn)

        let insertBtn = NSButton(title: "Einfügen", target: self, action: #selector(insert))
        insertBtn.bezelStyle = .rounded
        insertBtn.keyEquivalent = "\r"
        insertBtn.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(insertBtn)

        NSLayoutConstraint.activate([
            insertBtn.topAnchor.constraint(equalTo: prevAnchor, constant: prevGap + 6),
            insertBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            insertBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            cancelBtn.centerYAnchor.constraint(equalTo: insertBtn.centerYAnchor),
            cancelBtn.trailingAnchor.constraint(equalTo: insertBtn.leadingAnchor, constant: -8),
        ])

        // Wrapper with padding
        let wrapper = NSView()
        wrapper.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: pad),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: pad),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -pad),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -pad),
            content.widthAnchor.constraint(equalToConstant: innerWidth),
        ])

        // Size the panel by computing the content's fitting height
        wrapper.frame = CGRect(x: 0, y: 0, width: innerWidth + pad * 2, height: 600)
        wrapper.layoutSubtreeIfNeeded()
        let fittingH = content.fittingSize.height
        let panelH = max(fittingH + pad * 2, 200)
        let panelW = innerWidth + pad * 2

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.title = "Textbaustein"
        p.isFloatingPanel = true
        p.level = NSWindow.Level.floating
        p.contentView = wrapper
        p.delegate = self
        p.isReleasedWhenClosed = false
        return p
    }

    // MARK: - Actions

    @objc private func popupChanged() { updatePreview() }

    @objc private func insert() {
        let selections = popups.map { $0.selectedItem?.title ?? "" }
        let resolved = DropdownPlaceholder.resolve(text: template, selections: selections)
        let cb = completion
        dismiss()
        // Short delay for panel close animation; original app stays active (non-activating panel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cb?(resolved)
        }
    }

    @objc private func cancel() { dismiss() }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        completion = nil
        popups = []
        AppDelegate.shared?.keyboardMonitor.ensureEnabled()
    }

    // MARK: - Helpers

    private func updatePreview() {
        guard let storage = previewText?.textStorage else { return }
        storage.setAttributedString(buildHighlightedPreview())
    }

    private func buildHighlightedPreview() -> NSAttributedString {
        let baseFont = NSFont.systemFont(ofSize: 13)
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ]
        let highlightAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor,
            .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.12),
        ]

        let result = NSMutableAttributedString()
        var remaining = template
        let placeholders = DropdownPlaceholder.parse(in: template)
        let selections = popups.map { $0.selectedItem?.title ?? "" }

        for (i, ph) in placeholders.enumerated() {
            guard let range = remaining.range(of: ph.rawValue) else { continue }
            let before = String(remaining[remaining.startIndex..<range.lowerBound])
            if !before.isEmpty {
                result.append(NSAttributedString(string: before, attributes: baseAttrs))
            }
            let chosen = i < selections.count ? selections[i] : (ph.options.first ?? "")
            if !chosen.isEmpty {
                result.append(NSAttributedString(string: chosen, attributes: highlightAttrs))
            }
            remaining = String(remaining[range.upperBound...])
        }
        if !remaining.isEmpty {
            result.append(NSAttributedString(string: remaining, attributes: baseAttrs))
        }
        return result
    }

    private func dismiss() {
        let p = panel
        panel = nil
        completion = nil
        popups = []
        p?.close()
    }
}
