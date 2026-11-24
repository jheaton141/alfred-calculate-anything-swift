import Foundation

/// Settings for the time tool: the zone dates are read and shown in, and the PHP date() patterns for result rows.
public struct TimeOptions {
    public var zone: TimeZone
    public var formats: [String]
    public init(zone: TimeZone = .current, formats: [String] = ["F jS, Y, g:i:s a"]) {
        self.zone = zone; self.formats = formats
    }
}

/// Dates and time zones: "next friday", "2024-01-05 + 30 days", "1700000000", "3pm EST in Tokyo", "time in paris".
public struct TimeTool: Tool {
    public let name = "time"
    public let options: TimeOptions
    public init(options: TimeOptions = TimeOptions()) { self.options = options }

    private struct Env {
        let context: Context
        let parser: DateParser
        let zone: TimeZone
        var now: Date { context.now }
        var strings: Strings { context.strings }
    }

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let x = Env(context: context, parser: DateParser(zone: options.zone, now: context.now), zone: options.zone)
        let q0 = ToolSupport.normalize(query)
        let explicit = q0 == "time" || q0.hasPrefix("time ")

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

    private func plural(_ n: Int, _ unit: String) -> String { "\(n) \(unit)\(abs(n) == 1 ? "" : "s")" }

    /// "1 month, 25 days" between two instants, calendar-aware.
    private func span(_ a: Date, _ b: Date, _ x: Env) -> String {
        let (s, e) = a <= b ? (a, b) : (b, a)
        let c = TimeCal.calendar(x.zone).dateComponents([.year, .month, .day, .hour, .minute, .second], from: s, to: e)
        let parts: [(Int?, String)] = [(c.year, "year"), (c.month, "month"), (c.day, "day"), (c.hour, "hour"), (c.minute, "minute"), (c.second, "second")]
        let text = parts.compactMap { n, u in (n ?? 0) != 0 ? plural(n!, u) : nil }
        return text.isEmpty ? "0 seconds" : text.joined(separator: ", ")
    }

    private func stamp(_ d: Date) -> Int { Int(d.timeIntervalSince1970.rounded(.down)) }

    /// Formatted dates, the timespan from now, and the unix timestamp.
    private func dateRows(_ date: Date, isNow: Bool, _ x: Env) -> [AlfredItem] {
        let iso = TimeCal.iso(date, x.zone)
        var items: [AlfredItem] = []
        for f in options.formats {
            let pattern = f.trimmingCharacters(in: .whitespaces)
            let text = PHPDate.format(pattern, date, x.zone)
            items.append(row(text, String(format: ToolSupport.tr(x.strings, "format_subtitle", "Format %@"), pattern), raw: iso, x))
        }
        if !isNow {
            let s = span(x.now, date, x)
            let text = date < x.now ? s + " ago" : s
            items.append(row(text, "Timespan", raw: iso, x))
        }
        let ts = String(stamp(date))
        items.append(row(ts, "Timestamp", raw: ts, x))
        return items
    }

    private func plainDate(_ d: Date, _ x: Env) -> String { PHPDate.format("Y-m-d H:i:s", d, x.zone) }

    // MARK: unix timestamps

    private func timestampQuery(_ q: String, explicit: Bool, _ x: Env) -> [AlfredItem]? {
        if let g = ToolSupport.match(#"@?(-?\d+)"#, in: q) {
            let digits = g[0].replacingOccurrences(of: "-", with: "")
            let isBare = q.hasPrefix("@") || explicit || digits.count == 10 || digits.count == 13
            guard isBare, let n = Double(g[0]), abs(n) < 1e14 else { return nil }
            let seconds = digits.count == 13 ? n / 1000 : n
            return dateRows(Date(timeIntervalSince1970: seconds), isNow: false, x)
        }
        if let g = ToolSupport.match(#"(-?\d+)\s+(?:to|in|as)\s+(?:a\s+)?date"#, in: q), let n = Double(g[0]), abs(n) < 1e11 {
            return dateRows(Date(timeIntervalSince1970: n), isNow: false, x)
        }
        var source: String?
        if let g = ToolSupport.match(#"(?:unix\s+)?(?:timestamp|epoch|unix)\s+(?:of\s+)?(.+)"#, in: q) { source = g[0] }
        else if let g = ToolSupport.match(#"(.+?)\s+(?:to|in|as)\s+(?:a\s+)?(?:unix\s+)?(?:timestamp|epoch|unix|ts)"#, in: q) { source = g[0] }
        guard let text = source else { return nil }
        let date = text == "now" ? x.now : x.parser.parse(text, explicit: true)?.date
        guard let d = date else { return nil }
        let ts = String(stamp(d))
        let sub = "Unix timestamp of \(plainDate(d, x))"
        return [row(ts, sub, raw: ts, x), row(ts + "000", "Milliseconds", raw: ts + "000", x)]
    }

    // MARK: start / end of

    private func boundaryQuery(_ q: String, _ x: Env) -> [AlfredItem]? {
        guard let g = ToolSupport.match(#"(start|beginning|end)\s+of\s+(.+)"#, in: q) else { return nil }
        let cal = TimeCal.calendar(x.zone)
        let start = g[0] != "end"
        let what = g[1]
        var interval: DateInterval?
        if let y = ToolSupport.match(#"(\d{4})"#, in: what).flatMap({ Int($0[0]) }) {
            interval = x.parser.makeDate(y, 1, 1).flatMap { cal.dateInterval(of: .year, for: $0) }
        } else {
            let units: [String: Calendar.Component] = ["year": .year, "month": .month, "week": .weekOfYear, "day": .day, "hour": .hour]
            guard let comp = units[what] else { return nil }
            interval = cal.dateInterval(of: comp, for: x.now)
        }
        guard let i = interval else { return nil }
        let date = start ? i.start : i.end.addingTimeInterval(-1)
        return dateRows(date, isNow: false, x)
    }

    // MARK: until / since

    private func untilQuery(_ q: String, _ x: Env) -> [AlfredItem]? {
        guard let g = ToolSupport.match(#"(weeks?|days?|hours?|minutes?|seconds?)\s+(until|till|since)\s+(.+)"#, in: q),
              var target = x.parser.parse(g[2], explicit: true) else { return nil }
        let cal = TimeCal.calendar(x.zone)
        let until = g[1] != "since"
        if target.yearImplicit, let shifted = cal.date(byAdding: .year, value: until ? (target.date < x.now ? 1 : 0) : (target.date > x.now ? -1 : 0), to: target.date) {
            target.date = shifted
        }
        let diff = target.date.timeIntervalSince(x.now)
        let hours = Int(abs(diff) / 3600)
        var unit = g[0].hasSuffix("s") ? String(g[0].dropLast()) : g[0]
        var n: Int
        switch unit {
        case "week": n = Int(abs(diff) / 604_800)
        case "day": if hours < 24 { n = hours; unit = "hour" } else { n = Int((Double(hours) / 24).rounded()) }
        case "hour": n = hours
        case "minute": n = Int(abs(diff) / 60)
        default: n = Int(abs(diff))
        }
        let ago = until && diff < 0
        let title = plural(n, unit) + (ago ? " ago" : "")
        let sub = until
            ? String(format: ToolSupport.tr(x.strings, "until_subtitle", "%@ until %@"), g[0], g[2])
            : String(format: ToolSupport.tr(x.strings, "since_subtitle", "%@ since %@"), g[0], g[2])
        return [row(title, sub, copy: String(n), raw: String(n), x)]
    }

    // MARK: differences

    private func differenceQuery(_ q: String, explicit: Bool, _ x: Env) -> [AlfredItem]? {
        var body = q
        for prefix in ["days between ", "time between ", "between "] where body.hasPrefix(prefix) { body = String(body.dropFirst(prefix.count)); break }
        guard let re = try? NSRegularExpression(pattern: #"\s+(?:-|to|until|and)\s+"#, options: []) else { return nil }
        let ns = body as NSString
        for m in re.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
            let left = ns.substring(to: m.range.location), right = ns.substring(from: m.range.location + m.range.length)
            guard let a = x.parser.parse(left, explicit: explicit)?.date, let b = x.parser.parse(right, explicit: explicit)?.date else { continue }
            let (s, e) = a <= b ? (a, b) : (b, a)
            let cal = TimeCal.calendar(x.zone)
            let days = cal.dateComponents([.day], from: s, to: e).day ?? 0
            let hours = Int(e.timeIntervalSince(s) / 3600)
            let sub = String(format: ToolSupport.tr(x.strings, "difference_subtitle", "Time difference between %@ and %@"), plainDate(a, x), plainDate(b, x))
            return [row(span(a, b, x), sub, raw: String(Int(e.timeIntervalSince(s))), x),
                    row(plural(days, "day"), ToolSupport.tr(x.strings, "total_days", "Total days"), copy: String(days), raw: String(days), x),
                    row(plural(hours, "hour"), ToolSupport.tr(x.strings, "total_hours", "Total hours"), copy: String(hours), raw: String(hours), x)]
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
            if !g[2].isEmpty { guard let z = ZoneResolver.resolve(g[2]) else { return nil }; srcZone = z }
            let srcParser = DateParser(zone: srcZone.zone, now: x.now)
            var day = srcParser.cal.startOfDay(for: x.now)
            if !g[0].isEmpty {
                guard let p = srcParser.parseBase(g[0], explicit: true) else { return nil }
                day = srcParser.cal.startOfDay(for: p.date)
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
        let srcText = "\(TimeCal.fmt("HH:mm", instant, src.zone)) \(srcLabel) (\(TimeCal.fmt("EEE d MMM", instant, src.zone)))"
        return resolved.map { t in
            let label = ZoneResolver.label(t, at: instant)
            let title = "\(TimeCal.fmt("HH:mm", instant, t.zone)) \(label) (\(TimeCal.fmt("EEE d MMM", instant, t.zone)))"
            let full = "\(TimeCal.fmt("EEEE, MMMM d, yyyy HH:mm:ss", instant, t.zone)) \(label) (UTC\(TimeCal.offset(t.zone, instant)))"
            var sub = (isNow ? "Now: " : "From ") + srcText
            for note in [src.note, t.note].compactMap({ $0 }) { sub += "; " + note }
            return row(title, sub, raw: TimeCal.iso(instant, t.zone), alt: full, x)
        }
    }
}
