import XCTest
@testable import CalcCore

final class PercentageTests: XCTestCase {
    private func run(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? {
        miscBlockingEvaluate(PercentageTool(), q, s)
    }

    func testGoldenCases() {
        let cases = [("20% of 150", "30"), ("15% of 80", "12"), ("150 + 20%", "180"),
                     ("150 - 20%", "120"), ("100 + 15%", "115")]
        for (q, expected) in cases {
            let items = run(q)
            XCTAssertEqual(items?.map(\.title), [expected], q)
            XCTAssertEqual(items?.first?.arg, expected, q)
            XCTAssertEqual(items?.first?.mods?.cmd?.arg, expected, q)
        }
    }

    func testIsWhatPercent() {
        let items = run("50 is what % of 200")
        XCTAssertEqual(items?.map(\.title), [
            "50 is 25% of 200", "The percentage increase from 50 to 200 is 300%", "The percentage decrease from 200 to 50 is 75%"])
        XCTAssertEqual(items?.map { $0.mods?.cmd?.arg }, ["25", "300", "75"])
        // reversed: larger number first reads as decrease then increase
        XCTAssertEqual(run("200 is what % of 50")?.map(\.title), [
            "200 is 400% of 50", "The percentage increase from 50 to 200 is 300%", "The percentage decrease from 200 to 50 is 75%"])
        XCTAssertEqual(run("50 % 200")?.first?.title, "50 is 25% of 200")
        XCTAssertEqual(run("50 as a % of 200")?.first?.title, "50 is 25% of 200")
        XCTAssertEqual(run("5 is what % of 0")?.first?.valid, false)
    }

    func testNewPhrasings() {
        XCTAssertEqual(run("what is 20% of 150")?.map(\.title), ["30"])
        XCTAssertEqual(run("What's 20% of 150")?.map(\.title), ["30"])
        XCTAssertEqual(run("20 is 10% of what")?.map(\.title), ["200"])
        XCTAssertEqual(run("20% off 150")?.map(\.title), ["120"])
        XCTAssertEqual(run("150 plus 20%")?.map(\.title), ["180"])
        XCTAssertEqual(run("150 minus 20%")?.map(\.title), ["120"])
        XCTAssertEqual(run("150+20%")?.map(\.title), ["180"])
        XCTAssertEqual(run("0% of 5")?.map(\.title), ["0"])
        XCTAssertEqual(run("0.5% of 1000")?.map(\.title), ["5"])
        XCTAssertEqual(run("0.001% of 5")?.map(\.title), ["0.00005"])
        XCTAssertEqual(run("20 is 0% of what")?.first?.valid, false)
    }

    func testChange() {
        XCTAssertEqual(run("% change from 50 to 75")?.first?.title, "+50% (increase from 50 to 75)")
        XCTAssertEqual(run("10 to 30 % change")?.first?.title, "+200% (increase from 10 to 30)")
        XCTAssertEqual(run("200 to 150 % change")?.first?.title, "-25% (decrease from 200 to 150)")
        XCTAssertEqual(run("200 to 150 % change")?.first?.arg, "-25%")
        XCTAssertEqual(run("200 to 150 % change")?.first?.mods?.cmd?.arg, "-25")
        XCTAssertEqual(run("50 to 50 percent change")?.first?.title, "0% (no change from 50 to 50)")
        XCTAssertEqual(run("% change from 0 to 5")?.first?.valid, false)
    }

    func testCommaDecimal() {
        var s = Settings(); s.decimalSeparator = ","; s.thousandsSeparator = "."
        XCTAssertEqual(run("1.234,56 + 10%", s)?.map(\.title), ["1.358,02"])
        XCTAssertEqual(run("1.234,56 + 10%", s)?.first?.mods?.cmd?.arg, "1358.016")
        XCTAssertEqual(run("10,5% of 200", s)?.map(\.title), ["21"])
        XCTAssertEqual(run("1,234.56 + 10%")?.map(\.title), ["1,358.02"])
    }

    func testNotOurs() {
        for q in ["10 km to mi", "150 + 20", "10 + 5", "20 of 150", "hello", "100 vat", "10 gb to mb", "% of", "5%"] {
            let items = run(q)
            XCTAssertNil(items, q)
        }
    }
}
