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

        public var groupLabel: String {
            switch self {
            case .pointCloud: return "Point cloud"
            case .cadBim:     return "CAD & BIM"
            case .model3D:    return "3D model"
            }
        }
    }

    public let id: String          // file extension, also the stable id
    public let ext: String         // shown in mono, e.g. "LAZ"
    public let blurb: String       // plain-language one-liner
    public let intent: Intent
    public let capability: Capability

    public init(ext: String, blurb: String, intent: Intent, capability: Capability) {
        self.id = ext.lowercased()
        self.ext = ext
        self.blurb = blurb
        self.intent = intent
        self.capability = capability
    }
}

public enum ExportCatalog {
    /// Every supported target, in display order within its intent group.
    public static let all: [ExportFormat] = [
        // Point cloud
        ExportFormat(ext: "LAZ",     blurb: "Compressed LiDAR, the survey standard.",      intent: .pointCloud, capability: .exportLAZ),
        ExportFormat(ext: "COPC",    blurb: "Cloud-optimized LAZ for streaming & web.",    intent: .pointCloud, capability: .exportLAZ),
        ExportFormat(ext: "E57",     blurb: "Vendor-neutral scan exchange.",               intent: .pointCloud, capability: .exportE57),
        ExportFormat(ext: "PLY",     blurb: "Simple points for 3D tools.",                 intent: .pointCloud, capability: .exportLAZ),
        // CAD & BIM
        ExportFormat(ext: "DXF",     blurb: "Lines & contours for CAD.",                   intent: .cadBim,     capability: .exportDXF),
        ExportFormat(ext: "IFC",     blurb: "BIM hand-off for AEC.",                       intent: .cadBim,     capability: .exportIFC),
        ExportFormat(ext: "LandXML", blurb: "Surfaces & alignments for civil.",            intent: .cadBim,     capability: .exportLandXML),
        // 3D model
        ExportFormat(ext: "USDZ",    blurb: "AR-ready model for Apple devices.",           intent: .model3D,    capability: .exportLAZ),
        ExportFormat(ext: "OBJ",     blurb: "Universal mesh for modeling apps.",           intent: .model3D,    capability: .exportLAZ),
        ExportFormat(ext: "glTF",    blurb: "Web-native 3D interchange.",                  intent: .model3D,    capability: .exportLAZ),
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
}
