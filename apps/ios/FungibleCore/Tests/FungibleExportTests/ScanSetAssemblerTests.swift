import XCTest
import FungibleDomain
import FungibleCapture
import FungibleStorage
@testable import FungibleExport

final class ScanSetAssemblerTests: XCTestCase {
    private func points(at base: Double) -> [CapturedPoint] {
        [
            CapturedPoint(position: Vector3(base, 0, 0), confidence: .high),
            CapturedPoint(position: Vector3(base + 0.01, 0, 0), confidence: .high),
        ]
    }

    /// Two scans, the second posed +10 in z; assembler applies poses and unions.
    private func makeSet(store: InMemoryScanStore) async throws -> ScanSet {
        var set = ScanSet(name: "Assembled")
        let aID = ScanID(), bID = ScanID()
        let refA = try await store.writeBlob(points: points(at: 0), for: aID)
        let refB = try await store.writeBlob(points: points(at: 1), for: bID)
        set.append(Scan(id: aID, pointCloud: refA, pose: .identity, status: .registered))
        set.append(Scan(id: bID, pointCloud: refB,
                        pose: Transform(translation: Vector3(0, 0, 10)), status: .registered))
        return set
    }

    func testAssembleAppliesPosesAndUnionsAllPoints() async throws {
        let store = InMemoryScanStore()
        let set = try await makeSet(store: store)

        let merged = try await ScanSetAssembler(store: store).assemble(set)
        XCTAssertEqual(merged.count, 4)
        // The second scan's points are shifted +10 in z by its pose.
        XCTAssertTrue(merged.contains { abs($0.position.z - 10) < 1e-9 })
        XCTAssertTrue(merged.contains { abs($0.position.z) < 1e-9 })
    }

    func testDownsampleBoundsTheUnion() async throws {
        let store = InMemoryScanStore()
        let set = try await makeSet(store: store)

        // 1 m voxels collapse each scan's two near-coincident points into one.
        let merged = try await ScanSetAssembler(store: store).assemble(set, voxelSize: 1.0)
        XCTAssertEqual(merged.count, 2)
    }

    func testAssembledCloudExportsToPLY() async throws {
        let store = InMemoryScanStore()
        let set = try await makeSet(store: store)
        let merged = try await ScanSetAssembler(store: store).assemble(set)
        XCTAssertFalse(PLYExporter(binary: true).data(for: merged).isEmpty)
    }
}
