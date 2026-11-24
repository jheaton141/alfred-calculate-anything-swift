import XCTest
@testable import CalcCore

final class ColorVerifyTests: XCTestCase {
    private func run(_ q: String, lang: String = "en_EN") -> [AlfredItem]? {
        var s = Settings(); s.language = lang
        let ctx = Context(settings: s, strings: Strings.load(lang), dataDir: FileManager.default.temporaryDirectory)
        final class Box: @unchecked Sendable { var v: [AlfredItem]? }
        let box = Box(), sem = DispatchSemaphore(value: 0)
        Task { box.v = await ColorTool().evaluate(q, context: ctx); sem.signal() }
        sem.wait()
        return box.v
    }
    private func one(_ q: String) -> String? { run(q)?.first?.title }

    func testBareHexWordsAreNotClaimed() {
        for q in ["dec to hex", "bed to hex", "bad in rgb", "face to hex", "cafe in cmyk", "100000 to rgb", "ff8800 to rgb"] {
            XCTAssertNil(run(q), q)
        }
        XCTAssertEqual(one("#ff8800 to rgb"), "rgb(255, 136, 0)")
    }

    func testXYZIsCSSScale() {
        XCTAssertEqual(one("red to xyz"), "color(xyz 0.4125 0.2127 0.0193)")
        XCTAssertEqual(ColorMath.parse("color(xyz 0.4125 0.2127 0.0193)", allowBareHex: false)?.r, 255)
        XCTAssertEqual(ColorMath.parse("color(xyz 0.4125 0.2127 0.0193)", allowBareHex: false)?.g, 0)
        // Legacy 0-100 forms still parse.
        let legacy = ColorMath.parse("xyz(41.24 21.27 1.93)", allowBareHex: false)
        XCTAssertEqual(legacy?.r, 255); XCTAssertEqual(legacy?.g, 0)
        XCTAssertEqual(ColorMath.parse("color(xyz 41.24 21.27 1.93)", allowBareHex: false)?.r, 255)
    }

    func testAlphaNotRoundedAway() {
        XCTAssertEqual(one("rgba(0,0,255,0.996) to hex"), "#0000fffe")
        XCTAssertEqual(one("#0000fffe to rgb"), "rgba(0, 0, 255, 0.996)")
        XCTAssertEqual(one("rgba(0,0,255,0.004) to hex"), "#0000ff01")
        XCTAssertEqual(one("#0000ff01 to rgb"), "rgba(0, 0, 255, 0.004)")
        XCTAssertEqual(one("#ff000080 to hsv"), "hsva(0, 100%, 100%, 0.5)")
    }

    func testContrastCompositesAlpha() {
        // Black at 50% over white is mid grey (127.5), not black on white.
        let t = run("rgba(0,0,0,0.5) on white")?.first
        XCTAssertEqual(t?.title, "3.98:1")
        XCTAssertNotEqual(t?.title, "21:1")
        // Translucent background is composited over white first.
        XCTAssertEqual(run("black on rgba(0,0,0,0.5)")?.first?.title, "5.28:1")
        XCTAssertTrue(t?.subtitle.contains("composited") ?? false)
        XCTAssertFalse(run("#fff on #000")?.first?.subtitle.contains("composited") ?? true)
    }

    func testContrastLocalised() {
        XCTAssertEqual(run("#fff on #000", lang: "es_ES")?.first?.subtitle, "AA aprobado, AA grande aprobado, AAA aprobado, AAA grande aprobado")
        XCTAssertTrue(run("#777 on white", lang: "sv_SE")?.first?.subtitle.contains("underkänt") ?? false)
        XCTAssertEqual(run("#fff on #000")?.first?.subtitle, "AA pass, AA large pass, AAA pass, AAA large pass")
    }

    func testShiftLocalisedClampedDefault() {
        XCTAssertEqual(run("lighten #336699 20%")?.first?.subtitle, "HEX, lightened by 20%")
        XCTAssertEqual(run("lighten #336699 20%", lang: "es_ES")?.first?.subtitle, "HEX, aclarado en 20%")
        XCTAssertEqual(run("darken #336699 20%", lang: "sv_SE")?.first?.subtitle, "HEX, mörkare med 20%")
        XCTAssertEqual(run("lighten black 150%")?.first?.subtitle, "HEX, lightened by 100%")
        XCTAssertEqual(run("lighten red")?.first?.title, run("lighten red 10%")?.first?.title)
        XCTAssertEqual(run("darken red")?.first?.title, "#cc0000")
        XCTAssertNil(run("lighten #zzz"))
    }

    func testHsvaTarget() {
        XCTAssertEqual(one("red to hsva"), "hsva(0, 100%, 100%, 1)")
        XCTAssertEqual(one("#ff000080 to hsva"), "hsva(0, 100%, 100%, 0.5)")
    }
}
