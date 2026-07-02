import XCTest
import FungibleDomain
@testable import FungibleSync

/// Scripted transport: records every request, replays canned responses in
/// order. The whole hosted driver runs against this — no network in CI.
actor MockTransport: HTTPTransport {
    private(set) var requests: [HTTPRequest] = []
    private var responses: [HTTPResponse]

    init(responses: [HTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw SyncError.transferFailed("mock: no scripted response left")
        }
        return responses.removeFirst()
    }

    func recorded() -> [HTTPRequest] { requests }
}

/// Thread-safe capture box for progress callbacks / written files.
final class Captured<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value] = []

    func append(_ value: Value) {
        lock.lock(); defer { lock.unlock() }
        values.append(value)
    }

    var all: [Value] {
        lock.lock(); defer { lock.unlock() }
        return values
    }
}

final class HostedSyncProviderTests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!

    private func provider(
        _ transport: MockTransport,
        readFile: @escaping @Sendable (String) throws -> Data = { _ in Data([1, 2, 3]) },
        writeFile: @escaping @Sendable (Data, String) throws -> Void = { _, _ in }
    ) -> HostedSyncProvider {
        HostedSyncProvider(baseURL: base, apiKey: "k-secret", transport: transport,
                           readFile: readFile, writeFile: writeFile)
    }

    private func json(_ text: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, body: Data(text.utf8))
    }

    private func bodyJSON(_ request: HTTPRequest) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: request.body ?? Data())
        return object as? [String: Any] ?? [:]
    }

    func testCreateRemoteSetSendsAuthAndParsesID() async throws {
        let transport = MockTransport(responses: [
            json(#"{"id":"set-9","name":"Backyard","createdAt":"now","pointCount":42}"#, status: 201),
        ])
        let id = try await provider(transport).createRemoteSet(name: "Backyard", pointCount: 42)
        XCTAssertEqual(id, "set-9")

        let req = await transport.recorded()[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.url.absoluteString, "https://api.example.com/sets")
        XCTAssertEqual(req.headers["authorization"], "Bearer k-secret")
        let body = try bodyJSON(req)
        XCTAssertEqual(body["name"] as? String, "Backyard")
        XCTAssertEqual(body["pointCount"] as? Int, 42)
    }

    func testUploadBlobIsTwoStepsAndReportsProgress() async throws {
        let transport = MockTransport(responses: [
            json(#"{"url":"/blobs/set-9/scan.fpc","key":"set-9/scan.fpc"}"#, status: 201),
            HTTPResponse(status: 201),
        ])
        let progress = Captured<Double>()
        let blob = SyncableBlob(hash: ContentHash(rawValue: "sha256-abc"), localPath: "/tmp/x.fpc", byteSize: 3)

        let ref = try await provider(transport).uploadBlob(
            blob, toSet: "set-9", filename: "scan.fpc", progress: { progress.append($0) })

        XCTAssertEqual(ref, RemoteRef(backend: .hosted, locator: "set-9/scan.fpc"))
        XCTAssertEqual(progress.all.first, 0)
        XCTAssertEqual(progress.all.last, 1)

        let recorded = await transport.recorded()
        XCTAssertEqual(recorded.count, 2)
        XCTAssertEqual(recorded[0].url.absoluteString, "https://api.example.com/sets/set-9/uploads")
        XCTAssertEqual(try bodyJSON(recorded[0])["filename"] as? String, "scan.fpc")
        XCTAssertEqual(recorded[1].method, "PUT")
        XCTAssertEqual(recorded[1].url.absoluteString, "https://api.example.com/blobs/set-9/scan.fpc")
        XCTAssertEqual(recorded[1].body, Data([1, 2, 3]))          // the file's bytes
        XCTAssertEqual(recorded[1].headers["authorization"], "Bearer k-secret")
    }

    func testDefaultUploadFilenameDerivesFromHash() async throws {
        let transport = MockTransport(responses: [
            json(#"{"url":"/blobs/set-1/sha256-abc.fpc","key":"set-1/sha256-abc.fpc"}"#, status: 201),
            HTTPResponse(status: 201),
        ])
        let blob = SyncableBlob(hash: ContentHash(rawValue: "sha256-abc"), localPath: "/tmp/x.fpc", byteSize: 3)
        _ = try await provider(transport).uploadBlob(blob, toSet: "set-1")
        let first = await transport.recorded()[0]
        XCTAssertEqual(try bodyJSON(first)["filename"] as? String, "sha256-abc.fpc")
    }

    func testMintShareWithExpiryAndViewerURL() async throws {
        let transport = MockTransport(responses: [
            json(#"{"token":"tok-1","url":"/share/tok-1","expiresAt":"2026-07-09T00:00:00.000Z"}"#, status: 201),
        ])
        let share = try await provider(transport).mintShare(for: "set-9", expiresInDays: 7)
        XCTAssertEqual(share.token, "tok-1")
        XCTAssertEqual(share.expiresAt, "2026-07-09T00:00:00.000Z")

        let req = await transport.recorded()[0]
        XCTAssertEqual(req.url.absoluteString, "https://api.example.com/sets/set-9/share")
        XCTAssertEqual(try bodyJSON(req)["expiresInDays"] as? Int, 7)

        XCTAssertEqual(
            share.viewerURL(viewerBase: "https://view.fungible.app", apiBase: "https://api.example.com"),
            "https://view.fungible.app?share=tok-1&api=https%3A%2F%2Fapi.example.com"
        )
    }

    func testMintShareWithoutExpiryOmitsTheField() async throws {
        let transport = MockTransport(responses: [json(#"{"token":"tok-2","url":"/share/tok-2"}"#, status: 201)])
        let share = try await provider(transport).mintShare(for: "set-9")
        XCTAssertNil(share.expiresAt)
        let recorded = await transport.recorded()
        let body = try bodyJSON(recorded[0])
        XCTAssertNil(body["expiresInDays"], "absent expiry must not be sent as null")
    }

    func testRevokeShare() async throws {
        let transport = MockTransport(responses: [HTTPResponse(status: 204)])
        try await provider(transport).revokeShare(token: "tok-1")
        let req = await transport.recorded()[0]
        XCTAssertEqual(req.method, "DELETE")
        XCTAssertEqual(req.url.absoluteString, "https://api.example.com/share/tok-1")
    }

    func testErrorMapping() async throws {
        for (status, expected) in [(401, SyncError.notAuthorized), (404, .notFound), (500, .transferFailed("HTTP 500"))] {
            let transport = MockTransport(responses: [HTTPResponse(status: status)])
            do {
                _ = try await provider(transport).createRemoteSet(name: "X")
                XCTFail("expected error for HTTP \(status)")
            } catch {
                XCTAssertEqual(error as? SyncError, expected)
            }
        }
    }

    func testProtocolUploadRequiresABoundSet() async throws {
        let unbound = provider(MockTransport(responses: []))
        let blob = SyncableBlob(hash: ContentHash(rawValue: "h"), localPath: "/tmp/x", byteSize: 1)
        do {
            _ = try await unbound.upload(blob, progress: { _ in })
            XCTFail("expected failure without a bound set")
        } catch { /* expected */ }

        let transport = MockTransport(responses: [
            json(#"{"url":"/blobs/set-3/h.fpc","key":"set-3/h.fpc"}"#, status: 201),
            HTTPResponse(status: 201),
        ])
        let bound = provider(transport).withSet("set-3")
        let ref = try await bound.upload(blob, progress: { _ in })
        XCTAssertEqual(ref.locator, "set-3/h.fpc")
    }

    func testDownloadWritesFetchedBytes() async throws {
        let transport = MockTransport(responses: [HTTPResponse(status: 200, body: Data([9, 8, 7]))])
        let written = Captured<(String, Data)>()
        let p = provider(transport, writeFile: { data, path in written.append((path, data)) })

        try await p.download(RemoteRef(backend: .hosted, locator: "set-1/scan.fpc"), to: "/tmp/out.fpc", progress: { _ in })

        XCTAssertEqual(written.all.count, 1)
        XCTAssertEqual(written.all[0].0, "/tmp/out.fpc")
        XCTAssertEqual(written.all[0].1, Data([9, 8, 7]))
        let req = await transport.recorded()[0]
        XCTAssertEqual(req.url.absoluteString, "https://api.example.com/blobs/set-1/scan.fpc")
    }

    func testIsReadyRequiresAKey() async {
        let ready = HostedSyncProvider(baseURL: base, apiKey: "k", transport: MockTransport(responses: []))
        let notReady = HostedSyncProvider(baseURL: base, apiKey: "", transport: MockTransport(responses: []))
        let readyValue = await ready.isReady
        let notReadyValue = await notReady.isReady
        XCTAssertTrue(readyValue)
        XCTAssertFalse(notReadyValue)
    }
}
