import XCTest
@testable import CalcCore

final class PxEmRemTests: XCTestCase {
    private func run(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? {
        miscBlockingEvaluate(PxEmRemTool(), q, s)
    }

    func testGoldenCases() {
        let cases = [("16px to rem", "1rem"), ("1.5rem to px", "24px"), ("24px to em", "1.5em"),
                     ("2em to px", "32px"), ("16px to pt", "12pt")]
        for (q, expected) in cases {
            let items = run(q)
            XCTAssertEqual(items?.map(\.title), [expected], q)
            XCTAssertEqual(items?.first?.arg, expected, q)
        }
    }

    func testNoTargetListsOthers() {
        XCTAssertEqual(run("16px")?.map(\.title), ["1em", "1rem", "12pt"])
        XCTAssertEqual(run("2rem")?.map(\.title), ["32px", "2em", "24pt"])
    }

    func testBase() {
        XCTAssertEqual(run("18px to em base 20px")?.map(\.title), ["0.9em"])
        XCTAssertEqual(run("2rem to px base 18px")?.map(\.title), ["36px"])
        XCTAssertEqual(run("18px base 20px")?.map(\.title), ["0.9em", "0.9rem", "13.5pt"])
        var s = Settings(); s.basePixels = 10
        XCTAssertEqual(run("20px to rem", s)?.map(\.title), ["2rem"])
        XCTAssertEqual(run("12pt to px")?.map(\.title), ["16px"])
        XCTAssertEqual(run("1px to rem")?.map(\.title), ["0.0625rem"])
    }

    func testNotOurs() {
        for q in ["10 km to mi", "16 to rem", "16px to mb", "base 20px", "px", "10 gb to mb"] {
            let items = run(q)
            XCTAssertNil(items, q)
        }
    }
}
