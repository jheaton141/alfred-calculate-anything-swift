import XCTest
@testable import CalcCore

final class RadixTests: XCTestCase {
    private func run(_ q: String) -> [AlfredItem]? { miscBlockingEvaluate(RadixTool(), q, Settings()) }

    func testConversions() {
        let cases: [(String, String, String)] = [
            ("255 to hex", "0xff", "ff"), ("255 in binary", "0b11111111", "11111111"),
            ("255 to octal", "0o377", "377"), ("0xff to dec", "255", "255"),
            ("ff hex to decimal", "255", "255"), ("0b1010 to decimal", "10", "10"),
            ("0o17 to dec", "15", "15"), ("hex ff to bin", "0b11111111", "11111111"),
            ("1010 binary to hex", "0xa", "a"), ("0 to hex", "0x0", "0"),
            ("18446744073709551615 to hex", "0xffffffffffffffff", "ffffffffffffffff"),
            ("0XFF TO DEC", "255", "255"), ("255 as hex", "0xff", "ff"),
        ]
        for (q, title, arg) in cases {
            let items = run(q)
            XCTAssertEqual(items?.count, 1, q)
            XCTAssertEqual(items?.first?.title, title, q)
            XCTAssertEqual(items?.first?.arg, arg, q)
            XCTAssertEqual(items?.first?.valid, true, q)
        }
        XCTAssertEqual(run("255 to hex")?.first?.mods?.cmd?.arg, "0xff")
    }

    func testRejections() {
        for q in ["-5 to hex", "1.5 to hex", "18446744073709551616 to hex", "2 binary to dec", "0xfg to dec", "0b102 to dec"] {
            let items = run(q)
            XCTAssertEqual(items?.count, 1, q)
            XCTAssertEqual(items?.first?.valid, false, q)
        }
    }

    func testNotOurs() {
        for q in ["ff", "ff to hex", "#ff8800", "255", "1 bin to usd", "10 gb to mb", "10 to usd", "5 + 5", "hex", "to hex",
                  "10 km to hex", "ff hex", "255 to blue", "hello to hex"] {
            XCTAssertNil(run(q), q)
        }
    }

    func testDispatchOrder() {
        let tools = DefaultEngine.tools()
        let ctx = Context(dataDir: URL(fileURLWithPath: "/tmp"))
        func first(_ q: String) -> String? {
            final class Box: @unchecked Sendable { var v: String? }
            let b = Box(), done = DispatchSemaphore(value: 0)
            Task.detached {
                for t in tools { if await t.evaluate(q, context: ctx) != nil { b.v = t.name; break } }
                done.signal()
            }
            done.wait()
            return b.v
        }
        XCTAssertEqual(first("255 to hex"), "radix")
        XCTAssertEqual(first("0xff to dec"), "radix")
        XCTAssertNotEqual(first("10 gb to mb"), "radix")
        XCTAssertNotEqual(first("1 bin to usd"), "radix")
        XCTAssertNotEqual(first("#ff8800"), "radix")
        XCTAssertNotEqual(first("10 km to m"), "radix")
        XCTAssertNotEqual(first("100 usd to eur"), "radix")
        XCTAssertNotEqual(first("5 + 5"), "radix")
    }
}
