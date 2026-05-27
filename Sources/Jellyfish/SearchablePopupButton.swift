import AppKit

// MARK: - Protocol

/// Gemeinsames Interface für NSPopUpButton und SearchablePopupButton
protocol DropdownControl: AnyObject {
    var selectedTitle: String { get }
    func selectOption(_ title: String)
}

extension NSPopUpButton: DropdownControl {
    var selectedTitle: String { selectedItem?.title ?? "" }
    func selectOption(_ title: String) { selectItem(withTitle: title) }
}

// MARK: - SearchablePopupButton

/// Ersatz für NSPopUpButton bei Dropdowns mit vielen Einträgen.
/// Zeigt einen Button mit der aktuellen Auswahl – ein Klick öffnet
/// ein Popover mit Suchfeld + gefilterter Liste.
final class SearchablePopupButton: NSButton, DropdownControl {

    // Schwelle ab der das Suchfeld angezeigt wird (immer, da SearchablePopupButton
    // nur für große Menüs instanziiert wird)
    private var allOptions: [String] = []
    private(set) var selectedTitle: String = ""
    private var popover: NSPopover?

    func configure(options: [String]) {
        allOptions = options
        selectedTitle = options.first ?? ""
        refreshLabel()
    }

    func selectOption(_ title: String) {
        guard allOptions.contains(title) else { return }
        selectedTitle = title
        refreshLabel()
    }

    private func refreshLabel() {
        // Schriftbild wie NSPopUpButton (Systemschrift, kein Fettdruck)
        let display = selectedTitle.isEmpty ? "Auswählen" : selectedTitle
        title = display
    }

    // NSButton löst mouseDown für .momentaryPushIn BezelStyle nicht über
    // target/action aus – wir überschreiben es direkt.
    override func mouseDown(with event: NSEvent) {
        openPicker()
    }

    private func openPicker() {
        popover?.close()
        let vc = SearchPickerViewController(
            options: allOptions,
            selected: selectedTitle
        ) { [weak self] chosen in
            guard let self else { return }
            self.selectedTitle = chosen
            self.refreshLabel()
            self.popover?.close()
            self.popover = nil
            // Gleicher target/action-Mechanismus wie NSPopUpButton
            if let t = self.target, let a = self.action {
                _ = t.perform(a, with: self)
            }
        }
        let pop = NSPopover()
        pop.contentViewController = vc
        pop.behavior = .semitransient
        pop.show(relativeTo: bounds, of: self, preferredEdge: .minY)
        self.popover = pop
        // Sofort Suchfeld fokussieren
        vc.focusSearch()
    }
}

// MARK: - SearchPickerViewController

private final class SearchPickerViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate
{
    private let allOptions: [String]
    private var filtered: [String]
    private let onSelect: (String) -> Void

    private var searchField: NSSearchField!
    private var tableView: NSTableView!

    init(options: [String], selected: String, onSelect: @escaping (String) -> Void) {
        self.allOptions = options
        self.filtered   = options
        self.onSelect   = onSelect
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 260))
        container.translatesAutoresizingMaskIntoConstraints = false

        // Suchfeld
        searchField = NSSearchField()
        searchField.placeholderString = "Suchen…"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(searchField)

        // Trennlinie
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)

        // Tabelle
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 20
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.doubleAction = #selector(rowDoubleClicked)
        tableView.target = self
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.focusRingType = .none

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("option"))
        col.isEditable = false
        tableView.addTableColumn(col)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers  = true
        scroll.borderType = .noBorder
        scroll.documentView = tableView
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            sep.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            scroll.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 2),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            container.widthAnchor.constraint(equalToConstant: 340),
            container.heightAnchor.constraint(equalToConstant: 260),
        ])

        self.view = container
        self.preferredContentSize = NSSize(width: 340, height: 260)
    }

    func focusSearch() {
        view.window?.makeFirstResponder(searchField)
    }

    // MARK: - Suche

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.lowercased()
        filtered = query.isEmpty
            ? allOptions
            : allOptions.filter { $0.lowercased().contains(query) }
        tableView.reloadData()
        if !filtered.isEmpty { tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
    }

    // Enter im Suchfeld → erste Zeile übernehmen
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            confirmSelection()
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let next = min(tableView.selectedRow + 1, filtered.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            tableView.scrollRowToVisible(next)
            return true
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let prev = max(tableView.selectedRow - 1, 0)
            tableView.selectRowIndexes(IndexSet(integer: prev), byExtendingSelection: false)
            tableView.scrollRowToVisible(prev)
            return true
        }
        return false
    }

    @objc private func rowDoubleClicked() { confirmSelection() }

    private func confirmSelection() {
        let row = tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        onSelect(filtered[row])
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView
                ?? {
                    let v = NSTableCellView()
                    let tf = NSTextField(labelWithString: "")
                    tf.translatesAutoresizingMaskIntoConstraints = false
                    tf.lineBreakMode = .byTruncatingTail
                    v.addSubview(tf)
                    v.textField = tf
                    NSLayoutConstraint.activate([
                        tf.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
                        tf.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6),
                        tf.centerYAnchor.constraint(equalTo: v.centerYAnchor),
                    ])
                    v.identifier = id
                    return v
                }()
        cell.textField?.stringValue = filtered[row]
        cell.textField?.font = .systemFont(ofSize: 13)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // Einfachklick in Tabelle → direkt übernehmen
        let row = tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        onSelect(filtered[row])
    }
}
