import XCTest
@testable import CalcCore

private func blocking(_ tool: Tool, _ q: String, _ s: Settings = Settings(), now: TimeInterval = 1_795_447_845) -> [AlfredItem]? {
    final class Box: @unchecked Sendable { var value: [AlfredItem]? }
    let box = Box(), done = DispatchSemaphore(value: 0)
    let ctx = Context(settings: s, now: Date(timeIntervalSince1970: now), dataDir: URL(fileURLWithPath: "/tmp"))
    Task.detached { box.value = await tool.evaluate(q, context: ctx); done.signal() }
    done.wait()
    return box.value
}

/// "now" is Monday 2026-11-23 in New York.
final class DateArithmeticTests: XCTestCase {
    private func run(_ q: String) -> [AlfredItem]? { blocking(TimeTool(options: TimeOptions(zone: TimeZone(identifier: "America/New_York")!)), q) }

    func testWeekdayDayOfYearAndWeek() {
        XCTAssertEqual(run("time weekday of 2027-03-14")?.map(\.title), ["Sunday", "Day 73 / 365", "Week 10"])
        XCTAssertEqual(run("what day is 2026-12-25")?.first?.title, "Friday")
        XCTAssertEqual(run("time day of the year of 2026-12-25")?.first?.title, "Day 359 / 365")
        XCTAssertEqual(run("time day of the year of 2028-12-31")?.first?.title, "Day 366 / 366")
        XCTAssertEqual(run("time week number of 2026-12-25")?.first?.title, "Week 52")
        XCTAssertEqual(run("time what day is it")?.first?.title, "Monday")
        XCTAssertEqual(run("time weekday of 2027-03-14")?.first?.mods?.cmd?.arg, "Sunday")
    }

    func testAfterBeforeAndIn() {
        XCTAssertTrue(run("time 10 days after 2026-12-25")?.first?.title.hasPrefix("January 4th, 2027") == true)
        XCTAssertTrue(run("time 2 weeks before 2026-12-25")?.first?.title.hasPrefix("December 11th, 2026") == true)
        XCTAssertEqual(run("time 3pm in 5 days")?.first?.title, "November 28th, 2026, 3:00:00 pm")
        XCTAssertTrue(run("time 5 business days after 2026-12-25")?.first?.title.hasPrefix("January 1st, 2027") == true)
        XCTAssertEqual(run("time 3pm in Narnia")?.first?.title, "Unknown time zone")
        XCTAssertTrue(run("time 3pm in Tokyo")?.first?.title.contains("JST") == true)
        XCTAssertEqual(run("time 10 days after nonsense")?.first?.valid, false)
    }

    func testBusinessDays() {
        XCTAssertEqual(run("time business days between 2026-11-01 and 2026-11-30")?.first?.title, "21 days")
        XCTAssertEqual(run("time business days until 2026-11-30")?.first?.title, "5 days")
        XCTAssertEqual(run("time business days since 2026-11-16")?.first?.title, "5 days")
        XCTAssertEqual(run("time business days until 2026-11-16")?.first?.title, "5 days ago")
        XCTAssertEqual(run("time working days until 2026-11-23")?.first?.title, "0 days")
        XCTAssertEqual(run("time business days since 2026-11-29")?.first?.title, "4 days")
        XCTAssertEqual(run("time business days until 9999-12-31")?.first?.valid, true)
        XCTAssertEqual(run("time business days between 2024-02-26 and 2024-03-04")?.first?.title, "5 days")
        XCTAssertEqual(run("time business days between 1969-12-29 and 1970-01-05")?.first?.title, "5 days")
        XCTAssertEqual(run("time business days until 2026-11-30")?.first?.mods?.cmd?.arg, "5")
    }
}

final class CompoundUnitTests: XCTestCase {
    private func run(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? { blocking(UnitsTool(), q, s) }

    func testCompoundAmounts() {
        XCTAssertEqual(run("5 ft 3 in to cm")?.first?.title, "160.02 cm")
        XCTAssertEqual(run("5ft 3in to cm")?.first?.title, "160.02 cm")
        XCTAssertEqual(run("5'11\" to cm")?.first?.title, "180.34 cm")
        XCTAssertEqual(run("1h 30m to minutes")?.first?.title, "90 minutes")
        XCTAssertEqual(run("2 min 30 s to s")?.first?.title, "150 seconds")
        XCTAssertEqual(run("1 km 500 m to mi")?.first?.title, "0.93205679 mi")
        XCTAssertEqual(run("2 lb 4 oz to kg")?.first?.title, "1.02058283 kg")
        var comma = Settings(); comma.decimalSeparator = ","; comma.thousandsSeparator = "."
        XCTAssertEqual(run("5,5 ft 3 in to cm", comma)?.first?.title, "175,26 cm")
    }

    func testMinutesBeforeSeconds() {
        XCTAssertEqual(UnitsTool.expandCompound("2 m 30 s to s", settings: Settings()), "150 s to s")
        XCTAssertEqual(UnitsTool.expandCompound("2 m 30 cm to cm", settings: Settings()), "230 cm to cm")
    }

    func testCompoundGuards() {
        XCTAssertNil(run("3 in 5 ft to cm"), "ascending units are not a compound amount")
        XCTAssertEqual(run("5 ft 3 in to kg")?.first?.valid, false)
        XCTAssertEqual(run("10 km to mi")?.first?.title, "6.21371192 mi")
    }

    func testFuelEconomy() {
        XCTAssertEqual(run("30 mpg to l/100km")?.first?.title, "7.84 l/100km")
        XCTAssertEqual(run("8 l/100km to mpg")?.first?.title, "29.4 mpg")
        XCTAssertEqual(run("12 km/l to mpg")?.first?.title, "28.23 mpg")
        XCTAssertEqual(run("30 mpg to km/l")?.first?.title, "12.75 km/l")
        XCTAssertEqual(run("35 mpg uk to mpg")?.first?.title, "29.14 mpg")
        XCTAssertEqual(run("0 mpg to l/100km")?.first?.valid, false)
        XCTAssertEqual(run("-5 mpg to km/l")?.first?.valid, false)
    }
}

final class TipTests: XCTestCase {
    private func run(_ q: String) -> [AlfredItem]? { blocking(TipTool(), q) }

    func testSuggestedRates() {
        XCTAssertEqual(run("tip 85")?.map(\.title), ["15%: total 97.75", "18%: total 100.3", "20%: total 102", "25%: total 106.25"])
        XCTAssertEqual(run("20 tip")?.first?.title, "15%: total 23")
        XCTAssertEqual(run("tip 85 split 3")?.first?.title, "15%: each pays 32.58")
    }

    func testGivenRate() {
        for q in ["tip 85 at 18%", "tip 18% of 85", "tip 85 18", "85 tip 18%", "tip 85@18"] {
            let r = run(q)
            XCTAssertEqual(r?.map(\.title), ["Total 100.3", "Tip 15.3"], q)
            XCTAssertEqual(r?.first?.arg, "100.3", q)
            XCTAssertEqual(r?.first?.mods?.cmd?.arg, "100.3", q)
        }
        XCTAssertEqual(run("tip 1,234.50 at 15%")?.first?.title, "Total 1,419.68")
    }

    func testSplit() {
        let r = run("tip 85 20% split 3")
        XCTAssertEqual(r?.map(\.title), ["Each pays 34", "Total 102", "Tip 17"])
        XCTAssertEqual(r?.first?.subtitle, "Total 102 split 3 ways, tip 5.67 each")
        XCTAssertEqual(run("85 tip 18% between 4")?.first?.title, "Each pays 25.08")
    }

    func testGuards() {
        for q in ["tip 85 at 5000%", "tip 85 split 0", "tip 85 split 2000"] { XCTAssertEqual(run(q)?.first?.valid, false, q) }
        for q in ["tip", "tip hello", "10 tipping point", "85 at 18%", "hello"] { XCTAssertNil(run(q), q) }
        XCTAssertEqual(run("tip 0 at 10%")?.first?.title, "Total 0")
        XCTAssertNil(run("tip 2+2"))
        XCTAssertEqual(run("tip 85+20%")?.first?.title, "Total 102")
        XCTAssertEqual(run("tip -5")?.first?.valid, false)
        XCTAssertEqual(run("tip $85 at 18%")?.first?.title, "Total 100.3")
        XCTAssertEqual(run("tip 85 eur at 18%")?.first?.title, "Total 100.3")
    }
}

private final class StubRates: RatesProviding {
    var stale = false, fail = false
    func fiatRates() async throws -> RateTable {
        if fail { throw RatesError.unavailable("No fiat rates: nothing cached") }
        return RateTable(base: "USD", rates: ["EUR": 0.9, "GBP": 0.8], fetchedAt: Date(timeIntervalSince1970: 1_795_000_000), source: "frankfurter", stale: stale)
    }
    func cryptoRates(symbols: [String]) async throws -> RateTable {
        RateTable(base: "USD", rates: ["BTC": 0.00002], fetchedAt: Date(timeIntervalSince1970: 1_795_000_000), source: "coingecko", stale: stale)
    }
}

final class RatesRefreshTests: XCTestCase {
    func testForcingExpiresCaches() {
        let s = RatesRefresh.forcing(Settings())
        XCTAssertEqual(s.fiatCacheHours, 0)
        XCTAssertEqual(s.cryptoCacheMinutes, 0)
    }

    func testSummaries() async {
        let ok = await RatesRefresh.run(StubRates())
        XCTAssertEqual(ok, "Fiat: 2 rates from frankfurter. Crypto: 1 coins from coingecko")
        let stub = StubRates(); stub.stale = true
        let stale = await RatesRefresh.run(stub)
        XCTAssertTrue(stale.hasPrefix("Fiat: offline, kept 2 rates from 20"), stale)
        let bad = StubRates(); bad.fail = true
        let failed = await RatesRefresh.run(bad)
        XCTAssertTrue(failed.hasPrefix("Fiat: No fiat rates: nothing cached. Crypto:"), failed)
    }
}
