import XCTest
@testable import CalcCore

final class VerifyFixUnitsTests: XCTestCase {
    private func units(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? { miscBlockingEvaluate(UnitsTool(), q, s) }
    private func data(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? { miscBlockingEvaluate(DataStorageTool(), q, s) }
    private func px(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? { miscBlockingEvaluate(PxEmRemTool(), q, s) }
    private func radix(_ q: String) -> [AlfredItem]? { miscBlockingEvaluate(RadixTool(), q, Settings()) }

    private func assertInvalid(_ items: [AlfredItem]?, _ q: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(items?.count, 1, q, file: file, line: line)
        XCTAssertEqual(items?.first?.valid, false, q, file: file, line: line)
        XCTAssertEqual(items?.first?.title, "Invalid input", q, file: file, line: line)
    }

    private func assertFast(_ q: String, file: StaticString = #filePath, line: UInt = #line) {
        let t = Date()
        _ = units(q); _ = data(q); _ = px(q)
        XCTAssertLessThan(Date().timeIntervalSince(t), 0.15, String(q.prefix(30)), file: file, line: line)
    }

    // 1
    func testDataStorageTinyValues() {
        for q in ["1 b to gb", "1 kb to tb", "1 kb to pb"] {
            let r = data(q)?.first
            XCTAssertNotEqual(r?.title.hasPrefix("0 "), true, q)
            XCTAssertTrue(r?.title.contains("e-") == true, q)
            let raw = r?.mods?.cmd?.arg ?? "0"
            XCTAssertNotEqual(Double(raw), 0, q)
        }
        XCTAssertEqual(Double(data("1 b to gb")?.first?.mods?.cmd?.arg ?? ""), 1e-9)
    }

    // 2
    func testUnitsTinyRawCopy() {
        for (q, expected) in [("1 pm to ly", 1.0e-12 / 9_460_730_472_580_800), ("1 ev to kj", 1.602176634e-22)] {
            let r = units(q)?.first
            XCTAssertTrue(r?.title.contains("e-") == true, q)
            let raw = Double(r?.mods?.cmd?.arg ?? "") ?? 0
            XCTAssertEqual(raw / expected, 1, accuracy: 1e-9, q)
        }
    }

    // 3
    func testOverflowIsInvalid() {
        assertInvalid(units("1e308 km to m"), "1e308 km to m")
        assertInvalid(data("1e300 yb to b"), "1e300 yb to b")
        assertInvalid(px("1e308rem to px"), "1e308rem to px")
        assertInvalid(units(String(repeating: "9", count: 10_000) + " km to m"), "10k digits units")
        assertInvalid(data(String(repeating: "9", count: 10_000) + " gb to mb"), "10k digits data")
        assertInvalid(px(String(repeating: "9", count: 10_000) + "px to rem"), "10k digits px")
        assertInvalid(units("1e999 km to m"), "1e999 km to m")
    }

    func testHugeValuesHaveNoFloatNoise() {
        XCTAssertEqual(data("1 yb to b")?.first?.title, "1,000,000,000,000,000,000,000,000 B")
        XCTAssertEqual(data("1 yb to b")?.first?.mods?.cmd?.arg, "1000000000000000000000000")
        XCTAssertEqual(units("1 light year to km")?.first?.title, "9,460,730,472,580.8 km")
        XCTAssertEqual(units("1 km to nm")?.first?.title, "1,000,000,000,000 nm")
        XCTAssertEqual(units("1 ly to mm")?.first?.title, "9,460,730,472,580,800,000 mm")
    }

    // 4
    func testBelowAbsoluteZero() {
        for q in ["-300 c to k", "-273.15 k to c", "-500 f to c", "-300 c to f"] { assertInvalid(units(q), q) }
        XCTAssertEqual(units("-273.15 c to k")?.first?.title, "0 k")
        XCTAssertEqual(units("0 k to c")?.first?.title, "-273.15 c")
        XCTAssertEqual(units("-459.67 f to k")?.first?.title, "0 k")
    }

    // 5
    func testBitUnits() {
        XCTAssertEqual(data("1 mbit to kbit")?.first?.title, "1,000 kbit")
        XCTAssertEqual(data("8 gbit to gb")?.first?.title, "1 GB")
        XCTAssertEqual(data("8 kbit to b")?.first?.title, "1,000 B")
        XCTAssertEqual(data("1 tbit to gbit")?.first?.title, "1,000 Gbit")
        XCTAssertEqual(data("1 kibit to bit")?.first?.title, "1,024 bit")
        XCTAssertEqual(data("1 megabit to kilobits")?.first?.title, "1,000 kbit")
    }

    // 6
    func testLongQueriesAreFast() {
        assertFast("5 " + String(repeating: "km ", count: 2000) + "to mi")
        assertFast("5 km " + String(repeating: "to ", count: 3000) + "mi")
        assertFast(String(repeating: "5\t", count: 5000) + "km to m")
        assertFast("5" + String(repeating: "mb ", count: 3000) + "to gb")
        assertFast("1" + String(repeating: "e", count: 10_000) + " m to km")
        XCTAssertNil(units("5 " + String(repeating: "km ", count: 2000) + "to mi"))
    }

    // 7
    func testPxEmRem() {
        XCTAssertEqual(px("-16px to rem")?.map(\.title), ["-1rem"])
        XCTAssertEqual(px("-16px")?.first?.title, "-1em")
        XCTAssertEqual(px("1rem=px")?.map(\.title), ["16px"])
        XCTAssertEqual(px("1rem = px")?.map(\.title), ["16px"])
        XCTAssertEqual(px("1em=pt")?.map(\.title), ["12pt"])
        var s = Settings(); s.basePixels = 0
        XCTAssertEqual(px("2rem to px", s)?.map(\.title), ["32px"])
        s.basePixels = -4
        XCTAssertEqual(px("2rem to px", s)?.map(\.title), ["32px"])
        XCTAssertEqual(px("2rem to px base 0px")?.map(\.title), ["32px"])
        var c = Settings(); c.decimalSeparator = ","; c.thousandsSeparator = "."
        XCTAssertEqual(px("1px to rem", c)?.map(\.title), ["0,0625rem"])
        XCTAssertEqual(px("1px to rem", c)?.first?.mods?.cmd?.arg, "0.0625")
        var d = Settings(); d.decimals = 10
        XCTAssertEqual(px("1px to rem base 3px", d)?.map(\.title), ["0.3333333333rem"])
        let r = px("16px to rem")?.first
        XCTAssertEqual(r?.mods?.alt?.arg, "1rem")
        XCTAssertEqual(r?.mods?.cmd?.arg, "1")
    }

    // 8
    func testRadixUnderscoreAndPlus() {
        XCTAssertEqual(radix("1_000 to hex")?.first?.title, "0x3e8")
        XCTAssertEqual(radix("+255 to hex")?.first?.title, "0xff")
        XCTAssertEqual(radix("0xff_ff to dec")?.first?.title, "65535")
        XCTAssertEqual(radix("1111_0000 bin to hex")?.first?.title, "0xf0")
        XCTAssertEqual(radix("+0xff to dec")?.first?.title, "255")
        for q in ["1__0 to hex", "1_ to hex", "0x_ff to dec"] {
            XCTAssertEqual(radix(q)?.first?.valid, false, q)
        }
        XCTAssertNil(radix("ff to dec"))
        XCTAssertNil(radix("_ to hex"))
        XCTAssertEqual(radix("-5 to hex")?.first?.valid, false)
    }
}
