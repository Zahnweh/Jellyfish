import Cocoa

final class SnippetPreviewWindowController: NSObject, NSWindowDelegate {
    static let shared = SnippetPreviewWindowController()
    private override init() {}

    private var panel: NSPanel?
    private var completion: ((String) -> Void)?
    private var template: String = ""
    private var popups: [any DropdownControl] = []
    private var popupGroups: [Int?] = []   // parallel to popups
    private var checkboxes: [NSButton] = []
    private var optionalBlocks: [OptionalBlock] = []
    private weak var previewText: NSTextView?

    private static let blockColorPalette: [NSColor] = [
        .systemGreen, .systemBlue, .systemOrange,
        .systemPurple, .systemTeal, .systemPink,
    ]
    private var optionalBlockColors: [NSColor] = []

    // MARK: - Public API

    func show(expansion: String, completion: @escaping (String) -> Void) {
        panel?.close()
        self.completion = completion
        self.template = expansion
        self.popups = []
        self.popupGroups = []
        self.checkboxes = []
        self.optionalBlocks = []
        self.optionalBlockColors = []

        let placeholders = DropdownPlaceholder.parse(in: expansion)
        let p = buildPanel(placeholders: placeholders)
        self.panel = p
        updatePreview()
        p.center()
        p.makeKeyAndOrderFront(nil)
    }

    // MARK: - Panel construction

    private func buildPanel(placeholders: [DropdownPlaceholder]) -> NSPanel {
        let optionals = OptionalPlaceholder.parse(in: template)
        self.optionalBlocks = optionals

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetPanelW = floor(screenFrame.width * 0.5)
        let targetPanelH = floor(screenFrame.height * 0.7)
        let pad: CGFloat = 20
        let innerWidth: CGFloat = targetPanelW - pad * 2
        let labelColumnWidth: CGFloat = 80

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = NSTextField(labelWithString: "Textbaustein ausfüllen")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(titleLabel)

        // Preview header
        let previewHeader = NSTextField(labelWithString: "Vorschau:")
        previewHeader.font = NSFont.systemFont(ofSize: 11)
        previewHeader.textColor = .secondaryLabelColor
        previewHeader.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(previewHeader)

        // Preview text view
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.font = NSFont.systemFont(ofSize: 13)
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        previewText = tv

        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.borderType = .bezelBorder
        sv.documentView = tv
        sv.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sv)

        let svHeightConstraint = sv.heightAnchor.constraint(equalToConstant: 90)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            previewHeader.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            previewHeader.leadingAnchor.constraint(equalTo: content.leadingAnchor),

            sv.topAnchor.constraint(equalTo: previewHeader.bottomAnchor, constant: 4),
            sv.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            svHeightConstraint,
        ])

        var prevAnchor = sv.bottomAnchor
        var prevGap: CGFloat = 14

        // Dropdown rows
        for (i, ph) in placeholders.enumerated() {
            let labelText = ph.groupId.map { "Gruppe \($0):" } ?? "Auswahl \(i + 1):"
            let rowLabel = NSTextField(labelWithString: labelText)
            rowLabel.font = NSFont.systemFont(ofSize: 13)
            rowLabel.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(rowLabel)

            // Ab 10 Optionen: Suchfeld-Dropdown, darunter: klassisches Menü
            let searchThreshold = 10
            let dropControl: NSControl & DropdownControl
            if ph.options.count > searchThreshold {
                let btn = SearchablePopupButton(frame: .zero)
                btn.bezelStyle = .rounded
                btn.target = self
                btn.action = #selector(popupChanged(_:))
                btn.configure(options: ph.options)
                dropControl = btn
            } else {
                let popup = NSPopUpButton()
                let menu = NSMenu()
                for option in ph.options {
                    menu.addItem(NSMenuItem(title: option, action: nil, keyEquivalent: ""))
                }
                popup.menu = menu
                popup.target = self
                popup.action = #selector(popupChanged(_:))
                dropControl = popup
            }
            dropControl.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(dropControl)
            popups.append(dropControl)
            popupGroups.append(ph.groupId)

            NSLayoutConstraint.activate([
                rowLabel.topAnchor.constraint(equalTo: prevAnchor, constant: prevGap),
                rowLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                rowLabel.widthAnchor.constraint(equalToConstant: labelColumnWidth),

                dropControl.centerYAnchor.constraint(equalTo: rowLabel.centerYAnchor),
                dropControl.leadingAnchor.constraint(equalTo: rowLabel.trailingAnchor, constant: 8),
                dropControl.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            ])
            prevAnchor = rowLabel.bottomAnchor
            prevGap = 8
        }

        // Separator between dropdowns and optionals (only when both present)
        if !optionals.isEmpty && !placeholders.isEmpty {
            let sep = NSBox()
            sep.boxType = .separator
            sep.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.topAnchor.constraint(equalTo: prevAnchor, constant: prevGap + 4),
                sep.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                sep.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                sep.heightAnchor.constraint(equalToConstant: 1),
            ])
            prevAnchor = sep.bottomAnchor
            prevGap = 10
        }

        // Optional block checkboxes
        for (i, block) in optionals.enumerated() {
            let blockColor = Self.blockColorPalette[i % Self.blockColorPalette.count]
            optionalBlockColors.append(blockColor)
            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxChanged))
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: blockColor,
                .font: NSFont.systemFont(ofSize: 13),
            ]
            cb.attributedTitle = NSAttributedString(string: block.label, attributes: titleAttrs)
            // Group-bound blocks: initial state = index 0 in group
            if let binding = block.groupBinding {
                cb.state = binding.includedIndices.contains(0) ? .on : .off
            } else {
                cb.state = .on
            }
            cb.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(cb)
            checkboxes.append(cb)

            NSLayoutConstraint.activate([
                cb.topAnchor.constraint(equalTo: prevAnchor, constant: prevGap),
                cb.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            ])
            prevAnchor = cb.bottomAnchor
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

        wrapper.frame = CGRect(x: 0, y: 0, width: targetPanelW, height: 1200)
        wrapper.layoutSubtreeIfNeeded()
        let fittingH = content.fittingSize.height
        let extraH = max(targetPanelH - (fittingH + pad * 2), 0)
        svHeightConstraint.constant += extraH
        let panelH = max(fittingH + extraH + pad * 2, 300)
        let panelW = targetPanelW

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

    @objc private func popupChanged(_ sender: AnyObject) {
        guard let senderIdx = popups.firstIndex(where: { $0 === sender }) else {
            updatePreview(); return
        }
        let chosenTitle = popups[senderIdx].selectedTitle
        // Sync: nur bei Gruppen-Dropdowns
        if let groupId = senderIdx < popupGroups.count ? popupGroups[senderIdx] : nil {
            for (i, popup) in popups.enumerated() {
                guard i != senderIdx else { continue }
                let iGroup: Int? = i < popupGroups.count ? popupGroups[i] : nil
                guard iGroup == groupId else { continue }
                popup.selectOption(chosenTitle)
            }
            // Gruppen-gebundene Checkboxen synchronisieren
            // Wir brauchen den Index der gewählten Option in der Original-Liste
            if let ph = DropdownPlaceholder.parse(in: template)[safe: senderIdx],
               let selIdx = ph.options.firstIndex(of: chosenTitle) {
                for (i, block) in optionalBlocks.enumerated() {
                    guard let binding = block.groupBinding, binding.groupId == groupId else { continue }
                    checkboxes[safe: i]?.state = binding.includedIndices.contains(selIdx) ? .on : .off
                }
            }
        }
        updatePreview()
    }
    @objc private func checkboxChanged() { updatePreview() }

    @objc private func insert() {
        let dropSelections = popups.map { $0.selectedTitle }
        let included = Set(checkboxes.indices.filter { checkboxes[$0].state == .on })
        var resolved = DropdownPlaceholder.resolve(text: template, selections: dropSelections)
        resolved = OptionalPlaceholder.resolve(text: resolved, included: included)
        let cb = completion
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cb?(resolved)
        }
    }

    @objc private func cancel() { dismiss() }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        completion = nil
        popups = []
        popupGroups = []
        checkboxes = []
        optionalBlocks = []
        optionalBlockColors = []
        AppDelegate.shared?.keyboardMonitor.ensureEnabled()
        SearchablePopupButton.activePickerPanel?.close()
        SearchablePopupButton.activePickerPanel = nil
    }

    // MARK: - Preview

    private func updatePreview() {
        guard let storage = previewText?.textStorage else { return }
        storage.setAttributedString(buildHighlightedPreview())
    }

    private func buildHighlightedPreview() -> NSAttributedString {
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
        ]
        let dropdownAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor,
            .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.12),
        ]
        let dropdowns = DropdownPlaceholder.parse(in: template)
        let optionals  = OptionalPlaceholder.parse(in: template)
        let dropSel = popups.map { $0.selectedTitle }
        let included   = Set(checkboxes.indices.filter { checkboxes[$0].state == .on })

        // Collect all special spans (range in template → attributed replacement).
        // Search sequentially so duplicate rawValues map to the correct occurrence.
        var spans: [(Range<String.Index>, NSAttributedString)] = []

        var dropSearchFrom = template.startIndex
        for (i, ph) in dropdowns.enumerated() {
            if let r = template.range(of: ph.rawValue, range: dropSearchFrom..<template.endIndex) {
                let chosen = i < dropSel.count ? dropSel[i] : (ph.options.first ?? "")
                spans.append((r, NSAttributedString(string: chosen, attributes: dropdownAttrs)))
                dropSearchFrom = r.upperBound
            }
        }
        var optSearchFrom = template.startIndex
        for (i, block) in optionals.enumerated() {
            if let r = template.range(of: block.rawValue, range: optSearchFrom..<template.endIndex) {
                let color = optionalBlockColors.indices.contains(i)
                    ? optionalBlockColors[i] : .systemGreen
                let includedAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: color,
                    .backgroundColor: color.withAlphaComponent(0.12),
                ]
                let excludedAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: color.withAlphaComponent(0.45),
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: color.withAlphaComponent(0.45),
                ]
                let attrs = included.contains(i) ? includedAttrs : excludedAttrs
                spans.append((r, NSAttributedString(string: block.content, attributes: attrs)))
                optSearchFrom = r.upperBound
            }
        }
        spans.sort { $0.0.lowerBound < $1.0.lowerBound }

        let result = NSMutableAttributedString()
        var pos = template.startIndex
        for (range, rendered) in spans {
            if pos < range.lowerBound {
                result.append(NSAttributedString(string: String(template[pos..<range.lowerBound]),
                                                  attributes: baseAttrs))
            }
            result.append(rendered)
            pos = range.upperBound
        }
        if pos < template.endIndex {
            result.append(NSAttributedString(string: String(template[pos...]), attributes: baseAttrs))
        }
        return result
    }

    // MARK: - Helpers

    private func dismiss() {
        let p = panel
        panel = nil
        completion = nil
        popups = []
        popupGroups = []
        checkboxes = []
        optionalBlocks = []
        optionalBlockColors = []
        p?.close()
    }
}
