import Foundation

// Monetization seams without the machinery (ADR-0004). Features are gated behind
// capability flags. In the MVP every flag is open; turning paid later is a
// config + StoreKit change here, not a refactor across the app.

/// A gateable capability. Add cases as features that *might* become paid lines.
public enum Capability: String, Codable, Sendable, CaseIterable {
    case unlimitedScansPerSet   // the no-ceiling promise (ADR-0005) — always on
    case exportLAZ
    case exportE57
    case exportDXF
    case exportIFC
    case exportLandXML
    case cutFillVolume          // the earthwork moat
    case hostedStorage          // our managed cloud storage
    case byoCloud               // bring-your-own Drive / iCloud
    case cloudProcessing        // offload heavy reconstruction to workers
    case webShare               // shareable web-viewer links
}

/// A numeric/limit value associated with a capability (e.g. storage quota).
public struct Quota: Equatable, Codable, Sendable {
    public var bytes: Int64?     // nil = unlimited
    public init(bytes: Int64? = nil) { self.bytes = bytes }
    public static let unlimited = Quota(bytes: nil)
}

/// The set of capabilities and limits granted to the current account/tier.
public struct EntitlementSet: Equatable, Codable, Sendable {
    public var enabled: Set<Capability>
    public var storage: Quota

    public init(enabled: Set<Capability>, storage: Quota = .unlimited) {
        self.enabled = enabled
        self.storage = storage
    }

    /// The MVP grant: everything on, storage unlimited (free, monetization-ready).
    public static let mvpFreeEverything = EntitlementSet(
        enabled: Set(Capability.allCases),
        storage: .unlimited
    )
}

/// Resolves whether the current user may use a capability. The MVP injects
/// `.mvpFreeEverything`; a later billing layer swaps the source without callers
/// changing how they ask.
public protocol EntitlementsProviding: Sendable {
    func isEnabled(_ capability: Capability) -> Bool
    var storageQuota: Quota { get }
}

public struct EntitlementsService: EntitlementsProviding {
    private let entitlements: EntitlementSet

    public init(entitlements: EntitlementSet = .mvpFreeEverything) {
        self.entitlements = entitlements
    }

    public func isEnabled(_ capability: Capability) -> Bool {
        entitlements.enabled.contains(capability)
    }

    public var storageQuota: Quota { entitlements.storage }
}
