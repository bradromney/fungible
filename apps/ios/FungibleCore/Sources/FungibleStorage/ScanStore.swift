import Foundation
import FungibleDomain

// Local-first persistence (ADR-0003). The store owns the catalog (ScanSet
// metadata, intended to be backed by an Automerge CRDT doc) and the on-disk
// point-cloud blobs (append-only capture chunks, finalized to COPC/LAZ). Domain
// code talks to this protocol; the concrete implementation lives in the app.

public protocol ScanStore: Sendable {
    // Catalog (metadata) — small, mergeable, always loaded.
    func loadSets() async throws -> [ScanSet]
    func save(_ set: ScanSet) async throws
    func deleteSet(_ id: ScanSetID) async throws

    // Point-cloud blobs — large, content-addressed, streamed.
    /// Append a finalized capture to the store, returning its content hash and
    /// the relative local path of the resulting blob.
    func finalizeCapture(_ chunks: any PointChunkStream, for scan: ScanID) async throws -> PointCloudRef

    /// Resolve an absolute local file URL for a blob reference, if present.
    func localURL(for ref: PointCloudRef) -> URL?

    /// Total bytes the store is currently using on device.
    func diskUsageBytes() async -> Int64
}

/// An abstraction over the stream of point chunks produced during capture. The
/// concrete type (Metal buffers → COPC writer) lives in the app/codec layer;
/// the domain only needs the finalize contract above.
public protocol PointChunkStream: Sendable {
    var approximatePointCount: Int { get }
}

public enum StorageError: Error, Equatable, Sendable {
    case setNotFound
    case blobNotFound
    case writeFailed(String)
    case corrupted
}
