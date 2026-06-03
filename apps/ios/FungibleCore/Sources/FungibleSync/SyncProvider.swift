import Foundation
import FungibleDomain

// The pluggable sync layer (ADR-0003). Capture/storage depend ONLY on this
// protocol — never on a cloud SDK directly. v1 ships LocalOnlyProvider plus one
// cloud driver; iCloud / Google Drive / Hosted S3+R2 are added behind the same
// interface without touching the rest of the app.

/// Where a sync provider keeps its data, surfaced to the user when choosing.
public enum SyncBackend: String, Codable, Sendable, CaseIterable {
    case localOnly
    case iCloud
    case googleDrive
    case hosted
}

/// State of a blob within a provider.
public enum SyncState: Equatable, Sendable {
    case localOnly                       // exists on device, not synced
    case uploading(fractionComplete: Double)
    case synced(remote: RemoteRef)
    case downloading(fractionComplete: Double)
    case failed(reason: String)
}

/// An opaque handle to a blob in a remote backend.
public struct RemoteRef: Equatable, Hashable, Codable, Sendable {
    public var backend: SyncBackend
    /// Backend-specific locator (object key, Drive file id, CKRecord name…).
    public var locator: String
    public init(backend: SyncBackend, locator: String) {
        self.backend = backend
        self.locator = locator
    }
}

/// A unit of transfer: an immutable, content-addressed point-cloud (or export)
/// blob. Blobs are addressed by hash so providers dedup and verify integrity,
/// and "conflicts" are resolved by version, never by merge (ADR-0003).
public struct SyncableBlob: Equatable, Sendable {
    public var hash: ContentHash
    public var localPath: String
    public var byteSize: Int
    public init(hash: ContentHash, localPath: String, byteSize: Int) {
        self.hash = hash
        self.localPath = localPath
        self.byteSize = byteSize
    }
}

/// The one interface every storage backend implements. Implementations handle
/// their own auth, resumable/background transfer, and quota; callers see only
/// this. Methods are async and may be long-running (large files).
public protocol SyncProvider: Sendable {
    var backend: SyncBackend { get }

    /// Whether the provider is configured/authorized and ready to transfer.
    var isReady: Bool { get async }

    /// Upload a blob, reporting progress. Returns the remote handle on success.
    /// Implementations must be resumable across app restarts for large files.
    func upload(_ blob: SyncableBlob, progress: @Sendable @escaping (Double) -> Void) async throws -> RemoteRef

    /// Download a blob to a local path by its remote handle.
    func download(_ ref: RemoteRef, to localPath: String, progress: @Sendable @escaping (Double) -> Void) async throws

    /// Current state of a blob identified by content hash.
    func state(of hash: ContentHash) async -> SyncState

    /// Remove a blob from the remote backend.
    func delete(_ ref: RemoteRef) async throws
}

public enum SyncError: Error, Equatable, Sendable {
    case notAuthorized
    case notFound
    case quotaExceeded
    case integrityMismatch
    case transferFailed(String)
}
