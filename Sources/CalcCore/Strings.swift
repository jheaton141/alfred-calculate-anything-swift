import Foundation

/// Translatable UI strings, loaded from a language pack (JSON); falls back to the key.
public struct Strings {
    private let table: [String: String]
    public init(_ table: [String: String]) { self.table = table }
    public subscript(key: String) -> String { table[key] ?? key }

    public static let en = Strings([
        "copy_number": "Action this item to copy this number to the clipboard",
        "copy_raw": "Action this item to copy the amount with no format",
        "copy_with_unit": "Action this item to copy this value with unit to the clipboard",
    ])
}
