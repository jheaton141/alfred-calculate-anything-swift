import XCTest
@testable import CalcCore

final class ReviewFixNumberTests: XCTestCase {
    private func run(_ q: String, _ s: Settings = Settings()) async -> [String] {
        let ctx = Context(settings: s, rates: nil, dataDir: URL(fileURLWithPath: NSTemporaryDirectory()))
        return await Engine(tools: DefaultEngine.tools()).run(q, context: ctx).items.map(\.title)
    }

    func testIndianGroupingParses() {
        let s = Settings()
        XCTAssertEqual(NumberFormat.parse("12,34,567", settings: s), 1234567)
        XCTAssertEqual(NumberFormat.parse("1,00,000", settings: s), 100000)
        XCTAssertEqual(NumberFormat.parse("12,34,567.5", settings: s), 1234567.5)
        for bad in ["1,2,3,4", "1,,2", "12,3456", "123,45,678", "1,234,56"] { XCTAssertNil(NumberFormat.parse(bad, settings: s), bad) }
    }

    func testIndianInputInTools() async {
        var got = await run("12,34,567 + 1"); XCTAssertEqual(got.first, "1,234,568")
        got = await run("12,34,567 km to m"); XCTAssertTrue(got.first?.contains("1,234,567,000") ?? false, "\(got)")
        got = await run("1,00,000 m to km"); XCTAssertTrue(got.first?.contains("100") ?? false, "\(got)")
        got = await run("20% of 12,34,567"); XCTAssertFalse(got.isEmpty)
        got = await run("vat 12,34,567"); XCTAssertFalse(got.isEmpty)
    }

    func testRoundTrip() {
        for grouping in [NumberGrouping.indian, .western] {
            for comma in [false, true] {
                var s = Settings(); s.numberGrouping = grouping; s.decimals = 3
                if comma { s.decimalSeparator = ","; s.thousandsSeparator = "." }
                var v = 1.0
                for i in 0..<200 {
                    for x in [v, -v, v + 0.5, v / 7] {
                        let shown = NumberFormat.display(x, settings: s)
                        let want = Double(NumberFormat.plain(x, decimals: 3))!
                        XCTAssertEqual(NumberFormat.parse(shown, settings: s), want, "\(shown) \(grouping) \(comma)")
                    }
                    v = v * 1.37 + Double(i % 5)
                    if v > 1e13 { v = 3 }
                }
            }
        }
    }

    func testMultipliersExpandedCentrally() async {
        var got = await run("20% of 1 crore"); XCTAssertTrue(got.contains { $0.contains("2,000,000") }, "\(got)")
        got = await run("1 crore to hex"); XCTAssertTrue(got.contains { $0.uppercased().contains("989680") }, "\(got)")
        got = await run("1 crore vat"); XCTAssertFalse(got.isEmpty)
        got = await run("1 crore px to em"); XCTAssertFalse(got.isEmpty)
        got = await run("1 crore mb to gb"); XCTAssertTrue(got.contains { $0.contains("10,000") }, "\(got)")
        let s = Settings()
        let once = ToolSupport.expandIndianMultipliers("1 crore", settings: s)
        XCTAssertEqual(ToolSupport.expandIndianMultipliers(once, settings: s), once)
        XCTAssertEqual(ToolSupport.expandIndianMultipliers("#1 lakh 12:5 crore", settings: s), "#1 lakh 12:5 crore")
    }

    func testScientificCurrency() {
        let s = Settings()
        let r: (String) -> CurrencyUnit? = { CurrencyLexicon.resolve($0, coins: false) }
        XCTAssertEqual(ConversionParser.parse("1e3 usd to eur", settings: s, resolve: r)?.amount, 1000)
        XCTAssertEqual(ConversionParser.parse("2.5E2 usd to eur", settings: s, resolve: r)?.amount, 250)
        XCTAssertEqual(ConversionParser.parse("1e3 eur", settings: s, resolve: r)?.amount, 1000)
        XCTAssertEqual(ConversionParser.parse("5 eur", settings: s, resolve: r)?.amount, 5)
        XCTAssertNotEqual(ConversionParser.parse("2e to usd", settings: s, resolve: r)?.amount, 2)
    }

    func testSettingsTrimmedAndBounded() {
        let s = Settings(environment: ["decimals": " 3", "base_pixels": " 8", "number_grouping": " indian", "language": "es_ES "])
        XCTAssertEqual(s.decimals, 3); XCTAssertEqual(s.basePixels, 8)
        XCTAssertEqual(s.numberGrouping, .indian); XCTAssertEqual(s.language, "es_ES")
        XCTAssertEqual(Settings(environment: ["base_pixels": "0"]).basePixels, 16)
        XCTAssertEqual(Settings(environment: ["base_pixels": "1e9"]).basePixels, 16)
        XCTAssertEqual(Settings(environment: ["base_pixels": "1e-9"]).basePixels, 16)
        XCTAssertEqual(Settings(environment: ["pixels_base": "10"]).basePixels, 10)
        XCTAssertEqual(Settings(environment: ["vat_value": "20"]).vatPercentage, 20)
        XCTAssertEqual(Settings(environment: ["time_zone": "UTC"]).timezone, "UTC")
    }
}
