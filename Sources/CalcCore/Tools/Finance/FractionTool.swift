import Foundation

/// Exact fraction arithmetic: "1/3 + 1/4", "1 1/2 * 3", "0.75 to fraction", "simplify 6/8".
public struct FractionTool: Tool {
    public let name = "fraction"
    public init() {}

    struct Frac: Equatable {
        var n: Int, d: Int
        init?(_ n: Int, _ d: Int) {
            guard d != 0, n != Int.min, d != Int.min else { return nil }
            let g = Self.gcd(abs(n), abs(d))
            let sign = d < 0 ? -1 : 1
            self.n = sign * n / g; self.d = abs(d) / g
        }
        static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? max(a, 1) : gcd(b, a % b) }
        var value: Double { Double(n) / Double(d) }
        func add(_ o: Frac, _ sign: Int) -> Frac? {
            let (a, o1) = n.multipliedReportingOverflow(by: o.d), (b, o2) = (sign * o.n).multipliedReportingOverflow(by: d)
            let (num, o3) = a.addingReportingOverflow(b), (den, o4) = d.multipliedReportingOverflow(by: o.d)
            return o1 || o2 || o3 || o4 ? nil : Frac(num, den)
        }
        func mul(_ o: Frac) -> Frac? {
            let (num, o1) = n.multipliedReportingOverflow(by: o.n), (den, o2) = d.multipliedReportingOverflow(by: o.d)
            return o1 || o2 ? nil : Frac(num, den)
        }
        func div(_ o: Frac) -> Frac? { o.n == 0 ? nil : mul(Frac(o.d, o.n)!) }
        var text: String { d == 1 ? "\(n)" : "\(n)/\(d)" }
        var mixed: String? {
            guard d != 1, abs(n) > d else { return nil }
            return "\(n / d) \(abs(n % d))/\(d)"
        }
    }

    private enum Tok: Equatable { case int(Int), dec(Int, Int), frac(Int, Int), op(Character), open, close }
    private enum Fail: Error { case bad, zero, overflow }

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        var q = ToolSupport.normalize(query)
        var explicit = false
        for prefix in ["fraction ", "frac ", "simplify ", "reduce "] where q.hasPrefix(prefix) { q = String(q.dropFirst(prefix.count)); explicit = true }
        for suffix in [" to a fraction", " as a fraction", " to fraction", " as fraction", " in fractions", " in fraction", " to fractions"] where q.hasSuffix(suffix) {
            q = String(q.dropLast(suffix.count)); explicit = true
        }
        if q.range(of: #"^\(?\d+/\d+ of "#, options: .regularExpression) != nil { q = q.replacingOccurrences(of: " of ", with: " * "); explicit = true }
        let wantsDecimalInput = explicit
        if context.settings.decimalSeparator == "," {
            guard !q.contains(".") else { return nil }   // "." is a thousands separator here; leave it to the math tool
            q = q.replacingOccurrences(of: ",", with: ".")
        }
        guard q.count <= 200, let toks = Self.lex(q), !toks.isEmpty else { return nil }
        let fracLiterals = toks.filter { if case .frac = $0 { return true }; return false }.count
        guard explicit || fracLiterals >= 2 || (fracLiterals >= 1 && Self.hasMixed(toks)) else { return nil }
        let s = context.settings, str = context.strings
        do {
            var parser = Parser(toks: toks)
            let result = try parser.parseAll()
            return Self.rows(result, toks, wantsDecimalInput, s, str)
        } catch Fail.zero { return [ToolSupport.divisionByZero(str)] }
        catch Fail.overflow { return explicit ? [ToolSupport.invalidInput(str)] : nil }
        catch { return nil }
    }

    private static func rows(_ f: Frac, _ toks: [Tok], _ decimalInput: Bool, _ s: Settings, _ str: Strings) -> [AlfredItem] {
        func item(_ title: String, _ sub: String, copy: String, raw: String) -> AlfredItem {
            var i = AlfredItem.value(title: title, copy: copy, raw: raw, strings: str); i.subtitle = sub; return i
        }
        var items = [item(f.text, ToolSupport.tr(str, "frac_simplest", "Simplest form"), copy: f.text, raw: f.text)]
        if let m = f.mixed { items.append(item(m, ToolSupport.tr(str, "frac_mixed", "Mixed number"), copy: m, raw: m)) }
        if f.d != 1 {
            let v = f.value
            items.append(item(ToolSupport.show(v, s), ToolSupport.tr(str, "frac_decimal", "Decimal"), copy: ToolSupport.show(v, s), raw: ToolSupport.rawValue(v, s)))
        }
        if decimalInput, toks.count == 1, case .dec = toks[0], let a = approximate(f.value, maxDen: 1_000), a != f, a.d != 1 {
            items.append(item("≈ " + a.text, ToolSupport.tr(str, "frac_approx", "Closest simple fraction"), copy: a.text, raw: a.text))
        }
        return items
    }

    /// Best rational approximation with a denominator up to maxDen, within a relative error of 1e-6.
    static func approximate(_ x: Double, maxDen: Int) -> Frac? {
        guard x.isFinite, x != 0 else { return nil }
        var (h0, h1, k0, k1) = (0.0, 1.0, 1.0, 0.0)
        var r = abs(x)
        for _ in 0..<32 {
            let a = r.rounded(.down)
            let h2 = a * h1 + h0, k2 = a * k1 + k0
            guard k2 <= Double(maxDen), h2 < 9e15 else { break }
            (h0, h1, k0, k1) = (h1, h2, k1, k2)
            if abs(abs(x) - h1 / k1) <= abs(x) * 1e-5 { return Frac(Int(h1) * (x < 0 ? -1 : 1), Int(k1)) }
            let frac = r - a
            if frac < 1e-12 { break }
            r = 1 / frac
        }
        return nil
    }

    private static func hasMixed(_ t: [Tok]) -> Bool {
        for i in 0..<max(t.count - 1, 0) { if case .int = t[i], case .frac = t[i + 1] { return true } }
        return false
    }

    /// Splits into numbers, adjacent "a/b" fraction literals (no spaces), operators and parentheses; nil on anything else.
    private static func lex(_ q: String) -> [Tok]? {
        let c = Array(q)
        var i = 0, out: [Tok] = []
        func digits() -> String { var t = ""; while i < c.count, c[i].isASCII, c[i].isNumber { t.append(c[i]); i += 1 }; return t }
        while i < c.count {
            let ch = c[i]
            if ch == " " { i += 1; continue }
            if ch.isASCII, ch.isNumber || ch == "." {
                let whole = digits()
                if i < c.count, c[i] == "." {
                    i += 1
                    let frac = digits()
                    guard !(whole.isEmpty && frac.isEmpty), whole.count + frac.count <= 15, let n = Int(whole + frac), let d = Int("1" + String(repeating: "0", count: frac.count)) else { return nil }
                    out.append(.dec(n, d)); continue
                }
                guard let n = Int(whole), whole.count <= 15 else { return nil }
                if i + 1 < c.count, c[i] == "/", c[i + 1].isASCII, c[i + 1].isNumber {
                    i += 1
                    guard let d = Int(digits()) else { return nil }
                    if i + 1 < c.count, c[i] == "/", c[i + 1].isASCII, c[i + 1].isNumber { return nil }   // a date such as 1/2/2026
                    out.append(.frac(n, d))
                } else { out.append(.int(n)) }
                continue
            }
            switch ch {
            case "x" where !(i > 0 && c[i - 1] == " " && i + 1 < c.count && c[i + 1] == " "): return nil   // "0x10" is not a product
            case "+", "-", "*", "x", "×", "÷", "/": out.append(.op(ch == "x" || ch == "×" ? "*" : ch == "÷" ? "/" : ch))
            case "(": out.append(.open)
            case ")": out.append(.close)
            default: return nil
            }
            i += 1
        }
        return out
    }

    private struct Parser {
        let toks: [Tok]
        var pos = 0
        var depth = 0
        init(toks: [Tok]) { self.toks = toks }

        mutating func parseAll() throws -> Frac {
            let v = try expr()
            guard pos == toks.count else { throw Fail.bad }
            return v
        }
        mutating func expr() throws -> Frac {
            var v = try term()
            while pos < toks.count, case .op(let o) = toks[pos], o == "+" || o == "-" {
                pos += 1
                guard let r = v.add(try term(), o == "+" ? 1 : -1) else { throw Fail.overflow }
                v = r
            }
            return v
        }
        mutating func term() throws -> Frac {
            var v = try unary()
            while pos < toks.count, case .op(let o) = toks[pos], o == "*" || o == "/" {
                pos += 1
                let rhs = try unary()
                if o == "/" {
                    if rhs.n == 0 { throw Fail.zero }
                    guard let r = v.div(rhs) else { throw Fail.overflow }
                    v = r
                } else {
                    guard let r = v.mul(rhs) else { throw Fail.overflow }
                    v = r
                }
            }
            return v
        }
        mutating func unary() throws -> Frac {
            depth += 1; defer { depth -= 1 }
            guard depth < 64 else { throw Fail.bad }
            if pos < toks.count, case .op("-") = toks[pos] {
                pos += 1
                let v = try unary()
                guard let r = Frac(-v.n, v.d) else { throw Fail.overflow }
                return r
            }
            return try primary()
        }
        mutating func primary() throws -> Frac {
            guard pos < toks.count else { throw Fail.bad }
            let t = toks[pos]; pos += 1
            switch t {
            case .int(let n):
                if pos < toks.count, case .frac(let a, let b) = toks[pos] {
                    pos += 1
                    guard b != 0 else { throw Fail.zero }
                    let (w, o1) = n.multipliedReportingOverflow(by: b), (num, o2) = w.addingReportingOverflow(a)
                    guard !o1, !o2, let f = Frac(num, b) else { throw Fail.overflow }
                    return f
                }
                guard let f = Frac(n, 1) else { throw Fail.overflow }
                return f
            case .dec(let n, let d): guard let f = Frac(n, d) else { throw Fail.overflow }; return f
            case .frac(let a, let b): guard b != 0 else { throw Fail.zero }; guard let f = Frac(a, b) else { throw Fail.overflow }; return f
            case .open:
                depth += 1; defer { depth -= 1 }
                guard depth < 64 else { throw Fail.bad }
                let v = try expr()
                guard pos < toks.count, toks[pos] == .close else { throw Fail.bad }
                pos += 1
                return v
            default: throw Fail.bad
            }
        }
    }
}
