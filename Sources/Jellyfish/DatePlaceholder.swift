import Foundation

enum DatePlaceholder: String, CaseIterable {
    // Combined formats (must appear before single-component cases so longer
    // rawValues are processed first in resolve(in:))
    case yyyymmddhhmmss     = "{JJJJ-MM-TT HH:MM:SS}"
    case ddmmyyyyhhmmss     = "{TT.MM.JJJJ HH:MM:SS}"
    case ddmmyyyyhhmm       = "{TT.MM.JJJJ HH:MM}"
    case ddmmyyyy           = "{TT.MM.JJJJ}"
    case ddmmyy             = "{TT.MM.JJ}"
    case yyyymmdd           = "{JJJJ-MM-TT}"
    case yymmdd             = "{JJ-MM-TT}"
    case mmddyyyy           = "{MM/TT/JJJJ}"
    case mmddyy             = "{MM/TT/JJ}"
    case hhmm12             = "{hh:MM AM/PM}"
    case hhmmss             = "{HH:MM:SS}"
    case hhmm               = "{HH:MM}"
    // Single-component (longer rawValues first within each group)
    case weekdayName        = "{TTTT}"
    case weekdayShort       = "{TTT}"
    case monthName          = "{MMMM}"
    case monthShort         = "{MMM}"
    case year4              = "{JJJJ}"
    case calendarWeek       = "{KW}"
    case month2             = "{MM}"
    case year2              = "{JJ}"
    case day2               = "{TT}"
    case hour2              = "{HH}"
    case minute2            = "{Min}"
    case second2            = "{Sek}"
    case quarter            = "{Q}"
    case month1             = "{M}"
    case day1               = "{T}"

    enum Category { case date, time }

    var category: Category {
        switch self {
        case .hhmm, .hhmmss, .hhmm12, .hour2, .minute2, .second2:
            return .time
        default:
            return .date
        }
    }

    var displayName: String { String(rawValue.dropFirst().dropLast()) }

    private var dateFormat: String {
        switch self {
        case .ddmmyyyy:         return "dd.MM.yyyy"
        case .ddmmyy:           return "dd.MM.yy"
        case .yyyymmdd:         return "yyyy-MM-dd"
        case .yyyymmddhhmmss:   return "yyyy-MM-dd HH:mm:ss"
        case .yymmdd:           return "yy-MM-dd"
        case .mmddyyyy:         return "MM/dd/yyyy"
        case .mmddyy:           return "MM/dd/yy"
        case .hhmm:             return "HH:mm"
        case .hhmmss:           return "HH:mm:ss"
        case .hhmm12:           return "hh:mm a"
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
        case .calendarWeek:     return "ww"
        case .hour2:            return "HH"
        case .minute2:          return "mm"
        case .second2:          return "ss"
        case .quarter:          return ""
        }
    }

    func resolve(at date: Date = Date()) -> String {
        if self == .quarter {
            let month = Calendar.current.component(.month, from: date)
            return "\((month - 1) / 3 + 1)"
        }
        let fmt = DateFormatter()
        fmt.locale = self == .hhmm12 ? Locale(identifier: "en_US") : Locale(identifier: "de_DE")
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
