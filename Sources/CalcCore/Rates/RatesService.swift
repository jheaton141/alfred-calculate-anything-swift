import Foundation

/// Keyless fiat and crypto rates with JSON disk caches, source fallback and stale-cache serving.
public final class RatesService: RatesProviding {
    private let dataDir: URL
    private let settings: Settings
    private let http: HTTPFetching
    private let now: () -> Date

    public init(dataDir: URL, settings: Settings, http: HTTPFetching = URLSessionFetcher(), now: @escaping () -> Date = Date.init) {
        self.dataDir = dataDir; self.settings = settings; self.http = http; self.now = now
    }

    // MARK: Fiat

    public func fiatRates() async throws -> RateTable {
        let cached = readCache("rates-fiat.json")
        if let c = cached, isFresh(c, ttl: settings.fiatCacheHours * 3600) { return c }

        let fx = await frankfurter()
        let broad = await fawaz()
        guard fx != nil || broad != nil else { return try staleOrThrow(cached, "fiat") }

        var rates = fx ?? [:]
        for (code, v) in broad ?? [:] where rates[code] == nil { rates[code] = v }
        rates["USD"] = 1
        let source = [fx != nil ? "frankfurter" : nil, broad != nil ? "fawazahmed0" : nil].compactMap { $0 }.joined(separator: "+")
        let table = RateTable(base: "USD", rates: rates, fetchedAt: now(), source: source)
        writeCache(table, "rates-fiat.json")
        return table
    }

    private func frankfurter() async -> [String: Double]? {
        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD"),
              let data = try? await http.get(url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = obj["rates"] as? [String: Any] else { return nil }
        var out: [String: Double] = [:]
        for (k, v) in raw { if let d = (v as? NSNumber)?.doubleValue, d > 0 { out[k.uppercased()] = d } }
        return out.isEmpty ? nil : out
    }

    private func fawaz() async -> [String: Double]? {
        let urls = ["https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json",
                    "https://latest.currency-api.pages.dev/v1/currencies/usd.json"]
        for s in urls {
            guard let url = URL(string: s), let data = try? await http.get(url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let raw = obj["usd"] as? [String: Any] else { continue }
            var out: [String: Double] = [:]
            for (k, v) in raw {
                let code = k.uppercased()
                // Keep 3-letter alphabetic codes that are not crypto tickers; the source mixes both.
                guard code.count == 3, code.allSatisfy({ $0 >= "A" && $0 <= "Z" }), CoinMap.ids[code] == nil else { continue }
                if let d = (v as? NSNumber)?.doubleValue, d > 0 { out[code] = d }
            }
            if !out.isEmpty { return out }
        }
        return nil
    }

    // MARK: Crypto

    public func cryptoRates(symbols: [String]) async throws -> RateTable {
        let file = "rates-crypto.json"
        let wanted = Array(Set(symbols.map { $0.uppercased() }.filter { !$0.isEmpty }))
        let cached = readCache(file)
        let ttl = settings.cryptoCacheMinutes * 60
        let fresh = cached.map { isFresh($0, ttl: ttl) } ?? false
        let have = Set(cached?.rates.keys.map { $0 } ?? [])

        // Fresh cache holding every requested symbol needs no network.
        if let c = cached, fresh, Set(wanted).isSubset(of: have) { return c }

        // Expired: refresh everything cached plus the request; fresh but incomplete: fetch only what is missing.
        let toFetch: [String]
        if fresh { toFetch = wanted.filter { !have.contains($0) } }
        else { toFetch = Array(Set(wanted).union(have)).sorted() }
        let fetchList = toFetch.isEmpty ? CoinMap.ids.keys.sorted() : toFetch

        let prices = await coinGecko(fetchList)
        var source = "coingecko"
        var got = prices
        let missing = fetchList.filter { got[$0] == nil }
        if !missing.isEmpty {
            let cb = await coinbase(missing)
            if !cb.isEmpty { got.merge(cb) { a, _ in a }; source = prices.isEmpty ? "coinbase" : "coingecko+coinbase" }
        }

        if got.isEmpty {
            guard let c = cached, wanted.allSatisfy({ c.rates[$0] != nil }) else {
                let names = wanted.isEmpty ? "" : " for \(wanted.sorted().joined(separator: ", "))"
            throw RatesError.unavailable("No crypto rates\(names): network unavailable and not cached")
            }
            return fresh ? c : try staleOrThrow(c, "crypto")
        }

        var rates = cached?.rates ?? [:]
        for (sym, price) in got where price > 0 { rates[sym] = 1 / price }
        // Symbols that missed this refresh keep their old price, so an expired table stays expired and is flagged stale.
        let refreshedAll = have.allSatisfy { got[$0] != nil }
        let stamp = fresh || !refreshedAll ? (cached?.fetchedAt ?? now()) : now()
        var table = RateTable(base: "USD", rates: rates, fetchedAt: stamp, source: source)
        writeCache(table, file)
        table.stale = !fresh && !refreshedAll
        return table
    }

    private func coinGecko(_ symbols: [String]) async -> [String: Double] {
        var idToSym: [String: String] = [:]
        for s in symbols { if let id = CoinMap.ids[s] { idToSym[id] = s } }
        guard !idToSym.isEmpty,
              let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(idToSym.keys.sorted().joined(separator: ","))&vs_currencies=usd"),
              let data = try? await http.get(url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: Double] = [:]
        for (id, sym) in idToSym {
            if let usd = ((obj[id] as? [String: Any])?["usd"] as? NSNumber)?.doubleValue, usd > 0 { out[sym] = usd }
        }
        return out
    }

    private func coinbase(_ symbols: [String]) async -> [String: Double] {
        var out: [String: Double] = [:]
        await withTaskGroup(of: (String, Double?).self) { group in
            for sym in symbols {
                group.addTask { (sym, await self.coinbasePrice(sym)) }
            }
            for await (sym, price) in group { if let p = price { out[sym] = p } }
        }
        return out
    }

    private func coinbasePrice(_ sym: String) async -> Double? {
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/\(sym)-USD/spot"),
              let data = try? await http.get(url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let amount = (obj["data"] as? [String: Any])?["amount"] as? String,
              let d = Double(amount), d > 0 else { return nil }
        return d
    }

    // MARK: Cache

    private func isFresh(_ t: RateTable, ttl: Double) -> Bool {
        let age = now().timeIntervalSince(t.fetchedAt)
        return age >= 0 && age < ttl
    }

    private func staleOrThrow(_ cached: RateTable?, _ what: String) throws -> RateTable {
        guard var c = cached else { throw RatesError.unavailable("No \(what) rates: network unavailable and nothing cached") }
        c.stale = true
        return c
    }

    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }

    private func readCache(_ name: String) -> RateTable? {
        guard let data = try? Data(contentsOf: dataDir.appendingPathComponent(name)) else { return nil }
        guard var t = try? decoder().decode(RateTable.self, from: data) else { return nil }
        t.rates = t.rates.filter { $0.value > 0 && $0.value.isFinite }
        return t.rates.isEmpty ? nil : t
    }

    private func writeCache(_ table: RateTable, _ name: String) {
        var t = table; t.stale = false
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(t) else { return }
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        try? data.write(to: dataDir.appendingPathComponent(name), options: .atomic)
    }
}
