import Foundation
import FungibleDomain
import FungibleCapture

// Pure-Swift ASPRS LAS 1.2 writer (Point Data Record Format 2: XYZ + RGB) — the
// uncompressed survey standard that CloudCompare, ReCap, Cyclone, QGIS, etc. all
// import. No native library needed; LAZ (compression) and E57 are the only
// formats that require the bridged codecs. Little-endian, 227-byte public header
// + 26-byte records, per the spec. Coordinates use the survey plan-view mapping:
// LAS X=east(our x), Y=north(our z), Z=elevation(our y).
public struct LASExporter: PointCloudExporter {
    public var format: ExportFormat { .las }
    /// Stored coordinate precision (meters per integer step).
    public var scale: Double

    public init(scale: Double = 0.001) {
        precondition(scale > 0)
        self.scale = scale
    }

    public func data(for points: [CapturedPoint]) -> Data {
        data(for: points, sourceIDs: nil)
    }

    /// Write with per-point provenance: `sourceIDs` is parallel to `points`
    /// (1-based per source scan; 0 = unassigned, per spec) and lands in each
    /// record's point-source-ID field — so an exported merge can be split back
    /// into its scans in CloudCompare/ReCap (ADR-0010 external unmerge).
    public func data(for points: [CapturedPoint], sourceIDs: [UInt16]?) -> Data {
        precondition(sourceIDs == nil || sourceIDs!.count == points.count,
                     "sourceIDs must parallel points")
        // Map to LAS axes and find bounds.
        var minX = 0.0, minY = 0.0, minZ = 0.0, maxX = 0.0, maxY = 0.0, maxZ = 0.0
        if let first = points.first {
            minX = first.position.x; maxX = first.position.x
            minY = first.position.z; maxY = first.position.z   // LAS Y = our z (north)
            minZ = first.position.y; maxZ = first.position.y   // LAS Z = our y (up)
            for p in points {
                minX = Swift.min(minX, p.position.x); maxX = Swift.max(maxX, p.position.x)
                minY = Swift.min(minY, p.position.z); maxY = Swift.max(maxY, p.position.z)
                minZ = Swift.min(minZ, p.position.y); maxZ = Swift.max(maxZ, p.position.y)
            }
        }
        let offX = minX, offY = minY, offZ = minZ

        var data = Data(capacity: 227 + points.count * 26)
        writeHeader(&data, count: points.count,
                    offset: (offX, offY, offZ),
                    bounds: (minX, maxX, minY, maxY, minZ, maxZ))

        for (i, p) in points.enumerated() {
            appendI32(&data, scaled(p.position.x, offX))   // X = east
            appendI32(&data, scaled(p.position.z, offY))   // Y = north
            appendI32(&data, scaled(p.position.y, offZ))   // Z = elevation
            appendU16(&data, 0)                            // intensity
            data.append(0b0000_1001)                       // return 1 of 1
            data.append(0)                                 // classification
            data.append(0)                                 // scan angle rank
            data.append(0)                                 // user data
            appendU16(&data, sourceIDs?[i] ?? 0)           // point source id
            appendU16(&data, UInt16(p.r) &* 257)           // 8-bit → 16-bit
            appendU16(&data, UInt16(p.g) &* 257)
            appendU16(&data, UInt16(p.b) &* 257)
        }
        return data
    }

    private func scaled(_ coord: Double, _ offset: Double) -> Int32 {
        Int32(((coord - offset) / scale).rounded())
    }

    private func writeHeader(
        _ data: inout Data, count: Int,
        offset: (Double, Double, Double),
        bounds: (Double, Double, Double, Double, Double, Double)
    ) {
        data.append(contentsOf: Array("LASF".utf8))        // @0  signature
        appendU16(&data, 0)                                // @4  file source id
        appendU16(&data, 0)                                // @6  global encoding
        data.append(contentsOf: [UInt8](repeating: 0, count: 16)) // @8 project GUID
        data.append(1)                                     // @24 version major
        data.append(2)                                     // @25 version minor
        appendFixedString(&data, "Fungible", length: 32)   // @26 system id
        appendFixedString(&data, "FungibleExport", length: 32) // @58 generating sw
        appendU16(&data, 0)                                // @90 creation day
        appendU16(&data, 0)                                // @92 creation year
        appendU16(&data, 227)                              // @94 header size
        appendU32(&data, 227)                              // @96 offset to points
        appendU32(&data, 0)                                // @100 num VLRs
        data.append(2)                                     // @104 point format
        appendU16(&data, 26)                               // @105 record length
        appendU32(&data, UInt32(count))                    // @107 num point records
        appendU32(&data, UInt32(count))                    // @111 by-return[0]
        data.append(contentsOf: [UInt8](repeating: 0, count: 16)) // by-return[1..4]
        appendDouble(&data, scale); appendDouble(&data, scale); appendDouble(&data, scale)
        appendDouble(&data, offset.0); appendDouble(&data, offset.1); appendDouble(&data, offset.2)
        // Max X, Min X, Max Y, Min Y, Max Z, Min Z (spec order).
        appendDouble(&data, bounds.1); appendDouble(&data, bounds.0)
        appendDouble(&data, bounds.3); appendDouble(&data, bounds.2)
        appendDouble(&data, bounds.5); appendDouble(&data, bounds.4)
    }

    // MARK: - Little-endian writers

    private func appendU16(_ d: inout Data, _ v: UInt16) {
        var le = v.littleEndian; withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
    private func appendU32(_ d: inout Data, _ v: UInt32) {
        var le = v.littleEndian; withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
    private func appendI32(_ d: inout Data, _ v: Int32) {
        var le = v.littleEndian; withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
    private func appendDouble(_ d: inout Data, _ v: Double) {
        var le = v.bitPattern.littleEndian; withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
    private func appendFixedString(_ d: inout Data, _ s: String, length: Int) {
        var bytes = Array(s.utf8.prefix(length))
        bytes.append(contentsOf: [UInt8](repeating: 0, count: length - bytes.count))
        d.append(contentsOf: bytes)
    }
}
