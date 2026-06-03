import Foundation
import FungibleDomain

// The end-to-end control flow for no-ceiling capture (ADR-0005), independent of
// which aligners/optimizer back it. The caller appends a freshly-finalized Scan
// to the set (auto-save), then calls `register` to align it against the previous
// scan and re-optimize all poses. Per-scan cost stays bounded because we align
// against a local target, not every prior scan. Today it can run on the
// dependency-free ChainPoseGraphOptimizer + stub aligners; when the C++ bridge
// lands (TEASER++ / small_gicp / GTSAM), those conform to the same protocols and
// drop straight in.
public struct IncrementalRegistrar: Sendable {
    public let coarse: any CoarseAligner
    public let fine: any FineAligner
    public let optimizer: any PoseGraphOptimizer

    public init(coarse: any CoarseAligner, fine: any FineAligner, optimizer: any PoseGraphOptimizer) {
        self.coarse = coarse
        self.fine = fine
        self.optimizer = optimizer
    }

    /// Register `newScan` (already appended to `set`) against the previous scan,
    /// add the resulting constraint, and re-optimize every pose. Returns the new
    /// edge's registration result, or nil for the first scan in a set.
    @discardableResult
    public func register(
        newScan: ScanID,
        samples: PointSample,
        against previous: (id: ScanID, samples: PointSample)?,
        in set: inout ScanSet
    ) async throws -> RegistrationResult? {
        set.poseGraph.addNode(newScan)

        guard let previous else {
            // First scan anchors the set's frame at the origin.
            apply([newScan: .identity], to: &set)
            return nil
        }

        // Coarse global alignment (no initial guess) → fine refinement.
        let coarseResult = try await coarse.align(source: samples, target: previous.samples)
        let fineResult = try await fine.refine(
            source: samples, target: previous.samples, initial: coarseResult.transform
        )

        set.poseGraph.addConstraint(PoseConstraint(
            from: previous.id,
            to: newScan,
            relativePose: fineResult.transform,
            information: max(fineResult.fitness, 1e-3),
            kind: .sequential
        ))

        let poses = try await optimizer.optimize(set.poseGraph)
        apply(poses, to: &set)
        return fineResult
    }

    private func apply(_ poses: [ScanID: Transform], to set: inout ScanSet) {
        for i in set.scans.indices {
            if let pose = poses[set.scans[i].id] {
                set.scans[i].pose = pose
            }
        }
    }
}
