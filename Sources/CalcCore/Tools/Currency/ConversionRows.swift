import Foundation

/// Shared conversion maths and Alfred rows for the fiat and crypto tools.
enum ConversionRows {
    /// Converts through USD when either side is a coin (crypto table is coins per USD), directly otherwise.
    static func convert(_ amount: Double, from: CurrencyUnit, to: CurrencyUnit, fiat: RateTable?, crypto: RateTable?) -> Double? {
        if !from.isCrypto && !to.isCrypto { return fiat?.convert(amount, from: from.code, to: to.code) }
        var usd = amount
        if from.isCrypto {
            guard let r = crypto?.rates[from.code], r > 0 else { return nil }
            usd = amount / r
        } else if from.code != "USD" {
            guard let v = fiat?.convert(amount, from: from.code, to: "USD") else { return nil }
            usd = v
        }
        if to.isCrypto {
            guard let r = crypto?.rates[to.code], r > 0 else { return nil }
            return usd * r
        }
        return to.code == "USD" ? usd : fiat?.convert(usd, from: "USD", to: to.code)
    }

    static func rows(amount: Double, from: CurrencyUnit, targets: [CurrencyUnit], fiat: RateTable?, crypto: RateTable?, context: Context) -> [AlfredItem]? {
        let s = context.settings
        let multiple = targets.count > 1
        let stale = [fiat, crypto].compactMap { $0 }.filter { $0.stale }.map { $0.fetchedAt }.min()
        var items: [AlfredItem] = []
        for to in targets {
            if multiple && to.code == from.code { continue }
            guard let out = convert(amount, from: from, to: to, fiat: fiat, crypto: crypto),
                  let one = convert(1, from: from, to: to, fiat: fiat, crypto: crypto) else { continue }
            var display = s
            display.decimals = to.isCrypto && abs(out) < 1 ? max(s.decimals, 8) : s.decimals
            let shown = NumberFormat.display(out, settings: display)
            var rateSettings = s
            rateSettings.decimals = abs(one) >= 100 ? max(s.decimals, 2) : abs(one) >= 1 ? max(s.decimals, 4) : max(s.decimals, 8)
            var item = AlfredItem.value(
                title: "\(shown) \(to.code)", copy: shown, raw: NumberFormat.plain(out, decimals: display.decimals),
                withUnit: "\(shown) \(to.code)", strings: context.strings)
            item.subtitle = "1 \(from.code) = \(NumberFormat.display(one, settings: rateSettings)) \(to.code)"
            if let stale { item.subtitle += " (\(text(context, "cached_rates_from", "cached rates from")) \(dateString(stale)))" }
            items.append(item)
        }
        return items.isEmpty ? nil : items
    }

    static func errorRow(_ error: Error, context: Context) -> [AlfredItem] {
        [AlfredItem.error(text(context, "rates_unavailable", "Exchange rates unavailable"), subtitle: message(error))]
    }

    private static func message(_ error: Error) -> String {
        if case RatesError.unavailable(let m) = error { return m }
        return error.localizedDescription
    }

    /// Targets for a query with none: the configured base currencies other than the source.
    static func defaultTargets(excluding code: String, settings: Settings) -> [CurrencyUnit] {
        let list = settings.baseCurrency.split(whereSeparator: { ", ;".contains($0) }).map { $0.uppercased() }
        var codes = list.filter { $0 != code && CurrencyLexicon.fiatCodes.contains($0) }
        let configured = list.contains { CurrencyLexicon.fiatCodes.contains($0) }
        if codes.isEmpty && !configured { codes = [code == "USD" ? "EUR" : "USD"] }
        else if codes.isEmpty && code != "USD" { codes = ["USD"] }
        return codes.map { CurrencyUnit(code: $0) }
    }

    static func codes(in table: RateTable) -> Set<String> {
        Set(table.rates.keys.map { $0.uppercased() } + [table.base.uppercased()])
    }

    private static func text(_ c: Context, _ key: String, _ fallback: String) -> String {
        let v = c.strings[key]
        return v == key ? fallback : v
    }

    private static func dateString(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }
}
