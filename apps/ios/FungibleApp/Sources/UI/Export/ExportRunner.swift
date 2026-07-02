import Foundation
import FungibleDomain
import FungibleCapture
import FungibleStorage
import FungibleExport

/// Turns a project into a real file on disk for the on-device formats
/// (PLY/XYZ/LAS). Assembles the VISIBLE passes (ADR-0010) into the set frame and
/// writes with the matching FungibleExport writer; LAS also carries per-scan
/// point-source IDs (ADR-0010 external unmerge). Off the main actor.
///
/// LAZ/COPC/E57 are not here — they're built server-side by the PDAL worker; the
/// UI routes those through processing/sync instead of pretending to write them.
enum ExportRunner {

    /// The core writer for a catalog extension, or nil if it's not an on-device
    /// format.
    static func coreFormat(forExt ext: String) -> FungibleExport.ExportFormat? {
        switch ext.uppercased() {
        case "PLY": return .plyBinary
        case "XYZ": return .xyz
        case "LAS": return .las
        default:    return nil
        }
    }

    static func isOnDevice(ext: String) -> Bool { coreFormat(forExt: ext) != nil }

    /// Assemble the visible cloud and write it as `ext` to a temp file. Returns
    /// the file URL to hand to the share sheet. Throws if the format isn't
    /// on-device or the write fails.
    static func export(_ set: ScanSet, ext: String, store: any ScanStore) async throws -> URL {
        guard let format = coreFormat(forExt: ext) else { throw ExportRunnerError.notOnDevice(ext) }
        let assembler = ScanSetAssembler(store: store)

        let data: Data
        if format == .las {
            // LAS carries provenance so a merge splits back into passes elsewhere.
            let (points, sourceIDs) = try await assembler.assembleAttributed(set)
            guard !points.isEmpty else { throw ExportRunnerError.empty }
            data = LASExporter().data(for: points, sourceIDs: sourceIDs)
        } else {
            let points = try await assembler.assemble(set)   // visible passes only
            guard !points.isEmpty else { throw ExportRunnerError.empty }
            data = Exporters.make(format).data(for: points)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: set, ext: format.fileExtension))
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func fileName(for set: ScanSet, ext: String) -> String {
        let base = set.name.isEmpty ? "Untitled" : set.name
        let safe = base.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(safe) + "." + ext
    }
}

enum ExportRunnerError: LocalizedError {
    case notOnDevice(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .notOnDevice(let ext): return "\(ext) is built in the cloud, not on device."
        case .empty:                return "This project has no visible points to export."
        }
    }
}
