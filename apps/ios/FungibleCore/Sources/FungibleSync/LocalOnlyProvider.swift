import Foundation
import FungibleDomain

/// The default, always-available provider (ADR-0003). It performs no network
/// I/O: blobs already live on device, so "upload" is a no-op that simply
/// confirms the file exists and reports it as synced-to-local. This keeps the
/// rest of the app written against `SyncProvider` even with no cloud configured.
public struct LocalOnlyProvider: SyncProvider {
    public let backend: SyncBackend = .localOnly

    public init() {}

    public var isReady: Bool { get async { true } }

    public func upload(_ blob: SyncableBlob, progress: @Sendable @escaping (Double) -> Void) async throws -> RemoteRef {
        guard FileManager.default.fileExists(atPath: blob.localPath) else {
            throw SyncError.notFound
        }
        progress(1.0)
        // The "remote" locator for local-only is just the content hash.
        return RemoteRef(backend: .localOnly, locator: blob.hash.rawValue)
    }

    public func download(_ ref: RemoteRef, to localPath: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        // Local-only data is already present; nothing to fetch.
        guard FileManager.default.fileExists(atPath: localPath) else {
            throw SyncError.notFound
        }
        progress(1.0)
    }

    public func state(of hash: ContentHash) async -> SyncState {
        .localOnly
    }

    public func delete(_ ref: RemoteRef) async throws {
        // No remote copy exists; deletion of local files is the store's job.
    }
}
