import Foundation

/// Base conversion between binary, octal, decimal and hex for non-negative whole numbers up to 64 bits.
/// Only claims queries whose target is a base word ("255 to hex", "0xff to dec", "ff hex to bin").
public struct RadixTool: Tool {
    public let name = "radix"
    public init() {}

    private struct Base {
        let radix: Int, prefix: String, label: String
    }
    private static let bases: [String: Base] = {
        let bin = Base(radix: 2, prefix: "0b", label: "binary"), oct = Base(radix: 8, prefix: "0o", label: "octal")
        let dec = Base(radix: 10, prefix: "", label: "decimal"), hex = Base(radix: 16, prefix: "0x", label: "hex")
        return ["bin": bin, "binary": bin, "oct": oct, "octal": oct, "dec": dec, "decimal": dec, "hex": hex, "hexadecimal": hex]
    }()
    private static let word = "(bin|binary|oct|octal|dec|decimal|hex|hexadecimal)"
    private static let pattern = "(?:" + word + #"\s+)?([+-]?[0-9a-z_.]+(?:(?<=e)[+-][0-9]+)?)(?:\s+"# + word + #")?\s+(?:to|in|as|into)\s+"# + word

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        guard let m = ToolSupport.match(Self.pattern, in: ToolSupport.normalize(query)), m.count == 4,
              let target = Self.bases[m[3]] else { return nil }
        var token = m[1]
        if token.hasPrefix("+") { token.removeFirst() }
        // A base word may come before or after the number, not both.
        if !m[0].isEmpty && !m[2].isEmpty { return nil }
        let word = (m[0].isEmpty ? m[2] : m[0]), wordBase = Self.bases[word]

        var digits = token
        let source: Base
        if let prefixed = Self.bases.values.first(where: { !$0.prefix.isEmpty && token.hasPrefix($0.prefix) }) {
            if let w = wordBase, w.radix != prefixed.radix, w.radix != 16 { return nil }
            if let w = wordBase, w.radix == 16, prefixed.radix != 16 { source = w } else {
                source = prefixed; digits.removeFirst(2)
            }
        } else if let w = wordBase {
            source = w
        } else if Self.isScientific(token) {
            source = Self.bases["dec"]!
        } else if token.contains(where: { $0.isNumber }), token.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }) {
            source = Self.bases["dec"]!
        } else {
            return nil
        }

        let invalid = ToolSupport.tr(context.strings, "error_radix_invalid", "Enter a whole number from 0 to 18446744073709551615")
        if source.radix == 10, Self.isScientific(digits) {
            guard let whole = Self.wholeNumber(digits) else { return [.error(invalid)] }
            digits = whole
        }
        // digit separators may sit only between digits
        if digits.contains("_") {
            guard !digits.hasPrefix("_"), !digits.hasSuffix("_"), !digits.contains("__") else { return [.error(invalid)] }
            digits.removeAll { $0 == "_" }
        }
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && ($0.isNumber || $0.isLetter) }),
              let n = UInt64(digits, radix: source.radix) else { return [.error(invalid)] }

        let strings = context.strings
        let plain = String(n, radix: target.radix)
        let label: (Base) -> String = { strings["radix_" + $0.label] }
        let item = AlfredItem(
            title: target.prefix + plain, subtitle: String(format: ToolSupport.tr(strings, "radix_subtitle", "%@ %@ → %@"), label(source), digits, label(target)), arg: plain,
            mods: .init(cmd: .init(arg: target.prefix + plain, subtitle: target.prefix.isEmpty
                ? ToolSupport.tr(strings, "radix_copy_no_prefix", "Copy with no prefix")
                : String(format: ToolSupport.tr(strings, "radix_copy_prefix", "Copy with %@ prefix"), target.prefix))))
        return [item]
    }

    private static let sciPattern = #"[+-]?\d+(?:\.\d+)?e[+-]?\d{1,3}"#

    private static func isScientific(_ t: String) -> Bool { ToolSupport.match(sciPattern, in: t) != nil }

    /// Plain digits of a non-negative integral scientific-notation number, or nil when negative, fractional or too large.
    private static func wholeNumber(_ t: String) -> String? {
        guard !t.hasPrefix("-"), let d = Decimal(string: t), d.isFinite else { return nil }
        var r = Decimal(), v = d
        NSDecimalRound(&r, &v, 0, .down)
        guard r == d else { return nil }
        let text = NSDecimalNumber(decimal: d).stringValue
        return text.allSatisfy(\.isNumber) ? text : nil
    }
}
