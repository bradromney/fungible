import Foundation
import FungibleDomain

// Voxel-hash nearest-neighbour index — the fix for ICP's O(n·m) bottleneck
// (ADR-0008). Points are bucketed into a hash of cubic cells; a query scans only
// the 3×3×3 block around its cell. If the grid is built with
// `cellSize >= the search radius`, that block is guaranteed to contain the true
// nearest neighbour within that radius — so ICP (which gates correspondences by
// a max distance) gets exact results at ~O(1) per query instead of O(m).
public struct SpatialHashGrid {
    public let cellSize: Double
    private let points: [Vector3]
    private let cells: [Cell: [Int]]

    private struct Cell: Hashable { let x: Int; let y: Int; let z: Int }

    public init(points: [Vector3], cellSize: Double) {
        precondition(cellSize > 0, "cellSize must be positive")
        self.cellSize = cellSize
        self.points = points
        var buckets: [Cell: [Int]] = [:]
        for (i, p) in points.enumerated() {
            buckets[Self.cell(for: p, cellSize: cellSize), default: []].append(i)
        }
        self.cells = buckets
    }

    public var isEmpty: Bool { points.isEmpty }
    public var count: Int { points.count }

    /// Nearest point to `q` within the 3×3×3 neighbourhood of its cell. Returns
    /// the point, its index, and the distance — or nil if that neighbourhood is
    /// empty. Build with `cellSize >= maxCorrespondenceDistance` for exactness.
    public func nearest(to q: Vector3) -> (point: Vector3, index: Int, distance: Double)? {
        let base = Self.cell(for: q, cellSize: cellSize)
        var bestIndex = -1
        var bestSq = Double.greatestFiniteMagnitude
        for dz in -1...1 {
            for dy in -1...1 {
                for dx in -1...1 {
                    let key = Cell(x: base.x + dx, y: base.y + dy, z: base.z + dz)
                    guard let indices = cells[key] else { continue }
                    for i in indices {
                        let p = points[i]
                        let ddx = p.x - q.x, ddy = p.y - q.y, ddz = p.z - q.z
                        let sq = ddx * ddx + ddy * ddy + ddz * ddz
                        if sq < bestSq { bestSq = sq; bestIndex = i }
                    }
                }
            }
        }
        guard bestIndex >= 0 else { return nil }
        return (points[bestIndex], bestIndex, bestSq.squareRoot())
    }

    private static func cell(for p: Vector3, cellSize: Double) -> Cell {
        Cell(
            x: Int((p.x / cellSize).rounded(.down)),
            y: Int((p.y / cellSize).rounded(.down)),
            z: Int((p.z / cellSize).rounded(.down))
        )
    }
}
