import Cocoa

// MARK: - Sheet controller

final class ConditionalBlockSheetController: NSViewController {
    var onApply: ((String) -> Void)?
    var expansionText: String = ""

    private var options: [String] = ["", ""]

    private struct BlockData {
        let id: UUID
        var label: String
        var content: String
        var included: Set<Int>

        init(label: String = "", content: String = "", included: Set<Int> = []) {
            self.id = UUID()
            self.label = label
            self.content = content
            self.included = included
        }
    }
    private var blocks: [BlockData] = []
    private var blockRowViews: [BlockRowView] = []

    private var optionsTable: NSTableView!
    private var optionsRemoveBtn: NSButton!
    private var blocksStack: NSStackView!
    private var blocksScrollView: NSScrollView!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 490))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        rebuildBlockRows()
        updateRemoveOptionButton()
    }

    // MARK: - UI

    private func buildUI() {
        let pad: CGFloat = 16

        let titleLabel = NSTextField(labelWithString: "Dropdown mit bedingten Texten")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let noteLabel = NSTextField(labelWithString: "Dropdown und Blöcke werden am Cursor eingefügt und können danach im Text verschoben werden.")
        noteLabel.font = NSFont.systemFont(ofSize: 11)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.maximumNumberOfLines = 2
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(noteLabel)

        // ── OPTIONS ──────────────────────────────────────────────────────────

        let optHeader = sectionHeader("Auswahloptionen")
        view.addSubview(optHeader)

        optionsTable = NSTableView()
        optionsTable.headerView = nil
        optionsTable.rowHeight = 22
        optionsTable.dataSource = self
        optionsTable.delegate = self
        optionsTable.focusRingType = .none
        let optCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("opt"))
        optCol.isEditable = true
        optionsTable.addTableColumn(optCol)

        let optScroll = NSScrollView()
        optScroll.hasVerticalScroller = true
        optScroll.autohidesScrollers = true
        optScroll.borderType = .bezelBorder
        optScroll.documentView = optionsTable
        optScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(optScroll)

        let addOptBtn = toolbarIconButton(symbol: "plus", action: #selector(addOption))
        optionsRemoveBtn = toolbarIconButton(symbol: "minus", action: #selector(removeOption))
        optionsRemoveBtn.isEnabled = false

        let optToolbarSep = separator()
        let optToolbar = NSView()
        optToolbar.translatesAutoresizingMaskIntoConstraints = false
        [optToolbarSep, addOptBtn, optionsRemoveBtn].forEach { optToolbar.addSubview($0) }
        view.addSubview(optToolbar)

        NSLayoutConstraint.activate([
            optToolbarSep.topAnchor.constraint(equalTo: optToolbar.topAnchor),
            optToolbarSep.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            optToolbarSep.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            optToolbarSep.heightAnchor.constraint(equalToConstant: 1),
            addOptBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            addOptBtn.centerYAnchor.constraint(equalTo: optToolbar.centerYAnchor),
            addOptBtn.widthAnchor.constraint(equalToConstant: 22),
            addOptBtn.heightAnchor.constraint(equalToConstant: 22),
            optionsRemoveBtn.leadingAnchor.constraint(equalTo: addOptBtn.trailingAnchor, constant: 2),
            optionsRemoveBtn.centerYAnchor.constraint(equalTo: optToolbar.centerYAnchor),
            optionsRemoveBtn.widthAnchor.constraint(equalToConstant: 22),
            optionsRemoveBtn.heightAnchor.constraint(equalToConstant: 22),
            optToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            optToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            optToolbar.heightAnchor.constraint(equalToConstant: 26),
        ])

        // ── BLOCKS ───────────────────────────────────────────────────────────

        let blkHeader = sectionHeader("Bedingte Textblöcke")
        view.addSubview(blkHeader)

        blocksStack = NSStackView()
        blocksStack.orientation = .vertical
        blocksStack.alignment = .leading
        blocksStack.spacing = 0
        blocksStack.translatesAutoresizingMaskIntoConstraints = false

        blocksScrollView = NSScrollView()
        blocksScrollView.hasVerticalScroller = true
        blocksScrollView.autohidesScrollers = true
        blocksScrollView.borderType = .bezelBorder
        blocksScrollView.documentView = blocksStack
        blocksScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blocksScrollView)

        blocksStack.widthAnchor.constraint(equalTo: blocksScrollView.contentView.widthAnchor).isActive = true

        let addBlockBtn = NSButton(title: "+ Block hinzufügen", target: self, action: #selector(addBlock))
        addBlockBtn.bezelStyle = .inline
        addBlockBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addBlockBtn)

        // ── BUTTONS ──────────────────────────────────────────────────────────

        let cancelBtn = NSButton(title: "Abbrechen", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1B}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelBtn)

        let insertBtn = NSButton(title: "Einfügen", target: self, action: #selector(applySheet))
        insertBtn.bezelStyle = .rounded
        insertBtn.keyEquivalent = "\r"
        insertBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(insertBtn)

        // ── LAYOUT ───────────────────────────────────────────────────────────

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: pad),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            noteLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            noteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            noteLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            optHeader.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 12),
            optHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            optScroll.topAnchor.constraint(equalTo: optHeader.bottomAnchor, constant: 5),
            optScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            optScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            optScroll.heightAnchor.constraint(equalToConstant: 110),

            optToolbar.topAnchor.constraint(equalTo: optScroll.bottomAnchor),

            blkHeader.topAnchor.constraint(equalTo: optToolbar.bottomAnchor, constant: 10),
            blkHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            blocksScrollView.topAnchor.constraint(equalTo: blkHeader.bottomAnchor, constant: 5),
            blocksScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            blocksScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            blocksScrollView.heightAnchor.constraint(equalToConstant: 190),

            addBlockBtn.topAnchor.constraint(equalTo: blocksScrollView.bottomAnchor, constant: 8),
            addBlockBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            insertBtn.topAnchor.constraint(equalTo: addBlockBtn.bottomAnchor, constant: 14),
            insertBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            insertBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),

            cancelBtn.centerYAnchor.constraint(equalTo: insertBtn.centerYAnchor),
            cancelBtn.trailingAnchor.constraint(equalTo: insertBtn.leadingAnchor, constant: -8),
        ])
    }

    // MARK: - Actions

    @objc private func addOption() {
        commitCurrentEdits()
        options.append("")
        optionsTable.reloadData()
        let newRow = options.count - 1
        optionsTable.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        // Add checkbox to every block row; new option OFF by default in existing blocks
        for row in blockRowViews {
            row.addOptionCheckbox(label: "Option \(newRow + 1)", included: false)
        }
        updateRemoveOptionButton()
        DispatchQueue.main.async {
            if let cell = self.optionsTable.view(atColumn: 0, row: newRow, makeIfNecessary: false) as? NSTableCellView {
                self.view.window?.makeFirstResponder(cell.textField)
            }
        }
    }

    @objc private func removeOption() {
        let row = optionsTable.selectedRow
        guard row >= 0, row < options.count else { return }
        commitCurrentEdits()
        options.remove(at: row)
        for i in blocks.indices {
            blocks[i].included = Set(blocks[i].included.compactMap { idx -> Int? in
                if idx == row { return nil }
                return idx > row ? idx - 1 : idx
            })
        }
        optionsTable.reloadData()
        rebuildBlockRows()
        updateRemoveOptionButton()
    }

    @objc private func addBlock() {
        commitCurrentEdits()
        blocks.append(BlockData(included: Set(0..<options.count)))
        rebuildBlockRows()
        DispatchQueue.main.async {
            self.blocksScrollView.layoutSubtreeIfNeeded()
            let docH = self.blocksScrollView.documentView?.frame.height ?? 0
            let clipH = self.blocksScrollView.contentView.bounds.height
            let target = NSPoint(x: 0, y: max(0, docH - clipH))
            self.blocksScrollView.contentView.scroll(to: target)
            self.blocksScrollView.reflectScrolledClipView(self.blocksScrollView.contentView)
        }
    }

    @objc private func cancel() {
        presentingViewController?.dismiss(self)
    }

    @objc private func applySheet() {
        commitCurrentEdits()
        let validOptions = options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !validOptions.isEmpty else { return }

        // Include all blocks; auto-generate label if the user left it blank
        let activeBlocks = blocks.enumerated().map { (i, b) -> BlockData in
            var copy = b
            if copy.label.trimmingCharacters(in: .whitespaces).isEmpty {
                copy.label = "Block \(i + 1)"
            }
            return copy
        }

        let result: String
        if activeBlocks.isEmpty {
            result = "{AUSWAHL:\(validOptions.joined(separator: "|"))}"
        } else {
            let usedIds = Set(DropdownPlaceholder.parse(in: expansionText).compactMap { $0.groupId })
            var gid = 1
            while usedIds.contains(gid) { gid += 1 }

            var parts = ["{AUSWAHL:G\(gid):\(validOptions.joined(separator: "|"))}"]
            for block in activeBlocks {
                let label = block.label.trimmingCharacters(in: .whitespaces)
                let indices = block.included.sorted().map { String($0) }.joined(separator: ",")
                parts.append("{optional:G\(gid):\(indices):\(label)}\(block.content){/optional}")
            }
            result = parts.joined(separator: "\n")
        }

        presentingViewController?.dismiss(self)
        onApply?(result)
    }

    // MARK: - Data management

    private func commitCurrentEdits() {
        for row in 0..<optionsTable.numberOfRows {
            if let cell = optionsTable.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
               let tf = cell.textField, row < options.count {
                options[row] = tf.stringValue
            }
        }
        for (i, rowView) in blockRowViews.enumerated() where i < blocks.count {
            blocks[i].label = rowView.currentLabel
            blocks[i].content = rowView.currentContent
            blocks[i].included = rowView.currentIncluded
        }
    }

    private func rebuildBlockRows() {
        blockRowViews = []
        blocksStack.arrangedSubviews.forEach { blocksStack.removeArrangedSubview($0); $0.removeFromSuperview() }

        for block in blocks {
            let blockId = block.id
            let rowView = BlockRowView()
            rowView.configure(options: options, block: block.label, content: block.content, included: block.included)
            rowView.onDelete = { [weak self] in
                guard let self = self else { return }
                self.commitCurrentEdits()
                self.blocks.removeAll { $0.id == blockId }
                self.rebuildBlockRows()
            }
            blocksStack.addArrangedSubview(rowView)
            blockRowViews.append(rowView)
        }
    }

    private func updateRemoveOptionButton() {
        optionsRemoveBtn.isEnabled = optionsTable.selectedRow >= 0 && !options.isEmpty
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> NSTextField {
        let lbl = NSTextField(labelWithString: title)
        lbl.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = .secondaryLabelColor
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }

    private func toolbarIconButton(symbol: String, action: Selector) -> NSButton {
        let btn = NSButton(title: "", target: self, action: action)
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        btn.bezelStyle = .smallSquare
        btn.isBordered = false
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private func separator() -> NSBox {
        let s = NSBox()
        s.boxType = .separator
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }
}

// MARK: - NSTableViewDataSource / Delegate

extension ConditionalBlockSheetController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { options.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("CondOptCell")
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField()
            tf.font = NSFont.systemFont(ofSize: 13)
            tf.isBordered = false
            tf.backgroundColor = .clear
            tf.focusRingType = .none
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.delegate = self
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.textField?.stringValue = options[row]
        cell.textField?.placeholderString = "Option \(row + 1)"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveOptionButton()
    }
}

// MARK: - NSTextFieldDelegate (option label changes)

extension ConditionalBlockSheetController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField else { return }
        for row in 0..<optionsTable.numberOfRows {
            if let cell = optionsTable.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
               cell.textField === tf, row < options.count {
                options[row] = tf.stringValue
                // Refresh checkbox labels in all block rows
                let label = tf.stringValue.isEmpty ? "Option \(row + 1)" : tf.stringValue
                blockRowViews.forEach { $0.updateOptionLabel(at: row, to: label) }
                break
            }
        }
    }
}

// MARK: - BlockRowView

private final class BlockRowView: NSView {
    var onDelete: (() -> Void)?

    private var labelField: NSTextField!
    private var contentField: NSTextField!
    private var checkboxStack: NSStackView!
    private var checkboxes: [NSButton] = []

    var currentLabel: String { labelField.stringValue }
    var currentContent: String { contentField.stringValue }
    var currentIncluded: Set<Int> {
        Set(checkboxes.enumerated().filter { $0.element.state == .on }.map { $0.offset })
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(options: [String], block label: String, content: String, included: Set<Int>) {
        labelField.stringValue = label
        contentField.stringValue = content

        checkboxes.forEach { $0.removeFromSuperview() }
        checkboxes = []
        checkboxStack.arrangedSubviews.forEach { checkboxStack.removeArrangedSubview($0); $0.removeFromSuperview() }

        for (i, opt) in options.enumerated() {
            let name = opt.isEmpty ? "Option \(i + 1)" : opt
            let cb = NSButton(checkboxWithTitle: name, target: nil, action: nil)
            cb.state = included.contains(i) ? .on : .off
            cb.font = NSFont.systemFont(ofSize: 11)
            checkboxStack.addArrangedSubview(cb)
            checkboxes.append(cb)
        }
    }

    func addOptionCheckbox(label: String, included: Bool) {
        let cb = NSButton(checkboxWithTitle: label, target: nil, action: nil)
        cb.state = included ? .on : .off
        cb.font = NSFont.systemFont(ofSize: 11)
        checkboxStack.addArrangedSubview(cb)
        checkboxes.append(cb)
    }

    func updateOptionLabel(at index: Int, to label: String) {
        checkboxes[safe: index]?.title = label
    }

    private func buildUI() {
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sep)

        labelField = NSTextField()
        labelField.placeholderString = "z. B. Ort (optional)"
        labelField.font = NSFont.systemFont(ofSize: 12)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelField)

        let sichtbarLabel = NSTextField(labelWithString: "Sichtbar bei:")
        sichtbarLabel.font = NSFont.systemFont(ofSize: 11)
        sichtbarLabel.textColor = .secondaryLabelColor
        sichtbarLabel.setContentHuggingPriority(.required, for: .horizontal)
        sichtbarLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sichtbarLabel)

        checkboxStack = NSStackView()
        checkboxStack.orientation = .horizontal
        checkboxStack.spacing = 10
        checkboxStack.alignment = .centerY
        checkboxStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        checkboxStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkboxStack)

        let delBtn = NSButton(title: "", target: self, action: #selector(deleteSelf))
        delBtn.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Löschen")
        delBtn.bezelStyle = .inline
        delBtn.isBordered = false
        delBtn.contentTintColor = .tertiaryLabelColor
        delBtn.setContentHuggingPriority(.required, for: .horizontal)
        delBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(delBtn)

        contentField = NSTextField()
        contentField.placeholderString = "Inhalt dieses Blocks…"
        contentField.font = NSFont.systemFont(ofSize: 12)
        contentField.usesSingleLineMode = false
        contentField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentField)

        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: topAnchor),
            sep.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            sep.heightAnchor.constraint(equalToConstant: 1),

            labelField.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 8),
            labelField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            labelField.widthAnchor.constraint(equalToConstant: 130),

            sichtbarLabel.centerYAnchor.constraint(equalTo: labelField.centerYAnchor),
            sichtbarLabel.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 8),

            checkboxStack.centerYAnchor.constraint(equalTo: labelField.centerYAnchor),
            checkboxStack.leadingAnchor.constraint(equalTo: sichtbarLabel.trailingAnchor, constant: 6),
            checkboxStack.trailingAnchor.constraint(lessThanOrEqualTo: delBtn.leadingAnchor, constant: -6),

            delBtn.centerYAnchor.constraint(equalTo: labelField.centerYAnchor),
            delBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            delBtn.widthAnchor.constraint(equalToConstant: 16),
            delBtn.heightAnchor.constraint(equalToConstant: 16),

            contentField.topAnchor.constraint(equalTo: labelField.bottomAnchor, constant: 6),
            contentField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            contentField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            contentField.heightAnchor.constraint(equalToConstant: 44),
            contentField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    @objc private func deleteSelf() { onDelete?() }
}
