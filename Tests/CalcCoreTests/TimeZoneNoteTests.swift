import XCTest
@testable import CalcCore

final class TimeZoneNoteTests: XCTestCase {
    private let now: TimeInterval = 1_795_447_845 // 2026-11-23

    private func run(_ q: String, zone: String = "America/New_York", invalid: String? = nil) -> [AlfredItem]? {
        var o = TimeOptions(zone: TimeZone(identifier: zone)!)
        o.invalidZone = invalid
        let ctx = Context(now: Date(timeIntervalSince1970: now), dataDir: URL(fileURLWithPath: "/tmp"))
        final class Box: @unchecked Sendable { var value: [AlfredItem]? }
        let box = Box(), done = DispatchSemaphore(value: 0)
        let tool = TimeTool(options: o)
        Task.detached { box.value = await tool.evaluate(q, context: ctx); done.signal() }
        done.wait()
        return box.value
    }

    func testUnknownZoneGivesErrorRow() {
        for q in ["time 3pm in Narnia", "time 3pm in PT, Narnia", "what time is it in Gondor"] {
            let r = run(q)
            XCTAssertEqual(r?.count, 1, q)
            XCTAssertEqual(r?.first?.title, "Unknown time zone", q)
            XCTAssertEqual(r?.first?.valid, false, q)
        }
        XCTAssertTrue(run("time 3pm in Narnia")?.first?.subtitle.contains("narnia") == true)
    }

    func testDifferencesAreNotMistakenForUnknownZones() {
        XCTAssertEqual(run("time 3pm to 5pm")?.first?.title, "2 hours")
        XCTAssertNil(run("3pm in Narnia"), "without the time keyword the query is not claimed")
    }

    func testMixedQueriesAreNotUnknownZones() {
        XCTAssertNotEqual(run("time 3pm in tokyo to 5pm")?.first?.title, "Unknown time zone")
    }

    func testDaylightSavingInEffectNote() {
        let summer = run("time 3pm 2026-07-01 in London")?.first
        XCTAssertEqual(summer?.title, "20:00 BST (Wed 1 Jul)")
        XCTAssertTrue(summer?.subtitle.contains("EDT is daylight saving time (UTC-04:00)") == true)
        XCTAssertTrue(summer?.subtitle.contains("BST is daylight saving time (UTC+01:00)") == true)
        let winter = run("time 3pm in PT")?.first
        XCTAssertEqual(winter?.title, "12:00 PST (Mon 23 Nov)")
        XCTAssertFalse(winter?.subtitle.contains("daylight") == true)
    }

    func testSpringForwardGapNote() {
        let r = run("time 2026-03-08 2:30am in NYC")?.first
        XCTAssertEqual(r?.title, "03:30 EDT (Sun 8 Mar)")
        XCTAssertTrue(r?.subtitle.contains("02:30 does not exist on that day (clocks skip forward); shown as 03:30 EDT") == true, r?.subtitle ?? "")
        XCTAssertFalse(run("time 2026-03-08 3:30am in NYC")?.first?.subtitle.contains("does not exist") == true)
        XCTAssertFalse(run("time 2026-03-08 1:30am in NYC")?.first?.subtitle.contains("does not exist") == true)
    }

    func testFallBackRepeatNote() {
        let r = run("time 2026-11-01 1:30am in NYC")?.first
        XCTAssertEqual(r?.title, "01:30 EDT (Sun 1 Nov)")
        XCTAssertTrue(r?.subtitle.contains("01:30 happens twice that day (clocks go back); using the first") == true, r?.subtitle ?? "")
        XCTAssertFalse(run("time 2026-11-01 3:30am in NYC")?.first?.subtitle.contains("happens twice") == true)
        XCTAssertFalse(run("time 2026-11-01 12:30am in NYC")?.first?.subtitle.contains("happens twice") == true)
    }

    func testInvalidZoneSettingAddsWarningOnTimeResultsOnly() {
        let r = run("time now", invalid: "Nope/Zone")
        XCTAssertEqual(r?.first?.title, "Invalid time zone setting")
        XCTAssertEqual(r?.first?.valid, false)
        XCTAssertTrue(r?.first?.subtitle.contains("'Nope/Zone'") == true)
        XCTAssertTrue(r?.first?.subtitle.contains("America/New_York") == true)
        XCTAssertEqual(r?.count, 3)
        XCTAssertNotEqual(run("time now")?.first?.title, "Invalid time zone setting")
        XCTAssertNil(run("hello", invalid: "Nope/Zone"), "unclaimed queries stay unclaimed")
    }

    func testEngineAcceptsAliasesAndFlagsGarbage() async {
        func zoneOf(_ id: String) -> TimeTool? {
            var s = Settings(); s.timezone = id
            return DefaultEngine.tools(settings: s).compactMap { $0 as? TimeTool }.first
        }
        XCTAssertEqual(zoneOf("Asia/Tokyo")?.options.zone.identifier, "Asia/Tokyo")
        XCTAssertEqual(zoneOf("London")?.options.zone.identifier, "Europe/London")
        XCTAssertNil(zoneOf("London")?.options.invalidZone)
        XCTAssertNil(zoneOf("none")?.options.invalidZone, "the workflow popup stores none when no zone is picked")
        XCTAssertEqual(zoneOf("none")?.options.zone, TimeOptions().zone)
        XCTAssertEqual(zoneOf("Nope/Zone")?.options.invalidZone, "Nope/Zone")
    }
}
