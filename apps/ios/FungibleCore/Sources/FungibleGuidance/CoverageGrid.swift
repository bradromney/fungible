import Foundation
import FungibleDomain

// The engine behind outdoor scan-coverage guidance (research §7 — the key
// differentiator). An open site has no natural "done", so the user's
// region-of-interest defines completeness: we voxelize the ROI and mark voxels
// as the scan observes them. From that we get a real coverage %, a done signal,
// and a direction toward the un-scanned area ("scan over there"). Pure and
// CI-tested; the app feeds it observed points and reads back coverage + gap
// direction. (The on-device version can mirror this with a Metal occupancy
// texture; this is the spec.)
public struct CoverageGrid {
    public let bounds: BoundingBox
    public let voxelSize: Double
    public let nx: Int
    public let ny: Int
    public let nz: Int

    private var observed: [Bool]
    private var observedCount = 0

    public init(roi: RegionOfInterest, voxelSize: Double) {
        self.init(bounds: roi.bounds, voxelSize: voxelSize)
    }

    public init(bounds: BoundingBox, voxelSize: Double) {
        precondition(voxelSize > 0, "voxelSize must be positive")
        self.bounds = bounds
        self.voxelSize = voxelSize
        let size = bounds.sizeMeters
        self.nx = max(1, Int((size.x / voxelSize).rounded(.up)))
        self.ny = max(1, Int((size.y / voxelSize).rounded(.up)))
        self.nz = max(1, Int((size.z / voxelSize).rounded(.up)))
        self.observed = [Bool](repeating: false, count: nx * ny * nz)
    }

    public var totalVoxels: Int { nx * ny * nz }
    public var observedVoxels: Int { observedCount }
    public var coverage: Double {
        totalVoxels > 0 ? Double(observedCount) / Double(totalVoxels) : 0
    }

    public func isComplete(threshold: Double) -> Bool { coverage >= threshold }

    /// Mark the voxel containing `point` observed. Returns true if this newly
    /// covered a voxel (points outside the ROI are ignored).
    @discardableResult
    public mutating func observe(_ point: Vector3) -> Bool {
        guard let i = index(of: point) else { return false }
        if !observed[i] {
            observed[i] = true
            observedCount += 1
            return true
        }
        return false
    }

    public mutating func observe(_ points: [Vector3]) {
        for p in points { observe(p) }
    }

    /// Unit direction from `position` toward the centroid of unobserved voxels —
    /// the "scan over there" arrow. nil when coverage is complete. O(totalVoxels);
    /// call on a throttle, not every frame.
    public func gapDirection(from position: Vector3) -> Vector3? {
        guard observedCount < totalVoxels else { return nil }
        var sum = Vector3.zero
        var count = 0
        for iz in 0..<nz {
            for iy in 0..<ny {
                for ix in 0..<nx where !observed[(iz * ny + iy) * nx + ix] {
                    sum = sum + voxelCenter(ix, iy, iz)
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        let centroid = sum * (1.0 / Double(count))
        let dir = centroid - position
        return dir.length > 0 ? dir.normalized() : nil
    }

    // MARK: - Indexing

    private func index(of p: Vector3) -> Int? {
        guard bounds.contains(p) else { return nil }
        let ix = clamp(Int((p.x - bounds.min.x) / voxelSize), 0, nx - 1)
        let iy = clamp(Int((p.y - bounds.min.y) / voxelSize), 0, ny - 1)
        let iz = clamp(Int((p.z - bounds.min.z) / voxelSize), 0, nz - 1)
        return (iz * ny + iy) * nx + ix
    }

    private func voxelCenter(_ ix: Int, _ iy: Int, _ iz: Int) -> Vector3 {
        Vector3(
            bounds.min.x + (Double(ix) + 0.5) * voxelSize,
            bounds.min.y + (Double(iy) + 0.5) * voxelSize,
            bounds.min.z + (Double(iz) + 0.5) * voxelSize
        )
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(hi, max(lo, v)) }
}
