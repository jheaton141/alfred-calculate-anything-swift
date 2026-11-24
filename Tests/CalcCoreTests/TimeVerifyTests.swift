import XCTest
@testable import CalcCore

/// Fixed clock: Monday 2026-11-23 15:30:45 UTC = 10:30:45 EST (America/New_York unless a test says otherwise).
final class TimeVerifyTests: XCTestCase {
    private let now: TimeInterval = 1_795_447_845
    private let isoFormat = ["Y-m-d H:i:s"]

    private final class Box: @unchecked Sendable { var value: [AlfredItem]? }

    private func run(_ query: String, zone: String = "America/New_York", lang: String = "en_EN",
                     formats: [String]? = nil) -> [AlfredItem]? {
        var options = TimeOptions(zone: TimeZone(identifier: zone) ?? .current)
        options.formats = formats ?? isoFormat
        let ctx = Context(strings: Strings.load(lang), now: Date(timeIntervalSince1970: now),
                          dataDir: URL(fileURLWithPath: "/tmp"))
        let box = Box(), done = DispatchSemaphore(value: 0)
        let tool = TimeTool(options: options)
        Task.detached { box.value = await tool.evaluate(query, context: ctx); done.signal() }
        done.wait()
        return box.value
    }

    private func first(_ query: String, zone: String = "America/New_York", formats: [String]? = nil) -> String? {
        run(query, zone: zone, formats: formats)?.first?.title
    }

    // MARK: clock-first phrasings

    func testClockBeforeDay() {
        XCTAssertEqual(first("2:30am tomorrow"), "2026-11-24 02:30:00")
        XCTAssertEqual(first("3pm tomorrow"), "2026-11-24 15:00:00")
        XCTAssertEqual(first("noon tomorrow"), "2026-11-24 12:00:00")
        XCTAssertEqual(first("5pm friday"), "2026-11-27 17:00:00")
        XCTAssertEqual(first("time 3pm tomorrow"), "2026-11-24 15:00:00")
        XCTAssertEqual(first("tomorrow 3pm"), "2026-11-24 15:00:00")
        XCTAssertEqual(first("friday 5pm"), "2026-11-27 17:00:00")
    }

    func testClockBeforeDayWithZone() {
        // 3pm EST tomorrow = 20:00 UTC = 05:00 JST on the 25th.
        XCTAssertEqual(first("3pm tomorrow in Tokyo"), "05:00 JST (Wed 25 Nov)")
        XCTAssertEqual(first("tomorrow 3pm in Tokyo"), "05:00 JST (Wed 25 Nov)")
    }

    // MARK: bare clocks

    func testBareClockWithTimePrefix() {
        XCTAssertEqual(first("time 12am"), "2026-11-23 00:00:00")
        XCTAssertEqual(first("time noon"), "2026-11-23 12:00:00")
        XCTAssertEqual(first("time midnight"), "2026-11-23 00:00:00")
        XCTAssertEqual(first("time 3pm"), "2026-11-23 15:00:00")
        XCTAssertEqual(first("time 15:45"), "2026-11-23 15:45:00")
    }

    func testBareClockWithoutPrefixIsNotClaimed() {
        for query in ["3pm", "noon", "12am", "5 pm to nm", "5 pm", "15:00"] { XCTAssertNil(run(query), query) }
        XCTAssertEqual(first("3pm in PT"), "12:00 PST (Mon 23 Nov)")
    }

    // MARK: slash dates in days-between

    func testDaysBetweenSlashDatesWithoutTimePrefix() {
        let slash = run("days between 12/25/2026 and 1/1/2027")?.map(\.title)
        XCTAssertEqual(slash, run("days between 2026-12-25 and 2027-01-01")?.map(\.title))
        XCTAssertEqual(slash?[1], "7 days")
        XCTAssertNotNil(run("between 12/25/2026 and 1/1/2027"))
    }

    // MARK: until / since use calendar days

    func testUntilSinceCalendarDays() {
        XCTAssertEqual(run("days until 2026-11-24")?.map(\.title), ["1 day"])
        XCTAssertEqual(run("days since 2020-02-29")?.map(\.title), ["2459 days"])
        XCTAssertEqual(run("days until 2026-11-22")?.map(\.title), ["1 day ago"])
        XCTAssertEqual(run("days between today and 2026-11-24")?.map(\.title)[1], "1 day")
        XCTAssertEqual(run("days between today and 2020-02-29")?.map(\.title)[1], "2459 days")
        XCTAssertEqual(run("days until now + 10 hours")?.map(\.title), ["10 hours"])
    }

    // MARK: format letters e and T

    func testZoneFormatLetters() {
        XCTAssertEqual(first("2026-11-23 12:00", zone: "UTC", formats: ["e T"]), "UTC UTC")
        XCTAssertEqual(first("2026-11-23 12:00", zone: "Asia/Kathmandu", formats: ["e T"]), "Asia/Kathmandu +0545")
        XCTAssertEqual(first("2026-07-01 12:00", zone: "Australia/Lord_Howe", formats: ["T"]), "+1030")
        XCTAssertEqual(first("2026-11-23 12:00", formats: ["T"]), "EST")
        XCTAssertEqual(first("2026-11-23 12:00", zone: "Asia/Tokyo", formats: ["T"]), "JST")
    }

    // MARK: performance

    func testHostileInputsAreFast() {
        let cases = ["time " + String(repeating: "- ", count: 5000),
                     "3pm " + String(repeating: "tokyo in ", count: 1500),
                     "time " + String(repeating: "1 to ", count: 2000),
                     "days between " + String(repeating: "2026-01-01 and ", count: 700),
                     "3pm EST in " + String(repeating: "tokyo, ", count: 1500)]
        for query in cases {
            let start = Date()
            _ = run(query)
            let millis = Date().timeIntervalSince(start) * 1000
            XCTAssertLessThan(millis, 50, "\(query.prefix(24)) took \(millis) ms")
        }
    }

    // MARK: localisation

    func testEnglishNamesUnchanged() {
        let rows = run("2026-11-23", formats: ["l, j F Y", "D M"])?.prefix(2).map(\.title)
        XCTAssertEqual(rows, ["Monday, 23 November 2026", "Mon Nov"])
    }

    func testLocalisedFormatNames() {
        let spanish = run("2026-11-23", lang: "es_ES", formats: ["l, j F Y", "D M"])
        XCTAssertEqual(spanish?.prefix(2).map(\.title), ["lunes, 23 noviembre 2026", "lun nov"])
        let swedish = run("2026-11-23", lang: "sv_SE", formats: ["l, j F Y", "D M"])
        XCTAssertEqual(swedish?.prefix(2).map(\.title), ["måndag, 23 november 2026", "mån nov"])
    }

    func testLocalisedTimespanAndTimestamp() {
        let spanish = run("2026-11-20", lang: "es_ES")
        XCTAssertEqual(spanish?[1].title, "hace 3 días, 10 horas, 30 minutos, 45 segundos")
        XCTAssertEqual(spanish?[1].subtitle, "Intervalo")
        XCTAssertEqual(spanish?[2].subtitle, "Marca de tiempo")
        let swedish = run("2026-11-20", lang: "sv_SE")
        XCTAssertEqual(swedish?[1].title, "3 dagar, 10 timmar, 30 minuter, 45 sekunder sedan")
        XCTAssertEqual(swedish?[1].subtitle, "Tidsintervall")
        XCTAssertEqual(swedish?[2].subtitle, "Tidsstämpel")
        XCTAssertEqual(run("2026-11-20")?[1].title, "3 days, 10 hours, 30 minutes, 45 seconds ago")
    }

    func testLocalisedUnixTimestamp() {
        let spanish = run("timestamp of 2026-11-20", lang: "es_ES")
        XCTAssertEqual(spanish?[0].subtitle, "Marca de tiempo Unix de 2026-11-20 00:00:00")
        XCTAssertEqual(spanish?[1].subtitle, "Milisegundos")
        let swedish = run("timestamp of 2026-11-20", lang: "sv_SE")
        XCTAssertEqual(swedish?[0].subtitle, "Unix-tidsstämpel för 2026-11-20 00:00:00")
        XCTAssertEqual(swedish?[1].subtitle, "Millisekunder")
        XCTAssertEqual(run("timestamp of 2026-11-20")?[1].subtitle, "Milliseconds")
    }

    func testLocalisedUntilSince() {
        let esUntil = run("days until 2026-11-24", lang: "es_ES")?.first
        XCTAssertEqual(esUntil?.title, "1 día")
        XCTAssertEqual(esUntil?.subtitle, "días faltantes hasta el 24 de noviembre de 2026")
        let esSince = run("days since 2026-11-01", lang: "es_ES")?.first
        XCTAssertEqual(esSince?.title, "22 días")
        XCTAssertEqual(esSince?.subtitle, "días desde el 1 de noviembre de 2026")
        let svUntil = run("days until 2026-11-24", lang: "sv_SE")?.first
        XCTAssertEqual(svUntil?.title, "1 dag")
        XCTAssertEqual(svUntil?.subtitle, "dagar till 24 november 2026")
        let svSince = run("days since 2026-11-01", lang: "sv_SE")?.first
        XCTAssertEqual(svSince?.title, "22 dagar")
        XCTAssertEqual(svSince?.subtitle, "dagar sedan 1 november 2026")
        XCTAssertEqual(run("weeks until 2026-12-15", lang: "sv_SE")?.first?.title, "3 veckor")
        XCTAssertEqual(run("days until 2026-11-22", lang: "es_ES")?.first?.title, "hace 1 día")
    }

    func testLocalisedZoneSubtitles() {
        XCTAssertEqual(run("3pm EST in Tokyo", lang: "es_ES")?.first?.subtitle, "Desde 15:00 EST (lun 23 nov)")
    }
}
