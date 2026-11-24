import XCTest
@testable import CalcCore

private final class FakeRates: RatesProviding {
    var fiat: RateTable
    var crypto: RateTable
    var fail = false
    var fiatCalls = 0
    var cryptoCalls = 0
    init(stale: Bool = false) {
        let t = Date(timeIntervalSince1970: 1_763_600_000) // 2025-11-20 UTC
        let f: [String: Double] = ["EUR": 0.9234, "GBP": 0.8, "JPY": 150.0, "CNY": 7.2]
        let c: [String: Double] = ["BTC": 0.00002, "ETH": 0.0004, "DOGE": 10.0]
        fiat = RateTable(base: "USD", rates: f, fetchedAt: t, source: "fake", stale: stale)
        crypto = RateTable(base: "USD", rates: c, fetchedAt: t, source: "fake", stale: stale)
    }
    func fiatRates() async throws -> RateTable {
        fiatCalls += 1
        if fail { throw RatesError.unavailable("offline") }
        return fiat
    }
    func cryptoRates(symbols: [String]) async throws -> RateTable {
        cryptoCalls += 1
        if fail { throw RatesError.unavailable("offline") }
        return crypto
    }
}

final class CurrencyTests: XCTestCase {
    private func settings(comma: Bool = false, base: String = "USD") -> Settings {
        var s = Settings()
        s.baseCurrency = base
        if comma { s.decimalSeparator = ","; s.thousandsSeparator = "." }
        return s
    }
    private func items(_ tool: Tool, _ q: String, _ rates: FakeRates, _ s: Settings) async -> [AlfredItem]? {
        await tool.evaluate(q, context: Context(settings: s, rates: rates, dataDir: URL(fileURLWithPath: "/tmp")))
    }
    private func fiat(_ q: String, rates: FakeRates = FakeRates(), s: Settings = Settings()) async -> [AlfredItem]? {
        await items(CurrencyTool(), q, rates, s)
    }
    private func crypto(_ q: String, rates: FakeRates = FakeRates(), s: Settings = Settings()) async -> [AlfredItem]? {
        await items(CryptoTool(), q, rates, s)
    }
    private func titles(_ r: [AlfredItem]?) -> [String] { (r ?? []).map { $0.title } }

    func testSingleConversionFormat() async {
        let r = await fiat("100 usd to eur")
        XCTAssertEqual(titles(r), ["92.34 EUR"])
        XCTAssertEqual(r?[0].subtitle, "1 USD = 0.9234 EUR")
        XCTAssertEqual(r?[0].arg, "92.34")
        XCTAssertEqual(r?[0].mods?.cmd?.arg, "92.34")
        XCTAssertEqual(r?[0].mods?.alt?.arg, "92.34 EUR")
    }

    func testQueryShapes() async {
        let qs = ["100usd eur", "usd 100 to eur", "100 USD in EUR", "100 us dollars to euro", "100 bucks to eur", "$100 to €", "100$ = eur"]
        for q in qs {
            let r = await fiat(q)
            XCTAssertEqual(titles(r), ["92.34 EUR"], q)
        }
        let rmb = await fiat("72 rmb to usd")
        XCTAssertEqual(titles(rmb), ["10 USD"])
    }

    func testMultipleTargets() async {
        let r = await fiat("100 usd in eur, gbp, jpy")
        XCTAssertEqual(titles(r), ["92.34 EUR", "80 GBP", "15,000 JPY"])
    }

    func testSymbols() async {
        let a = await fiat("€100 to $")
        XCTAssertEqual(titles(a), ["108.3 USD"])
        let b = await fiat("£80 to usd")
        XCTAssertEqual(titles(b), ["100 USD"])
        let c = await fiat("¥1500 to usd")
        XCTAssertEqual(titles(c), ["10 USD"])
    }

    func testSuffixes() async {
        let a = await fiat("10M eur in usd")
        XCTAssertEqual(titles(a), ["10,829,542.99 USD"])
        let b = await fiat("2.5k usd to eur")
        XCTAssertEqual(titles(b), ["2,308.5 EUR"])
        let c = await fiat("1b jpy to usd")
        XCTAssertEqual(titles(c), ["6,666,666.67 USD"])
    }

    func testEuropeanNumberFormat() async {
        let r = await fiat("1.234,56 eur to usd", s: settings(comma: true))
        XCTAssertEqual(titles(r), ["1.336,97 USD"])
    }

    func testBareAmountUsesBaseCurrencies() async {
        let one = await fiat("100 eur")
        XCTAssertEqual(titles(one), ["108.3 USD"])
        let two = await fiat("100 eur", s: settings(base: "USD,GBP"))
        XCTAssertEqual(titles(two), ["108.3 USD", "86.64 GBP"])
        let none = await fiat("100 usd")
        XCTAssertNil(none)
    }

    func testUnknownReturnsNil() async {
        let qs = ["10 m to ft", "100 xyz to eur", "100 usd to ft", "100 aud to eur", "10 min to sec", "usd to eur", "hello", "5 cup", "100 usd to"]
        for q in qs {
            let r = await fiat(q)
            XCTAssertNil(r, q)
        }
    }

    func testNoProviderReturnsNil() async {
        let r = await CurrencyTool().evaluate("100 usd to eur", context: Context(dataDir: URL(fileURLWithPath: "/tmp")))
        XCTAssertNil(r)
    }

    func testStaleSubtitle() async {
        let r = await fiat("100 usd to eur", rates: FakeRates(stale: true))
        XCTAssertEqual(titles(r), ["92.34 EUR"])
        XCTAssertEqual(r?[0].subtitle, "1 USD = 0.9234 EUR (cached rates from 2025-11-20)")
    }

    func testProviderErrorRow() async {
        let rates = FakeRates()
        rates.fail = true
        let r = await fiat("100 usd to eur", rates: rates)
        XCTAssertEqual(r?.count, 1)
        XCTAssertEqual(r?[0].valid, false)
        XCTAssertEqual(r?[0].title, "Exchange rates unavailable")
        let other = await fiat("10 min to sec", rates: rates)
        XCTAssertNil(other)
    }

    func testCryptoToFiat() async {
        let a = await crypto("1 btc to usd")
        XCTAssertEqual(titles(a), ["50,000 USD"])
        XCTAssertEqual(a?[0].subtitle, "1 BTC = 50,000 USD")
        let b = await crypto("0.5 eth in eur")
        XCTAssertEqual(titles(b), ["1,154.25 EUR"])
        let c = await crypto("1 bitcoin to gbp")
        XCTAssertEqual(titles(c), ["40,000 GBP"])
    }

    func testFiatToCryptoAndProviderCalls() async {
        let a = await crypto("100 usd to btc")
        XCTAssertEqual(titles(a), ["0.002 BTC"])
        let rates = FakeRates()
        _ = await crypto("0.5 eth in eur", rates: rates)
        XCTAssertEqual(rates.cryptoCalls, 1)
        XCTAssertEqual(rates.fiatCalls, 1)
    }

    func testCryptoToCrypto() async {
        let a = await crypto("1000 doge btc")
        XCTAssertEqual(titles(a), ["0.002 BTC"])
        let rates = FakeRates()
        let b = await crypto("1 btc to eth, doge", rates: rates)
        XCTAssertEqual(titles(b), ["20 ETH", "500,000 DOGE"])
        XCTAssertEqual(rates.fiatCalls, 0)
    }

    func testBareCoinShowsBasePrice() async {
        let a = await crypto("btc")
        XCTAssertEqual(titles(a), ["50,000 USD"])
        let b = await crypto("eth", s: settings(base: "EUR"))
        XCTAssertEqual(titles(b), ["2,308.5 EUR"])
    }

    func testCryptoLeavesFiatAlone() async {
        for q in ["100 usd to eur", "100 eur", "10 m to ft", "100 usd in eur, gbp", "hello"] {
            let r = await crypto(q)
            XCTAssertNil(r, q)
        }
    }

    func testCryptoErrorRow() async {
        let rates = FakeRates()
        rates.fail = true
        let r = await crypto("1 btc to usd", rates: rates)
        XCTAssertEqual(r?.first?.valid, false)
    }
}
