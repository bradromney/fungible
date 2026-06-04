import Foundation
import FungibleDomain

// A least-squares plane through points, for cut/fill against a *sloped* design
// grade or stockpile base (research §9). Real sites are rarely flat, so
// comparing the DEM to a fitted plane (not just a constant elevation) is what
// makes earthwork volumes meaningful. Plane form: y = a·x + b·z + c (Y is up).
public struct Plane: Equatable, Sendable {
    public var a: Double
    public var b: Double
    public var c: Double

    public init(a: Double, b: Double, c: Double) {
        self.a = a
        self.b = b
        self.c = c
    }

    /// Elevation of the plane at a horizontal (x, z) position.
    public func elevation(x: Double, z: Double) -> Double { a * x + b * z + c }

    /// Fit a plane minimizing vertical (Y) residuals via the 3×3 normal
    /// equations. Returns nil if the points are degenerate (collinear in plan,
    /// or fewer than 3) so the system is singular.
    public static func fit(_ points: [Vector3]) -> Plane? {
        guard points.count >= 3 else { return nil }
        var sxx = 0.0, sxz = 0.0, sx = 0.0
        var szz = 0.0, sz = 0.0
        var sxy = 0.0, szy = 0.0, sy = 0.0
        let n = Double(points.count)
        for p in points {
            sxx += p.x * p.x; sxz += p.x * p.z; sx += p.x
            szz += p.z * p.z; sz += p.z
            sxy += p.x * p.y; szy += p.z * p.y; sy += p.y
        }
        // [sxx sxz sx][a]   [sxy]
        // [sxz szz sz][b] = [szy]
        // [sx  sz  n ][c]   [sy ]
        return solve3x3(
            (sxx, sxz, sx,
             sxz, szz, sz,
             sx, sz, n),
            rhs: (sxy, szy, sy)
        ).map { Plane(a: $0.0, b: $0.1, c: $0.2) }
    }

    /// Cramer's-rule solve of a 3×3 system; nil if near-singular.
    private static func solve3x3(
        _ m: (Double, Double, Double, Double, Double, Double, Double, Double, Double),
        rhs r: (Double, Double, Double)
    ) -> (Double, Double, Double)? {
        let (a, b, c, d, e, f, g, h, i) = m
        let det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        guard abs(det) > 1e-12 else { return nil }
        let (r0, r1, r2) = r
        let detX = r0 * (e * i - f * h) - b * (r1 * i - f * r2) + c * (r1 * h - e * r2)
        let detY = a * (r1 * i - f * r2) - r0 * (d * i - f * g) + c * (d * r2 - r1 * g)
        let detZ = a * (e * r2 - r1 * h) - b * (d * r2 - r1 * g) + r0 * (d * h - e * g)
        return (detX / det, detY / det, detZ / det)
    }
}

public extension CutFillEngine {
    /// Cut/fill of a DEM against a fitted/design plane (per-cell reference =
    /// plane elevation at the cell centre).
    static func compare(existing: HeightGrid, toPlane plane: Plane) -> CutFillResult {
        var cut = 0.0, fill = 0.0, compared = 0
        let area = existing.cellArea
        for r in 0..<existing.rows {
            for col in 0..<existing.columns {
                guard let e = existing.height(col: col, row: r) else { continue }
                let x = existing.originX + (Double(col) + 0.5) * existing.cellSize
                let z = existing.originZ + (Double(r) + 0.5) * existing.cellSize
                let diff = plane.elevation(x: x, z: z) - e
                if diff > 0 { fill += diff * area } else if diff < 0 { cut += -diff * area }
                compared += 1
            }
        }
        return CutFillResult(cutVolume: cut, fillVolume: fill, comparedCells: compared)
    }
}
