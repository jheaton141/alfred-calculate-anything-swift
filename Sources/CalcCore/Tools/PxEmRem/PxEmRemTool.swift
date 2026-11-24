import Foundation

/// Converts between px, em, rem and pt using a base font size (default from settings, or "base 20px").
public struct PxEmRemTool: Tool {
    public let name = "pxemrem"
    public init() {}

    private static let order = ["px", "em", "rem", "pt"]

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let q = ToolSupport.normalize(query)
        let n = ToolSupport.number
        let pattern = "(\(n))\\s*(px|em|rem|pt)(?:\\s*(?:(?:to|in|as|=)\\s+)?(px|em|rem|pt))?(?:\\s+base\\s+(\(n))\\s*(?:px)?)?"
        guard let g = ToolSupport.match(pattern, in: q),
              let amount = NumberFormat.parse(g[0], settings: context.settings) else { return nil }
        var base = context.settings.basePixels
        if !g[3].isEmpty {
            guard let b = NumberFormat.parse(g[3], settings: context.settings) else { return nil }
            base = b
        }
        guard base > 0 else { return nil }
        let from = g[1]
        let targets = g[2].isEmpty ? Self.order.filter { $0 != from } : [g[2]]
        let px = Self.toPixels(amount, from, base)
        return targets.map { t in
            let v = Self.fromPixels(px, t, base)
            let num = NumberFormat.plain(v, decimals: 8)
            return .value(title: num + t, copy: num + t, raw: num, strings: context.strings)
        }
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
