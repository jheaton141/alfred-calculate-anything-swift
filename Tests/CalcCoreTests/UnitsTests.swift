import XCTest
@testable import CalcCore

final class UnitsTests: XCTestCase {
    private let ctx = Context(dataDir: URL(fileURLWithPath: NSTemporaryDirectory()))

    private func run(_ q: String) async -> [AlfredItem]? { await UnitsTool().evaluate(q, context: ctx) }
    private func titles(_ q: String) async -> [String]? { await run(q)?.map(\.title) }
    private func first(_ q: String) async -> String? { await titles(q)?.first }

    func testPHPGoldenLengthMassSpeed() async {
        let cases: [(String, String)] = [
            ("10 km to mi", "6.21371192 mi"),
            ("100oz to kg", "2.83495231 kg"),
            ("1 mi to km", "1.609344 km"),
            ("5 ft to m", "1.524 m"),
            ("72 inches to ft", "6 ft"),
            ("96 in to ft", "8 ft"),
            ("12 in to ft", "1 ft"),
            ("1 gal to l", "3.78541178 l"),
            ("1 l to gal", "0.26417205 gal"),
            ("1 uk pint to ml", "568.26125 ml"),
            ("100 kph to mph", "62.13711922 mph"),
            ("0 c to f", "32 f"),
        ]
        for (q, want) in cases { let got = await first(q); XCTAssertEqual(got, want, q) }
    }

    func testPHPBugFixes() async {
        var got = await first("100 f to c"); XCTAssertEqual(got, "37.78 c")
        got = await first("30 c to k"); XCTAssertEqual(got, "303.15 k")
        got = await first("1 uk gallon to l"); XCTAssertEqual(got, "4.54609 l")
        got = await first("60 mph to kph"); XCTAssertEqual(got, "96.56064 kph")
        let t = await titles("84 in to ft"); XCTAssertEqual(t, ["7 ft"])
        got = await first("10 lb to kg"); XCTAssertEqual(got, "4.5359237 kg")
        got = await first("70 kg to lb"); XCTAssertEqual(got, "154.32358353 lb")
        got = await first("-40 f to c"); XCTAssertEqual(got, "-40 c")
    }

    func testFractionRow() async {
        let t = await titles("5 ft to m")
        XCTAssertEqual(t, ["1.524 m", "1 m, 52.4 cm"])
        let t2 = await titles("5 mi to km")
        XCTAssertEqual(t2, ["8.04672 km"])
    }

    func testTimeUnits() async {
        var got = await first("10 years to months"); XCTAssertEqual(got, "120 months")
        got = await first("1 year to sec"); XCTAssertEqual(got, "31,536,000 seconds")
        got = await first("1hr s"); XCTAssertEqual(got, "3,600 seconds")
        got = await first("90 min to hours"); XCTAssertEqual(got, "1.5 hours")
        got = await first("2 days to hours"); XCTAssertEqual(got, "48 hours")
        got = await first("1 day to min"); XCTAssertEqual(got, "1,440 minutes")
        got = await first("60 min to hr"); XCTAssertEqual(got, "1 hour")
        XCTAssertFalse((got ?? "").contains("  "))
    }

    func testNewVolumeUnits() async {
        var got = await first("1 cup to ml"); XCTAssertEqual(got, "236.5882365 ml")
        got = await first("1 tbsp to ml"); XCTAssertEqual(got, "14.78676478 ml")
        got = await first("1 tsp to ml"); XCTAssertEqual(got, "4.92892159 ml")
        got = await first("1 fl oz to ml"); XCTAssertEqual(got, "29.57352956 ml")
        got = await first("1 uk fl oz to ml"); XCTAssertEqual(got, "28.4130625 ml")
        got = await first("1 metric cup to ml"); XCTAssertEqual(got, "250 ml")
        got = await first("1 l to cup"); XCTAssertEqual(got, "4.22675284 cup")
        got = await first("1 tbsp to tsp"); XCTAssertEqual(got, "3 tsp")
        got = await first("1 cup to fl oz"); XCTAssertEqual(got, "8 fl oz")
        got = await first("3 uk gallon to uk pint"); XCTAssertEqual(got, "24 uk pt")
        got = await first("1 us pint to ml"); XCTAssertEqual(got, "473.176473 ml")
        got = await first("1 quart to l"); XCTAssertEqual(got, "0.94635295 l")
        got = await first("2.5 l to metric cup"); XCTAssertEqual(got, "10 metric cup")
    }

    func testOunceAmbiguity() async {
        var got = await first("1 ml to oz"); XCTAssertEqual(got, "0.03381402 fl oz")
        got = await first("500 ml to fl oz"); XCTAssertEqual(got, "16.90701135 fl oz")
        got = await first("1 oz to ml"); XCTAssertEqual(got, "29.57352956 ml")
        got = await first("1 oz to g"); XCTAssertEqual(got, "28.34952313 g")
        got = await first("1 lb to oz"); XCTAssertEqual(got, "16 oz")
        got = await first("100 oz to kg"); XCTAssertEqual(got, "2.83495231 kg")
        got = await first("2 l to oz"); XCTAssertEqual(got, "67.6280454 fl oz")
    }

    func testAreaUnits() async {
        var got = await first("10 acres to sqm"); XCTAssertEqual(got, "40,468.564224 sqm")
        got = await first("1 sqft to sqm"); XCTAssertEqual(got, "0.09290304 sqm")
        got = await first("1 hectare to acres"); XCTAssertEqual(got, "2.47105381 ac")
        got = await first("1 acre to sqft"); XCTAssertEqual(got, "43,560 sqft")
        got = await first("1 sq mi to sqkm"); XCTAssertEqual(got, "2.58998811 sqkm")
        got = await first("1 square meter to sq in"); XCTAssertEqual(got, "1,550.00310001 sqin")
        got = await first("144 sqin to sqft"); XCTAssertEqual(got, "1 sqft")
        got = await first("1 sq yd to sqft"); XCTAssertEqual(got, "9 sqft")
        got = await first("1 km2 to ha"); XCTAssertEqual(got, "100 ha")
    }

    func testMassSpeedOthers() async {
        var got = await first("1 stone to kg"); XCTAssertEqual(got, "6.35029318 kg")
        got = await first("10 kg to st"); XCTAssertEqual(got, "1.57473044 st")
        got = await first("1 t to kg"); XCTAssertEqual(got, "1,000 kg")
        got = await first("1 kg to g"); XCTAssertEqual(got, "1,000 g")
        got = await first("36 kph to mps"); XCTAssertEqual(got, "10 mps")
        got = await first("1 knot to kph"); XCTAssertEqual(got, "1.852 kph")
        got = await first("1 nmi to km"); XCTAssertEqual(got, "1.852 km")
        got = await first("1 atm to psi"); XCTAssertEqual(got, "14.69594878 psi")
        got = await first("1 bar to kpa"); XCTAssertEqual(got, "100 kpa")
        got = await first("1 kwh to kj"); XCTAssertEqual(got, "3,600 kj")
        got = await first("1 hp to kw"); XCTAssertEqual(got, "0.74569987 kw")
        got = await first("180 deg to rad"); XCTAssertEqual(got, "3.14159265 rad")
    }

    func testQueryForms() async {
        var got = await first("1 l = gal"); XCTAssertEqual(got, "0.26417205 gal")
        got = await first("1 l=gal"); XCTAssertEqual(got, "0.26417205 gal")
        got = await first("1 l in gal"); XCTAssertEqual(got, "0.26417205 gal")
        got = await first("10 in in cm"); XCTAssertEqual(got, "25.4 cm")
        got = await first("100f to c"); XCTAssertEqual(got, "37.78 c")
        got = await first("1 mile per hour to kph"); XCTAssertEqual(got, "1.609344 kph")
        got = await first("1 Km TO M"); XCTAssertEqual(got, "1,000 m")
        let multi = await run("10 km to mi, ft, yd")
        XCTAssertEqual(multi?.map(\.title).first, "6.21371192 mi")
        XCTAssertEqual(multi?.map(\.title), ["6.21371192 mi", "32,808.39895013 ft", "32,808 ft, 4.78740156 in", "10,936.13298338 yd"])
    }

    func testItemFields() async {
        let items = await run("10 km to mi")
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?[0].arg, "6.21371192")
        XCTAssertEqual(items?[0].mods?.cmd?.arg, "6.21371192")
        XCTAssertEqual(items?[0].mods?.alt?.arg, "6.21371192 mi")
        XCTAssertEqual(items?[0].valid, true)
        let big = await run("1 year to sec")
        XCTAssertEqual(big?[0].arg, "31,536,000")
        XCTAssertEqual(big?[0].mods?.cmd?.arg, "31536000")
    }

    func testNilForNonUnitQueries() async {
        for q in ["hello", "10 + 5", "usd 100", "100 usd to eur", "10 km", "km to mi", "10 gb to mb", "20% of 150"] {
            let r = await run(q)
            XCTAssertNil(r, q)
        }
    }

    func testDimensionMismatchError() async {
        let r = await run("10 kg to km")
        XCTAssertEqual(r?.count, 1)
        XCTAssertEqual(r?.first?.title, "Error, you can not convert from kg to km")
        XCTAssertEqual(r?.first?.valid, false)
        let e = await run("1 s to m")
        XCTAssertEqual(e?.first?.valid, false)
    }

    func testSettingsDecimalsAndSeparators() async {
        var s = Settings(); s.decimalSeparator = ","; s.thousandsSeparator = "."
        let c = Context(settings: s, dataDir: ctx.dataDir)
        let r = await UnitsTool().evaluate("1 km to m", context: c)
        XCTAssertEqual(r?.first?.title, "1.000 m")
        let r2 = await UnitsTool().evaluate("1,5 km to m", context: c)
        XCTAssertEqual(r2?.first?.title, "1.500 m")
        var s3 = Settings(); s3.decimals = 3
        let r3 = await UnitsTool().evaluate("100 f to c", context: Context(settings: s3, dataDir: ctx.dataDir))
        XCTAssertEqual(r3?.first?.title, "37.778 c")
    }
}
