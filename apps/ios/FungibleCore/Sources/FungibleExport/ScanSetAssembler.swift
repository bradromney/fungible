import Foundation
import FungibleDomain
import FungibleCapture
import FungibleStorage

// Ties registration → storage → export: collapse a whole set's scans into one
// cloud in the set's frame by applying each scan's optimized pose, then export
// it (PLY/XYZ/DXF here; LAZ/E57/COPC via the bridged codecs). Optionally
// voxel-downsamples the merged result — the on-device counterpart of the cloud
// worker's `merge`, so a finished set is one coherent deliverable.
public struct ScanSetAssembler {
    private let store: any ScanStore

    public init(store: any ScanStore) {
        self.store = store
    }

    /// Merge every scan's points into the set frame. Pass `voxelSize` to
    /// downsample the union (bounds memory for export/preview); omit for the
    /// full-resolution union.
    public func assemble(
        _ set: ScanSet,
        voxelSize: Double? = nil,
        capacity: Int = 20_000_000
    ) async throws -> [CapturedPoint] {
        if let voxelSize {
            var acc = VoxelAccumulator(voxelSize: voxelSize, capacity: capacity)
            try await forEachWorldPoint(in: set) { acc.insert($0) }
            return acc.points()
        } else {
            var all: [CapturedPoint] = []
            try await forEachWorldPoint(in: set) { all.append($0) }
            return all
        }
    }

    private func forEachWorldPoint(in set: ScanSet, _ body: (CapturedPoint) -> Void) async throws {
        for scan in set.scans {
            let points = try await store.readBlob(scan.pointCloud)
            for p in points {
                body(CapturedPoint(
                    position: scan.pose.apply(to: p.position),
                    confidence: p.confidence, r: p.r, g: p.g, b: p.b
                ))
            }
        }
    }
}
