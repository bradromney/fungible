import XCTest
import FungibleDomain
@testable import FungibleSync

/// Thread-safe progress sink: the `SyncProvider` progress closure is `@Sendable`,
/// so we can't mutate a captured `var` from it. This box is safe to capture.
private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _last: Double = 0
    var last: Double {
        lock.lock(); defer { lock.unlock() }
        return _last
    }
    func record(_ value: Double) {
        lock.lock(); _last = value; lock.unlock()
    }
}

final class LocalOnlyProviderTests: XCTestCase {
    private func makeTempFile(_ contents: String = "points") throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("laz")
        try contents.data(using: .utf8)!.write(to: url)
        return url.path
    }

    func testUploadExistingFileReportsSyncedAndCompletes() async throws {
        let path = try makeTempFile()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let provider = LocalOnlyProvider()
        let recorder = ProgressRecorder()
        let blob = SyncableBlob(hash: ContentHash(rawValue: "abc123"), localPath: path, byteSize: 6)
        let ref = try await provider.upload(blob) { recorder.record($0) }

        XCTAssertEqual(ref.backend, .localOnly)
        XCTAssertEqual(ref.locator, "abc123")
        XCTAssertEqual(recorder.last, 1.0, accuracy: 1e-9)
    }

    func testUploadMissingFileThrowsNotFound() async {
        let provider = LocalOnlyProvider()
        let blob = SyncableBlob(hash: ContentHash(rawValue: "missing"), localPath: "/no/such/file.laz", byteSize: 0)
        do {
            _ = try await provider.upload(blob) { _ in }
            XCTFail("Expected notFound")
        } catch {
            XCTAssertEqual(error as? SyncError, .notFound)
        }
    }

    func testStateIsLocalOnly() async {
        let provider = LocalOnlyProvider()
        let state = await provider.state(of: ContentHash(rawValue: "x"))
        XCTAssertEqual(state, .localOnly)
    }

    func testIsReady() async {
        let provider = LocalOnlyProvider()
        let ready = await provider.isReady
        XCTAssertTrue(ready)
    }
}
