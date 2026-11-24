import Foundation

/// Translatable UI strings, loaded from a language pack (JSON); falls back to the key.
public struct Strings {
    private let table: [String: String]
    public init(_ table: [String: String]) { self.table = table }
    public subscript(key: String) -> String { table[key] ?? key }

    public static let en = Strings(decode(LanguagePacks.en))

    /// Language codes with a built-in pack.
    public static let available = LanguagePacks.json.keys.sorted()

    /// Pack for a code such as "es_ES", "es-es" or "es"; missing keys and unknown languages fall back to English.
    public static func load(_ code: String) -> Strings {
        let wanted = code.lowercased().replacingOccurrences(of: "-", with: "_")
        let key = LanguagePacks.json.keys.first { $0.lowercased() == wanted }
            ?? LanguagePacks.json.keys.sorted().first { $0.lowercased().hasPrefix(wanted + "_") && !wanted.isEmpty }
        guard let key, let json = LanguagePacks.json[key] else { return .en }
        return Strings(decode(LanguagePacks.en).merging(decode(json)) { _, new in new })
    }

    static func decode(_ json: String) -> [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(json.utf8))) ?? [:]
    }
}
