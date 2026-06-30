import Foundation
import FungibleDomain

// Presentation layer for project state. The *data* now lives on the domain model
// (`ScanSet.type`, `Annotation.category`, `ScanSet.share` — ADR-0009); this file
// owns the *vocabulary*: the labels, glyphs, and per-market fact strings the
// SwiftUI screens bind to. `SyncState` stays here because it's a runtime posture
// derived from the `SyncProvider` (ADR-0003), not authored data on the set.

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

/// Display vocabulary for `ProjectType` (the enum + `detect` live in
/// `FungibleDomain`; this is the market-facing wording — ADR-0007/0009).
public extension ProjectType {
    var chipLabel: String {
        switch self {
        case .site:     return "Site"
        case .interior: return "Interior"
        case .object:   return "Object"
        }
    }

    /// The single contextual action that swaps per type; the rest of the
    /// toolbar (Measure/Annotate/Export/Report) is constant across markets.
    var contextualToolLabel: String {
        switch self {
        case .site:     return "Cut/Fill"
        case .interior: return "Floorplan"
        case .object:   return "Mesh"
        }
    }

    var contextualToolSymbol: String {
        switch self {
        case .site:     return "mountain.2"
        case .interior: return "square.split.bottomrightquarter"
        case .object:   return "cube.transparent"
        }
    }

    /// Section title for the market-specific facts (ADR-0007: same screen,
    /// different vocabulary — never a fork).
    var factsSectionTitle: String {
        switch self {
        case .site:     return "Site facts"
        case .interior: return "Room facts"
        case .object:   return "Object facts"
        }
    }

    /// The ordered fact labels a report/detail leads with, per market. The same
    /// cloud feeds all of them; only the framing changes.
    var factLabels: [String] {
        switch self {
        case .site:     return ["Plan area", "Elevation range", "Net cut @ grade", "Avg slope"]
        case .interior: return ["Floor area", "Ceiling height", "Wall area", "Openings"]
        case .object:   return ["Height", "Max diameter", "Bounding box", "Coverage"]
        }
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

/// Display vocabulary for a pinned-note category (screen 04). The enum lives on
/// the domain model (`Annotation.category` — ADR-0009); this is its wording/glyph.
public extension AnnotationCategory {
    var label: String {
        switch self {
        case .issue: return "Issue"
        case .todo:  return "To-do"
        case .note:  return "Note"
        case .spec:  return "Spec"
        }
    }

    var symbolName: String {
        switch self {
        case .issue: return "exclamationmark.triangle"
        case .todo:  return "checklist"
        case .note:  return "note.text"
        case .spec:  return "ruler"
        }
    }
}
