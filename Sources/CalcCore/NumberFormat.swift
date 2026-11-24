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

    /// Unformatted number rounded half away from zero, trailing zeros trimmed, "." decimal point.
    public static func plain(_ value: Double, decimals: Int) -> String {
        let d = min(max(decimals, 0), 12)
        var s: String
        // 15 significant digits drop binary float noise such as -6995.039999999999
        let clean = value.isFinite ? (Double(String(format: "%.14e", value)) ?? value) : value
        if clean.isFinite, abs(clean) < 1e15, var src = Decimal(string: String(clean)) {
            var rounded = Decimal()
            NSDecimalRound(&rounded, &src, d, .plain)
            s = String(describing: rounded)
        } else {
            s = String(format: "%.\(d)f", clean)
        }
        if s.contains(".") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() } }
        return s == "-0" ? "0" : s
    }

    /// Parses "1,234.56", "1.234,56", "1234.5" and "1,5": with both separators the last one is the decimal point; a lone one is a decimal point unless repeated or followed by exactly three digits where the setting says thousands. Malformed grouping returns nil.
    public static func parse(_ text: String, settings: Settings) -> Double? {
        var t = text.trimmingCharacters(in: .whitespaces)
        t.removeAll { $0 == " " }
        var exponent = ""
        if let r = t.range(of: #"(?<=[0-9.,])[eE][-+]?[0-9]+$"#, options: .regularExpression) {
            exponent = "e" + t[r].dropFirst().replacingOccurrences(of: "+", with: "")
            t = String(t[..<r.lowerBound])
        }
        var sign = ""
        if let f = t.first, f == "-" || f == "+" { sign = f == "-" ? "-" : ""; t.removeFirst() }
        guard let digits = normalizedDigits(t, settings: settings) else { return nil }
        guard let v = Double(sign + digits + exponent), v.isFinite else { return nil }
        return v
    }

    /// Digits with "." as the only separator, or nil when the grouping is malformed.
    private static func normalizedDigits(_ t: String, settings: Settings) -> String? {
        guard !t.isEmpty, t.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }) else { return nil }
        func isGrouped(_ parts: [Substring]) -> Bool {
            guard let first = parts.first, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }), let last = parts.last, parts.count > 1 else { return false }
            let western = (1...3).contains(first.count) && parts.dropFirst().allSatisfy { $0.count == 3 }
            // Indian grouping: 1-2 leading digits, then pairs, then a final group of three.
            let indian = parts.count > 2 && (1...2).contains(first.count) && last.count == 3 && parts.dropFirst().dropLast().allSatisfy { $0.count == 2 }
            return western || indian
        }
        let hasDot = t.contains("."), hasComma = t.contains(",")
        if !hasDot && !hasComma { return t }
        if hasDot && hasComma {
            let dec: Character = t.lastIndex(of: ".")! > t.lastIndex(of: ",")! ? "." : ","
            let thou: Character = dec == "." ? "," : "."
            let halves = t.split(separator: dec, omittingEmptySubsequences: false)
            guard halves.count == 2, !halves[1].contains(thou), isGrouped(halves[0].split(separator: thou, omittingEmptySubsequences: false)) else { return nil }
            return halves[0].replacingOccurrences(of: String(thou), with: "") + "." + halves[1]
        }
        let sep: Character = hasDot ? "." : ","
        let parts = t.split(separator: sep, omittingEmptySubsequences: false)
        if parts.count > 2 { return isGrouped(parts) ? parts.joined() : nil }
        if parts[1].count > 3, sep == settings.thousandsSeparator { return nil }
        if parts[1].count == 3, sep == settings.thousandsSeparator, isGrouped(parts) { return parts.joined() }
        return parts[0] + "." + parts[1]
    }
}
