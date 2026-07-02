import XCTest
import FungibleDomain
import FungibleCapture
@testable import FungibleStorage

final class PointCloudCodecTests: XCTestCase {
    private func samplePoints() -> [CapturedPoint] {
        [
            CapturedPoint(position: Vector3(1.5, -2.25, 3.0), confidence: .high, r: 10, g: 20, b: 30),
            CapturedPoint(position: Vector3(0, 0, 0), confidence: .low, r: 0, g: 0, b: 0),
            CapturedPoint(position: Vector3(-100.5, 50.25, 7.75), confidence: .medium, r: 255, g: 128, b: 1),
        ]
    }

    func testEncodeDecodeRoundTrip() throws {
        let points = samplePoints()
        let decoded = try PointCloudCodec.decode(PointCloudCodec.encode(points))
        XCTAssertEqual(decoded.count, points.count)
        for (a, b) in zip(points, decoded) {
            // Positions round-trip through Float32, so compare with tolerance.
            XCTAssertEqual(a.position.x, b.position.x, accuracy: 1e-3)
            XCTAssertEqual(a.position.y, b.position.y, accuracy: 1e-3)
            XCTAssertEqual(a.position.z, b.position.z, accuracy: 1e-3)
            XCTAssertEqual(a.confidence, b.confidence)
            XCTAssertEqual(a.r, b.r); XCTAssertEqual(a.g, b.g); XCTAssertEqual(a.b, b.b)
        }
    }

    func testEmptyRoundTrips() throws {
        XCTAssertEqual(try PointCloudCodec.decode(PointCloudCodec.encode([])).count, 0)
    }

    func testCorruptDataThrows() {
        XCTAssertThrowsError(try PointCloudCodec.decode(Data([0, 1, 2, 3])))
    }

    func testUnknownVersionIsRejectedNotMisdecoded() throws {
        var data = PointCloudCodec.encode(samplePoints())
        data[4] = 2 // bump the little-endian version field to an unknown v2
        do {
            _ = try PointCloudCodec.decode(data)
            XCTFail("expected unsupportedVersion")
        } catch {
            XCTAssertEqual(error as? StorageError, .unsupportedVersion(2))
        }
    }

    func testByteSizeMatchesFormula() {
        let data = PointCloudCodec.encode(samplePoints())
        XCTAssertEqual(data.count, 12 + 3 * 16)
    }
}

final class ContentHashingTests: XCTestCase {
    func testDeterministicAndDistinct() {
        let a = ContentHashing.contentHash(Data([1, 2, 3]))
        let b = ContentHashing.contentHash(Data([1, 2, 3]))
        let c = ContentHashing.contentHash(Data([1, 2, 4]))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertTrue(a.rawValue.hasPrefix("sha256-"))
    }

    func testSHA256MatchesNISTVectors() {
        // FIPS 180-4 / NIST CAVP known-answer vectors.
        XCTAssertEqual(
            ContentHashing.sha256Hex(Data()),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        XCTAssertEqual(
            ContentHashing.sha256Hex(Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(
            ContentHashing.sha256Hex(Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        )
        // 64 bytes = exactly one block before padding; exercises the two-block path.
        XCTAssertEqual(
            ContentHashing.sha256Hex(Data(repeating: 0x61, count: 64)),
            "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"
        )
    }

    func testLegacyFNV1a64StillAvailable() {
        // Pre-upgrade blobs are tagged "fnv1a64-…"; the algorithm must keep
        // producing identical hex so those names remain explicable/verifiable.
        XCTAssertEqual(ContentHashing.fnv1a64Hex(Data()), "cbf29ce484222325")
    }
}

final class FileScanStoreTests: XCTestCase {
    private func makeStore() throws -> (FileScanStore, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (try FileScanStore(root: root), root)
    }

    func testSaveLoadDeleteSet() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        var set = ScanSet(name: "Backyard Grading")
        set.append(Scan(deviceModel: "iPhone16,1"))
        try await store.save(set)

        let loaded = try await store.loadSets()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Backyard Grading")
        XCTAssertEqual(loaded.first?.scanCount, 1)

        try await store.deleteSet(set.id)
        let after = try await store.loadSets()
        XCTAssertTrue(after.isEmpty)
    }

    func testBlobWriteReadRoundTrip() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let points = [
            CapturedPoint(position: Vector3(1, 2, 3), confidence: .high, r: 1, g: 2, b: 3),
            CapturedPoint(position: Vector3(4, 5, 6), confidence: .medium),
        ]
        let scan = ScanID()
        let ref = try await store.writeBlob(points: points, for: scan)
        XCTAssertEqual(ref.pointCount, 2)
        XCTAssertNotNil(ref.hash)
        XCTAssertNotNil(store.localURL(for: ref))

        let readBack = try await store.readBlob(ref)
        XCTAssertEqual(readBack.count, 2)
    }

    func testContentAddressingDeduplicates() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let points = [CapturedPoint(position: Vector3(1, 1, 1), confidence: .high)]
        let ref1 = try await store.writeBlob(points: points, for: ScanID())
        let usageAfterFirst = await store.diskUsageBytes()
        let ref2 = try await store.writeBlob(points: points, for: ScanID())
        let usageAfterSecond = await store.diskUsageBytes()

        XCTAssertEqual(ref1.hash, ref2.hash, "identical points → identical hash")
        XCTAssertEqual(usageAfterFirst, usageAfterSecond, "duplicate blob not rewritten")
    }

    func testCorruptCatalogFileIsSkippedNotFatal() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try await store.save(ScanSet(name: "Healthy"))
        // Simulate a truncated write / disk corruption alongside the good file.
        let bad = root.appendingPathComponent("sets").appendingPathComponent("broken.json")
        try Data("{\"id\": tru".utf8).write(to: bad)

        let loaded = try await store.loadSets()
        XCTAssertEqual(loaded.map(\.name), ["Healthy"])
    }

    func testReadMissingBlobThrows() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let bogus = PointCloudRef(hash: ContentHash(rawValue: "fnv1a64-deadbeef"), localPath: "x.fpc")
        do {
            _ = try await store.readBlob(bogus)
            XCTFail("expected blobNotFound")
        } catch {
            XCTAssertEqual(error as? StorageError, .blobNotFound)
        }
    }
}

final class InMemoryScanStoreTests: XCTestCase {
    func testRoundTrip() async throws {
        let store = InMemoryScanStore()
        let set = ScanSet(name: "Memory Site")
        try await store.save(set)
        let points = [CapturedPoint(position: Vector3(0, 1, 2), confidence: .high)]
        let ref = try await store.writeBlob(points: points, for: ScanID())

        let loaded = try await store.loadSets()
        XCTAssertEqual(loaded.first?.name, "Memory Site")
        let read = try await store.readBlob(ref)
        XCTAssertEqual(read.count, 1)
        let usage = await store.diskUsageBytes()
        XCTAssertGreaterThan(usage, 0)
    }
}
