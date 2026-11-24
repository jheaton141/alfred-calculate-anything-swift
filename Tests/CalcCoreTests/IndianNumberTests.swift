import XCTest
@testable import CalcCore

final class IndianNumberTests: XCTestCase {
    private var indian: Settings { var s = Settings(); s.numberGrouping = .indian; return s }
    private func ctx(_ s: Settings) -> Context { var c = Context(dataDir: URL(fileURLWithPath: NSTemporaryDirectory())); c.settings = s; return c }
    private func first(_ q: String, _ s: Settings = Settings()) async -> String? {
        await UnitsTool().evaluate(q, context: ctx(s))?.first?.title
    }

    func testGroupingFormat() {
        XCTAssertEqual(NumberFormat.display(123456789, settings: indian), "12,34,56,789")
        XCTAssertEqual(NumberFormat.display(-1000000, settings: indian), "-10,00,000")
        XCTAssertEqual(NumberFormat.display(123456.5, settings: indian), "1,23,456.5")
        XCTAssertEqual(NumberFormat.display(999, settings: indian), "999")
        XCTAssertEqual(NumberFormat.display(1000, settings: indian), "1,000")
        XCTAssertEqual(NumberFormat.display(123456789, settings: Settings()), "123,456,789")
    }

    func testSettingFromEnvironment() {
        XCTAssertEqual(Settings(environment: ["number_grouping": "indian"]).numberGrouping, .indian)
        XCTAssertEqual(Settings(environment: ["number_grouping": "western"]).numberGrouping, .western)
        XCTAssertEqual(Settings(environment: ["number_grouping": "bogus"]).numberGrouping, .western)
        XCTAssertEqual(Settings(environment: [:]).numberGrouping, .western)
    }

    func testMultiplierWords() async {
        var got = await first("10 lakh"); XCTAssertEqual(got, "1,000,000")
        got = await first("10 lakh", indian); XCTAssertEqual(got, "10,00,000")
        got = await first("2 crore"); XCTAssertEqual(got, "20,000,000")
        got = await first("1 lac"); XCTAssertEqual(got, "100,000")
        got = await first("1 crore to million"); XCTAssertEqual(got, "10 million")
        got = await first("2.5 lakh to thousand"); XCTAssertEqual(got, "250 thousand")
        got = await first("3 lakh m to km"); XCTAssertEqual(got, "300 km")
    }

    func testExpandHelper() {
        let s = Settings()
        XCTAssertEqual(ToolSupport.expandIndianMultipliers("5 lakh usd to eur", settings: s), "500000 usd to eur")
        XCTAssertEqual(ToolSupport.expandIndianMultipliers("1.5 crore eur", settings: s), "15000000 eur")
        XCTAssertEqual(ToolSupport.expandIndianMultipliers("10 lakhs", settings: s), "1000000")
        XCTAssertEqual(ToolSupport.expandIndianMultipliers("10 lakhmi", settings: s), "10 lakhmi")
        XCTAssertEqual(ToolSupport.expandIndianMultipliers("5 usd to eur", settings: s), "5 usd to eur")
    }
}
