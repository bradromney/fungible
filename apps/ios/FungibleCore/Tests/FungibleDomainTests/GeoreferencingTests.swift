import XCTest
@testable import FungibleDomain

final class GeoreferencingTests: XCTestCase {
    func testAnchorMakesLocalPointMapToCRSPoint() {
        let local = Vector3(1, 0, 1)
        let crs = Vector3(500_000, 12, 4_000_000) // UTM-ish easting/elev/northing
        let ref = CoordinateReference.anchored(epsg: "EPSG:32613", localPoint: local, crsPoint: crs)

        XCTAssertEqual(ref.epsg, "EPSG:32613")
        XCTAssertEqual(ref.toCRS(local), crs)
    }

    func testToCRSAndToLocalAreInverses() {
        let ref = CoordinateReference(epsg: "EPSG:32613", originOffset: Vector3(100, 5, -200))
        let p = Vector3(3, 4, 5)
        XCTAssertEqual(ref.toLocal(ref.toCRS(p)), p)
        XCTAssertEqual(ref.toCRS(ref.toLocal(p)), p)
    }

    func testAnchorTranslatesOtherPointsConsistently() {
        let ref = CoordinateReference.anchored(
            epsg: nil, localPoint: Vector3(0, 0, 0), crsPoint: Vector3(10, 0, 20)
        )
        // A point 1 m east of the anchor lands 1 m east in CRS too (metric scale).
        XCTAssertEqual(ref.toCRS(Vector3(1, 0, 0)), Vector3(11, 0, 20))
    }
}
