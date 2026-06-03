import Foundation
import FungibleDomain
import FungibleCapture

/// Writes PLY with x/y/z (float32) + red/green/blue (uchar) per vertex, in
/// either ASCII or binary little-endian. PLY is widely read by CloudCompare,
/// MeshLab, ReCap, and three.js loaders.
public struct PLYExporter: PointCloudExporter {
    public let binary: Bool
    public var format: ExportFormat { binary ? .plyBinary : .plyASCII }

    public init(binary: Bool = true) {
        self.binary = binary
    }

    public func data(for points: [CapturedPoint]) -> Data {
        binary ? encodeBinary(points) : encodeASCII(points)
    }

    private func header(count: Int, formatLine: String) -> String {
        """
        ply
        format \(formatLine)
        element vertex \(count)
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        end_header

        """
    }

    private func encodeASCII(_ points: [CapturedPoint]) -> Data {
        var text = header(count: points.count, formatLine: "ascii 1.0")
        for p in points {
            text += "\(Float(p.position.x)) \(Float(p.position.y)) \(Float(p.position.z)) \(p.r) \(p.g) \(p.b)\n"
        }
        return Data(text.utf8)
    }

    private func encodeBinary(_ points: [CapturedPoint]) -> Data {
        var data = Data(header(count: points.count, formatLine: "binary_little_endian 1.0").utf8)
        data.reserveCapacity(data.count + points.count * 15)
        for p in points {
            appendFloatLE(&data, Float(p.position.x))
            appendFloatLE(&data, Float(p.position.y))
            appendFloatLE(&data, Float(p.position.z))
            data.append(p.r); data.append(p.g); data.append(p.b)
        }
        return data
    }

    private func appendFloatLE(_ data: inout Data, _ value: Float) {
        var le = value.bitPattern.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }
}
