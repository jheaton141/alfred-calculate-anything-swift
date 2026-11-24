import Foundation

/// Converts between px, em, rem and pt using a base font size (default from settings, or "base 20px").
public struct PxEmRemTool: Tool {
    public let name = "pxemrem"
    public init() {}

    private static let order = ["px", "em", "rem", "pt"]

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let verdict = ScaleFormat.check(query)
        if verdict == .skip { return nil }
        let q = ToolSupport.normalize(query)
        let n = ToolSupport.number
        let pattern = "([-+]?\(n))\\s*(px|em|rem|pt)(?:\\s*(?:(?:to|in|as)\\s+|=\\s*)?(px|em|rem|pt))?(?:\\s+base\\s+(\(n))\\s*(?:px)?)?"
        guard let g = ToolSupport.match(pattern, in: q) else { return nil }
        guard verdict == .ok, let amount = NumberFormat.parse(g[0], settings: context.settings) else {
            return verdict == .overflow || ScaleFormat.overflowing(g[0]) ? [ScaleFormat.invalid(context.strings)] : nil
        }
        // a base of zero, below zero or not finite falls back to 16px
        var base = context.settings.basePixels
        if !g[3].isEmpty {
            guard let b = NumberFormat.parse(g[3], settings: context.settings) else { return nil }
            base = b
        }
        if !(base > 0) || !base.isFinite { base = 16 }
        let from = g[1]
        let targets = g[2].isEmpty ? Self.order.filter { $0 != from } : [g[2]]
        let px = Self.toPixels(amount, from, base)
        guard px.isFinite else { return [ScaleFormat.invalid(context.strings)] }
        let decimals = max(context.settings.decimals, 8)
        var items: [AlfredItem] = []
        for t in targets {
            let v = Self.fromPixels(px, t, base)
            guard v.isFinite else { return [ScaleFormat.invalid(context.strings)] }
            var num = ScaleFormat.plainText(v, decimals: decimals)
            if context.settings.decimalSeparator != "." { num = num.replacingOccurrences(of: ".", with: String(context.settings.decimalSeparator)) }
            items.append(.value(title: num + t, copy: num + t, raw: ScaleFormat.raw(v, decimals: decimals), withUnit: num + t, strings: context.strings))
        }
        return items
    }

    private static func toPixels(_ v: Double, _ unit: String, _ base: Double) -> Double {
        switch unit {
        case "em", "rem": return v * base
        case "pt": return v / 0.75
        default: return v
        }
    }

    private static func fromPixels(_ px: Double, _ unit: String, _ base: Double) -> Double {
        switch unit {
        case "em", "rem": return px / base
        case "pt": return px * 0.75
        default: return px
        }
    }
}
