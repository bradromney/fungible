import XCTest
import FungibleDomain
@testable import FungiblePresentation

final class DisplayFormatTests: XCTestCase {

    func testGrouping() {
        XCTAssertEqual(DisplayFormat.grouped(0), "0")
        XCTAssertEqual(DisplayFormat.grouped(999), "999")
        XCTAssertEqual(DisplayFormat.grouped(1_000), "1,000")
        XCTAssertEqual(DisplayFormat.grouped(1_234_567), "1,234,567")
        XCTAssertEqual(DisplayFormat.grouped(-4200), "-4,200")
    }

    func testTrimOne() {
        XCTAssertEqual(DisplayFormat.trimOne(1.20), "1.2")
        XCTAssertEqual(DisplayFormat.trimOne(5.0), "5")
        XCTAssertEqual(DisplayFormat.trimOne(2.449), "2.4")
    }

    func testPointCountAbbreviation() {
        XCTAssertEqual(DisplayFormat.pointCount(923), "923")
        XCTAssertEqual(DisplayFormat.pointCount(12_300), "12.3K")
        XCTAssertEqual(DisplayFormat.pointCount(1_200_000), "1.2M")
        XCTAssertEqual(DisplayFormat.pointCount(5_000_000), "5M")
        XCTAssertEqual(DisplayFormat.pointCountLabel(1_200_000), "1.2M pts")
    }

    func testPassCountNeverImpliesACap() {
        XCTAssertEqual(DisplayFormat.passCount(1), "1 pass")
        XCTAssertEqual(DisplayFormat.passCount(12), "12 passes")
        XCTAssertEqual(DisplayFormat.passCount(0), "0 passes")
    }

    func testLinearDistance() {
        // 3.7592 m ≈ 12.333 ft ≈ 12' 4"
        XCTAssertEqual(DisplayFormat.feetInches(3.7592), "12' 4\"")
        XCTAssertEqual(DisplayFormat.feetDecimal(3.7592), "12.3 ft")
        XCTAssertEqual(DisplayFormat.metersEcho(3.7592), "3.76 m")
    }

    func testInchRollupBoundary() {
        // 11.99 ft should render as 12' 0", not 11' 12".
        let meters = 11.99 / Units.feetPerMeter
        XCTAssertEqual(DisplayFormat.feetInches(meters), "12' 0\"")
    }

    func testAreaPromotesToAcres() {
        // ~100 m² stays in sq ft.
        XCTAssertEqual(DisplayFormat.areaImperial(100), "1,076 sq ft")
        // ~2500 m² (> ½ acre) promotes to acres: 2500 m² ≈ 0.6178 acres.
        XCTAssertEqual(DisplayFormat.areaImperial(2500), "0.6 acres")
        XCTAssertEqual(DisplayFormat.areaMetricEcho(2500), "2,500 m²")
    }

    func testVolumeAndTruckLoads() {
        // 7 m³ ≈ 9.156 cu yd
        XCTAssertEqual(DisplayFormat.volumeCubicYards(7), "9.2 cu yd")
        XCTAssertEqual(DisplayFormat.volumeMetricEcho(7), "7 m³")
        // 9.156 cu yd / 12 ≈ 0.76 loads → rounds to 1.
        XCTAssertEqual(DisplayFormat.truckLoads(7), "≈ 1 truck load")
        // ~110 cu yd → ~9 loads.
        XCTAssertEqual(DisplayFormat.truckLoads(84), "≈ 9 truck loads")
        // Below half a load → nil (no gloss).
        XCTAssertNil(DisplayFormat.truckLoads(1))
    }

    func testQuality() {
        XCTAssertEqual(DisplayFormat.coverage(0.84), "84% coverage")
        XCTAssertEqual(DisplayFormat.drift(0.012), "1.2 cm drift")
        XCTAssertNil(DisplayFormat.drift(nil))
    }

    func testPreciseTimestampIsDeterministic() {
        // 2026-06-18 14:14:00 UTC
        let date = Date(timeIntervalSince1970: 1_781_792_040)
        let s = DisplayFormat.preciseTimestamp(
            date,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertEqual(s, "Jun 18, 2026 · 2:14 PM")
    }
}
