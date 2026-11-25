import Foundation

/// A currency or coin named in a query.
struct CurrencyUnit: Equatable {
    var code: String
    var isCrypto = false
}

/// Coin symbols the crypto tool claims.
public enum CryptoSymbols {
    public static let known: Set<String> = [
        "BTC", "ETH", "USDT", "BNB", "SOL", "XRP", "USDC", "ADA", "DOGE", "TRX",
        "TON", "AVAX", "SHIB", "DOT", "LINK", "BCH", "LTC", "MATIC", "POL", "NEAR",
        "UNI", "ICP", "APT", "XLM", "ATOM", "XMR", "ETC", "FIL", "HBAR", "ARB",
        "VET", "MKR", "AAVE", "ALGO", "GRT", "INJ", "SUI", "DAI", "OP", "STX",
    ]
}

/// Currency codes, symbols and spoken names recognised in queries.
enum CurrencyLexicon {
    static let fiatCodes: Set<String> = Set((
        "AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BGN BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BYR BZD "
        + "CAD CDF CHF CLF CLP CNH CNY COP CRC CUC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GHS "
        + "GIP GMD GNF GTQ GYD HKD HNL HRK HTG HUF IDR ILS INR IQD IRR ISK JMD JOD JPY KES KGS KHR KMF KPW KRW KWD "
        + "KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRO MRU MUR MVR MWK MXN MXV MYR MZN NAD NGN "
        + "NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLE SLL "
        + "SOS SRD SSP STD STN SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX USD UYI UYU UZS VEF VES VND "
        + "VUV WST XAF XAG XAU XCD XOF XPF YER ZAR ZMW ZWG ZWL"
    ).split(separator: " ").map(String.init))

    /// Codes that are also everyday words; a bare "5 cup" must not be taken as currency.
    static let bareCollisions: Set<String> = ["CUP", "ALL", "TOP", "TRY", "SOS", "MOP", "BOB", "PAB", "PEN"]

    static let aliases: [String: String] = [
        "€": "EUR", "$": "USD", "£": "GBP", "¥": "JPY", "r$": "BRL", "c¥": "CNY", "₹": "INR", "₩": "KRW",
        "₺": "TRY", "₪": "ILS", "₦": "NGN", "₴": "UAH", "₱": "PHP", "₡": "CRC", "៛": "KHR", "лв": "BGN",
        "kč": "CZK", "j$": "JMD", "tt$": "TTD", "c$": "NIO", "rd$": "DOP", "s/.": "PEN", "b/.": "PAB",
        "ƒ": "ANG", "ден": "MKD",
        "euro": "EUR", "euros": "EUR", "eurs": "EUR", "yen": "JPY", "yens": "JPY",
        "dollar": "USD", "dollars": "USD", "us dollar": "USD", "us dollars": "USD", "buck": "USD", "bucks": "USD",
        "pound": "GBP", "pounds": "GBP", "pounds sterling": "GBP", "nis": "ILS", "shekel": "ILS", "shekels": "ILS", "sheqel": "ILS",
        "taka": "BDT", "takas": "BDT", "baht": "THB", "zloty": "PLN", "zlotys": "PLN", "ruble": "RUB", "rubles": "RUB",
        "rouble": "RUB", "roubles": "RUB", "ringgit": "MYR", "rand": "ZAR", "rmb": "CNY", "yuan": "CNY", "renminbi": "CNY", "sterling": "GBP", "pound sterling": "GBP",
        "rupe": "INR", "rupee": "INR", "rupees": "INR", "rupiah": "IDR",
        "mexican peso": "MXN", "mexican pesos": "MXN", "argentinian peso": "ARS", "argentinian pesos": "ARS",
        "argentinian": "ARS", "colombian peso": "COP", "colombian pesos": "COP",
        "canadian dollar": "CAD", "canadian dollars": "CAD", "canadian": "CAD",
    ]

    static let cryptoAliases: [String: String] = [
        "bitcoin": "BTC", "bitcoins": "BTC", "ether": "ETH", "ethereum": "ETH", "etherium": "ETH",
        "dogecoin": "DOGE", "litecoin": "LTC", "solana": "SOL", "cardano": "ADA", "ripple": "XRP",
        "monero": "XMR", "polkadot": "DOT", "tether": "USDT",
    ]

    /// Maps one name, symbol or code to a unit; nil when it is not a currency (or coin, when `coins`).
    static func resolve(_ text: String, coins: Bool) -> CurrencyUnit? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return nil }
        if coins {
            if let c = cryptoAliases[t] { return CurrencyUnit(code: c, isCrypto: true) }
            if CryptoSymbols.known.contains(t.uppercased()) { return CurrencyUnit(code: t.uppercased(), isCrypto: true) }
        }
        if let c = aliases[t] { return CurrencyUnit(code: c) }
        if t.count == 3, t.unicodeScalars.allSatisfy({ $0.isASCII && CharacterSet.letters.contains($0) }) {
            return CurrencyUnit(code: t.uppercased())
        }
        return nil
    }
}
