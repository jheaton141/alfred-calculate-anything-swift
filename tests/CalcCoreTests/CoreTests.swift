import XCTest
@testable import CalcCore

final class CoreTests: XCTestCase {
    func testNumberDisplay() {
        let s = Settings()
        XCTAssertEqual(NumberFormat.display(31536000, settings: s), "31,536,000")
        XCTAssertEqual(NumberFormat.display(1.5, settings: s), "1.5")
        XCTAssertEqual(NumberFormat.display(-1234.567, settings: s), "-1,234.57")
        var eu = Settings(); eu.decimalSeparator = ","; eu.thousandsSeparator = "."
        XCTAssertEqual(NumberFormat.display(1234.56, settings: eu), "1.234,56")
        XCTAssertEqual(NumberFormat.parse("1.234,56", settings: eu), 1234.56)
    }

    func testRateConvert() {
        let t = RateTable(base: "EUR", rates: ["USD": 2, "GBP": 0.5], fetchedAt: Date(), source: "test")
        XCTAssertEqual(t.convert(10, from: "usd", to: "gbp"), 2.5)
        XCTAssertEqual(t.convert(10, from: "EUR", to: "USD"), 20)
        XCTAssertNil(t.convert(1, from: "XXX", to: "USD"))
    }

    func testEngineFirstNonNilWins() async {
        struct No: Tool { let name = "no"; func evaluate(_ q: String, context: Context) async -> [AlfredItem]? { nil } }
        struct Yes: Tool { let name = "yes"; func evaluate(_ q: String, context: Context) async -> [AlfredItem]? { [AlfredItem(title: q)] } }
        let ctx = Context(dataDir: URL(fileURLWithPath: NSTemporaryDirectory()))
        let out = await Engine(tools: [No(), Yes()]).run("  hi ", context: ctx)
        XCTAssertEqual(out.items.map(\.title), ["hi"])
        let empty = await Engine(tools: [Yes()]).run("   ", context: ctx)
        XCTAssertTrue(empty.items.isEmpty)
    }

    func testAlfredJSONShape() throws {
        let item = AlfredItem.value(title: "6.21 mi", copy: "6.21", raw: "6.21", withUnit: "6.21 mi")
        let data = AlfredOutput(items: [item]).json().data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let first = (obj["items"] as! [[String: Any]])[0]
        XCTAssertEqual(first["title"] as? String, "6.21 mi")
        XCTAssertNotNil((first["mods"] as? [String: Any])?["cmd"])
    }
}
