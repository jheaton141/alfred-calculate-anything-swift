import Foundation

/// Settings for the time tool: the zone dates are read and shown in, and the date pattern letters (j F, Y, g:i a) for result rows.
public struct TimeOptions {
    public var zone: TimeZone
    public var formats: [String]
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
            return convert(instant: x.now, src: ResolvedZone(zone: x.zone), isNow: true, targets: g[0], x)
        }
        if q.hasPrefix("time ") { q = String(q.dropFirst(5)) }
        if let g = ToolSupport.match(#"(.+?)\s+time"#, in: q), ZoneResolver.resolve(g[0]) != nil {
            return convert(instant: x.now, src: ResolvedZone(zone: x.zone), isNow: true, targets: g[0], x)
        }
        guard let re = try? NSRegularExpression(pattern: #"\s+(?:in|to|into)\s+|\s*->\s*"#),
              let m = re.firstMatch(in: q, range: NSRange(location: 0, length: (q as NSString).length)) else { return nil }
        let left = (q as NSString).substring(to: m.range.location)
        let right = (q as NSString).substring(from: m.range.location + m.range.length)

        var srcZone = ResolvedZone(zone: x.zone)
        var instant = x.now
        var isNow = false
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
        } else {
            return nil
        }
        return convert(instant: instant, src: srcZone, isNow: isNow, targets: right, x)
    }

    private func convert(instant: Date, src: ResolvedZone, isNow: Bool, targets: String, _ x: Env) -> [AlfredItem]? {
        let names = targets.components(separatedBy: CharacterSet(charactersIn: ",&")).flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !names.isEmpty, !names.contains(where: \.isEmpty) else { return nil }
        let resolved = names.compactMap { ZoneResolver.resolve($0) }
        guard resolved.count == names.count else { return nil }

        let srcLabel = ZoneResolver.label(src, at: instant)
        let srcText = "\(TimeCal.fmt("H:i", instant, src.zone, x.strings)) \(srcLabel) (\(TimeCal.fmt("D j M", instant, src.zone, x.strings)))"
        return resolved.map { t in
            let label = ZoneResolver.label(t, at: instant)
            let title = "\(TimeCal.fmt("H:i", instant, t.zone, x.strings)) \(label) (\(TimeCal.fmt("D j M", instant, t.zone, x.strings)))"
            let full = "\(TimeCal.fmt("l, F j, Y H:i:s", instant, t.zone, x.strings)) \(label) (UTC\(TimeCal.offset(t.zone, instant)))"
            var sub = String(format: ToolSupport.tr(x.strings, isNow ? "zone_now" : "zone_from", isNow ? "Now: %@" : "From %@"), srcText)
            for note in [src.note, t.note].compactMap({ $0 }) { sub += "; " + note }
            return row(title, sub, raw: TimeCal.iso(instant, t.zone), alt: full, x)
        }
    }
}
