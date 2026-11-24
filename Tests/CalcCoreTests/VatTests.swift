import XCTest
@testable import CalcCore

final class VatTests: XCTestCase {
    private func run(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? {
        miscBlockingEvaluate(VatTool(), q, s)
    }

    func testGoldenHundred() {
        for q in ["vat 100", "100 vat", "vat 100 vat"] {
            let items = run(q)
            XCTAssertEqual(items?.map(\.title), ["VAT of 100 = 16", "100 plus VAT = 116", "100 minus VAT = 86.21"], q)
        }
        let items = run("vat 100")
        XCTAssertEqual(items?.map(\.subtitle), ["VAT of 16%", "VAT of 16%", "100 minus 16% of VAT"])
        XCTAssertEqual(items?.map(\.arg), ["16", "116", "86.21"])
        XCTAssertEqual(items?[2].mods?.cmd?.arg, "86.2068965517")
    }

    func testRoundingFixed() {
        let items = run("121 vat")
        XCTAssertEqual(items?.map(\.title), ["VAT of 121 = 19.36", "121 plus VAT = 140.36", "121 minus VAT = 104.31"])
        XCTAssertEqual(run("vat 200 -vat")?.map(\.title), ["VAT of 200 = 32", "200 plus VAT = 232", "200 minus VAT = 172.41"])
        XCTAssertEqual(run("vat 121 with vat")?.count, 3)
    }

    func testSingleRowDirections() {
        XCTAssertEqual(run("100 + vat")?.map(\.title), ["100 plus VAT = 116"])
        XCTAssertEqual(run("100 plus vat")?.map(\.title), ["100 plus VAT = 116"])
        XCTAssertEqual(run("121 - vat")?.map(\.title), ["121 minus VAT = 104.31"])
        XCTAssertEqual(run("121 without vat")?.map(\.title), ["121 minus VAT = 104.31"])
    }

    func testOtherRateAndSeparators() {
        var s = Settings(); s.vatPercentage = 20
        XCTAssertEqual(run("vat 1,200", s)?.map(\.title), ["VAT of 1,200 = 240", "1,200 plus VAT = 1,440", "1,200 minus VAT = 1,000"])
        s.decimalSeparator = ","; s.thousandsSeparator = "."
        XCTAssertEqual(run("vat 10,5", s)?.first?.title, "VAT of 10,5 = 2,1")
    }

    func testEmptyAndNotOurs() {
        let hint = run("vat")
        XCTAssertEqual(hint?.first?.valid, false)
        XCTAssertEqual(run("vat 0")?.first?.valid, false)
        for q in ["10 km to mi", "100", "vat abc", "hello vat", "20% of 150"] {
            let items = run(q)
            XCTAssertNil(items, q)
        }
    }
}
