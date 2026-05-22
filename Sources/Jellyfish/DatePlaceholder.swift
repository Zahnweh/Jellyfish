import Foundation

enum DatePlaceholder: String, CaseIterable {
    // Combined formats (must appear before single-component cases so longer
    // rawValues are processed first in resolve(in:))
    case ddmmyyyyhhmmss = "{TT.MM.JJJJ HH:MM:SS}"
    case ddmmyyyyhhmm   = "{TT.MM.JJJJ HH:MM}"
    case ddmmyyyy       = "{TT.MM.JJJJ}"
    case ddmmyy         = "{TT.MM.JJ}"
    case yyyymmdd       = "{JJJJ-MM-TT}"
    case yymmdd         = "{JJ-MM-TT}"
    case hhmmss         = "{HH:MM:SS}"
    case hhmm           = "{HH:MM}"
    // Single-component (longer rawValues first within each group)
    case weekdayName    = "{TTTT}"
    case weekdayShort   = "{TTT}"
    case monthName      = "{MMMM}"
    case monthShort     = "{MMM}"
    case year4          = "{JJJJ}"
    case month2         = "{MM}"
    case year2          = "{JJ}"
    case day2           = "{TT}"
    case month1         = "{M}"
    case day1           = "{T}"

    enum Category { case date, time }

    var category: Category {
        switch self {
        case .hhmm, .hhmmss: return .time
        default:             return .date
        }
    }

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
        case .year4:            return "yyyy"
        case .year2:            return "yy"
        case .monthName:        return "MMMM"
        case .monthShort:       return "MMM"
        case .month2:           return "MM"
        case .month1:           return "M"
        case .weekdayName:      return "EEEE"
        case .weekdayShort:     return "EEE"
        case .day2:             return "dd"
        case .day1:             return "d"
        }
    }

    func resolve(at date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = dateFormat
        return fmt.string(from: date)
    }

    static func resolve(in text: String, at date: Date = Date()) -> String {
        guard text.contains("{") else { return text }
        var result = text
        for ph in allCases where result.contains(ph.rawValue) {
            result = result.replacingOccurrences(of: ph.rawValue, with: ph.resolve(at: date))
        }
        return result
    }
}
