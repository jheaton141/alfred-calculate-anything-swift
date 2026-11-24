import Foundation

/// Coin conversions such as "1 btc to usd", "1000 doge btc" or a bare "btc".
public struct CryptoTool: Tool {
    public let name = "crypto"
    public init() {}

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        guard let provider = context.rates,
              let parsed = ConversionParser.parse(ToolSupport.expandIndianMultipliers(query, settings: context.settings), settings: context.settings, resolve: { CurrencyLexicon.resolve($0, coins: true) })
        else { return nil }
        // Unit words that are also tickers need an explicit target ("ton" alone is a unit).
        if parsed.targets.isEmpty, ["TON"].contains(parsed.from.code) { return nil }
        let targets = parsed.targets.isEmpty ? ConversionRows.defaultTargets(excluding: parsed.from.code, settings: context.settings) : parsed.targets
        let units = [parsed.from] + targets
        guard units.contains(where: { $0.isCrypto }), !targets.isEmpty else { return nil }
        guard units.allSatisfy({ $0.isCrypto || CurrencyLexicon.fiatCodes.contains($0.code) }) else { return nil }

        var coins: [String] = []
        for u in units where u.isCrypto && !coins.contains(u.code) { coins.append(u.code) }
        let crypto: RateTable
        do { crypto = try await provider.cryptoRates(symbols: coins) } catch { return ConversionRows.errorRow(error, context: context) }
        guard coins.allSatisfy({ (crypto.rates[$0] ?? 0) > 0 }) else { return nil }

        var fiat: RateTable?
        let fiatUnits = units.filter { !$0.isCrypto }
        if !fiatUnits.isEmpty {
            do { fiat = try await provider.fiatRates() } catch { return ConversionRows.errorRow(error, context: context) }
            let known = ConversionRows.codes(in: fiat!)
            guard fiatUnits.allSatisfy({ known.contains($0.code) || $0.code == "USD" }) else { return nil }
        }
        return ConversionRows.rows(amount: parsed.amount ?? 1, from: parsed.from, targets: targets, fiat: fiat, crypto: crypto, context: context)
    }
}
