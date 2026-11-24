import Foundation

/// Helpers shared by the data storage, px/em/rem, VAT, percentage and math tools.
enum ToolSupport {
    /// A number with optional thousands/decimal separators, either style ("1,234.56" or "1.234,56").
    static let number = #"(?:\d+(?:[.,]\d+)*|[.,]\d+)(?:[eE][-+]?\d+)?"#
    static let signedNumber = "-?" + number

    /// Rewrites "5 lakh", "1.5 crore" (lac, lakhs, crores) as plain numbers: "5 lakh usd" becomes "500000 usd".
    static func expandIndianMultipliers(_ query: String, settings: Settings) -> String {
        let pattern = "(?<![\\w.,])(\\d+(?:[.,]\\d+)*|[.,]\\d+)\\s*(lakhs?|lacs?|crores?)(?![\\p{L}\\d])"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return query }
        var out = query
        let ns = query as NSString
        for m in re.matches(in: query, range: NSRange(location: 0, length: ns.length)).reversed() {
            guard let v = NumberFormat.parse(ns.substring(with: m.range(at: 1)), settings: settings) else { continue }
            let word = ns.substring(with: m.range(at: 2)).lowercased()
            var text = NumberFormat.plain(v * (word.hasPrefix("c") ? 1e7 : 1e5), decimals: 10)
            if settings.decimalSeparator != "." { text = text.replacingOccurrences(of: ".", with: String(settings.decimalSeparator)) }
            out = (out as NSString).replacingCharacters(in: m.range, with: text)
        }
        return out
    }

    /// Lowercases, trims and collapses whitespace.
    static func normalize(_ query: String) -> String {
        query.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Full-match regex (case-insensitive); returns the capture groups, or nil when it does not match.
    static func match(_ pattern: String, in text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: "^" + pattern + "$", options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1..<max(m.numberOfRanges, 1)).map { i in
            m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i))
        }
    }

    /// Display string: grouped, rounded to the user's decimals, but keeps precision for tiny non-zero values.
    static func fmt(_ v: Double, _ s: Settings) -> String {
        var st = s
        if v != 0, abs(v) < 0.5 * pow(10, -Double(max(s.decimals, 0))) { st.decimals = max(s.decimals, 8) }
        return NumberFormat.display(v, settings: st)
    }

    /// Unformatted number for the cmd (raw copy) action.
    static func raw(_ v: Double) -> String { NumberFormat.plain(v, decimals: 10) }

    /// Translation with an English fallback when the language pack lacks the key.
    static func tr(_ strings: Strings, _ key: String, _ fallback: String) -> String {
        let v = strings[key]
        return v == key ? fallback : v
    }

    static func divisionByZero(_ strings: Strings) -> AlfredItem {
        .error(tr(strings, "error_div_zero", "Cannot divide by zero"))
    }
}
