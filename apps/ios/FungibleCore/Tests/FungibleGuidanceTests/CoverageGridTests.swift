import XCTest
import FungibleDomain
@testable import FungibleGuidance

final class CoverageGridTests: XCTestCase {
    private func grid() -> CoverageGrid {
        // 2×2×2 m ROI at 1 m voxels → 8 voxels.
        CoverageGrid(bounds: BoundingBox(min: .zero, max: Vector3(2, 2, 2)), voxelSize: 1)
    }

    func testDimensionsAndTotal() {
        let g = grid()
        XCTAssertEqual(g.nx, 2); XCTAssertEqual(g.ny, 2); XCTAssertEqual(g.nz, 2)
        XCTAssertEqual(g.totalVoxels, 8)
        XCTAssertEqual(g.coverage, 0)
    }

    func testObserveMarksVoxelsAndDedups() {
        var g = grid()
        XCTAssertTrue(g.observe(Vector3(0.5, 0.5, 0.5)))   // voxel (0,0,0)
        XCTAssertFalse(g.observe(Vector3(0.9, 0.1, 0.2)))  // same voxel
        XCTAssertEqual(g.observedVoxels, 1)
        XCTAssertEqual(g.coverage, 1.0 / 8.0, accuracy: 1e-9)
    }

    func testPointsOutsideROIIgnored() {
        var g = grid()
        XCTAssertFalse(g.observe(Vector3(5, 5, 5)))
        XCTAssertEqual(g.observedVoxels, 0)
    }

    func testCompletionThreshold() {
        var g = grid()
        // Observe one point in each of the 8 voxels.
        for z in 0..<2 { for y in 0..<2 { for x in 0..<2 {
            g.observe(Vector3(Double(x) + 0.5, Double(y) + 0.5, Double(z) + 0.5))
        }}}
        XCTAssertEqual(g.coverage, 1.0, accuracy: 1e-9)
        XCTAssertTrue(g.isComplete(threshold: 0.9))
    }

    func testGapDirectionPointsAwayFromCoveredCorner() {
        var g = grid()
        // Cover only the voxel at the min corner; the unobserved centroid lies
        // toward +x/+y/+z, so from that corner the gap direction is positive.
        g.observe(Vector3(0.5, 0.5, 0.5))
        let dir = g.gapDirection(from: Vector3(0.5, 0.5, 0.5))
        let d = try! XCTUnwrap(dir)
        XCTAssertGreaterThan(d.x, 0)
        XCTAssertGreaterThan(d.y, 0)
        XCTAssertGreaterThan(d.z, 0)
        XCTAssertEqual(d.length, 1, accuracy: 1e-9)
    }

    func testGapDirectionNilWhenComplete() {
        var g = grid()
        for z in 0..<2 { for y in 0..<2 { for x in 0..<2 {
            g.observe(Vector3(Double(x) + 0.5, Double(y) + 0.5, Double(z) + 0.5))
        }}}
        XCTAssertNil(g.gapDirection(from: .zero))
    }
}
