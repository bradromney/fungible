import XCTest
import FungibleDomain
@testable import FungibleMeasure

final class ContoursTests: XCTestCase {
    /// One cell tilted along +Z: TL/TR low, BL/BR high.
    private func tiltedCell() -> HeightGrid {
        // heights[r*columns + c]: TL=0, TR=0, BL=2, BR=2
        HeightGrid(originX: 0, originZ: 0, cellSize: 1, columns: 2, rows: 2,
                   heights: [0, 0, 2, 2])
    }

    func testSingleLevelCrossingProducesOneSegment() {
        let segs = Contours.segments(from: tiltedCell(), interval: 1)
        XCTAssertEqual(segs.count, 1)
        let s = segs[0]
        XCTAssertEqual(s.elevation, 1, accuracy: 1e-9)
        // Iso-line at z = 0.5 across the cell, both ends at elevation 1.
        XCTAssertEqual(s.a.y, 1, accuracy: 1e-9)
        XCTAssertEqual(s.b.y, 1, accuracy: 1e-9)
        XCTAssertEqual(s.a.z, 0.5, accuracy: 1e-9)
        XCTAssertEqual(s.b.z, 0.5, accuracy: 1e-9)
    }

    func testFlatGridHasNoContours() {
        let flat = HeightGrid(originX: 0, originZ: 0, cellSize: 1, columns: 2, rows: 2,
                              heights: [5, 5, 5, 5])
        XCTAssertTrue(Contours.segments(from: flat, interval: 1).isEmpty)
    }

    func testMultipleLevelsAcrossRange() {
        // TL=0, TR=0, BL=3, BR=3 → interval 1 crosses levels 1 and 2.
        let grid = HeightGrid(originX: 0, originZ: 0, cellSize: 1, columns: 2, rows: 2,
                              heights: [0, 0, 3, 3])
        let segs = Contours.segments(from: grid, interval: 1)
        let levels = Set(segs.map { $0.elevation })
        XCTAssertEqual(levels, [1, 2])
    }

    func testCellsWithMissingHeightsAreSkipped() {
        let grid = HeightGrid(originX: 0, originZ: 0, cellSize: 1, columns: 2, rows: 2,
                              heights: [0, nil, 2, 2])
        XCTAssertTrue(Contours.segments(from: grid, interval: 1).isEmpty)
    }
}
