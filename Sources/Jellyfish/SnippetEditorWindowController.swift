import Cocoa

// MARK: - Safe array subscript

extension Array {
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

// MARK: - Tree node for folder outline view

final class FolderItem {
    let folderId: UUID?
    let name: String
    let isShared: Bool
    var children: [FolderItem] = []

    init(folderId: UUID?, name: String, isShared: Bool = false) {
        self.folderId = folderId
        self.name = name
        self.isShared = isShared
    }
}

// MARK: - Folder cell with optional team-share icon

private final class FolderCellView: NSTableCellView {
    private let shareIcon = NSImageView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        let tf = NSTextField(labelWithString: "")
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.lineBreakMode = .byTruncatingTail
        addSubview(tf)
        textField = tf

        shareIcon.image = NSImage(systemSymbolName: "person.2.fill",
                                  accessibilityDescription: "Geteilt mit Team")
        shareIcon.contentTintColor = .tertiaryLabelColor
        shareIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shareIcon)

        NSLayoutConstraint.activate([
            shareIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            shareIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            shareIcon.widthAnchor.constraint(equalToConstant: 15),
            shareIcon.heightAnchor.constraint(equalToConstant: 12),

            tf.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            tf.trailingAnchor.constraint(equalTo: shareIcon.leadingAnchor, constant: -4),
            tf.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, isAll: Bool, isShared: Bool) {
        textField?.stringValue = name
        textField?.font = isAll ? .systemFont(ofSize: 13, weight: .medium) : .systemFont(ofSize: 13)
        shareIcon.isHidden = !isShared
    }
}

// MARK: - Left column: folder list

final class FolderViewController: NSViewController {
    weak var delegate: FolderViewControllerDelegate?

    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    private var removeButton: NSButton!
    private var rootItems: [FolderItem] = []

    var selectedFolderId: UUID? {
        guard outlineView.selectedRow >= 0,
              let item = outlineView.item(atRow: outlineView.selectedRow) as? FolderItem
        else { return nil }
        return item.folderId
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
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowHeight = 28
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.allowsEmptySelection = false
        outlineView.focusRingType = .none
        outlineView.indentationPerLevel = 14
        outlineView.autoresizesOutlineColumn = false
        outlineView.doubleAction = #selector(renameSelected)
        outlineView.target = self
        if #available(macOS 12.0, *) {
            outlineView.style = .sourceList
        } else {
            outlineView.selectionHighlightStyle = .sourceList
        }

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder"))
        col.isEditable = false
        col.resizingMask = .autoresizingMask
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = outlineView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

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

        let subfolderItem = NSMenuItem(title: "Unterordner erstellen",
                                       action: #selector(addSubfolder), keyEquivalent: "")
        subfolderItem.target = self
        let renameItem = NSMenuItem(title: "Umbenennen",
                                    action: #selector(renameSelected), keyEquivalent: "")
        renameItem.target = self
        let shareItem = NSMenuItem(title: "Mit Team teilen",
                                   action: #selector(toggleShared), keyEquivalent: "")
        shareItem.target = self
        let deleteItem = NSMenuItem(title: "Löschen",
                                    action: #selector(removeFolder), keyEquivalent: "")
        deleteItem.target = self

        let menu = NSMenu()
        menu.addItem(subfolderItem)
        menu.addItem(renameItem)
        menu.addItem(.separator())
        menu.addItem(shareItem)
        menu.addItem(.separator())
        menu.addItem(deleteItem)
        menu.delegate = self
        outlineView.menu = menu

        outlineView.registerForDraggedTypes([.snippetID])
    }

    func reload() {
        let previousId = selectedFolderId
        buildTree()
        outlineView?.reloadData()
        outlineView?.expandItem(nil, expandChildren: true)
        if let fid = previousId {
            restoreSelection(folderId: fid)
        } else if (outlineView?.selectedRow ?? -1) < 0 {
            outlineView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updateButtons()
    }

    private func buildTree() {
        let folders = SnippetManager.shared.folders
        var items: [UUID: FolderItem] = [:]
        for f in folders { items[f.id] = FolderItem(folderId: f.id, name: f.name, isShared: f.isShared) }
        var topLevel: [FolderItem] = []
        for f in folders {
            guard let item = items[f.id] else { continue }
            if let pid = f.parentId, let parent = items[pid] {
                parent.children.append(item)
            } else {
                topLevel.append(item)
            }
        }
        rootItems = [FolderItem(folderId: nil, name: "Alle")] + topLevel
    }

    private func restoreSelection(folderId: UUID) {
        for row in 0..<(outlineView?.numberOfRows ?? 0) {
            if let item = outlineView.item(atRow: row) as? FolderItem, item.folderId == folderId {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                return
            }
        }
        outlineView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    private func updateButtons() {
        let row = outlineView?.selectedRow ?? -1
        removeButton?.isEnabled = row >= 0 &&
            (outlineView.item(atRow: row) as? FolderItem)?.folderId != nil
    }

    @objc private func addFolder() {
        promptName(title: "Neuer Ordner") { [weak self] name in
            _ = SnippetManager.shared.addFolder(name: name, parentId: nil)
            self?.reload()
            self?.delegate?.folderSelectionChanged()
        }
    }

    @objc private func addSubfolder() {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) as? FolderItem,
              let parentId = item.folderId else { return }
        promptName(title: "Neuer Unterordner") { [weak self] name in
            _ = SnippetManager.shared.addFolder(name: name, parentId: parentId)
            self?.reload()
            self?.delegate?.folderSelectionChanged()
        }
    }

    private func promptName(title: String, completion: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "Anlegen")
        alert.addButton(withTitle: "Abbrechen")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        tf.placeholderString = "Name"
        alert.accessoryView = tf
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let name = tf.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            completion(name)
        }
        tf.becomeFirstResponder()
    }

    @objc private func removeFolder() {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) as? FolderItem,
              let folderId = item.folderId,
              let folder = SnippetManager.shared.folders.first(where: { $0.id == folderId })
        else { return }

        let affected = SnippetManager.shared.snippets.filter { $0.folderId == folderId }
        guard let window = view.window else { return }

        func doRemove(moveToRoot: Bool) {
            SnippetManager.shared.removeFolder(id: folderId, moveToRoot: moveToRoot)
            self.reload()
            self.outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            self.delegate?.folderSelectionChanged()
        }

        if affected.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Ordner \u{201E}\(folder.name)\u{201C} löschen?"
            alert.informativeText = "Der Ordner ist leer."
            alert.addButton(withTitle: "Löschen")
            alert.addButton(withTitle: "Abbrechen")
            alert.beginSheetModal(for: window) { response in
                guard response == .alertFirstButtonReturn else { return }
                doRemove(moveToRoot: true)
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Ordner \u{201E}\(folder.name)\u{201C} löschen?"
            alert.informativeText = "\(affected.count) Textbaustein(e) sind in diesem Ordner."
            alert.addButton(withTitle: "In »Alle« verschieben")
            alert.addButton(withTitle: "Alle löschen")
            alert.addButton(withTitle: "Abbrechen")
            alert.beginSheetModal(for: window) { response in
                switch response {
                case .alertFirstButtonReturn:  doRemove(moveToRoot: true)
                case .alertSecondButtonReturn: doRemove(moveToRoot: false)
                default: break
                }
            }
        }
    }

    @objc private func toggleShared() {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) as? FolderItem,
              let folderId = item.folderId else { return }
        SnippetManager.shared.toggleShared(folderId: folderId)
        reload()
        delegate?.folderSelectionChanged()
    }

    @objc private func renameSelected() {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) as? FolderItem,
              let folderId = item.folderId,
              let folder = SnippetManager.shared.folders.first(where: { $0.id == folderId })
        else { return }

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
            SnippetManager.shared.renameFolder(id: folderId, newName: name)
            self?.reload()
            self?.delegate?.folderSelectionChanged()
        }
        tf.becomeFirstResponder()
    }
}

extension FolderViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? rootItems.count : (item as! FolderItem).children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        item == nil ? rootItems[index] : (item as! FolderItem).children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !(item as! FolderItem).children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView,
                     viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let fi = item as! FolderItem
        let id = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: FolderCellView
        if let existing = outlineView.makeView(withIdentifier: id, owner: self) as? FolderCellView {
            cell = existing
        } else {
            cell = FolderCellView()
            cell.identifier = id
        }
        cell.configure(name: fi.folderId == nil ? "Alle" : fi.name,
                       isAll: fi.folderId == nil,
                       isShared: fi.isShared)
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        updateButtons()
        delegate?.folderSelectionChanged()
    }

    // MARK: Drag-to-folder drop

    func outlineView(_ outlineView: NSOutlineView,
                     validateDrop info: NSDraggingInfo,
                     proposedItem item: Any?,
                     proposedChildIndex index: Int) -> NSDragOperation {
        guard item is FolderItem else { return [] }
        outlineView.setDropItem(item, dropChildIndex: -1)
        return .move
    }

    func outlineView(_ outlineView: NSOutlineView,
                     acceptDrop info: NSDraggingInfo,
                     item: Any?, childIndex index: Int) -> Bool {
        guard let fi = item as? FolderItem,
              let idStr = info.draggingPasteboard.string(forType: .snippetID),
              let snippetID = UUID(uuidString: idStr),
              var snippet = SnippetManager.shared.snippets.first(where: { $0.id == snippetID })
        else { return false }
        snippet.folderId = fi.folderId
        SnippetManager.shared.update(snippet)
        delegate?.folderSelectionChanged()
        return true
    }
}

extension FolderViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        let row = outlineView.selectedRow
        guard let fi = outlineView.item(atRow: row) as? FolderItem,
              let _ = fi.folderId else {
            menu.items.forEach { $0.isEnabled = false }
            return
        }
        let hasTeamFolder = SnippetManager.shared.teamFolderURL != nil
        for item in menu.items {
            if item.action == #selector(toggleShared) {
                item.isEnabled = hasTeamFolder
                item.title = fi.isShared ? "Nicht mehr mit Team teilen" : "Mit Team teilen"
            } else if item.isSeparatorItem {
                // keep separators as-is
            } else {
                item.isEnabled = true
            }
        }
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
    private var searchField: NSSearchField!
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
        searchField = NSSearchField()
        searchField.placeholderString = "Suchen…"
        (searchField as NSTextField).delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

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
        let duplicateItem = NSMenuItem(title: "Duplizieren", action: #selector(duplicateSelected), keyEquivalent: "")
        duplicateItem.target = self
        ctxMenu.addItem(duplicateItem)
        ctxMenu.addItem(.separator())
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
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            newButton.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),
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
        let term = searchField?.stringValue.lowercased() ?? ""
        if !term.isEmpty {
            filteredSnippets = all.filter {
                $0.trigger.lowercased().contains(term) ||
                $0.name.lowercased().contains(term) ||
                $0.expansion.lowercased().contains(term)
            }
        } else if let fid = currentFolderId {
            let descendants = SnippetManager.shared.descendantFolderIds(of: fid)
            filteredSnippets = all.filter { $0.folderId == fid || descendants.contains($0.folderId ?? UUID()) }
        } else {
            filteredSnippets = all
        }
        tableView?.reloadData()
        updateDeleteButton()
    }

    func reloadCurrentSelection() {
        let row = tableView?.selectedRow ?? -1
        guard row >= 0, row < filteredSnippets.count else { return }
        // Sync filteredSnippets[row] with the saved version so the cell
        // reflects the latest name/expansion without a full reload.
        if let updated = SnippetManager.shared.snippets.first(where: { $0.id == filteredSnippets[row].id }) {
            filteredSnippets[row] = updated
        }
        tableView?.reloadData(forRowIndexes: IndexSet(integer: row),
                              columnIndexes: IndexSet(integer: 0))
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
        addNewSnippet()
    }

    func addNewSnippet() {
        let snippet = Snippet(trigger: "", expansion: "", name: "", folderId: currentFolderId)
        SnippetManager.shared.add(snippet)
        let idx = filteredSnippets.count
        filteredSnippets.append(snippet)
        tableView.insertRows(at: IndexSet(integer: idx), withAnimation: .slideDown)
        updateDeleteButton()
        tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        tableView.scrollRowToVisible(idx)
        // tableViewSelectionDidChange fires here → delegate?.snippetSelected(snippet)
    }

    @objc private func duplicateSelected() {
        guard let snippet = selectedSnippet else { return }
        let copy = SnippetManager.shared.duplicate(snippet)
        let idx = filteredSnippets.count
        filteredSnippets.append(copy)
        tableView.insertRows(at: IndexSet(integer: idx), withAnimation: .slideDown)
        updateDeleteButton()
        tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        tableView.scrollRowToVisible(idx)
        AppDelegate.shared?.statusBar.rebuild()
        // tableViewSelectionDidChange fires here → delegate?.snippetSelected(copy)
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

extension SnippetListViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSSearchField != nil else { return }
        reload()
    }
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
    private var titleLabel: NSTextField!
    private var contentTypeLabel: NSTextField!
    private var contentTypePopup: NSPopUpButton!
    private var expansionScrollView: NSScrollView!
    private var expansionView: NSTextView!
    private var nameLabel: NSTextField!
    private var nameField: NSTextField!
    private var triggerLabel: NSTextField!
    private var triggerField: NSTextField!

    private var calendarButton: NSButton!
    private var timestampButton: NSButton!
    private var clipboardButton: NSButton!
    private var calculatorButton: NSButton!
    private var optionalButton: NSButton!
    private var dropdownButton: NSButton!
    private var conditionButton: NSButton!
    private var iconToolbar: NSView!
    private var formattingBar: NSView!
    private var formattingBarHeight: NSLayoutConstraint!
    private var boldButton: NSButton!
    private var italicButton: NSButton!
    private var underlineButton: NSButton!
    private var linkButton: NSButton!
    private var noSelectionOverlay: NSTextField!

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
        contentTypePopup.addItem(withTitle: "Formatierter Text")
        contentTypePopup.target = self
        contentTypePopup.action = #selector(contentTypeChanged)
        contentTypePopup.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(contentTypePopup)

        // Expansion text view
        expansionView = NSTextView()
        expansionView.isEditable = true
        expansionView.font = NSFont.systemFont(ofSize: 13)
        expansionView.delegate = self
        expansionView.isRichText = false
        expansionView.allowsUndo = true
        expansionView.isVerticallyResizable = true
        expansionView.isHorizontallyResizable = false
        expansionView.autoresizingMask = [.width]
        expansionView.textContainer?.widthTracksTextView = true

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

        // Formatting toolbar (only visible in rich text mode)
        boldButton = makeFormatButton(symbol: "bold", tooltip: "Fett", action: #selector(boldAction))
        italicButton = makeFormatButton(symbol: "italic", tooltip: "Kursiv", action: #selector(italicAction))
        underlineButton = makeFormatButton(symbol: "underline", tooltip: "Unterstrichen", action: #selector(underlineAction))
        linkButton = makeFormatButton(symbol: "link", tooltip: "Link einfügen", action: #selector(linkAction))

        formattingBar = NSView()
        formattingBar.translatesAutoresizingMaskIntoConstraints = false
        formattingBar.addSubview(boldButton)
        formattingBar.addSubview(italicButton)
        formattingBar.addSubview(underlineButton)
        formattingBar.addSubview(linkButton)
        formContainer.addSubview(formattingBar)

        let fmtButtons: [NSButton] = [boldButton, italicButton, underlineButton, linkButton]
        for (i, btn) in fmtButtons.enumerated() {
            let leading: NSLayoutConstraint = i == 0
                ? btn.leadingAnchor.constraint(equalTo: formattingBar.leadingAnchor)
                : btn.leadingAnchor.constraint(equalTo: fmtButtons[i - 1].trailingAnchor, constant: 2)
            NSLayoutConstraint.activate([
                leading,
                btn.centerYAnchor.constraint(equalTo: formattingBar.centerYAnchor),
                btn.widthAnchor.constraint(equalToConstant: 28),
                btn.heightAnchor.constraint(equalToConstant: 24),
            ])
        }

        formattingBarHeight = formattingBar.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            formattingBar.topAnchor.constraint(equalTo: contentTypeLabel.bottomAnchor, constant: 8),
            formattingBar.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            formattingBar.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),
            formattingBarHeight,
        ])
        formattingBar.isHidden = true

        // Icon toolbar between content type row and text editor
        calendarButton = makeIconButton(resource: "icon-calendar", tooltip: "Datum einfügen",
                                        action: #selector(showCalendarMenu(_:)))
        timestampButton = makeIconButton(resource: "icon-clock", tooltip: "Uhrzeit einfügen",
                                         action: #selector(showTimestampMenu(_:)))
        clipboardButton = makeIconButton(resource: "icon-clipboard", tooltip: "Zwischenablage einfügen",
                                         action: #selector(insertFromClipboard))
        calculatorButton = makeIconButton(resource: "icon-calculator", tooltip: "Datumsrechnung einfügen",
                                          action: #selector(showDateArithmeticSheet))
        optionalButton = makeIconButton(resource: "icon-optional", tooltip: "Optionalen Block einfügen",
                                         action: #selector(insertOptionalBlock))
        dropdownButton = makeIconButton(resource: "icon-dropdown", tooltip: "Dropdown einfügen",
                                        action: #selector(showDropdownDialog))
        conditionButton = makeIconButton(resource: "icon-condition",
                                         tooltip: "Dropdown mit bedingten Texten einfügen",
                                         action: #selector(showConditionalBlockDialog))

        iconToolbar = NSView()
        iconToolbar.translatesAutoresizingMaskIntoConstraints = false
        iconToolbar.addSubview(calendarButton)
        iconToolbar.addSubview(timestampButton)
        iconToolbar.addSubview(clipboardButton)
        iconToolbar.addSubview(calculatorButton)
        iconToolbar.addSubview(optionalButton)
        iconToolbar.addSubview(dropdownButton)
        iconToolbar.addSubview(conditionButton)
        formContainer.addSubview(iconToolbar)

        let toolbarButtons: [NSButton] = [calendarButton, timestampButton, clipboardButton,
                                           calculatorButton, optionalButton, dropdownButton, conditionButton]
        for (i, btn) in toolbarButtons.enumerated() {
            let leading: NSLayoutConstraint
            if i == 0 {
                leading = btn.leadingAnchor.constraint(equalTo: iconToolbar.leadingAnchor)
            } else {
                leading = btn.leadingAnchor.constraint(equalTo: toolbarButtons[i - 1].trailingAnchor, constant: 4)
            }
            NSLayoutConstraint.activate([
                leading,
                btn.centerYAnchor.constraint(equalTo: iconToolbar.centerYAnchor),
                btn.widthAnchor.constraint(equalToConstant: 24),
                btn.heightAnchor.constraint(equalToConstant: 24),
            ])
        }
        NSLayoutConstraint.activate([
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

            iconToolbar.topAnchor.constraint(equalTo: formattingBar.bottomAnchor, constant: 0),

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

        noSelectionOverlay = NSTextField(labelWithString: "Kein Textbaustein ausgewählt")
        noSelectionOverlay.font = NSFont.systemFont(ofSize: 13)
        noSelectionOverlay.textColor = .secondaryLabelColor
        noSelectionOverlay.alignment = .center
        noSelectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(noSelectionOverlay)
        NSLayoutConstraint.activate([
            noSelectionOverlay.centerXAnchor.constraint(equalTo: expansionScrollView.centerXAnchor),
            noSelectionOverlay.centerYAnchor.constraint(equalTo: expansionScrollView.centerYAnchor),
        ])
    }

    func showEmpty() {
        noSelectionOverlay.isHidden = false
        expansionView.isRichText = false
        expansionView.font = NSFont.systemFont(ofSize: 13)
        expansionView.textColor = .labelColor
        expansionView.string = ""
        expansionView.isEditable = false
        nameField.stringValue = ""
        nameField.isEditable = false
        triggerField.stringValue = ""
        triggerField.isEditable = false
        contentTypePopup.selectItem(at: 0)
        setFormattingBarVisible(false)
        setToolbarEnabled(false)
        currentSnippet = nil
    }

    func show(_ snippet: Snippet) {
        noSelectionOverlay.isHidden = true
        expansionView.isEditable = true
        nameField.isEditable = true
        triggerField.isEditable = true
        setToolbarEnabled(true)
        currentSnippet = snippet
        populate(snippet)
    }

    private func setToolbarEnabled(_ enabled: Bool) {
        [calendarButton, timestampButton, clipboardButton, calculatorButton,
         optionalButton, dropdownButton, conditionButton]
            .forEach { $0?.isEnabled = enabled }
        [boldButton, italicButton, underlineButton, linkButton]
            .forEach { $0?.isEnabled = enabled }
        contentTypePopup?.isEnabled = enabled
    }

    private func setFormattingBarVisible(_ visible: Bool) {
        formattingBar.isHidden = !visible
        formattingBarHeight.constant = visible ? 28 : 0
    }

    private func makeFormatButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let btn = NSButton(title: "", target: self, action: action)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.toolTip = tooltip
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) {
            btn.image = img
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    @objc private func contentTypeChanged() {
        guard !isPopulating else { return }
        let wantsRich = contentTypePopup.indexOfSelectedItem == 1
        if wantsRich {
            let plain = expansionView.string
            expansionView.isRichText = true
            expansionView.textColor = .labelColor
            let attrStr = NSAttributedString(string: plain, attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ])
            expansionView.textStorage?.setAttributedString(attrStr)
            setFormattingBarVisible(true)
            saveCurrentSnippet()
        } else {
            guard let window = view.window else { return }
            if (expansionView.textStorage?.length ?? 0) > 0 {
                let alert = NSAlert()
                alert.messageText = "Formatierung verwerfen?"
                alert.informativeText = "Beim Wechsel zu reinem Text gehen alle Formatierungen verloren."
                alert.addButton(withTitle: "Wechseln")
                alert.addButton(withTitle: "Abbrechen")
                alert.beginSheetModal(for: window) { [weak self] response in
                    guard let self else { return }
                    if response == .alertFirstButtonReturn {
                        self.applyPlainTextMode()
                    } else {
                        self.contentTypePopup.selectItem(at: 1)
                    }
                }
            } else {
                applyPlainTextMode()
            }
        }
    }

    private func applyPlainTextMode() {
        let plain = expansionView.string
        expansionView.isRichText = false
        let plainAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
        ]
        expansionView.textStorage?.setAttributedString(
            NSAttributedString(string: plain, attributes: plainAttrs)
        )
        expansionView.font = NSFont.systemFont(ofSize: 13)
        expansionView.textColor = .labelColor
        setFormattingBarVisible(false)
        saveCurrentSnippet()
    }

    @objc private func boldAction() {
        toggleFontTrait(.boldFontMask)
    }

    @objc private func italicAction() {
        toggleFontTrait(.italicFontMask)
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let storage = expansionView.textStorage else { return }
        let range = expansionView.selectedRange()
        guard range.length > 0 else { return }
        var hasTrait = false
        storage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            if let f = value as? NSFont, NSFontManager.shared.traits(of: f).contains(trait) {
                hasTrait = true
            }
        }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let font = (value as? NSFont) ?? NSFont.systemFont(ofSize: 13)
            let newFont = hasTrait
                ? NSFontManager.shared.convert(font, toNotHaveTrait: trait)
                : NSFontManager.shared.convert(font, toHaveTrait: trait)
            storage.addAttribute(.font, value: newFont, range: subRange)
        }
        storage.endEditing()
        saveCurrentSnippet()
    }

    @objc private func underlineAction() {
        guard let storage = expansionView.textStorage else { return }
        let range = expansionView.selectedRange()
        guard range.length > 0 else { return }
        let hasUnderline = storage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) != nil
        storage.beginEditing()
        if hasUnderline {
            storage.removeAttribute(.underlineStyle, range: range)
        } else {
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        storage.endEditing()
        saveCurrentSnippet()
    }

    @objc private func linkAction() {
        let range = expansionView.selectedRange()
        guard range.length > 0, let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Link einfügen"
        alert.addButton(withTitle: "Einfügen")
        alert.addButton(withTitle: "Abbrechen")
        let urlField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        urlField.placeholderString = "https://..."
        alert.accessoryView = urlField
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn,
                  let self,
                  let url = URL(string: urlField.stringValue.trimmingCharacters(in: .whitespaces))
            else { return }
            self.expansionView.textStorage?.addAttributes([
                .link: url,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ], range: range)
            self.saveCurrentSnippet()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { urlField.becomeFirstResponder() }
    }

    private func populate(_ snippet: Snippet) {
        isPopulating = true
        if let rtf = snippet.expansionRTF,
           let attrStr = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            expansionView.isRichText = true
            expansionView.textColor = .labelColor
            expansionView.textStorage?.setAttributedString(attrStr)
            contentTypePopup.selectItem(at: 1)
            setFormattingBarVisible(true)
        } else {
            expansionView.isRichText = false
            let plainAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ]
            expansionView.textStorage?.setAttributedString(
                NSAttributedString(string: snippet.expansion, attributes: plainAttrs)
            )
            expansionView.font = NSFont.systemFont(ofSize: 13)
            expansionView.textColor = .labelColor
            contentTypePopup.selectItem(at: 0)
            setFormattingBarVisible(false)
        }
        nameField.stringValue = snippet.name
        triggerField.stringValue = snippet.trigger
        isPopulating = false
    }

    private func saveCurrentSnippet() {
        guard !isPopulating, var snippet = currentSnippet else { return }
        snippet.expansion = expansionView.string
        if expansionView.isRichText, let storage = expansionView.textStorage {
            snippet.expansionRTF = storage.rtf(from: NSRange(location: 0, length: storage.length),
                                                documentAttributes: [:])
        } else {
            snippet.expansionRTF = nil
        }
        snippet.name = nameField.stringValue
        snippet.trigger = triggerField.stringValue.trimmingCharacters(in: .whitespaces)
        currentSnippet = snippet
        SnippetManager.shared.update(snippet)
        listVC?.reloadCurrentSelection()
        AppDelegate.shared?.statusBar.rebuild()
    }

    @objc private func showCalendarMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let now = Date()
        for ph in DatePlaceholder.allCases where ph.category == .date {
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

    @objc private func showTimestampMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let now = Date()
        for ph in DatePlaceholder.allCases where ph.category == .time {
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

    @objc private func insertFromClipboard() {
        expansionView.insertText("{ZWISCHENABLAGE}", replacementRange: expansionView.selectedRange())
        saveCurrentSnippet()
    }

    @objc private func showDateArithmeticSheet() {
        let sheet = DateArithmeticSheetController()
        sheet.onApply = { [weak self] placeholder in
            guard let self = self else { return }
            self.expansionView.insertText(placeholder, replacementRange: self.expansionView.selectedRange())
            self.saveCurrentSnippet()
        }
        presentAsSheet(sheet)
    }

    @objc private func insertOptionalBlock() {
        let sel = expansionView.selectedRange()
        let selectedText = sel.length > 0
            ? (expansionView.string as NSString).substring(with: sel)
            : ""

        let sheet = OptionalBlockSheetController()
        sheet.selectedText = selectedText
        sheet.onApply = { [weak self] placeholder in
            guard let self = self else { return }
            self.expansionView.insertText(placeholder, replacementRange: sel)
            self.saveCurrentSnippet()
        }
        presentAsSheet(sheet)
    }

    @objc private func showDropdownDialog() {
        let insertRange = expansionView.selectedRange()
        let sheet = DropdownOptionsSheetController()
        sheet.configure(initialOptions: [])
        sheet.onApply = { [weak self] options, groupId in
            guard let self = self else { return }
            let placeholder = DropdownPlaceholder.make(options: options, groupId: groupId)
            self.expansionView.insertText(placeholder, replacementRange: insertRange)
            self.saveCurrentSnippet()
        }
        presentAsSheet(sheet)
    }

    @objc private func showConditionalBlockDialog() {
        let sheet = ConditionalBlockSheetController()
        sheet.expansionText = expansionView.string
        sheet.onApply = { [weak self] text in
            guard let self = self else { return }
            self.expansionView.insertText(text, replacementRange: self.expansionView.selectedRange())
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
    private var folderVC: FolderViewController!
    private var listVC: SnippetListViewController!
    private var editorVC: SnippetEditorViewController!

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadFromExternalChange),
            name: .snippetsDidReloadExternally,
            object: nil
        )
    }

    @objc private func reloadFromExternalChange() {
        guard window != nil else { return }
        folderVC?.reload()
        listVC?.reload()
    }

    func showAddMode() {
        present()
        listVC.reload()
        listVC.addNewSnippet()
    }

    func showManageMode() {
        present()
    }

    private func present() {
        if window == nil { buildWindow() }
        installMainMenu()
        window?.makeKeyAndOrderFront(nil)
        applyFirstLaunchSizeIfNeeded()
        NSApp.setActivationPolicy(.regular)
        AppIconManager.shared.update()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyFirstLaunchSizeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "JellyfishMainWindowSized"),
              let w = window,
              let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let width  = (sf.width  * 0.7).rounded()
        let height = (sf.height * 0.7).rounded()
        let x = (sf.minX + (sf.width  - width)  / 2).rounded()
        let y = (sf.minY + (sf.height - height) / 2).rounded()
        w.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        UserDefaults.standard.set(true, forKey: "JellyfishMainWindowSized")
    }

    func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu()

        let aboutItem = NSMenuItem(title: "Über Jellyfish",
                                   action: #selector(showAbout),
                                   keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        appMenu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Einstellungen…",
                                   action: #selector(showPreferences),
                                   keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)

        appMenu.addItem(.separator())

        appMenu.addItem(NSMenuItem(title: "Jellyfish ausblenden",
                                   action: #selector(NSApplication.hide(_:)),
                                   keyEquivalent: "h"))

        let hideOthersItem = NSMenuItem(title: "Andere ausblenden",
                                        action: #selector(NSApplication.hideOtherApplications(_:)),
                                        keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        appMenu.addItem(NSMenuItem(title: "Alle einblenden",
                                   action: #selector(NSApplication.unhideAllApplications(_:)),
                                   keyEquivalent: ""))

        appMenu.addItem(.separator())

        appMenu.addItem(NSMenuItem(title: "Jellyfish beenden",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appItem.submenu = appMenu

        let fileItem = NSMenuItem(); mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "Ablage")
        fileMenu.addItem(NSMenuItem(title: "Schließen",
                                    action: #selector(NSWindow.performClose(_:)),
                                    keyEquivalent: "w"))
        fileMenu.addItem(.separator())
        let importItem = NSMenuItem(title: "Importieren…",
                                    action: #selector(importCSVAction),
                                    keyEquivalent: "")
        importItem.target = self
        fileMenu.addItem(importItem)
        let importTEItem = NSMenuItem(title: "TextExpander importieren…",
                                      action: #selector(importTextExpanderAction),
                                      keyEquivalent: "")
        importTEItem.target = self
        fileMenu.addItem(importTEItem)
        fileMenu.addItem(.separator())
        let exportItem = NSMenuItem(title: "Exportieren…",
                                    action: #selector(exportCSVAction),
                                    keyEquivalent: "")
        exportItem.target = self
        fileMenu.addItem(exportItem)
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

    @objc func showAbout() {
        AboutWindowController.shared.show()
    }

    @objc func showPreferences() {
        PreferencesWindowController.shared.show()
    }

    // MARK: - Import / Export

    @objc private func importCSVAction() {
        showManageMode()
        guard let w = window else { return }
        ImportExportController.runImport(convertTextExpander: false, window: w) { [weak self] folderId in
            self?.reloadAfterImport(selectFolderId: folderId)
        }
    }

    @objc private func importTextExpanderAction() {
        showManageMode()
        guard let w = window else { return }
        ImportExportController.runImport(convertTextExpander: true, window: w) { [weak self] folderId in
            self?.reloadAfterImport(selectFolderId: folderId)
        }
    }

    @objc private func exportCSVAction() {
        showManageMode()
        guard let w = window else { return }

        // Aktuell sichtbare Bausteine (abhängig von Ordnerauswahl)
        let currentFolderId = listVC.currentFolderId
        let allSnippets = SnippetManager.shared.snippets
        let toExport: [Snippet]
        let suggestedName: String

        if let fid = currentFolderId {
            let descendants = SnippetManager.shared.descendantFolderIds(of: fid)
            toExport = allSnippets.filter { $0.folderId == fid || descendants.contains($0.folderId ?? UUID()) }
            suggestedName = SnippetManager.shared.folders.first(where: { $0.id == fid })?.name ?? "Bausteine"
        } else {
            toExport = allSnippets
            suggestedName = "Alle-Bausteine"
        }

        ImportExportController.runExport(snippets: toExport, suggestedName: suggestedName, window: w)
    }

    private func reloadAfterImport(selectFolderId: UUID?) {
        folderVC.reload()
        listVC.currentFolderId = selectFolderId
        listVC.reload()
        AppDelegate.shared?.statusBar.rebuild()
    }

    private func buildWindow() {
        folderVC = FolderViewController()
        listVC = SnippetListViewController()
        editorVC = SnippetEditorViewController()
        editorVC.listVC = listVC

        // Use NSSplitView directly (frame-based) instead of NSSplitViewController
        // (Auto Layout). NSSplitViewController creates internal width constraints
        // that fight user drags and cause snap-back on release.
        let sv = NSSplitView()
        sv.isVertical = true
        sv.dividerStyle = .thin
        sv.delegate = self

        // addChild before accessing .view so the lifecycle is wired up first.
        // Accessing .view triggers loadView → viewDidLoad on each VC.
        let containerVC = NSViewController()
        containerVC.addChild(folderVC)
        containerVC.addChild(listVC)
        containerVC.addChild(editorVC)

        // Set explicit initial frames so NSSplitView has a valid starting layout.
        // The split view uses these widths on the first run; autosave overrides on
        // subsequent runs. Heights are corrected automatically when the window shows.
        let h = CGFloat(580)
        let d = CGFloat(1)  // thin divider
        folderVC.view.frame = NSRect(x: 0,               y: 0, width: 180, height: h)
        listVC.view.frame   = NSRect(x: 180 + d,         y: 0, width: 230, height: h)
        editorVC.view.frame = NSRect(x: 180 + d + 230 + d, y: 0, width: 549, height: h)
        sv.addSubview(folderVC.view)
        sv.addSubview(listVC.view)
        sv.addSubview(editorVC.view)

        // New autosave name — old "JellyfishSplitView" entry had corrupted zero
        // positions from a prior NSSplitViewController run and would snap dividers to 0.
        sv.autosaveName = NSSplitView.AutosaveName("JellyfishSplitViewColumns")
        containerVC.view = sv

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 580),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Jellyfish"
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 700, height: 420)
        w.contentViewController = containerVC

        w.setFrameAutosaveName("JellyfishMainWindow")

        window = w

        // Delegates wired after views are loaded so viewDidLoad callbacks
        // don't fire into uninitialised outlets.
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

extension SnippetEditorWindowController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView,
                   constrainMinCoordinate proposedMin: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        let d = splitView.dividerThickness
        switch dividerIndex {
        case 0: return 160
        case 1: return splitView.subviews[0].frame.maxX + d + 160
        default: return proposedMin
        }
    }

    func splitView(_ splitView: NSSplitView,
                   constrainMaxCoordinate proposedMax: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        switch dividerIndex {
        case 0: return 220
        case 1: return splitView.frame.width - 270
        default: return proposedMax
        }
    }

    // Only the editor (rightmost) column absorbs window-resize changes.
    func splitView(_ splitView: NSSplitView,
                   shouldAdjustSizeOfSubview view: NSView) -> Bool {
        return view === editorVC?.view
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
