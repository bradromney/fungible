import XCTest
import FungibleDomain
import FungibleCapture
@testable import FungibleStorage

final class GarbageCollectionTests: XCTestCase {
    private func point(_ x: Double) -> [CapturedPoint] {
        [CapturedPoint(position: Vector3(x, 0, 0), confidence: .high)]
    }

    func testInMemoryGCDropsOrphanBlobs() async throws {
        let store = InMemoryScanStore()
        let keptID = ScanID()
        let keptRef = try await store.writeBlob(points: point(0), for: keptID)
        let orphanRef = try await store.writeBlob(points: point(99), for: ScanID())

        var set = ScanSet(name: "Keep")
        set.append(Scan(id: keptID, pointCloud: keptRef, status: .registered))

        let before = await store.diskUsageBytes()
        let freed = try await store.collectGarbage(keeping: [set])
        let after = await store.diskUsageBytes()

        XCTAssertGreaterThan(freed, 0)
        XCTAssertEqual(after, before - freed)
        // Kept blob still readable; orphan gone.
        let keptCount = try await store.readBlob(keptRef).count
        XCTAssertEqual(keptCount, 1)
        do {
            _ = try await store.readBlob(orphanRef)
            XCTFail("orphan should be collected")
        } catch {
            XCTAssertEqual(error as? StorageError, .blobNotFound)
        }
    }

    func testFileGCDropsOrphanBlobs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try FileScanStore(root: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let keptID = ScanID()
        let keptRef = try await store.writeBlob(points: point(0), for: keptID)
        _ = try await store.writeBlob(points: point(99), for: ScanID()) // orphan

        var set = ScanSet(name: "Keep")
        set.append(Scan(id: keptID, pointCloud: keptRef, status: .registered))

        let freed = try await store.collectGarbage(keeping: [set])
        XCTAssertGreaterThan(freed, 0)
        XCTAssertNotNil(store.localURL(for: keptRef))
        let keptCount = try await store.readBlob(keptRef).count
        XCTAssertEqual(keptCount, 1)
    }

    func testGCKeepsEverythingWhenAllReferenced() async throws {
        let store = InMemoryScanStore()
        let id = ScanID()
        let ref = try await store.writeBlob(points: point(0), for: id)
        var set = ScanSet()
        set.append(Scan(id: id, pointCloud: ref, status: .registered))
        let freed = try await store.collectGarbage(keeping: [set])
        XCTAssertEqual(freed, 0)
    }
}
