import Foundation
import FungibleDomain

// Closed-form rigid alignment (Horn's unit-quaternion method): given matched
// source→target correspondences, find the rotation+translation minimizing
// squared distance. This is the kernel inside ICP. It's dependency-free — the
// optimal rotation is the dominant eigenvector of a symmetric 4×4 matrix, which
// we get with power iteration (no SVD / no Accelerate) so it builds and tests on
// Linux CI and runs on-device with no native bridge.
public enum RigidAlignment {
    /// Best-fit transform mapping `source[i]` onto `target[i]`. Requires equal
    /// counts and ≥3 points; nil otherwise.
    public static func align(source: [Vector3], target: [Vector3], iterations: Int = 64) -> Transform? {
        guard source.count == target.count, source.count >= 3 else { return nil }
        let n = Double(source.count)

        // Centroids.
        var pc = Vector3.zero, qc = Vector3.zero
        for i in source.indices { pc = pc + source[i]; qc = qc + target[i] }
        pc = pc * (1.0 / n); qc = qc * (1.0 / n)

        // Cross-covariance H = Σ (p-­p̄)(q-­q̄)ᵀ.
        var sxx = 0.0, sxy = 0.0, sxz = 0.0
        var syx = 0.0, syy = 0.0, syz = 0.0
        var szx = 0.0, szy = 0.0, szz = 0.0
        for i in source.indices {
            let p = source[i] - pc, q = target[i] - qc
            sxx += p.x * q.x; sxy += p.x * q.y; sxz += p.x * q.z
            syx += p.y * q.x; syy += p.y * q.y; syz += p.y * q.z
            szx += p.z * q.x; szy += p.z * q.y; szz += p.z * q.z
        }

        // Horn's symmetric N (4×4); its top eigenvector is the optimal quaternion.
        var n4: [Double] = [
            sxx + syy + szz, syz - szy,        szx - sxz,        sxy - syx,
            syz - szy,       sxx - syy - szz,  sxy + syx,        szx + sxz,
            szx - sxz,       sxy + syx,       -sxx + syy - szz,  syz + szy,
            sxy - syx,       szx + sxz,        syz + szy,       -sxx - syy + szz,
        ]

        // Diagonal shift so all eigenvalues are positive (Gershgorin bound),
        // making "largest magnitude" (what power iteration finds) == "largest
        // algebraic" (what we want).
        let shift = gershgorinBound(n4)
        for d in 0..<4 { n4[d * 4 + d] += shift }

        // Power iteration → dominant eigenvector.
        var v = [1.0, 0.0, 0.0, 0.0]
        for _ in 0..<iterations {
            v = matVec4(n4, v)
            let norm = (v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3]).squareRoot()
            guard norm > 0 else { return nil }
            for k in 0..<4 { v[k] /= norm }
        }

        let rotation = Quaternion(w: v[0], x: v[1], y: v[2], z: v[3]).normalized()
        let translation = qc - rotation.act(pc)
        return Transform(rotation: rotation, translation: translation)
    }

    private static func matVec4(_ m: [Double], _ v: [Double]) -> [Double] {
        [
            m[0] * v[0] + m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
            m[4] * v[0] + m[5] * v[1] + m[6] * v[2] + m[7] * v[3],
            m[8] * v[0] + m[9] * v[1] + m[10] * v[2] + m[11] * v[3],
            m[12] * v[0] + m[13] * v[1] + m[14] * v[2] + m[15] * v[3],
        ]
    }

    /// Max absolute row sum — an upper bound on the spectral radius.
    private static func gershgorinBound(_ m: [Double]) -> Double {
        var maxSum = 0.0
        for r in 0..<4 {
            var s = 0.0
            for c in 0..<4 { s += abs(m[r * 4 + c]) }
            maxSum = Swift.max(maxSum, s)
        }
        return maxSum
    }
}
