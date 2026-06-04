import XCTest
import FungibleDomain
@testable import FungibleRegistration

final class SpatialHashGridTests: XCTestCase {
    private func cloud() -> [Vector3] {
        var pts: [Vector3] = []
        for x in 0..<5 { for y in 0..<5 { for z in 0..<5 {
            pts.append(Vector3(Double(x), Double(y), Double(z)))
        }}}
        return pts
    }

    private func bruteNearest(_ q: Vector3, _ pts: [Vector3]) -> Int {
        var best = -1, bestSq = Double.greatestFiniteMagnitude
        for (i, p) in pts.enumerated() {
            let sq = (p - q).length * (p - q).length
            if sq < bestSq { bestSq = sq; best = i }
        }
        return best
    }

    func testMatchesBruteForceWithinCellSize() {
        let pts = cloud()
        let grid = SpatialHashGrid(points: pts, cellSize: 1.0)
        // Queries whose true nearest is < cellSize away → must match brute force.
        let queries = [Vector3(1.2, 1.1, 0.9), Vector3(3.4, 2.6, 4.1), Vector3(0.1, 4.0, 2.0)]
        for q in queries {
            let hit = try! XCTUnwrap(grid.nearest(to: q))
            XCTAssertEqual(hit.index, bruteNearest(q, pts))
            XCTAssertEqual(hit.distance, (pts[hit.index] - q).length, accuracy: 1e-9)
        }
    }

    func testReturnsNilWhenNeighborhoodEmpty() {
        let grid = SpatialHashGrid(points: [Vector3(0, 0, 0)], cellSize: 0.1)
        XCTAssertNil(grid.nearest(to: Vector3(5, 5, 5))) // far outside the 3x3x3 block
    }

    func testFindsExactPoint() {
        let pts = cloud()
        let grid = SpatialHashGrid(points: pts, cellSize: 1.0)
        let hit = try! XCTUnwrap(grid.nearest(to: Vector3(2, 3, 4)))
        XCTAssertEqual(hit.distance, 0, accuracy: 1e-12)
        XCTAssertEqual(hit.point, Vector3(2, 3, 4))
    }

    func testEmptyGrid() {
        let grid = SpatialHashGrid(points: [], cellSize: 1.0)
        XCTAssertTrue(grid.isEmpty)
        XCTAssertNil(grid.nearest(to: .zero))
    }
}
