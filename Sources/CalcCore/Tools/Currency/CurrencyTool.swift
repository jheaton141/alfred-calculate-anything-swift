import Foundation

/// Fiat conversions such as "100 usd to eur, gbp" or "10M eur in usd".
public struct CurrencyTool: Tool {
    public let name = "currency"
    public init() {}

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        guard let provider = context.rates,
              let parsed = ConversionParser.parse(query, settings: context.settings, resolve: { CurrencyLexicon.resolve($0, coins: false) }),
              let amount = parsed.amount else { return nil }
        let explicit = !parsed.targets.isEmpty
        let targets = explicit ? parsed.targets : ConversionRows.defaultTargets(excluding: parsed.from.code, settings: context.settings)
        guard !targets.isEmpty else { return nil }
        let units = [parsed.from] + targets
        guard units.allSatisfy({ CurrencyLexicon.fiatCodes.contains($0.code) }) else { return nil }
        if !explicit && CurrencyLexicon.bareCollisions.contains(parsed.from.code) { return nil }

        let table: RateTable
        do { table = try await provider.fiatRates() } catch { return ConversionRows.errorRow(error, context: context) }
        let known = ConversionRows.codes(in: table)
        guard units.allSatisfy({ known.contains($0.code) }) else { return nil }
        return ConversionRows.rows(amount: amount, from: parsed.from, targets: targets, fiat: table, crypto: nil, context: context)
    }
}
