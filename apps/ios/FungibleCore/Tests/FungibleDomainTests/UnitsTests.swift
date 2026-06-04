import XCTest
@testable import FungibleDomain

final class UnitsTests: XCTestCase {
    func testLengthConversion() {
        XCTAssertEqual(Units.feet(1), 3.280839895, accuracy: 1e-6)
        XCTAssertEqual(Units.feet(100), 328.0839895, accuracy: 1e-4)
    }

    func testAreaConversions() {
        XCTAssertEqual(Units.squareFeet(1), 10.7639104, accuracy: 1e-5)
        // 1 acre = 4046.856 m²
        XCTAssertEqual(Units.acres(4046.8564224), 1.0, accuracy: 1e-6)
    }

    func testVolumeConversion() {
        // 1 m³ ≈ 1.30795 yd³
        XCTAssertEqual(Units.cubicYards(1), 1.307950619, accuracy: 1e-6)
        XCTAssertEqual(Units.cubicYards(42), 54.9339, accuracy: 1e-3)
    }

    func testUnitSystemIsCodable() throws {
        let data = try JSONEncoder().encode(UnitSystem.imperial)
        XCTAssertEqual(try JSONDecoder().decode(UnitSystem.self, from: data), .imperial)
        XCTAssertEqual(UnitSystem.allCases.count, 2)
    }
}
