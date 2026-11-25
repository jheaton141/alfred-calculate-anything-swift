import XCTest
@testable import CalcCore

private final class Rates: RatesProviding {
    func fiatRates() async throws -> RateTable {
        RateTable(base: "USD", rates: ["EUR": 0.9, "GBP": 0.8, "ILS": 3.5, "BDT": 120], fetchedAt: Date(), source: "test")
    }
    func cryptoRates(symbols: [String]) async throws -> RateTable { throw RatesError.unavailable("none") }
}

final class DefaultConversionTests: XCTestCase {
    private func items(_ q: String) async -> [AlfredItem] {
        let ctx = Context(rates: Rates(), dataDir: URL(fileURLWithPath: NSTemporaryDirectory()))
        return await Engine(tools: DefaultEngine.tools()).run(q, context: ctx).items
    }
    private func run(_ q: String) async -> [String] { await items(q).map(\.title) }

    func testBareUnitShowsFewCommonConversions() async {
        let km = await run("10 km")
        XCTAssertEqual(km.count, 2)
        XCTAssertTrue(km[0].hasSuffix("mi"), "\(km)")
        let f = await run("100 f")
        XCTAssertEqual(f.first, "37.78 c")
        let cups = await run("5 cups")
        XCTAssertEqual(cups.count, 3)
        let lb = await run("1 lb")
        XCTAssertEqual(lb.count, 2)
        XCTAssertLessThanOrEqual(lb.count, 3)
    }

    func testOunceNamesBothReadings() async {
        let oz = await items("8 oz")
        XCTAssertEqual(oz.map(\.subtitle), ["Mass", "Volume"])
    }

    func testSuffixesAndUnlistedUnitsAreLeftAlone() async {
        let tenK = await run("10k"), tenM = await run("5M"), hand = await run("10 hand"), kelvin = await run("10 k")
        XCTAssertEqual(tenK, ["10,000"])
        XCTAssertEqual(tenM, ["5,000,000"])
        XCTAssertEqual(hand, [])
        XCTAssertEqual(kelvin, [])
    }

    func testPoundIsWeightUnlessAMoneyTargetIsGiven() async {
        let bare = await run("100 pounds")
        XCTAssertTrue(bare[0].hasSuffix("kg"), "\(bare)")
        let toKg = await run("100 pounds to kg")
        XCTAssertEqual(toKg, ["45.359237 kg"])
        let money = await items("100 pounds to usd")
        XCTAssertEqual(money.first?.title, "125 USD")
        let back = await run("100 usd to pounds")
        XCTAssertEqual(back, ["80 GBP"])
        let sterling = await run("100 pounds sterling to eur")
        XCTAssertEqual(sterling, ["112.5 EUR"])
        let sign = await run("£100 to usd")
        XCTAssertEqual(sign, ["125 USD"])
    }

    func testNewCurrencyNames() async {
        let a = await run("350 nis to usd"), b = await run("100 shekels to usd"), c = await run("1200 taka to usd")
        XCTAssertEqual(a, ["100 USD"])
        XCTAssertEqual(b, ["28.57 USD"])
        XCTAssertEqual(c, ["10 USD"])
    }

    func testNewton() async {
        let n = await run("1 newton to lbf")
        XCTAssertEqual(n, ["0.22480894 lbf"])
        let knot = await run("5 kn")
        XCTAssertTrue(knot[0].hasSuffix("kph"), "\(knot)")   // kn stays knots
    }
}

final class DefaultConversionEdgeTests: XCTestCase {
    private func items(_ q: String) async -> [AlfredItem] {
        let ctx = Context(dataDir: URL(fileURLWithPath: NSTemporaryDirectory()))
        return await Engine(tools: DefaultEngine.tools()).run(q, context: ctx).items
    }

    func testOutOfRangeGivesOneErrorRow() async {
        for q in ["-500 c", "-273.16 c", "1e308 km"] {
            let r = await items(q)
            XCTAssertEqual(r.count, 1, q)
            XCTAssertEqual(r.first?.valid, false, q)
        }
    }
}
