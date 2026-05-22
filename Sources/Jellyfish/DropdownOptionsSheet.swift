import Cocoa

final class DropdownOptionsSheetController: NSViewController {
    var onApply: (([String], Int?) -> Void)?

    private var options: [String] = []
    private var tableView: NSTableView!
    private var removeButton: NSButton!
    private var groupField: NSTextField!

    // MARK: - Setup

    func configure(initialOptions: [String]) {
        options = initialOptions.isEmpty ? [""] : initialOptions
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 330))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        tableView.reloadData()
        updateRemoveButton()
    }

    // MARK: - Build UI

    private func buildUI() {
        // Title label inside the sheet (sheets have no visible title bar on macOS)
        let titleLabel = NSTextField(labelWithString: "Dropdown-Optionen")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Group row
        let groupLabel = NSTextField(labelWithString: "Gruppe:")
        groupLabel.font = NSFont.systemFont(ofSize: 12)
        groupLabel.textColor = .secondaryLabelColor
        groupLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(groupLabel)

        groupField = NSTextField()
        groupField.placeholderString = "optional, z. B. 1"
        groupField.font = NSFont.systemFont(ofSize: 12)
        groupField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(groupField)

        let groupHint = NSTextField(labelWithString: "Gleiche Nummer = Auswahl wird synchronisiert")
        groupHint.font = NSFont.systemFont(ofSize: 10)
        groupHint.textColor = .tertiaryLabelColor
        groupHint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(groupHint)

        // Table view
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 24
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = true
        tableView.focusRingType = .none

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("option"))
        col.isEditable = true
        tableView.addTableColumn(col)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Toolbar: + and - buttons
        let addButton = NSButton(title: "", target: self, action: #selector(addOption))
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Option hinzufügen")
        addButton.bezelStyle = .smallSquare
        addButton.isBordered = false
        addButton.translatesAutoresizingMaskIntoConstraints = false

        removeButton = NSButton(title: "", target: self, action: #selector(removeOption))
        removeButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: "Option entfernen")
        removeButton.bezelStyle = .smallSquare
        removeButton.isBordered = false
        removeButton.isEnabled = false
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        let toolbarSep = NSBox()
        toolbarSep.boxType = .separator
        toolbarSep.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(toolbarSep)
        toolbar.addSubview(addButton)
        toolbar.addSubview(removeButton)
        view.addSubview(toolbar)

        // Action buttons
        let cancelButton = NSButton(title: "Abbrechen", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        let okButton = NSButton(title: "Übernehmen", target: self, action: #selector(applyOptions))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(okButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            groupLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            groupLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            groupLabel.widthAnchor.constraint(equalToConstant: 60),

            groupField.centerYAnchor.constraint(equalTo: groupLabel.centerYAnchor),
            groupField.leadingAnchor.constraint(equalTo: groupLabel.trailingAnchor, constant: 6),
            groupField.widthAnchor.constraint(equalToConstant: 80),

            groupHint.centerYAnchor.constraint(equalTo: groupLabel.centerYAnchor),
            groupHint.leadingAnchor.constraint(equalTo: groupField.trailingAnchor, constant: 8),
            groupHint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: groupLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),

            toolbarSep.topAnchor.constraint(equalTo: toolbar.topAnchor),
            toolbarSep.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toolbarSep.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toolbarSep.heightAnchor.constraint(equalToConstant: 1),

            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 22),
            addButton.heightAnchor.constraint(equalToConstant: 22),

            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 2),
            removeButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 22),
            removeButton.heightAnchor.constraint(equalToConstant: 22),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: okButton.topAnchor, constant: -12),
            toolbar.heightAnchor.constraint(equalToConstant: 28),

            okButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            okButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: okButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func addOption() {
        commitActiveEdit()
        options.append("")
        tableView.reloadData()
        let newRow = options.count - 1
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
        updateRemoveButton()
        DispatchQueue.main.async {
            if let cell = self.tableView.view(atColumn: 0, row: newRow, makeIfNecessary: false) as? NSTableCellView {
                self.view.window?.makeFirstResponder(cell.textField)
            }
        }
    }

    @objc private func removeOption() {
        let row = tableView.selectedRow
        guard row >= 0, row < options.count else { return }
        commitActiveEdit()
        options.remove(at: row)
        tableView.reloadData()
        if !options.isEmpty {
            let selectRow = min(row, options.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: selectRow), byExtendingSelection: false)
        }
        updateRemoveButton()
    }

    @objc private func cancel() {
        presentingViewController?.dismiss(self)
    }

    @objc private func applyOptions() {
        commitActiveEdit()
        let valid = options
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let groupId = Int(groupField.stringValue.trimmingCharacters(in: .whitespaces))
        presentingViewController?.dismiss(self)
        if !valid.isEmpty { onApply?(valid, groupId) }
    }

    // MARK: - Helpers

    private func commitActiveEdit() {
        // Read back any in-progress text field values before acting
        for row in 0..<tableView.numberOfRows {
            if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
               let tf = cell.textField, row < options.count {
                options[row] = tf.stringValue
            }
        }
    }

    private func updateRemoveButton() {
        removeButton?.isEnabled = tableView.selectedRow >= 0 && !options.isEmpty
    }
}

// MARK: - NSTableViewDataSource / Delegate

extension DropdownOptionsSheetController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { options.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("OptionCell")
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
        cell.textField?.placeholderString = "Option eingeben…"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButton()
    }
}

// MARK: - NSTextFieldDelegate

extension DropdownOptionsSheetController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField else { return }
        for row in 0..<tableView.numberOfRows {
            if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
               cell.textField === tf, row < options.count {
                options[row] = tf.stringValue
                break
            }
        }
    }
}
