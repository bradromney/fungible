import XCTest
import FungibleDomain
@testable import FungibleMeasure

final class CutFillTests: XCTestCase {
    /// A flat 3×3 m surface of points at a given elevation, one point per cell.
    private func flatSurface(y: Double) -> [Vector3] {
        var pts: [Vector3] = []
        for x in 0...2 {
            for z in 0...2 {
                pts.append(Vector3(Double(x), y, Double(z)))
            }
        }
        return pts
    }

    func testTopSurfaceBuildsExpectedGrid() throws {
        let grid = try XCTUnwrap(HeightGrid.topSurface(from: flatSurface(y: 2), cellSize: 1))
        XCTAssertEqual(grid.columns, 3)
        XCTAssertEqual(grid.rows, 3)
        XCTAssertEqual(grid.filledCellCount, 9)
        XCTAssertEqual(grid.height(col: 1, row: 1), 2)
    }

    func testTopSurfaceTakesMaxYPerCell() throws {
        // Two points in the same cell at different heights → cell takes the max.
        let pts = [Vector3(0, 1, 0), Vector3(0.4, 5, 0.4)]
        let grid = try XCTUnwrap(HeightGrid.topSurface(from: pts, cellSize: 1))
        XCTAssertEqual(grid.height(col: 0, row: 0), 5)
    }

    func testCutVolumeAgainstReferencePlane() throws {
        // Flat surface 2 m above a reference plane at 0 over 9 cells of 1 m² →
        // everything is "cut" (existing above design): 9 × 2 × 1 = 18 m³.
        let grid = try XCTUnwrap(HeightGrid.topSurface(from: flatSurface(y: 2), cellSize: 1))
        let result = CutFillEngine.compare(existing: grid, toReferenceElevation: 0)
        XCTAssertEqual(result.cutVolume, 18, accuracy: 1e-9)
        XCTAssertEqual(result.fillVolume, 0, accuracy: 1e-9)
        XCTAssertEqual(result.comparedCells, 9)
        XCTAssertEqual(result.netVolume, -18, accuracy: 1e-9)
    }

    func testFillVolumeAgainstReferencePlane() throws {
        // Surface 1 m below the target grade → all fill: 9 × 1 × 1 = 9 m³.
        let grid = try XCTUnwrap(HeightGrid.topSurface(from: flatSurface(y: -1), cellSize: 1))
        let result = CutFillEngine.compare(existing: grid, toReferenceElevation: 0)
        XCTAssertEqual(result.fillVolume, 9, accuracy: 1e-9)
        XCTAssertEqual(result.cutVolume, 0, accuracy: 1e-9)
    }

    func testCompareTwoGridsRaisingGradeIsFill() throws {
        let existing = try XCTUnwrap(HeightGrid.topSurface(from: flatSurface(y: 0), cellSize: 1))
        let design = try XCTUnwrap(HeightGrid.topSurface(from: flatSurface(y: 1), cellSize: 1))
        let result = try XCTUnwrap(CutFillEngine.compare(existing: existing, design: design))
        XCTAssertEqual(result.fillVolume, 9, accuracy: 1e-9)
        XCTAssertEqual(result.cutVolume, 0, accuracy: 1e-9)
        XCTAssertEqual(result.netVolume, 9, accuracy: 1e-9)
    }

    func testMismatchedGridGeometryReturnsNil() throws {
        let a = try XCTUnwrap(HeightGrid.topSurface(from: flatSurface(y: 0), cellSize: 1))
        let b = try XCTUnwrap(HeightGrid.topSurface(from: flatSurface(y: 0), cellSize: 2))
        XCTAssertNil(CutFillEngine.compare(existing: a, design: b))
    }

    func testMisalignedOriginsReturnNil() throws {
        // Same shape and cell size, but the design surface sits 10 m east: the
        // grids cover different ground, so a cell-by-cell compare must refuse
        // rather than integrate misaligned heights into a wrong volume.
        let shifted = flatSurface(y: 1).map { Vector3($0.x + 10, $0.y, $0.z) }
        let existing = try XCTUnwrap(HeightGrid.topSurface(from: flatSurface(y: 0), cellSize: 1))
        let design = try XCTUnwrap(HeightGrid.topSurface(from: shifted, cellSize: 1))
        XCTAssertEqual(existing.columns, design.columns)
        XCTAssertEqual(existing.rows, design.rows)
        XCTAssertNil(CutFillEngine.compare(existing: existing, design: design))
    }
}
