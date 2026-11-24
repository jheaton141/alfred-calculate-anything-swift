import Foundation

/// Safe arithmetic evaluator: + - * / ^ %, parentheses, unary minus, common functions, pi/e and k/M/B/T suffixes.
public struct MathTool: Tool {
    public let name = "math"
    public init() {}

    enum EvalError: Error { case syntax, divisionByZero, domain }

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        var parser = MathParser(Array(query), settings: context.settings)
        let value: Double
        do {
            value = try parser.parseAll()
        } catch EvalError.divisionByZero {
            return parser.sawOperation ? [ToolSupport.divisionByZero(context.strings)] : nil
        } catch EvalError.domain {
            return parser.sawOperation ? [.error(ToolSupport.tr(context.strings, "error_math_domain", "Invalid input"))] : nil
        } catch { return nil }
        guard parser.sawOperation else { return nil }
        guard value.isFinite else { return [.error(ToolSupport.tr(context.strings, "error_math_domain", "Invalid input"))] }
        let shown = ToolSupport.fmt(value, context.settings)
        return [.value(title: shown, copy: shown, raw: ToolSupport.raw(value), strings: context.strings)]
    }
}

/// Recursive-descent parser that evaluates as it goes; `sawOperation` is false for a bare number or constant.
struct MathParser {
    private let chars: [Character]
    private var pos = 0
    private let settings: Settings
    private(set) var sawOperation = false

    init(_ chars: [Character], settings: Settings) { self.chars = chars; self.settings = settings }

    private static let functions: [String: (Double) -> Double] = [
        "sqrt": { $0.squareRoot() }, "abs": { abs($0) }, "round": { $0.rounded() }, "floor": { floor($0) },
        "ceil": { ceil($0) }, "ln": { log($0) }, "log": { log10($0) }, "sin": { sin($0) },
        "cos": { cos($0) }, "tan": { tan($0) }, "exp": { exp($0) },
    ]
    private static let suffixes: [Character: Double] = ["k": 1e3, "K": 1e3, "M": 1e6, "B": 1e9, "T": 1e12]

    mutating func parseAll() throws -> Double {
        let v = try expression()
        skipSpaces()
        guard pos == chars.count else { throw MathTool.EvalError.syntax }
        return v
    }

    private mutating func skipSpaces() { while pos < chars.count, chars[pos].isWhitespace { pos += 1 } }

    private mutating func peek() -> Character? { skipSpaces(); return pos < chars.count ? chars[pos] : nil }

    private mutating func expression() throws -> Double {
        var v = try term()
        while let c = peek(), c == "+" || c == "-" {
            pos += 1; sawOperation = true
            let r = try term()
            v = c == "+" ? v + r : v - r
        }
        return v
    }

    private mutating func term() throws -> Double {
        var v = try unary()
        while let c = peek(), "*/%×÷".contains(c) {
            if c == "*", pos + 1 < chars.count, chars[pos + 1] == "*" { break }
            pos += 1; sawOperation = true
            let r = try unary()
            switch c {
            case "*", "×": v *= r
            case "/", "÷":
                if r == 0 { throw MathTool.EvalError.divisionByZero }
                v /= r
            default:
                if r == 0 { throw MathTool.EvalError.divisionByZero }
                v = v.truncatingRemainder(dividingBy: r)
            }
        }
        return v
    }

    private mutating func unary() throws -> Double {
        if let c = peek(), c == "-" || c == "+" {
            pos += 1
            let v = try unary()
            return c == "-" ? -v : v
        }
        return try power()
    }

    private mutating func power() throws -> Double {
        let base = try atom()
        guard let c = peek() else { return base }
        if c == "^" || (c == "*" && pos + 1 < chars.count && chars[pos + 1] == "*") {
            pos += c == "^" ? 1 : 2; sawOperation = true
            let e = try unary()
            let r = pow(base, e)
            if r.isNaN { throw MathTool.EvalError.domain }
            if base == 0, e < 0 { throw MathTool.EvalError.divisionByZero }
            return r
        }
        return base
    }

    private mutating func atom() throws -> Double {
        guard let c = peek() else { throw MathTool.EvalError.syntax }
        if c == "(" {
            pos += 1
            let v = try expression()
            guard peek() == ")" else { throw MathTool.EvalError.syntax }
            pos += 1
            return v
        }
        if c.isNumber || c == "." || c == "," { return try numberLiteral() }
        if c.isLetter || c == "π" {
            var word = ""
            while pos < chars.count, chars[pos].isLetter { word.append(chars[pos]); pos += 1 }
            let key = word.lowercased()
            if key == "pi" || word == "π" { return Double.pi }
            if key == "e" { return M_E }
            guard let f = Self.functions[key], peek() == "(" else { throw MathTool.EvalError.syntax }
            pos += 1
            let arg = try expression()
            guard peek() == ")" else { throw MathTool.EvalError.syntax }
            pos += 1; sawOperation = true
            if (key == "sqrt" && arg < 0) || ((key == "ln" || key == "log") && arg <= 0) { throw MathTool.EvalError.domain }
            return f(arg)
        }
        throw MathTool.EvalError.syntax
    }

    private mutating func numberLiteral() throws -> Double {
        var text = ""
        while pos < chars.count, chars[pos].isASCII, chars[pos].isNumber || chars[pos] == "." || chars[pos] == "," {
            text.append(chars[pos]); pos += 1
        }
        guard text.contains(where: { $0.isNumber }), var v = NumberFormat.parse(text, settings: settings) else { throw MathTool.EvalError.syntax }
        if pos < chars.count, let mult = Self.suffixes[chars[pos]],
           pos + 1 >= chars.count || !chars[pos + 1].isLetter {
            v *= mult; pos += 1; sawOperation = true
        }
        return v
    }
}
