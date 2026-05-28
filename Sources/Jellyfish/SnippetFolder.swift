import Foundation

struct SnippetFolder: Codable, Identifiable {
    var id: UUID
    var name: String
    var parentId: UUID?
    var isShared: Bool

    init(id: UUID = UUID(), name: String, parentId: UUID? = nil, isShared: Bool = false) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.isShared = isShared
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        parentId = try? c.decode(UUID.self, forKey: .parentId)
        isShared = (try? c.decode(Bool.self, forKey: .isShared)) ?? false
    }
}
