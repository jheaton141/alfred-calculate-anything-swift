import Foundation

/// Settings for the time tool: the zone dates are read and shown in, and the date pattern letters (j F, Y, g:i a) for result rows.
public struct TimeOptions {
    public var zone: TimeZone
    public var formats: [String]
    /// The timezone setting when it names no known zone; results then carry a warning row.
    public var invalidZone: String?
    /// The shipped format, replaced by the language pack's own long date format when a pack defines one.
    public static let defaultFormat = "F jS, Y, g:i:s a"
    public init(zone: TimeZone = .current, formats: [String] = [TimeOptions.defaultFormat]) {
        self.zone = zone; self.formats = formats
    }
}

/// Dates and time zones: "next friday", "2024-01-05 + 30 days", "1700000000", "3pm EST in Tokyo", "time in paris".
public struct TimeTool: Tool {
    public let name = "time"
    public let options: TimeOptions
    public init(options: TimeOptions = TimeOptions()) { self.options = options }

    /// Longest query worth parsing; longer input is never a date and would only cost quadratic parsing time.
    private static let maxQueryLength = 200
    /// Delimiter positions tried when splitting a query into two halves.
    private static let maxSplits = 6

    private struct Env {
        let context: Context
        let parser: DateParser
        let zone: TimeZone
        /// The clock truncated to whole seconds, so relative phrases never show a 59-second remainder.
        let now: Date
        var strings: Strings { context.strings }
    }

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        guard let items = run(query, context: context) else { return nil }
        guard let bad = options.invalidZone else { return items }
        let warning = AlfredItem(title: ToolSupport.tr(context.strings, "zone_setting_invalid", "Invalid time zone setting"),
                                 subtitle: String(format: ToolSupport.tr(context.strings, "zone_setting_invalid_sub", "'%@' is not a known time zone; using %@. Fix it in the workflow configuration."), bad, options.zone.identifier),
                                 arg: "", valid: false)
        return [warning] + items
    }

    private func run(_ query: String, context: Context) -> [AlfredItem]? {
        let now = Date(timeIntervalSince1970: context.now.timeIntervalSince1970.rounded(.down))
        let x = Env(context: context, parser: DateParser(zone: options.zone, now: now), zone: options.zone, now: now)
        let q0 = ToolSupport.normalize(query)
        let explicit = q0 == "time" || q0.hasPrefix("time ")
        guard q0.count <= Self.maxQueryLength else { return explicit ? [invalid(x)] : nil }

        if let r = zoneQuery(q0, x) { return r }
        let q = explicit ? String(q0.dropFirst(4)).trimmingCharacters(in: .whitespaces) : q0
        if q.isEmpty || q == "now" { return dateRows(x.now, isNow: true, x) }
        if let r = timestampQuery(q, explicit: explicit, x) { return r }
        if let r = boundaryQuery(q, x) { return r }
        if let r = calendarQuery(q, x) { return r }
        if let r = businessDaysQuery(q, x) { return r }
        if let r = untilQuery(q, x) { return r }
        if let p = x.parser.parse(q, explicit: explicit) { return dateRows(p.date, isNow: false, x) }
        if let r = differenceQuery(q, explicit: explicit, x) { return r }
        return explicit ? [invalid(x)] : nil
    }

    // MARK: rows

    private func invalid(_ x: Env) -> AlfredItem {
        AlfredItem(title: "...", subtitle: ToolSupport.tr(x.strings, "notvalid_subtitle", "Enter a valid date"), arg: "", valid: false)
    }

    private func row(_ title: String, _ subtitle: String, copy: String? = nil, raw: String, alt: String? = nil, _ x: Env) -> AlfredItem {
        var item = AlfredItem.value(title: title, copy: copy ?? title, raw: raw, withUnit: alt, strings: x.strings)
        item.subtitle = subtitle
        return item
    }

    private func plural(_ n: Int, _ unit: String, _ x: Env) -> String {
        "\(n) \(x.strings["unit_\(unit)" + (abs(n) == 1 ? "" : "s")])"
    }

    private func agoText(_ text: String, _ x: Env) -> String {
        String(format: ToolSupport.tr(x.strings, "time_ago", "%@ ago"), text)
    }

    /// "1 month, 25 days" between two instants, calendar-aware.
    private func span(_ a: Date, _ b: Date, _ x: Env) -> String {
        let (s, e) = a <= b ? (a, b) : (b, a)
        let c = TimeCal.diff(s, e, x.zone)
        let parts: [(Int?, String)] = [(c.y, "year"), (c.mo, "month"), (c.d, "day"), (c.h, "hour"), (c.mi, "minute"), (c.s, "second")]
        let text = parts.compactMap { n, u in (n ?? 0) != 0 ? plural(n!, u, x) : nil }
        return text.isEmpty ? plural(0, "second", x) : text.joined(separator: ", ")
    }

    private func stamp(_ d: Date) -> Int { Int(d.timeIntervalSince1970.rounded(.down)) }

    /// Formatted dates, the timespan from now, and the unix timestamp.
    private func dateRows(_ date: Date, isNow: Bool, _ x: Env) -> [AlfredItem] {
        guard TimeCal.inRange(date) else { return [invalid(x)] }
        let iso = TimeCal.iso(date, x.zone)
        var items: [AlfredItem] = []
        for f in options.formats {
            var pattern = f.trimmingCharacters(in: .whitespaces)
            if pattern == TimeOptions.defaultFormat { pattern = ToolSupport.tr(x.strings, "date_long_format", pattern) }
            let text = DatePattern.format(pattern, date, x.zone, x.strings)
            items.append(row(text, String(format: ToolSupport.tr(x.strings, "format_subtitle", "Format %@"), pattern), raw: iso, x))
        }
        if !isNow {
            let s = span(x.now, date, x)
            let text = date < x.now ? agoText(s, x) : s
            items.append(row(text, ToolSupport.tr(x.strings, "timespan", "Timespan"), raw: iso, x))
        }
        let ts = String(stamp(date))
        items.append(row(ts, ToolSupport.tr(x.strings, "timestamp", "Timestamp"), raw: ts, x))
        return items
    }

    private func plainDate(_ d: Date, _ x: Env) -> String { DatePattern.format("Y-m-d H:i:s", d, x.zone) }

    // MARK: unix timestamps

    private func timestampQuery(_ q: String, explicit: Bool, _ x: Env) -> [AlfredItem]? {
        if let g = ToolSupport.match(#"@?([+-]?\d+(?:\.\d+)?e[+-]?\d{1,2})"#, in: q), q.hasPrefix("@") || explicit,
           let n = Double(g[0]), n == n.rounded(), abs(n) < 1e14 {
            return dateRows(Date(timeIntervalSince1970: String(Int(abs(n))).count == 13 ? n / 1000 : n), isNow: false, x)
        }
        if let g = ToolSupport.match(#"@?(-?\d+)"#, in: q) {
            let digits = g[0].replacingOccurrences(of: "-", with: "")
            let isBare = q.hasPrefix("@") || explicit || digits.count == 10 || digits.count == 13
            guard isBare, let n = Double(g[0]), abs(n) < 1e14 else { return nil }
            let seconds = digits.count == 13 ? n / 1000 : n
            return dateRows(Date(timeIntervalSince1970: seconds), isNow: false, x)
        }
        if let g = ToolSupport.match(#"([+-]?\d+(?:\.\d+)?(?:e[+-]?\d{1,2})?)\s+(?:to|in|as)\s+(?:a\s+)?date"#, in: q), let n = Double(g[0]), n == n.rounded(), abs(n) < 1e11 {
            return dateRows(Date(timeIntervalSince1970: n), isNow: false, x)
        }
        var source: String?
        if let g = ToolSupport.match(#"(?:unix\s+)?(?:timestamp|epoch|unix)\s+(?:of\s+)?(.+)"#, in: q) { source = g[0] }
        else if let g = ToolSupport.match(#"(.+?)\s+(?:to|in|as)\s+(?:a\s+)?(?:unix\s+)?(?:timestamp|epoch|unix|ts)"#, in: q) { source = g[0] }
        guard let text = source else { return nil }
        let date = text == "now" ? x.now : x.parser.parse(text, explicit: true)?.date
        guard let d = date, TimeCal.inRange(d) else { return nil }
        let ts = String(stamp(d))
        let sub = String(format: ToolSupport.tr(x.strings, "unix_timestamp_of", "Unix timestamp of %@"), plainDate(d, x))
        return [row(ts, sub, raw: ts, x), row(ts + "000", ToolSupport.tr(x.strings, "milliseconds", "Milliseconds"), raw: ts + "000", x)]
    }

    // MARK: start / end of

    private func boundaryQuery(_ q: String, _ x: Env) -> [AlfredItem]? {
        guard let g = ToolSupport.match(#"(start|beginning|end)\s+of\s+(.+)"#, in: q) else { return nil }
        let start = g[0] != "end"
        let what = g[1]
        let zone = x.zone
        var interval: (Date, Date)?
        func bounds(_ from: Date, _ unit: String) -> (Date, Date)? {
            let c = TimeCal.civil(from, zone)
            switch unit {
            case "year": return (TimeCal.resolve(c.y, 1, 1, 0, 0, 0, in: zone), TimeCal.resolve(c.y + 1, 1, 1, 0, 0, 0, in: zone))
            case "month":
                let (ny, nm) = c.m == 12 ? (c.y + 1, 1) : (c.y, c.m + 1)
                return (TimeCal.resolve(c.y, c.m, 1, 0, 0, 0, in: zone), TimeCal.resolve(ny, nm, 1, 0, 0, 0, in: zone))
            case "week":
                guard let s = TimeCal.add(.day, -((c.weekday + 6) % 7), to: TimeCal.startOfDay(from, zone), in: zone),
                      let e = TimeCal.add(.day, 7, to: s, in: zone) else { return nil }
                return (s, e)
            case "day":
                let s = TimeCal.startOfDay(from, zone)
                return TimeCal.add(.day, 1, to: s, in: zone).map { (s, $0) }
            case "hour":
                let s = TimeCal.resolve(c.y, c.m, c.d, c.h, 0, 0, in: zone)
                return (s, s.addingTimeInterval(3600))
            default: return nil
            }
        }
        if let y = ToolSupport.match(#"(\d{4})"#, in: what).flatMap({ Int($0[0]) }) {
            interval = x.parser.makeDate(y, 1, 1).flatMap { bounds($0, "year") }
        } else {
            interval = bounds(x.now, what)
        }
        guard let i = interval else { return nil }
        let date = start ? i.0 : i.1.addingTimeInterval(-1)
        return dateRows(date, isNow: false, x)
    }

    // MARK: until / since

    private func untilQuery(_ q: String, _ x: Env) -> [AlfredItem]? {
        guard let g = ToolSupport.match(#"(weeks?|days?|hours?|minutes?|seconds?)\s+(until|till|since)\s+(.+)"#, in: q),
              var target = x.parser.parse(g[2], explicit: true) else { return nil }
        let until = g[1] != "since"
        if target.yearImplicit, let shifted = TimeCal.add(.year, until ? (target.date < x.now ? 1 : 0) : (target.date > x.now ? -1 : 0), to: target.date, in: x.zone) {
            target.date = shifted
        }
        let diff = target.date.timeIntervalSince(x.now)
        let hours = Int(abs(diff) / 3600)
        let requested = g[0].hasSuffix("s") ? String(g[0].dropLast()) : g[0]
        var unit = requested
        var n: Int
        switch unit {
        case "week": n = Int(abs(diff) / 604_800)
        case "day":
            let (a, b) = (TimeCal.civil(target.date, x.zone), TimeCal.civil(x.now, x.zone))
            n = abs(TimeCal.daysFromCivil(a.y, a.m, a.d) - TimeCal.daysFromCivil(b.y, b.m, b.d))
            if n == 0 { n = hours; unit = "hour" }
        case "hour": n = hours
        case "minute": n = Int(abs(diff) / 60)
        default: n = Int(abs(diff))
        }
        let ago = until && diff < 0
        let title = ago ? agoText(plural(n, unit, x), x) : plural(n, unit, x)
        let unitWord = x.strings["unit_\(requested)s"]
        let dateOnly = x.strings["date_only_format"]
        let echo = dateOnly.isEmpty || dateOnly == "date_only_format" ? g[2] : DatePattern.format(dateOnly, target.date, x.zone, x.strings)
        let sub = until
            ? String(format: ToolSupport.tr(x.strings, "until_subtitle", "%@ until %@"), unitWord, echo)
            : String(format: ToolSupport.tr(x.strings, "since_subtitle", "%@ since %@"), unitWord, echo)
        return [row(title, sub, copy: String(n), raw: String(n), x)]
    }

    // MARK: calendar facts

    /// Weekday, day of the year and ISO week of a date: "what day is 2027-03-14", "week number of dec 25".
    private func calendarQuery(_ q: String, _ x: Env) -> [AlfredItem]? {
        let tail = #"\s+(?:is|was|of|for|on)\s+(.+)"#
        var kind = "dow"
        var text: String
        if let g = ToolSupport.match(#"(?:what\s+)?(?:day\s+of\s+(?:the\s+)?year|day\s+number)"# + tail, in: q) { kind = "doy"; text = g[0] }
        else if let g = ToolSupport.match(#"(?:what\s+)?(?:week\s+number|week\s+of\s+(?:the\s+)?year|iso\s+week)"# + tail, in: q) { kind = "week"; text = g[0] }
        else if let g = ToolSupport.match(#"(?:what\s+)?(?:(?:week)?day(?:\s+of\s+(?:the\s+)?week)?)"# + tail, in: q) { text = g[0] }
        else { return nil }
        if text == "it" { text = "today" }
        guard let date = x.parser.parse(text, explicit: true)?.date, TimeCal.inRange(date) else { return nil }
        let c = TimeCal.civil(date, x.zone)
        let doy = TimeCal.daysFromCivil(c.y, c.m, c.d) - TimeCal.daysFromCivil(c.y, 1, 1) + 1
        let yearLength = TimeCal.isLeap(c.y) ? 366 : 365
        let day = TimeCal.fmt("l", date, x.zone, x.strings)
        let when = TimeCal.fmt("Y-m-d", date, x.zone, x.strings)
        let week = TimeCal.fmt("W", date, x.zone, x.strings), weekYear = TimeCal.fmt("o", date, x.zone, x.strings)
        let rows: [String: AlfredItem] = [
            "dow": row(day, String(format: ToolSupport.tr(x.strings, "cal_weekday", "Day of the week for %@"), when), raw: day, x),
            "doy": row("\(ToolSupport.tr(x.strings, "cal_day", "Day")) \(doy) / \(yearLength)", String(format: ToolSupport.tr(x.strings, "cal_doy", "Day of the year for %@"), when), copy: String(doy), raw: String(doy), x),
            "week": row("\(ToolSupport.tr(x.strings, "cal_week", "Week")) \(Int(week) ?? 0)", String(format: ToolSupport.tr(x.strings, "cal_isoweek", "ISO week %@-W%@ for %@"), weekYear, week, when), copy: String(Int(week) ?? 0), raw: String(Int(week) ?? 0), x),
        ]
        let order = [kind] + ["dow", "doy", "week"].filter { $0 != kind }
        return order.compactMap { rows[$0] }
    }

    // MARK: business days

    /// Weekdays after the start day up to and including the end day; day 0 (1970-01-01) was a Thursday.
    private func weekdayCount(from a: Date, to b: Date, _ x: Env) -> Int {
        func upTo(_ c: Civil) -> Int {
            let days = TimeCal.daysFromCivil(c.y, c.m, c.d) + 4   // Monday-based: 0 = Monday of week zero
            let n = days + 1
            return TimeCal.floorDiv(n, 7) * 5 + min(((n % 7) + 7) % 7, 5)
        }
        return max(0, upTo(TimeCal.civil(b, x.zone)) - upTo(TimeCal.civil(a, x.zone)))
    }

    /// "business days until 2027-01-01", "working days since monday", "business days between a and b" (weekends only, no holidays).
    private func businessDaysQuery(_ q: String, _ x: Env) -> [AlfredItem]? {
        let unit = #"(?:business|working|work)\s+days?|weekdays?"#
        var from = x.now, to = x.now
        var showAgo = false
        if let g = ToolSupport.match("(?:" + unit + #")\s+between\s+(.+?)\s+and\s+(.+)"#, in: q) {
            guard let a = x.parser.parse(g[0], explicit: true)?.date, let b = x.parser.parse(g[1], explicit: true)?.date else { return nil }
            (from, to) = a <= b ? (a, b) : (b, a)
        } else if let g = ToolSupport.match("(?:" + unit + #")\s+(until|till|since|to)\s+(.+)"#, in: q) {
            guard var t = x.parser.parse(g[1], explicit: true) else { return nil }
            let until = g[0] != "since"
            if t.yearImplicit, let shifted = TimeCal.add(.year, until ? (t.date < x.now ? 1 : 0) : (t.date > x.now ? -1 : 0), to: t.date, in: x.zone) { t.date = shifted }
            (from, to) = until ? (x.now, t.date) : (t.date, x.now)
            showAgo = until
        } else { return nil }
        guard TimeCal.inRange(from), TimeCal.inRange(to) else { return [invalid(x)] }
        let past = to < from
        let n = past ? weekdayCount(from: to, to: from, x) : weekdayCount(from: from, to: to, x)
        let title = past && showAgo && n > 0 ? agoText(plural(n, "day", x), x) : plural(n, "day", x)
        return [row(title, ToolSupport.tr(x.strings, "business_days_sub", "Business days (Mon-Fri, holidays not counted)"), copy: String(n), raw: String(n), x)]
    }

    // MARK: differences

    private func differenceQuery(_ q: String, explicit: Bool, _ x: Env) -> [AlfredItem]? {
        var body = q
        var isExplicit = explicit
        for prefix in ["days between ", "time between ", "between "] where body.hasPrefix(prefix) {
            body = String(body.dropFirst(prefix.count)); isExplicit = true; break
        }
        guard let re = try? NSRegularExpression(pattern: #"\s+(?:-|to|until|and)\s+"#, options: []) else { return nil }
        let ns = body as NSString
        for m in re.matches(in: body, range: NSRange(location: 0, length: ns.length)).prefix(Self.maxSplits) {
            let left = ns.substring(to: m.range.location), right = ns.substring(from: m.range.location + m.range.length)
            guard let a = x.parser.parse(left, explicit: isExplicit)?.date, let b = x.parser.parse(right, explicit: isExplicit)?.date else { continue }
            let (s, e) = a <= b ? (a, b) : (b, a)
            let days = TimeCal.totalDays(s, e, x.zone)
            let hours = Int(e.timeIntervalSince(s) / 3600)
            let sub = String(format: ToolSupport.tr(x.strings, "difference_subtitle", "Time difference between %@ and %@"), plainDate(a, x), plainDate(b, x))
            return [row(span(a, b, x), sub, raw: String(Int(e.timeIntervalSince(s))), x),
                    row(plural(days, "day", x), ToolSupport.tr(x.strings, "total_days", "Total days"), copy: String(days), raw: String(days), x),
                    row(plural(hours, "hour", x), ToolSupport.tr(x.strings, "total_hours", "Total hours"), copy: String(hours), raw: String(hours), x)]
        }
        return nil
    }

    // MARK: time zones

    private func zoneQuery(_ q0: String, _ x: Env) -> [AlfredItem]? {
        var q = q0
        if let g = ToolSupport.match(#"(?:what(?:'s| is)?\s+(?:the\s+)?)?(?:current\s+)?time(?:\s+is\s+it)?\s+(?:in|at)\s+(.+)"#, in: q) {
            return convert(instant: x.now, src: ResolvedZone(zone: x.zone), isNow: true, targets: g[0], explicit: true, x)
        }
        if q.hasPrefix("time ") { q = String(q.dropFirst(5)) }
        if let g = ToolSupport.match(#"(.+?)\s+time"#, in: q), ZoneResolver.resolve(g[0]) != nil {
            return convert(instant: x.now, src: ResolvedZone(zone: x.zone), isNow: true, targets: g[0], explicit: true, x)
        }
        guard let re = try? NSRegularExpression(pattern: #"\s+(?:in|to|into)\s+|\s*->\s*"#),
              let m = re.firstMatch(in: q, range: NSRange(location: 0, length: (q as NSString).length)) else { return nil }
        let left = (q as NSString).substring(to: m.range.location)
        let right = (q as NSString).substring(from: m.range.location + m.range.length)
        // "3pm in 5 days" is a date, not a zone conversion
        if x.parser.parseTerms(right, signed: false) != nil { return nil }

        var srcZone = ResolvedZone(zone: x.zone)
        var instant = x.now
        var isNow = false
        var srcNote: String?
        if left == "now" {
            isNow = true
        } else if let g = ToolSupport.match(#"now\s+(.+)"#, in: left) {
            guard let z = ZoneResolver.resolve(g[0]) else { return nil }
            srcZone = z; isNow = true
        } else if let g = ToolSupport.match("(?:(.+?)\\s+)?(?:at\\s+)?(\(DateParser.clockPattern))(?:\\s+(.+))?", in: left) {
            guard let clock = DateParser.parseClock(g[1]) else { return nil }
            var trailingDay = ""
            if !g[2].isEmpty {
                if let z = ZoneResolver.resolve(g[2]) { srcZone = z } else if g[0].isEmpty { trailingDay = g[2] } else { return nil }
            }
            let srcParser = DateParser(zone: srcZone.zone, now: x.now)
            var day = srcParser.startOfDay(x.now)
            if !trailingDay.isEmpty {
                guard let p = srcParser.parseBase(trailingDay, explicit: true) else { return nil }
                day = srcParser.startOfDay(p.date)
            } else if !g[0].isEmpty {
                guard let p = srcParser.parseBase(g[0], explicit: true) else { return nil }
                day = srcParser.startOfDay(p.date)
            }
            guard let d = srcParser.setClock(day, clock) else { return nil }
            instant = d
            srcNote = wallClockNote(d, requested: clock, day: day, zone: srcZone, x)
        } else {
            return nil
        }
        return convert(instant: instant, src: srcZone, isNow: isNow, targets: right, explicit: q0.hasPrefix("time "), srcNote: srcNote, x)
    }

    /// A note when the typed wall time falls in a spring-forward gap or a fall-back repeat of its zone.
    private func wallClockNote(_ d: Date, requested: (Int, Int, Int), day: Date, zone: ResolvedZone, _ x: Env) -> String? {
        let want = TimeCal.civil(day, zone.zone), got = TimeCal.civil(d, zone.zone)
        let typed = String(format: "%02d:%02d", requested.0, requested.1)
        let label = ZoneResolver.label(zone, at: d)
        if got.h != requested.0 || got.mi != requested.1 || got.d != want.d {
            return String(format: ToolSupport.tr(x.strings, "dst_gap_note", "%@ does not exist on that day (clocks skip forward); shown as %@"), typed, "\(TimeCal.fmt("H:i", d, zone.zone, x.strings)) \(label)")
        }
        for gap in [1800.0, 3600.0] {
            let later = TimeCal.civil(d.addingTimeInterval(gap), zone.zone)
            if later.h == got.h, later.mi == got.mi, later.d == got.d {
                return String(format: ToolSupport.tr(x.strings, "dst_repeat_note", "%@ happens twice that day (clocks go back); using the first"), typed)
            }
        }
        return nil
    }

    private func convert(instant: Date, src: ResolvedZone, isNow: Bool, targets: String, explicit: Bool, srcNote: String? = nil, _ x: Env) -> [AlfredItem]? {
        let names = targets.components(separatedBy: CharacterSet(charactersIn: ",&")).flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !names.isEmpty, !names.contains(where: \.isEmpty) else { return nil }
        let resolved = names.compactMap { ZoneResolver.resolve($0) }
        guard resolved.count == names.count else {
            // a name that is neither a zone nor a date or clock is an unknown zone, not another tool's query
            let unknown = names.filter { ZoneResolver.resolve($0) == nil && x.parser.parse($0, explicit: true) == nil && DateParser.parseClock($0) == nil }
            let mixed = unknown.contains { $0.range(of: #"\s(?:to|in|into|until|and|-)\s|->"#, options: .regularExpression) != nil }
            guard explicit, !mixed, unknown.count == names.count - resolved.count, !unknown.isEmpty else { return nil }
            return [AlfredItem(title: ToolSupport.tr(x.strings, "zone_unknown", "Unknown time zone"),
                               subtitle: String(format: ToolSupport.tr(x.strings, "zone_unknown_sub", "'%@' is not a time zone, city or abbreviation I know"), unknown.joined(separator: ", ")),
                               arg: "", valid: false)]
        }

        let srcLabel = ZoneResolver.label(src, at: instant)
        let srcText = "\(TimeCal.fmt("H:i", instant, src.zone, x.strings)) \(srcLabel) (\(TimeCal.fmt("D j M", instant, src.zone, x.strings)))"
        return resolved.map { t in
            let label = ZoneResolver.label(t, at: instant)
            let title = "\(TimeCal.fmt("H:i", instant, t.zone, x.strings)) \(label) (\(TimeCal.fmt("D j M", instant, t.zone, x.strings)))"
            let full = "\(TimeCal.fmt("l, F j, Y H:i:s", instant, t.zone, x.strings)) \(label) (UTC\(TimeCal.offset(t.zone, instant)))"
            var sub = String(format: ToolSupport.tr(x.strings, isNow ? "zone_now" : "zone_from", isNow ? "Now: %@" : "From %@"), srcText)
            for note in [src.note, t.note, srcNote].compactMap({ $0 }) { sub += "; " + note }
            var seen = Set<String>()
            for (z, l) in [(src, srcLabel), (t, label)] where z.zone.isDaylightSavingTime(for: instant) && seen.insert(l).inserted {
                sub += "; " + String(format: ToolSupport.tr(x.strings, "dst_in_effect", "%@ is daylight saving time (UTC%@)"), l, TimeCal.offset(z.zone, instant))
            }
            return row(title, sub, raw: TimeCal.iso(instant, t.zone), alt: full, x)
        }
    }
}
