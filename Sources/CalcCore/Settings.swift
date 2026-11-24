import Foundation

/// User settings. Values come from Alfred workflow variables (environment) with defaults; no API keys exist.
/// Digit grouping for display: 1,234,567 (western) or 12,34,567 (indian).
public enum NumberGrouping: String, Equatable { case western, indian }

public struct Settings: Equatable {
    public var decimals = 2
    public var decimalSeparator: Character = "."
    public var thousandsSeparator: Character = ","
    public var baseCurrency = "USD"
    public var fiatCacheHours = 6.0
    public var cryptoCacheMinutes = 5.0
    public var basePixels = 16.0
    public var vatPercentage = 16.0
    public var numberGrouping = NumberGrouping.western
    public var language = "en_EN"
    public var timezone: String?
    public var timeFormat: String?

    public init() {}

    public init(environment env: [String: String]) {
        self.init()
        if let v = env["decimals"].flatMap(Int.init) { decimals = min(max(v, 0), 12) }
        if let v = env["decimal_separator"], v == "," { decimalSeparator = ","; thousandsSeparator = "." }
        if let v = env["base_currency"], !v.isEmpty { baseCurrency = v.uppercased() }
        if let v = env["currency_cache_hours"].flatMap(Double.init) { fiatCacheHours = v }
        if let v = (env["base_pixels"] ?? env["pixels_base"]).flatMap(Double.init) { basePixels = v }
        if let v = (env["vat_percentage"] ?? env["vat_value"]).flatMap(Self.parseVatPercentage) { vatPercentage = v }
        if let v = env["number_grouping"]?.lowercased(), let g = NumberGrouping(rawValue: v) { numberGrouping = g }
        if let v = env["language"], !v.isEmpty { language = v }
        if let v = env["timezone"] ?? env["time_zone"], !v.isEmpty { timezone = v }
        if let v = env["time_format"], !v.isEmpty { timeFormat = v }
    }

    /// A finite rate above -100, written like "20", " 20 " or "20%"; anything else is nil.
    static func parseVatPercentage(_ text: String) -> Double? {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasSuffix("%") { t.removeLast(); t = t.trimmingCharacters(in: .whitespaces) }
        guard let v = Double(t), v.isFinite, v > -100 else { return nil }
        return v
    }
}
