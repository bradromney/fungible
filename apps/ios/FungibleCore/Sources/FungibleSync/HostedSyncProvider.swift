import Foundation
import FungibleDomain

// The hosted cloud driver (ADR-0003's "Hosted S3/R2" option), speaking the
// services/api contract:
//
//   POST   /sets                 { name, pointCount }    -> { id, ... }
//   POST   /sets/:id/uploads     { filename }            -> { url, key }
//   PUT    <url>                 <bytes>                 -> 201
//   GET    /blobs/:key                                   -> bytes
//   POST   /sets/:id/share       { expiresInDays? }      -> { token, url, expiresAt? }
//   DELETE /share/:token                                 -> 204
//
// Every request carries the app's bearer key. File I/O and the network are
// injected (readFile/writeFile/transport) so the driver is fully unit-tested
// on Linux CI; URLSessionTransport + real file I/O are the defaults the app
// uses. Progress is start/finish only for now — resumable chunked transfer is
// the planned upgrade for large clouds and can land inside this driver without
// touching callers.

/// A minted share link plus the pieces the app needs to present it.
public struct HostedShareLink: Equatable, Sendable {
    public var token: String
    /// ISO-8601 expiry instant, when the share was minted with one.
    public var expiresAt: String?

    public init(token: String, expiresAt: String? = nil) {
        self.token = token
        self.expiresAt = expiresAt
    }

    /// The URL to hand to the share sheet: the web viewer resolves
    /// `?share=<token>&api=<apiBase>` against the API (see web/viewer).
    public func viewerURL(viewerBase: String, apiBase: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let safeToken = token.addingPercentEncoding(withAllowedCharacters: allowed) ?? token
        let safeAPI = apiBase.addingPercentEncoding(withAllowedCharacters: allowed) ?? apiBase
        return "\(viewerBase)?share=\(safeToken)&api=\(safeAPI)"
    }
}

public struct HostedSyncProvider: SyncProvider {
    public let backend: SyncBackend = .hosted
    public let baseURL: URL
    /// Remote set that protocol-level `upload`s land in (see `withSet`).
    public let boundSetID: String?

    private let apiKey: String
    private let transport: any HTTPTransport
    private let readFile: @Sendable (String) throws -> Data
    private let writeFile: @Sendable (Data, String) throws -> Void

    public init(
        baseURL: URL,
        apiKey: String,
        transport: any HTTPTransport = URLSessionTransport(),
        readFile: @escaping @Sendable (String) throws -> Data = { path in
            try Data(contentsOf: URL(fileURLWithPath: path))
        },
        writeFile: @escaping @Sendable (Data, String) throws -> Void = { data, path in
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.transport = transport
        self.readFile = readFile
        self.writeFile = writeFile
        self.boundSetID = nil
    }

    private init(copying other: HostedSyncProvider, boundSetID: String?) {
        self.baseURL = other.baseURL
        self.apiKey = other.apiKey
        self.transport = other.transport
        self.readFile = other.readFile
        self.writeFile = other.writeFile
        self.boundSetID = boundSetID
    }

    /// A copy whose protocol-level `upload` targets the given remote set.
    public func withSet(_ setID: String) -> HostedSyncProvider {
        HostedSyncProvider(copying: self, boundSetID: setID)
    }

    public var isReady: Bool {
        get async { !apiKey.isEmpty }
    }

    // MARK: - Share loop (beyond the SyncProvider protocol)

    /// Create the remote counterpart of a local ScanSet; returns its remote id.
    public func createRemoteSet(name: String, pointCount: Int = 0) async throws -> String {
        struct Body: Encodable { let name: String; let pointCount: Int }
        struct Reply: Decodable { let id: String }
        let response = try await send("POST", "/sets", json: Body(name: name, pointCount: pointCount))
        return try decode(Reply.self, from: response).id
    }

    /// Upload a blob under a remote set. Two steps, mirroring the API: request
    /// an upload target, then PUT the bytes to it. The returned locator is the
    /// backend object key.
    public func uploadBlob(
        _ blob: SyncableBlob,
        toSet setID: String,
        filename: String? = nil,
        progress: @Sendable @escaping (Double) -> Void = { _ in }
    ) async throws -> RemoteRef {
        struct Body: Encodable { let filename: String }
        struct Target: Decodable { let url: String; let key: String }

        progress(0)
        let name = filename ?? "\(blob.hash.rawValue).fpc"
        let response = try await send("POST", "/sets/\(setID)/uploads", json: Body(filename: name))
        let target = try decode(Target.self, from: response)

        let bytes = try readFile(blob.localPath)
        var put = try request("PUT", target.url)
        put.headers["content-type"] = "application/octet-stream"
        put.body = bytes
        let putResponse = try await transport.send(put)
        try check(putResponse)

        progress(1)
        return RemoteRef(backend: .hosted, locator: target.key)
    }

    /// Mint a share link for a remote set (optionally expiring).
    public func mintShare(for setID: String, expiresInDays: Int? = nil) async throws -> HostedShareLink {
        struct Body: Encodable { let expiresInDays: Int? }
        struct Reply: Decodable { let token: String; let expiresAt: String? }
        let response = try await send("POST", "/sets/\(setID)/share", json: Body(expiresInDays: expiresInDays))
        let reply = try decode(Reply.self, from: response)
        return HostedShareLink(token: reply.token, expiresAt: reply.expiresAt)
    }

    /// Revoke a share link so it stops resolving.
    public func revokeShare(token: String) async throws {
        let response = try await transport.send(request("DELETE", "/share/\(token)"))
        try check(response)
    }

    // MARK: - SyncProvider

    public func upload(_ blob: SyncableBlob, progress: @Sendable @escaping (Double) -> Void) async throws -> RemoteRef {
        guard let setID = boundSetID else {
            throw SyncError.transferFailed("no remote set bound — use withSet(_:) or uploadBlob(_:toSet:)")
        }
        return try await uploadBlob(blob, toSet: setID, progress: progress)
    }

    public func download(_ ref: RemoteRef, to localPath: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        progress(0)
        let response = try await transport.send(request("GET", "/blobs/\(ref.locator)"))
        try check(response)
        try writeFile(response.body, localPath)
        progress(1)
    }

    public func state(of hash: ContentHash) async -> SyncState {
        // The API has no lookup-by-hash endpoint yet; without one we can't
        // distinguish synced from local-only, so report the conservative state.
        .localOnly
    }

    public func delete(_ ref: RemoteRef) async throws {
        // The API deliberately has no blob-delete endpoint yet (shares would
        // dangle); revoke the share instead. Fail loudly rather than pretend.
        throw SyncError.transferFailed("hosted blob delete is not supported yet")
    }

    // MARK: - Request plumbing

    private func request(_ method: String, _ path: String) throws -> HTTPRequest {
        let base = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        guard let url = URL(string: base + path) else {
            throw SyncError.transferFailed("bad URL: \(base + path)")
        }
        return HTTPRequest(method: method, url: url, headers: ["authorization": "Bearer \(apiKey)"])
    }

    private func send(_ method: String, _ path: String, json body: some Encodable) async throws -> HTTPResponse {
        var req = try request(method, path)
        req.headers["content-type"] = "application/json"
        req.body = try JSONEncoder().encode(body)
        let response = try await transport.send(req)
        try check(response)
        return response
    }

    private func check(_ response: HTTPResponse) throws {
        switch response.status {
        case 200...299: return
        case 401, 403: throw SyncError.notAuthorized
        case 404: throw SyncError.notFound
        default: throw SyncError.transferFailed("HTTP \(response.status)")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from response: HTTPResponse) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: response.body)
        } catch {
            throw SyncError.transferFailed("malformed API response: \(error)")
        }
    }
}
