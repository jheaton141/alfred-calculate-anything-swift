import Foundation

/// Shopping and pricing maths: sales tax in and out, stacked discounts, price changes, cost/price/margin/markup.
public struct DiscountTool: Tool {
    public let name = "discount"
    public init() {}

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let q = Self.clean(query)
        let s = context.settings, str = context.strings
        func num(_ t: String) -> Double? { NumberFormat.parse(t, settings: s) }
        let n = "(" + ToolSupport.number + ")"
        func item(_ title: String, _ sub: String, copy: String, raw: Double) -> AlfredItem {
            var i = AlfredItem.value(title: title, copy: copy, raw: ToolSupport.raw(raw), strings: str); i.subtitle = sub; return i
        }
        func money(_ label: String, _ sub: String, _ v: Double) -> AlfredItem { item("\(label) \(ToolSupport.fmt(v, s))", sub, copy: ToolSupport.fmt(v, s), raw: v) }
        func pct(_ label: String, _ sub: String, _ v: Double) -> AlfredItem {
            let t = ToolSupport.plainLocal(v, decimals: 2, s)
            return item("\(label) \(t)%", sub, copy: t, raw: v)
        }
        func ok(_ vs: Double...) -> Bool { vs.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1e12 } }
        let bad = [ToolSupport.invalidInput(str)]

        // Tax on top: "80 plus 8% tax", "8% tax on 80", "20% off 80 plus 8% tax"
        let taxWord = #"(?:sales\s+)?tax"#
        if let g = ToolSupport.match(n + #"\s+(?:incl\.?|including|inclusive(?:\s+of)?)\s*"# + n + #"\s*%\s*"# + taxWord + #"(?:\s+(?:included|inclusive|incl\.?))?"#, in: q)
            ?? ToolSupport.match(n + #"\s+with\s*"# + n + #"\s*%\s*"# + taxWord + #"\s+(?:included|inclusive|incl\.?)"#, in: q),
           let total = num(g[0]), let rate = num(g[1]) {
            guard ok(total, rate), rate <= 1_000 else { return bad }
            let net = total / (1 + rate / 100)
            return [money("Before tax", "\(ToolSupport.fmt(total, s)) includes \(ToolSupport.plainLocal(rate, decimals: 4, s))% tax", net), money("Tax", "Part of the total", total - net), money("Total", "As given", total)]
        }
        let discount = #"(?:"# + n + #"\s*%(?:\s*(?:\+|and|then)\s*"# + n + #"\s*%)?\s*off\s*"# + n + #")"#
        if let g = ToolSupport.match(discount + #"\s*(?:\+|plus|and|with)\s*"# + n + #"\s*%\s*"# + taxWord, in: q) ?? ToolSupport.match(discount, in: q).map({ $0 + [""] }),
           g.count == 4, let d1 = num(g[0]), let price = num(g[2]) {
            let d2 = num(g[1]) ?? 0, taxRate = num(g[3])
            if g[3].isEmpty, g[1].isEmpty { return nil }   // plain "20% off 80" belongs to the percentage tool
            guard ok(d1, d2, price), d1 <= 100, d2 <= 100, taxRate.map({ ok($0) && $0 <= 1_000 }) ?? true else { return bad }
            let sale = price * (1 - d1 / 100) * (1 - d2 / 100)
            let off = (1 - sale / (price == 0 ? 1 : price)) * 100
            var items = [money("Sale price", d2 > 0 ? "\(ToolSupport.plainLocal(d1, decimals: 4, s))% then \(ToolSupport.plainLocal(d2, decimals: 4, s))% off \(ToolSupport.fmt(price, s)), \(ToolSupport.plainLocal(off, decimals: 2, s))% off in all" : "\(ToolSupport.plainLocal(d1, decimals: 4, s))% off \(ToolSupport.fmt(price, s))", sale),
                         money("You save", "Original price minus sale price", price - sale)]
            if let t = taxRate {
                items.insert(money("Total with tax", "Sale price plus \(ToolSupport.plainLocal(t, decimals: 4, s))% tax of \(ToolSupport.fmt(sale * t / 100, s))", sale * (1 + t / 100)), at: 0)
            }
            return items
        }
        let toTaxed = ToolSupport.match(n + #"\s*(?:\+|plus|with|and)\s*"# + n + #"\s*%\s*"# + taxWord, in: q) ?? ToolSupport.match(n + #"\s*%\s*"# + taxWord + #"\s*(?:on|of)\s*"# + n, in: q).map { [$0[1], $0[0]] }
        if let g = toTaxed, let price = num(g[0]), let rate = num(g[1]) {
            guard ok(price, rate), rate <= 1_000 else { return bad }
            return [money("Total", "\(ToolSupport.fmt(price, s)) plus \(ToolSupport.plainLocal(rate, decimals: 4, s))% tax", price * (1 + rate / 100)), money("Tax", "\(ToolSupport.plainLocal(rate, decimals: 4, s))% of \(ToolSupport.fmt(price, s))", price * rate / 100)]
        }
        // Price change: "was 80 now 60"
        if let g = ToolSupport.match(#"(?:was|from|old)\s*"# + n + #"\s*(?:now|to|new)\s*"# + n, in: q), let was = num(g[0]), let now = num(g[1]) {
            guard ok(was, now), was > 0 else { return bad }
            let change = (now - was) / was * 100
            guard change.isFinite else { return bad }
            return [pct(change < 0 ? "Discount" : "Increase", "From \(ToolSupport.fmt(was, s)) to \(ToolSupport.fmt(now, s))", abs(change)), money(change < 0 ? "You save" : "Extra cost", "Difference", abs(now - was))]
        }
        return Self.margins(q, n, s, str, num)
    }

    /// Cost, price, markup and margin: any two give the rest.
    private static func margins(_ q: String, _ n: String, _ s: Settings, _ str: Strings, _ num: (String) -> Double?) -> [AlfredItem]? {
        var text = " " + q + " "
        var cost: Double?, price: Double?, markup: Double?, margin: Double?
        let keys: [(String, String)] = [("cost", #"cost|cogs"#), ("price", #"price|selling price|sell|sale price|sells for|sale"#), ("markup", #"markup|mark-up"#), ("margin", #"margin|profit margin"#)]
        for (key, alt) in keys {
            let isPct = key == "markup" || key == "margin"
            let suffix = isPct ? #"\s*%?"# : ""
            if let r = try? NSRegularExpression(pattern: #"\s(?:"# + alt + #")\s*(?:of|is|=|:|at)?\s*"# + n + suffix + #"(?=\s|$)"#),
               let m = r.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let g = Range(m.range(at: 1), in: text), let v = num(String(text[g])) {
                switch key { case "cost": cost = v; case "price": price = v; case "markup": markup = v; default: margin = v }
                text.replaceSubrange(Range(m.range, in: text)!, with: " ")
            }
        }
        let leftover = text.replacingOccurrences(of: #"\b(?:and|with|at|for|a|the|of|then|is|,)\b|,"#, with: " ", options: .regularExpression).split(separator: " ")
        guard leftover.isEmpty, [cost, price, markup, margin].compactMap({ $0 }).count == 2 else { return nil }
        let bad = [ToolSupport.invalidInput(str)]
        func pctOf(_ v: Double) -> String { ToolSupport.plainLocal(v, decimals: 2, s) + "%" }
        func item(_ title: String, _ sub: String, _ copy: String, _ raw: Double) -> AlfredItem {
            var i = AlfredItem.value(title: title, copy: copy, raw: ToolSupport.raw(raw), strings: str); i.subtitle = sub; return i
        }
        var c = cost, p = price
        if let mu = markup {
            guard mu >= 0, mu <= 1e6 else { return bad }
            if let c0 = cost { p = c0 * (1 + mu / 100) } else if let p0 = price { c = p0 / (1 + mu / 100) }
        } else if let mg = margin {
            guard mg >= 0, mg < 100 else { return bad }
            if let c0 = cost { p = c0 / (1 - mg / 100) } else if let p0 = price { c = p0 * (1 - mg / 100) }
        }
        guard let cc = c, let pp = p, cc.isFinite, pp.isFinite, cc >= 0, pp >= 0, cc <= 1e12, pp <= 1e12 else { return bad }
        let profit = pp - cc
        let outMargin = pp == 0 ? 0 : profit / pp * 100
        guard cc > 0 || markup == nil else { return bad }
        let outMarkup = cc == 0 ? 0 : profit / cc * 100
        var items: [AlfredItem] = []
        if cost == nil { items.append(item("Cost \(ToolSupport.fmt(cc, s))", "Selling price \(ToolSupport.fmt(pp, s))", ToolSupport.fmt(cc, s), cc)) }
        if price == nil { items.append(item("Price \(ToolSupport.fmt(pp, s))", "Cost \(ToolSupport.fmt(cc, s))", ToolSupport.fmt(pp, s), pp)) }
        items.append(item("Profit \(ToolSupport.fmt(profit, s))", "Price minus cost", ToolSupport.fmt(profit, s), profit))
        if margin == nil { items.append(item("Margin \(pctOf(outMargin))", "Profit as a share of the price", ToolSupport.plainLocal(outMargin, decimals: 2, s), outMargin)) }
        if markup == nil, cc > 0 { items.append(item("Markup \(pctOf(outMarkup))", "Profit as a share of the cost", ToolSupport.plainLocal(outMarkup, decimals: 2, s), outMarkup)) }
        return items
    }

    private static func clean(_ query: String) -> String {
        let q = ToolSupport.normalize(query).replacingOccurrences(of: #"[$€£¥]|\b(?:usd|eur|gbp|jpy|cad|aud|chf|cny|inr|sek|nok|dkk|mxn|brl)\b"#, with: " ", options: .regularExpression)
        var out = q.split(separator: " ").joined(separator: " ")
        // keyword forms: "tax 8% on 80", "tax 80 at 8%"
        let n = "(" + ToolSupport.number + ")"
        if let g = ToolSupport.match("tax\\s+" + n + "\\s*%\\s*(?:on|of)\\s*" + n, in: out) { out = "\(g[0])% tax on \(g[1])" }
        else if let g = ToolSupport.match("tax\\s+" + n + "\\s*(?:at|@|with|plus)?\\s*" + n + "\\s*%", in: out) { out = "\(g[0]) plus \(g[1])% tax" }
        return out
    }
}
