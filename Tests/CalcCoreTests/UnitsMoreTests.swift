import XCTest
@testable import CalcCore

final class UnitsMoreTests: XCTestCase {
    private let ctx = Context(dataDir: URL(fileURLWithPath: NSTemporaryDirectory()))

    private func first(_ q: String) async -> String? { await UnitsTool().evaluate(q, context: ctx)?.first?.title }

    func testOldAndImperialUnits() async {
        let cases: [(String, String)] = [
            ("1 thou to mm", "0.0254 mm"), ("1 mil to in", "0.001 in"), ("1 chain to m", "20.1168 m"),
            ("3 chains to ft", "198 ft"), ("1 furlong to m", "201.168 m"), ("2 furlongs to yd", "440 yd"),
            ("1 rod to ft", "16.5 ft"), ("1 perch to m", "5.0292 m"), ("1 pole to ft", "16.5 ft"),
            ("1 league to mi", "3 mi"), ("1 fathom to ft", "6 ft"), ("1 cable to m", "185.2 m"),
            ("1 nautical league to nmi", "3 nmi"), ("1 link to in", "7.92 in"), ("1 hand to in", "4 in"),
            ("1 bushel to l", "35.23907017 l"), ("1 peck to l", "8.80976754 l"), ("1 uk peck to l", "9.09218 l"),
            ("1 grain to mg", "64.79891 mg"), ("1 dram to g", "1.7718452 g"), ("1 cwt to lb", "100 lb"),
            ("1 long hundredweight to lb", "112 lb"), ("1 slug to kg", "14.59390294 kg"),
            ("1 stone to lb", "14 lb"), ("1 acre to sqft", "43,560 sqft"), ("1 ton to kg", "907.18474 kg"),
            ("1 troy ounce to g", "31.1034768 g"), ("1 carat to mg", "200 mg"), ("1 gill to ml", "118.29411825 ml"),
            ("1 pinch to tsp", "0.0625 tsp"), ("1 dash to tsp", "0.125 tsp"), ("1 barrel to l", "158.98729493 l"),
        ]
        for (q, want) in cases { let got = await first(q); XCTAssertEqual(got, want, q) }
    }

    func testTonStaysAndNonUnitsAreNotUnits() async {
        var got = await first("1 ton to usd"); XCTAssertNil(got)
        got = await first("1 link to usd"); XCTAssertNil(got)
        got = await first("1 ton to ukt"); XCTAssertEqual(got, "0.89285714 long ton")
    }

    func testScientificNotationInUnits() async {
        let cases: [(String, String)] = [
            ("3.2e-5 m to mm", "0.032 mm"), ("1.5e3 m to km", "1.5 km"), ("2E-4 km to m", "0.2 m"),
            ("2e3 m to km", "2 km"), ("1e+3 m to km", "1 km"), ("5 ev to mev", "0.000005 mev"),
        ]
        for (q, want) in cases { let got = await first(q); XCTAssertEqual(got, want, q) }
    }

    func testExponentGuards() async {
        for q in ["1 em to px", "3 eur", "2e to usd", "2 e to usd"] {
            let got = await first(q); XCTAssertNil(got, q)
        }
        let g1 = ToolSupport.match("(\(ToolSupport.number))(.*)", in: "2e")
        XCTAssertEqual(g1, ["2", "e"])
        let g2 = ToolSupport.match("(\(ToolSupport.number))\\s*([a-z]+)", in: "1 em")
        XCTAssertEqual(g2, ["1", "em"])
        let g3 = ToolSupport.match("(\(ToolSupport.number))\\s*([a-z]+)", in: "2E-4 kb")
        XCTAssertEqual(g3, ["2E-4", "kb"])
        let g4 = ToolSupport.match("(\(ToolSupport.signedNumber))\\s*([a-z]+)", in: "-1.5e3 mb")
        XCTAssertEqual(g4, ["-1.5e3", "mb"])
        var eu = Settings(); eu.decimalSeparator = ","; eu.thousandsSeparator = "."
        XCTAssertEqual(NumberFormat.parse("1.5e3", settings: Settings()), 1500)
        XCTAssertEqual(NumberFormat.parse("1,5e3", settings: eu), 1500)
        XCTAssertEqual(NumberFormat.parse("2E-4", settings: Settings()), 0.0002)
    }
}
