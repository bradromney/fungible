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

    /// Axis-aligned box enclosing all points (nil if empty). Used to default a
    /// region-of-interest and to auto-detect the project type from a first scan.
    public static func containing(_ points: [Vector3]) -> BoundingBox? {
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

/// Device-authored share intent (screen 09, ADR-0009). The hosted link's live
/// facts — view count, server-side expiry enforcement, the real URL — belong to
/// the SyncProvider, not here; this persists only what the user chose so the
/// toggles survive a reopen.
public struct ShareSettings: Equatable, Codable, Sendable {
    public enum Expiry: String, Codable, Sendable, CaseIterable {
        case never, week, month
    }
    public var isEnabled: Bool
    public var allowDownload: Bool
    public var expiry: Expiry
    /// Stable suffix of the minted link (e.g. "7f3a"); nil until first shared.
    public var linkSlug: String?

    public init(
        isEnabled: Bool = false,
        allowDownload: Bool = false,
        expiry: Expiry = .never,
        linkSlug: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.allowDownload = allowDownload
        self.expiry = expiry
        self.linkSlug = linkSlug
    }
}

/// A site/project. Grows incrementally without a scan-count limit (ADR-0005).
public struct ScanSet: Identifiable, Equatable, Codable, Sendable {
    public let id: ScanSetID
    public var name: String
    public var createdAt: Date
    /// What this project captures — tunes vocabulary + one tool slot (ADR-0007).
    public var type: ProjectType
    public var regionOfInterest: RegionOfInterest?
    public var crs: CoordinateReference?
    public var poseGraph: PoseGraph
    public var scans: [Scan]
    public var measurements: [Measurement]
    public var annotations: [Annotation]
    /// Device-authored web-share intent (ADR-0009).
    public var share: ShareSettings
    /// Scans the user has hidden/excluded from the combined cloud (ADR-0010).
    /// Non-destructive: the blob + pose stay, so show/hide is fully reversible —
    /// the merge is composed from the *visible* scans at read/export time.
    public var hiddenScans: Set<ScanID>

    public init(
        id: ScanSetID = ScanSetID(),
        name: String = "Untitled Site",
        createdAt: Date = Date(),
        type: ProjectType = .site,
        regionOfInterest: RegionOfInterest? = nil,
        crs: CoordinateReference? = nil,
        poseGraph: PoseGraph = PoseGraph(),
        scans: [Scan] = [],
        measurements: [Measurement] = [],
        annotations: [Annotation] = [],
        share: ShareSettings = ShareSettings(),
        hiddenScans: Set<ScanID> = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.type = type
        self.regionOfInterest = regionOfInterest
        self.crs = crs
        self.poseGraph = poseGraph
        self.scans = scans
        self.measurements = measurements
        self.annotations = annotations
        self.share = share
        self.hiddenScans = hiddenScans
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, type, regionOfInterest, crs, poseGraph, scans, measurements, annotations, share, hiddenScans
    }

    // Tolerant decode (ADR-0009): a set written before `type`/`share` existed
    // loads with sensible defaults rather than failing the whole catalog.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ScanSetID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        type = try c.decodeIfPresent(ProjectType.self, forKey: .type) ?? .site
        regionOfInterest = try c.decodeIfPresent(RegionOfInterest.self, forKey: .regionOfInterest)
        crs = try c.decodeIfPresent(CoordinateReference.self, forKey: .crs)
        poseGraph = try c.decode(PoseGraph.self, forKey: .poseGraph)
        scans = try c.decode([Scan].self, forKey: .scans)
        measurements = try c.decode([Measurement].self, forKey: .measurements)
        annotations = try c.decode([Annotation].self, forKey: .annotations)
        share = try c.decodeIfPresent(ShareSettings.self, forKey: .share) ?? ShareSettings()
        hiddenScans = try c.decodeIfPresent(Set<ScanID>.self, forKey: .hiddenScans) ?? []
    }

    public var scanCount: Int { scans.count }

    public func scan(_ id: ScanID) -> Scan? { scans.first { $0.id == id } }

    // MARK: - Reversible multi-scan composition (ADR-0010)

    /// The scans that make up the combined cloud right now — everything the user
    /// hasn't hidden. Registration, rendering, and export all work off this so
    /// hiding a scan never touches its stored points.
    public var visibleScans: [Scan] { scans.filter { !hiddenScans.contains($0.id) } }

    public func isVisible(_ id: ScanID) -> Bool { !hiddenScans.contains(id) }

    /// Hide/show a scan (reversible exclude). Ignores unknown ids.
    public mutating func setScan(_ id: ScanID, hidden: Bool) {
        guard scans.contains(where: { $0.id == id }) else { return }
        if hidden { hiddenScans.insert(id) } else { hiddenScans.remove(id) }
    }

    /// Split a subset of scans into a brand-new project, leaving this one intact.
    /// Each scan keeps its optimized pose, so the extracted set renders/exports
    /// correctly on its own; pose-graph edges wholly inside the subset carry over.
    /// The original is unchanged — the caller decides whether to also hide/remove
    /// the moved scans here.
    public func split(scanIDs: Set<ScanID>, name: String) -> ScanSet {
        let taken = scans.filter { scanIDs.contains($0.id) }
        var graph = PoseGraph()
        for scan in taken { graph.addNode(scan.id) }
        for c in poseGraph.constraints where scanIDs.contains(c.from) && scanIDs.contains(c.to) {
            graph.addConstraint(c)
        }
        return ScanSet(name: name, type: type, crs: crs, poseGraph: graph, scans: taken)
    }

    /// Add a freshly-finalized scan and register it as a node. No limit check —
    /// that absence is the point (ADR-0005).
    public mutating func append(_ scan: Scan) {
        scans.append(scan)
        poseGraph.addNode(scan.id)
    }

    // MARK: - Editing (ADR-0009)
    // Small, pure mutations the editor screens drive through the view-model,
    // which then writes the set back to the store. Upserts replace by id so a
    // re-saved edit doesn't duplicate.

    /// Add a measurement, or replace the existing one with the same id.
    public mutating func upsert(_ measurement: Measurement) {
        if let i = measurements.firstIndex(where: { $0.id == measurement.id }) {
            measurements[i] = measurement
        } else {
            measurements.append(measurement)
        }
    }

    public mutating func removeMeasurement(_ id: MeasurementID) {
        measurements.removeAll { $0.id == id }
    }

    /// Add an annotation, or replace the existing one with the same id.
    public mutating func upsert(_ annotation: Annotation) {
        if let i = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[i] = annotation
        } else {
            annotations.append(annotation)
        }
    }

    public mutating func removeAnnotation(_ id: AnnotationID) {
        annotations.removeAll { $0.id == id }
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
