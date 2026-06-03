import Foundation
import FungibleDomain

// Bounded, deduplicating point accumulation for live capture (research §1–2):
// snapping points to a voxel grid keeps memory bounded and cuts the per-frame
// tiler load (~3× in the literature). One representative point per voxel is
// retained — the highest-confidence sample. The Metal capture pass mirrors this
// (grid-sampling into a fixed-capacity buffer); this pure version is the spec
// and is unit-tested on CI.

/// Integer voxel coordinate.
public struct VoxelKey: Hashable, Sendable {
    public let x: Int
    public let y: Int
    public let z: Int
    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct VoxelAccumulator {
    public let voxelSize: Double
    public let capacity: Int
    private var cells: [VoxelKey: CapturedPoint]

    /// - Parameters:
    ///   - voxelSize: edge length of a voxel in meters (e.g. 0.01 = 1 cm).
    ///   - capacity: hard cap on retained voxels; once reached, points that
    ///     would open a *new* voxel are dropped (existing voxels still update).
    public init(voxelSize: Double, capacity: Int) {
        precondition(voxelSize > 0, "voxelSize must be positive")
        precondition(capacity > 0, "capacity must be positive")
        self.voxelSize = voxelSize
        self.capacity = capacity
        self.cells = [:]
        self.cells.reserveCapacity(min(capacity, 1 << 16))
    }

    public var count: Int { cells.count }
    public var isFull: Bool { cells.count >= capacity }

    public func key(for p: Vector3) -> VoxelKey {
        VoxelKey(
            x: Int((p.x / voxelSize).rounded(.down)),
            y: Int((p.y / voxelSize).rounded(.down)),
            z: Int((p.z / voxelSize).rounded(.down))
        )
    }

    /// Insert a point. Returns true iff this opened a new voxel (useful for
    /// coverage tracking). Within an existing voxel, the higher-confidence
    /// sample is kept. At capacity, new voxels are dropped (bounded memory).
    @discardableResult
    public mutating func insert(_ point: CapturedPoint) -> Bool {
        let k = key(for: point.position)
        if let existing = cells[k] {
            if point.confidence > existing.confidence {
                cells[k] = point
            }
            return false
        }
        guard cells.count < capacity else { return false }
        cells[k] = point
        return true
    }

    /// All retained points (one per occupied voxel), unordered.
    public func points() -> [CapturedPoint] {
        Array(cells.values)
    }

    public mutating func removeAll() {
        cells.removeAll(keepingCapacity: true)
    }
}
