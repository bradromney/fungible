import XCTest
import FungibleDomain
@testable import FungibleMeasure

final class BestFitPlaneTests: XCTestCase {
    func testFitFlatPlane() {
        let pts = [Vector3(0, 2, 0), Vector3(1, 2, 0), Vector3(0, 2, 1), Vector3(1, 2, 1)]
        let plane = try! XCTUnwrap(Plane.fit(pts))
        XCTAssertEqual(plane.a, 0, accuracy: 1e-9)
        XCTAssertEqual(plane.b, 0, accuracy: 1e-9)
        XCTAssertEqual(plane.c, 2, accuracy: 1e-9)
    }

    func testFitTiltedPlane() {
        // y = 0.5x + 0.25z + 1, sampled exactly → recovered exactly.
        func y(_ x: Double, _ z: Double) -> Double { 0.5 * x + 0.25 * z + 1 }
        var pts: [Vector3] = []
        for x in 0...3 { for z in 0...3 {
            pts.append(Vector3(Double(x), y(Double(x), Double(z)), Double(z)))
        }}
        let plane = try! XCTUnwrap(Plane.fit(pts))
        XCTAssertEqual(plane.a, 0.5, accuracy: 1e-9)
        XCTAssertEqual(plane.b, 0.25, accuracy: 1e-9)
        XCTAssertEqual(plane.c, 1, accuracy: 1e-9)
        XCTAssertEqual(plane.elevation(x: 2, z: 2), y(2, 2), accuracy: 1e-9)
    }

    func testDegenerateInputReturnsNil() {
        XCTAssertNil(Plane.fit([Vector3(0, 0, 0), Vector3(1, 0, 0)]))           // <3
        // All points collinear in plan (same x and z) → singular.
        XCTAssertNil(Plane.fit([Vector3(1, 0, 1), Vector3(1, 5, 1), Vector3(1, 9, 1)]))
    }

    func testCutFillAgainstFittedPlaneIsZeroWhenCoincident() throws {
        // A flat DEM at y=2 vs the plane y=2 → no cut, no fill.
        let dem = try XCTUnwrap(HeightGrid.topSurface(
            from: (0...4).flatMap { x in (0...4).map { z in Vector3(Double(x), 2, Double(z)) } },
            cellSize: 1))
        let result = CutFillEngine.compare(existing: dem, toPlane: Plane(a: 0, b: 0, c: 2))
        XCTAssertEqual(result.cutVolume, 0, accuracy: 1e-9)
        XCTAssertEqual(result.fillVolume, 0, accuracy: 1e-9)
    }

    func testCutFillAgainstLowerPlaneIsAllCut() throws {
        let dem = try XCTUnwrap(HeightGrid.topSurface(
            from: (0...2).flatMap { x in (0...2).map { z in Vector3(Double(x), 2, Double(z)) } },
            cellSize: 1))
        let result = CutFillEngine.compare(existing: dem, toPlane: Plane(a: 0, b: 0, c: 0))
        XCTAssertGreaterThan(result.cutVolume, 0)
        XCTAssertEqual(result.fillVolume, 0, accuracy: 1e-9)
    }
}
