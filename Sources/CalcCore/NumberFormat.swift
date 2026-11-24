import Foundation

public enum NumberFormat {
    /// Formats with thousands grouping and up to `decimals` fraction digits, trailing zeros trimmed.
    public static func display(_ value: Double, settings: Settings) -> String {
        let s = plain(value, decimals: settings.decimals)
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        var int = String(parts[0]); let neg = int.hasPrefix("-"); if neg { int.removeFirst() }
        var out = ""
        for (i, ch) in int.reversed().enumerated() {
            let groupEnd = i == 3 || (i > 3 && (i - 3) % 2 == 0)
            if settings.numberGrouping == .indian ? groupEnd : (i > 0 && i % 3 == 0) { out.append(settings.thousandsSeparator) }
            out.append(ch)
        }
        out = String(out.reversed())
        if parts.count > 1 { out += String(settings.decimalSeparator) + parts[1] }
        return (neg ? "-" : "") + out
    }

    /// Unformatted number rounded half away from zero (half away from zero), trailing zeros trimmed, "." decimal point.
    public static func plain(_ value: Double, decimals: Int) -> String {
        let d = min(max(decimals, 0), 12)
        var s: String
        if value.isFinite, abs(value) < 1e15, var src = Decimal(string: String(value)) {
            var rounded = Decimal()
            NSDecimalRound(&rounded, &src, d, .plain)
            s = String(format: "%.\(d)f", NSDecimalNumber(decimal: rounded).doubleValue)
        } else {
            s = String(format: "%.\(d)f", value)
        }
        if s.contains(".") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() } }
        return s == "-0" ? "0" : s
    }

    /// Parses "1,234.56", "1.234,56", "1234.5" and "1,5": with both separators the last one is the decimal point; a lone one is a decimal point unless repeated or followed by exactly three digits where the setting says thousands.
    public static func parse(_ text: String, settings: Settings) -> Double? {
        var t = text.trimmingCharacters(in: .whitespaces)
        t.removeAll { $0 == " " }
        // a trailing exponent ("1.5e3", "2E-4") scales the mantissa parsed on its own
        if let r = t.range(of: #"(?<=[0-9.,])[eE][-+]?[0-9]+$"#, options: .regularExpression),
           let exp = Double(t[r].dropFirst().replacingOccurrences(of: "+", with: "")),
           let mantissa = parse(String(t[..<r.lowerBound]), settings: settings) {
            return mantissa * pow(10, exp)
        }
        let hasDot = t.contains("."), hasComma = t.contains(",")
        var decimalChar: Character?
        if hasDot && hasComma {
            decimalChar = t.lastIndex(of: ".")! > t.lastIndex(of: ",")! ? "." : ","
        } else if hasDot || hasComma {
            let sep: Character = hasDot ? "." : ","
            let parts = t.split(separator: sep, omittingEmptySubsequences: false)
            let thousands = parts.count > 2 || (parts.count == 2 && parts[1].count == 3 && sep == settings.thousandsSeparator)
            decimalChar = thousands ? nil : sep
        }
        var out = ""
        for ch in t {
            if ch == decimalChar { out.append(".") } else if ch == "." || ch == "," { continue } else { out.append(ch) }
        }
        return Double(out)
    }
}
