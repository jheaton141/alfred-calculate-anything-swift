import Foundation

struct ParsedConversion {
    var amount: Double?
    var from: CurrencyUnit
    var targets: [CurrencyUnit]
}

/// Splits "100 usd to eur, gbp" style queries into amount, source and targets.
enum ConversionParser {
    private static let stopRegex = try! NSRegularExpression(pattern: "(?<![\\p{L}])(?:to|in|as)(?![\\p{L}])|=", options: .caseInsensitive)
    private static let numberRegex = try! NSRegularExpression(pattern: "[-+]?\\d[\\d.,]*")
    private static let suffixes: [Character: Double] = ["k": 1e3, "m": 1e6, "b": 1e9, "t": 1e12]

    static func parse(_ query: String, settings: Settings, resolve: (String) -> CurrencyUnit?) -> ParsedConversion? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var left = q, right = "", hasStop = false
        if let m = stopRegex.firstMatch(in: q, range: NSRange(q.startIndex..., in: q)), let r = Range(m.range, in: q) {
            left = String(q[..<r.lowerBound]); right = String(q[r.upperBound...]); hasStop = true
        }
        let rightUnits = greedy(words(right), resolve)
        if hasStop && (rightUnits ?? []).isEmpty { return nil }
        guard let rightUnits else { return nil }

        var amount: Double?
        var from: CurrencyUnit
        var targets: [CurrencyUnit]
        if let m = numberRegex.firstMatch(in: left, range: NSRange(left.startIndex..., in: left)),
           let r = Range(m.range, in: left) {
            let numText = String(left[r]).trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            guard var value = NumberFormat.parse(numText, settings: settings) else { return nil }
            var rest = String(left[r.upperBound...])
            if let first = rest.first, let scale = suffixes[Character(first.lowercased())],
               !(rest.dropFirst().first?.isLetter ?? false) {
                value *= scale; rest.removeFirst()
            }
            amount = value
            let before = words(String(left[..<r.lowerBound])), after = words(rest)
            if before.isEmpty {
                guard let split = prefixUnit(after, resolve) else { return nil }
                (from, targets) = split
            } else {
                guard let f = resolve(before.joined(separator: " ")), let t = greedy(after, resolve) else { return nil }
                (from, targets) = (f, t)
            }
        } else {
            guard let split = prefixUnit(words(left), resolve) else { return nil }
            (from, targets) = split
        }
        return ParsedConversion(amount: amount, from: from, targets: targets + rightUnits)
    }

    private static func words(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" }).map(String.init)
            .filter { !["and", "&"].contains($0.lowercased()) }
    }

    /// Longest leading run of words naming one unit, with the remaining words resolved as units too.
    private static func prefixUnit(_ w: [String], _ resolve: (String) -> CurrencyUnit?) -> (CurrencyUnit, [CurrencyUnit])? {
        for n in stride(from: min(3, w.count), through: 1, by: -1) {
            if let u = resolve(w[0..<n].joined(separator: " ")), let rest = greedy(Array(w[n...]), resolve) { return (u, rest) }
        }
        return nil
    }

    /// Resolves every word into units, joining up to three words for names like "us dollars"; nil if any word fails.
    private static func greedy(_ w: [String], _ resolve: (String) -> CurrencyUnit?) -> [CurrencyUnit]? {
        var out: [CurrencyUnit] = [], i = 0
        while i < w.count {
            var hit = false
            for n in stride(from: min(3, w.count - i), through: 1, by: -1) {
                if let u = resolve(w[i..<i + n].joined(separator: " ")) { out.append(u); i += n; hit = true; break }
            }
            if !hit { return nil }
        }
        return out
    }
}
