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

    func testHiddenScanIsExcludedButRecoverable() async throws {
        let store = InMemoryScanStore()
        var set = ScanSet(name: "Vis")
        let aID = ScanID(), bID = ScanID()
        let refA = try await store.writeBlob(points: points(at: 0), for: aID)
        let refB = try await store.writeBlob(points: points(at: 1), for: bID)
        set.append(Scan(id: aID, pointCloud: refA, pose: .identity, status: .registered))
        set.append(Scan(id: bID, pointCloud: refB,
                        pose: Transform(translation: Vector3(0, 0, 10)), status: .registered))

        set.setScan(bID, hidden: true)
        let visible = try await ScanSetAssembler(store: store).assemble(set)
        XCTAssertEqual(visible.count, 2, "hidden scan drops out of the merge")
        XCTAssertFalse(visible.contains { abs($0.position.z - 10) < 1e-9 })

        // includeHidden brings it back — nothing was deleted, just hidden.
        let all = try await ScanSetAssembler(store: store).assemble(set, includeHidden: true)
        XCTAssertEqual(all.count, 4)
    }

    func testAssembledCloudExportsToPLY() async throws {
        let store = InMemoryScanStore()
        let set = try await makeSet(store: store)
        let merged = try await ScanSetAssembler(store: store).assemble(set)
        XCTAssertFalse(PLYExporter(binary: true).data(for: merged).isEmpty)
    }

    // MARK: - Provenance for external unmerge (ADR-0010)

    func testAssembleAttributedTagsPointsByScanAndRespectsVisibility() async throws {
        let store = InMemoryScanStore()
        var set = try await makeSet(store: store)

        let (pts, ids) = try await ScanSetAssembler(store: store).assembleAttributed(set)
        XCTAssertEqual(pts.count, 4)
        XCTAssertEqual(ids, [1, 1, 2, 2], "1-based per scan, in visible order")

        set.setScan(set.scans[0].id, hidden: true)
        let (visPts, visIDs) = try await ScanSetAssembler(store: store).assembleAttributed(set)
        XCTAssertEqual(visPts.count, 2)
        XCTAssertEqual(visIDs, [1, 1], "remaining scan renumbers from 1")
    }

    func testLASRecordsCarryPointSourceIDs() async throws {
        let store = InMemoryScanStore()
        let set = try await makeSet(store: store)
        let (pts, ids) = try await ScanSetAssembler(store: store).assembleAttributed(set)
        let las = LASExporter().data(for: pts, sourceIDs: ids)

        // LAS 1.2 PDRF2: 227-byte header, 26-byte records; point-source-ID is
        // the little-endian u16 at record offset 18.
        XCTAssertEqual(las.count, 227 + 4 * 26)
        func sourceID(record i: Int) -> UInt16 {
            let base = 227 + i * 26 + 18
            return UInt16(las[base]) | (UInt16(las[base + 1]) << 8)
        }
        XCTAssertEqual((0..<4).map(sourceID(record:)), [1, 1, 2, 2])
    }
}
