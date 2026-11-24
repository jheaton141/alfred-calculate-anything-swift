import Foundation

/// Tip and bill splitting: "tip 85", "tip 85 at 18%", "tip 18% of 85", "tip 85 20% split 3", "85 tip 18% between 4".
public struct TipTool: Tool {
    public let name = "tip"
    public init() {}

    private static let suggested: [Double] = [15, 18, 20, 25]
    private static let maxPeople = 1_000

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        guard let parsed = Self.parse(ToolSupport.normalize(query), context.settings) else { return nil }
        let str = context.strings
        guard let bill = parsed.bill, bill.isFinite, bill >= 0, bill <= 1e12,
              parsed.percent.map({ $0.isFinite && $0 >= 0 && $0 <= 1_000 }) ?? true,
              parsed.people.map({ $0 >= 1 && $0 <= Self.maxPeople }) ?? true else { return [ToolSupport.invalidInput(str)] }
        let s = context.settings
        let people = parsed.people ?? 1
        let ways = people > 1 ? " " + String(format: ToolSupport.tr(str, "tip_split_ways", "split %d ways"), people) : ""

        func figures(_ pct: Double) -> (tip: Double, total: Double, each: Double) {
            let tip = bill * pct / 100
            return (tip, bill + tip, (bill + tip) / Double(people))
        }
        func pctText(_ p: Double) -> String {
            var t = NumberFormat.plain(p, decimals: 4)
            if s.decimalSeparator != "." { t = t.replacingOccurrences(of: ".", with: String(s.decimalSeparator)) }
            return t + "%"
        }
        func row(_ title: String, _ subtitle: String, copy: Double) -> AlfredItem {
            var item = AlfredItem.value(title: title, copy: ToolSupport.fmt(copy, s), raw: ToolSupport.raw(copy), strings: str)
            item.subtitle = subtitle
            return item
        }

        if let p = parsed.percent {
            let f = figures(p)
            var items = [
                row(String(format: ToolSupport.tr(str, "tip_total", "Total %@"), ToolSupport.fmt(f.total, s)),
                    String(format: ToolSupport.tr(str, "tip_sub", "Tip %@ (%@ of %@)"), ToolSupport.fmt(f.tip, s), pctText(p), ToolSupport.fmt(bill, s)), copy: f.total),
                row(String(format: ToolSupport.tr(str, "tip_amount", "Tip %@"), ToolSupport.fmt(f.tip, s)),
                    String(format: ToolSupport.tr(str, "tip_of", "%@ of %@"), pctText(p), ToolSupport.fmt(bill, s)), copy: f.tip),
            ]
            if people > 1 {
                items.insert(row(String(format: ToolSupport.tr(str, "tip_each", "Each pays %@"), ToolSupport.fmt(f.each, s)),
                                 String(format: ToolSupport.tr(str, "tip_each_sub", "Total %@%@, tip %@ each"), ToolSupport.fmt(f.total, s), ways, ToolSupport.fmt(f.tip / Double(people), s)) + Self.roundingNote(f.each, f.total, people, s), copy: f.each), at: 0)
            }
            return items
        }
        return Self.suggested.map { p in
            let f = figures(p)
            let title = people > 1
                ? String(format: ToolSupport.tr(str, "tip_each_at", "%@: each pays %@"), pctText(p), ToolSupport.fmt(f.each, s))
                : String(format: ToolSupport.tr(str, "tip_total_at", "%@: total %@"), pctText(p), ToolSupport.fmt(f.total, s))
            return row(title, String(format: ToolSupport.tr(str, "tip_line_sub", "Tip %@ on %@, total %@%@"), ToolSupport.fmt(f.tip, s), ToolSupport.fmt(bill, s), ToolSupport.fmt(f.total, s), ways), copy: people > 1 ? f.each : f.total)
        }
    }

    private struct Parsed { var bill: Double?; var percent: Double?; var people: Int? }

    /// nil unless the query contains the word "tip" and a bill amount.
    private static func parse(_ q: String, _ settings: Settings) -> Parsed? {
        guard ToolSupport.match(#".*\btip\b.*"#, in: q) != nil else { return nil }
        var rest = q.replacingOccurrences(of: #"\btip\b"#, with: " ", options: .regularExpression)
        rest = rest.replacingOccurrences(of: #"[$€£¥]|\b(?:usd|eur|gbp|jpy|cad|aud|chf|cny|inr|sek|nok|dkk|mxn|brl)\b"#, with: " ", options: .regularExpression)
        rest = rest.split(separator: " ").joined(separator: " ")
        let n = "(" + ToolSupport.number + ")"
        var people: Int?
        if rest.trimmingCharacters(in: .whitespaces).hasPrefix("-") { return Parsed(bill: -1, percent: nil, people: nil) }
        if let g = ToolSupport.match(#"(.*?)\s*(?:split|between|among|for|/)\s*(\d+)(?:\s*(?:ways|people|persons|guests|diners))?"#, in: rest) {
            guard let count = Int(g[1]) else { return nil }
            people = count; rest = g[0]
        }
        func num(_ t: String) -> Double? { NumberFormat.parse(t, settings: settings) }
        let sep = #"(?:\s+(?:(?:at|@|with)\s*)?|\s*@\s*)"#
        let plus = #"\s*(?:\+|plus)\s*"#
        if let g = ToolSupport.match(n + "\\s*%\\s*(?:of|on)\\s*" + n, in: rest) { return Parsed(bill: num(g[1]), percent: num(g[0]), people: people) }
        if let g = ToolSupport.match(n + plus + n + "\\s*%", in: rest) { return Parsed(bill: num(g[0]), percent: num(g[1]), people: people) }
        if let g = ToolSupport.match(n + sep + n + "\\s*%?", in: rest) { return Parsed(bill: num(g[0]), percent: num(g[1]), people: people) }
        if let g = ToolSupport.match(n, in: rest) { return Parsed(bill: num(g[0]), percent: nil, people: people) }
        return nil
    }

    /// A short note when the rounded shares do not add up to the rounded total.
    static func roundingNote(_ each: Double, _ total: Double, _ people: Int, _ s: Settings) -> String {
        let scale = pow(10, Double(s.decimals))
        let shares = (each * scale).rounded() / scale * Double(people)
        guard abs(shares - (total * scale).rounded() / scale) > 0.5 / scale else { return "" }
        return "; shares add up to \(ToolSupport.fmt(shares, s))"
    }
}
