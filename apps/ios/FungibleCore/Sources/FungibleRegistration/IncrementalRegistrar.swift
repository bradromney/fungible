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
    public let submap: SubmapSelector

    public init(
        coarse: any CoarseAligner,
        fine: any FineAligner,
        optimizer: any PoseGraphOptimizer,
        submap: SubmapSelector = SubmapSelector()
    ) {
        self.coarse = coarse
        self.fine = fine
        self.optimizer = optimizer
        self.submap = submap
    }

    /// Register `newScan` (already appended to `set`) against the previous scan,
    /// add the resulting constraint, and re-optimize every pose. Returns the new
    /// edge's registration result, or nil for the first scan in a set.
    ///
    /// `prior` is the caller's relative-pose estimate taking the new scan's frame
    /// into the previous scan's frame — on device, derived from ARKit world
    /// tracking (`previousWorldPose.inverse().composed(with: newWorldPose)`).
    /// When present it seeds fine alignment directly; ICP converges locally, so
    /// without a prior any real inter-scan motion beyond the correspondence gate
    /// cannot register. Without a prior, coarse alignment supplies the seed
    /// (passthrough-identity today; a TEASER++ bridge later).
    ///
    /// `neighborSamples` makes registration scan-to-**submap** (ADR-0005): after
    /// the sequential edge lands, the scan is also aligned against its bounded
    /// graph neighborhood, adding redundant constraints that a real optimizer
    /// and loop closure exploit. Return nil for scans whose samples aren't
    /// available (e.g. not resident in memory) — they're simply skipped.
    @discardableResult
    public func register(
        newScan: ScanID,
        samples: PointSample,
        against previous: (id: ScanID, samples: PointSample)?,
        prior: Transform? = nil,
        neighborSamples: @Sendable (ScanID) async throws -> PointSample? = { _ in nil },
        in set: inout ScanSet
    ) async throws -> RegistrationResult? {
        set.poseGraph.addNode(newScan)

        guard let previous else {
            // First scan anchors the set's frame at the origin.
            apply([newScan: .identity], to: &set)
            return nil
        }

        // Seed for fine refinement: pose prior > coarse alignment.
        let initial: Transform
        if let prior {
            initial = prior
        } else {
            initial = try await coarse.align(source: samples, target: previous.samples).transform
        }
        let fineResult = try await fine.refine(
            source: samples, target: previous.samples, initial: initial
        )

        set.poseGraph.addConstraint(PoseConstraint(
            from: previous.id,
            to: newScan,
            relativePose: fineResult.transform,
            information: max(fineResult.fitness, 1e-3),
            kind: .sequential
        ))

        // Scan-to-submap: constrain against the local neighborhood too. The
        // sequential edge above is required; a neighbor that can't align (thin
        // overlap) is skipped without failing the registration.
        let previousPose = set.scan(previous.id)?.pose ?? .identity
        let newPoseEstimate = previousPose.composed(with: fineResult.transform)
        let neighbors = submap.neighborhood(of: newScan, in: set.poseGraph)
            .filter { $0 != previous.id && $0 != newScan }
        for neighbor in neighbors {
            guard let neighborSample = try await neighborSamples(neighbor) else { continue }
            let neighborPose = set.scan(neighbor)?.pose ?? .identity
            // Estimate mapping the new scan's frame into the neighbor's frame,
            // via both scans' current set-frame poses.
            let guess = neighborPose.inverse().composed(with: newPoseEstimate)
            guard let result = try? await fine.refine(
                source: samples, target: neighborSample, initial: guess
            ) else { continue }
            set.poseGraph.addConstraint(PoseConstraint(
                from: neighbor,
                to: newScan,
                relativePose: result.transform,
                information: max(result.fitness, 1e-3),
                kind: .submap
            ))
        }

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
