import Foundation

/// What kind of thing a project captures. Auto-detected from the first scan,
/// user-overridable; it tunes vocabulary, the one contextual toolbar slot, and
/// which facts a report computes — it does NOT fork the codebase (ADR-0007).
///
/// Persisted on `ScanSet.type` (ADR-0009). The *data* lives here in the
/// device-independent core; the display strings (`chipLabel`, `factLabels`, …)
/// live in `FungiblePresentation` as extensions, so the module layering stays
/// acyclic (presentation depends on domain, never the reverse).
public enum ProjectType: String, Codable, Sendable, CaseIterable {
    case site       // open ground / earthwork / landscaping
    case interior   // rooms, floors, walls (AEC)
    case object     // a single thing scanned all around

    /// Heuristic auto-detection from a captured volume's bounding box. Open and
    /// wide-but-shallow reads as a site; room-scale enclosure reads as interior;
    /// small all-around reads as an object. A best-effort default the user can
    /// override — never a hard classification.
    public static func detect(bounds: BoundingBox) -> ProjectType {
        let size = bounds.sizeMeters
        let footprint = Double(size.x) * Double(size.z)   // ground extent (m²)
        let height = Double(size.y)
        let maxHorizontal = Double(max(size.x, size.z))

        // Small in every dimension → a single object on a table/ground.
        if maxHorizontal <= 2.0 && height <= 2.0 {
            return .object
        }
        // Large ground footprint and relatively low → open site/terrain.
        if footprint >= 100 && height < maxHorizontal {
            return .site
        }
        // Otherwise room-scale: enclosed interior.
        return .interior
    }
}
