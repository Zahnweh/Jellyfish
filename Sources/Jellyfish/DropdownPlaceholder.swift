import Foundation

struct DropdownPlaceholder {
    let rawValue: String   // e.g. "{AUSWAHL:Herr|Frau}" or "{AUSWAHL:G1:Herr|Frau}"
    let options: [String]
    let groupId: Int?      // nil = ungrouped

    // MARK: - Syntax helpers

    static let openTag = "{AUSWAHL:"

    /// Build a placeholder string from options and an optional group ID.
    static func make(options: [String], groupId: Int?) -> String {
        let prefix = groupId.map { "G\($0):" } ?? ""
        return "{AUSWAHL:\(prefix)\(options.joined(separator: "|"))}"
    }

    // MARK: - Parsing

    /// Returns all dropdown placeholders in `text`, in order of appearance.
    static func parse(in text: String) -> [DropdownPlaceholder] {
        var results: [DropdownPlaceholder] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let tagRange = text.range(of: openTag, range: searchStart..<text.endIndex),
              let closeIdx = text[tagRange.upperBound...].firstIndex(of: "}") {
            let inner = String(text[tagRange.upperBound..<closeIdx])

            // Detect optional group prefix: "G<digits>:" or plain "<digits>:"
            var groupId: Int? = nil
            var optionsStr = inner
            if let colonIdx = inner.firstIndex(of: ":") {
                let prefix = inner[inner.startIndex..<colonIdx]
                let digits = prefix.hasPrefix("G") ? String(prefix.dropFirst()) : String(prefix)
                if !digits.isEmpty, digits.allSatisfy(\.isNumber), let gid = Int(digits) {
                    groupId = gid
                    optionsStr = String(inner[inner.index(after: colonIdx)...])
                }
            }

            let opts = optionsStr.components(separatedBy: "|")
                .filter { !$0.isEmpty }
            if !opts.isEmpty {
                let raw = String(text[tagRange.lowerBound...closeIdx])
                results.append(DropdownPlaceholder(rawValue: raw, options: opts, groupId: groupId))
            }
            let next = text.index(after: closeIdx)
            guard next < text.endIndex else { break }
            searchStart = next
        }
        return results
    }

    static func hasPlaceholders(in text: String) -> Bool {
        text.contains(openTag)
    }

    /// Replaces each `{AUSWAHL:…}` with the corresponding element from `selections`.
    static func resolve(text: String, selections: [String]) -> String {
        var result = text
        for (i, ph) in parse(in: text).enumerated() {
            let chosen = i < selections.count ? selections[i] : (ph.options.first ?? "")
            result = result.replacingOccurrences(of: ph.rawValue, with: chosen)
        }
        return result
    }
}
