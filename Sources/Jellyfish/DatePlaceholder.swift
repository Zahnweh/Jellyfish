import Foundation

enum DatePlaceholder: String, CaseIterable {
    case ddmmyyyy       = "{TT.MM.JJJJ}"
    case ddmmyy         = "{TT.MM.JJ}"
    case yyyymmdd       = "{JJJJ-MM-TT}"
    case yymmdd         = "{JJ-MM-TT}"
    case hhmm           = "{HH:MM}"
    case hhmmss         = "{HH:MM:SS}"
    case ddmmyyyyhhmm   = "{TT.MM.JJJJ HH:MM}"
    case ddmmyyyyhhmmss = "{TT.MM.JJJJ HH:MM:SS}"

    // Human-readable label shown in menus (rawValue without braces)
    var displayName: String { String(rawValue.dropFirst().dropLast()) }

    private var dateFormat: String {
        switch self {
        case .ddmmyyyy:         return "dd.MM.yyyy"
        case .ddmmyy:           return "dd.MM.yy"
        case .yyyymmdd:         return "yyyy-MM-dd"
        case .yymmdd:           return "yy-MM-dd"
        case .hhmm:             return "HH:mm"
        case .hhmmss:           return "HH:mm:ss"
        case .ddmmyyyyhhmm:     return "dd.MM.yyyy HH:mm"
        case .ddmmyyyyhhmmss:   return "dd.MM.yyyy HH:mm:ss"
        }
    }

    func resolve(at date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = dateFormat
        return fmt.string(from: date)
    }

    /// Replace all known placeholders in `text` with their current values.
    static func resolve(in text: String, at date: Date = Date()) -> String {
        guard text.contains("{") else { return text }
        var result = text
        for ph in allCases where result.contains(ph.rawValue) {
            result = result.replacingOccurrences(of: ph.rawValue, with: ph.resolve(at: date))
        }
        return result
    }
}
