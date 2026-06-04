import XCTest
@testable import FungibleDomain

final class BoundingBoxTests: XCTestCase {
    func testContainingComputesAABB() {
        let box = BoundingBox.containing([
            Vector3(1, -2, 3), Vector3(-4, 5, 0), Vector3(2, 2, 9),
        ])
        let b = try! XCTUnwrap(box)
        XCTAssertEqual(b.min, Vector3(-4, -2, 0))
        XCTAssertEqual(b.max, Vector3(2, 5, 9))
    }

    func testContainingEmptyIsNil() {
        XCTAssertNil(BoundingBox.containing([]))
    }

    func testCenterAndSize() {
        let b = BoundingBox(min: Vector3(0, 0, 0), max: Vector3(4, 2, 10))
        XCTAssertEqual(b.center, Vector3(2, 1, 5))
        XCTAssertEqual(b.sizeMeters, Vector3(4, 2, 10))
    }
}
