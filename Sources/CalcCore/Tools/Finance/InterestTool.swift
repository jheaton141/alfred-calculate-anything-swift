import Foundation

/// Compound interest: "1000 at 5% for 10 years", "invest 5000 at 4.5% for 30 years monthly adding 200 per month".
public struct InterestTool: Tool {
    public let name = "interest"
    public init() {}

    private static let compounding: [(words: [String], perYear: Double)] = [
        (["continuously", "continuous"], .infinity), (["semi-annually", "semiannually", "semiannual", "twice a year"], 2),
        (["annually", "yearly", "annual"], 1), (["quarterly"], 4), (["monthly"], 12), (["weekly"], 52), (["daily"], 365)]

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        guard query.count <= 200, let p = Self.parse(ToolSupport.normalize(query), context.settings) else { return nil }
        let s = context.settings, str = context.strings
        guard p.principal >= 0, p.principal <= 1e12, p.rate >= 0, p.rate <= 1_000, p.years > 0, p.years <= 1_000,
              p.deposit >= 0, p.deposit <= 1e12, p.principal > 0 || p.deposit > 0 else { return [ToolSupport.invalidInput(str)] }

        let r = p.rate / 100
        let apy = p.perYear.isInfinite ? exp(r) - 1 : pow(1 + r / p.perYear, p.perYear) - 1
        let growth = pow(1 + apy, p.years)
        var balance = p.principal * growth
        var contributed = p.principal
        if p.deposit > 0 {
            let periods = p.depositsMonthly ? p.years * 12 : p.years
            let i = p.depositsMonthly ? pow(1 + apy, 1.0 / 12) - 1 : apy
            let annuity = i == 0 ? periods : (pow(1 + i, periods) - 1) / i
            balance += p.deposit * annuity
            contributed += p.deposit * periods
        }
        guard balance.isFinite, balance < 1e18 else { return [ToolSupport.invalidInput(str)] }
        let interest = balance - contributed

        func item(_ title: String, _ sub: String, _ v: Double) -> AlfredItem {
            var i = AlfredItem.value(title: title, copy: ToolSupport.fmt(v, s), raw: ToolSupport.raw(v), strings: str); i.subtitle = sub; return i
        }
        let yearsText = ToolSupport.plainLocal(p.years, decimals: 2, s)
        let how = p.perYear.isInfinite ? "compounded continuously" : "compounded \(Self.name(p.perYear))"
        var sub = "\(ToolSupport.fmt(p.principal, s)) at \(ToolSupport.plainLocal(p.rate, decimals: 4, s))% for \(yearsText) years, \(how)"
        if p.deposit > 0 { sub += ", adding \(ToolSupport.fmt(p.deposit, s)) per \(p.depositsMonthly ? "month" : "year")" }
        var items = [item("Final balance \(ToolSupport.fmt(balance, s))", sub, balance),
                     item("Interest earned \(ToolSupport.fmt(interest, s))", "Balance minus \(ToolSupport.fmt(contributed, s)) paid in", interest)]
        if p.deposit > 0 { items.append(item("Total paid in \(ToolSupport.fmt(contributed, s))", "Starting amount plus deposits", contributed)) }
        let apyPct = apy * 100
        items.append(item("Effective annual rate \(ToolSupport.plainLocal(apyPct, decimals: 4, s))%", "What the nominal rate grows to in one year", apyPct))
        return items
    }

    private static func name(_ perYear: Double) -> String {
        switch perYear { case 1: return "annually"; case 2: return "twice a year"; case 4: return "quarterly"; case 12: return "monthly"; case 52: return "weekly"; case 365: return "daily"; default: return "\(Int(perYear)) times a year" }
    }

    private struct Parsed { var principal: Double, rate: Double, years: Double, perYear: Double, deposit: Double, depositsMonthly: Bool }

    private static func parse(_ query: String, _ settings: Settings) -> Parsed? {
        var q = " " + query.replacingOccurrences(of: #"[$€£¥]|\b(?:usd|eur|gbp|jpy|cad|aud|chf|cny|inr|sek|nok|dkk|mxn|brl)\b"#, with: " ", options: .regularExpression) + " "
        let n = "(" + ToolSupport.number + ")"
        func num(_ t: String) -> Double? { NumberFormat.parse(t, settings: settings) }

        var deposit = 0.0, monthly = true
        if let g = firstMatch(#"\s(?:adding|add|plus|\+|contributing|contribute|depositing|deposit|saving|save)\s*"# + n + #"\s*(?:per|a|each|every|/)\s*(month|year|mo|yr)\b"#, in: q) {
            guard let d = num(g.groups[0]) else { return nil }
            deposit = d; monthly = g.groups[1].hasPrefix("m"); q.replaceSubrange(g.range, with: " ")
        }
        var perYear = 1.0
        for (words, k) in compounding {
            for w in words {
                if let r = q.range(of: " \(w) ") ?? q.range(of: " compounded \(w) ") ?? q.range(of: " compounding \(w) ") {
                    perYear = k; q.replaceSubrange(r, with: " ")
                    if let c = q.range(of: " compounded ") ?? q.range(of: " compounding ") ?? q.range(of: " compound ") { q.replaceSubrange(c, with: " ") }
                    break
                }
            }
            if perYear != 1 { break }
        }
        for junk in [" per annum ", " a year ", " p.a. ", " interest ", " invest ", " investing ", " compound ", " compounded ", " compounding ", " of ", " principal "] { q = q.replacingOccurrences(of: junk, with: " ") }
        q = q.split(separator: " ").joined(separator: " ")
        let pattern = n + #"\s*(?:at|@|,|with)?\s*"# + n + #"\s*%\s*(?:,|for|over|in|after)?\s*"# + n + #"\s*(years?|yrs?|y|months?|mos?|mo)"#
        guard let g = ToolSupport.match(pattern, in: q), let pr = num(g[0]), let rate = num(g[1]), let t = num(g[2]) else { return nil }
        let years = g[3].hasPrefix("m") ? t / 12 : t
        return Parsed(principal: pr, rate: rate, years: years, perYear: perYear, deposit: deposit, depositsMonthly: monthly)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> (range: Range<String.Index>, groups: [String])? {
        guard let re = try? NSRegularExpression(pattern: pattern), let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range, in: text) else { return nil }
        return (r, (1..<m.numberOfRanges).map { Range(m.range(at: $0), in: text).map { String(text[$0]) } ?? "" })
    }
}
