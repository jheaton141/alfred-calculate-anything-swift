import XCTest
@testable import CalcCore

final class ReviewFixLocaleTests: XCTestCase {
    private let ny = TimeZone(identifier: "America/New_York")!
    private final class Box: @unchecked Sendable { var value: [AlfredItem]? }

    private func eval(_ tool: Tool, _ q: String, lang: String = "en_EN", now: Date = Date(timeIntervalSince1970: 1_795_447_845)) -> [AlfredItem]? {
        let ctx = Context(strings: Strings.load(lang), now: now, dataDir: URL(fileURLWithPath: "/tmp"))
        let box = Box(), done = DispatchSemaphore(value: 0)
        Task.detached { box.value = await tool.evaluate(q, context: ctx); done.signal() }
        done.wait()
        return box.value
    }
    private func time(_ q: String, lang: String = "en_EN", formats: [String]? = nil, now: Date = Date(timeIntervalSince1970: 1_795_447_845)) -> [AlfredItem]? {
        var o = TimeOptions(zone: ny)
        if let f = formats { o.formats = f }
        return eval(TimeTool(options: o), q, lang: lang, now: now)
    }
    private func radix(_ q: String, lang: String = "en_EN") -> [AlfredItem]? { eval(RadixTool(), q, lang: lang) }

    // MARK: radix strings

    func testRadixKeysExistInEveryPack() {
        for (code, json) in LanguagePacks.json {
            let pack = Strings.decode(json)
            for k in ["error_radix_invalid", "radix_binary", "radix_octal", "radix_decimal", "radix_hex", "radix_copy_prefix", "radix_copy_no_prefix"] {
                XCTAssertNotNil(pack[k], "\(code).\(k)")
            }
        }
    }

    func testRadixLocalised() {
        let es = radix("255 to hex", lang: "es_ES")?.first
        XCTAssertEqual(es?.subtitle, "decimal 255 → hexadecimal")
        XCTAssertEqual(es?.mods?.cmd?.subtitle, "Copiar con prefijo 0x")
        XCTAssertEqual(radix("255 to dec", lang: "es_ES")?.first?.mods?.cmd?.subtitle, "Copiar sin prefijo")
        XCTAssertEqual(radix("0xfg to dec", lang: "es_ES")?.first?.title, "Ingresa un número entero de 0 a 18446744073709551615")
        XCTAssertEqual(radix("0xfg to dec", lang: "sv_SE")?.first?.title, "Ange ett heltal från 0 till 18446744073709551615")
        XCTAssertEqual(radix("255 to hex")?.first?.subtitle, "decimal 255 → hex")
        XCTAssertEqual(radix("255 to dec")?.first?.mods?.cmd?.subtitle, "Copy with no prefix")
    }

    // MARK: dates

    func testSpanishAndSwedishDatesHaveNoEnglishOrdinals() {
        XCTAssertEqual(time("now", lang: "es_ES")?.first?.title, "23 de noviembre de 2026, 10:30:45")
        XCTAssertEqual(time("now", lang: "sv_SE")?.first?.title, "23 november 2026, 10:30:45")
        XCTAssertEqual(time("now", lang: "es_ES", formats: ["F jS, Y"])?.first?.title, "noviembre 23, 2026")
        XCTAssertEqual(time("now", formats: ["F jS, Y"])?.first?.title, "November 23rd, 2026")
        XCTAssertEqual(time("2026-12-31", formats: ["F jS"])?.first?.title, "December 31st")
    }

    func testUntilSubtitleEchoesLocalisedDate() {
        let es = time("days until 31 december", lang: "es_ES")?.first?.subtitle ?? ""
        XCTAssertTrue(es.hasSuffix("31 de diciembre de 2026"), es)
        let sv = time("days until 31 december", lang: "sv_SE")?.first?.subtitle ?? ""
        XCTAssertTrue(sv.hasSuffix("31 december 2026"), sv)
        XCTAssertEqual(time("days until 31 december")?.first?.subtitle, "days until 31 december")
    }

    // MARK: wording

    func testSpanishWording() {
        let es = Strings.load("es_ES")
        XCTAssertTrue(es["copy_with_unit"].hasSuffix("con unidad"), es["copy_with_unit"])
        XCTAssertEqual(es["color_fail"], "no cumple")
    }

    // MARK: sub-second now

    func testRelativePhraseIgnoresSubSecondNow() {
        let base = 1_795_447_845.0
        var instants = [base.nextUp, (base + 1).nextDown, (base + 1).nextDown.nextDown, base + 0.5, base + 0.999_999_9]
        for i in 0..<400 { instants.append(base + Double(i) * 0.123_456_7 + 1_000_000 * Double(i % 7)) }
        for t in instants {
            let now = Date(timeIntervalSince1970: t)
            let frac = now.timeIntervalSince1970
            for q in ["5 days ago", "3 weeks ago", "2 months ago", "1 year ago", "5 days from now"] {
                let titles = time(q, now: now)?.map(\.title) ?? []
                XCTAssertFalse(titles.contains { $0.contains("23 hours") || $0.contains("59 minutes") }, "\(q) @\(frac): \(titles)")
            }
            XCTAssertEqual(time("5 days ago", now: now)?[1].title, "5 days ago", "@\(frac)")
        }
    }

    // MARK: scientific notation

    func testRadixScientific() {
        XCTAssertEqual(radix("1e3 to hex")?.first?.title, "0x3e8")
        XCTAssertEqual(radix("1.5e3 to dec")?.first?.title, "1500")
        XCTAssertEqual(radix("2e0 to bin")?.first?.title, "0b10")
        for q in ["1e-1 to hex", "1.5 to hex", "-1e3 to hex", "1e30 to hex", "1e999 to hex"] {
            XCTAssertEqual(radix(q)?.first?.valid, false, q)
        }
        XCTAssertEqual(radix("1e3 hex to dec")?.first?.title, "483")
    }

    func testTimeScientific() {
        XCTAssertEqual(time("time 1e9")?.last?.title, "1000000000")
        XCTAssertEqual(time("time +1e3 seconds")?.last?.title, "1795448845")
        XCTAssertEqual(time("1e9 to date")?.last?.title, "1000000000")
        XCTAssertEqual(time("in 1e3 seconds")?.last?.title, "1795448845")
    }

    // MARK: network cache

    func testFetcherUsesEphemeralSession() {
        let cfg = URLSessionFetcher.configuration
        XCTAssertNil(cfg.urlCache)
        XCTAssertNil(cfg.httpCookieStorage)
        XCTAssertFalse(cfg.httpShouldSetCookies)
        XCTAssertEqual(cfg.timeoutIntervalForRequest, 10)
    }
}
