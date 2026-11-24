import Foundation

/// Minimal HTTP GET so tests can inject fixtures.
public protocol HTTPFetching {
    func get(_ url: URL) async throws -> Data
}

/// URLSession-backed fetcher with a 10 s timeout; non-2xx responses throw.
public struct URLSessionFetcher: HTTPFetching {
    public init() {}

    /// Ephemeral configuration: no URL cache, cookies or credential storage, so nothing is written to disk.
    static let configuration: URLSessionConfiguration = {
        let c = URLSessionConfiguration.ephemeral
        c.urlCache = nil; c.httpCookieStorage = nil; c.httpShouldSetCookies = false; c.urlCredentialStorage = nil
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 10; c.timeoutIntervalForResource = 30
        return c
    }()
    private static let session = URLSession(configuration: configuration)

    public func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.setValue("calc-alfred-workflow", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await Self.session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
        return data
    }
}
