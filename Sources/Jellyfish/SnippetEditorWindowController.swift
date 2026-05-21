import Cocoa

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Custom pasteboard type for snippet drag

private extension NSPasteboard.PasteboardType {
    static let snippetID = NSPasteboard.PasteboardType("de.extragroup.jellyfish.snippet-id")
}

// MARK: - Trigger pill view

final class TriggerPillView: NSView {
    private let label = NSTextField(labelWithString: "")

    var text: String = "" {
        didSet {
            label.stringValue = text
            label.sizeToFit()
            invalidateIntrinsicContentSize()
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func updateLayer() {
        layer?.cornerRadius = 11
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    override var intrinsicContentSize: NSSize {
        let w = max(label.intrinsicContentSize.width + 12, 22)
        return NSSize(width: w, height: 22)
    }
}

// MARK: - Left column: folder list

final class FolderViewController: NSViewController {
    weak var delegate: FolderViewControllerDelegate?

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    private var removeButton: NSButton!

    // "Alle" is index 0; real folders are 1…n
    private var rows: [FolderRow] = []

    enum FolderRow {
        case all
        case folder(SnippetFolder)
    }

    var selectedFolderId: UUID? {
        let row = tableView.selectedRow
        guard row > 0, let f = rows[safe: row] else { return nil }
        if case .folder(let sf) = f { return sf.id }
        return nil
    }

    override func loadView() {
        let effectView = NSVisualEffectView()
        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        view = effectView
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        reload()
    }

    private func buildUI() {
        // Scroll + table
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = false
        tableView.focusRingType = .none
        if #available(macOS 12.0, *) {
            tableView.style = .sourceList
        } else {
            tableView.selectionHighlightStyle = .sourceList
        }

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder"))
        col.isEditable = false
        tableView.addTableColumn(col)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Toolbar
        addButton = NSButton(title: "", target: self, action: #selector(addFolder))
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Ordner hinzufügen")
        addButton.bezelStyle = .smallSquare
        addButton.isBordered = false
        addButton.translatesAutoresizingMaskIntoConstraints = false

        removeButton = NSButton(title: "", target: self, action: #selector(removeFolder))
        removeButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: "Ordner löschen")
        removeButton.bezelStyle = .smallSquare
        removeButton.isBordered = false
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(separator)
        toolbar.addSubview(addButton)
        toolbar.addSubview(removeButton)
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            separator.topAnchor.constraint(equalTo: toolbar.topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            addButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 4),
            addButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor, constant: 1),
            addButton.widthAnchor.constraint(equalToConstant: 22),
            addButton.heightAnchor.constraint(equalToConstant: 22),

            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 2),
            removeButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor, constant: 1),
            removeButton.widthAnchor.constraint(equalToConstant: 22),
            removeButton.heightAnchor.constraint(equalToConstant: 22),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 28),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
        ])

        // Right-click menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Umbenennen", action: #selector(renameSelected), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Löschen", action: #selector(removeFolder), keyEquivalent: ""))
        tableView.menu = menu

        // Accept snippet drops from the list column
        tableView.registerForDraggedTypes([.snippetID])
    }

    func reload() {
        rows = [.all] + SnippetManager.shared.folders.map { .folder($0) }
        tableView?.reloadData()
        if tableView.selectedRow < 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updateButtons()
    }

    private func updateButtons() {
        let row = tableView.selectedRow
        removeButton.isEnabled = row > 0
    }

    @objc private func addFolder() {
        let alert = NSAlert()
        alert.messageText = "Neuer Ordner"
        alert.informativeText = "Name des Ordners:"
        alert.addButton(withTitle: "Anlegen")
        alert.addButton(withTitle: "Abbrechen")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        tf.placeholderString = "Ordnername"
        alert.accessoryView = tf
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let name = tf.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            _ = SnippetManager.shared.addFolder(name: name)
            self?.reload()
            let newRow = (self?.rows.count ?? 1) - 1
            self?.tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
            self?.delegate?.folderSelectionChanged()
        }
        tf.becomeFirstResponder()
    }

    @objc private func removeFolder() {
        let row = tableView.selectedRow
        guard row > 0, let f = rows[safe: row], case .folder(let folder) = f else { return }

        let affected = SnippetManager.shared.snippets.filter { $0.folderId == folder.id }

        if affected.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Ordner \u{201E}\(folder.name)\u{201C} l\u{00F6}schen?"
            alert.informativeText = "Der Ordner ist leer."
            alert.addButton(withTitle: "L\u{00F6}schen")
            alert.addButton(withTitle: "Abbrechen")
            guard let window = view.window else { return }
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                SnippetManager.shared.removeFolder(id: folder.id, moveToRoot: true)
                self?.reload()
                self?.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                self?.delegate?.folderSelectionChanged()
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Ordner \u{201E}\(folder.name)\u{201C} l\u{00F6}schen?"
            alert.informativeText = "\(affected.count) Textbaustein(e) sind in diesem Ordner."
            alert.addButton(withTitle: "In »Alle« verschieben")
            alert.addButton(withTitle: "Alle löschen")
            alert.addButton(withTitle: "Abbrechen")
            guard let window = view.window else { return }
            alert.beginSheetModal(for: window) { [weak self] response in
                switch response {
                case .alertFirstButtonReturn:
                    SnippetManager.shared.removeFolder(id: folder.id, moveToRoot: true)
                case .alertSecondButtonReturn:
                    SnippetManager.shared.removeFolder(id: folder.id, moveToRoot: false)
                default:
                    return
                }
                self?.reload()
                self?.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                self?.delegate?.folderSelectionChanged()
            }
        }
    }

    @objc private func renameSelected() {
        let row = tableView.selectedRow
        guard row > 0, let f = rows[safe: row], case .folder(let folder) = f else { return }

        let alert = NSAlert()
        alert.messageText = "Ordner umbenennen"
        alert.addButton(withTitle: "Umbenennen")
        alert.addButton(withTitle: "Abbrechen")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        tf.stringValue = folder.name
        alert.accessoryView = tf
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let name = tf.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            SnippetManager.shared.renameFolder(id: folder.id, newName: name)
            self?.reload()
            self?.delegate?.folderSelectionChanged()
        }
        tf.becomeFirstResponder()
    }
}

extension FolderViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingTail
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        switch rows[row] {
        case .all:
            cell.textField?.stringValue = "Alle"
            cell.textField?.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        case .folder(let f):
            cell.textField?.stringValue = f.name
            cell.textField?.font = NSFont.systemFont(ofSize: 13)
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtons()
        delegate?.folderSelectionChanged()
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }

    // Double-click to rename
    @objc func tableViewDoubleClicked(_ sender: Any?) {
        renameSelected()
    }

    // MARK: Drag-to-folder drop target

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard dropOperation == .on, rows[safe: row] != nil else { return [] }
        return .move
    }

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        guard let idString = info.draggingPasteboard.string(forType: .snippetID),
              let snippetID = UUID(uuidString: idString) else { return false }

        let targetFolderID: UUID?
        switch rows[safe: row] {
        case .all:           targetFolderID = nil
        case .folder(let f): targetFolderID = f.id
        default:             return false
        }

        guard var snippet = SnippetManager.shared.snippets.first(where: { $0.id == snippetID }) else { return false }
        snippet.folderId = targetFolderID
        SnippetManager.shared.update(snippet)
        delegate?.folderSelectionChanged()
        return true
    }
}

protocol FolderViewControllerDelegate: AnyObject {
    func folderSelectionChanged()
}

// MARK: - Middle column: snippet list

final class SnippetListViewController: NSViewController {
    weak var delegate: SnippetListViewControllerDelegate?

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var newButton: NSButton!
    private var deleteButton: NSButton!
    private var filteredSnippets: [Snippet] = []
    var currentFolderId: UUID? = nil  // nil = "Alle"

    var selectedSnippet: Snippet? {
        filteredSnippets[safe: tableView.selectedRow]
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        reload()
    }

    private func buildUI() {
        newButton = NSButton(title: "Neuer Textbaustein", target: self, action: #selector(addSnippet))
        newButton.bezelStyle = .rounded
        newButton.translatesAutoresizingMaskIntoConstraints = false

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 48
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = true
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .regular
        tableView.registerForDraggedTypes([.snippetID])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("snippet"))
        col.isEditable = false
        tableView.addTableColumn(col)

        // Context menu
        let ctxMenu = NSMenu()
        let deleteItem = NSMenuItem(title: "Löschen", action: #selector(deleteSelected), keyEquivalent: "")
        deleteItem.target = self
        ctxMenu.addItem(deleteItem)
        tableView.menu = ctxMenu

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let topSep = NSBox()
        topSep.boxType = .separator
        topSep.translatesAutoresizingMaskIntoConstraints = false

        // Bottom toolbar (matches folder list style)
        deleteButton = NSButton(title: "", target: self, action: #selector(deleteSelected))
        deleteButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: "Textbaustein löschen")
        deleteButton.bezelStyle = .smallSquare
        deleteButton.isBordered = false
        deleteButton.isEnabled = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false

        let bottomSep = NSBox()
        bottomSep.boxType = .separator
        bottomSep.translatesAutoresizingMaskIntoConstraints = false

        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(bottomSep)
        bottomBar.addSubview(deleteButton)

        view.addSubview(newButton)
        view.addSubview(topSep)
        view.addSubview(scrollView)
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            newButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            newButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            newButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            topSep.topAnchor.constraint(equalTo: newButton.bottomAnchor, constant: 8),
            topSep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topSep.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topSep.heightAnchor.constraint(equalToConstant: 1),

            scrollView.topAnchor.constraint(equalTo: topSep.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomSep.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            bottomSep.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            bottomSep.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomSep.heightAnchor.constraint(equalToConstant: 1),

            deleteButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 4),
            deleteButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor, constant: 1),
            deleteButton.widthAnchor.constraint(equalToConstant: 22),
            deleteButton.heightAnchor.constraint(equalToConstant: 22),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    func reload() {
        let all = SnippetManager.shared.snippets
        if let fid = currentFolderId {
            filteredSnippets = all.filter { $0.folderId == fid }
        } else {
            filteredSnippets = all
        }
        tableView?.reloadData()
        updateDeleteButton()
    }

    private func updateDeleteButton() {
        deleteButton?.isEnabled = tableView?.selectedRow ?? -1 >= 0
    }

    @objc private func deleteSelected() {
        guard let snippet = selectedSnippet else { return }
        SnippetManager.shared.remove(id: snippet.id)
        reload()
        delegate?.snippetDeselected()
        AppDelegate.shared?.statusBar.rebuild()
    }

    func selectSnippet(id: UUID?) {
        guard let id = id else {
            tableView.deselectAll(nil)
            return
        }
        if let idx = filteredSnippets.firstIndex(where: { $0.id == id }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
        }
    }

    @objc private func addSnippet() {
        let snippet = Snippet(trigger: "", expansion: "", name: "", folderId: currentFolderId)
        SnippetManager.shared.add(snippet)
        reload()
        selectSnippet(id: snippet.id)
        delegate?.snippetSelected(snippet)
    }
}

extension SnippetListViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { filteredSnippets.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("SnippetCell")
        let cell: SnippetCellView
        if let existing = tableView.makeView(withIdentifier: id, owner: self) as? SnippetCellView {
            cell = existing
        } else {
            cell = SnippetCellView()
            cell.identifier = id
        }
        let snippet = filteredSnippets[row]
        let displayName = snippet.name.isEmpty
            ? String(snippet.expansion.prefix(40)).replacingOccurrences(of: "\n", with: " ")
            : snippet.name
        cell.configure(name: displayName.isEmpty ? "Neuer Textbaustein" : displayName,
                       trigger: snippet.trigger)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDeleteButton()
        let row = tableView.selectedRow
        if let snippet = filteredSnippets[safe: row] {
            delegate?.snippetSelected(snippet)
        } else {
            delegate?.snippetDeselected()
        }
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let snippet = filteredSnippets[safe: row] else { return nil }
        let item = NSPasteboardItem()
        item.setString(snippet.id.uuidString, forType: .snippetID)
        return item
    }
}

protocol SnippetListViewControllerDelegate: AnyObject {
    func snippetSelected(_ snippet: Snippet)
    func snippetDeselected()
}

// MARK: - Snippet cell

final class SnippetCellView: NSTableCellView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let pill = TriggerPillView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.setContentHuggingPriority(.required, for: .horizontal)
        pill.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(nameLabel)
        addSubview(pill)

        NSLayoutConstraint.activate([
            pill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.widthAnchor.constraint(lessThanOrEqualToConstant: 120),

            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: pill.leadingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(name: String, trigger: String) {
        nameLabel.stringValue = name
        pill.text = trigger
        pill.isHidden = trigger.isEmpty
    }
}

// MARK: - Right column: snippet editor

final class SnippetEditorViewController: NSViewController {
    private var currentSnippet: Snippet?

    // Form views
    private var formContainer: NSView!
    private var emptyLabel: NSTextField!
    private var titleLabel: NSTextField!
    private var contentTypeLabel: NSTextField!
    private var contentTypePopup: NSPopUpButton!
    private var expansionScrollView: NSScrollView!
    private var expansionView: NSTextView!
    private var nameLabel: NSTextField!
    private var nameField: NSTextField!
    private var triggerLabel: NSTextField!
    private var triggerField: NSTextField!

    private var timestampButton: NSButton!
    private var dropdownButton: NSButton!
    private var iconToolbar: NSView!

    // Flag to suppress saving while we're programmatically populating fields
    private var isPopulating = false

    weak var listVC: SnippetListViewController?

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        showEmpty()
    }

    private func makeIconButton(resource: String, tooltip: String, action: Selector) -> NSButton {
        let btn = NSButton(title: "", target: self, action: action)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.toolTip = tooltip
        btn.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.main.url(forResource: resource, withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            let sized = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                img.draw(in: rect)
                return true
            }
            sized.isTemplate = true
            btn.image = sized
        }
        return btn
    }

    private func buildUI() {
        // Empty state
        emptyLabel = NSTextField(labelWithString: "Kein Textbaustein ausgewählt")
        emptyLabel.font = NSFont.systemFont(ofSize: 14)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        // Form
        formContainer = NSView()
        formContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(formContainer)
        NSLayoutConstraint.activate([
            formContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            formContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            formContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            formContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])

        // Title
        titleLabel = NSTextField(labelWithString: "Textbaustein")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(titleLabel)

        // Content type row
        contentTypeLabel = NSTextField(labelWithString: "Inhaltstyp")
        contentTypeLabel.font = NSFont.systemFont(ofSize: 12)
        contentTypeLabel.textColor = .secondaryLabelColor
        contentTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(contentTypeLabel)

        contentTypePopup = NSPopUpButton()
        contentTypePopup.addItem(withTitle: "Reiner Text")
        contentTypePopup.isEnabled = false
        contentTypePopup.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(contentTypePopup)

        // Expansion text view
        expansionView = NSTextView()
        expansionView.isEditable = true
        expansionView.font = NSFont.systemFont(ofSize: 13)
        expansionView.delegate = self
        expansionView.isRichText = false
        expansionView.allowsUndo = true

        expansionScrollView = NSScrollView()
        expansionScrollView.hasVerticalScroller = true
        expansionScrollView.autohidesScrollers = true
        expansionScrollView.borderType = .bezelBorder
        expansionScrollView.documentView = expansionView
        expansionScrollView.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(expansionScrollView)

        // Name field
        nameLabel = NSTextField(labelWithString: "Bezeichnung")
        nameLabel.font = NSFont.systemFont(ofSize: 12)
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(nameLabel)

        nameField = NSTextField()
        nameField.placeholderString = "Optionaler Name"
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.delegate = self
        formContainer.addSubview(nameField)

        // Trigger field
        triggerLabel = NSTextField(labelWithString: "Kürzel")
        triggerLabel.font = NSFont.systemFont(ofSize: 12)
        triggerLabel.textColor = .secondaryLabelColor
        triggerLabel.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(triggerLabel)

        triggerField = NSTextField()
        triggerField.placeholderString = "z. B. mfg#"
        triggerField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        triggerField.translatesAutoresizingMaskIntoConstraints = false
        triggerField.delegate = self
        formContainer.addSubview(triggerField)

        // Icon toolbar between content type row and text editor
        timestampButton = makeIconButton(resource: "icon-clock", tooltip: "Zeitstempel einfügen",
                                         action: #selector(showTimestampMenu(_:)))
        dropdownButton = makeIconButton(resource: "icon-dropdown", tooltip: "Dropdown einfügen",
                                        action: #selector(showDropdownDialog))

        iconToolbar = NSView()
        iconToolbar.translatesAutoresizingMaskIntoConstraints = false
        iconToolbar.addSubview(timestampButton)
        iconToolbar.addSubview(dropdownButton)
        formContainer.addSubview(iconToolbar)

        NSLayoutConstraint.activate([
            timestampButton.leadingAnchor.constraint(equalTo: iconToolbar.leadingAnchor),
            timestampButton.centerYAnchor.constraint(equalTo: iconToolbar.centerYAnchor),
            timestampButton.widthAnchor.constraint(equalToConstant: 24),
            timestampButton.heightAnchor.constraint(equalToConstant: 24),

            dropdownButton.leadingAnchor.constraint(equalTo: timestampButton.trailingAnchor, constant: 4),
            dropdownButton.centerYAnchor.constraint(equalTo: iconToolbar.centerYAnchor),
            dropdownButton.widthAnchor.constraint(equalToConstant: 24),
            dropdownButton.heightAnchor.constraint(equalToConstant: 24),

            iconToolbar.heightAnchor.constraint(equalToConstant: 28),
            iconToolbar.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            iconToolbar.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),
        ])

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: formContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),

            contentTypeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            contentTypeLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),

            contentTypePopup.centerYAnchor.constraint(equalTo: contentTypeLabel.centerYAnchor),
            contentTypePopup.leadingAnchor.constraint(equalTo: contentTypeLabel.trailingAnchor, constant: 8),
            contentTypePopup.widthAnchor.constraint(equalToConstant: 140),

            iconToolbar.topAnchor.constraint(equalTo: contentTypeLabel.bottomAnchor, constant: 8),

            expansionScrollView.topAnchor.constraint(equalTo: iconToolbar.bottomAnchor, constant: 4),
            expansionScrollView.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            expansionScrollView.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),

            nameLabel.topAnchor.constraint(equalTo: expansionScrollView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 90),

            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),

            triggerLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            triggerLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            triggerLabel.widthAnchor.constraint(equalToConstant: 90),
            triggerLabel.bottomAnchor.constraint(lessThanOrEqualTo: formContainer.bottomAnchor),

            triggerField.centerYAnchor.constraint(equalTo: triggerLabel.centerYAnchor),
            triggerField.leadingAnchor.constraint(equalTo: triggerLabel.trailingAnchor, constant: 8),
            triggerField.widthAnchor.constraint(equalToConstant: 140),
            triggerField.bottomAnchor.constraint(lessThanOrEqualTo: formContainer.bottomAnchor),

            // Expansion takes remaining space
            expansionScrollView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -12),
        ])
    }

    func showEmpty() {
        emptyLabel.isHidden = false
        formContainer.isHidden = true
        currentSnippet = nil
    }

    func show(_ snippet: Snippet) {
        emptyLabel.isHidden = true
        formContainer.isHidden = false
        currentSnippet = snippet
        populate(snippet)
    }

    private func populate(_ snippet: Snippet) {
        isPopulating = true
        expansionView.string = snippet.expansion
        nameField.stringValue = snippet.name
        triggerField.stringValue = snippet.trigger
        isPopulating = false
    }

    private func saveCurrentSnippet() {
        guard !isPopulating, var snippet = currentSnippet else { return }
        snippet.expansion = expansionView.string
        snippet.name = nameField.stringValue
        snippet.trigger = triggerField.stringValue.trimmingCharacters(in: .whitespaces)
        currentSnippet = snippet
        SnippetManager.shared.update(snippet)
        listVC?.reload()
        AppDelegate.shared?.statusBar.rebuild()
    }

    @objc private func showTimestampMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let now = Date()
        for ph in DatePlaceholder.allCases {
            let item = NSMenuItem(
                title: "\(ph.displayName)   →   \(ph.resolve(at: now))",
                action: #selector(insertTimestamp(_:)),
                keyEquivalent: "")
            item.representedObject = ph
            item.target = self
            menu.addItem(item)
        }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: sender.bounds.height + 4),
                   in: sender)
    }

    @objc private func insertTimestamp(_ sender: NSMenuItem) {
        guard let ph = sender.representedObject as? DatePlaceholder else { return }
        expansionView.insertText(ph.rawValue, replacementRange: expansionView.selectedRange())
        saveCurrentSnippet()
    }

    @objc private func showDropdownDialog() {
        let sheet = DropdownOptionsSheetController()
        sheet.configure(initialOptions: [])
        sheet.onApply = { [weak self] options in
            guard let self = self else { return }
            let placeholder = "{AUSWAHL:\(options.joined(separator: "|"))}"
            self.expansionView.insertText(placeholder, replacementRange: self.expansionView.selectedRange())
            self.saveCurrentSnippet()
        }
        presentAsSheet(sheet)
    }
}

extension SnippetEditorViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        saveCurrentSnippet()
    }
}

extension SnippetEditorViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        saveCurrentSnippet()
    }
}

// MARK: - Window controller

class SnippetEditorWindowController: NSObject, NSWindowDelegate {
    static let shared = SnippetEditorWindowController()

    private var window: NSWindow?
    private var splitVC: NSSplitViewController!
    private var folderVC: FolderViewController!
    private var listVC: SnippetListViewController!
    private var editorVC: SnippetEditorViewController!

    func showAddMode() {
        present()
        listVC.reload()
        // Create new snippet and select it
        let snippet = Snippet(trigger: "", expansion: "", name: "", folderId: listVC.currentFolderId)
        SnippetManager.shared.add(snippet)
        listVC.reload()
        listVC.selectSnippet(id: snippet.id)
        editorVC.show(snippet)
    }

    func showManageMode() {
        present()
    }

    private func present() {
        if window == nil { buildWindow() }
        installMainMenu()
        window?.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        AppIconManager.shared.update()
        NSApp.activate(ignoringOtherApps: true)
    }

    func installMainMenu() {
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

        let editItem = NSMenuItem(); mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Bearbeiten")
        editMenu.addItem(NSMenuItem(title: "Rückgängig", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() {
        // Build view controllers — delegates set AFTER contentViewController
        // assignment so all views are loaded before any delegate callbacks fire.
        folderVC = FolderViewController()
        listVC = SnippetListViewController()
        editorVC = SnippetEditorViewController()
        editorVC.listVC = listVC

        // Split view
        splitVC = NSSplitViewController()

        let sidebarItem = NSSplitViewItem(viewController: folderVC)
        sidebarItem.minimumThickness = 160
        sidebarItem.maximumThickness = 220
        splitVC.addSplitViewItem(sidebarItem)

        let listItem = NSSplitViewItem(viewController: listVC)
        listItem.minimumThickness = 230
        splitVC.addSplitViewItem(listItem)

        let editorItem = NSSplitViewItem(viewController: editorVC)
        editorItem.minimumThickness = 270
        splitVC.addSplitViewItem(editorItem)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Jellyfish"
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 700, height: 420)
        w.center()
        // Setting contentViewController triggers viewDidLoad on all child VCs.
        // Delegates must be wired up only afterwards so callbacks don't fire
        // into views that haven't initialised their outlets yet.
        w.contentViewController = splitVC
        window = w

        folderVC.delegate = self
        listVC.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        // Auto-save is already continuous; just ensure everything is flushed
        SnippetManager.shared.save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
            AppDelegate.shared?.keyboardMonitor.ensureEnabled()
        }
    }
}

extension SnippetEditorWindowController: FolderViewControllerDelegate {
    func folderSelectionChanged() {
        listVC.currentFolderId = folderVC.selectedFolderId
        listVC.reload()
        editorVC.showEmpty()
    }
}

extension SnippetEditorWindowController: SnippetListViewControllerDelegate {
    func snippetSelected(_ snippet: Snippet) {
        editorVC.show(snippet)
    }

    func snippetDeselected() {
        editorVC.showEmpty()
    }
}
