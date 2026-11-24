import Foundation

/// Forces a rates update (the _carefresh keyword) and describes what happened in one line.
public enum RatesRefresh {
    /// Settings that treat every cached table as expired, so the provider refetches.
    public static func forcing(_ settings: Settings) -> Settings {
        var s = settings
        s.fiatCacheHours = 0
        s.cryptoCacheMinutes = 0
        return s
    }

    public static func run(_ rates: RatesProviding) async -> String {
        async let fiat = describe("Fiat", { try await rates.fiatRates() }, unit: "rates")
        async let crypto = describe("Crypto", { try await rates.cryptoRates(symbols: []) }, unit: "coins")
        return await [fiat, crypto].joined(separator: ". ")
    }

    private static func describe(_ label: String, _ fetch: () async throws -> RateTable, unit: String) async -> String {
        do {
            let t = try await fetch()
            if t.stale {
                let day = DatePattern.format("Y-m-d", t.fetchedAt, TimeZone.current)
                return "\(label): offline, kept \(t.rates.count) \(unit) from \(day)"
            }
            return "\(label): \(t.rates.count) \(unit) from \(t.source)"
        } catch {
            if case RatesError.unavailable(let message) = error { return "\(label): \(message)" }
            return "\(label): unavailable"
        }
    }
}
