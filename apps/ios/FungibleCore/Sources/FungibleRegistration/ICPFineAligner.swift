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

        var current = initial
        var lastRMSE = Double.greatestFiniteMagnitude
        var inliers = 0

        for _ in 0..<maxIterations {
            var srcMatched: [Vector3] = []
            var tgtMatched: [Vector3] = []
            var sqSum = 0.0

            for p in source.points {
                let tp = current.apply(to: p)
                if let (q, dist) = nearest(to: tp, in: targets), dist <= maxCorrespondenceDistance {
                    srcMatched.append(tp)
                    tgtMatched.append(q)
                    sqSum += dist * dist
                }
            }

            inliers = srcMatched.count
            guard inliers >= 3 else { throw RegistrationError.insufficientOverlap }

            let rmse = (sqSum / Double(inliers)).squareRoot()
            guard let delta = RigidAlignment.align(source: srcMatched, target: tgtMatched) else { break }
            current = delta.composed(with: current)

            if abs(lastRMSE - rmse) < convergenceDelta { lastRMSE = rmse; break }
            lastRMSE = rmse
        }

        let fitness = Double(inliers) / Double(source.points.count)
        return RegistrationResult(transform: current, fitness: fitness, inlierRMSE: lastRMSE)
    }

    private func nearest(to point: Vector3, in cloud: [Vector3]) -> (Vector3, Double)? {
        var best: Vector3?
        var bestSq = Double.greatestFiniteMagnitude
        for q in cloud {
            let dx = q.x - point.x, dy = q.y - point.y, dz = q.z - point.z
            let sq = dx * dx + dy * dy + dz * dz
            if sq < bestSq { bestSq = sq; best = q }
        }
        guard let best else { return nil }
        return (best, bestSq.squareRoot())
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
