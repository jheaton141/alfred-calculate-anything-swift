import Foundation

public enum NumberFormat {
    /// Formats with thousands grouping and up to `decimals` fraction digits, trailing zeros trimmed.
    public static func display(_ value: Double, settings: Settings) -> String {
        let s = plain(value, decimals: settings.decimals)
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        var int = String(parts[0]); let neg = int.hasPrefix("-"); if neg { int.removeFirst() }
        var out = ""
        for (i, ch) in int.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(settings.thousandsSeparator) }
            out.append(ch)
        }
        out = String(out.reversed())
        if parts.count > 1 { out += String(settings.decimalSeparator) + parts[1] }
        return (neg ? "-" : "") + out
    }

    /// Unformatted number, trailing zeros trimmed, "." decimal point.
    public static func plain(_ value: Double, decimals: Int) -> String {
        var s = String(format: "%.\(max(decimals, 0))f", value)
        if s.contains(".") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() } }
        return s == "-0" ? "0" : s
    }

    /// Parses "1,234.56", "1.234,56", "1234.5" using the configured separators; nil if not a number.
    public static func parse(_ text: String, settings: Settings) -> Double? {
        var t = text.trimmingCharacters(in: .whitespaces)
        t.removeAll { $0 == settings.thousandsSeparator || $0 == " " }
        if settings.decimalSeparator != "." { t = t.replacingOccurrences(of: String(settings.decimalSeparator), with: ".") }
        return Double(t)
    }
}
