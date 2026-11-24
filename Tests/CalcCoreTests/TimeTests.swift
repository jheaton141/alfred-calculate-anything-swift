import XCTest
@testable import CalcCore

/// Fixed clock: Monday 2026-11-23 15:30:45 UTC = 10:30:45 EST in the default test zone (America/New_York).
final class TimeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_795_447_845)
    private let ny = TimeZone(identifier: "America/New_York")!

    private func run(_ q: String, formats: [String]? = nil) -> [AlfredItem]? {
        var o = TimeOptions(zone: ny)
        if let f = formats { o.formats = f }
        let ctx = Context(now: now, dataDir: URL(fileURLWithPath: "/tmp"))
        final class Box: @unchecked Sendable { var value: [AlfredItem]? }
        let box = Box(), done = DispatchSemaphore(value: 0)
        let tool = TimeTool(options: o)
        Task.detached { box.value = await tool.evaluate(q, context: ctx); done.signal() }
        done.wait()
        return box.value
    }

    private func titles(_ q: String) -> [String]? { run(q)?.map(\.title) }
    private func first(_ q: String) -> String? { run(q)?.first?.title }

    // MARK: time zones

    func testAbbreviationToCity() {
        let r = run("3pm EST in Tokyo")
        XCTAssertEqual(r?.count, 1)
        XCTAssertEqual(r?[0].title, "05:00 JST (Tue 24 Nov)")
        XCTAssertEqual(r?[0].subtitle, "From 15:00 EST (Mon 23 Nov)")
        XCTAssertEqual(r?[0].mods?.cmd?.arg, "2026-11-24T05:00:00+09:00")
        XCTAssertEqual(r?[0].mods?.alt?.arg, "Tuesday, November 24, 2026 05:00:00 JST (UTC+09:00)")
        XCTAssertEqual(r?[0].arg, "05:00 JST (Tue 24 Nov)")
    }

    func testCityToCity() {
        XCTAssertEqual(titles("15:00 London to New York"), ["10:00 EST (Mon 23 Nov)"])
        XCTAssertEqual(run("15:00 London to New York")?[0].subtitle, "From 15:00 GMT (Mon 23 Nov)")
    }

    func testNowInCityAndTimeIn() {
        let r = run("now in sydney")
        XCTAssertEqual(r?.map(\.title), ["02:30 AEDT (Tue 24 Nov)"])
        XCTAssertEqual(r?[0].subtitle, "Now: 10:30 EST (Mon 23 Nov); AEDT is daylight saving time (UTC+11:00)")
        XCTAssertEqual(titles("time in paris"), ["16:30 CET (Mon 23 Nov)"])
        XCTAssertEqual(titles("what time is it in tokyo"), ["00:30 JST (Tue 24 Nov)"])
        XCTAssertEqual(titles("tokyo time"), ["00:30 JST (Tue 24 Nov)"])
    }

    func testMultipleTargets() {
        XCTAssertEqual(titles("9am PST to CET, JST"), ["18:00 CET (Mon 23 Nov)", "02:00 JST (Tue 24 Nov)"])
        XCTAssertEqual(titles("9am pst to cet and jst")?.count, 2)
    }

    func testTomorrowAndSourceZoneDay() {
        XCTAssertEqual(titles("tomorrow 9am pst to berlin"), ["18:00 CET (Tue 24 Nov)"])
        XCTAssertEqual(titles("9am pst to tokyo"), ["02:00 JST (Tue 24 Nov)"])
    }

    func testDSTSpringForwardNewYork() {
        XCTAssertEqual(titles("2024-03-09 20:00 america/new_york to tokyo"), ["10:00 JST (Sun 10 Mar)"])
        XCTAssertEqual(titles("2024-03-10 20:00 america/new_york to tokyo"), ["09:00 JST (Mon 11 Mar)"])
        XCTAssertEqual(titles("2024-03-10 01:59 america/new_york to utc"), ["06:59 UTC (Sun 10 Mar)"])
        XCTAssertEqual(titles("2024-03-10 03:00 america/new_york to utc"), ["07:00 UTC (Sun 10 Mar)"])
        XCTAssertEqual(titles("2024-03-10 12:00 utc to new york"), ["08:00 EDT (Sun 10 Mar)"])
        XCTAssertEqual(titles("2024-03-09 12:00 utc to new york"), ["07:00 EST (Sat 9 Mar)"])
    }

    func testDSTFallBackNewYork() {
        XCTAssertEqual(titles("2024-11-03 00:30 america/new_york to utc"), ["04:30 UTC (Sun 3 Nov)"])
        XCTAssertEqual(titles("2024-11-03 03:00 america/new_york to utc"), ["08:00 UTC (Sun 3 Nov)"])
        XCTAssertEqual(titles("2024-11-03 12:00 utc to ny"), ["07:00 EST (Sun 3 Nov)"])
        XCTAssertEqual(titles("2024-11-02 12:00 utc to ny"), ["08:00 EDT (Sat 2 Nov)"])
    }

    func testMidnightRollover() {
        XCTAssertEqual(titles("11pm est in utc"), ["04:00 UTC (Tue 24 Nov)"])
        XCTAssertEqual(titles("1am tokyo to new york"), ["11:00 EST (Mon 23 Nov)"])
        XCTAssertEqual(titles("2026-11-23 01:00 tokyo to new york"), ["11:00 EST (Sun 22 Nov)"])
        XCTAssertEqual(titles("midnight utc to tokyo"), ["09:00 JST (Mon 23 Nov)"])
        XCTAssertEqual(titles("noon utc to tokyo"), ["21:00 JST (Mon 23 Nov)"])
    }

    func testHalfHourZone() {
        XCTAssertEqual(titles("9am utc to kolkata"), ["14:30 IST (Mon 23 Nov)"])
        XCTAssertEqual(titles("18:30 asia/kolkata to utc"), ["13:00 UTC (Mon 23 Nov)"])
        let r = run("6:30pm IST to UTC")
        XCTAssertEqual(r?.first?.title, "13:00 UTC (Mon 23 Nov)")
        XCTAssertTrue(r?.first?.subtitle.contains("India Standard Time") == true)
        XCTAssertEqual(titles("12:00 utc to utc+5:30"), ["17:30 UTC+05:30 (Mon 23 Nov)"])
    }

    func testZoneNamesAndAliases() {
        XCTAssertEqual(titles("noon nyc to la"), ["09:00 PST (Mon 23 Nov)"])
        XCTAssertEqual(titles("noon eastern to pacific"), ["09:00 PST (Mon 23 Nov)"])
        XCTAssertEqual(titles("12:00 America/Los_Angeles to Europe/London"), ["20:00 GMT (Mon 23 Nov)"])
        XCTAssertEqual(titles("12:00 san francisco to mumbai"), ["01:30 IST (Tue 24 Nov)"])
    }

    func testFixedAbbreviationDoesNotFollowDST() {
        // EST is a fixed -05:00 even in July, unlike America/New_York
        XCTAssertEqual(titles("2024-07-01 12:00 est to utc"), ["17:00 UTC (Mon 1 Jul)"])
        XCTAssertEqual(titles("2024-07-01 12:00 new york to utc"), ["16:00 UTC (Mon 1 Jul)"])
    }

    func testNotTimeZoneQueries() {
        for q in ["5 + 5", "10 km to mi", "100 usd to eur", "20% of 150", "100 + 16%", "3pm", "15:00", "5 mi", "2 weeks",
                  "10 days + 5 days", "hello world", "3pm in nowhere", "100 eur in usd", "12 in to cm", "1.5 gb to mb", "what is 7 times 6"] {
            XCTAssertNil(run(q), q)
        }
    }

    // MARK: relative dates

    func testNowRows() {
        let r = run("now")
        XCTAssertEqual(r?.map(\.title), ["November 23rd, 2026, 10:30:45 am", "1795447845"])
        XCTAssertEqual(r?[0].subtitle, "Format F jS, Y, g:i:s a")
        XCTAssertEqual(r?[1].subtitle, "Timestamp")
        XCTAssertEqual(titles("time"), titles("now"))
    }

    func testTodayTomorrowYesterday() {
        XCTAssertEqual(titles("today"), ["November 23rd, 2026, 12:00:00 am", "10 hours, 30 minutes, 45 seconds ago", "1795410000"])
        XCTAssertEqual(titles("tomorrow"), ["November 24th, 2026, 10:30:45 am", "1 day", "1795534245"])
        XCTAssertEqual(titles("yesterday")?.prefix(2).map { $0 }, ["November 22nd, 2026, 10:30:45 am", "1 day ago"])
    }

    func testInAndAgo() {
        XCTAssertEqual(titles("in 3 days")?.prefix(2).map { $0 }, ["November 26th, 2026, 10:30:45 am", "3 days"])
        XCTAssertEqual(titles("3 days ago")?.prefix(2).map { $0 }, ["November 20th, 2026, 10:30:45 am", "3 days ago"])
        XCTAssertEqual(first("2 weeks from now"), "December 7th, 2026, 10:30:45 am")
        XCTAssertEqual(first("an hour ago"), "November 23rd, 2026, 9:30:45 am")
        XCTAssertEqual(first("in 2 hours and 15 minutes"), "November 23rd, 2026, 12:45:45 pm")
    }

    func testWeekdays() {
        XCTAssertEqual(first("next friday"), "November 27th, 2026, 12:00:00 am")
        XCTAssertEqual(first("last monday"), "November 16th, 2026, 12:00:00 am")
        XCTAssertEqual(first("friday"), "November 27th, 2026, 12:00:00 am")
        XCTAssertEqual(first("monday"), "November 23rd, 2026, 12:00:00 am")
        XCTAssertEqual(first("next monday"), "November 30th, 2026, 12:00:00 am")
        XCTAssertEqual(first("next fri 3pm"), "November 27th, 2026, 3:00:00 pm")
        XCTAssertNil(run("sat"))
        XCTAssertNil(run("wed"))
    }

    func testNextLastUnits() {
        XCTAssertEqual(first("next week"), "November 30th, 2026, 10:30:45 am")
        XCTAssertEqual(first("last month"), "October 23rd, 2026, 10:30:45 am")
        XCTAssertEqual(first("next year"), "November 23rd, 2027, 10:30:45 am")
    }

    // MARK: arithmetic

    func testArithmetic() {
        XCTAssertEqual(first("2024-01-05 + 30 days"), "February 4th, 2024, 12:00:00 am")
        XCTAssertEqual(first("2024-01-31 + 1 month"), "February 29th, 2024, 12:00:00 am")
        XCTAssertEqual(first("today + 2 weeks"), "December 7th, 2026, 12:00:00 am")
        XCTAssertEqual(first("now plus 6 hours"), "November 23rd, 2026, 4:30:45 pm")
        XCTAssertEqual(first("time +15 years"), "November 23rd, 2041, 10:30:45 am")
        XCTAssertEqual(first("today - 3 days"), "November 20th, 2026, 12:00:00 am")
        XCTAssertEqual(first("tomorrow + 2 hours"), "November 24th, 2026, 12:30:45 pm")
    }

    func testWorkdays() {
        XCTAssertEqual(first("time + 3 workdays"), "November 26th, 2026, 10:30:45 am")
        XCTAssertEqual(first("today + 5 workdays"), "November 30th, 2026, 12:00:00 am")
        XCTAssertEqual(first("friday + 1 weekday"), "November 30th, 2026, 12:00:00 am")
        XCTAssertEqual(first("today - 1 weekday"), "November 20th, 2026, 12:00:00 am")
    }

    func testArithmeticAcrossDST() {
        XCTAssertEqual(first("2024-03-09 12:00 + 24 hours"), "March 10th, 2024, 1:00:00 pm")
        XCTAssertEqual(first("2024-03-09 12:00 + 1 day"), "March 10th, 2024, 12:00:00 pm")
        XCTAssertEqual(first("2024-11-02 12:00 + 24 hours"), "November 3rd, 2024, 11:00:00 am")
    }

    // MARK: timestamps and formats

    func testTimestampToDate() {
        XCTAssertEqual(titles("1700000000"), ["November 14th, 2023, 5:13:20 pm", "3 years, 8 days, 17 hours, 17 minutes, 25 seconds ago", "1700000000"])
        XCTAssertEqual(first("time 1577836800"), "December 31st, 2019, 7:00:00 pm")
        XCTAssertEqual(first("@1700000000"), "November 14th, 2023, 5:13:20 pm")
        XCTAssertEqual(first("1700000000000"), "November 14th, 2023, 5:13:20 pm")
        XCTAssertEqual(first("1700000000 to date"), "November 14th, 2023, 5:13:20 pm")
        XCTAssertEqual(run("1700000000")?.last?.arg, "1700000000")
        XCTAssertNil(run("12345"))
    }

    func testDateToTimestamp() {
        XCTAssertEqual(titles("2024-01-05 to timestamp"), ["1704430800", "1704430800000"])
        XCTAssertEqual(first("timestamp 2024-01-05"), "1704430800")
        XCTAssertEqual(first("now to unix"), "1795447845")
        XCTAssertEqual(run("2024-01-05 to timestamp")?[0].subtitle, "Unix timestamp of 2024-01-05 00:00:00")
    }

    func testAbsoluteFormats() {
        XCTAssertEqual(first("2024-01-05"), "January 5th, 2024, 12:00:00 am")
        XCTAssertEqual(first("2024-01-05 18:30"), "January 5th, 2024, 6:30:00 pm")
        XCTAssertEqual(first("2024-01-05T18:30:00Z"), "January 5th, 2024, 1:30:00 pm")
        XCTAssertEqual(first("2024-01-05T18:30:00+02:00"), "January 5th, 2024, 11:30:00 am")
        XCTAssertEqual(first("time 31 December, 2021 18:00:00"), "December 31st, 2021, 6:00:00 pm")
        XCTAssertEqual(first("time 31/12/2021 18:00:00"), "December 31st, 2021, 6:00:00 pm")
        XCTAssertEqual(first("time 12/31/2021 18:00:00"), "December 31st, 2021, 6:00:00 pm")
        XCTAssertEqual(first("5 may 2024"), "May 5th, 2024, 12:00:00 am")
        XCTAssertEqual(first("mar 2"), "March 2nd, 2026, 12:00:00 am")
        XCTAssertEqual(first("december 22, 2025 3pm"), "December 22nd, 2025, 3:00:00 pm")
    }

    func testCustomFormats() {
        let r = run("2024-03-10 15:00", formats: ["Y-m-d H:i:s", " D, d M Y O T N z t L ", "l \\t\\h\\e jS \\o\\f F"])
        XCTAssertEqual(r?[0].title, "2024-03-10 15:00:00")
        XCTAssertEqual(r?[0].subtitle, "Format Y-m-d H:i:s")
        XCTAssertEqual(r?[1].title, "Sun, 10 Mar 2024 -0400 EDT 7 69 31 1")
        XCTAssertEqual(r?[2].title, "Sunday the 10th of March")
    }

    // MARK: differences, until, boundaries

    func testDifferenceBetweenDates() {
        let r = run("2024-01-05 to 2024-03-01")
        XCTAssertEqual(r?.map(\.title), ["1 month, 25 days", "56 days", "1344 hours"])
        XCTAssertEqual(r?[0].subtitle, "Time difference between 2024-01-05 00:00:00 and 2024-03-01 00:00:00")
        XCTAssertEqual(titles("2024-01-05 - 2024-03-01"), ["1 month, 25 days", "56 days", "1344 hours"])
        XCTAssertEqual(titles("25 december, 2021 - 31 december, 2021")?.first, "6 days")
        XCTAssertEqual(titles("time 30-11-2019 - 21-11-2019")?.first, "9 days")
        XCTAssertEqual(titles("time 11/30/2019 - 11/21/2019")?.first, "9 days")
        XCTAssertEqual(titles("2024-03-01 to 2024-01-05")?.first, "1 month, 25 days")
    }

    func testInvalidCalendarDateRejected() {
        let r = run("time 31-11-2019 - 21-11-2019")
        XCTAssertEqual(r?.first?.title, "...")
        XCTAssertEqual(r?.first?.valid, false)
        XCTAssertNil(run("2024-02-30"))
    }

    func testUntilAndSince() {
        XCTAssertEqual(titles("days until 31 december"), ["38 days"])
        XCTAssertEqual(titles("days until 2026-11-20"), ["3 days ago"])
        XCTAssertEqual(titles("days since 2026-11-01"), ["22 days"])
        XCTAssertEqual(titles("hours until tomorrow"), ["24 hours"])
        XCTAssertEqual(titles("days until tomorrow"), ["1 day"])
        XCTAssertEqual(titles("days until now + 10 hours"), ["10 hours"])
        XCTAssertEqual(titles("hours until 2026-11-23 18:00"), ["7 hours"])
        XCTAssertEqual(run("days until 31 december")?[0].subtitle, "days until 31 december")
        XCTAssertEqual(titles("days until 1 november"), ["343 days"])
    }

    func testStartAndEndOf() {
        XCTAssertEqual(first("start of year"), "January 1st, 2026, 12:00:00 am")
        XCTAssertEqual(first("end of year"), "December 31st, 2026, 11:59:59 pm")
        XCTAssertEqual(first("time start of 2021"), "January 1st, 2021, 12:00:00 am")
        XCTAssertEqual(first("time end of 2021"), "December 31st, 2021, 11:59:59 pm")
        XCTAssertEqual(first("end of month"), "November 30th, 2026, 11:59:59 pm")
        XCTAssertEqual(first("start of week"), "November 23rd, 2026, 12:00:00 am")
        XCTAssertEqual(first("end of week"), "November 29th, 2026, 11:59:59 pm")
    }

    func testKeywordAndInvalid() {
        let bad = run("time banana")
        XCTAssertEqual(bad?.count, 1)
        XCTAssertEqual(bad?.first?.valid, false)
        XCTAssertEqual(bad?.first?.subtitle, "Enter a valid date")
        XCTAssertNil(run("banana"))
    }

    func testZoneOptionChangesDisplay() {
        var o = TimeOptions(zone: TimeZone(identifier: "Asia/Tokyo")!)
        o.formats = ["H:i T"]
        let ctx = Context(now: now, dataDir: URL(fileURLWithPath: "/tmp"))
        final class Box: @unchecked Sendable { var value: [AlfredItem]? }
        let box = Box(), done = DispatchSemaphore(value: 0)
        Task.detached { box.value = await TimeTool(options: o).evaluate("now", context: ctx); done.signal() }
        done.wait()
        XCTAssertEqual(box.value?.first?.title, "00:30 JST")
    }

    func testHostileInputsDoNotCrash() {
        let inputs = ["99999999999999999999999", "@99999999999999999999", "in 99999999999999 years", "today + 1e9 days", "-5 days ago", "00:00 to 25:99",
                      "25pm utc to tokyo", "13pm utc to tokyo", "0am utc to tokyo", "9:75am utc to tokyo", "utc+99 to utc", "now in ,", "now in , ,", " to ", " - ",
                      "time -", "time to", "2024-13-45", "0000-00-00", "start of", "end of 99999", "days until", "days until days until", "1/1/1 - 2/2/2",
                      "31 feb 2024", "next", "last", "in", "ago", "+", "- 3 days", "3 days -", "2024-01-05 + 99999999 days", "9999999999999 days ago"]
        for q in inputs { _ = run(q); _ = run("time " + q) }
        XCTAssertNil(run("31 feb 2024"))
        XCTAssertNil(run("25pm utc to tokyo"))
    }
}
