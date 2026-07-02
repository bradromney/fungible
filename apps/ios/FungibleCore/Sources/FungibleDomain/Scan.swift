import Foundation

/// A handle to point-cloud bytes on disk or in a sync provider — never the
/// bytes themselves. Domain code passes references around; only the storage and
/// rendering layers touch the actual points.
public struct PointCloudRef: Equatable, Hashable, Codable, Sendable {
    /// Content address of the finalized blob, if it has been finalized.
    public var hash: ContentHash?
    /// Relative path within the local store (capture chunks or finalized COPC).
    public var localPath: String?
    /// Approximate point count, for UI and LOD budgeting.
    public var pointCount: Int
    /// On-disk byte size of the finalized blob, if known.
    public var byteSize: Int?

    public init(hash: ContentHash? = nil, localPath: String? = nil, pointCount: Int = 0, byteSize: Int? = nil) {
        self.hash = hash
        self.localPath = localPath
        self.pointCount = pointCount
        self.byteSize = byteSize
    }
}

/// Lifecycle of a single scan as it moves through the incremental pipeline.
public enum ScanStatus: String, Codable, Sendable, CaseIterable {
    case capturing      // actively accumulating points
    case pendingRegister // finalized, queued for registration
    case registering    // background registration in progress
    case registered     // aligned into the set's frame
    case failed          // registration failed; user can retry / re-assign
}

/// A quality summary computed during/after capture, surfaced to the user and
/// used by the guidance engine. All values are best-effort estimates.
public struct QualityReport: Equatable, Codable, Sendable {
    /// Fraction [0,1] of the region-of-interest voxels observed.
    public var coverage: Double
    /// Fraction [0,1] of points captured at high ARKit confidence.
    public var highConfidenceFraction: Double
    /// Estimated registration drift in meters (nil until registered).
    public var driftEstimateMeters: Double?

    public init(coverage: Double = 0, highConfidenceFraction: Double = 0, driftEstimateMeters: Double? = nil) {
        self.coverage = coverage
        self.highConfidenceFraction = highConfidenceFraction
        self.driftEstimateMeters = driftEstimateMeters
    }
}

/// One capture pass. Auto-saved the moment capture finishes (ADR-0005) — there
/// is no manual save step and no per-set count limit.
public struct Scan: Identifiable, Equatable, Codable, Sendable {
    public let id: ScanID
    public var capturedAt: Date
    public var deviceModel: String
    public var pointCloud: PointCloudRef
    /// Optimized transform mapping this scan's points into the set's frame.
    public var pose: Transform
    public var quality: QualityReport
    public var status: ScanStatus
    /// GPS fix captured at finalize, if location was available (ADR-0011).
    /// Optional so a scan without a fix — or written before GPS existed —
    /// decodes cleanly (synthesized Codable uses decodeIfPresent for optionals).
    public var geoFix: GeoFix?

    public init(
        id: ScanID = ScanID(),
        capturedAt: Date = Date(),
        deviceModel: String = "",
        pointCloud: PointCloudRef = PointCloudRef(),
        pose: Transform = .identity,
        quality: QualityReport = QualityReport(),
        status: ScanStatus = .capturing,
        geoFix: GeoFix? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.deviceModel = deviceModel
        self.pointCloud = pointCloud
        self.pose = pose
        self.quality = quality
        self.status = status
        self.geoFix = geoFix
    }
}
