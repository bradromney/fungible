import XCTest
@testable import FungibleDomain

final class MeasurementTests: XCTestCase {
    func testPlanAreaOfUnitSquare() {
        let m = Measurement(kind: .area, points: [
            Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1),
        ])
        XCTAssertEqual(m.planArea, 1.0, accuracy: 1e-9)
    }

    func testPlanAreaIgnoresElevation() {
        // Same footprint, varying heights → same plan (footprint) area.
        let m = Measurement(kind: .area, points: [
            Vector3(0, 5, 0), Vector3(2, 1, 0), Vector3(2, 9, 3), Vector3(0, -4, 3),
        ])
        XCTAssertEqual(m.planArea, 6.0, accuracy: 1e-9) // 2 × 3 footprint
    }

    func testPlanAreaWindingIndependent() {
        let cw = Measurement(kind: .area, points: [
            Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0),
        ])
        XCTAssertEqual(cw.planArea, 1.0, accuracy: 1e-9)
    }

    func testDegeneratePolygonsAreZeroArea() {
        XCTAssertEqual(Measurement(kind: .area, points: []).planArea, 0)
        XCTAssertEqual(Measurement(kind: .area, points: [Vector3(0, 0, 0), Vector3(1, 0, 0)]).planArea, 0)
    }

    func testClosedPerimeterClosesTheLoop() {
        let m = Measurement(kind: .area, points: [
            Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(3, 0, 4),
        ])
        // 3 + 4 + hypotenuse 5 = 12
        XCTAssertEqual(m.closedPerimeter, 12.0, accuracy: 1e-9)
    }
}
