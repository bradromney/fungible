import Foundation
import FungibleDomain

// Iterative Closest Point, pure Swift. Repeatedly: match each (initial-aligned)
// source point to its nearest target within a gate, solve the best-fit rigid
// transform for those pairs (RigidAlignment), apply, and repeat until the inlier
// RMSE stops improving. This is the real, on-device, no-bridge registration
// engine (the GICP C++ lib would be a faster drop-in behind the same
// FineAligner protocol). Nearest-neighbour is brute force O(n·m) here — fine for
// the downsampled samples registration uses; a grid/kd-tree is the optimization.
public struct ICPFineAligner: FineAligner {
    public var maxIterations: Int
    public var maxCorrespondenceDistance: Double
    public var convergenceDelta: Double

    public init(maxIterations: Int = 30, maxCorrespondenceDistance: Double = 1.0, convergenceDelta: Double = 1e-5) {
        self.maxIterations = maxIterations
        self.maxCorrespondenceDistance = maxCorrespondenceDistance
        self.convergenceDelta = convergenceDelta
    }

    public func refine(source: PointSample, target: PointSample, initial: Transform) async throws -> RegistrationResult {
        let targets = target.points
        guard source.points.count >= 3, targets.count >= 3 else {
            throw RegistrationError.notEnoughPoints
        }

        // Index the target once (it doesn't move); cell size = the gate, so the
        // 3×3×3 search returns the exact nearest within maxCorrespondenceDistance.
        let index = SpatialHashGrid(points: targets, cellSize: maxCorrespondenceDistance)

        var current = initial
        var lastRMSE = Double.greatestFiniteMagnitude

        for _ in 0..<maxIterations {
            var srcMatched: [Vector3] = []
            var tgtMatched: [Vector3] = []
            var sqSum = 0.0

            for p in source.points {
                let tp = current.apply(to: p)
                if let hit = index.nearest(to: tp), hit.distance <= maxCorrespondenceDistance {
                    srcMatched.append(tp)
                    tgtMatched.append(hit.point)
                    sqSum += hit.distance * hit.distance
                }
            }

            guard srcMatched.count >= 3 else { throw RegistrationError.insufficientOverlap }

            let rmse = (sqSum / Double(srcMatched.count)).squareRoot()
            guard let delta = RigidAlignment.align(source: srcMatched, target: tgtMatched) else { break }
            current = delta.composed(with: current)

            if abs(lastRMSE - rmse) < convergenceDelta { break }
            lastRMSE = rmse
        }

        // Measure once more under the final pose: inside the loop the RMSE is
        // computed *before* the solve advances `current`, so reporting it would
        // hand QualityReport a number one iteration staler than the transform
        // we return.
        var inliers = 0
        var sqSum = 0.0
        for p in source.points {
            let tp = current.apply(to: p)
            if let hit = index.nearest(to: tp), hit.distance <= maxCorrespondenceDistance {
                inliers += 1
                sqSum += hit.distance * hit.distance
            }
        }
        guard inliers >= 3 else { throw RegistrationError.insufficientOverlap }

        let fitness = Double(inliers) / Double(source.points.count)
        return RegistrationResult(
            transform: current,
            fitness: fitness,
            inlierRMSE: (sqSum / Double(inliers)).squareRoot()
        )
    }
}

/// Trivial coarse aligner that trusts the supplied initial guess (e.g. the
/// ARKit world-tracking pose between scans). Pairs with `ICPFineAligner` to form
/// a complete pure-Swift pipeline without a global-registration bridge (TEASER++
/// can replace this later for scans with no pose prior).
public struct PassthroughCoarseAligner: CoarseAligner {
    public init() {}
    public func align(source: PointSample, target: PointSample) async throws -> RegistrationResult {
        RegistrationResult(transform: .identity, fitness: 0, inlierRMSE: .greatestFiniteMagnitude)
    }
}
