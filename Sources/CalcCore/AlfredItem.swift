import Foundation

/// One row in an Alfred Script Filter result list.
public struct AlfredItem: Codable, Equatable {
    public struct Mod: Codable, Equatable {
        public var valid: Bool
        public var arg: String
        public var subtitle: String
        public init(valid: Bool = true, arg: String, subtitle: String) {
            self.valid = valid; self.arg = arg; self.subtitle = subtitle
        }
    }
    public struct Mods: Codable, Equatable {
        public var cmd: Mod?
        public var alt: Mod?
        public init(cmd: Mod? = nil, alt: Mod? = nil) { self.cmd = cmd; self.alt = alt }
    }

    public var title: String
    public var subtitle: String
    public var arg: String
    public var valid: Bool
    public var mods: Mods?

    public init(title: String, subtitle: String = "", arg: String? = nil, valid: Bool = true, mods: Mods? = nil) {
        self.title = title; self.subtitle = subtitle; self.arg = arg ?? title; self.valid = valid; self.mods = mods
    }

    /// Result row for a computed value: Enter copies the formatted value, cmd copies the raw number, alt copies value plus unit.
    public static func value(title: String, copy: String, raw: String, withUnit: String? = nil, strings: Strings = .en) -> AlfredItem {
        AlfredItem(
            title: title, subtitle: strings["copy_number"], arg: copy,
            mods: Mods(
                cmd: .init(arg: raw, subtitle: strings["copy_raw"]),
                alt: withUnit.map { .init(arg: $0, subtitle: strings["copy_with_unit"]) }))
    }

    public static func error(_ message: String, subtitle: String = "") -> AlfredItem {
        AlfredItem(title: message, subtitle: subtitle, arg: "", valid: false)
    }
}

public struct AlfredOutput: Codable, Equatable {
    public var items: [AlfredItem]
    public init(items: [AlfredItem] = []) { self.items = items }

    public func json() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        return (try? String(data: enc.encode(self), encoding: .utf8)) ?? #"{"items":[]}"#
    }
}
