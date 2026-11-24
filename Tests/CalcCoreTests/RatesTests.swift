import XCTest
@testable import CalcCore

fileprivate final class FakeHTTP: HTTPFetching {
    var routes: [String: Data] = [:]
    var calls: [String] = []
    func get(_ url: URL) async throws -> Data {
        calls.append(url.absoluteString)
        for (prefix, data) in routes where url.absoluteString.hasPrefix(prefix) { return data }
        throw URLError(.notConnectedToInternet)
    }
}

fileprivate final class Clock { var t = Date(timeIntervalSince1970: 1_800_000_000) }

final class RatesTests: XCTestCase {
    let fxURL = "https://api.frankfurter.dev/v1/latest"
    let fawazURL = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"
    let fawazMirror = "https://latest.currency-api.pages.dev/v1/currencies/usd.json"
    let geckoURL = "https://api.coingecko.com/api/v3/simple/price"
    let cbBTC = "https://api.coinbase.com/v2/prices/BTC-USD/spot"
    let cbETH = "https://api.coinbase.com/v2/prices/ETH-USD/spot"

    var dir: URL!
    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("rates-\(UUID().uuidString)/nested")
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }

    func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
    }

    fileprivate func make(_ http: FakeHTTP, _ clock: Clock, hours: Double = 6, minutes: Double = 5) -> RatesService {
        var s = Settings(); s.fiatCacheHours = hours; s.cryptoCacheMinutes = minutes
        return RatesService(dataDir: dir, settings: s, http: http, now: { clock.t })
    }

    fileprivate func fiatHTTP() throws -> FakeHTTP {
        let h = FakeHTTP()
        h.routes[fxURL] = try fixture("rates-frankfurter")
        h.routes[fawazURL] = try fixture("rates-fawaz")
        return h
    }

    func testMergeFrankfurterWinsAndFawazFillsGaps() async throws {
        let t = try await make(fiatHTTP(), Clock()).fiatRates()
        XCTAssertEqual(t.base, "USD")
        XCTAssertEqual(t.rates["EUR"], 0.9)          // Frankfurter wins
        XCTAssertEqual(t.rates["AED"], 3.6725)       // only in fawaz
        XCTAssertEqual(t.rates["USD"], 1)
        XCTAssertNil(t.rates["BTC"])                 // crypto tickers excluded
        XCTAssertNil(t.rates["ZZZZ9"]); XCTAssertNil(t.rates["AB"])
        XCTAssertNil(t.rates["XAUU"])                // 4 letters excluded
        XCTAssertEqual(try XCTUnwrap(t.convert(10, from: "AED", to: "EUR")), 10 / 3.6725 * 0.9, accuracy: 1e-9)
        XCTAssertFalse(t.stale)
    }

    func testFreshCacheMakesNoHTTPCalls() async throws {
        let h = try fiatHTTP(), c = Clock()
        _ = try await make(h, c).fiatRates()
        let n = h.calls.count
        c.t += 5 * 3600
        let t = try await make(h, c).fiatRates()
        XCTAssertEqual(h.calls.count, n)
        XCTAssertEqual(t.rates["EUR"], 0.9)
    }

    func testExpiredCacheRefetches() async throws {
        let h = try fiatHTTP(), c = Clock()
        _ = try await make(h, c).fiatRates()
        let n = h.calls.count
        h.routes[fxURL] = Data(#"{"base":"USD","date":"x","rates":{"EUR":0.5}}"#.utf8)
        c.t += 7 * 3600
        let t = try await make(h, c).fiatRates()
        XCTAssertGreaterThan(h.calls.count, n)
        XCTAssertEqual(t.rates["EUR"], 0.5)
    }

    func testFrankfurterFailureUsesFawazAndMirror() async throws {
        let h = FakeHTTP()
        h.routes[fawazMirror] = try fixture("rates-fawaz")   // CDN down, mirror up
        let t = try await make(h, Clock()).fiatRates()
        XCTAssertEqual(t.rates["EUR"], 0.95)
        XCTAssertEqual(t.source, "fawazahmed0")
        XCTAssertTrue(h.calls.contains { $0.hasPrefix(fawazMirror) })
    }

    func testAllFailReturnsStaleCache() async throws {
        let h = try fiatHTTP(), c = Clock()
        _ = try await make(h, c).fiatRates()
        h.routes = [:]
        c.t += 100 * 3600
        let t = try await make(h, c).fiatRates()
        XCTAssertTrue(t.stale)
        XCTAssertEqual(t.rates["EUR"], 0.9)
    }

    func testAllFailWithoutCacheThrows() async {
        do { _ = try await make(FakeHTTP(), Clock()).fiatRates(); XCTFail("expected throw") }
        catch { guard case RatesError.unavailable = error else { return XCTFail("\(error)") } }
        do { _ = try await make(FakeHTTP(), Clock()).cryptoRates(symbols: ["BTC"]); XCTFail("expected throw") }
        catch { guard case RatesError.unavailable = error else { return XCTFail("\(error)") } }
    }

    func testCacheFileWrittenAtomicallyAndDecodable() async throws {
        _ = try await make(fiatHTTP(), Clock()).fiatRates()
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertEqual(files, ["rates-fiat.json"])   // no temp leftovers
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("rates-fiat.json"))) as? [String: Any]
        XCTAssertEqual(obj?["base"] as? String, "USD")
    }

    func testCryptoCoinGeckoInvertsPrice() async throws {
        let h = FakeHTTP(); h.routes[geckoURL] = try fixture("rates-coingecko")
        let t = try await make(h, Clock()).cryptoRates(symbols: ["btc", "ETH"])
        XCTAssertEqual(try XCTUnwrap(t.rates["BTC"]), 1.0 / 50000, accuracy: 1e-15)
        XCTAssertEqual(try XCTUnwrap(t.convert(1, from: "BTC", to: "USD")), 50000, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(t.convert(1, from: "ETH", to: "BTC")), 0.05, accuracy: 1e-12)
        XCTAssertEqual(h.calls.count, 1)
        XCTAssertTrue(h.calls[0].contains("ids=bitcoin,ethereum"))
    }

    func testCryptoCoinbaseFallback() async throws {
        let h = FakeHTTP()
        h.routes[cbBTC] = try fixture("rates-coinbase-btc"); h.routes[cbETH] = try fixture("rates-coinbase-eth")
        let t = try await make(h, Clock()).cryptoRates(symbols: ["BTC", "ETH"])
        XCTAssertEqual(t.source, "coinbase")
        XCTAssertEqual(try XCTUnwrap(t.convert(1, from: "BTC", to: "USD")), 40000, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(t.convert(1, from: "ETH", to: "USD")), 2000.5, accuracy: 1e-6)
    }

    func testCryptoCacheMergesSymbolsAndHonoursTTL() async throws {
        let h = FakeHTTP(), c = Clock()
        h.routes[geckoURL] = Data(#"{"bitcoin":{"usd":50000}}"#.utf8)
        _ = try await make(h, c).cryptoRates(symbols: ["BTC"])
        _ = try await make(h, c).cryptoRates(symbols: ["BTC"])
        XCTAssertEqual(h.calls.count, 1)                 // fresh hit
        h.routes[geckoURL] = Data(#"{"ethereum":{"usd":2500}}"#.utf8)
        let t = try await make(h, c).cryptoRates(symbols: ["ETH"])
        XCTAssertEqual(h.calls.count, 2)                 // missing symbol fetched
        XCTAssertNotNil(t.rates["BTC"]); XCTAssertNotNil(t.rates["ETH"])
        h.routes[geckoURL] = Data(#"{"bitcoin":{"usd":100000},"ethereum":{"usd":5000}}"#.utf8)
        c.t += 6 * 60
        let t2 = try await make(h, c).cryptoRates(symbols: ["ETH"])
        XCTAssertEqual(try XCTUnwrap(t2.convert(1, from: "BTC", to: "USD")), 100000, accuracy: 1e-6)
        h.routes = [:]
        c.t += 3600
        let t3 = try await make(h, c).cryptoRates(symbols: ["ETH"])
        XCTAssertTrue(t3.stale)
    }

    func testLiveSmoke() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_LIVE"] == "1", "set RUN_LIVE=1")
        let s = RatesService(dataDir: dir, settings: Settings())
        let fiat = try await s.fiatRates()
        let eur = try XCTUnwrap(fiat.rates["EUR"])
        let crypto = try await s.cryptoRates(symbols: ["BTC", "ETH"])
        let btc = try XCTUnwrap(crypto.convert(1, from: "BTC", to: "USD"))
        print("LIVE USD->EUR=\(eur) source=\(fiat.source) codes=\(fiat.rates.count) BTC=\(btc) src=\(crypto.source)")
        XCTAssertTrue(eur > 0.3 && eur < 3)
        XCTAssertTrue(btc > 1000)
    }
}
