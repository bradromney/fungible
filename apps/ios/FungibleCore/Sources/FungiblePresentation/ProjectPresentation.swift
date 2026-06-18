import Foundation
import FungibleDomain

// Display-side concepts the wireframes lean on that aren't (yet) persisted on
// the domain structs. Kept here as pure, testable presentation types so the
// SwiftUI screens bind to verified logic. Promoting `type`/`syncState` onto
// `ScanSet` (and `category`/`photo` onto `Annotation`) in the domain model is a
// follow-up that warrants its own ADR — these mirror what that model will hold.

/// Sync posture shown as a glyph on each project row. `localOnly` is a valid
/// resting state, not an error — the app is local-first (ADR-0003).
public enum SyncState: String, Codable, Sendable, CaseIterable {
    case synced
    case syncing
    case localOnly
    case needsAttention

    /// SF Symbol name for the row glyph.
    public var symbolName: String {
        switch self {
        case .synced:         return "checkmark.icloud"
        case .syncing:        return "arrow.triangle.2.circlepath.icloud"
        case .localOnly:      return "iphone"
        case .needsAttention: return "exclamationmark.icloud"
        }
    }

    public var label: String {
        switch self {
        case .synced:         return "Synced"
        case .syncing:        return "Syncing…"
        case .localOnly:      return "On this iPhone"
        case .needsAttention: return "Needs attention"
        }
    }

    /// Only `needsAttention` is a problem; `localOnly` is intentional.
    public var isError: Bool { self == .needsAttention }
}

/// What kind of thing a project captures. Auto-detected from the first scan,
/// user-overridable; it tunes vocabulary, the one contextual toolbar slot, and
/// which facts a report computes — it does NOT fork the codebase (ADR-0007).
public enum ProjectType: String, Codable, Sendable, CaseIterable {
    case site       // open ground / earthwork / landscaping
    case interior   // rooms, floors, walls (AEC)
    case object     // a single thing scanned all around

    public var chipLabel: String {
        switch self {
        case .site:     return "Site"
        case .interior: return "Interior"
        case .object:   return "Object"
        }
    }

    /// The single contextual action that swaps per type; the rest of the
    /// toolbar (Measure/Annotate/Export/Report) is constant across markets.
    public var contextualToolLabel: String {
        switch self {
        case .site:     return "Cut/Fill"
        case .interior: return "Floorplan"
        case .object:   return "Mesh"
        }
    }

    public var contextualToolSymbol: String {
        switch self {
        case .site:     return "mountain.2"
        case .interior: return "square.split.bottomrightquarter"
        case .object:   return "cube.transparent"
        }
    }

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

/// Everything screen 01 needs to draw one project row, derived purely from a
/// `ScanSet` (+ its display-only sync state). No view code, so it's unit-tested.
public struct ProjectRowModel: Equatable, Sendable {
    public let id: ScanSetID
    public let name: String
    public let passCountLabel: String
    public let pointCountLabel: String
    public let timestampLabel: String
    public let sync: SyncState

    public init(
        from set: ScanSet,
        sync: SyncState = .localOnly,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) {
        self.id = set.id
        self.name = set.name
        self.passCountLabel = DisplayFormat.passCount(set.scanCount)
        let totalPoints = set.scans.reduce(0) { $0 + $1.pointCloud.pointCount }
        self.pointCountLabel = DisplayFormat.pointCountLabel(totalPoints)
        // Most-recent pass time orders the library; fall back to creation.
        let stamp = set.scans.map(\.capturedAt).max() ?? set.createdAt
        self.timestampLabel = DisplayFormat.preciseTimestamp(stamp, locale: locale, timeZone: timeZone)
        self.sync = sync
    }
}

/// How a `Scan`'s lifecycle status reads in the passes list (screen 03). Low
/// quality is flagged, never hidden — auto-grouping must stay honest.
public extension ScanStatus {
    var displayLabel: String {
        switch self {
        case .capturing:       return "Capturing"
        case .pendingRegister: return "Queued"
        case .registering:     return "Registering…"
        case .registered:      return "Registered"
        case .failed:          return "Needs attention"
        }
    }

    var symbolName: String {
        switch self {
        case .capturing:       return "dot.radiowaves.left.and.right"
        case .pendingRegister: return "clock"
        case .registering:     return "arrow.triangle.2.circlepath"
        case .registered:      return "checkmark.circle"
        case .failed:          return "exclamationmark.triangle"
        }
    }

    /// Registration runs in the background — these states show a non-blocking
    /// "keep going" banner rather than a spinner that locks the project.
    var isInProgress: Bool { self == .registering || self == .pendingRegister }

    /// Only `failed` calls for user attention; everything else is on-track.
    var needsAttention: Bool { self == .failed }
}

/// A pinned-note category (screen 04). Display-side until the domain
/// `Annotation` grows a category/photo (ADR follow-up).
public enum AnnotationCategory: String, Codable, Sendable, CaseIterable {
    case issue
    case todo
    case note
    case spec

    public var label: String {
        switch self {
        case .issue: return "Issue"
        case .todo:  return "To-do"
        case .note:  return "Note"
        case .spec:  return "Spec"
        }
    }

    public var symbolName: String {
        switch self {
        case .issue: return "exclamationmark.triangle"
        case .todo:  return "checklist"
        case .note:  return "note.text"
        case .spec:  return "ruler"
        }
    }
}
