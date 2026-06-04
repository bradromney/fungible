import Foundation
import FungibleDomain
import FungibleCapture

// In-memory store for tests and SwiftUI previews. An actor so concurrent access
// is safe; mirrors FileScanStore's content-addressed blob semantics.
public actor InMemoryScanStore: ScanStore {
    private var sets: [ScanSetID: ScanSet] = [:]
    private var blobs: [String: Data] = [:] // contentHash -> encoded bytes

    public init() {}

    public func loadSets() async throws -> [ScanSet] {
        sets.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ set: ScanSet) async throws {
        sets[set.id] = set
    }

    public func deleteSet(_ id: ScanSetID) async throws {
        guard sets.removeValue(forKey: id) != nil else { throw StorageError.setNotFound }
    }

    public func writeBlob(points: [CapturedPoint], for scan: ScanID) async throws -> PointCloudRef {
        let data = PointCloudCodec.encode(points)
        let hash = ContentHashing.contentHash(data)
        blobs[hash.rawValue] = data
        return PointCloudRef(hash: hash, localPath: nil, pointCount: points.count, byteSize: data.count)
    }

    public func readBlob(_ ref: PointCloudRef) async throws -> [CapturedPoint] {
        guard let hash = ref.hash, let data = blobs[hash.rawValue] else {
            throw StorageError.blobNotFound
        }
        return try PointCloudCodec.decode(data)
    }

    public nonisolated func localURL(for ref: PointCloudRef) -> URL? { nil }

    public func diskUsageBytes() async -> Int64 {
        Int64(blobs.values.reduce(0) { $0 + $1.count })
    }

    @discardableResult
    public func collectGarbage(keeping sets: [ScanSet]) async throws -> Int64 {
        let keep = referencedHashes(in: sets)
        // Snapshot the orphans before mutating (don't mutate while iterating).
        let orphans = blobs.filter { !keep.contains($0.key) }
        var freed: Int64 = 0
        for (hash, data) in orphans {
            freed += Int64(data.count)
            blobs[hash] = nil
        }
        return freed
    }
}
