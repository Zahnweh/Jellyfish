import Foundation

class SnippetManager {
    static let shared = SnippetManager()

    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Jellyfish", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("snippets.json")
    }()

    var snippets: [Snippet] = []

    private init() { load() }

    func load() {
        if FileManager.default.fileExists(atPath: storageURL.path),
           let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
            return
        }
        if let bundleURL = Bundle.module.url(forResource: "snippets", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
            save()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: storageURL)
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

    func update(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            save()
        }
    }

    func match(buffer: String) -> (trigger: String, expansion: String)? {
        for snippet in snippets where buffer.hasSuffix(snippet.trigger) {
            return (snippet.trigger, snippet.expansion)
        }
        return nil
    }
}
