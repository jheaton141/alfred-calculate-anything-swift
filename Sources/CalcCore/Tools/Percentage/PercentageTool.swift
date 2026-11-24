import Foundation

/// Percentage phrasings: "20% of 150", "150 + 20%", "20% off 150", "50 is what % of 200", "20 is 10% of what", "% change from 50 to 75".
public struct PercentageTool: Tool {
    public let name = "percentage"
    public init() {}

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let q = ToolSupport.normalize(query)
        guard q.contains("%") || q.contains("percent") else { return nil }
        let n = "(\(ToolSupport.number))", sn = "(\(ToolSupport.signedNumber))"
        let st = context.settings
        func num(_ s: String) -> Double? { NumberFormat.parse(s, settings: st) }
        func item(_ title: String, _ value: Double, copy: String? = nil) -> AlfredItem {
            .value(title: title, copy: copy ?? title, raw: ToolSupport.raw(value), strings: context.strings)
        }
        func plain(_ v: Double) -> AlfredItem { item(ToolSupport.fmt(v, st), v) }

        // N% of M
        if let g = ToolSupport.match("(?:what(?: is|'s|s) |calculate )?\(n) ?% ?(?:of|in) \(sn)", in: q),
           let p = num(g[0]), let a = num(g[1]) { return [plain(p / 100 * a)] }

        // N +/- P%
        if let g = ToolSupport.match("\(sn) ?(\\+|plus|-|minus) ?\(n) ?%", in: q),
           let a = num(g[0]), let p = num(g[2]) {
            let add = g[1] == "+" || g[1] == "plus"
            return [plain(add ? a + a * p / 100 : a - a * p / 100)]
        }

        // P% off N
        if let g = ToolSupport.match("\(n) ?% off \(sn)", in: q), let p = num(g[0]), let a = num(g[1]) {
            return [plain(a - a * p / 100)]
        }

        // A is P% of what
        if let g = ToolSupport.match("\(sn) is \(n) ?% of what", in: q), let a = num(g[0]), let p = num(g[1]) {
            return p == 0 ? [ToolSupport.divisionByZero(context.strings)] : [plain(a / (p / 100))]
        }

        // percentage change between two numbers
        let change = [
            "(?:%|percent|percentage) ?change (?:from )?\(sn) ?(?:to|and|->|→) ?\(sn)",
            "(?:change )?(?:from )?\(sn) ?(?:to|->|→) ?\(sn) ?(?:%|percent|percentage) ?(?:change|increase|decrease|difference)",
        ]
        for pattern in change {
            if let g = ToolSupport.match(pattern, in: q), let a = num(g[0]), let b = num(g[1]) {
                return [percentChange(from: a, to: b, context)]
            }
        }

        // A is what % of B
        let what = "(?:is what ?(?:%|percent)(?: of)?|as an? ?(?:%|percent)(?: of)?)"
        if let g = ToolSupport.match("\(sn) ?\(what) ?\(sn)", in: q), let a = num(g[0]), let b = num(g[1]) {
            return isWhatPercent(a, b, context)
        }
        return nil
    }

    private func percentChange(from a: Double, to b: Double, _ c: Context) -> AlfredItem {
        guard a != 0 else { return ToolSupport.divisionByZero(c.strings) }
        let pct = (b - a) / abs(a) * 100
        let shown = ToolSupport.fmt(abs(pct), c.settings)
        let sign = pct > 0 ? "+" : (pct < 0 ? "-" : "")
        let key = pct > 0 ? "change_increase" : (pct < 0 ? "change_decrease" : "change_none")
        let fallback = pct > 0 ? "increase from %@ to %@" : (pct < 0 ? "decrease from %@ to %@" : "no change from %@ to %@")
        let detail = String(format: ToolSupport.tr(c.strings, key, fallback), ToolSupport.fmt(a, c.settings), ToolSupport.fmt(b, c.settings))
        let title = "\(sign)\(shown)% (\(detail))"
        return .value(title: title, copy: "\(sign)\(shown)%", raw: ToolSupport.raw(pct), strings: c.strings)
    }

    private func isWhatPercent(_ a: Double, _ b: Double, _ c: Context) -> [AlfredItem] {
        guard b != 0 else { return [ToolSupport.divisionByZero(c.strings)] }
        let s = c.settings, str = c.strings
        func row(_ title: String, _ v: Double) -> AlfredItem { .value(title: title, copy: title, raw: ToolSupport.raw(v), strings: str) }
        let pct = a / b * 100
        let isFmt = ToolSupport.tr(str, "percentage_result", "%@ is %@ of %@")
        var rows = [row(String(format: isFmt, ToolSupport.fmt(a, s), ToolSupport.fmt(pct, s) + "%", ToolSupport.fmt(b, s)), pct)]
        let lo = min(a, b), hi = max(a, b)
        if lo != 0 {
            let v = (hi - lo) / lo * 100
            rows.append(row(String(format: ToolSupport.tr(str, "percentage_increase", "The percentage increase from %@ to %@ is %@"),
                                   ToolSupport.fmt(lo, s), ToolSupport.fmt(hi, s), ToolSupport.fmt(v, s) + "%"), v))
        }
        if hi != 0 {
            let v = (hi - lo) / hi * 100
            rows.append(row(String(format: ToolSupport.tr(str, "percentage_decrease", "The percentage decrease from %@ to %@ is %@"),
                                   ToolSupport.fmt(hi, s), ToolSupport.fmt(lo, s), ToolSupport.fmt(v, s) + "%"), v))
        }
        return rows
    }
}
