import Foundation
import FungibleDomain

// The second moat (research §9): mobile cut/fill / stockpile volume. No
// permissive drop-in library exists, so we own the math. The standard method is
// a 2.5D grid (DEM): rasterize points into XZ cells with a per-cell height (Y is
// up, matching ARKit), then integrate the height difference between two aligned
// surfaces times the cell area. CloudCompare's 2.5D volume tool (GPL) is the
// reference for this method; this is a clean-room implementation.

/// A 2.5D height grid over the horizontal (X,Z) plane, with Y as elevation.
/// `heights[r * columns + c]` is the cell elevation, or nil if no points fell
/// in that cell (a hole).
public struct HeightGrid: Equatable, Sendable {
    public let originX: Double
    public let originZ: Double
    public let cellSize: Double
    public let columns: Int
    public let rows: Int
    public private(set) var heights: [Double?]

    public init(originX: Double, originZ: Double, cellSize: Double, columns: Int, rows: Int, heights: [Double?]) {
        precondition(cellSize > 0, "cellSize must be positive")
        precondition(heights.count == columns * rows, "heights count must equal columns*rows")
        self.originX = originX
        self.originZ = originZ
        self.cellSize = cellSize
        self.columns = columns
        self.rows = rows
        self.heights = heights
    }

    public var cellArea: Double { cellSize * cellSize }

    public func height(col: Int, row: Int) -> Double? {
        guard col >= 0, col < columns, row >= 0, row < rows else { return nil }
        return heights[row * columns + col]
    }

    /// The number of cells that actually contain a surface sample.
    public var filledCellCount: Int { heights.lazy.filter { $0 != nil }.count }

    /// Build a top-surface DEM from points: each cell takes the **maximum** Y of
    /// the points within it (the visible top surface — right for stockpiles and
    /// grade). `aggregate` can override (e.g. min/mean) for other use cases.
    public static func topSurface(
        from points: [Vector3],
        cellSize: Double,
        aggregate: ([Double]) -> Double = { $0.max() ?? 0 }
    ) -> HeightGrid? {
        guard !points.isEmpty, cellSize > 0 else { return nil }

        var minX = points[0].x, maxX = points[0].x
        var minZ = points[0].z, maxZ = points[0].z
        for p in points {
            minX = Swift.min(minX, p.x); maxX = Swift.max(maxX, p.x)
            minZ = Swift.min(minZ, p.z); maxZ = Swift.max(maxZ, p.z)
        }

        let columns = Swift.max(1, Int(((maxX - minX) / cellSize).rounded(.up)) + 1)
        let rows = Swift.max(1, Int(((maxZ - minZ) / cellSize).rounded(.up)) + 1)

        var buckets = [[Double]](repeating: [], count: columns * rows)
        for p in points {
            let c = Swift.min(columns - 1, Swift.max(0, Int((p.x - minX) / cellSize)))
            let r = Swift.min(rows - 1, Swift.max(0, Int((p.z - minZ) / cellSize)))
            buckets[r * columns + c].append(p.y)
        }

        let heights: [Double?] = buckets.map { $0.isEmpty ? nil : aggregate($0) }
        return HeightGrid(originX: minX, originZ: minZ, cellSize: cellSize, columns: columns, rows: rows, heights: heights)
    }
}

/// Cut/fill totals between an existing surface and a design/reference surface,
/// in cubic meters. "Cut" = material to remove (existing above design); "fill" =
/// material to add (existing below design).
public struct CutFillResult: Equatable, Sendable {
    public var cutVolume: Double
    public var fillVolume: Double
    /// Cells compared (had a height in both surfaces).
    public var comparedCells: Int

    public init(cutVolume: Double, fillVolume: Double, comparedCells: Int) {
        self.cutVolume = cutVolume
        self.fillVolume = fillVolume
        self.comparedCells = comparedCells
    }

    /// Net = fill − cut. Positive means net material added.
    public var netVolume: Double { fillVolume - cutVolume }
}

public enum CutFillEngine {
    /// Compare two grids of identical geometry (same origin/cellSize/dimensions).
    /// Cells missing a height in either surface are skipped. Returns nil when the
    /// grids are misaligned — including different origins: `topSurface` derives
    /// the origin from the data bounds, so two same-shaped grids built from
    /// different point sets generally do NOT cover the same ground, and comparing
    /// them cell-by-cell would produce silently wrong volumes.
    public static func compare(existing: HeightGrid, design: HeightGrid) -> CutFillResult? {
        // Origins must coincide to a tolerance far below any real cell size;
        // exact double equality would be needlessly brittle for derived origins.
        let originTolerance = existing.cellSize * 1e-9
        guard existing.columns == design.columns,
              existing.rows == design.rows,
              existing.cellSize == design.cellSize,
              abs(existing.originX - design.originX) <= originTolerance,
              abs(existing.originZ - design.originZ) <= originTolerance else { return nil }

        var cut = 0.0, fill = 0.0, compared = 0
        let area = existing.cellArea
        for i in 0..<existing.heights.count {
            guard let e = existing.heights[i], let d = design.heights[i] else { continue }
            let diff = d - e // design minus existing
            if diff > 0 {
                fill += diff * area
            } else if diff < 0 {
                cut += -diff * area
            }
            compared += 1
        }
        return CutFillResult(cutVolume: cut, fillVolume: fill, comparedCells: compared)
    }

    /// Compare a surface against a flat reference elevation (e.g. a target grade
    /// or stockpile base plane).
    public static func compare(existing: HeightGrid, toReferenceElevation refY: Double) -> CutFillResult {
        var cut = 0.0, fill = 0.0, compared = 0
        let area = existing.cellArea
        for h in existing.heights {
            guard let e = h else { continue }
            let diff = refY - e
            if diff > 0 {
                fill += diff * area
            } else if diff < 0 {
                cut += -diff * area
            }
            compared += 1
        }
        return CutFillResult(cutVolume: cut, fillVolume: fill, comparedCells: compared)
    }
}
