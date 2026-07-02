import Foundation
import FungibleDomain

// Real least-squares pose-graph optimization, pure Swift (ADR-0005/0008). Where
// ChainPoseGraphOptimizer composes a spanning tree and ignores everything else,
// this minimizes the weighted residual of EVERY constraint — sequential, submap,
// loop-closure, manual — so redundant edges tighten the solution and a closure
// actually pulls accumulated drift back. Damped Gauss–Newton over a rotation-
// vector + translation parameterization, gauge fixed at the first node, seeded
// from the chain baseline. Numeric Jacobians keep it dependency-free; the
// bridged GTSAM iSAM2 remains the drop-in if device profiling demands sparse
// analytic solving on very large graphs.
public struct GaussNewtonPoseGraphOptimizer: PoseGraphOptimizer {
    public var maxIterations: Int
    public var damping: Double
    public var jacobianEpsilon: Double

    public init(maxIterations: Int = 50, damping: Double = 1e-6, jacobianEpsilon: Double = 1e-6) {
        self.maxIterations = maxIterations
        self.damping = damping
        self.jacobianEpsilon = jacobianEpsilon
    }

    public func optimize(_ graph: PoseGraph) async throws -> [ScanID: Transform] {
        // Seed from the chain baseline — exact for trees, a good start otherwise.
        let seed = try await ChainPoseGraphOptimizer().optimize(graph)
        let nodes = graph.nodes
        // A tree/forest is already exactly consistent; nothing to optimize.
        guard nodes.count >= 2, graph.constraints.count > nodes.count - 1 else { return seed }

        var nodeIndex: [ScanID: Int] = [:]
        for (i, node) in nodes.enumerated() { nodeIndex[node] = i }

        // 6 parameters (rotation vector + translation) per non-gauge node.
        var x: [Double] = []
        x.reserveCapacity((nodes.count - 1) * 6)
        for node in nodes.dropFirst() {
            let pose = seed[node] ?? .identity
            let r = PoseGraphMath.logRot(pose.rotation)
            x.append(contentsOf: [r.x, r.y, r.z, pose.translation.x, pose.translation.y, pose.translation.z])
        }

        let residuals: ([Double]) -> [Double] = { params in
            Self.residuals(params, nodes: nodes, nodeIndex: nodeIndex, constraints: graph.constraints)
        }

        for _ in 0..<maxIterations {
            let r = residuals(x)
            let m = r.count
            let n = x.count

            // Numeric Jacobian (dense; graphs are modest and this is exact
            // enough — sparse analytic Jacobians are the profiled upgrade).
            var jacobian = [[Double]](repeating: [Double](repeating: 0, count: n), count: m)
            for k in 0..<n {
                var perturbed = x
                perturbed[k] += jacobianEpsilon
                let rp = residuals(perturbed)
                for i in 0..<m {
                    jacobian[i][k] = (rp[i] - r[i]) / jacobianEpsilon
                }
            }

            // Damped normal equations: (JᵀJ + λI) δ = −Jᵀr.
            var h = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
            var g = [Double](repeating: 0, count: n)
            for a in 0..<n {
                for b in a..<n {
                    var sum = 0.0
                    for i in 0..<m { sum += jacobian[i][a] * jacobian[i][b] }
                    h[a][b] = sum
                    h[b][a] = sum
                }
                h[a][a] += damping
                var dot = 0.0
                for i in 0..<m { dot += jacobian[i][a] * r[i] }
                g[a] = -dot
            }

            guard let delta = Self.solve(h, g) else { break }
            for k in 0..<n { x[k] += delta[k] }
            if (delta.map { abs($0) }.max() ?? 0) < 1e-10 { break }
        }

        var poses: [ScanID: Transform] = [nodes[0]: seed[nodes[0]] ?? .identity]
        for (i, node) in nodes.dropFirst().enumerated() {
            poses[node] = Self.unpack(x, at: i * 6)
        }
        return poses
    }

    // MARK: - Residuals

    /// One 6-vector per constraint: the translation and rotation-log of the
    /// error transform between the predicted and current `to` pose, scaled by
    /// √information (so the squared norm is information-weighted).
    static func residuals(
        _ x: [Double],
        nodes: [ScanID],
        nodeIndex: [ScanID: Int],
        constraints: [PoseConstraint]
    ) -> [Double] {
        func pose(of id: ScanID) -> Transform {
            guard let k = nodeIndex[id], k > 0 else { return .identity }
            return unpack(x, at: (k - 1) * 6)
        }

        var r: [Double] = []
        r.reserveCapacity(constraints.count * 6)
        for c in constraints {
            let weight = max(c.information, 1e-9).squareRoot()
            let predicted = pose(of: c.from).composed(with: c.relativePose)
            let error = predicted.inverse().composed(with: pose(of: c.to))
            let rot = PoseGraphMath.logRot(error.rotation)
            r.append(contentsOf: [
                error.translation.x * weight, error.translation.y * weight, error.translation.z * weight,
                rot.x * weight, rot.y * weight, rot.z * weight,
            ])
        }
        return r
    }

    static func unpack(_ x: [Double], at i: Int) -> Transform {
        Transform(
            rotation: PoseGraphMath.expRot(Vector3(x[i], x[i + 1], x[i + 2])),
            translation: Vector3(x[i + 3], x[i + 4], x[i + 5])
        )
    }

    // MARK: - Linear solve

    /// Gaussian elimination with partial pivoting: solves H δ = g.
    static func solve(_ h: [[Double]], _ g: [Double]) -> [Double]? {
        let n = g.count
        var a = h
        var b = g

        for col in 0..<n {
            var pivot = col
            for row in (col + 1)..<n where abs(a[row][col]) > abs(a[pivot][col]) {
                pivot = row
            }
            guard abs(a[pivot][col]) > 1e-15 else { return nil }
            a.swapAt(col, pivot)
            b.swapAt(col, pivot)

            for row in (col + 1)..<n {
                let factor = a[row][col] / a[col][col]
                if factor == 0 { continue }
                for c in col..<n { a[row][c] -= factor * a[col][c] }
                b[row] -= factor * b[col]
            }
        }

        var x = [Double](repeating: 0, count: n)
        for row in stride(from: n - 1, through: 0, by: -1) {
            var sum = b[row]
            for c in (row + 1)..<n { sum -= a[row][c] * x[c] }
            x[row] = sum / a[row][row]
        }
        return x
    }
}

/// Rotation-vector (axis·angle) ↔ quaternion, shared by the optimizer and its
/// tests. Internal so @testable tests can compute reference costs.
enum PoseGraphMath {
    static func expRot(_ v: Vector3) -> Quaternion {
        let angle = v.length
        if angle < 1e-12 {
            return Quaternion(w: 1, x: v.x / 2, y: v.y / 2, z: v.z / 2).normalized()
        }
        let s = sin(angle / 2) / angle
        return Quaternion(w: cos(angle / 2), x: v.x * s, y: v.y * s, z: v.z * s)
    }

    static func logRot(_ q0: Quaternion) -> Vector3 {
        var q = q0.normalized()
        if q.w < 0 { q = Quaternion(w: -q.w, x: -q.x, y: -q.y, z: -q.z) } // short arc
        let n = (q.x * q.x + q.y * q.y + q.z * q.z).squareRoot()
        if n < 1e-12 { return Vector3(2 * q.x, 2 * q.y, 2 * q.z) }
        let angle = 2 * atan2(n, q.w)
        return Vector3(q.x / n * angle, q.y / n * angle, q.z / n * angle)
    }
}
