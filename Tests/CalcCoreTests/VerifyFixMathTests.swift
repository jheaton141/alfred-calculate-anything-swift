import XCTest
@testable import CalcCore

final class VerifyFixMathTests: XCTestCase {
    private func math(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? { miscBlockingEvaluate(MathTool(), q, s) }
    private func pct(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? { miscBlockingEvaluate(PercentageTool(), q, s) }
    private func vat(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? { miscBlockingEvaluate(VatTool(), q, s) }

    func testPercentInsideLongerExpression() {
        XCTAssertEqual(math("200 + 10% + 5")?.first?.title, "225")
        XCTAssertEqual(math("200 - 10% - 5")?.first?.title, "175")
        XCTAssertEqual(math("200 + 10%")?.first?.title, "220")
        XCTAssertEqual(math("150 + 20%")?.first?.title, "180")
        XCTAssertEqual(math("(200 + 10%) * 2")?.first?.title, "440")
        XCTAssertEqual(math("10 % 3")?.first?.title, "1")
        XCTAssertEqual(math("200 + 10 % 3")?.first?.title, "201")
        XCTAssertEqual(math("10 % 3 + 1")?.first?.title, "2")
    }

    func testMalformedSeparatorsRejected() {
        let s = Settings()
        for t in ["0.1.2", "1..2", "1,,2", "1,2,3", "1,234.5.6", "1.2,3,4", "12,34,567", "1,23.4"] {
            XCTAssertNil(NumberFormat.parse(t, settings: s), t)
        }
        for q in ["0.1.2+1", "1..2+1", "1,,2+1", "1,2,3+1"] { XCTAssertNil(math(q), q) }
        XCTAssertEqual(NumberFormat.parse("1,234.56", settings: s), 1234.56)
        XCTAssertEqual(NumberFormat.parse("1.234,56", settings: s), 1234.56)
        XCTAssertEqual(NumberFormat.parse("1,234", settings: s), 1234)
        XCTAssertEqual(NumberFormat.parse("1.234", settings: s), 1.234)
        XCTAssertEqual(NumberFormat.parse("1,234,567.5", settings: s), 1234567.5)
        XCTAssertEqual(NumberFormat.parse("-200", settings: s), -200)
        XCTAssertEqual(NumberFormat.parse(".5", settings: s), 0.5)
    }

    func testTinyValuesGoScientific() {
        XCTAssertEqual(math("3 / 10^9")?.first?.title, "3e-09")
        XCTAssertEqual(math("1 / 10^9")?.first?.title, "1e-09")
        XCTAssertEqual(math("1 / 10^8")?.first?.title, "0.00000001")
    }

    func testDecimalsZeroIsConsistent() {
        var s = Settings(); s.decimals = 0
        XCTAssertEqual(math("2/3", s)?.first?.title, "1")
        XCTAssertEqual(math("1/3", s)?.first?.title, "0")
        XCTAssertEqual(vat("vat 0.4", s)?.first?.title, "VAT of 0 = 0")
        XCTAssertEqual(math("1/300").flatMap { $0.first?.title }, "0.00333333")
    }

    func testExponentCorrectlyRounded() {
        XCTAssertEqual(math("3e-4 - 0.0003")?.first?.title, "0")
        XCTAssertEqual(math("30 % 3e-4")?.first?.title, "0")
        XCTAssertEqual(NumberFormat.parse("3e-4", settings: Settings()), 0.0003)
    }

    func testFloatNoiseAtTwelveDecimals() {
        XCTAssertEqual(NumberFormat.plain(-6995.039999999999, decimals: 12), "-6995.04")
        var s = Settings(); s.decimals = 12
        XCTAssertEqual(math("-6995.039999999999 + 0", s)?.first?.title, "-6,995.04")
    }

    func testIsWhatPercentNegativeBase() {
        let t = pct("50 is what % of -200")?.map(\.title)
        XCTAssertEqual(t?.count, 3)
        XCTAssertTrue(t?[0].contains("-25%") == true, t?[0] ?? "")
        XCTAssertTrue(t?[1].contains("is 125%") == true, t?[1] ?? "")
        XCTAssertTrue(t?[2].contains("is 500%") == true, t?[2] ?? "")
        let u = pct("-50 is what % of -200")?.map(\.title)
        XCTAssertTrue(u?[0].contains("25%") == true && u?[0].contains("-25%") == false, u?[0] ?? "")
        XCTAssertTrue(u?[1].contains("is 75%") == true, u?[1] ?? "")
    }

    func testNonFiniteAndHugeValues() {
        let err = pct("1e300 % of 1e300")
        XCTAssertEqual(err?.count, 1)
        XCTAssertFalse(err?.first?.title.contains("inf") == true)
        XCTAssertEqual(err?.first?.valid, false)
        let big = pct("1e200 + 1e200%")?.first?.title ?? ""
        XCTAssertLessThan(big.count, 40, big)
        XCTAssertEqual(pct("50% of 1e300")?.first?.title, "5e+299")
        let tiny = pct("50% of 1e-20")?.first?.title ?? ""
        XCTAssertEqual(tiny, "5e-21")
        XCTAssertFalse((vat("vat 1e300")?.first?.title ?? "").count > 60)
        var huge = Settings(); huge.vatPercentage = 1e10
        let over = vat("vat 1e305", huge)
        XCTAssertEqual(over?.count, 1)
        XCTAssertEqual(over?.first?.valid, false)
    }

    func testVatSettingsValidated() {
        for bad in ["inf", "nan", "1e400", "-100", "-500", "abc", ""] {
            XCTAssertEqual(Settings(environment: ["vat_percentage": bad]).vatPercentage, 16, bad)
        }
        XCTAssertEqual(Settings(environment: ["vat_percentage": "20%"]).vatPercentage, 20)
        XCTAssertEqual(Settings(environment: ["vat_percentage": " 20 "]).vatPercentage, 20)
        XCTAssertEqual(Settings(environment: ["vat_percentage": "-50"]).vatPercentage, -50)
        var s = Settings(); s.vatPercentage = .infinity
        XCTAssertEqual(vat("vat 100", s)?.first?.title, "VAT of 100 = 16")
    }

    func testVatTinyAmountConsistent() {
        let t = vat("vat 0.005")?.map(\.title)
        XCTAssertEqual(t?.first, "VAT of 0.005 = 0.0008")
        XCTAssertEqual(t?[1], "0.005 plus VAT = 0.0058")
    }

    func testPercentWords() {
        XCTAssertEqual(pct("20 percent of 150")?.first?.title, "30")
        XCTAssertEqual(pct("20 percent off 150")?.first?.title, "120")
        XCTAssertEqual(pct("150 plus 20 percent")?.first?.title, "180")
        XCTAssertEqual(pct("150 minus 20 percent")?.first?.title, "120")
        XCTAssertEqual(pct("-20% of 150")?.first?.title, "-30")
        XCTAssertEqual(pct("150 + -20%")?.first?.title, "120")
        XCTAssertEqual(pct("150 - -20%")?.first?.title, "180")
        XCTAssertEqual(pct("-20 percent of 150")?.first?.title, "-30")
        XCTAssertNotNil(pct("percent change from 50 to 75"))
        XCTAssertNotNil(pct("50 is what percent of 200"))
    }

    func testLongQueriesAreFast() {
        for n in [300, 1200] {
            let q = String(repeating: "10 is what % of ", count: n)
            for tool in DefaultEngine.tools() where ["math", "percentage", "vat"].contains(tool.name) {
                let t0 = Date()
                _ = miscBlockingEvaluate(tool, q, Settings())
                XCTAssertLessThan(Date().timeIntervalSince(t0), 0.05, "\(tool.name) \(n)")
            }
        }
    }
}
