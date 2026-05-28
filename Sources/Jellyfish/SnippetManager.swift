import Foundation

extension Notification.Name {
    static let snippetsDidReloadExternally = Notification.Name("snippetsDidReloadExternally")
}

class SnippetManager {
    static let shared = SnippetManager()

    private let syncFolderKey = "syncFolderPath"
    private let teamFolderKey = "teamFolderPath"
    private var isSaving = false
    private var personalWatcher: DispatchSourceFileSystemObject?
    private var teamWatcher: DispatchSourceFileSystemObject?

    // MARK: - Configured paths

    var syncFolderURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: syncFolderKey) else { return nil }
        return URL(fileURLWithPath: path)
    }

    var teamFolderURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: teamFolderKey) else { return nil }
        return URL(fileURLWithPath: path)
    }

    private var personalDirectory: URL {
        if let sync = syncFolderURL {
            try? FileManager.default.createDirectory(at: sync, withIntermediateDirectories: true)
            return sync
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Jellyfish", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var storageURL: URL  { personalDirectory.appendingPathComponent("snippets.json") }
    private var foldersURL: URL  { personalDirectory.appendingPathComponent("folders.json") }

    private var teamStorageURL: URL? { teamFolderURL?.appendingPathComponent("snippets.json") }
    private var teamFoldersURL: URL? { teamFolderURL?.appendingPathComponent("folders.json") }

    // MARK: - Data

    var snippets: [Snippet] = []
    var folders: [SnippetFolder] = []

    private init() {
        load()
        startWatching()
    }

    // MARK: - Load

    func load() {
        var allSnippets: [Snippet] = []
        var allFolders: [SnippetFolder] = []

        // Personal
        if FileManager.default.fileExists(atPath: storageURL.path),
           let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            allSnippets = decoded
        } else if let bundleURL = Bundle.main.url(forResource: "snippets", withExtension: "json"),
                  let data = try? Data(contentsOf: bundleURL),
                  let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            allSnippets = decoded
        }

        if FileManager.default.fileExists(atPath: foldersURL.path),
           let data = try? Data(contentsOf: foldersURL),
           let decoded = try? JSONDecoder().decode([SnippetFolder].self, from: data) {
            allFolders = decoded.map { var f = $0; f.isShared = false; return f }
        }

        // Team
        if let url = teamStorageURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            allSnippets += decoded
        }

        if let url = teamFoldersURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([SnippetFolder].self, from: data) {
            allFolders += decoded.map { var f = $0; f.isShared = true; return f }
        }

        snippets = allSnippets
        folders = allFolders
    }

    // MARK: - Save

    func save() {
        isSaving = true

        let sharedFolderIds = Set(folders.filter { $0.isShared }.map { $0.id })

        let personalSnippets = snippets.filter { s in
            guard let fid = s.folderId else { return true }
            return !sharedFolderIds.contains(fid)
        }
        let personalFolders = folders.filter { !$0.isShared }

        if let data = try? JSONEncoder().encode(personalSnippets) {
            try? data.write(to: storageURL)
        }
        if let data = try? JSONEncoder().encode(personalFolders) {
            try? data.write(to: foldersURL)
        }

        let sharedSnippets = snippets.filter { s in
            guard let fid = s.folderId else { return false }
            return sharedFolderIds.contains(fid)
        }
        let sharedFolders = folders.filter { $0.isShared }

        if let url = teamStorageURL, let data = try? JSONEncoder().encode(sharedSnippets) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: url)
        }
        if let url = teamFoldersURL, let data = try? JSONEncoder().encode(sharedFolders) {
            try? data.write(to: url)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSaving = false
        }
    }

    // MARK: - Sync folder config

    func setSyncFolder(_ url: URL?) {
        let currentSnippets = snippets
        let currentFolders = folders

        if let url = url {
            UserDefaults.standard.set(url.path, forKey: syncFolderKey)
        } else {
            UserDefaults.standard.removeObject(forKey: syncFolderKey)
        }

        if FileManager.default.fileExists(atPath: storageURL.path) {
            load()
        } else {
            snippets = currentSnippets
            folders = currentFolders
            save()
        }

        startWatching()
        NotificationCenter.default.post(name: .snippetsDidReloadExternally, object: nil)
    }

    func setTeamFolder(_ url: URL?) {
        if let url = url {
            UserDefaults.standard.set(url.path, forKey: teamFolderKey)
        } else {
            UserDefaults.standard.removeObject(forKey: teamFolderKey)
            // Remove shared flag from all folders
            for i in folders.indices { folders[i].isShared = false }
        }

        load()
        startWatching()
        NotificationCenter.default.post(name: .snippetsDidReloadExternally, object: nil)
    }

    // MARK: - Toggle shared

    func toggleShared(folderId: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == folderId }) else { return }
        let nowShared = !folders[idx].isShared
        folders[idx].isShared = nowShared
        let descendants = descendantFolderIds(of: folderId)
        for did in descendants {
            if let didx = folders.firstIndex(where: { $0.id == did }) {
                folders[didx].isShared = nowShared
            }
        }
        save()
    }

    // MARK: - File watching

    private func startWatching() {
        startWatcher(for: personalDirectory, source: &personalWatcher)
        if let teamDir = teamFolderURL {
            startWatcher(for: teamDir, source: &teamWatcher)
        } else {
            teamWatcher?.cancel()
            teamWatcher = nil
        }
    }

    private func startWatcher(for dir: URL,
                               source: inout DispatchSourceFileSystemObject?) {
        source?.cancel()
        source = nil
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        s.setEventHandler { [weak self] in
            guard let self, !self.isSaving else { return }
            self.load()
            NotificationCenter.default.post(name: .snippetsDidReloadExternally, object: nil)
        }
        s.setCancelHandler { close(fd) }
        s.resume()
        source = s
    }

    // MARK: - Snippet management

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        save()
    }

    func batchAdd(_ newSnippets: [Snippet]) {
        snippets.append(contentsOf: newSnippets)
        save()
    }

    func remove(at index: Int) {
        snippets.remove(at: index)
        save()
    }

    func remove(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    func update(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            save()
        }
    }

    @discardableResult
    func duplicate(_ snippet: Snippet) -> Snippet {
        var copy = snippet
        copy.id = UUID()
        copy.name = snippet.name.isEmpty ? "" : snippet.name + " (Kopie)"
        copy.trigger = ""
        snippets.append(copy)
        save()
        return copy
    }

    // MARK: - Folder management

    func addFolder(name: String, parentId: UUID? = nil) -> SnippetFolder {
        // Inherit isShared from parent
        let parentShared = parentId.flatMap { pid in folders.first { $0.id == pid } }?.isShared ?? false
        let folder = SnippetFolder(name: name, parentId: parentId, isShared: parentShared)
        folders.append(folder)
        save()
        return folder
    }

    func descendantFolderIds(of folderId: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        var queue = [folderId]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let children = folders.filter { $0.parentId == current }
            for child in children {
                result.insert(child.id)
                queue.append(child.id)
            }
        }
        return result
    }

    func renameFolder(id: UUID, newName: String) {
        if let index = folders.firstIndex(where: { $0.id == id }) {
            folders[index].name = newName
            save()
        }
    }

    func removeFolder(id: UUID, moveToRoot: Bool) {
        var idsToRemove = [id]
        var queue = [id]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let children = folders.filter { $0.parentId == current }.map { $0.id }
            idsToRemove.append(contentsOf: children)
            queue.append(contentsOf: children)
        }
        for rid in idsToRemove {
            folders.removeAll { $0.id == rid }
            if moveToRoot {
                for i in snippets.indices where snippets[i].folderId == rid {
                    snippets[i].folderId = nil
                }
            } else {
                snippets.removeAll { $0.folderId == rid }
            }
        }
        save()
    }

    // MARK: - Text expansion

    func match(buffer: String) -> (trigger: String, expansion: String)? {
        let sorted = snippets.sorted { $0.trigger.count > $1.trigger.count }
        for snippet in sorted where !snippet.trigger.isEmpty && buffer.hasSuffix(snippet.trigger) {
            let expanded = DateArithmetic.resolve(in: DatePlaceholder.resolve(in: snippet.expansion))
            return (snippet.trigger, expanded)
        }
        return nil
    }
}
