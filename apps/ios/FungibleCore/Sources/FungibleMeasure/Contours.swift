import Foundation
import FungibleDomain

// Contour / topo generation from a DEM via marching squares (research §9 —
// contour generation is rare in mobile scanners and pairs naturally with the
// grading/cut-fill workflow). Produces iso-elevation line segments; the DXF
// exporter turns these into a survey topo drawing. Segments (not stitched
// polylines) keep the algorithm simple and exact; the exporter is happy with
// either.

/// One iso-line segment at a given elevation, in the set's frame (XZ plan, Y up).
public struct ContourSegment: Equatable, Sendable {
    public var elevation: Double
    public var a: Vector3
    public var b: Vector3

    public init(elevation: Double, a: Vector3, b: Vector3) {
        self.elevation = elevation
        self.a = a
        self.b = b
    }
}

public enum Contours {
    /// Generate contour segments at every multiple of `interval` that the grid
    /// spans. `interval` is in meters. Cells touching a missing (nil) height are
    /// skipped.
    public static func segments(from grid: HeightGrid, interval: Double) -> [ContourSegment] {
        precondition(interval > 0, "interval must be positive")
        let levels = levels(for: grid, interval: interval)
        guard !levels.isEmpty else { return [] }

        var out: [ContourSegment] = []
        for r in 0..<(grid.rows - 1) {
            for c in 0..<(grid.columns - 1) {
                guard
                    let tl = grid.height(col: c, row: r),
                    let tr = grid.height(col: c + 1, row: r),
                    let br = grid.height(col: c + 1, row: r + 1),
                    let bl = grid.height(col: c, row: r + 1)
                else { continue }
                for level in levels {
                    appendCell(grid: grid, c: c, r: r, tl: tl, tr: tr, br: br, bl: bl, level: level, into: &out)
                }
            }
        }
        return out
    }

    private static func levels(for grid: HeightGrid, interval: Double) -> [Double] {
        let present = grid.heights.compactMap { $0 }
        guard let lo = present.min(), let hi = present.max(), hi > lo else { return [] }
        // First multiple of `interval` strictly greater than the minimum, so a
        // flat floor at an exact multiple doesn't produce a boundary iso-line.
        let first = (lo / interval).rounded(.down) * interval + interval
        var levels: [Double] = []
        var level = first
        while level < hi { // strictly inside so flat plateaus don't spam levels
            levels.append(level)
            level += interval
        }
        return levels
    }

    // Marching squares for one cell at one level. Corners (world XZ, Y up):
    //   TL(c,r)  TR(c+1,r)
    //   BL(c,r+1) BR(c+1,r+1)
    private static func appendCell(
        grid: HeightGrid, c: Int, r: Int,
        tl: Double, tr: Double, br: Double, bl: Double,
        level: Double, into out: inout [ContourSegment]
    ) {
        let x0 = grid.originX + Double(c) * grid.cellSize
        let x1 = x0 + grid.cellSize
        let z0 = grid.originZ + Double(r) * grid.cellSize
        let z1 = z0 + grid.cellSize

        // Corner world positions in the XZ plane.
        let pTL = (x0, z0), pTR = (x1, z0), pBR = (x1, z1), pBL = (x0, z1)

        // Crossings on each of the 4 edges, in order [top, right, bottom, left].
        var crossings: [Vector3] = []
        if let p = cross(level, pTL, tl, pTR, tr) { crossings.append(p) } // top
        if let p = cross(level, pTR, tr, pBR, br) { crossings.append(p) } // right
        if let p = cross(level, pBR, br, pBL, bl) { crossings.append(p) } // bottom
        if let p = cross(level, pBL, bl, pTL, tl) { crossings.append(p) } // left

        switch crossings.count {
        case 2:
            out.append(ContourSegment(elevation: level, a: crossings[0], b: crossings[1]))
        case 4:
            // Saddle: connect in encounter order (ambiguous; consistent choice).
            out.append(ContourSegment(elevation: level, a: crossings[0], b: crossings[1]))
            out.append(ContourSegment(elevation: level, a: crossings[2], b: crossings[3]))
        default:
            break // 0 crossings, or degenerate
        }
    }

    /// Interpolated crossing point on the edge between two corners, or nil if the
    /// level doesn't straddle it.
    private static func cross(
        _ level: Double,
        _ pA: (Double, Double), _ hA: Double,
        _ pB: (Double, Double), _ hB: Double
    ) -> Vector3? {
        let above = (hA - level) > 0
        let bAbove = (hB - level) > 0
        guard above != bAbove, hA != hB else { return nil }
        let t = (level - hA) / (hB - hA)
        let x = pA.0 + (pB.0 - pA.0) * t
        let z = pA.1 + (pB.1 - pA.1) * t
        return Vector3(x, level, z)
    }
}
