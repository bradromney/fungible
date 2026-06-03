import XCTest
import FungibleDomain
@testable import FungibleSync

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
        var lastProgress = 0.0
        let blob = SyncableBlob(hash: ContentHash(rawValue: "abc123"), localPath: path, byteSize: 6)
        let ref = try await provider.upload(blob) { lastProgress = $0 }

        XCTAssertEqual(ref.backend, .localOnly)
        XCTAssertEqual(ref.locator, "abc123")
        XCTAssertEqual(lastProgress, 1.0, accuracy: 1e-9)
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
