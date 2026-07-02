import Foundation
import FungibleDomain

// The first LoopCloser implementation (ADR-0005's drift-correction half). The
// RTAB-Map-style appearance-based detector is the eventual upgrade; this
// baseline uses what we already trust: pose proximity. If the new scan's
// estimated origin lands near a much-earlier scan's origin, the user has
// walked back to somewhere they've been — verify the revisit with fine
// alignment and, when it holds, emit a `.loopClosure` constraint for the
// optimizer (GaussNewtonPoseGraphOptimizer) to pull accumulated drift back.
public struct ProximityLoopCloser: LoopCloser {
    /// How close (meters, between pose origins) counts as a revisit candidate.
    public var maxDistance: Double
    /// Candidates within this many capture positions are skipped — near-in-
    /// sequence overlap is submap territory, not a loop.
    public var minSequenceGap: Int
    /// Reject alignments below this fitness — a bad closure is worse than none.
    public var minFitness: Double

    private let fine: any FineAligner
    private let samples: @Sendable (ScanID) async throws -> PointSample?

    public init(
        fine: any FineAligner,
        maxDistance: Double = 3.0,
        minSequenceGap: Int = 5,
        minFitness: Double = 0.5,
        samples: @escaping @Sendable (ScanID) async throws -> PointSample?
    ) {
        precondition(minSequenceGap >= 1)
        self.fine = fine
        self.maxDistance = maxDistance
        self.minSequenceGap = minSequenceGap
        self.minFitness = minFitness
        self.samples = samples
    }

    public func detectClosures(in set: ScanSet, newScan: ScanID) async throws -> [PoseConstraint] {
        guard let newIndex = set.scans.firstIndex(where: { $0.id == newScan }) else { return [] }
        let newPose = set.scans[newIndex].pose
        guard let newSamples = try await samples(newScan) else { return [] }

        var closures: [PoseConstraint] = []
        for (index, candidate) in set.scans.enumerated() {
            guard newIndex - index >= minSequenceGap else { continue } // also skips self/later
            guard candidate.pose.translation.distance(to: newPose.translation) <= maxDistance else { continue }
            guard let candidateSamples = try await samples(candidate.id) else { continue }

            // Seed the verification from both scans' current pose estimates.
            let guess = candidate.pose.inverse().composed(with: newPose)
            guard let result = try? await fine.refine(
                source: newSamples, target: candidateSamples, initial: guess
            ), result.fitness >= minFitness else { continue }

            closures.append(PoseConstraint(
                from: candidate.id,
                to: newScan,
                relativePose: result.transform,
                information: max(result.fitness, 1e-3),
                kind: .loopClosure
            ))
        }
        return closures
    }
}
