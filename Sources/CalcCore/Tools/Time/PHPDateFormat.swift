import Foundation

/// Shared calendar and formatter helpers for the time tool.
enum TimeCal {
    static func calendar(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        c.locale = Locale(identifier: "en_US_POSIX")
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }

    /// ICU-pattern formatting in a given zone with English names.
    static func fmt(_ pattern: String, _ date: Date, _ zone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar(zone)
        f.timeZone = zone
        f.dateFormat = pattern
        return f.string(from: date)
    }

    /// "+09:00" style offset of a zone at a date.
    static func offset(_ zone: TimeZone, _ date: Date) -> String {
        let s = zone.secondsFromGMT(for: date)
        let a = abs(s)
        return String(format: "%@%02d:%02d", s < 0 ? "-" : "+", a / 3600, (a % 3600) / 60)
    }

    /// ISO-8601 with numeric offset, e.g. 2026-11-24T05:00:00+09:00.
    static func iso(_ date: Date, _ zone: TimeZone) -> String {
        fmt("yyyy-MM-dd'T'HH:mm:ss", date, zone) + offset(zone, date)
    }
}

/// Formats dates with PHP date() patterns (upstream's time_format setting), e.g. "F jS, Y, g:i:s a".
enum PHPDate {
    private static let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    static func format(_ pattern: String, _ date: Date, _ zone: TimeZone) -> String {
        let cal = TimeCal.calendar(zone)
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday, .weekOfYear, .yearForWeekOfYear], from: date)
        let y = c.year!, mo = c.month!, d = c.day!, h = c.hour!, mi = c.minute!, s = c.second!, wd = c.weekday!
        let h12 = h % 12 == 0 ? 12 : h % 12
        let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
        func p2(_ n: Int) -> String { String(format: "%02d", n) }
        var out = ""
        var escape = false
        for ch in pattern {
            if escape { out.append(ch); escape = false; continue }
            switch ch {
            case "\\": escape = true
            case "d": out += p2(d)
            case "D": out += String(days[wd - 1].prefix(3))
            case "j": out += String(d)
            case "l": out += days[wd - 1]
            case "N": out += String((wd + 5) % 7 + 1)
            case "S":
                let suffix = (11...13).contains(d % 100) ? "th" : (d % 10 == 1 ? "st" : d % 10 == 2 ? "nd" : d % 10 == 3 ? "rd" : "th")
                out += suffix
            case "w": out += String(wd - 1)
            case "z": out += String((cal.ordinality(of: .day, in: .year, for: date) ?? 1) - 1)
            case "W": out += p2(c.weekOfYear ?? 1)
            case "F": out += months[mo - 1]
            case "m": out += p2(mo)
            case "M": out += String(months[mo - 1].prefix(3))
            case "n": out += String(mo)
            case "t": out += String(cal.range(of: .day, in: .month, for: date)?.count ?? 30)
            case "L": out += leap ? "1" : "0"
            case "o": out += String(c.yearForWeekOfYear ?? y)
            case "Y": out += String(y)
            case "y": out += p2(y % 100)
            case "a": out += h < 12 ? "am" : "pm"
            case "A": out += h < 12 ? "AM" : "PM"
            case "g": out += String(h12)
            case "G": out += String(h)
            case "h": out += p2(h12)
            case "H": out += p2(h)
            case "i": out += p2(mi)
            case "s": out += p2(s)
            case "u": out += "000000"
            case "v": out += "000"
            case "e": out += zone.identifier
            case "I": out += zone.isDaylightSavingTime(for: date) ? "1" : "0"
            case "O": out += TimeCal.offset(zone, date).replacingOccurrences(of: ":", with: "")
            case "P": out += TimeCal.offset(zone, date)
            case "T": out += ZoneResolver.abbreviation(zone, at: date)
            case "Z": out += String(zone.secondsFromGMT(for: date))
            case "c": out += format("Y-m-d\\TH:i:sP", date, zone)
            case "r": out += format("D, d M Y H:i:s O", date, zone)
            case "U": out += String(Int(date.timeIntervalSince1970.rounded(.down)))
            default: out.append(ch)
            }
        }
        return out
    }
}
