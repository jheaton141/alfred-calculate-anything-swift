import Foundation

/// VAT amounts at the configured rate or one given in the query: "vat 100", "100 vat", "121 with vat", "100 + vat", "vat 100 at 21%", "100 vat 5".
public struct VatTool: Tool {
    public let name = "vat"
    public init() {}

    private enum Mode { case all, plus, minus }

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let q = ToolSupport.normalize(query)
        var mode = Mode.all
        let n = "(\(ToolSupport.number))"
        var amountText: String?
        var rateText: String?
        // optional per-query rate: "5", "5%", "at 5%", "@ 5", "rate 5"
        let rate = "(?:\\s+(?:at|@|rate|rate of)?\\s*(\(ToolSupport.number))\\s*%?)?"

        if q == "vat" { return [Self.hint(context)] }
        if q.hasPrefix("vat ") {
            let rest = String(q.dropFirst(4))
            let pattern = "\(n)(?:\\s*(?:\\+|-|plus|minus|with|without|incl\\.?|excl\\.?|inc|exc|ex)?\\s*(?:of\\s+)?(?:vat)?)?"
            if let g = ToolSupport.match(pattern, in: rest) { amountText = g[0] }
            else if let g = ToolSupport.match("\(n)\\s*(?:\\+|plus|with|incl\\.?|inc)?\\s*\(rate)", in: rest), !g[1].isEmpty {
                amountText = g[0]; rateText = g[1]
            } else { return nil }
        } else if let g = ToolSupport.match("\(n)\\s*(\\+|plus|with|incl\\.?|inc)\\s*vat\(rate)", in: q) {
            amountText = g[0]; mode = .plus; rateText = g[2].isEmpty ? nil : g[2]
        } else if let g = ToolSupport.match("\(n)\\s*(-|minus|without|excl\\.?|exc|ex)\\s*vat\(rate)", in: q) {
            amountText = g[0]; mode = .minus; rateText = g[2].isEmpty ? nil : g[2]
        } else if let g = ToolSupport.match("\(n)\\s*vat\(rate)", in: q) {
            amountText = g[0]; rateText = g[1].isEmpty ? nil : g[1]
        }
        guard let text = amountText, let amount = NumberFormat.parse(text, settings: context.settings) else { return nil }
        if amount == 0 { return [Self.hint(context)] }

        let str = context.strings
        var p = context.settings.vatPercentage.isFinite && context.settings.vatPercentage > -100 ? context.settings.vatPercentage : 16
        if let r = rateText {
            guard let v = NumberFormat.parse(r, settings: context.settings), v.isFinite, v > -100, v <= 1_000 else { return [ToolSupport.invalidInput(str)] }
            p = v
        }
        let vat = amount * p / 100
        let plus = amount + vat
        let minus = amount / (1 + p / 100)
        guard [vat, plus, minus].allSatisfy({ $0.isFinite }) else { return [ToolSupport.invalidInput(str)] }
        // one precision for every figure so the amounts agree with each other
        let s = ToolSupport.displaySettings([amount, vat, plus, minus], context.settings)
        var pct = NumberFormat.plain(p, decimals: 4) + "%"
        if context.settings.decimalSeparator != "." { pct = pct.replacingOccurrences(of: ".", with: String(context.settings.decimalSeparator)) }
        let a = ToolSupport.show(amount, s)

        func row(_ title: String, _ subtitle: String, _ value: Double) -> AlfredItem {
            AlfredItem(title: title, subtitle: subtitle, arg: ToolSupport.show(value, s),
                       mods: .init(cmd: .init(arg: ToolSupport.rawValue(value, s), subtitle: ToolSupport.tr(str, "copy_raw", "Action this item to copy the amount with no format"))))
        }
        let vatRow = row(String(format: ToolSupport.tr(str, "vat_result", "VAT of %@ = %@"), a, ToolSupport.show(vat, s)),
                         String(format: ToolSupport.tr(str, "vat_subtitle", "VAT of %@"), pct), vat)
        let plusRow = row(String(format: ToolSupport.tr(str, "vat_plus", "%@ plus VAT = %@"), a, ToolSupport.show(plus, s)),
                          String(format: ToolSupport.tr(str, "vat_subtitle", "VAT of %@"), pct), plus)
        let minusRow = row(String(format: ToolSupport.tr(str, "vat_minus", "%@ minus VAT = %@"), a, ToolSupport.show(minus, s)),
                           String(format: ToolSupport.tr(str, "vat_minus_subtitle", "%@ minus %@ of VAT"), a, pct), minus)
        switch mode {
        case .all: return [vatRow, plusRow, minusRow]
        case .plus: return [plusRow]
        case .minus: return [minusRow]
        }
    }

    private static func hint(_ c: Context) -> AlfredItem {
        AlfredItem(title: "...", subtitle: ToolSupport.tr(c.strings, "vat_empty", "Enter a value to process"), arg: "", valid: false)
    }
}
