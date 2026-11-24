import XCTest
@testable import CalcCore

final class VatRateTests: XCTestCase {
    private func run(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? { miscBlockingEvaluate(VatTool(), q, s) }
    private func titles(_ q: String, _ s: Settings = Settings()) -> [String] { run(q, s)?.map(\.title) ?? [] }

    func testPrefixFormRates() {
        let expected = ["VAT of 100 = 5", "100 plus VAT = 105", "100 minus VAT = 95.24"]
        for q in ["vat 100 5", "vat 100 5%", "vat 100 at 5%", "vat 100 @ 5", "vat 100 rate 5%", "vat 100 rate of 5"] {
            XCTAssertEqual(titles(q), expected, q)
            XCTAssertEqual(run(q)?.first?.subtitle, "VAT of 5%", q)
        }
    }

    func testPostfixFormRates() {
        XCTAssertEqual(titles("100 vat 5%"), ["VAT of 100 = 5", "100 plus VAT = 105", "100 minus VAT = 95.24"])
        XCTAssertEqual(titles("100 vat at 21%"), ["VAT of 100 = 21", "100 plus VAT = 121", "100 minus VAT = 82.64"])
        XCTAssertEqual(titles("100 + vat 5%"), ["100 plus VAT = 105"])
        XCTAssertEqual(titles("100 plus vat at 20"), ["100 plus VAT = 120"])
        XCTAssertEqual(titles("120 - vat 20%"), ["120 minus VAT = 100"])
        XCTAssertEqual(titles("120 excl vat at 20%"), ["120 minus VAT = 100"])
    }

    func testRateOverridesSettingAndFractionsWork() {
        var s = Settings(); s.vatPercentage = 25
        XCTAssertEqual(titles("vat 100", s).first, "VAT of 100 = 25")
        XCTAssertEqual(titles("vat 100 7.5%", s).first, "VAT of 100 = 7.5")
        XCTAssertEqual(run("vat 100 7.5%", s)?.first?.subtitle, "VAT of 7.5%")
        XCTAssertEqual(titles("vat 100 0%").first, "VAT of 100 = 0")
        var c = Settings(); c.decimalSeparator = ","; c.thousandsSeparator = "."
        XCTAssertEqual(titles("vat 100 7,5%", c).first, "VAT of 100 = 7,5")
    }

    func testRawCopyKeepsPrecision() {
        XCTAssertEqual(run("vat 100 at 5%")?[2].mods?.cmd?.arg, "95.2380952381")
    }

    func testBadRatesAndUnchangedBehaviour() {
        XCTAssertNil(run("vat 100 abc"))
        XCTAssertEqual(titles("vat 100").first, "VAT of 100 = 16")
        XCTAssertEqual(titles("100 vat").first, "VAT of 100 = 16")
        XCTAssertEqual(titles("100 + vat"), ["100 plus VAT = 116"])
        XCTAssertNil(run("100 usd"))
        XCTAssertNil(run("vat of 5 cats"))
    }

    func testSubtitleUsesLocaleSeparatorAndYearsAreNotRates() {
        var c = Settings(); c.decimalSeparator = ","; c.thousandsSeparator = "."
        XCTAssertEqual(run("100 vat 5,5%", c)?.first?.subtitle, "VAT of 5,5%")
        XCTAssertEqual(run("100 vat 2026")?.first?.valid, false)
        XCTAssertEqual(run("vat 100 5e2")?.first?.valid, true)
    }

    func testHugeRateIsRejected() {
        XCTAssertEqual(run("vat 100 at 999999%")?.first?.valid, false)
    }
}
