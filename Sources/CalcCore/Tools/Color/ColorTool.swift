import Foundation

/// Converts colours between hex, rgb, hsl, hsv, hwb, cmyk, lab, lch and xyz; also contrast ratio and lighten/darken.
public struct ColorTool: Tool {
    public let name = "color"
    public init() {}

    static let spaceOrder = ["hex", "rgb", "hsl", "hsv", "hwb", "cmyk", "lab", "lch", "xyz"]
    static let targetWords = ["hex", "rgb", "rgba", "hsl", "hsla", "hsv", "hsb", "hwb", "cmyk", "lab", "lch", "xyz"]

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let q = ToolSupport.normalize(query)
        guard !q.isEmpty else { return nil }
        if let items = contrast(q, context) { return items }
        if let items = shift(q, context) { return items }

        // A bare colour lists every space.
        if let c = ColorMath.parse(q, allowBareHex: false) {
            return Self.spaceOrder.map { row(c, $0, context) }
        }
        // "<colour> [to|in|as|=] <space>"
        let words = Self.targetWords.joined(separator: "|")
        guard let g = ToolSupport.match("(.+?)\\s+(\(words))", in: q) else { return nil }
        var src = g[0]
        for sep in [" to", " in", " as", " ="] where src.hasSuffix(sep) { src.removeLast(sep.count) }
        if src.hasSuffix("=") { src.removeLast() }
        src = src.trimmingCharacters(in: .whitespaces)
        guard let c = ColorMath.parse(src, allowBareHex: true) else { return nil }
        return [row(c, g[1], context)]
    }

    private func row(_ c: ColorMath.RGBA, _ space: String, _ ctx: Context) -> AlfredItem {
        let s = ColorMath.format(c, space)
        var item = AlfredItem.value(title: s, copy: s, raw: s, strings: ctx.strings)
        item.subtitle = space.uppercased()
        return item
    }

    // MARK: contrast

    private func contrast(_ q: String, _ ctx: Context) -> [AlfredItem]? {
        guard let g = ToolSupport.match("(?:contrast\\s+)?(.+?)\\s+(?:on|vs|against|and)\\s+(.+)", in: q),
              let a = ColorMath.parse(g[0], allowBareHex: false),
              let b = ColorMath.parse(g[1], allowBareHex: false) else { return nil }
        let la = ColorMath.luminance(a), lb = ColorMath.luminance(b)
        let ratio = (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
        let flag: (Double) -> String = { ratio >= $0 ? "pass" : "fail" }
        let title = NumberFormat.plain(ratio, decimals: 2) + ":1"
        let sub = "AA \(flag(4.5)), AA large \(flag(3)), AAA \(flag(7)), AAA large \(flag(4.5))"
        return [AlfredItem.value(title: title, copy: title, raw: NumberFormat.plain(ratio, decimals: 4), strings: ctx.strings).with(subtitle: sub)]
    }

    // MARK: lighten / darken

    private func shift(_ q: String, _ ctx: Context) -> [AlfredItem]? {
        guard let g = ToolSupport.match("(lighten|darken)\\s+(.+?)(?:\\s+by)?\\s+(\\d+(?:\\.\\d+)?)\\s*%?", in: q),
              let c = ColorMath.parse(g[1], allowBareHex: false), let amount = Double(g[2]) else { return nil }
        let (h, s, l) = ColorMath.toHSL(c)
        let nl = min(max(l + (g[0] == "lighten" ? amount : -amount) / 100, 0), 1)
        let out = ColorMath.fromHSL(h, s, nl, c.a)
        let verb = g[0] == "lighten" ? "Lightened" : "Darkened"
        return ["hex", "rgb", "hsl"].map { sp in
            let v = ColorMath.format(out, sp)
            let item = AlfredItem.value(title: v, copy: v, raw: v, strings: ctx.strings)
            return item.with(subtitle: sp == "hex" ? "HEX, \(verb.lowercased()) by \(NumberFormat.plain(amount, decimals: 2))%" : sp.uppercased())
        }
    }
}

private extension AlfredItem {
    func with(subtitle: String) -> AlfredItem { var c = self; c.subtitle = subtitle; return c }
}
