import XCTest
@testable import CalcCore

final class DataStorageTests: XCTestCase {
    private func run(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? {
        miscBlockingEvaluate(DataStorageTool(), q, s)
    }

    func testGoldenCases() {
        let cases: [(String, String, String)] = [
            ("10 gb to mb", "10,000 MB", "10,000"), ("1 tb to gb", "1,000 GB", "1,000"),
            ("1024 kb to mb", "1.024 MB", "1.024"), ("500 mb to gb", "0.5 GB", "0.5"),
            ("1 gib to mib", "1,024 MiB", "1,024"), ("2 pb to tb", "2,000 TB", "2,000"),
        ]
        for (q, title, copy) in cases {
            let items = run(q)
            XCTAssertEqual(items?.count, 1, q)
            XCTAssertEqual(items?.first?.title, title, q)
            XCTAssertEqual(items?.first?.arg, copy, q)
        }
    }

    func testRawAndBinaryAndBits() {
        XCTAssertEqual(run("10 gb to mb")?.first?.mods?.cmd?.arg, "10000")
        XCTAssertEqual(run("1 gb to gib")?.first?.title, "0.93132257 GiB")
        XCTAssertEqual(run("1 kib to b")?.first?.title, "1,024 B")
        XCTAssertEqual(run("8 bit to b")?.first?.title, "1 B")
        XCTAssertEqual(run("2 b to bit")?.first?.title, "16 bit")
        XCTAssertEqual(run("1 b to kb")?.first?.title, "0.001 kB")
        XCTAssertEqual(run("1.5gb in mb")?.first?.title, "1,500 MB")
        XCTAssertEqual(run("1 gigabyte to megas")?.first?.title, "1,000 MB")
        XCTAssertEqual(run("1 GB mib")?.first?.title, "953.67431641 MiB")
    }

    func testCommaDecimal() {
        var s = Settings(); s.decimalSeparator = ","; s.thousandsSeparator = "."
        XCTAssertEqual(run("1,5 gb to mb", s)?.first?.title, "1.500 MB")
    }

    func testNotOurs() {
        for q in ["10 km to mi", "10 gb", "1 gb to xx", "hello", "20% of 150", "16px to rem", "5 mb to"] {
            let items = run(q)
            XCTAssertNil(items, q)
        }
    }
}

/// Runs a tool's async evaluate from a synchronous test.
func miscBlockingEvaluate(_ tool: Tool, _ query: String, _ settings: Settings) -> [AlfredItem]? {
    final class Box: @unchecked Sendable { var value: [AlfredItem]? }
    let box = Box(), done = DispatchSemaphore(value: 0)
    let ctx = Context(settings: settings, dataDir: URL(fileURLWithPath: "/tmp"))
    Task.detached { box.value = await tool.evaluate(query, context: ctx); done.signal() }
    done.wait()
    return box.value
}
