import Foundation

/// Converts between storage sizes: decimal SI (kB, MB, ...) and binary (KiB, MiB, ...), plus bits.
public struct DataStorageTool: Tool {
    public let name = "datastorage"
    public init() {}

    private struct Unit { let label: String; let bytes: Double }

    private static let units: [String: Unit] = {
        var u: [String: Unit] = [
            "b": Unit(label: "B", bytes: 1),
            "bit": Unit(label: "bit", bytes: 0.125),
        ]
        let si = [("k", "kilo", "kB"), ("m", "mega", "MB"), ("g", "giga", "GB"), ("t", "tera", "TB"),
                  ("p", "peta", "PB"), ("e", "exa", "EB"), ("z", "zetta", "ZB"), ("y", "yotta", "YB")]
        let bin = [("ki", "kibi", "KiB"), ("mi", "mebi", "MiB"), ("gi", "gibi", "GiB"), ("ti", "tebi", "TiB"),
                   ("pi", "pebi", "PiB"), ("ei", "exbi", "EiB"), ("zi", "zebi", "ZiB"), ("yi", "yobi", "YiB")]
        let siBits = ["kbit", "Mbit", "Gbit", "Tbit", "Pbit", "Ebit", "Zbit", "Ybit"]
        let binBits = ["Kibit", "Mibit", "Gibit", "Tibit", "Pibit", "Eibit", "Zibit", "Yibit"]
        for (i, (sym, word, label)) in si.enumerated() {
            let bits = Unit(label: siBits[i], bytes: pow(1000, Double(i + 1)) / 8)
            u[sym + "bit"] = bits; u[word + "bit"] = bits; u[word + "bits"] = bits
            // lowercase "mb" is always megabyte; "mbit" is the unambiguous megabit

            let unit = Unit(label: label, bytes: pow(1000, Double(i + 1)))
            u[sym + "b"] = unit; u[word + "byte"] = unit; u[word + "bytes"] = unit
            u[word + "s"] = unit; u[word] = unit
        }
        for (i, (sym, word, label)) in bin.enumerated() {
            let bits = Unit(label: binBits[i], bytes: pow(1024, Double(i + 1)) / 8)
            u[sym + "bit"] = bits; u[word + "bit"] = bits; u[word + "bits"] = bits
            let unit = Unit(label: label, bytes: pow(1024, Double(i + 1)))
            u[sym + "b"] = unit; u[word + "byte"] = unit; u[word + "bytes"] = unit
            u[word + "s"] = unit; u[word] = unit
        }
        u["byte"] = u["b"]; u["bytes"] = u["b"]; u["bits"] = u["bit"]
        return u
    }()

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let verdict = ScaleFormat.check(query)
        if verdict == .skip { return nil }
        let q = ToolSupport.normalize(query)
        let pattern = "(\(ToolSupport.number))\\s*([a-z]+)\\s*(?:(?:to|in|as|=)\\s*)?([a-z]+)"
        guard let g = ToolSupport.match(pattern, in: q),
              let from = Self.units[g[1]], let to = Self.units[g[2]] else { return nil }
        guard verdict == .ok, let amount = NumberFormat.parse(g[0], settings: context.settings) else {
            return verdict == .overflow || ScaleFormat.overflowing(g[0]) ? [ScaleFormat.invalid(context.strings)] : nil
        }
        var value = amount * from.bytes / to.bytes
        if !value.isFinite { value = amount * (from.bytes / to.bytes) }
        guard value.isFinite else { return [ScaleFormat.invalid(context.strings)] }
        var st = context.settings; st.decimals = max(st.decimals, 8)
        let shown = ScaleFormat.show(value, st)
        return [.value(title: "\(shown) \(to.label)", copy: shown, raw: ScaleFormat.raw(value), withUnit: "\(shown) \(to.label)", strings: context.strings)]
    }
}
