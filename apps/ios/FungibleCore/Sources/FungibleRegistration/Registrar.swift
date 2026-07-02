import Foundation
import FungibleDomain

// The no-ceiling engine (ADR-0005). Implementations bridge to permissively
// licensed C++/Rust: TEASER++ (coarse), small_gicp (fine), GTSAM iSAM2
// (pose-graph back-end), RTAB-Map-style appearance loop closure. None of these
// is GPL; ORB-SLAM3 is explicitly excluded (see buy/build/reuse matrix).

/// A downsampled point set handed to the aligners. The dense bytes stay on
/// disk; registration works on a thinned copy for speed.
public struct PointSample: Equatable, Sendable {
    public var points: [Vector3]
    public init(points: [Vector3]) { self.points = points }
}

/// The result of aligning one scan against a target.
public struct RegistrationResult: Equatable, Sendable {
    public var transform: Transform   // maps source into target frame
    public var fitness: Double        // [0,1] overlap quality
    public var inlierRMSE: Double     // meters
    public init(transform: Transform, fitness: Double, inlierRMSE: Double) {
        self.transform = transform
        self.fitness = fitness
        self.inlierRMSE = inlierRMSE
    }
}

/// Coarse global alignment with no initial guess. Today: PassthroughCoarseAligner
/// (trusts the caller's prior); a TEASER++ + FPFH bridge is the future drop-in
/// for scans with no usable pose prior.
public protocol CoarseAligner: Sendable {
    func align(source: PointSample, target: PointSample) async throws -> RegistrationResult
}

/// Fine local refinement given an initial guess. Today: ICPFineAligner
/// (pure-Swift point-to-point ICP, ADR-0008); small_gicp point-to-plane is the
/// profiled drop-in if device profiling demands it.
public protocol FineAligner: Sendable {
    func refine(source: PointSample, target: PointSample, initial: Transform) async throws -> RegistrationResult
}

/// Incremental pose-graph optimization. Consumes the domain PoseGraph and
/// returns optimized per-scan poses, decoupling per-scan cost from total set
/// size. Today: ChainPoseGraphOptimizer (odometry-only composition — ignores
/// redundant/loop-closure edges); real optimization (GTSAM iSAM2 or a Swift
/// Gauss-Newton) is the drop-in this protocol exists for.
public protocol PoseGraphOptimizer: Sendable {
    func optimize(_ graph: PoseGraph) async throws -> [ScanID: Transform]
}

/// Detects revisits to add loop-closure constraints (RTAB-Map-style).
/// No implementation exists yet; drift correction is open until one does.
public protocol LoopCloser: Sendable {
    func detectClosures(in set: ScanSet, newScan: ScanID) async throws -> [PoseConstraint]
}

/// Top-level orchestrator: register a freshly-finalized scan into an existing
/// set against its local submap neighborhood (not all-pairs), update the pose
/// graph, run loop closure, and re-optimize. Runs off the capture thread.
public protocol Registrar: Sendable {
    func registerNewScan(_ scan: ScanID, into set: ScanSet) async throws -> ScanSet
}

public enum RegistrationError: Error, Equatable, Sendable {
    case insufficientOverlap
    case notEnoughPoints
    case optimizationFailed(String)
}
