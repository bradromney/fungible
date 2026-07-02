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
        capacity: Int = 20_000_000,
        includeHidden: Bool = false
    ) async throws -> [CapturedPoint] {
        // Compose from the visible scans only (ADR-0010) unless the caller asks
        // for everything — hiding a scan simply drops it from the union.
        let scans = includeHidden ? set.scans : set.visibleScans
        if let voxelSize {
            var acc = VoxelAccumulator(voxelSize: voxelSize, capacity: capacity)
            try await forEachWorldPoint(in: scans) { acc.insert($0) }
            return acc.points()
        } else {
            var all: [CapturedPoint] = []
            try await forEachWorldPoint(in: scans) { all.append($0) }
            return all
        }
    }

    /// Full-resolution union with per-point provenance: `sourceIDs[i]` is the
    /// 1-based index (in `visibleScans` order) of the scan that produced
    /// `points[i]`. Feed both to `LASExporter.data(for:sourceIDs:)` so the
    /// exported merge can be split back into scans in external tools
    /// (ADR-0010). Full-res only — voxel downsampling merges points across
    /// scans and would destroy the attribution.
    public func assembleAttributed(_ set: ScanSet) async throws -> (points: [CapturedPoint], sourceIDs: [UInt16]) {
        var pts: [CapturedPoint] = []
        var ids: [UInt16] = []
        for (i, scan) in set.visibleScans.enumerated() {
            let raw = try await store.readBlob(scan.pointCloud)
            let id = UInt16(clamping: i + 1)
            pts.reserveCapacity(pts.count + raw.count)
            ids.reserveCapacity(ids.count + raw.count)
            for p in raw {
                pts.append(CapturedPoint(
                    position: scan.pose.apply(to: p.position),
                    confidence: p.confidence, r: p.r, g: p.g, b: p.b
                ))
                ids.append(id)
            }
        }
        return (pts, ids)
    }

    private func forEachWorldPoint(in scans: [Scan], _ body: (CapturedPoint) -> Void) async throws {
        for scan in scans {
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
