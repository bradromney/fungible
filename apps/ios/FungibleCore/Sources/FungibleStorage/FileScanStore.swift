import Foundation
import FungibleDomain
import FungibleCapture

// File-backed, local-first store. The on-disk layout is the source of truth, so
// the type holds only an immutable root URL and is trivially Sendable:
//
//   <root>/
//     sets/<scanSetID>.json      catalog entries (ScanSet, Codable)
//     blobs/<contentHash>.fpc    content-addressed point-cloud blobs
//
// Content addressing means identical blobs are stored once and a re-finalized
// scan with the same points doesn't duplicate data.
public struct FileScanStore: ScanStore {
    public let root: URL
    // Computed (not stored) so the type stays Sendable — FileManager isn't.
    private var fm: FileManager { .default }

    public init(root: URL) throws {
        self.root = root
        try fm.createDirectory(at: setsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
    }

    private var setsDir: URL { root.appendingPathComponent("sets", isDirectory: true) }
    private var blobsDir: URL { root.appendingPathComponent("blobs", isDirectory: true) }

    private func blobURL(forHash hash: String) -> URL {
        blobsDir.appendingPathComponent(hash).appendingPathExtension("fpc")
    }

    // MARK: Catalog

    public func loadSets() async throws -> [ScanSet] {
        let urls = (try? fm.contentsOfDirectory(at: setsDir, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        return try urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try decoder.decode(ScanSet.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ set: ScanSet) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = setsDir.appendingPathComponent(set.id.rawValue.uuidString).appendingPathExtension("json")
        do {
            try encoder.encode(set).write(to: url, options: .atomic)
        } catch {
            throw StorageError.writeFailed("\(error)")
        }
    }

    public func deleteSet(_ id: ScanSetID) async throws {
        let url = setsDir.appendingPathComponent(id.rawValue.uuidString).appendingPathExtension("json")
        guard fm.fileExists(atPath: url.path) else { throw StorageError.setNotFound }
        try fm.removeItem(at: url)
    }

    // MARK: Blobs

    public func writeBlob(points: [CapturedPoint], for scan: ScanID) async throws -> PointCloudRef {
        let data = PointCloudCodec.encode(points)
        let hash = ContentHashing.contentHash(data)
        let url = blobURL(forHash: hash.rawValue)
        if !fm.fileExists(atPath: url.path) { // content-addressed: skip if identical
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                throw StorageError.writeFailed("\(error)")
            }
        }
        return PointCloudRef(
            hash: hash,
            localPath: url.lastPathComponent,
            pointCount: points.count,
            byteSize: data.count
        )
    }

    public func readBlob(_ ref: PointCloudRef) async throws -> [CapturedPoint] {
        guard let url = localURL(for: ref) else { throw StorageError.blobNotFound }
        let data = try Data(contentsOf: url)
        return try PointCloudCodec.decode(data)
    }

    public func localURL(for ref: PointCloudRef) -> URL? {
        guard let hash = ref.hash else { return nil }
        let url = blobURL(forHash: hash.rawValue)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    public func diskUsageBytes() async -> Int64 {
        var total: Int64 = 0
        for dir in [setsDir, blobsDir] {
            let urls = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            for url in urls {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                total += Int64(size)
            }
        }
        return total
    }

    @discardableResult
    public func collectGarbage(keeping sets: [ScanSet]) async throws -> Int64 {
        let keep = referencedHashes(in: sets)
        var freed: Int64 = 0
        let urls = (try? fm.contentsOfDirectory(at: blobsDir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        for url in urls where url.pathExtension == "fpc" {
            let hash = url.deletingPathExtension().lastPathComponent
            guard !keep.contains(hash) else { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try? fm.removeItem(at: url)
            freed += Int64(size)
        }
        return freed
    }
}
