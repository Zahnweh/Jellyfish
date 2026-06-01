import Foundation

struct Snippet: Codable, Identifiable {
    var id: UUID
    var trigger: String
    var expansion: String       // plain text, always present (used for search and fallback)
    var expansionRTF: Data?     // nil = plain text snippet
    var name: String
    var folderId: UUID?

    var isRichText: Bool { expansionRTF != nil }

    init(id: UUID = UUID(), trigger: String, expansion: String, expansionRTF: Data? = nil,
         name: String = "", folderId: UUID? = nil) {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
        self.expansionRTF = expansionRTF
        self.name = name
        self.folderId = folderId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        trigger = try c.decode(String.self, forKey: .trigger)
        expansion = try c.decode(String.self, forKey: .expansion)
        expansionRTF = try? c.decode(Data.self, forKey: .expansionRTF)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        folderId = try? c.decode(UUID.self, forKey: .folderId)
    }
}
