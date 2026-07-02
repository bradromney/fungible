import Foundation

/// A GPS fix captured alongside a scan pass (ADR-0011). Phone GNSS is ±3–5 m —
/// tagging / coarse-georeferencing grade, NOT survey grade — so `accuracy` is a
/// first-class field and consumers must treat it honestly. Full lat/lon → grid
/// projection (UTM, State Plane) is applied server-side via PROJ; on device we
/// keep the raw WGS84 fix and the metric relationships between fixes.
public struct GeoFix: Equatable, Codable, Sendable {
    public var latitude: Double        // degrees, WGS84
    public var longitude: Double       // degrees, WGS84
    public var altitude: Double        // meters, ellipsoidal/MSL as reported
    /// Radial horizontal accuracy (meters, 68% confidence). Lower is better;
    /// negative means the fix is invalid (CoreLocation convention).
    public var horizontalAccuracy: Double
    public var verticalAccuracy: Double
    /// True-north heading in degrees [0,360), if available.
    public var heading: Double?
    public var timestamp: Date

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double = 0,
        horizontalAccuracy: Double = -1,
        verticalAccuracy: Double = -1,
        heading: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.heading = heading
        self.timestamp = timestamp
    }

    /// A fix is usable when CoreLocation reported a non-negative accuracy.
    public var isValid: Bool { horizontalAccuracy >= 0 }
}

/// Pure geodesy: the parts we can do honestly on-device without a projection
/// library. Grid projection itself stays server-side (PROJ).
public enum Geodesy {
    /// UTM zone number (1…60) for a longitude in degrees.
    public static func utmZone(longitude: Double) -> Int {
        let normalized = (longitude + 180).truncatingRemainder(dividingBy: 360)
        let wrapped = normalized < 0 ? normalized + 360 : normalized
        return Swift.min(60, Swift.max(1, Int(wrapped / 6) + 1))
    }

    /// EPSG code for the WGS84 / UTM zone containing a fix — 326xx northern
    /// hemisphere, 327xx southern. This is the target grid the worker projects
    /// into; we can name it exactly from lat/lon alone.
    public static func utmEPSG(latitude: Double, longitude: Double) -> String {
        let zone = utmZone(longitude: longitude)
        let base = latitude >= 0 ? 32600 : 32700
        return "EPSG:\(base + zone)"
    }

    /// Local east-north-up offset (meters) of `fix` relative to `origin`, via the
    /// equirectangular small-area approximation. Accurate to well under 1% over a
    /// site (hundreds of meters) — enough to sanity-check GPS against the scanned
    /// displacement and to seed a local tangent frame. Not for long baselines.
    public static func enu(of fix: GeoFix, from origin: GeoFix) -> Vector3 {
        let metersPerDegLat = 111_320.0
        let lat0 = origin.latitude * .pi / 180
        let east = (fix.longitude - origin.longitude) * metersPerDegLat * cos(lat0)
        let north = (fix.latitude - origin.latitude) * metersPerDegLat
        let up = fix.altitude - origin.altitude
        return Vector3(east, north, up)
    }
}
