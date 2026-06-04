import Foundation

/// An axis-aligned bounding box in the set's coordinate frame (meters). Used to
/// define the region of interest: an open site has no natural "done", so the
/// user's bounds are what make "coverage complete" meaningful (see guidance).
public struct BoundingBox: Equatable, Codable, Sendable {
    public var min: Vector3
    public var max: Vector3

    public init(min: Vector3, max: Vector3) {
        self.min = min
        self.max = max
    }

    public func contains(_ p: Vector3) -> Bool {
        p.x >= min.x && p.x <= max.x &&
        p.y >= min.y && p.y <= max.y &&
        p.z >= min.z && p.z <= max.z
    }

    public var sizeMeters: Vector3 { max - min }

    public var center: Vector3 { (min + max) * 0.5 }

    /// Axis-aligned box enclosing all points (nil if empty). Useful for
    /// defaulting a region-of-interest from a first scan.
    static func containing(_ points: [Vector3]) -> BoundingBox? {
        guard let first = points.first else { return nil }
        var lo = first, hi = first
        for p in points {
            lo = Vector3(Swift.min(lo.x, p.x), Swift.min(lo.y, p.y), Swift.min(lo.z, p.z))
            hi = Vector3(Swift.max(hi.x, p.x), Swift.max(hi.y, p.y), Swift.max(hi.z, p.z))
        }
        return BoundingBox(min: lo, max: hi)
    }
}

/// Optional region the user cares about, plus how complete we consider coverage.
public struct RegionOfInterest: Equatable, Codable, Sendable {
    public var bounds: BoundingBox
    /// Coverage fraction [0,1] at which we tell the user "you've got enough".
    public var completionThreshold: Double

    public init(bounds: BoundingBox, completionThreshold: Double = 0.9) {
        self.bounds = bounds
        self.completionThreshold = completionThreshold
    }
}

/// Coordinate reference for georeferencing on export (resolved via PROJ in the
/// cloud worker). `nil` means a local, ungeoreferenced frame.
public struct CoordinateReference: Equatable, Codable, Sendable {
    /// e.g. "EPSG:32613" (UTM 13N). Kept as a string so we don't bind PROJ here.
    public var epsg: String?
    /// Translation from the local frame origin to the CRS origin (meters).
    public var originOffset: Vector3

    public init(epsg: String? = nil, originOffset: Vector3 = .zero) {
        self.epsg = epsg
        self.originOffset = originOffset
    }
}

/// A site/project. Grows incrementally without a scan-count limit (ADR-0005).
public struct ScanSet: Identifiable, Equatable, Codable, Sendable {
    public let id: ScanSetID
    public var name: String
    public var createdAt: Date
    public var regionOfInterest: RegionOfInterest?
    public var crs: CoordinateReference?
    public var poseGraph: PoseGraph
    public var scans: [Scan]
    public var measurements: [Measurement]
    public var annotations: [Annotation]

    public init(
        id: ScanSetID = ScanSetID(),
        name: String = "Untitled Site",
        createdAt: Date = Date(),
        regionOfInterest: RegionOfInterest? = nil,
        crs: CoordinateReference? = nil,
        poseGraph: PoseGraph = PoseGraph(),
        scans: [Scan] = [],
        measurements: [Measurement] = [],
        annotations: [Annotation] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.regionOfInterest = regionOfInterest
        self.crs = crs
        self.poseGraph = poseGraph
        self.scans = scans
        self.measurements = measurements
        self.annotations = annotations
    }

    public var scanCount: Int { scans.count }

    public func scan(_ id: ScanID) -> Scan? { scans.first { $0.id == id } }

    /// Add a freshly-finalized scan and register it as a node. No limit check —
    /// that absence is the point (ADR-0005).
    public mutating func append(_ scan: Scan) {
        scans.append(scan)
        poseGraph.addNode(scan.id)
    }

    /// Aggregate coverage across the set, clamped to [0,1].
    public var coverage: Double {
        guard !scans.isEmpty else { return 0 }
        let total = scans.reduce(0.0) { $0 + $1.quality.coverage }
        return Swift.min(1.0, total / Double(scans.count))
    }

    public var isComplete: Bool {
        guard let roi = regionOfInterest else { return false }
        return coverage >= roi.completionThreshold
    }
}
