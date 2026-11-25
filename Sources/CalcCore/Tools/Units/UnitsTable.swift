import Foundation

enum UnitDimension: String {
    case length, area, volume, mass, speed, time, temperature, pressure, energy, power, angle, count, fuel, force
}

struct UnitDef {
    let id: String
    let dim: UnitDimension
    let symbol: String
    let plural: String?
    let factor: Double   // multiplier to the dimension's base unit (unused for temperature)
    let aliases: [String]
}

/// Unit table and alias index.
enum UnitsTable {
    private static func u(_ id: String, _ dim: UnitDimension, _ symbol: String, _ factor: Double, _ aliases: [String], plural: String? = nil) -> UnitDef {
        UnitDef(id: id, dim: dim, symbol: symbol, plural: plural, factor: factor, aliases: [id] + aliases)
    }

    static let au = 149_597_870_700.0

    static let all: [UnitDef] = [
        // length (base m)
        u("m", .length, "m", 1, ["meter", "metre", "meters", "metres"]),
        u("km", .length, "km", 1000, ["kilometer", "kilometers", "kms"]),
        u("dm", .length, "dm", 0.1, ["decimeter"]),
        u("cm", .length, "cm", 0.01, ["centimeter", "centimeters"]),
        u("mm", .length, "mm", 0.001, ["millimeter", "milimeter", "milimeters"]),
        u("μm", .length, "μm", 1e-6, ["um", "micrometer", "micron", "microns"]),
        u("nm", .length, "nm", 1e-9, ["nanometer"]),
        u("pm", .length, "pm", 1e-12, ["picometer"]),
        u("in", .length, "in", 0.0254, ["inch", "inches", "″", "\""]),
        u("ft", .length, "ft", 0.3048, ["foot", "feet", "feets", "foots", "′", "'"]),
        u("yd", .length, "yd", 0.9144, ["yard", "yards"]),
        u("mi", .length, "mi", 1609.344, ["mile", "miles"]),
        u("nmi", .length, "nmi", 1852, ["nauticalmile", "nauticalmiles"]),
        u("hand", .length, "hand", 0.1016, ["hands"]),
        u("thou", .length, "thou", 2.54e-5, ["mil", "mils"]),
        u("link", .length, "link", 0.201168, ["links"]),
        u("rod", .length, "rod", 5.0292, ["rods", "perch", "perches", "pole", "poles"]),
        u("chain", .length, "chain", 20.1168, ["chains", "ch"]),
        u("furlong", .length, "furlong", 201.168, ["furlongs", "fur"]),
        u("league", .length, "league", 4828.032, ["leagues"]),
        u("fathom", .length, "fathom", 1.8288, ["fathoms", "ftm", "fth"]),
        u("cable", .length, "cable", 185.2, ["cables"]),
        u("nleague", .length, "nautical league", 5556, ["nauticalleague", "nauticalleagues"]),
        u("ly", .length, "ly", 9_460_730_472_580_800, ["lightyear", "lightyears"]),
        u("au", .length, "au", au, ["astronomicalunit"]),
        u("pc", .length, "pc", au * 648_000 / Double.pi, ["parsec"]),
        // area (base m2)
        u("sqm", .area, "sqm", 1, ["m2", "sqmeter", "sqmeters"]),
        u("sqkm", .area, "sqkm", 1e6, ["km2", "sqkilometer"]),
        u("sqcm", .area, "sqcm", 1e-4, ["cm2", "sqcentimeter"]),
        u("sqmm", .area, "sqmm", 1e-6, ["mm2", "sqmillimeter"]),
        u("sqft", .area, "sqft", 0.09290304, ["ft2", "sqfoot", "sqfeet"]),
        u("sqin", .area, "sqin", 0.00064516, ["in2", "sqinch", "sqinches"]),
        u("sqyd", .area, "sqyd", 0.83612736, ["yd2", "sqyard"]),
        u("sqmi", .area, "sqmi", 2_589_988.110336, ["mi2", "sqmile"]),
        u("acre", .area, "ac", 4046.8564224, ["ac", "acres"]),
        u("hectare", .area, "ha", 10000, ["ha", "hectares"]),
        // volume (base l)
        u("l", .volume, "l", 1, ["liter", "litre", "liters", "litres", "ltr"]),
        u("dm3", .volume, "dm3", 1, ["cudecimeter"]),
        u("ml", .volume, "ml", 0.001, ["milliliter", "mililiter", "mililiters"]),
        u("cm3", .volume, "cm3", 0.001, ["cc", "cucentimeter"]),
        u("cl", .volume, "cl", 0.01, ["centiliter"]),
        u("dl", .volume, "dl", 0.1, ["deciliter"]),
        u("hl", .volume, "hl", 100, ["hectoliter"]),
        u("kl", .volume, "kl", 1000, ["kiloliter"]),
        u("m3", .volume, "m3", 1000, ["cumeter"]),
        u("gal", .volume, "gal", 3.785411784, ["gallon", "usgal", "usgallon"]),
        u("qt", .volume, "qt", 0.946352946, ["quart", "usqt", "usquart"]),
        u("pt", .volume, "pt", 0.473176473, ["pint", "uspt", "uspint"]),
        u("cup", .volume, "cup", 0.2365882365, ["uscup"]),
        u("floz", .volume, "fl oz", 0.0295735295625, ["fluidounce", "usfloz", "usfluidounce"]),
        u("tbsp", .volume, "tbsp", 0.01478676478125, ["tablespoon", "tbs"]),
        u("tsp", .volume, "tsp", 0.00492892159375, ["teaspoon"]),
        u("ukgal", .volume, "uk gal", 4.54609, ["ukgallon"]),
        u("ukqt", .volume, "uk qt", 1.1365225, ["ukquart"]),
        u("ukpt", .volume, "uk pt", 0.56826125, ["ukpint"]),
        u("ukfloz", .volume, "uk fl oz", 0.0284130625, ["ukfluidounce"]),
        u("metriccup", .volume, "metric cup", 0.25, []),
        u("yd3", .volume, "yd3", 764.554857984, ["cuyard"]),
        u("ft3", .volume, "ft3", 28.316846592, ["cufoot", "cufeet"]),
        u("in3", .volume, "in3", 0.016387064, ["cuinch", "cuinches"]),
        u("peck", .volume, "peck", 8.80976754172, ["pecks", "uspeck", "pk"]),
        u("bushel", .volume, "bushel", 35.23907016688, ["bushels", "usbushel", "bu"]),
        u("ukpeck", .volume, "uk peck", 9.09218, ["ukpecks"]),
        u("ukbushel", .volume, "uk bushel", 36.36872, ["ukbushels"]),
        u("gill", .volume, "gill", 0.11829411825, ["gills", "usgill"]),
        u("ukgill", .volume, "uk gill", 0.1420653125, ["ukgills"]),
        u("barrel", .volume, "barrel", 158.987294928, ["barrels", "bbl", "oilbarrel"]),
        u("dessertspoon", .volume, "dessertspoon", 0.00985784318750, ["dessertspoons", "dsp"]),
        u("pinch", .volume, "pinch", 0.00030805759960937, ["pinches"]),
        u("dash", .volume, "dash", 0.00061611519921875, ["dashes"]),
        // mass (base kg)
        u("kg", .mass, "kg", 1, ["kilogram", "kilo", "kilos", "kgs"]),
        u("g", .mass, "g", 0.001, ["gram", "gm"]),
        u("mg", .mass, "mg", 1e-6, ["milligram", "miligram", "miligrams"]),
        u("μg", .mass, "μg", 1e-9, ["ug", "mcg", "microgram"]),
        u("lb", .mass, "lb", 0.45359237, ["pound", "lbs", "pounds"]),
        u("ozmass", .mass, "oz", 0.028349523125, ["oz", "ounce"]),
        u("st", .mass, "st", 6.35029318, ["stone", "stones"]),
        u("t", .mass, "t", 1000, ["tonne", "tonnes", "metricton"]),
        u("ukt", .mass, "long ton", 1016.0469088, ["longton", "ukton"]),
        u("ust", .mass, "short ton", 907.18474, ["shortton", "uston", "ton"]),
        u("grain", .mass, "grain", 6.479891e-5, ["grains", "gr"]),
        u("dram", .mass, "dram", 0.0017718451953125, ["drams", "dr"]),
        u("cwt", .mass, "cwt", 45.359237, ["hundredweight", "hundredweights", "cwts", "ushundredweight", "shorthundredweight"]),
        u("ukcwt", .mass, "uk cwt", 50.80234544, ["longhundredweight", "ukhundredweight"]),
        u("slug", .mass, "slug", 14.593902937206364, ["slugs"]),
        u("ozt", .mass, "ozt", 0.0311034768, ["troyounce", "troyounces", "troyoz"]),
        u("carat", .mass, "carat", 0.0002, ["carats", "ct"]),
        u("dwt", .mass, "dwt", 0.00155517384, ["pennyweight", "pennyweights"]),
        // speed (base m/s)
        u("mps", .speed, "mps", 1, ["m/s", "meterspersecond", "meterpersecond"]),
        u("kph", .speed, "kph", 1000.0 / 3600.0, ["km/h", "kmh", "kmph", "kilometersperhour", "kilometerperhour"]),
        u("mph", .speed, "mph", 0.44704, ["mi/h", "milesperhour", "mileperhour", "milehour"]),
        u("fps", .speed, "fps", 0.3048, ["ft/s", "feetpersecond"]),
        u("knot", .speed, "knot", 1852.0 / 3600.0, ["kn", "kt", "kts"]),
        // time (base s)
        u("s", .time, "second", 1, ["sec", "second", "secs", "seconds"], plural: "seconds"),
        u("ms", .time, "millisecond", 0.001, ["millisecond", "milliseconds"], plural: "milliseconds"),
        u("μs", .time, "microsecond", 1e-6, ["us", "microsecond", "microseconds"], plural: "microseconds"),
        u("ns", .time, "nanosecond", 1e-9, ["nanosecond", "nanoseconds"], plural: "nanoseconds"),
        u("min", .time, "minute", 60, ["minute", "mins", "minutes"], plural: "minutes"),
        u("hr", .time, "hour", 3600, ["h", "hour", "hrs", "hours"], plural: "hours"),
        u("day", .time, "day", 86400, ["d", "days"], plural: "days"),
        u("week", .time, "week", 604800, ["wk", "wks", "weeks"], plural: "weeks"),
        u("month", .time, "month", 2_628_000, ["mo", "months"], plural: "months"),
        u("year", .time, "year", 31_536_000, ["y", "yr", "yrs", "years"], plural: "years"),
        // count words (base unit 1)
        u("thousand", .count, "thousand", 1e3, []),
        u("lakh", .count, "lakh", 1e5, ["lac", "lakhs", "lacs"]),
        u("million", .count, "million", 1e6, []),
        u("crore", .count, "crore", 1e7, ["crores"]),
        u("billion", .count, "billion", 1e9, []),
        // temperature (base K, converted by formula)
        u("k", .temperature, "k", 1, ["kelvin", "kelvins"]),
        u("c", .temperature, "c", 1, ["celsius", "°c", "degc"]),
        u("f", .temperature, "f", 1, ["fahrenheit", "fahrenheits", "°f", "degf"]),
        // fuel economy (base km/l; l/100km is the inverse, handled in the converter)
        u("kmpl", .fuel, "km/l", 1, ["km/l", "kpl", "kmperl", "kilometersperliter"]),
        u("mpg", .fuel, "mpg", 1.609344 / 3.785411784, ["mpgus", "usmpg", "milespergallon"]),
        u("ukmpg", .fuel, "mpg (uk)", 1.609344 / 4.54609, ["mpguk", "mpgimp", "impmpg", "ukmilespergallon"]),
        u("l100km", .fuel, "l/100km", 1, ["l/100km", "lper100km", "litersper100km", "lp100km"]),
        // pressure (base Pa)
        u("pa", .pressure, "pa", 1, ["pascal"]),
        u("hpa", .pressure, "hpa", 100, ["hectopascal"]),
        u("kpa", .pressure, "kpa", 1000, ["kilopascal"]),
        u("mpa", .pressure, "mpa", 1e6, ["megapascal"]),
        u("bar", .pressure, "bar", 1e5, []),
        u("mbar", .pressure, "mbar", 100, ["millibar"]),
        u("psi", .pressure, "psi", 6894.757293168361, []),
        u("atm", .pressure, "atm", 101_325, ["atmosphere"]),
        u("mmhg", .pressure, "mmhg", 133.322387415, []),
        u("torr", .pressure, "torr", 101_325.0 / 760.0, []),
        // energy (base J)
        u("j", .energy, "j", 1, ["joule"]),
        u("kj", .energy, "kj", 1000, ["kilojoule"]),
        u("mj", .energy, "mj", 1e6, ["megajoule"]),
        u("cal", .energy, "cal", 4.184, []),
        u("kcal", .energy, "kcal", 4184, ["calorie", "calories", "kilocalorie"]),
        u("ftlb", .energy, "ftlb", 1.3558179483314004, ["footpound"]),
        u("whr", .energy, "whr", 3600, ["wh", "watthour"]),
        u("kwhr", .energy, "kwhr", 3_600_000, ["kwh", "kilowatthour"]),
        u("mwhr", .energy, "mwhr", 3_600_000_000, ["mwh", "megawatthour"]),
        u("btu", .energy, "btu", 1055.05585262, []),
        u("ev", .energy, "ev", 1.602176634e-19, ["electronvolt"]),
        u("mev", .energy, "mev", 1.602176634e-13, []),
        // power (base W)
        u("w", .power, "w", 1, ["watt"]),
        u("kw", .power, "kw", 1000, ["kilowatt"]),
        u("megawatt", .power, "megawatt", 1e6, ["megawatts"]),
        u("ps", .power, "ps", 735.49875, ["metrichorsepower"]),
        u("hp", .power, "hp", 745.69987158227022, ["horsepower"]),
        // force (base N)
        u("n", .force, "n", 1, ["newton", "newtons"]),
        u("kilonewton", .force, "kN", 1000, ["kilonewtons"]),
        u("lbf", .force, "lbf", 4.4482216152605, ["poundforce"]),
        u("kgf", .force, "kgf", 9.80665, ["kilogramforce"]),
        u("dyne", .force, "dyn", 1e-5, ["dynes", "dyn"]),
        // angle (base degree)
        u("deg", .angle, "deg", 1, ["degree", "°"]),
        u("rad", .angle, "rad", 180 / Double.pi, ["radian"]),
        u("grad", .angle, "grad", 0.9, ["gon"]),
        u("turn", .angle, "turn", 360, ["rev", "revolution"]),
        u("arcmin", .angle, "arcmin", 1.0 / 60.0, ["arcminute"]),
        u("arcsec", .angle, "arcsec", 1.0 / 3600.0, ["arcsecond"]),
    ]

    /// Lowercases and strips spacing and punctuation so "Fl. Oz", "fl-oz" and "floz" share one key.
    static func normalize(_ s: String) -> String {
        var t = s.lowercased()
        t = t.replacingOccurrences(of: "µ", with: "μ").replacingOccurrences(of: "²", with: "2").replacingOccurrences(of: "³", with: "3")
        t.removeAll { " .-^_".contains($0) }
        t = t.replacingOccurrences(of: "metre", with: "meter").replacingOccurrences(of: "litre", with: "liter")
        if t.hasPrefix("square") { t = "sq" + t.dropFirst(6) }
        if t.hasPrefix("cubic") { t = "cu" + t.dropFirst(5) }
        return t
    }

    static let byId: [String: UnitDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Normalised alias to candidate unit ids, in table order ("oz" has two).
    static let index: [String: [String]] = {
        var d: [String: [String]] = [:]
        for unit in all {
            for alias in unit.aliases {
                let key = normalize(alias)
                if !(d[key] ?? []).contains(unit.id) { d[key, default: []].append(unit.id) }
            }
        }
        d["oz", default: []].append("floz")
        return d
    }()

    static func candidates(_ text: String) -> [UnitDef] {
        let key = normalize(text)
        guard !key.isEmpty else { return [] }
        var ids = index[key]
        if ids == nil, key.count > 2, key.hasSuffix("s") { ids = index[String(key.dropLast())] }
        return (ids ?? []).compactMap { byId[$0] }
    }

    /// What a bare "10 km" shows: a few common units, mostly the other measuring system. Units not listed are left alone.
    static let defaultTargets: [String: [String]] = [
        "km": ["mi", "m"], "m": ["ft", "yd"], "cm": ["in", "mm"], "mm": ["in", "cm"], "mi": ["km", "m"], "ft": ["m", "cm"],
        "in": ["cm", "mm"], "yd": ["m", "ft"],
        "kg": ["lb", "ozmass"], "g": ["ozmass", "lb"], "lb": ["kg", "ozmass"], "ozmass": ["g", "kg"], "st": ["kg", "lb"],
        "t": ["kg", "lb"], "ust": ["kg", "lb"], "mg": ["g", "ozmass"],
        "l": ["gal", "floz", "ml"], "ml": ["floz", "tsp"], "gal": ["l", "ml"], "qt": ["l", "ml"], "pt": ["ml", "l"],
        "cup": ["ml", "floz", "tbsp"], "floz": ["ml", "tbsp"], "tbsp": ["ml", "tsp"], "tsp": ["ml"],
        "c": ["f", "k"], "f": ["c", "k"], 
        "kph": ["mph", "mps"], "mph": ["kph", "mps"], "mps": ["kph", "mph"], "knot": ["kph", "mph"], "fps": ["mps", "kph"],
        "sqm": ["sqft", "sqyd"], "sqft": ["sqm", "sqin"], "sqkm": ["sqmi", "acre"], "sqmi": ["sqkm", "acre"],
        "acre": ["hectare", "sqm", "sqft"], "hectare": ["acre", "sqm"], "sqcm": ["sqin"], "sqin": ["sqcm"],
        "kcal": ["kj", "whr"], "kj": ["kcal", "j"], "j": ["cal", "kj"], "cal": ["j", "kj"], "kwhr": ["mj", "kcal"],
        "w": ["kw", "hp"], "kw": ["hp", "w"], "hp": ["kw", "w"],
        "psi": ["bar", "kpa", "atm"], "bar": ["psi", "kpa", "atm"], "atm": ["kpa", "psi", "bar"], "kpa": ["psi", "bar"], "mmhg": ["kpa", "psi"],
        "deg": ["rad"], "rad": ["deg"],
        "s": ["min", "hr"], "min": ["s", "hr"], "hr": ["min", "day"], "day": ["hr", "week"], "week": ["day", "hr"], "month": ["day", "week"], "year": ["month", "day"],
        "mpg": ["l100km", "kmpl"], "l100km": ["mpg", "kmpl"], "kmpl": ["mpg", "l100km"],
        "n": ["lbf", "kgf"], "lbf": ["n", "kgf"], "kgf": ["n", "lbf"], "kilonewton": ["lbf", "kgf"],
    ]

    /// Whole-unit fraction row: converting x of a unit leaves a remainder expressed in the smaller unit.
    static let fraction: [String: String] = [
        "m": "cm", "km": "m", "dm": "cm", "cm": "mm", "mm": "μm", "μm": "nm", "nm": "pm",
        "ft": "in", "yd": "in", "mi": "ft", "l": "ml", "pt": "floz", "ukpt": "ukfloz",
        "gal": "qt", "qt": "pt", "ukqt": "ukpt", "ukgal": "ukqt", "g": "mg", "st": "lb",
    ]
    /// Targets that get a fraction row (upstream shows it only for units that are themselves a fraction unit).
    static let fractionTargets: Set<String> = Set(fraction.keys).intersection(Set(fraction.values))
}
