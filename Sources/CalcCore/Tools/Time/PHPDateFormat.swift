import Foundation

/// A broken-down local time in a zone, in the proleptic Gregorian calendar.
struct Civil {
    var y: Int, m: Int, d: Int, h: Int, mi: Int, s: Int
    /// 0 = Sunday ... 6 = Saturday.
    var weekday: Int
    /// 0-based day of the year.
    var yearDay: Int
}

/// Proleptic Gregorian calendar arithmetic and DST-aware local-time resolution, independent of Foundation's Julian-hybrid Calendar.
enum TimeCal {
    /// Latest instant (about year 200000) treated as valid; beyond it dates are reported as not valid.
    static let maxSeconds: Double = 6.3e12

    static func inRange(_ date: Date) -> Bool { abs(date.timeIntervalSince1970) <= maxSeconds }

    static func floorDiv(_ a: Int, _ b: Int) -> Int { let q = a / b; return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q }

    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    static func daysInMonth(_ y: Int, _ m: Int) -> Int { [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1] }

    /// Days since 1970-01-01 of a proleptic Gregorian date.
    static func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? y0 - 1 : y0
        let era = floorDiv(y, 400)
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civilFromDays(_ z0: Int) -> (y: Int, m: Int, d: Int) {
        let z = z0 + 719_468
        let era = floorDiv(z, 146_097)
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }

    /// Local wall-clock fields of an instant in a zone.
    static func civil(_ date: Date, _ zone: TimeZone) -> Civil {
        let local = Int(date.timeIntervalSince1970.rounded(.down)) + zone.secondsFromGMT(for: date)
        let days = floorDiv(local, 86_400), sec = local - days * 86_400
        let (y, m, d) = civilFromDays(days)
        return Civil(y: y, m: m, d: d, h: sec / 3600, mi: sec % 3600 / 60, s: sec % 60,
                     weekday: ((days % 7) + 11) % 7, yearDay: days - daysFromCivil(y, 1, 1))
    }

    /// Local clock fields (already range-checked) to an instant; a time inside a DST gap shifts forward by the gap, a repeated time takes the first occurrence.
    static func resolve(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int, in zone: TimeZone) -> Date {
        resolveWall(Double(daysFromCivil(y, m, d) * 86_400 + h * 3600 + mi * 60 + s), in: zone)
    }

    /// `wall` is the local clock reading encoded as seconds since 1970 as if the zone were UTC.
    static func resolveWall(_ wall: Double, in zone: TimeZone) -> Date {
        let w = Date(timeIntervalSince1970: wall)
        let before = zone.secondsFromGMT(for: w.addingTimeInterval(-86_400))
        let after = zone.secondsFromGMT(for: w.addingTimeInterval(86_400))
        let a = w.addingTimeInterval(-Double(before))
        if before == after { return a }
        let b = w.addingTimeInterval(-Double(after))
        let valid = [(a, before), (b, after)].filter { zone.secondsFromGMT(for: $0.0) == $0.1 }.map(\.0)
        return valid.min() ?? a
    }

    static func startOfDay(_ date: Date, _ zone: TimeZone) -> Date {
        let c = civil(date, zone)
        return resolve(c.y, c.m, c.d, 0, 0, 0, in: zone)
    }

    /// Adds days, months or years to the local wall-clock reading (months clamp to month end), resolving the result like `resolve`.
    static func add(_ unit: Calendar.Component, _ n: Int, to date: Date, in zone: TimeZone) -> Date? {
        guard abs(n) < 100_000_000 else { return nil }
        let c = civil(date, zone)
        let frac = date.timeIntervalSince1970 - date.timeIntervalSince1970.rounded(.down)
        var (y, m, d) = (c.y, c.m, c.d)
        switch unit {
        case .day:
            (y, m, d) = civilFromDays(daysFromCivil(y, m, d) + n)
        case .month, .year:
            let total = y * 12 + (m - 1) + (unit == .year ? n * 12 : n)
            y = floorDiv(total, 12); m = total - y * 12 + 1
            d = min(d, daysInMonth(y, m))
        default: return nil
        }
        guard abs(y) < 400_000 else { return nil }
        let result = resolve(y, m, d, c.h, c.mi, c.s, in: zone).addingTimeInterval(frac)
        return inRange(result) ? result : nil
    }

    /// Calendar difference of two instants (start <= end) as years, months, days, hours, minutes, seconds.
    static func diff(_ start: Date, _ end: Date, _ zone: TimeZone) -> (y: Int, mo: Int, d: Int, h: Int, mi: Int, s: Int) {
        func largest(_ unit: Calendar.Component, from base: Date, guess: Int) -> (Int, Date) {
            var n = max(guess, 0)
            while n > 0, let t = add(unit, n, to: base, in: zone), t > end { n -= 1 }
            while let t = add(unit, n + 1, to: base, in: zone), t <= end { n += 1 }
            return (n, n == 0 ? base : (add(unit, n, to: base, in: zone) ?? base))
        }
        let a = civil(start, zone), b = civil(end, zone)
        let (y, afterY) = largest(.year, from: start, guess: b.y - a.y)
        let (mo, afterM) = largest(.month, from: afterY, guess: 0)
        let (d, afterD) = largest(.day, from: afterM, guess: Int(end.timeIntervalSince(afterM) / 86_400))
        var rest = Int(end.timeIntervalSince(afterD).rounded(.down))
        let h = rest / 3600; rest -= h * 3600
        return (y, mo, d, h, rest / 60, rest % 60)
    }

    /// Whole calendar days from start to end (start <= end).
    static func totalDays(_ start: Date, _ end: Date, _ zone: TimeZone) -> Int {
        var n = max(Int(end.timeIntervalSince(start) / 86_400) - 1, 0)
        while let t = add(.day, n + 1, to: start, in: zone), t <= end { n += 1 }
        return n
    }

    /// "HH:mm" style output via PHP date() patterns in a given zone.
    static func fmt(_ pattern: String, _ date: Date, _ zone: TimeZone) -> String { PHPDate.format(pattern, date, zone) }

    /// "+09:00" style offset of a zone at a date.
    static func offset(_ zone: TimeZone, _ date: Date) -> String {
        let s = zone.secondsFromGMT(for: date)
        let a = abs(s)
        return String(format: "%@%02d:%02d", s < 0 ? "-" : "+", a / 3600, (a % 3600) / 60)
    }

    /// ISO-8601 with numeric offset, e.g. 2026-11-24T05:00:00+09:00.
    static func iso(_ date: Date, _ zone: TimeZone) -> String { PHPDate.format("Y-m-d\\TH:i:sP", date, zone) }
}

/// Formats dates with PHP date() patterns (upstream's time_format setting), e.g. "F jS, Y, g:i:s a".
enum PHPDate {
    private static let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private static func year4(_ y: Int) -> String { (y < 0 ? "-" : "") + String(format: "%04d", abs(y)) }

    /// ISO-8601 week-numbering year and week.
    private static func isoWeek(_ c: Civil) -> (Int, Int) {
        let isoWd = (c.weekday + 6) % 7 + 1
        let week = (c.yearDay + 1 - isoWd + 10) / 7
        func weeks(_ y: Int) -> Int {
            let jan1 = ((TimeCal.daysFromCivil(y, 1, 1) + 3) % 7 + 7) % 7  // 0 = Monday
            return jan1 == 3 || (jan1 == 2 && TimeCal.isLeap(y)) ? 53 : 52
        }
        if week < 1 { return (c.y - 1, weeks(c.y - 1)) }
        if week > weeks(c.y) { return (c.y + 1, 1) }
        return (c.y, week)
    }

    static func format(_ pattern: String, _ date: Date, _ zone: TimeZone) -> String {
        let c = TimeCal.civil(date, zone)
        let y = c.y, mo = c.m, d = c.d, h = c.h, mi = c.mi, s = c.s, wd = c.weekday + 1
        let h12 = h % 12 == 0 ? 12 : h % 12
        let leap = TimeCal.isLeap(y)
        let (isoYear, isoWeek) = isoWeek(c)
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
            case "z": out += String(c.yearDay)
            case "W": out += p2(isoWeek)
            case "F": out += months[mo - 1]
            case "m": out += p2(mo)
            case "M": out += String(months[mo - 1].prefix(3))
            case "n": out += String(mo)
            case "t": out += String(TimeCal.daysInMonth(y, mo))
            case "L": out += leap ? "1" : "0"
            case "o": out += year4(isoYear)
            case "Y": out += year4(y)
            case "y": out += p2(abs(y) % 100)
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
