import Foundation

/// A zone the user named, with the label they typed when it was an abbreviation.
struct ResolvedZone {
    var zone: TimeZone
    var label: String?
    var note: String?
}

/// Resolves abbreviations, IANA ids, UTC offsets, aliases and city names to time zones.
enum ZoneResolver {
    /// Fixed-offset abbreviations (seconds from UTC); the offset does not change with the season.
    static let abbreviations: [String: Int] = [
        "EST": -18000, "EDT": -14400, "CST": -21600, "CDT": -18000, "MST": -25200, "MDT": -21600,
        "PST": -28800, "PDT": -25200, "AKST": -32400, "AKDT": -28800, "HST": -36000,
        "UTC": 0, "GMT": 0, "Z": 0, "WET": 0, "WEST": 3600, "BST": 3600, "CET": 3600, "CEST": 7200,
        "EET": 7200, "EEST": 10800, "MSK": 10800, "SAST": 7200, "GST": 14400, "PKT": 18000, "IST": 19800,
        "WIB": 25200, "ICT": 25200, "SGT": 28800, "HKT": 28800, "AWST": 28800, "JST": 32400, "KST": 32400,
        "ACST": 34200, "ACDT": 37800, "AEST": 36000, "AEDT": 39600, "NZST": 43200, "NZDT": 46800,
    ]

    private static let notes: [String: String] = [
        "IST": "IST read as India Standard Time (UTC+05:30); Irish and Israel time differ",
        "CST": "CST read as US Central Standard Time (UTC-06:00); China and Cuba differ",
        "BST": "BST read as British Summer Time (UTC+01:00)",
        "GST": "GST read as Gulf Standard Time (UTC+04:00)",
    ]

    /// Informal names mapped to DST-aware zones.
    static let aliases: [String: String] = [
        "nyc": "America/New_York", "ny": "America/New_York", "new york city": "America/New_York", "boston": "America/New_York",
        "washington": "America/New_York", "washington dc": "America/New_York", "dc": "America/New_York", "miami": "America/New_York",
        "atlanta": "America/New_York", "eastern": "America/New_York", "et": "America/New_York", "us eastern": "America/New_York",
        "la": "America/Los_Angeles", "sf": "America/Los_Angeles", "san francisco": "America/Los_Angeles", "seattle": "America/Los_Angeles",
        "california": "America/Los_Angeles", "pacific": "America/Los_Angeles", "pt": "America/Los_Angeles", "us pacific": "America/Los_Angeles",
        "silicon valley": "America/Los_Angeles", "las vegas": "America/Los_Angeles", "san diego": "America/Los_Angeles",
        "central": "America/Chicago", "ct": "America/Chicago", "us central": "America/Chicago", "houston": "America/Chicago",
        "dallas": "America/Chicago", "texas": "America/Chicago", "austin": "America/Chicago",
        "mountain": "America/Denver", "mt": "America/Denver", "us mountain": "America/Denver", "salt lake city": "America/Denver",
        "hawaii": "Pacific/Honolulu", "alaska": "America/Anchorage", "mexico city": "America/Mexico_City", "cdmx": "America/Mexico_City",
        "uk": "Europe/London", "england": "Europe/London", "britain": "Europe/London", "great britain": "Europe/London",
        "germany": "Europe/Berlin", "france": "Europe/Paris", "spain": "Europe/Madrid", "italy": "Europe/Rome", "sweden": "Europe/Stockholm",
        "kiev": "Europe/Kiev", "kyiv": "Europe/Kiev", "moscow": "Europe/Moscow", "russia": "Europe/Moscow",
        "japan": "Asia/Tokyo", "korea": "Asia/Seoul", "china": "Asia/Shanghai", "beijing": "Asia/Shanghai", "shanghai": "Asia/Shanghai",
        "hongkong": "Asia/Hong_Kong", "hong kong": "Asia/Hong_Kong", "india": "Asia/Kolkata", "kolkata": "Asia/Kolkata",
        "delhi": "Asia/Kolkata", "new delhi": "Asia/Kolkata", "mumbai": "Asia/Kolkata", "bombay": "Asia/Kolkata", "bangalore": "Asia/Kolkata",
        "bengaluru": "Asia/Kolkata", "chennai": "Asia/Kolkata", "saigon": "Asia/Ho_Chi_Minh", "ho chi minh": "Asia/Ho_Chi_Minh",
        "vietnam": "Asia/Ho_Chi_Minh", "uae": "Asia/Dubai", "abu dhabi": "Asia/Dubai", "australia": "Australia/Sydney",
        "nz": "Pacific/Auckland", "new zealand": "Pacific/Auckland", "wellington": "Pacific/Auckland", "brazil": "America/Sao_Paulo",
        "sao paulo": "America/Sao_Paulo", "rio": "America/Sao_Paulo", "rio de janeiro": "America/Sao_Paulo", "south africa": "Africa/Johannesburg",
        "cape town": "Africa/Johannesburg", "korea seoul": "Asia/Seoul",
    ]

    /// Lowercased last path component (underscores as spaces) -> identifier, for city names.
    private static let cityIndex: [String: String] = {
        let regions = ["Africa/", "America/", "Asia/", "Atlantic/", "Australia/", "Europe/", "Indian/", "Pacific/"]
        var index: [String: String] = [:]
        for id in TimeZone.knownTimeZoneIdentifiers.sorted() where regions.contains(where: { id.hasPrefix($0) }) {
            let city = String(id.split(separator: "/").last!).replacingOccurrences(of: "_", with: " ").lowercased()
            if index[city] == nil { index[city] = id }
        }
        return index
    }()

    private static let idIndex: [String: String] = {
        var m: [String: String] = [:]
        for id in TimeZone.knownTimeZoneIdentifiers { m[id.lowercased()] = id }
        return m
    }()

    static func resolve(_ raw: String) -> ResolvedZone? {
        var t = raw.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        if t.isEmpty { return nil }
        if let r = resolveExact(t) { return r }
        for suffix in [" time", " timezone", " time zone"] where t.hasSuffix(suffix) {
            if let r = resolveExact(String(t.dropLast(suffix.count))) { return r }
        }
        return nil
    }

    private static func resolveExact(_ t: String) -> ResolvedZone? {
        let upper = t.uppercased()
        if let secs = abbreviations[upper], let z = TimeZone(secondsFromGMT: secs) {
            return ResolvedZone(zone: z, label: upper, note: notes[upper])
        }
        if let g = ToolSupport.match(#"(utc|gmt)\s*([+-])\s*(\d{1,2})(?::?(\d{2}))?"#, in: t),
           let h = Int(g[2]) {
            let m = Int(g[3]) ?? 0
            guard h <= 14, m < 60 else { return nil }
            let secs = (h * 3600 + m * 60) * (g[1] == "-" ? -1 : 1)
            guard let z = TimeZone(secondsFromGMT: secs) else { return nil }
            let label = "UTC" + g[1] + String(format: "%02d:%02d", h, m)
            return ResolvedZone(zone: z, label: label, note: nil)
        }
        if let id = aliases[t], let z = TimeZone(identifier: id) { return ResolvedZone(zone: z) }
        if let id = idIndex[t.replacingOccurrences(of: " ", with: "_")], let z = TimeZone(identifier: id) { return ResolvedZone(zone: z) }
        if t.contains("/"), !t.contains(" ") {
            let cased = t.split(separator: "/").map { $0.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "_") }.joined(separator: "/")
            if let z = TimeZone(identifier: cased) { return ResolvedZone(zone: z) }
        }
        if let id = cityIndex[t], let z = TimeZone(identifier: id) { return ResolvedZone(zone: z) }
        return nil
    }

    private static let european: [String: (String, String)] = {
        var m: [String: (String, String)] = [:]
        for c in ["Paris", "Berlin", "Madrid", "Rome", "Amsterdam", "Brussels", "Vienna", "Zurich", "Stockholm", "Oslo", "Copenhagen",
                  "Prague", "Warsaw", "Budapest", "Belgrade", "Zagreb", "Luxembourg", "Monaco", "Malta", "Bratislava", "Ljubljana"] { m["Europe/" + c] = ("CET", "CEST") }
        for c in ["Athens", "Helsinki", "Kiev", "Kyiv", "Bucharest", "Sofia", "Riga", "Tallinn", "Vilnius"] { m["Europe/" + c] = ("EET", "EEST") }
        m["Europe/London"] = ("GMT", "BST"); m["Europe/Dublin"] = ("GMT", "IST"); m["Europe/Lisbon"] = ("WET", "WEST")
        m["Australia/Sydney"] = ("AEST", "AEDT"); m["Australia/Melbourne"] = ("AEST", "AEDT"); m["Australia/Hobart"] = ("AEST", "AEDT")
        m["Australia/Canberra"] = ("AEST", "AEDT"); m["Australia/Brisbane"] = ("AEST", "AEST"); m["Australia/Adelaide"] = ("ACST", "ACDT")
        m["Australia/Perth"] = ("AWST", "AWST"); m["Pacific/Auckland"] = ("NZST", "NZDT")
        return m
    }()

    private static let fixed: [String: String] = [
        "Asia/Tokyo": "JST", "Asia/Seoul": "KST", "Asia/Kolkata": "IST", "Asia/Calcutta": "IST", "Asia/Shanghai": "CST",
        "Asia/Hong_Kong": "HKT", "Asia/Singapore": "SGT", "Asia/Dubai": "GST", "Asia/Karachi": "PKT", "Asia/Bangkok": "ICT",
        "Asia/Jakarta": "WIB", "Europe/Moscow": "MSK", "Africa/Johannesburg": "SAST", "Africa/Cairo": "EET",
        "Africa/Lagos": "WAT", "Africa/Nairobi": "EAT",
    ]

    /// Short zone name at a date; Foundation only knows US names, so common zones come from a table.
    static func abbreviation(_ zone: TimeZone, at date: Date) -> String {
        if let (std, dst) = european[zone.identifier] { return zone.isDaylightSavingTime(for: date) ? dst : std }
        if let f = fixed[zone.identifier] { return f }
        if zone.identifier == "UTC" || zone.identifier == "GMT" { return "UTC" }
        return zone.abbreviation(for: date) ?? zone.identifier
    }

    static func label(_ r: ResolvedZone, at date: Date) -> String { r.label ?? abbreviation(r.zone, at: date) }
}
