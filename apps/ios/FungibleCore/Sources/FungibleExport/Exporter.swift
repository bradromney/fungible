import Foundation
import FungibleDomain
import FungibleCapture

// Pro-grade export (research §3/§9). Today we ship correct, dependency-free
// **PLY** and **XYZ** — both read directly by CloudCompare, ReCap, and most
// survey/CAD tools — so a captured scan is immediately useful elsewhere. The
// survey-standard codecs (LAS/LAZ, E57, COPC) come via the vetted bridged
// libraries (las-rs/LASzip, libE57Format, copc-lib) behind this same protocol;
// hand-rolling LAS risks subtle non-conformance, so we don't.

public enum ExportFormat: String, CaseIterable, Sendable {
    case plyBinary   // PLY, binary little-endian (compact, recommended)
    case plyASCII    // PLY, ASCII (human-readable / debugging)
    case xyz         // ASCII "x y z r g b" per line (universal fallback)
    case las         // ASPRS LAS 1.2 (uncompressed survey standard)

    public var fileExtension: String {
        switch self {
        case .plyBinary, .plyASCII: return "ply"
        case .xyz: return "xyz"
        case .las: return "las"
        }
    }
}

public protocol PointCloudExporter: Sendable {
    var format: ExportFormat { get }
    func data(for points: [CapturedPoint]) -> Data
}

public extension PointCloudExporter {
    /// Convenience: encode and write to a file URL.
    func write(_ points: [CapturedPoint], to url: URL) throws {
        try data(for: points).write(to: url, options: .atomic)
    }
}

public enum Exporters {
    public static func make(_ format: ExportFormat) -> any PointCloudExporter {
        switch format {
        case .plyBinary: return PLYExporter(binary: true)
        case .plyASCII: return PLYExporter(binary: false)
        case .xyz: return XYZExporter()
        case .las: return LASExporter()
        }
    }
}
