import XCTest
@testable import CalcCore

private func titles(_ tool: Tool, _ q: String, _ s: Settings = Settings()) -> [String]? {
    final class Box: @unchecked Sendable { var value: [AlfredItem]? }
    let box = Box(), done = DispatchSemaphore(value: 0)
    let ctx = Context(settings: s, dataDir: URL(fileURLWithPath: "/tmp"))
    Task.detached { box.value = await tool.evaluate(q, context: ctx); done.signal() }
    done.wait()
    return box.value?.map(\.title)
}

final class FractionToolTests: XCTestCase {
    private func f(_ q: String) -> [String]? { titles(FractionTool(), q) }

    func testArithmetic() {
        XCTAssertEqual(f("1/3 + 1/4")?.first, "7/12")
        XCTAssertEqual(f("1 1/2 * 3"), ["9/2", "4 1/2", "4.5"])
        XCTAssertEqual(f("frac 3/4 / 1/2")?.first, "3/2")
        XCTAssertNil(f("1/2 / 1/4"))   // spaced division stays with the math tool
        XCTAssertEqual(f("1/2 - 3/4")?.first, "-1/4")
        XCTAssertEqual(f("(1/2 + 1/3) * 6"), ["5"])
        XCTAssertEqual(f("3/4 of 80"), ["60"])
    }

    func testConversions() {
        XCTAssertEqual(f("0.75 to fraction")?.first, "3/4")
        XCTAssertEqual(f("simplify 6/8")?.first, "3/4")
        XCTAssertEqual(f("0.3333333 to fraction")?.last, "≈ 1/3")
        XCTAssertEqual(f("frac 10/4")?.first, "5/2")
    }

    func testNotMine() {
        XCTAssertNil(f("10/4"))
        XCTAssertNil(f("1/2/2026 + 1/2"))
        XCTAssertNil(f("1/2 + 1/3 cm"))
        XCTAssertNil(f("2 + 3"))
    }

    func testReviewFixes() {
        XCTAssertNil(f("fraction " + String(repeating: "-", count: 1500) + "1/2"))
        XCTAssertNil(f(String(repeating: "(", count: 100) + "1/2 + 1/3" + String(repeating: ")", count: 100)))
        XCTAssertNil(f("0x10/2 + 1/4"))
        XCTAssertNil(f("999999999999999/7 * 999999999999999/11"))
        var comma = Settings(); comma.decimalSeparator = ","
        XCTAssertNil(titles(FractionTool(), "1.000 + 1/2 + 1/2", comma))
        XCTAssertEqual(titles(FractionTool(), "0,75 to fraction", comma)?.first, "3/4")
        XCTAssertEqual(f("0.333333 to fraction")?.last, "≈ 1/3")
        XCTAssertEqual(f("2 x 3/4 + 1/4")?.first, "7/4")
    }

    func testErrors() {
        XCTAssertEqual(f("1/0 + 1/2"), ["Cannot divide by zero"])
        XCTAssertEqual(f("frac 1/2 / 0/1"), ["Cannot divide by zero"])
        XCTAssertEqual(f("frac 99999999999/3 * 99999999999/7"), ["Invalid input"])
        XCTAssertNil(f("99999999999/3 * 99999999999/7"))
    }
}

final class InterestToolTests: XCTestCase {
    private func i(_ q: String) -> [String]? { titles(InterestTool(), q) }

    func testCompound() {
        XCTAssertEqual(i("1000 at 5% for 10 years"), ["Final balance 1,628.89", "Interest earned 628.89", "Effective annual rate 5%"])
        XCTAssertEqual(i("1000 at 5% for 10 years continuously")?.first, "Final balance 1,648.72")
        XCTAssertEqual(i("1000 at 5% for 6 months")?.first, "Final balance 1,024.7")
        XCTAssertEqual(i("1000 at 0% for 5 years")?.first, "Final balance 1,000")
    }

    func testDeposits() {
        let r = i("invest 5000 at 4.5% for 30 years monthly adding 200 per month")
        XCTAssertEqual(r?.first, "Final balance 171,115.72")
        XCTAssertEqual(r?[2], "Total paid in 77,000")
    }

    func testGuards() {
        XCTAssertEqual(i("1000 at 5% for 0 years"), ["Invalid input"])
        XCTAssertNil(i("1000 at 5%"))
        XCTAssertNil(i("tip 85"))
    }
}

final class DiscountToolTests: XCTestCase {
    private func d(_ q: String) -> [String]? { titles(DiscountTool(), q) }

    func testTax() {
        XCTAssertEqual(d("80 plus 8% tax"), ["Total 86.4", "Tax 6.4"])
        XCTAssertEqual(d("8% tax on 80"), ["Total 86.4", "Tax 6.4"])
        XCTAssertEqual(d("tax 8% on 80"), ["Total 86.4", "Tax 6.4"])
        XCTAssertEqual(d("tax 80 at 8%"), ["Total 86.4", "Tax 6.4"])
        XCTAssertEqual(d("108 incl 8% tax"), ["Before tax 100", "Tax 8", "Total 108"])
    }

    func testDiscounts() {
        XCTAssertEqual(d("20% + 10% off 100"), ["Sale price 72", "You save 28"])
        XCTAssertEqual(d("20% off 80 plus 8% tax"), ["Total with tax 69.12", "Sale price 64", "You save 16"])
        XCTAssertNil(d("20% off 80"))
        XCTAssertEqual(d("was 80 now 60"), ["Discount 25%", "You save 20"])
        XCTAssertEqual(d("was 60 now 80")?.first, "Increase 33.33%")
    }

    func testMargins() {
        XCTAssertEqual(d("cost 60 price 100"), ["Profit 40", "Margin 40%", "Markup 66.67%"])
        XCTAssertEqual(d("cost 60 markup 50%"), ["Price 90", "Profit 30", "Margin 33.33%"])
        XCTAssertEqual(d("cost 60 margin 40%"), ["Price 100", "Profit 40", "Markup 66.67%"])
        XCTAssertEqual(d("price 100 margin 40%"), ["Cost 60", "Profit 40", "Markup 66.67%"])
    }

    func testReviewFixes() {
        XCTAssertEqual(d("cost 0 price 80"), ["Profit 80", "Margin 100%"])
        XCTAssertEqual(d("was 1e-320 now 5"), ["Invalid input"])
        var comma = Settings(); comma.decimalSeparator = ","
        XCTAssertEqual(titles(DiscountTool(), "cost 60 markup 50%", comma)?.last, "Margin 33,33%")
        XCTAssertEqual(titles(InterestTool(), "1000 at 5,5% for 10 years", comma)?.last, "Effective annual rate 5,5%")
    }

    func testGuards() {
        XCTAssertEqual(d("cost 60 margin 100%"), ["Invalid input"])
        XCTAssertEqual(d("cost 0 markup 50%"), ["Invalid input"])
        XCTAssertNil(d("cost 60"))
        XCTAssertNil(d("2 + 2"))
    }
}

final class ReviewRoundTwoTests: XCTestCase {
    func testLongInputIsRejectedFast() {
        let long = String(repeating: "1", count: 20_000)
        XCTAssertNil(titles(InterestTool(), long))
        XCTAssertNil(titles(DiscountTool(), long))
    }

    func testFromToIsNotAPriceChange() {
        XCTAssertNil(titles(DiscountTool(), "from 10 to 20"))
        XCTAssertEqual(titles(DiscountTool(), "was 80 now 60")?.first, "Discount 25%")
    }

    func testBareLakhShowsNumber() async {
        let out = await Engine(tools: DefaultEngine.tools()).run("10 lakh", context: Context(settings: Settings(), dataDir: URL(fileURLWithPath: "/tmp")))
        XCTAssertEqual(out.items.first?.title, "1,000,000")
    }
}
