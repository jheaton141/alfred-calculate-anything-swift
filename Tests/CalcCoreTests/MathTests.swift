import XCTest
@testable import CalcCore

final class MathTests: XCTestCase {
    private func run(_ q: String, _ s: Settings = Settings()) -> [AlfredItem]? {
        miscBlockingEvaluate(MathTool(), q, s)
    }
    private func title(_ q: String, _ s: Settings = Settings()) -> String? { run(q, s)?.first?.title }

    func testGoldenCases() {
        let t1 = title("10 + 5"), t2 = title("2 * 3"), t3 = title("10 / 4")
        let t4 = title("2 ^ 3"), t5 = title("sqrt(16)")
        XCTAssertEqual([t1, t2, t3, t4, t5], ["15", "6", "2.5", "8", "4"])
    }

    func testPrecedenceAndAssociativity() {
        let r = [title("2 + 3 * 4"), title("(2 + 3) * 4"), title("2 ^ 3 ^ 2"), title("-2 ^ 2"),
                 title("2 ^ -1"), title("10 - 4 - 3"), title("100 / 10 / 5"), title("--3 + 1"),
                 title("10 % 4"), title("2 * -3"), title("2 ** 3")]
        XCTAssertEqual(r, ["14", "20", "512", "-4", "0.5", "3", "2", "4", "2", "-6", "8"])
    }

    func testFunctionsAndConstants() {
        let r = [title("abs(-5) + 1"), title("round(2.6) + 0"), title("floor(2.9) + 0"), title("ceil(2.1) + 0"),
                 title("ln(e)"), title("log(1000)"), title("sin(0) + 1"), title("cos(0) * 2"),
                 title("pi * 2"), title("tan(0) + 5"), title("sqrt(2)")]
        XCTAssertEqual(r, ["6", "3", "2", "3", "1", "3", "1", "2", "6.28", "5", "1.41"])
        XCTAssertEqual(run("pi * 2")?.first?.mods?.cmd?.arg, "6.2831853072")
    }

    func testSuffixes() {
        let r = [title("2k * 3"), title("1.5M + 0"), title("2B / 4"), title("1T / 1M"), title("3K"), title("2k")]
        XCTAssertEqual(r, ["6,000", "1,500,000", "500,000,000", "1,000,000", "3,000", "2,000"])
    }

    func testSeparators() {
        XCTAssertEqual(title("1,000 + 234.5"), "1,234.5")
        var s = Settings(); s.decimalSeparator = ","; s.thousandsSeparator = "."
        XCTAssertEqual(title("1.234,5 * 2", s), "2.469")
        XCTAssertEqual(title("0,5 + 0,25", s), "0,75")
    }

    func testErrors() {
        for q in ["1 / 0", "5 % 0", "1 / (2 - 2)", "sqrt(-1)", "ln(0)", "0 ^ -1"] {
            let items = run(q)
            XCTAssertEqual(items?.count, 1, q)
            XCTAssertEqual(items?.first?.valid, false, q)
        }
        XCTAssertEqual(title("1/0"), "Cannot divide by zero")
    }

    func testNil() {
        for q in ["10", "-5", "(5)", "pi", "e", "", "hello", "10 km to mi", "2 +", "(1 + 2", "1 + 2)", "20% of 150",
                  "100 vat", "5 m", "2e", "foo(3)", "sqrt 4", "1 2", "10 gb to mb", "..", "5m"] {
            let items = run(q)
            XCTAssertNil(items, q)
        }
    }
}
