import Foundation

enum TimeUnit { case second, minute, hour, day, week, month, year, weekday }

struct TimeTerm { var amount: Double; var unit: TimeUnit }

struct ParsedDate { var date: Date; var hasTime: Bool; var yearImplicit = false }

/// Parses natural-language dates ("next friday", "2024-01-05 + 30 days", "31 December, 2021 18:00") in one zone.
struct DateParser {
    let zone: TimeZone
    let now: Date

    init(zone: TimeZone, now: Date) { self.zone = zone; self.now = now }

    func startOfDay(_ d: Date) -> Date { TimeCal.startOfDay(d, zone) }

    static let unitMap: [String: TimeUnit] = [
        "second": .second, "seconds": .second, "sec": .second, "secs": .second,
        "minute": .minute, "minutes": .minute, "min": .minute, "mins": .minute,
        "hour": .hour, "hours": .hour, "hr": .hour, "hrs": .hour,
        "day": .day, "days": .day, "week": .week, "weeks": .week, "wk": .week, "wks": .week,
        "month": .month, "months": .month, "year": .year, "years": .year, "yr": .year, "yrs": .year,
        "weekday": .weekday, "weekdays": .weekday, "workday": .weekday, "workdays": .weekday, "wd": .weekday,
        "business day": .weekday, "business days": .weekday, "working day": .weekday, "working days": .weekday,
    ]
    static let unitAlt = unitMap.keys.sorted { $0.count > $1.count }.joined(separator: "|")

    static let monthNames: [String: Int] = {
        let full = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
        var m: [String: Int] = [:]
        for (i, n) in full.enumerated() { m[n] = i + 1; m[String(n.prefix(3))] = i + 1 }
        m["sept"] = 9
        return m
    }()
    static let monthAlt = monthNames.keys.sorted { $0.count > $1.count }.joined(separator: "|")

    static let weekdayNames: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7,
        "sun": 1, "mon": 2, "tue": 3, "tues": 3, "wed": 4, "thu": 5, "thur": 5, "thurs": 5, "fri": 6, "sat": 7,
    ]
    static let weekdayAlt = weekdayNames.keys.sorted { $0.count > $1.count }.joined(separator: "|")

    static let clockPattern = #"(?:\d{1,2}(?::\d{2}){1,2}\s*(?:am|pm|a\.m\.|p\.m\.)?|\d{1,2}\s*(?:am|pm|a\.m\.|p\.m\.)|noon|midnight)"#

    /// "3pm", "15:00", "9:30 am", "noon" -> (hour, minute, second); a bare number is not a clock.
    static func parseClock(_ text: String) -> (Int, Int, Int)? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        if t == "noon" { return (12, 0, 0) }
        if t == "midnight" { return (0, 0, 0) }
        guard let g = ToolSupport.match(#"(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?"#, in: t) else { return nil }
        guard !g[3].isEmpty || !g[1].isEmpty else { return nil }
        var h = Int(g[0])!
        let m = Int(g[1]) ?? 0, s = Int(g[2]) ?? 0
        guard m < 60, s < 60 else { return nil }
        if !g[3].isEmpty {
            guard (1...12).contains(h) else { return nil }
            let pm = g[3].hasPrefix("p")
            h = (h % 12) + (pm ? 12 : 0)
        } else {
            guard !g[1].isEmpty, h < 24 else { return nil }
        }
        return (h, m, s)
    }

    func makeDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0, in z: TimeZone? = nil) -> Date? {
        guard (1...12).contains(mo), abs(y) <= 200_000, (1...TimeCal.daysInMonth(y, mo)).contains(d),
              (0..<24).contains(h), (0..<60).contains(mi), (0..<60).contains(s) else { return nil }
        let date = TimeCal.resolve(y, mo, d, h, mi, s, in: z ?? zone)
        return TimeCal.inRange(date) ? date : nil
    }

    func setClock(_ day: Date, _ clock: (Int, Int, Int)) -> Date? {
        let c = TimeCal.civil(day, zone)
        return makeDate(c.y, c.m, c.d, clock.0, clock.1, clock.2)
    }

    // MARK: terms

    /// "3 days", "+2 weeks", "- 1 month", "an hour"; every term needs a sign when `signed`, none may have one otherwise.
    func parseTerms(_ text: String, signed: Bool) -> [TimeTerm]? {
        let pattern = #"(?<![a-z0-9.])(?:(\+|-|plus|minus)\s*)?(?:(\d+(?:\.\d+)?(?:e[+-]?\d{1,2})?)\s*|(an?|one)\s+)("# + Self.unitAlt + #")\b"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return nil }
        var terms: [TimeTerm] = []
        var pos = 0
        func gapOK(_ from: Int, _ to: Int) -> Bool {
            let gap = ns.substring(with: NSRange(location: from, length: to - from)).lowercased()
            return ToolSupport.match(#"[\s,]*(?:and)?[\s,]*"#, in: gap) != nil
        }
        for m in matches {
            guard gapOK(pos, m.range.location) else { return nil }
            pos = m.range.location + m.range.length
            func grp(_ i: Int) -> String { m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i)).lowercased() }
            let sign = grp(1)
            if signed != !sign.isEmpty { return nil }
            let amount = grp(2).isEmpty ? 1.0 : Double(grp(2)) ?? 0
            guard let unit = Self.unitMap[grp(4)] else { return nil }
            terms.append(TimeTerm(amount: sign == "-" || sign == "minus" ? -amount : amount, unit: unit))
        }
        guard gapOK(pos, ns.length) else { return nil }
        return terms
    }

    private func isWeekend(_ d: Date) -> Bool { [0, 6].contains(TimeCal.civil(d, zone).weekday) }

    func apply(_ terms: [TimeTerm], factor: Double = 1, to start: Date) -> Date? {
        var date = start
        for t in terms {
            let n = t.amount * factor
            guard abs(n) <= 1_000_000 else { return nil }
            let whole = n == n.rounded()
            switch t.unit {
            case .month, .year, .weekday:
                guard whole else { return nil }
            default: break
            }
            switch t.unit {
            case .second: date = date.addingTimeInterval(n)
            case .minute: date = date.addingTimeInterval(n * 60)
            case .hour: date = date.addingTimeInterval(n * 3600)
            case .day:
                if whole { guard let d = TimeCal.add(.day, Int(n), to: date, in: zone) else { return nil }; date = d }
                else { date = date.addingTimeInterval(n * 86400) }
            case .week:
                if whole { guard let d = TimeCal.add(.day, Int(n) * 7, to: date, in: zone) else { return nil }; date = d }
                else { date = date.addingTimeInterval(n * 7 * 86400) }
            case .month: guard let d = TimeCal.add(.month, Int(n), to: date, in: zone) else { return nil }; date = d
            case .year: guard let d = TimeCal.add(.year, Int(n), to: date, in: zone) else { return nil }; date = d
            case .weekday:
                let step = n < 0 ? -1 : 1
                var left = Int(abs(n))
                while left > 0 {
                    guard let d = TimeCal.add(.day, step, to: date, in: zone) else { return nil }
                    date = d
                    if !isWeekend(date) { left -= 1 }
                }
            }
            guard TimeCal.inRange(date) else { return nil }
        }
        return date
    }

    // MARK: expressions

    func parse(_ raw: String, explicit: Bool) -> ParsedDate? {
        var s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if s.hasPrefix("on ") { s = String(s.dropFirst(3)) }
        let termPattern = #"(?:\s*(?:\+|-|plus|minus)\s*(?:\d+(?:\.\d+)?(?:e[+-]?\d{1,2})?\s*|(?:an?|one)\s+)(?:"# + Self.unitAlt + #")\b)+"#
        if let g = ToolSupport.match("(.*?)(" + termPattern + ")", in: s) {
            let base = g[0].trimmingCharacters(in: .whitespaces)
            guard let terms = parseTerms(g[1], signed: true) else { return nil }
            let start: ParsedDate? = base.isEmpty ? ParsedDate(date: now, hasTime: true) : parseBase(base, explicit: explicit)
            guard let b = start, let d = apply(terms, to: b.date) else { return nil }
            return ParsedDate(date: d, hasTime: true)
        }
        if let g = ToolSupport.match(#"in\s+(.+)"#, in: s), let terms = parseTerms(g[0], signed: false), let d = apply(terms, to: now) {
            return ParsedDate(date: d, hasTime: true)
        }
        if let g = ToolSupport.match(#"(.+?)\s+(ago|from now|from today|hence)"#, in: s), let terms = parseTerms(g[0], signed: false) {
            let ago = g[1] == "ago"
            let base = g[1] == "from today" ? (parseBase("today", explicit: explicit)?.date ?? now) : now
            if let d = apply(terms, factor: ago ? -1 : 1, to: base) { return ParsedDate(date: d, hasTime: true) }
            return nil
        }
        if let g = ToolSupport.match(#"(.+?)\s+(after|before|from)\s+(.+)"#, in: s), let terms = parseTerms(g[0], signed: false),
           let base = parseBase(g[2], explicit: true), let d = apply(terms, factor: g[1] == "before" ? -1 : 1, to: base.date) {
            return ParsedDate(date: d, hasTime: true)
        }
        if let g = ToolSupport.match(#"(.+?)\s+in\s+(.+)"#, in: s), let terms = parseTerms(g[1], signed: false),
           let base = parseBase(g[0], explicit: true), let d = apply(terms, to: base.date) {
            return ParsedDate(date: d, hasTime: true)
        }
        return parseBase(s, explicit: explicit)
    }

    /// True for the day phrases that may be followed by a clock: today/tomorrow/yesterday and weekday names.
    static func dayWords(_ text: String) -> Bool {
        ToolSupport.match("(?:today|tomorrow|yesterday|(?:(?:next|last|previous|this)\\s+)?(?:\(weekdayAlt)))", in: text) != nil
    }

    /// A single date: keyword, weekday phrase, "next month", or an absolute date.
    func parseBase(_ raw: String, explicit: Bool) -> ParsedDate? {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if s == "now" { return ParsedDate(date: now, hasTime: true) }
        if explicit, Self.parseClock(s) != nil, ToolSupport.match(Self.clockPattern, in: s) != nil {
            return Self.parseClock(s).flatMap { setClock(startOfDay(now), $0) }.map { ParsedDate(date: $0, hasTime: true) }
        }
        if let g = ToolSupport.match("(\(Self.clockPattern))\\s+(?:on\\s+)?(.+)", in: s), Self.parseClock(g[0]) != nil,
           Self.dayWords(g[1]) {
            return parseBase(g[1] + " " + g[0], explicit: explicit)
        }
        if let g = ToolSupport.match(#"(today|tomorrow|yesterday)(?:\s+(?:at\s+)?(.+))?"#, in: s) {
            let offset = g[0] == "tomorrow" ? 1 : g[0] == "yesterday" ? -1 : 0
            if g[1].isEmpty {
                if g[0] == "today" { return ParsedDate(date: startOfDay(now), hasTime: false) }
                return TimeCal.add(.day, offset, to: now, in: zone).map { ParsedDate(date: $0, hasTime: true) }
            }
            guard let clock = Self.parseClock(g[1]), let day = TimeCal.add(.day, offset, to: now, in: zone),
                  let d = setClock(day, clock) else { return nil }
            return ParsedDate(date: d, hasTime: true)
        }
        if let g = ToolSupport.match("(?:(next|last|previous|this)\\s+)?(\(Self.weekdayAlt))(?:\\s+(?:at\\s+)?(.+))?", in: s) {
            let mod = g[0]
            if mod.isEmpty && !g[1].hasSuffix("day") { return nil }
            let target = Self.weekdayNames[g[1]]!
            let today = startOfDay(now)
            let diff = (target - (TimeCal.civil(today, zone).weekday + 1) + 7) % 7
            let delta: Int
            switch mod {
            case "next": delta = diff == 0 ? 7 : diff
            case "last", "previous": delta = diff == 0 ? -7 : diff - 7
            default: delta = diff
            }
            guard var d = TimeCal.add(.day, delta, to: today, in: zone) else { return nil }
            if !g[2].isEmpty { guard let clock = Self.parseClock(g[2]), let withClock = setClock(d, clock) else { return nil }; d = withClock }
            return ParsedDate(date: d, hasTime: !g[2].isEmpty)
        }
        if let g = ToolSupport.match(#"(next|last|previous)\s+(second|minute|hour|day|week|month|year)"#, in: s),
           let unit = Self.unitMap[g[1]], let d = apply([TimeTerm(amount: g[0] == "next" ? 1 : -1, unit: unit)], to: now) {
            return ParsedDate(date: d, hasTime: true)
        }
        return parseAbsolute(s, explicit: explicit)
    }

    func parseAbsolute(_ s: String, explicit: Bool) -> ParsedDate? {
        // ISO 8601 with optional time and offset
        if let g = ToolSupport.match(#"(\d{4})-(\d{2})-(\d{2})(?:[t ]\s*(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?\s*(z|[+-]\d{2}(?::?\d{2})?)?)?"#, in: s) {
            let hasTime = !g[3].isEmpty
            var z = zone
            if !g[6].isEmpty {
                if g[6] == "z" { z = TimeZone(secondsFromGMT: 0)! }
                else {
                    let digits = g[6].dropFirst().replacingOccurrences(of: ":", with: "")
                    let hh = Int(digits.prefix(2)) ?? 0, mm = digits.count > 2 ? Int(digits.suffix(2)) ?? 0 : 0
                    z = TimeZone(secondsFromGMT: (hh * 3600 + mm * 60) * (g[6].hasPrefix("-") ? -1 : 1)) ?? zone
                }
            }
            guard let d = makeDate(Int(g[0])!, Int(g[1])!, Int(g[2])!, Int(g[3]) ?? 0, Int(g[4]) ?? 0, Int(g[5]) ?? 0, in: z),
                  (Int(g[3]) ?? 0) < 24, (Int(g[4]) ?? 0) < 60 else { return nil }
            return ParsedDate(date: d, hasTime: hasTime)
        }
        var datePart = s
        var clock: (Int, Int, Int)?
        if let g = ToolSupport.match("(.+?)(?:,\\s*|\\s+)(?:at\\s+)?(\(Self.clockPattern))", in: s) {
            guard let c = Self.parseClock(g[1]) else { return nil }
            datePart = g[0]; clock = c
        }
        guard let (day, implicit) = parseDay(datePart, explicit: explicit || clock != nil) else { return nil }
        if let c = clock {
            guard let d = setClock(day, c) else { return nil }
            return ParsedDate(date: d, hasTime: true, yearImplicit: implicit)
        }
        return ParsedDate(date: day, hasTime: false, yearImplicit: implicit)
    }

    /// A calendar day (start of day): ISO, numeric d/m/Y styles, or "31 December, 2021".
    func parseDay(_ s: String, explicit: Bool) -> (Date, Bool)? {
        let y0 = TimeCal.civil(now, zone).y
        if let g = ToolSupport.match(#"(\d{4})-(\d{2})-(\d{2})"#, in: s) {
            return makeDate(Int(g[0])!, Int(g[1])!, Int(g[2])!).map { ($0, false) }
        }
        if explicit, let g = ToolSupport.match(#"(\d{1,2})([/.-])(\d{1,2})\2(\d{4})"#, in: s) {
            let a = Int(g[0])!, b = Int(g[2])!, y = Int(g[3])!
            let dayFirst = g[1] != "/" || a > 12
            let (d, m) = dayFirst ? (a, b) : (b, a)
            if let date = makeDate(y, m, d) ?? makeDate(y, d, m) { return (date, false) }
            return nil
        }
        let ord = #"(?:st|nd|rd|th)?"#
        if let g = ToolSupport.match("(\\d{1,2})\(ord)\\s+(?:of\\s+)?(\(Self.monthAlt))\\.?(?:,?\\s*(\\d{4}))?", in: s)
            ?? ToolSupport.match("(\(Self.monthAlt))\\.?\\s+(\\d{1,2})\(ord)(?:,?\\s*(\\d{4}))?", in: s).map({ [$0[1], $0[0], $0[2]] }) {
            guard let m = Self.monthNames[g[1]], let d = Int(g[0]) else { return nil }
            let y = Int(g[2]) ?? y0
            return makeDate(y, m, d).map { ($0, g[2].isEmpty) }
        }
        return nil
    }
}
