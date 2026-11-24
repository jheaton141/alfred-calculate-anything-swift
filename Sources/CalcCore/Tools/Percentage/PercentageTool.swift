import Foundation

/// Percentage phrasings: "20% of 150", "150 + 20%", "20% off 150", "50 is what % of 200", "20 is 10% of what", "% change from 50 to 75".
public struct PercentageTool: Tool {
    public let name = "percentage"
    public init() {}

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        guard query.count <= 200 else { return nil }
        let q = ToolSupport.normalize(query).replacingOccurrences(of: #"(?<![a-z])percent(?:age)?(?![a-z])"#, with: "%", options: .regularExpression)
        guard q.contains("%") else { return nil }
        let n = "(\(ToolSupport.number))", sn = "(\(ToolSupport.signedNumber))"
        let st = context.settings
        func num(_ s: String) -> Double? { NumberFormat.parse(s, settings: st) }
        let invalid = [ToolSupport.invalidInput(context.strings)]
        func plain(_ v: Double) -> [AlfredItem] {
            guard v.isFinite else { return invalid }
            let t = ToolSupport.show(v, st)
            return [.value(title: t, copy: t, raw: ToolSupport.rawValue(v, st), strings: context.strings)]
        }

        // N% of M
        if let g = ToolSupport.match("(?:what(?: is|'s|s) |calculate )?\(sn) ?% ?(?:of|in) \(sn)", in: q),
           let p = num(g[0]), let a = num(g[1]) { return plain(p / 100 * a) }

        // N +/- P%
        if let g = ToolSupport.match("\(sn) ?(\\+|plus|-|minus) ?\(sn) ?%", in: q),
           let a = num(g[0]), let p = num(g[2]) {
            let add = g[1] == "+" || g[1] == "plus"
            return plain(add ? a + a * p / 100 : a - a * p / 100)
        }

        // P% off N
        if let g = ToolSupport.match("\(sn) ?% off \(sn)", in: q), let p = num(g[0]), let a = num(g[1]) {
            return plain(a - a * p / 100)
        }

        // A is P% of what
        if let g = ToolSupport.match("\(sn) is \(n) ?% of what", in: q), let a = num(g[0]), let p = num(g[1]) {
            return p == 0 ? [ToolSupport.divisionByZero(context.strings)] : plain(a / (p / 100))
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
        guard pct.isFinite else { return ToolSupport.invalidInput(c.strings) }
        let s = ToolSupport.displaySettings([a, b, pct], c.settings)
        let shown = ToolSupport.show(abs(pct), s)
        let sign = pct > 0 ? "+" : (pct < 0 ? "-" : "")
        let key = pct > 0 ? "change_increase" : (pct < 0 ? "change_decrease" : "change_none")
        let fallback = pct > 0 ? "increase from %@ to %@" : (pct < 0 ? "decrease from %@ to %@" : "no change from %@ to %@")
        let detail = String(format: ToolSupport.tr(c.strings, key, fallback), ToolSupport.show(a, c.settings), ToolSupport.show(b, c.settings))
        let title = "\(sign)\(shown)% (\(detail))"
        return .value(title: title, copy: "\(sign)\(shown)%", raw: ToolSupport.rawValue(pct, c.settings), strings: c.strings)
    }

    private func isWhatPercent(_ a: Double, _ b: Double, _ c: Context) -> [AlfredItem] {
        guard b != 0 else { return [ToolSupport.divisionByZero(c.strings)] }
        let s = c.settings, str = c.strings
        func row(_ title: String, _ v: Double) -> AlfredItem { .value(title: title, copy: title, raw: ToolSupport.rawValue(v, s), strings: str) }
        func show(_ v: Double) -> String { ToolSupport.show(v, s) }
        let pct = a / b * 100
        guard pct.isFinite else { return [ToolSupport.invalidInput(str)] }
        let isFmt = ToolSupport.tr(str, "percentage_result", "%@ is %@ of %@")
        var rows = [row(String(format: isFmt, show(a), show(pct) + "%", show(b)), pct)]
        let lo = min(a, b), hi = max(a, b)
        // bases use abs() like the change rows, so negative numbers give positive magnitudes
        if lo != 0, case let v = (hi - lo) / abs(lo) * 100, v.isFinite {
            rows.append(row(String(format: ToolSupport.tr(str, "percentage_increase", "The percentage increase from %@ to %@ is %@"),
                                   show(lo), show(hi), show(v) + "%"), v))
        }
        if hi != 0, case let v = (hi - lo) / abs(hi) * 100, v.isFinite {
            rows.append(row(String(format: ToolSupport.tr(str, "percentage_decrease", "The percentage decrease from %@ to %@ is %@"),
                                   show(hi), show(lo), show(v) + "%"), v))
        }
        return rows
    }
}
