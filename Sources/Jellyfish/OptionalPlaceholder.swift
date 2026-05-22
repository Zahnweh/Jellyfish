import Foundation

struct GroupBinding {
    let groupId: Int
    let includedIndices: Set<Int>
}

struct OptionalBlock {
    let label: String
    let content: String
    let rawValue: String  // full "{optional:...}content{/optional}"
    let groupBinding: GroupBinding?
}

struct OptionalPlaceholder {
    static let openPrefix = "{optional:"
    static let closeTag   = "{/optional}"

    static func hasPlaceholders(in text: String) -> Bool {
        text.contains(openPrefix)
    }

    static func parse(in text: String) -> [OptionalBlock] {
        var results: [OptionalBlock] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex {
            guard let openRange = text.range(of: openPrefix, range: searchStart..<text.endIndex) else { break }
            guard let closeBrace = text[openRange.upperBound...].firstIndex(of: "}") else { break }
            let header = String(text[openRange.upperBound..<closeBrace])
            let contentStart = text.index(after: closeBrace)
            guard contentStart <= text.endIndex else { break }
            guard let closeRange = text.range(of: closeTag, range: contentStart..<text.endIndex) else { break }
            let content = String(text[contentStart..<closeRange.lowerBound])
            let rawValue = String(text[openRange.lowerBound..<closeRange.upperBound])

            // Parse optional group binding: "G<id>:<idx1>,<idx2>,...:<label>"
            var label = header
            var groupBinding: GroupBinding? = nil
            if header.hasPrefix("G"), let colonIdx1 = header.firstIndex(of: ":") {
                let groupPart = String(header[header.index(after: header.startIndex)..<colonIdx1])
                if let groupId = Int(groupPart) {
                    let rest = String(header[header.index(after: colonIdx1)...])
                    if let colonIdx2 = rest.firstIndex(of: ":") {
                        let indicesPart = String(rest[rest.startIndex..<colonIdx2])
                        label = String(rest[rest.index(after: colonIdx2)...])
                        let indices = indicesPart.split(separator: ",").compactMap { Int($0) }
                        groupBinding = GroupBinding(groupId: groupId, includedIndices: Set(indices))
                    }
                }
            }

            results.append(OptionalBlock(label: label, content: content, rawValue: rawValue, groupBinding: groupBinding))
            searchStart = closeRange.upperBound
        }
        return results
    }

    /// Included indices → keep content; excluded → remove entire block.
    static func resolve(text: String, included: Set<Int>) -> String {
        var result = text
        for (i, block) in parse(in: text).enumerated().reversed() {
            result = result.replacingOccurrences(of: block.rawValue,
                                                  with: included.contains(i) ? block.content : "")
        }
        return result
    }
}
