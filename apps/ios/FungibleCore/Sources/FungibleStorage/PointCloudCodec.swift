import Foundation
import FungibleDomain
import FungibleCapture

// Compact internal on-device blob format ("FPC1"). This is the fast, simple
// capture/finalize format; pro-grade export to LAZ/COPC/E57 (the formats
// surveyors ingest) happens in FungibleExport via the bridged codecs. 16 bytes
// per point: 3× Float32 position + RGB + 1 confidence byte. Little-endian.

public enum PointCloudCodec {
    static let magic: [UInt8] = [0x46, 0x50, 0x43, 0x31] // "FPC1"
    static let version: UInt32 = 1
    static let headerSize = 12 // magic(4) + version(4) + count(4)
    static let pointStride = 16 // 3*4 + 3 + 1

    public static func encode(_ points: [CapturedPoint]) -> Data {
        var data = Data(capacity: headerSize + points.count * pointStride)
        data.append(contentsOf: magic)
        appendLE(&data, version)
        appendLE(&data, UInt32(points.count))
        for p in points {
            appendLE(&data, Float(p.position.x).bitPattern)
            appendLE(&data, Float(p.position.y).bitPattern)
            appendLE(&data, Float(p.position.z).bitPattern)
            data.append(p.r)
            data.append(p.g)
            data.append(p.b)
            data.append(UInt8(p.confidence.rawValue))
        }
        return data
    }

    public static func decode(_ data: Data) throws -> [CapturedPoint] {
        let bytes = [UInt8](data)
        guard bytes.count >= headerSize, Array(bytes[0..<4]) == magic else {
            throw StorageError.corrupted
        }
        // Reject unknown versions rather than mis-decoding a future layout as v1.
        guard readLE32(bytes, 4) == version else {
            throw StorageError.unsupportedVersion(readLE32(bytes, 4))
        }
        let count = Int(readLE32(bytes, 8))
        guard bytes.count == headerSize + count * pointStride else {
            throw StorageError.corrupted
        }

        var points = [CapturedPoint]()
        points.reserveCapacity(count)
        var offset = headerSize
        for _ in 0..<count {
            let x = Float(bitPattern: readLE32(bytes, offset))
            let y = Float(bitPattern: readLE32(bytes, offset + 4))
            let z = Float(bitPattern: readLE32(bytes, offset + 8))
            let r = bytes[offset + 12]
            let g = bytes[offset + 13]
            let b = bytes[offset + 14]
            let conf = DepthConfidence(rawValue: Int(bytes[offset + 15])) ?? .low
            points.append(CapturedPoint(
                position: Vector3(Double(x), Double(y), Double(z)),
                confidence: conf, r: r, g: g, b: b
            ))
            offset += pointStride
        }
        return points
    }

    // MARK: - Little-endian helpers

    private static func appendLE(_ data: inout Data, _ value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func readLE32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}
