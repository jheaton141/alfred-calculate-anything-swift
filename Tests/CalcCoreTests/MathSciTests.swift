import XCTest
@testable import CalcCore

final class MathSciTests: XCTestCase {
    private func run(_ q: String) -> [AlfredItem]? { miscBlockingEvaluate(MathTool(), q, Settings()) }
    private func title(_ q: String) -> String? { run(q)?.first?.title }

    func testScientificLiterals() {
        XCTAssertEqual(title("1.5e3"), "1,500")
        XCTAssertEqual(title("2e-3"), "0.002")
        XCTAssertEqual(title("1E5"), "100,000")
        XCTAssertEqual(title("1.5e+3 + 1"), "1,501")
        XCTAssertEqual(title("6.02e23 * 2"), "1.204e+24")
    }

    func testConstantAndExpStillWork() {
        XCTAssertEqual(title("2 * e"), "5.44")
        XCTAssertEqual(title("2e"), nil)
        XCTAssertEqual(title("2 * exp(0)"), "2")
        XCTAssertEqual(title("ln(e)"), "1")
        XCTAssertEqual(title("2e + 1"), nil)
    }

    func testLargeAndSmallDisplay() {
        XCTAssertEqual(title("10^15 + 0"), "1e+15")
        XCTAssertEqual(title("10^14 + 0"), "100,000,000,000,000")
        XCTAssertEqual(title("1 / 10^10"), "1e-10")
        XCTAssertEqual(title("1 / 10^8"), "0.00000001")
        let item = run("6.02e23 * 2")?.first
        XCTAssertEqual(item?.arg, "1.204e+24")
        XCTAssertTrue(item?.mods?.cmd?.arg.hasPrefix("12039999") == true || item?.mods?.cmd?.arg.hasPrefix("1204") == true)
        XCTAssertEqual(run("1 / 10^10")?.first?.mods?.cmd?.arg, "1e-10")
    }

    func testFactorial() {
        XCTAssertEqual(title("5!"), "120")
        XCTAssertEqual(title("(3+2)!"), "120")
        XCTAssertEqual(title("0! + 0"), "1")
        XCTAssertEqual(title("3! + 4!"), "30")
        XCTAssertEqual(title("2 * 3!"), "12")
        XCTAssertEqual(title("20!"), "2.432902008e+18")
        XCTAssertTrue(title("170!")?.contains("e+306") == true)
        XCTAssertEqual(title("171!"), "Invalid input")
        XCTAssertEqual(title("(-1)!"), "Invalid input")
        XCTAssertEqual(title("2.5!"), "Invalid input")
        XCTAssertNil(title("5 != 3"))
        XCTAssertNil(title("hello!"))
        XCTAssertNil(title("5"))
    }
}
