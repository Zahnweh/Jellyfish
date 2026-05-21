import Foundation

struct Snippet: Codable, Identifiable {
    var id: UUID
    var trigger: String
    var expansion: String
    var name: String
    var folderId: UUID?

    init(id: UUID = UUID(), trigger: String, expansion: String, name: String = "", folderId: UUID? = nil) {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
        self.name = name
        self.folderId = folderId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        trigger = try c.decode(String.self, forKey: .trigger)
        expansion = try c.decode(String.self, forKey: .expansion)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        folderId = try? c.decode(UUID.self, forKey: .folderId)
    }
}
