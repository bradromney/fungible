import Foundation
import FungibleEntitlements

// The interop matrix for the Convert/Export screen (05), grouped by intent. Each
// format maps to the real `Capability` seam that may become paid later — today
// every flag is open (free MVP, ADR-0004), so a format is never locked, only
// quietly badged. Static, pure data → unit-tested so the screen can't drift from
// the entitlement model.
public struct ExportFormat: Equatable, Sendable, Identifiable {
    public enum Intent: String, Sendable, CaseIterable {
        case pointCloud
        case cadBim
        case model3D

        /// Section header in the matrix.
        public var groupLabel: String {
            switch self {
            case .pointCloud: return "Point cloud"
            case .cadBim:     return "CAD & BIM"
            case .model3D:    return "3D model"
            }
        }

        /// Label for the category filter chip.
        public var filterLabel: String {
            switch self {
            case .pointCloud: return "Point cloud"
            case .cadBim:     return "CAD / BIM"
            case .model3D:    return "3D model"
            }
        }
    }

    public let id: String          // file extension, also the stable id
    public let ext: String         // shown in mono, e.g. "LAZ"
    public let blurb: String       // plain-language one-liner
    public let tag: String         // short intent chip on the card (Cloud/CAD/…)
    public let intent: Intent
    public let capability: Capability

    public init(ext: String, blurb: String, tag: String, intent: Intent, capability: Capability) {
        self.id = ext.lowercased()
        self.ext = ext
        self.blurb = blurb
        self.tag = tag
        self.intent = intent
        self.capability = capability
    }
}

public enum ExportCatalog {
    /// Every supported target, in display order within its intent group. Copy
    /// mirrors the wireframe so the screen reads the same plain-language text.
    public static let all: [ExportFormat] = [
        // Point cloud
        ExportFormat(ext: "LAZ",     blurb: "Compressed LAS — the survey standard",     tag: "Cloud", intent: .pointCloud, capability: .exportLAZ),
        ExportFormat(ext: "COPC",    blurb: "Cloud-optimized point cloud — streamable", tag: "Cloud", intent: .pointCloud, capability: .exportLAZ),
        ExportFormat(ext: "E57",     blurb: "ASTM interchange — scans + imagery",        tag: "Cloud", intent: .pointCloud, capability: .exportE57),
        ExportFormat(ext: "PLY",     blurb: "Polygon / point — universal mesh",          tag: "Cloud", intent: .pointCloud, capability: .exportLAZ),
        // CAD & BIM
        ExportFormat(ext: "DXF",     blurb: "AutoCAD drawing exchange",                  tag: "CAD",   intent: .cadBim,     capability: .exportDXF),
        ExportFormat(ext: "IFC",     blurb: "openBIM building model",                    tag: "BIM",   intent: .cadBim,     capability: .exportIFC),
        ExportFormat(ext: "LandXML", blurb: "Civil surfaces & alignments",               tag: "Civil", intent: .cadBim,     capability: .exportLandXML),
        // 3D model
        ExportFormat(ext: "USDZ",    blurb: "AR Quick Look — view on iOS",               tag: "3D",    intent: .model3D,    capability: .exportLAZ),
        ExportFormat(ext: "OBJ",     blurb: "Universal textured mesh",                   tag: "3D",    intent: .model3D,    capability: .exportLAZ),
        ExportFormat(ext: "glTF",    blurb: "Modern runtime 3D — web & engines",         tag: "3D",    intent: .model3D,    capability: .exportLAZ),
    ]

    /// Formats for one intent group, preserving declared order.
    public static func formats(in intent: ExportFormat.Intent) -> [ExportFormat] {
        all.filter { $0.intent == intent }
    }

    /// Whether a format carries a soft (paywall-candidate) badge for this user.
    /// In the free MVP everything is enabled, so this drives the quiet "✦
    /// included free during beta" note — never a lock.
    public static func isSoftPro(_ format: ExportFormat, entitlements: EntitlementsProviding) -> Bool {
        // Soft-badge the capabilities most likely to become paid lines later.
        let proCandidates: Set<Capability> = [.exportE57, .exportIFC, .exportLandXML]
        return proCandidates.contains(format.capability)
            && entitlements.isEnabled(format.capability)
    }

    /// A 3D-model format needs surface geometry; on an empty/too-sparse project
    /// the screen shows an inline caveat and redirects to the nearest viable
    /// format (never a dead end — note 8 on the wireframe). Returns the suggested
    /// fallback format's extension, or nil if the selection is fine.
    public static func unsupportedFallback(for format: ExportFormat, pointCount: Int) -> String? {
        guard format.intent == .model3D, pointCount == 0 else { return nil }
        return "PLY"
    }
}
