import XCTest
@testable import CalcCore

/// Regression tests for far-future years, DST-gap resolution and the proleptic Gregorian calendar.
final class TimeFixTests: XCTestCase {
    private func run(_ q: String, zone: String = "America/New_York", now: TimeInterval = 1_795_447_845,
                     formats: [String] = ["Y-m-d H:i:s P"]) -> [AlfredItem]? {
        var o = TimeOptions(zone: TimeZone(identifier: zone)!)
        o.formats = formats
        let ctx = Context(now: Date(timeIntervalSince1970: now), dataDir: URL(fileURLWithPath: "/tmp"))
        final class Box: @unchecked Sendable { var value: [AlfredItem]? }
        let box = Box(), done = DispatchSemaphore(value: 0)
        let tool = TimeTool(options: o)
        Task.detached { box.value = await tool.evaluate(q, context: ctx); done.signal() }
        done.wait()
        return box.value
    }

    private func first(_ q: String, zone: String = "America/New_York", now: TimeInterval = 1_795_447_845) -> String? {
        run(q, zone: zone, now: now)?.first?.title
    }

    // MARK: far-future years

    func testFarFutureYearsAreCorrectOrInvalid() {
        for y in [500_000, 1_000_000] {
            let t = first("time 2026-01-01 + \(y) years", zone: "UTC")
            let expected = "\(y + 2026)-01-01 00:00:00 +00:00"
            XCTAssertTrue(t == expected || t == "...", "year +\(y): \(t ?? "nil")")
        }
        XCTAssertEqual(first("2026-01-01 + 100000 years", zone: "UTC"), "102026-01-01 00:00:00 +00:00")
    }

    // MARK: DST gaps

    func testNewYorkGapAllPathsShiftForward() {
        // 2026-03-08 02:30 does not exist in New York; PHP gives 03:30 EDT.
        let want = "2026-03-08 03:30:00 -04:00"
        XCTAssertEqual(first("2026-03-08 02:30"), want)
        XCTAssertEqual(first("2026-03-08 02:30:00"), want)
        XCTAssertEqual(first("march 8, 2026 2:30am"), want)
        XCTAssertEqual(first("8 march 2026 2:30 am"), want)
        XCTAssertEqual(first("2026-03-08 at 2:30am"), want)
        XCTAssertEqual(first("2026-03-07 02:30 + 1 day"), want)
        XCTAssertEqual(first("2026-03-01 02:30 + 1 week"), want)
        XCTAssertEqual(first("2026-02-08 02:30 + 1 month"), want)
        XCTAssertEqual(first("2025-03-08 02:30 + 1 year"), want)
        // "tomorrow 2:30am" when now is 2026-03-07 12:00 New York
        let now = TimeInterval(1_772_902_800)  // 2026-03-07 17:00 UTC
        XCTAssertEqual(first("tomorrow 2:30am", now: now), want)
        XCTAssertEqual(first("tomorrow at 2:30am", now: now), want)
    }

    func testGapInZoneConversion() {
        // Sunday 2026-03-08 12:00 UTC = 08:00 EDT; "2:30am in tokyo" reads 02:30 New York that day.
        let now = TimeInterval(1_772_971_200)
        let r = run("2:30am in tokyo", now: now)?.first?.title
        XCTAssertEqual(r, "16:30 JST (Sun 8 Mar)")  // 03:30 EDT = 07:30 UTC = 16:30 JST
    }

    func testLordHoweGap() {
        // DST starts 2026-10-04 02:00 -> 02:30 (30 minute shift); 02:15 does not exist.
        XCTAssertEqual(first("2026-10-04 02:15", zone: "Australia/Lord_Howe"), "2026-10-04 02:45:00 +11:00")
        XCTAssertEqual(first("october 4, 2026 2:15am", zone: "Australia/Lord_Howe"), "2026-10-04 02:45:00 +11:00")
        XCTAssertEqual(first("2026-10-03 02:15 + 1 day", zone: "Australia/Lord_Howe"), "2026-10-04 02:45:00 +11:00")
    }

    func testAucklandGap() {
        XCTAssertEqual(first("2026-09-27 02:30", zone: "Pacific/Auckland"), "2026-09-27 03:30:00 +13:00")
        XCTAssertEqual(first("september 27, 2026 2:30am", zone: "Pacific/Auckland"), "2026-09-27 03:30:00 +13:00")
    }

    func testOrdinaryAndAmbiguousTimesUnchanged() {
        XCTAssertEqual(first("2026-03-08 01:30"), "2026-03-08 01:30:00 -05:00")
        XCTAssertEqual(first("2026-03-08 03:30"), "2026-03-08 03:30:00 -04:00")
        // Fall back: 01:30 occurs twice on 2026-11-01; the first (EDT) one is used.
        XCTAssertEqual(first("2026-11-01 01:30"), "2026-11-01 01:30:00 -04:00")
    }

    // MARK: proleptic Gregorian

    func testBefore1582IsProleptic() {
        XCTAssertEqual(first("1500-03-01", zone: "UTC"), "1500-03-01 00:00:00 +00:00")
        XCTAssertEqual(first("time 1500-02-29", zone: "UTC"), "...")  // 1500 is not a Gregorian leap year
        XCTAssertEqual(first("1582-10-10", zone: "UTC"), "1582-10-10 00:00:00 +00:00")  // inside the Julian cutover gap
        XCTAssertEqual(first("1582-10-04 + 1 day", zone: "UTC"), "1582-10-05 00:00:00 +00:00")
        XCTAssertEqual(first("1000-01-01 + 1 day", zone: "UTC"), "1000-01-02 00:00:00 +00:00")
        // Known proleptic Gregorian instants: 1000-01-01 = -30610224000, 0001-01-01 = -62135596800.
        let ts = run("1000-01-01 to timestamp", zone: "UTC")
        XCTAssertEqual(ts?.first?.title, "-30610224000")
        XCTAssertEqual(run("0001-01-01 to timestamp", zone: "UTC")?.first?.title, "-62135596800")
    }

    func testWeekdayBefore1582IsProleptic() {
        // 1500-03-01 was a Thursday in the proleptic Gregorian calendar.
        XCTAssertEqual(run("1500-03-01", zone: "UTC", formats: ["l"])?.first?.title, "Thursday")
    }

    func testIsoWeekAndYearDayAcrossEras() {
        func check(_ q: String, _ want: String) {
            XCTAssertEqual(run(q, zone: "UTC", formats: ["o W z D"])?.first?.title, want, q)
        }
        check("2020-12-31", "2020 53 365 Thu")
        check("2021-01-03", "2020 53 2 Sun")
        check("2021-01-04", "2021 01 3 Mon")
        check("2026-11-23", "2026 48 326 Mon")
        check("1500-03-01", "1500 09 59 Thu")
        check("2024-12-30", "2025 01 364 Mon")
        check("2016-01-01", "2015 53 0 Fri")
        check("1000-07-04", "1000 27 184 Fri")
        check("0100-03-01", "0100 09 59 Mon")
    }
}
