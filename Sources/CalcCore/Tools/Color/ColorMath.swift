import Foundation

/// Colour parsing, conversion and formatting (sRGB, D65).
enum ColorMath {
    struct RGBA: Equatable { var r: Int; var g: Int; var b: Int; var a: Double = 1 }

    // MARK: parsing

    /// Parses a hex code, CSS name or colour function; bare hex (no "#") only when allowed.
    static func parse(_ text: String, allowBareHex: Bool) -> RGBA? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        if let hex = ColorNames.table[t] { return parseHex(hex) }
        if t.hasPrefix("#") { return parseHex(String(t.dropFirst())) }
        if allowBareHex, [3, 4, 6, 8].contains(t.count), t.allSatisfy({ $0.isHexDigit }),
           t.count == 6 || t.contains(where: { $0.isLetter }) { return parseHex(t) }
        return parseFunction(t)
    }

    private static func parseHex(_ h: String) -> RGBA? {
        guard h.allSatisfy({ $0.isHexDigit }) else { return nil }
        var digits = Array(h)
        if digits.count == 3 || digits.count == 4 { digits = digits.flatMap { [$0, $0] } }
        guard digits.count == 6 || digits.count == 8 else { return nil }
        let v = (0..<digits.count / 2).map { Int(String(digits[$0 * 2...$0 * 2 + 1]), radix: 16)! }
        return RGBA(r: v[0], g: v[1], b: v[2], a: v.count == 4 ? Double(v[3]) / 255 : 1)
    }

    private static func parseFunction(_ t: String) -> RGBA? {
        guard let open = t.firstIndex(of: "("), t.hasSuffix(")") else { return nil }
        let fn = String(t[..<open]).trimmingCharacters(in: .whitespaces)
        let body = t[t.index(after: open)..<t.index(before: t.endIndex)]
        var parts = body.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "/", with: " ")
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var name = fn
        if fn == "color", parts.first == "xyz" { name = "xyz"; parts.removeFirst() }
        let args = parts.compactMap(parseArg)
        guard args.count == parts.count else { return nil }
        let n = args.count
        let v = args.map(\.value)
        func alpha(_ i: Int) -> Double { n > i ? min(max(args[i].percent ? v[i] / 100 : v[i], 0), 1) : 1 }
        func pct(_ i: Int) -> Double { v[i] / 100 }
        switch name {
        case "rgb", "rgba":
            guard n == 3 || n == 4 else { return nil }
            let ch = (0..<3).map { args[$0].percent ? v[$0] * 255 / 100 : v[$0] }
            return RGBA(r: clamp255(ch[0]), g: clamp255(ch[1]), b: clamp255(ch[2]), a: alpha(3))
        case "hsl", "hsla":
            guard n == 3 || n == 4 else { return nil }
            return fromHSL(v[0], pct(1), pct(2), alpha(3))
        case "hsv", "hsb", "hsva":
            guard n == 3 || n == 4 else { return nil }
            return fromHSV(v[0], pct(1), pct(2), alpha(3))
        case "hwb":
            guard n == 3 || n == 4 else { return nil }
            return fromHWB(v[0], pct(1), pct(2), alpha(3))
        case "cmyk":
            guard n == 4 else { return nil }
            let k = pct(3)
            return RGBA(r: clamp255(255 * (1 - pct(0)) * (1 - k)), g: clamp255(255 * (1 - pct(1)) * (1 - k)),
                        b: clamp255(255 * (1 - pct(2)) * (1 - k)))
        case "lab":
            guard n == 3 else { return nil }
            return fromLab(v[0], v[1], v[2])
        case "lch":
            guard n == 3 else { return nil }
            let rad = v[2] * .pi / 180
            return fromLab(v[0], v[1] * cos(rad), v[1] * sin(rad))
        case "xyz":
            guard n == 3 else { return nil }
            return fromXYZ(v[0] / 100, v[1] / 100, v[2] / 100)
        default: return nil
        }
    }

    private static func parseArg(_ s: String) -> (value: Double, percent: Bool)? {
        var t = s, pct = false
        if t.hasSuffix("%") { t.removeLast(); pct = true }
        else if t.hasSuffix("deg") { t.removeLast(3) }
        else if t.hasSuffix("°") { t.removeLast() }
        guard let v = Double(t), v.isFinite else { return nil }
        return (v, pct)
    }

    private static func clamp255(_ x: Double) -> Int { x.isNaN ? 0 : Int(min(max(x.rounded(), 0), 255)) }

    // MARK: to / from spaces

    static func toHSL(_ c: RGBA) -> (h: Double, s: Double, l: Double) {
        let (r, g, b) = unit(c), mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        let l = (mx + mn) / 2
        let s = d == 0 ? 0 : d / (1 - abs(2 * l - 1))
        return (hue(r, g, b, mx, d), s, l)
    }

    static func toHSV(_ c: RGBA) -> (h: Double, s: Double, v: Double) {
        let (r, g, b) = unit(c), mx = max(r, g, b), d = mx - min(r, g, b)
        return (hue(r, g, b, mx, d), mx == 0 ? 0 : d / mx, mx)
    }

    static func toHWB(_ c: RGBA) -> (h: Double, w: Double, b: Double) {
        let (r, g, b) = unit(c), mx = max(r, g, b), mn = min(r, g, b)
        return (hue(r, g, b, mx, mx - mn), mn, 1 - mx)
    }

    static func toCMYK(_ c: RGBA) -> (c: Double, m: Double, y: Double, k: Double) {
        let (r, g, b) = unit(c), k = 1 - max(r, g, b)
        if k >= 1 { return (0, 0, 0, 1) }
        return ((1 - r - k) / (1 - k), (1 - g - k) / (1 - k), (1 - b - k) / (1 - k), k)
    }

    /// XYZ on the 0 to 1 scale (D65 white = 0.95047, 1, 1.08883).
    static func toXYZ(_ c: RGBA) -> (x: Double, y: Double, z: Double) {
        let (r0, g0, b0) = unit(c)
        let (r, g, b) = (linear(r0), linear(g0), linear(b0))
        return (0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
                0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
                0.0193339 * r + 0.1191920 * g + 0.9503041 * b)
    }

    static func toLab(_ c: RGBA) -> (l: Double, a: Double, b: Double) {
        let (x, y, z) = toXYZ(c)
        let fx = labF(x / 0.95047), fy = labF(y), fz = labF(z / 1.08883)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    static func fromHSL(_ h: Double, _ s: Double, _ l: Double, _ a: Double = 1) -> RGBA {
        let ss = min(max(s, 0), 1), ll = min(max(l, 0), 1)
        let chroma = (1 - abs(2 * ll - 1)) * ss
        return fromChroma(h, chroma, ll - chroma / 2, a)
    }

    static func fromHSV(_ h: Double, _ s: Double, _ v: Double, _ a: Double = 1) -> RGBA {
        let ss = min(max(s, 0), 1), vv = min(max(v, 0), 1)
        return fromChroma(h, vv * ss, vv - vv * ss, a)
    }

    static func fromHWB(_ h: Double, _ w: Double, _ b: Double, _ a: Double = 1) -> RGBA {
        var ww = min(max(w, 0), 1), bb = min(max(b, 0), 1)
        if ww + bb >= 1 { let g = ww / (ww + bb); return RGBA(r: clamp255(g * 255), g: clamp255(g * 255), b: clamp255(g * 255), a: a) }
        let pure = fromChroma(h, 1, 0, a)
        let k = 1 - ww - bb
        ww *= 255
        bb = 0
        return RGBA(r: clamp255(Double(pure.r) * k + ww), g: clamp255(Double(pure.g) * k + ww), b: clamp255(Double(pure.b) * k + ww), a: a)
    }

    static func fromXYZ(_ x: Double, _ y: Double, _ z: Double) -> RGBA {
        let lr = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
        let lg = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
        let lb = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z
        return RGBA(r: clamp255(gamma(lr) * 255), g: clamp255(gamma(lg) * 255), b: clamp255(gamma(lb) * 255))
    }

    static func fromLab(_ l: Double, _ a: Double, _ b: Double) -> RGBA {
        let fy = (l + 16) / 116, fx = fy + a / 500, fz = fy - b / 200
        return fromXYZ(labFInv(fx) * 0.95047, labFInv(fy), labFInv(fz) * 1.08883)
    }

    /// Hue-sector conversion shared by hsl, hsv and hwb.
    private static func fromChroma(_ h: Double, _ chroma: Double, _ m: Double, _ a: Double) -> RGBA {
        var hh = h.truncatingRemainder(dividingBy: 360); if hh < 0 { hh += 360 }
        let hp = hh / 60, x = chroma * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double)
        switch hp {
        case ..<1: (r, g, b) = (chroma, x, 0)
        case ..<2: (r, g, b) = (x, chroma, 0)
        case ..<3: (r, g, b) = (0, chroma, x)
        case ..<4: (r, g, b) = (0, x, chroma)
        case ..<5: (r, g, b) = (x, 0, chroma)
        default: (r, g, b) = (chroma, 0, x)
        }
        return RGBA(r: clamp255((r + m) * 255), g: clamp255((g + m) * 255), b: clamp255((b + m) * 255), a: a)
    }

    // MARK: helpers

    private static func unit(_ c: RGBA) -> (Double, Double, Double) { (Double(c.r) / 255, Double(c.g) / 255, Double(c.b) / 255) }

    private static func hue(_ r: Double, _ g: Double, _ b: Double, _ mx: Double, _ d: Double) -> Double {
        if d == 0 { return 0 }
        let h: Double
        if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        let deg = h * 60
        return deg < 0 ? deg + 360 : deg
    }

    private static func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    private static func gamma(_ v: Double) -> Double {
        let c = min(max(v, 0), 1)
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
    private static func labF(_ t: Double) -> Double { t > 216.0 / 24389 ? cbrt(t) : (24389.0 / 27 * t + 16) / 116 }
    private static func labFInv(_ t: Double) -> Double { t * t * t > 216.0 / 24389 ? t * t * t : (116 * t - 16) / (24389.0 / 27) }

    /// WCAG 2 relative luminance.
    static func luminance(_ c: RGBA) -> Double {
        let (r, g, b) = unit(c)
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    // MARK: formatting

    /// Formats a colour in the named space; percent-based spaces use the fewest decimals that round-trip to the same rgb.
    static func format(_ c: RGBA, _ space: String) -> String {
        let hasAlpha = c.a < 1
        let alpha = NumberFormat.plain(c.a, decimals: 2)
        func n(_ v: Double, _ p: Int) -> String { NumberFormat.plain(v, decimals: p) }
        switch space {
        case "hex":
            var s = String(format: "#%02x%02x%02x", c.r, c.g, c.b)
            if hasAlpha { s += String(format: "%02x", clamp255(c.a * 255)) }
            return s
        case "rgb", "rgba":
            return hasAlpha || space == "rgba" ? "rgba(\(c.r), \(c.g), \(c.b), \(alpha))" : "rgb(\(c.r), \(c.g), \(c.b))"
        case "hsl", "hsla":
            return roundTrip(c) { p in
                let v = toHSL(c)
                let body = "\(n(v.h, p)), \(n(v.s * 100, p))%, \(n(v.l * 100, p))%"
                return hasAlpha || space == "hsla" ? "hsla(\(body), \(alpha))" : "hsl(\(body))"
            }
        case "hsv", "hsb":
            return roundTrip(c) { p in
                let v = toHSV(c)
                return "\(space)(\(n(v.h, p)), \(n(v.s * 100, p))%, \(n(v.v * 100, p))%)"
            }
        case "hwb":
            return roundTrip(c) { p in
                let v = toHWB(c)
                return "hwb(\(n(v.h, p)), \(n(v.w * 100, p))%, \(n(v.b * 100, p))%)"
            }
        case "cmyk":
            return roundTrip(c) { p in
                let v = toCMYK(c)
                return "cmyk(\(n(v.c * 100, p))%, \(n(v.m * 100, p))%, \(n(v.y * 100, p))%, \(n(v.k * 100, p))%)"
            }
        case "lab":
            let v = toLab(c)
            return "lab(\(n(v.l, 2))% \(n(v.a, 2)) \(n(v.b, 2)))"
        case "lch":
            let v = toLab(c)
            var h = atan2(v.b, v.a) * 180 / .pi; if h < 0 { h += 360 }
            let chroma = hypot(v.a, v.b)
            return "lch(\(n(v.l, 2))% \(n(chroma, 2)) \(n(chroma < 0.005 ? 0 : h, 2)))"
        default:
            let v = toXYZ(c)
            return "color(xyz \(n(v.x * 100, 2)) \(n(v.y * 100, 2)) \(n(v.z * 100, 2)))"
        }
    }

    private static func roundTrip(_ c: RGBA, _ make: (Int) -> String) -> String {
        for p in 0...2 {
            let s = make(p)
            if let back = parse(s, allowBareHex: false), back.r == c.r, back.g == c.g, back.b == c.b { return s }
        }
        return make(2)
    }
}
