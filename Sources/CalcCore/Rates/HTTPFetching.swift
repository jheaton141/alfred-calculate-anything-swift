import Foundation

/// Minimal HTTP GET so tests can inject fixtures.
public protocol HTTPFetching {
    func get(_ url: URL) async throws -> Data
}

/// URLSession-backed fetcher with a 10 s timeout; non-2xx responses throw.
public struct URLSessionFetcher: HTTPFetching {
    public init() {}

    public func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.setValue("calc-alfred-workflow", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
        return data
    }
}
