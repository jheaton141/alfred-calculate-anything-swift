import Foundation

/// Exchange rates relative to one base code, with where they came from.
public struct RateTable: Codable, Equatable {
    public var base: String
    public var rates: [String: Double]
    public var fetchedAt: Date
    public var source: String
    public var stale: Bool = false

    public init(base: String, rates: [String: Double], fetchedAt: Date, source: String, stale: Bool = false) {
        self.base = base; self.rates = rates; self.fetchedAt = fetchedAt; self.source = source; self.stale = stale
    }

    /// Converts `amount` from one code to another through the base; nil if either code is unknown.
    public func convert(_ amount: Double, from: String, to: String) -> Double? {
        let f = from.uppercased(), t = to.uppercased()
        func rate(_ c: String) -> Double? { c == base.uppercased() ? 1 : rates[c] ?? rates[c.lowercased()] }
        guard let rf = rate(f), let rt = rate(t), rf != 0 else { return nil }
        return amount / rf * rt
    }
}

/// Keyless rate sources behind a cache. Implementations live in Rates/.
public protocol RatesProviding {
    /// Fiat rates (ECB via Frankfurter, fallback fawazahmed0). Stale cache is returned flagged when offline.
    func fiatRates() async throws -> RateTable
    /// Crypto prices expressed in USD per coin (symbol uppercased), CoinGecko then Coinbase.
    func cryptoRates(symbols: [String]) async throws -> RateTable
}

public enum RatesError: Error, Equatable { case unavailable(String) }
