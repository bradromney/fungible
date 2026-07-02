import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// The one seam between sync drivers and the network. Drivers speak in these
// value types; production uses URLSessionTransport, tests inject a mock — so
// the whole hosted driver is exercised on Linux CI with zero network I/O,
// matching the services/api convention of pure logic behind a Store seam.

public struct HTTPRequest: Equatable, Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data = Data()) {
        self.status = status
        self.body = body
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// URLSession-backed transport — the production driver. Uses the completion-
/// handler API (not the async overloads) because FoundationNetworking on Linux
/// doesn't ship them for our toolchain floor.
public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        urlRequest.httpBody = request.body

        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    continuation.resume(throwing: SyncError.transferFailed("\(error)"))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: SyncError.transferFailed("non-HTTP response"))
                    return
                }
                continuation.resume(returning: HTTPResponse(status: http.statusCode, body: data ?? Data()))
            }.resume()
        }
    }
}
