import Foundation

/// VAT amounts at the configured rate: "vat 100", "100 vat", "121 with vat", "100 + vat", "100 - vat".
public struct VatTool: Tool {
    public let name = "vat"
    public init() {}

    private enum Mode { case all, plus, minus }

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let q = ToolSupport.normalize(query)
        var mode = Mode.all
        let n = "(\(ToolSupport.number))"
        var amountText: String?

        if q == "vat" { return [Self.hint(context)] }
        if q.hasPrefix("vat ") {
            let rest = String(q.dropFirst(4))
            let pattern = "\(n)(?:\\s*(?:\\+|-|plus|minus|with|without|incl\\.?|excl\\.?|inc|exc|ex)?\\s*(?:of\\s+)?(?:vat)?)?"
            guard let g = ToolSupport.match(pattern, in: rest) else { return nil }
            amountText = g[0]
        } else if let g = ToolSupport.match("\(n)\\s*(\\+|plus|with|incl\\.?|inc)\\s*vat", in: q) {
            amountText = g[0]; mode = .plus
        } else if let g = ToolSupport.match("\(n)\\s*(-|minus|without|excl\\.?|exc|ex)\\s*vat", in: q) {
            amountText = g[0]; mode = .minus
        } else if let g = ToolSupport.match("\(n)\\s*vat", in: q) {
            amountText = g[0]
        }
        guard let text = amountText, let amount = NumberFormat.parse(text, settings: context.settings) else { return nil }
        if amount == 0 { return [Self.hint(context)] }

        let str = context.strings
        let p = context.settings.vatPercentage.isFinite && context.settings.vatPercentage > -100 ? context.settings.vatPercentage : 16
        let vat = amount * p / 100
        let plus = amount + vat
        let minus = amount / (1 + p / 100)
        guard [vat, plus, minus].allSatisfy({ $0.isFinite }) else { return [ToolSupport.invalidInput(str)] }
        // one precision for every figure so the amounts agree with each other
        let s = ToolSupport.displaySettings([amount, vat, plus, minus], context.settings)
        let pct = NumberFormat.plain(p, decimals: 4) + "%"
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
