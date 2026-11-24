import Foundation

/// Query guards and number formatting shared by the units, data storage and px/em/rem tools.
enum ScaleFormat {
    static let maxQueryLength = 200

    enum Verdict { case ok, skip, overflow }

    /// Over-long queries are skipped; a leading run of 309+ digits followed by text is an overflowing number.
    static func check(_ query: String) -> Verdict {
        guard query.utf8.count > maxQueryLength else { return .ok }
        var digits = 0
        var rest = Substring(query.drop { $0 == " " || $0 == "-" || $0 == "+" })
        while let ch = rest.first, ch.isASCII, ch.isNumber { digits += 1; rest = rest.dropFirst() }
        if digits >= 309, rest.prefix(60).contains(where: { $0.isLetter }) { return .overflow }
        return .skip
    }

    /// True when the number text is well formed but too large for a finite Double.
    static func overflowing(_ text: String) -> Bool {
        var t = text.filter { $0 != "," && $0 != " " }
        if t.hasPrefix("-") || t.hasPrefix("+") { t.removeFirst() }
        guard !t.isEmpty, t.allSatisfy({ $0.isASCII && ($0.isNumber || ".eE+-".contains($0)) }) else { return false }
        return Double(t) == .infinity
    }

    /// Rounds to 15 significant digits to drop binary float noise.
    static func clean(_ v: Double) -> Double { v.isFinite ? (Double(String(format: "%.14e", v)) ?? v) : v }

    /// Whole-number digits of a cleaned magnitude of 1e15 or more.
    private static func integerDigits(_ v: Double) -> String {
        let s = String(format: "%.14e", abs(v))
        let parts = s.split(separator: "e")
        guard parts.count == 2, let exp = Int(parts[1]) else { return String(format: "%.0f", abs(v)) }
        return parts[0].filter { $0 != "." } + String(repeating: "0", count: max(exp - 14, 0))
    }

    private static func group(_ digits: String, _ s: Settings) -> String {
        var out = ""
        for (i, ch) in digits.reversed().enumerated() {
            let groupEnd = i == 3 || (i > 3 && (i - 3) % 2 == 0)
            if s.numberGrouping == .indian ? groupEnd : (i > 0 && i % 3 == 0) { out.append(s.thousandsSeparator) }
            out.append(ch)
        }
        return String(out.reversed())
    }

    private static func localized(_ text: String, _ s: Settings) -> String {
        s.decimalSeparator == "." ? text : text.replacingOccurrences(of: ".", with: String(s.decimalSeparator))
    }

    /// Grouped display text; huge values print every digit, non-zero values that round to 0 print in scientific form.
    static func show(_ v: Double, _ s: Settings) -> String {
        let c = clean(v)
        if abs(c) >= 1e15 { return (c < 0 ? "-" : "") + group(integerDigits(c), s) }
        let t = NumberFormat.display(c, settings: s)
        if t == "0", c != 0 { return localized(String(format: "%.4g", c), s) }
        return t
    }

    /// Ungrouped text with "." as the decimal point and no scientific form unless the value is tiny.
    static func plainText(_ v: Double, decimals: Int) -> String {
        let c = clean(v)
        if abs(c) >= 1e15 { return (c < 0 ? "-" : "") + integerDigits(c) }
        let p = NumberFormat.plain(c, decimals: decimals)
        return p == "0" && c != 0 ? String(format: "%.4g", c) : p
    }

    /// Raw copy value: parseable and exact to 15 significant digits, scientific for very small magnitudes.
    static func raw(_ v: Double, decimals: Int = 10) -> String {
        let c = clean(v)
        if abs(c) >= 1e15 { return (c < 0 ? "-" : "") + integerDigits(c) }
        if c != 0, abs(c) < 1e-4 { return String(format: "%.15g", c) }
        return NumberFormat.plain(c, decimals: decimals)
    }

    static func invalid(_ strings: Strings) -> AlfredItem { .error(ToolSupport.tr(strings, "error_math_domain", "Invalid input")) }
}
