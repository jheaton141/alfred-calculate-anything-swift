import XCTest
@testable import CalcCore

final class LanguageTests: XCTestCase {
    private func run(_ tool: Tool, _ q: String, lang: String) -> [AlfredItem]? {
        var s = Settings(); s.language = lang
        let ctx = Context(settings: s, strings: Strings.load(lang), dataDir: FileManager.default.temporaryDirectory)
        let box = ResultBox()
        let sem = DispatchSemaphore(value: 0)
        Task { box.value = await tool.evaluate(q, context: ctx); sem.signal() }
        sem.wait()
        return box.value
    }
    private final class ResultBox: @unchecked Sendable { var value: [AlfredItem]? }

    func testEveryPackHasTheSameKeysAndPlaceholders() {
        let en = Strings.decode(LanguagePacks.en)
        for (code, json) in LanguagePacks.json {
            let pack = Strings.decode(json)
            XCTAssertEqual(Set(pack.keys), Set(en.keys), code)
            for (k, v) in pack {
                XCTAssertEqual(v.components(separatedBy: "%@").count, en[k]!.components(separatedBy: "%@").count, "\(code).\(k) placeholder count")
                XCTAssertFalse(v.contains("%s"), "\(code).\(k) uses PHP placeholder")
            }
        }
    }

    func testLoadResolution() {
        XCTAssertEqual(Strings.load("es_ES")["vat_empty"], "Ingresa un valor para procesar")
        XCTAssertEqual(Strings.load("es-es")["vat_empty"], "Ingresa un valor para procesar")
        XCTAssertEqual(Strings.load("sv")["vat_empty"], "Fyll i ett korrekt värde")
        XCTAssertEqual(Strings.load("xx_XX")["vat_empty"], "Enter a value to process")
        XCTAssertEqual(Strings.load("")["vat_empty"], "Enter a value to process")
        XCTAssertEqual(Strings.load("_")["vat_empty"], "Enter a value to process")
    }

    func testToolsUseTranslatedStrings() {
        XCTAssertEqual(run(PercentageTool(), "50 is what % of 200", lang: "es_ES")?.first?.title, "50 es 25% de 200")
        XCTAssertEqual(run(PercentageTool(), "50 is what % of 200", lang: "es_ES")?.first?.subtitle, "Presiona enter para copiar el valor al clipboard")
        XCTAssertEqual(run(PercentageTool(), "50 is what % of 200", lang: "sv_SE")?.first?.title, "50 är 25% av 200")
        XCTAssertEqual(run(MathTool(), "1/0", lang: "sv_SE")?.first?.title, "Kan inte dividera med noll")
        XCTAssertEqual(run(MathTool(), "1/0", lang: "en_EN")?.first?.title, "Cannot divide by zero")
        XCTAssertEqual(run(VatTool(), "100 vat", lang: "es_ES")?.first?.title, "IVA de 100 = 16")
    }
}

final class SinceSubtitleTests: XCTestCase {
    func testSinceUsesItsOwnSubtitle() {
        for (lang, want) in [("en_EN", "days since 1 january"), ("es_ES", "days desde el 1 january"), ("sv_SE", "days sedan 1 january")] {
            var s = Settings(); s.language = lang
            let ctx = Context(settings: s, strings: Strings.load(lang), dataDir: FileManager.default.temporaryDirectory)
            let sem = DispatchSemaphore(value: 0)
            final class Box: @unchecked Sendable { var v: [AlfredItem]? }
            let box = Box()
            Task { box.v = await TimeTool().evaluate("days since 1 january", context: ctx); sem.signal() }
            sem.wait()
            XCTAssertEqual(box.v?.first?.subtitle, want, lang)
        }
    }
}
