import Foundation

/// User settings. Values come from Alfred workflow variables (environment) with defaults; no API keys exist.
public struct Settings: Equatable {
    public var decimals = 2
    public var decimalSeparator: Character = "."
    public var thousandsSeparator: Character = ","
    public var baseCurrency = "USD"
    public var fiatCacheHours = 6.0
    public var cryptoCacheMinutes = 5.0
    public var basePixels = 16.0
    public var vatPercentage = 16.0
    public var language = "en_EN"

    public init() {}

    public init(environment env: [String: String]) {
        self.init()
        if let v = env["decimals"].flatMap(Int.init) { decimals = v }
        if let v = env["decimal_separator"], v == "," { decimalSeparator = ","; thousandsSeparator = "." }
        if let v = env["base_currency"], !v.isEmpty { baseCurrency = v.uppercased() }
        if let v = env["currency_cache_hours"].flatMap(Double.init) { fiatCacheHours = v }
        if let v = env["base_pixels"].flatMap(Double.init) { basePixels = v }
        if let v = env["vat_percentage"].flatMap(Double.init) { vatPercentage = v }
        if let v = env["language"], !v.isEmpty { language = v }
    }
}
