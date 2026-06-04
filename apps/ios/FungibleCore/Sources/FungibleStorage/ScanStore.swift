import Foundation
import FungibleDomain
import FungibleCapture

// Local-first persistence (ADR-0003). The store owns the catalog (ScanSet
// metadata) and the on-disk point-cloud blobs. Domain code talks to this
// protocol; concrete implementations (file-backed, in-memory) live here and are
// CI-tested. The on-device finalize-to-COPC path will add a COPC writer behind
// the same `writeBlob` contract; today blobs use our compact internal format.

public protocol ScanStore: Sendable {
    // Catalog (metadata) — small, mergeable, the disk is the source of truth.
    func loadSets() async throws -> [ScanSet]
    func save(_ set: ScanSet) async throws
    func deleteSet(_ id: ScanSetID) async throws

    // Point-cloud blobs — large, content-addressed.
    /// Persist a finalized capture and return a reference (content hash, local
    /// path, point count, byte size).
    func writeBlob(points: [CapturedPoint], for scan: ScanID) async throws -> PointCloudRef
    /// Load points back for rendering/measurement/export.
    func readBlob(_ ref: PointCloudRef) async throws -> [CapturedPoint]

    /// Absolute file URL for a blob, if present locally.
    func localURL(for ref: PointCloudRef) -> URL?
    /// Total bytes the store is using on device.
    func diskUsageBytes() async -> Int64

    /// Delete blobs not referenced by any of `keeping`'s scans. Returns bytes
    /// freed. Use after deleting/trimming sets to reclaim orphaned point clouds.
    @discardableResult
    func collectGarbage(keeping sets: [ScanSet]) async throws -> Int64
}

public extension ScanStore {
    /// Hashes still referenced by the given sets' scans.
    func referencedHashes(in sets: [ScanSet]) -> Set<String> {
        Set(sets.flatMap { $0.scans.compactMap { $0.pointCloud.hash?.rawValue } })
    }
}

public enum StorageError: Error, Equatable, Sendable {
    case setNotFound
    case blobNotFound
    case writeFailed(String)
    case corrupted
}
