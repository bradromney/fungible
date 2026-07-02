import XCTest
@testable import FungibleDomain

final class GeoFixTests: XCTestCase {

    func testValidityFollowsAccuracy() {
        XCTAssertFalse(GeoFix(latitude: 40, longitude: -111).isValid, "default -1 accuracy is invalid")
        XCTAssertTrue(GeoFix(latitude: 40, longitude: -111, horizontalAccuracy: 5).isValid)
    }

    func testUTMZoneAndEPSG() {
        XCTAssertEqual(Geodesy.utmZone(longitude: 0), 31)
        XCTAssertEqual(Geodesy.utmZone(longitude: -111), 12)   // Utah
        XCTAssertEqual(Geodesy.utmZone(longitude: -123), 10)   // Pacific NW
        // Northern hemisphere → 326xx, southern → 327xx.
        XCTAssertEqual(Geodesy.utmEPSG(latitude: 40.7, longitude: -111.9), "EPSG:32612")
        XCTAssertEqual(Geodesy.utmEPSG(latitude: -33.9, longitude: 151.2), "EPSG:32756") // Sydney
    }

    func testENUOffsetIsMetricAndSigned() {
        let origin = GeoFix(latitude: 0, longitude: 0, altitude: 100, horizontalAccuracy: 5)
        // At the equator, 0.001° ≈ 111.32 m in both axes.
        let east = Geodesy.enu(of: GeoFix(latitude: 0, longitude: 0.001), from: origin)
        XCTAssertEqual(east.x, 111.32, accuracy: 0.2)
        XCTAssertEqual(east.y, 0, accuracy: 1e-6)
        let north = Geodesy.enu(of: GeoFix(latitude: 0.001, longitude: 0, altitude: 105), from: origin)
        XCTAssertEqual(north.y, 111.32, accuracy: 0.2)
        XCTAssertEqual(north.z, 5, accuracy: 1e-6, "up = altitude delta")
    }

    func testScanGeoFixRoundTripsAndLegacyDecodesNil() throws {
        var scan = Scan(deviceModel: "iPhone")
        scan.geoFix = GeoFix(latitude: 40.7, longitude: -111.9, horizontalAccuracy: 4.5)
        let decoded = try JSONDecoder().decode(Scan.self, from: JSONEncoder().encode(scan))
        XCTAssertEqual(decoded.geoFix, scan.geoFix)

        // A scan written before geoFix existed decodes with a nil fix.
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(scan)) as! [String: Any]
        obj.removeValue(forKey: "geoFix")
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        XCTAssertNil(try JSONDecoder().decode(Scan.self, from: stripped).geoFix)
    }

    func testBestGeoFixPicksMostAccurateValid() {
        var set = ScanSet()
        set.append(Scan(geoFix: GeoFix(latitude: 40, longitude: -111, horizontalAccuracy: 12)))
        set.append(Scan(geoFix: GeoFix(latitude: 40, longitude: -111, horizontalAccuracy: 4)))
        set.append(Scan(geoFix: GeoFix(latitude: 40, longitude: -111, horizontalAccuracy: -1))) // invalid
        XCTAssertEqual(set.bestGeoFix?.horizontalAccuracy, 4)
    }

    func testDeriveGeoreferencePrefersOriginPassAndNamesUTM() {
        var set = ScanSet()
        // First pass (the origin, identity pose) has a usable fix.
        set.append(Scan(geoFix: GeoFix(latitude: 40.7, longitude: -111.9, horizontalAccuracy: 6)))
        set.append(Scan(geoFix: GeoFix(latitude: 40.7, longitude: -111.9, horizontalAccuracy: 3)))

        XCTAssertTrue(set.deriveGeoreference())
        XCTAssertEqual(set.crs?.epsg, "EPSG:32612")
        XCTAssertEqual(set.crs?.geoAnchor?.horizontalAccuracy, 6, "anchored to the origin pass, not the most accurate")
    }

    func testDeriveGeoreferenceNoOpWithoutFix() {
        var set = ScanSet()
        set.append(Scan())
        XCTAssertFalse(set.deriveGeoreference())
        XCTAssertNil(set.crs)
    }
}
