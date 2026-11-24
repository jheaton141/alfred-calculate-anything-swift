import XCTest
@testable import CalcCore

final class ColorTests: XCTestCase {
    private func run(_ q: String) -> [AlfredItem]? { miscBlockingEvaluate(ColorTool(), q, Settings()) }
    private func one(_ q: String) -> String? { run(q)?.first?.title }

    func testGoldenRow() {
        let items = run("#00ff00 rgb")
        XCTAssertEqual(items?.map(\.title), ["rgb(0, 255, 0)"])
        XCTAssertEqual(items?.first?.arg, "rgb(0, 255, 0)")
    }

    func testReferenceColours() {
        XCTAssertEqual(one("#ff0000 to rgb"), "rgb(255, 0, 0)")
        XCTAssertEqual(one("#ff0000 to hsl"), "hsl(0, 100%, 50%)")
        XCTAssertEqual(one("#ff0000 to cmyk"), "cmyk(0%, 100%, 100%, 0%)")
        XCTAssertEqual(one("#ff0000 to hsv"), "hsv(0, 100%, 100%)")
        XCTAssertEqual(one("#ff0000 to hwb"), "hwb(0, 0%, 0%)")
        XCTAssertEqual(one("#ff0000 to lab"), "lab(53.24% 80.09 67.2)")
        XCTAssertEqual(one("#808080 to hsl"), "hsl(0, 0%, 50%)")
        XCTAssertEqual(one("white to hsl"), "hsl(0, 0%, 100%)")
        XCTAssertEqual(one("black to cmyk"), "cmyk(0%, 0%, 0%, 100%)")
        XCTAssertEqual(one("#1e90ff to hsl"), "hsl(209.6, 100%, 55.9%)")
        XCTAssertEqual(one("#1e90ff to rgb"), "rgb(30, 144, 255)")
        XCTAssertEqual(one("dodgerblue to hex"), "#1e90ff")
        XCTAssertEqual(one("rgb(255,0,0) to hex"), "#ff0000")
        // hsl(210,100%,56%) is (0.12, 0.56, 1) of 255 = (30.6, 142.8, 255), rounded.
        XCTAssertEqual(one("hsl(210, 100%, 56%) to hex"), "#1f8fff")
        XCTAssertEqual(one("red to hsl"), "hsl(0, 100%, 50%)")
        XCTAssertEqual(one("#f00 hex"), "#ff0000")
        XCTAssertEqual(one("ff8000 to rgb"), "rgb(255, 128, 0)")
        XCTAssertEqual(one("#ff000080 to rgb"), "rgba(255, 0, 0, 0.5)")
        XCTAssertEqual(one("rgba(255,0,0,0.5) to hex"), "#ff000080")
        XCTAssertEqual(one("hsb(120, 100%, 100%) to hex"), "#00ff00")
        XCTAssertEqual(one("hwb(0 0% 0%) to hex"), "#ff0000")
        XCTAssertEqual(one("cmyk(0%, 100%, 100%, 0%) to hex"), "#ff0000")
        XCTAssertEqual(one("lab(53.24% 80.09 67.2) to hex"), "#ff0000")
        XCTAssertEqual(one("white to xyz"), "color(xyz 95.05 100 108.88)")
    }

    func testBareColourListsAllSpaces() {
        let items = run("#1e90ff")
        XCTAssertEqual(items?.map(\.subtitle), ["HEX", "RGB", "HSL", "HSV", "HWB", "CMYK", "LAB", "LCH", "XYZ"])
        XCTAssertEqual(items?[1].title, "rgb(30, 144, 255)")
        XCTAssertEqual(run("red")?.count, 9)
        XCTAssertEqual(run("rgb(255,0,0)")?.first?.title, "#ff0000")
    }

    func testNamedTable() {
        XCTAssertEqual(ColorNames.table.count, 148)
        let known = ["rebeccapurple": "663399", "tomato": "ff6347", "teal": "008080", "gold": "ffd700",
                     "lime": "00ff00", "navy": "000080", "salmon": "fa8072", "khaki": "f0e68c"]
        for (n, h) in known { XCTAssertEqual(ColorNames.table[n], h, n) }
    }

    func testNamedRoundTripHexRgbHslHex() {
        for (name, hex) in ColorNames.table {
            let h = "#" + hex
            guard let rgb = one("\(h) to rgb"), let hsl = one("\(rgb) to hsl"), let back = one("\(hsl) to hex") else {
                XCTFail(name); continue
            }
            XCTAssertEqual(back, h, "\(name): \(rgb) -> \(hsl)")
            for space in ["hsv", "hwb", "cmyk"] {
                guard let s = one("\(h) to \(space)") else { XCTFail("\(name) \(space)"); continue }
                XCTAssertEqual(one("\(s) to hex"), h, "\(name) via \(space): \(s)")
            }
        }
    }

    func testSampleRoundTrip() {
        for v in stride(from: 0, through: 255, by: 5) {
            let h = String(format: "#%02x%02x%02x", v, 255 - v, (v * 7) % 256)
            XCTAssertEqual(one("\(one("\(h) to hsl")!) to hex"), h)
        }
    }

    func testContrast() {
        let bw = run("#fff on #000")?.first
        XCTAssertEqual(bw?.title, "21:1")
        XCTAssertEqual(bw?.subtitle, "AA pass, AA large pass, AAA pass, AAA large pass")
        XCTAssertEqual(run("contrast white vs black")?.first?.title, "21:1")
        XCTAssertEqual(run("#fff on #fff")?.first?.title, "1:1")
        // #777777 on white is 4.48:1, just below the AA threshold.
        let grey = run("#777 on white")?.first
        XCTAssertEqual(grey?.title, "4.48:1")
        XCTAssertEqual(grey?.subtitle, "AA fail, AA large pass, AAA fail, AAA large fail")
        XCTAssertEqual(run("#595959 on white")?.first?.subtitle, "AA pass, AA large pass, AAA pass, AAA large pass")
    }

    func testLightenDarken() {
        XCTAssertEqual(run("lighten #336699 20%")?.map(\.title), ["#6699cc", "rgb(102, 153, 204)", "hsl(210, 50%, 60%)"])
        XCTAssertEqual(run("darken #336699 20%")?.first?.title, "#1a334d")
        XCTAssertEqual(run("lighten black 150%")?.first?.title, "#ffffff")
        XCTAssertEqual(run("darken red by 10")?.first?.title, "#cc0000")
    }

    func testNotOurs() {
        for q in ["red 5", "10 km", "5 + 5", "#", "100", "16px to rem", "1e90ff", "#12345", "rgb(1,2) to hex",
                  "#ff0000 to foo", "ff to rgb", "foo to hex", "lighten #zzz 5%"] {
            XCTAssertNil(run(q), q)
        }
    }
}
