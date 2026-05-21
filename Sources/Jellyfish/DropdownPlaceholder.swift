import Foundation

struct DropdownPlaceholder {
    let rawValue: String   // e.g. "{AUSWAHL:Herr|Frau|Divers}"
    let options: [String]

    static let openTag = "{AUSWAHL:"

    /// Returns all dropdown placeholders in `text`, in order of appearance.
    static func parse(in text: String) -> [DropdownPlaceholder] {
        var results: [DropdownPlaceholder] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let tagRange = text.range(of: openTag, range: searchStart..<text.endIndex),
              let closeIdx = text[tagRange.upperBound...].firstIndex(of: "}") {
            let inner = String(text[tagRange.upperBound..<closeIdx])
            let opts = inner.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !opts.isEmpty {
                let raw = String(text[tagRange.lowerBound...closeIdx])
                results.append(DropdownPlaceholder(rawValue: raw, options: opts))
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
    /// If `selections` is shorter than the number of placeholders, the first option is used.
    static func resolve(text: String, selections: [String]) -> String {
        var result = text
        for (i, ph) in parse(in: text).enumerated() {
            let chosen = i < selections.count ? selections[i] : (ph.options.first ?? "")
            result = result.replacingOccurrences(of: ph.rawValue, with: chosen)
        }
        return result
    }
}
