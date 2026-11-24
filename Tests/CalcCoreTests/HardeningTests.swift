import XCTest
@testable import CalcCore

final class HardeningTests: XCTestCase {
    private func run(_ q: String, _ settings: Settings = Settings(), rates: RatesProviding? = nil) async -> [String] {
        let ctx = Context(settings: settings, rates: rates, dataDir: URL(fileURLWithPath: NSTemporaryDirectory()))
        return await Engine(tools: DefaultEngine.tools()).run(q, context: ctx).items.map(\.title)
    }

    func testTieRoundingIsHalfAwayFromZero() {
        XCTAssertEqual(NumberFormat.plain(1.005, decimals: 2), "1.01")
        XCTAssertEqual(NumberFormat.plain(2.675, decimals: 2), "2.68")
        XCTAssertEqual(NumberFormat.plain(0.125, decimals: 2), "0.13")
        XCTAssertEqual(NumberFormat.plain(2.5, decimals: 0), "3")
        XCTAssertEqual(NumberFormat.plain(-2.5, decimals: 0), "-3")
        XCTAssertEqual(NumberFormat.plain(1e300, decimals: 2).first, "1")
    }

    func testDecimalsClamped() {
        XCTAssertEqual(Settings(environment: ["decimals": "99999999999"]).decimals, 12)
        XCTAssertEqual(Settings(environment: ["decimals": "400"]).decimals, 12)
        XCTAssertEqual(Settings(environment: ["decimals": "-3"]).decimals, 0)
        XCTAssertEqual(NumberFormat.plain(1.0 / 3.0, decimals: 400), "0.333333333333")
    }

    func testParseDetectsSeparators() {
        let dot = Settings()
        var comma = Settings(); comma.decimalSeparator = ","; comma.thousandsSeparator = "."
        XCTAssertEqual(NumberFormat.parse("1.234,56", settings: dot), 1234.56)
        XCTAssertEqual(NumberFormat.parse("1,234.56", settings: comma), 1234.56)
        XCTAssertEqual(NumberFormat.parse("1.5", settings: comma), 1.5)
        XCTAssertEqual(NumberFormat.parse("1,5", settings: dot), 1.5)
        XCTAssertEqual(NumberFormat.parse("1,234", settings: dot), 1234)
        XCTAssertEqual(NumberFormat.parse("1.234", settings: comma), 1234)
        XCTAssertEqual(NumberFormat.parse("1,234,567", settings: dot), 1234567)
        XCTAssertNil(NumberFormat.parse("abc", settings: dot))
    }

    func testEngineDispatchModuloAndPercent() async {
        let mod = await run("10 % 3")
        XCTAssertEqual(mod, ["1"])
        let seven = await run("7%3")
        XCTAssertEqual(seven, ["1"])
        let pct = await run("50 is what % of 200")
        XCTAssertEqual(pct.first, "50 is 25% of 200")
        let of = await run("20% of 150")
        XCTAssertEqual(of, ["30"])
    }

    func testMathDepthCapDoesNotCrash() async {
        let deep = String(repeating: "(", count: 400) + "1" + String(repeating: ")", count: 400) + "+1"
        let r1 = await run(deep)
        XCTAssertTrue(r1.isEmpty)
        let r2 = await run(String(repeating: "-", count: 5000) + "1")
        XCTAssertTrue(r2.isEmpty)
        let r3 = await run(Array(repeating: "2", count: 2000).joined(separator: "^"))
        XCTAssertTrue(r3.isEmpty)
        let ok = await run(String(repeating: "(", count: 50) + "1" + String(repeating: ")", count: 50) + "+1")
        XCTAssertEqual(ok, ["2"])
    }

    func testTrailingSNoLongerFabricatesUnits() async {
        let r = await run("5 ds to s")
        XCTAssertTrue(r.isEmpty)
        let ok = await run("2 hrs to min")
        XCTAssertEqual(ok, ["120 minutes"])
    }

    func testRateTableRejectsBadRates() {
        let t = RateTable(base: "USD", rates: ["EUR": 0, "GBP": -1, "JPY": 1e308, "CAD": 2], fetchedAt: Date(), source: "t")
        XCTAssertNil(t.convert(100, from: "USD", to: "EUR"))
        XCTAssertNil(t.convert(100, from: "USD", to: "GBP"))
        XCTAssertNil(t.convert(1e308, from: "USD", to: "JPY"))
        XCTAssertEqual(t.convert(10, from: "USD", to: "CAD"), 20)
    }

    func testFutureDatedAndCorruptCacheNotTrusted() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let future = #"{"base":"USD","rates":{"EUR":0.5,"USD":1,"BAD":-2},"fetchedAt":"2099-01-01T00:00:00Z","source":"x","stale":false}"#
        try future.write(to: dir.appendingPathComponent("rates-fiat.json"), atomically: true, encoding: .utf8)
        struct Dead: HTTPFetching { func get(_ url: URL) async throws -> Data { throw URLError(.notConnectedToInternet) } }
        let svc = RatesService(dataDir: dir, settings: Settings(), http: Dead())
        let t = try await svc.fiatRates()
        XCTAssertTrue(t.stale, "future-dated cache must not count as fresh")
        XCTAssertNil(t.rates["BAD"])
        XCTAssertEqual(t.rates["EUR"], 0.5)
    }

    func testPartialCryptoRefreshStaysStale() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let old = #"{"base":"USD","rates":{"BTC":0.00002,"ETH":0.0005},"fetchedAt":"2020-01-01T00:00:00Z","source":"x","stale":false}"#
        try old.write(to: dir.appendingPathComponent("rates-crypto.json"), atomically: true, encoding: .utf8)
        struct OnlyBTC: HTTPFetching {
            func get(_ url: URL) async throws -> Data {
                if url.absoluteString.contains("coingecko") { return Data(#"{"bitcoin":{"usd":50000}}"#.utf8) }
                throw URLError(.notConnectedToInternet)
            }
        }
        let svc = RatesService(dataDir: dir, settings: Settings(), http: OnlyBTC())
        let t = try await svc.cryptoRates(symbols: ["BTC"])
        XCTAssertEqual(t.rates["BTC"] ?? 0, 1.0 / 50000, accuracy: 1e-12)
        XCTAssertEqual(t.rates["ETH"], 0.0005)
        XCTAssertTrue(t.stale)
        XCTAssertLessThan(t.fetchedAt.timeIntervalSince1970, 1_600_000_000)
    }
}

final class SettingsCompatTests: XCTestCase {
    func testUpstreamVariableNamesStillRead() {
        let s = Settings(environment: ["vat_value": "20", "pixels_base": "10"])
        XCTAssertEqual(s.vatPercentage, 20)
        XCTAssertEqual(s.basePixels, 10)
    }
}
