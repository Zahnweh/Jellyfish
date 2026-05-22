import Foundation

class SnippetManager {
    static let shared = SnippetManager()

    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Jellyfish", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("snippets.json")
    }()

    private let foldersURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Jellyfish", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("folders.json")
    }()

    var snippets: [Snippet] = []
    var folders: [SnippetFolder] = []

    private init() { load() }

    func load() {
        // Load snippets
        if FileManager.default.fileExists(atPath: storageURL.path),
           let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
        } else if let bundleURL = Bundle.main.url(forResource: "snippets", withExtension: "json"),
                  let data = try? Data(contentsOf: bundleURL),
                  let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
            save()
        }

        // Load folders
        if FileManager.default.fileExists(atPath: foldersURL.path),
           let data = try? Data(contentsOf: foldersURL),
           let decoded = try? JSONDecoder().decode([SnippetFolder].self, from: data) {
            folders = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: storageURL)
        }
        if let data = try? JSONEncoder().encode(folders) {
            try? data.write(to: foldersURL)
        }
    }

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
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

    // MARK: - Folder management

    func addFolder(name: String, parentId: UUID? = nil) -> SnippetFolder {
        let folder = SnippetFolder(name: name, parentId: parentId)
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

    /// Remove folder and all its descendants. Snippets are moved to root or deleted.
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

    // MARK: - Text expansion (unchanged, operates on all snippets)

    func match(buffer: String) -> (trigger: String, expansion: String)? {
        let sorted = snippets.sorted { $0.trigger.count > $1.trigger.count }
        for snippet in sorted where !snippet.trigger.isEmpty && buffer.hasSuffix(snippet.trigger) {
            let expanded = DateArithmetic.resolve(in: DatePlaceholder.resolve(in: snippet.expansion))
            return (snippet.trigger, expanded)
        }
        return nil
    }
}
