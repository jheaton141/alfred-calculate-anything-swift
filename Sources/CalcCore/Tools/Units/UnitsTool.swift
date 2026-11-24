import Foundation

/// Converts between physical units: "10 km to mi", "100oz kg", "1 l = gal", "10 km to mi, ft".
public struct UnitsTool: Tool {
    public let name = "units"
    public init() {}

    private static let stopWords: Set<String> = ["to", "in", "as", "="]

    public func evaluate(_ query: String, context: Context) async -> [AlfredItem]? {
        let verdict = ScaleFormat.check(query)
        if verdict == .skip { return nil }
        guard let (parsed, parsedRest) = Self.splitAmount(query, settings: context.settings) else { return nil }
        var amount = parsed, rest = parsedRest
        if verdict == .overflow { amount = .infinity }
        // "3 lakh m to km": a multiplier word before a unit scales the amount
        let parts = rest.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2, let k = Self.bareMultiplier(parts[0]), !Self.stopWords.contains(parts[1].lowercased().split(separator: " ").first.map(String.init) ?? "") {
            amount *= k; rest = parts[1]
        }
        if let words = Self.bareMultiplier(rest) {
            let v = amount * words
            guard v.isFinite else { return [ScaleFormat.invalid(context.strings)] }
            let shown = ToolSupport.fmt(v, context.settings)
            return [.value(title: shown, copy: shown, raw: ToolSupport.raw(v), strings: context.strings)]
        }
        guard let (from, targets) = Self.splitUnits(rest) else { return nil }
        if !amount.isFinite { return [ScaleFormat.invalid(context.strings)] }
        var items: [AlfredItem] = []
        for target in targets {
            guard let pair = Self.pick(from: from, to: target) else {
                items.append(.error(String(format: "Error, you can not convert from %@ to %@", from[0].symbol, target[0].symbol)))
                continue
            }
            items += Self.rows(amount: amount, from: pair.0, to: pair.1, context: context)
        }
        return items
    }

    // MARK: parsing

    /// Leading signed number and the remaining text; nil without a number.
    static func splitAmount(_ query: String, settings: Settings) -> (Double, String)? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard let r = q.range(of: #"^[-+]?(?:\d[\d,. ]*|\.\d+)(?:(?<=[0-9.,])[eE][-+]?\d+)?"#, options: .regularExpression) else { return nil }
        var numText = String(q[r])
        var rest = String(q[r.upperBound...])
        // a trailing "." or "," belongs to the text, not the number
        while let last = numText.last, last == "." || last == "," || last == " " {
            numText.removeLast(); rest = String(last) + rest
        }
        if numText.hasPrefix("+") { numText.removeFirst() }
        guard let v = NumberFormat.parse(numText, settings: settings) ?? (ScaleFormat.overflowing(numText) ? Double.infinity : nil) else { return nil }
        return (v, rest.trimmingCharacters(in: .whitespaces))
    }

    /// "lakh", "lac" or "crore" alone after the number: the plain multiplier.
    static func bareMultiplier(_ rest: String) -> Double? {
        switch rest.lowercased() {
        case "lakh", "lakhs", "lac", "lacs": return 1e5
        case "crore", "crores": return 1e7
        default: return nil
        }
    }

    /// Splits "km to mi, ft" into source candidates and one candidate list per target.
    static func splitUnits(_ rest: String) -> ([UnitDef], [[UnitDef]])? {
        let tokens = rest.replacingOccurrences(of: "=", with: " = ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard tokens.count >= 2 else { return nil }
        func attempt(_ i: Int, skipStop: Bool) -> ([UnitDef], [[UnitDef]])? {
            let from = UnitsTable.candidates(tokens[0..<i].joined(separator: " "))
            guard !from.isEmpty else { return nil }
            let right = tokens[(skipStop ? i + 1 : i)...].joined(separator: " ")
            let parts = right.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            let targets = parts.map { UnitsTable.candidates($0) }
            guard !targets.isEmpty, targets.allSatisfy({ !$0.isEmpty }) else { return nil }
            return (from, targets)
        }
        for i in 1..<tokens.count where stopWords.contains(tokens[i].lowercased()) && i + 1 < tokens.count {
            if let r = attempt(i, skipStop: true) { return r }
        }
        for i in 1..<tokens.count {
            if let r = attempt(i, skipStop: false) { return r }
        }
        return nil
    }

    /// First candidate pair in the same dimension; resolves ambiguous aliases such as "oz".
    static func pick(from: [UnitDef], to: [UnitDef]) -> (UnitDef, UnitDef)? {
        for f in from { for t in to where f.dim == t.dim { return (f, t) } }
        return nil
    }

    // MARK: conversion

    static func convert(_ v: Double, from: UnitDef, to: UnitDef) -> Double {
        guard from.dim == .temperature else {
            let r = v * from.factor / to.factor
            return r.isFinite ? r : v * (from.factor / to.factor)
        }
        let kv = kelvin(v, from)
        switch to.id {
        case "c": return kv - 273.15
        case "f": return kv * 9 / 5 - 459.67
        default: return kv
        }
    }

    /// Kelvin value of a temperature; below absolute zero (beyond rounding noise) is NaN.
    static func kelvin(_ v: Double, _ from: UnitDef) -> Double {
        let k: Double
        switch from.id {
        case "c": k = v + 273.15
        case "f": k = (v + 459.67) * 5 / 9
        default: k = v
        }
        if k < -1e-9 { return .nan }
        return max(k, 0)
    }

    // MARK: output

    private static func settingsFor(_ unit: UnitDef, _ s: Settings) -> Settings {
        var out = s
        if unit.dim != .temperature { out.decimals = max(s.decimals, 8) }
        return out
    }

    private static func show(_ v: Double, _ s: Settings) -> String { ScaleFormat.show(v, s) }

    private static func label(_ unit: UnitDef, value: Double) -> String {
        guard let plural = unit.plural else { return unit.symbol }
        return abs(value) == 1 ? unit.symbol : plural
    }

    private static func rows(amount: Double, from: UnitDef, to: UnitDef, context: Context) -> [AlfredItem] {
        let s = settingsFor(to, context.settings)
        if from.dim == .temperature, kelvin(amount, from).isNaN { return [ScaleFormat.invalid(context.strings)] }
        let rawConverted = convert(amount, from: from, to: to)
        guard rawConverted.isFinite else { return [ScaleFormat.invalid(context.strings)] }
        let converted = ScaleFormat.clean(rawConverted)
        let shown = show(converted, s)
        let unitText = label(to, value: Double(NumberFormat.plain(converted, decimals: s.decimals)) ?? converted)
        let raw = ScaleFormat.raw(converted, decimals: s.decimals)
        let title = "\(shown) \(unitText)"
        var items = [AlfredItem.value(title: title, copy: shown, raw: raw, withUnit: title, strings: context.strings)]

        if converted >= 1, UnitsTable.fractionTargets.contains(to.id), let smallID = UnitsTable.fraction[to.id], let small = UnitsTable.byId[smallID] {
            let rounded = Double(NumberFormat.plain(converted, decimals: s.decimals)) ?? converted
            let whole = rounded.rounded(.towardZero)
            let frac = rounded - whole
            if frac > 1e-9 {
                let fracValue = convert(frac, from: to, to: small)
                let fs = settingsFor(small, context.settings)
                var s0 = context.settings; s0.decimals = 0
                let ft = "\(NumberFormat.display(whole, settings: s0)) \(to.symbol), \(show(fracValue, fs)) \(small.symbol)"
                items.append(.value(title: ft, copy: shown, raw: raw, withUnit: ft, strings: context.strings))
            }
        }
        return items
    }
}
