import Foundation

// The pose graph is what lets a set grow without a scan-count ceiling
// (ADR-0005). Each scan is a node; each registration result is an edge
// constraint. A back-end optimizer (GTSAM iSAM2, bridged on-device) consumes
// this structure incrementally rather than re-solving everything per scan.

/// A relative-pose constraint between two scans, produced by registration or
/// by loop closure. `information` is a scalar confidence weight (higher = more
/// certain); the on-device optimizer maps it to a full information matrix.
public struct PoseConstraint: Equatable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case sequential   // adjacent capture-order alignment
        case submap       // redundant local-neighborhood alignment (ADR-0005)
        case loopClosure  // revisit detected; corrects accumulated drift
        case manual       // user-asserted alignment / correction
    }

    public var from: ScanID
    public var to: ScanID
    /// Transform taking `to`'s frame into `from`'s frame.
    public var relativePose: Transform
    public var information: Double
    public var kind: Kind

    public init(from: ScanID, to: ScanID, relativePose: Transform, information: Double = 1.0, kind: Kind = .sequential) {
        self.from = from
        self.to = to
        self.relativePose = relativePose
        self.information = information
        self.kind = kind
    }
}

/// Graph of scan nodes and the constraints between them. Holds structure only;
/// the numeric optimization lives behind `FungibleRegistration.PoseGraphOptimizer`.
public struct PoseGraph: Equatable, Codable, Sendable {
    public private(set) var nodes: [ScanID]
    public private(set) var constraints: [PoseConstraint]

    public init(nodes: [ScanID] = [], constraints: [PoseConstraint] = []) {
        self.nodes = nodes
        self.constraints = constraints
    }

    public mutating func addNode(_ id: ScanID) {
        guard !nodes.contains(id) else { return }
        nodes.append(id)
    }

    public mutating func addConstraint(_ c: PoseConstraint) {
        addNode(c.from)
        addNode(c.to)
        constraints.append(c)
    }

    /// Constraints touching a given scan — used to find a scan's local
    /// neighborhood for incremental (scan-to-submap) registration.
    public func constraints(touching id: ScanID) -> [PoseConstraint] {
        constraints.filter { $0.from == id || $0.to == id }
    }

    public var hasLoopClosures: Bool {
        constraints.contains { $0.kind == .loopClosure }
    }
}
