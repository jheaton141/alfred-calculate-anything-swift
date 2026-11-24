import XCTest
@testable import CalcCore

final class ColorFixTests: XCTestCase {
    private typealias C = ColorMath.RGBA

    private func sampleColours() -> [C] {
        var out: [C] = []
        // Every dark colour (where the 2-decimal xyz output was too coarse) plus a coarse lattice and a seeded pseudo-random walk.
        for r in 0..<16 { for g in 0..<16 { for b in 0..<16 { out.append(C(r: r, g: g, b: b)) } } }
        for r in stride(from: 0, through: 255, by: 15) { for g in stride(from: 0, through: 255, by: 15) {
            for b in stride(from: 0, through: 255, by: 15) { out.append(C(r: r, g: g, b: b)) } } }
        var s: UInt64 = 12345
        for _ in 0..<6000 {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let v = Int(s >> 40)
            out.append(C(r: v & 255, g: (v >> 8) & 255, b: (v >> 16) & 255))
        }
        return out
    }

    func testXYZRoundTripsExactly() {
        var bad: [String] = []
        for c in sampleColours() {
            let s = ColorMath.format(c, "xyz")
            guard let back = ColorMath.parse(s, allowBareHex: false), back.r == c.r, back.g == c.g, back.b == c.b else {
                bad.append("\(c) -> \(s)"); continue
            }
        }
        XCTAssertTrue(bad.isEmpty, "\(bad.count) failed, e.g. \(bad.prefix(3))")
    }

    func testXYZReferenceStaysShort() {
        XCTAssertEqual(ColorMath.format(C(r: 255, g: 255, b: 255), "xyz"), "color(xyz 0.9505 1 1.0888)")
    }

    func testAlphaSurvivesEverySpace() {
        let c = C(r: 255, g: 0, b: 0, a: 0.5)
        for space in ["hsv", "hwb", "cmyk", "lab", "lch", "xyz", "hsl", "rgb", "hex"] {
            let s = ColorMath.format(c, space)
            let back = ColorMath.parse(s, allowBareHex: false)
            XCTAssertEqual(back?.a ?? -1, 0.5, accuracy: 0.005, "\(space): \(s)")
            XCTAssertEqual(back?.r, 255, s); XCTAssertEqual(back?.g, 0, s); XCTAssertEqual(back?.b, 0, s)
        }
        XCTAssertEqual(ColorMath.format(c, "hsv"), "hsva(0, 100%, 100%, 0.5)")
        XCTAssertEqual(ColorMath.format(c, "hwb"), "hwb(0, 0%, 0%, 0.5)")
        XCTAssertEqual(ColorMath.format(c, "cmyk"), "cmyk(0%, 100%, 100%, 0%, 0.5)")
        XCTAssertEqual(ColorMath.format(c, "lab"), "lab(53.24% 80.09 67.2 / 0.5)")
    }

    func testOpaqueOutputHasNoAlpha() {
        let c = C(r: 255, g: 0, b: 0)
        for space in ["hsv", "hwb", "cmyk", "lab", "lch", "xyz"] {
            XCTAssertFalse(ColorMath.format(c, space).contains("/"), space)
        }
        XCTAssertEqual(ColorMath.format(c, "hsv"), "hsv(0, 100%, 100%)")
    }

    func testAlphaParsedFromEveryFunction() {
        for q in ["hsva(0, 100%, 100%, 0.5)", "hwb(0 0% 0% / 0.5)", "cmyk(0%, 100%, 100%, 0%, 0.5)",
                  "lab(53.24% 80.09 67.2 / 0.5)", "lch(53.24% 104.55 40 / 0.5)", "color(xyz 41.24 21.27 1.93 / 0.5)"] {
            XCTAssertEqual(ColorMath.parse(q, allowBareHex: false)?.a ?? -1, 0.5, accuracy: 0.001, q)
        }
    }

    func testToolCarriesAlpha() {
        let items = miscBlockingEvaluate(ColorTool(), "#ff000080 to hsv", Settings())
        XCTAssertEqual(items?.first?.title, "hsva(0, 100%, 100%, 0.5)")
        let xyz = miscBlockingEvaluate(ColorTool(), "#ff000080 to xyz", Settings())
        XCTAssertTrue(xyz?.first?.title.hasSuffix("/ 0.5)") ?? false)
    }
}
