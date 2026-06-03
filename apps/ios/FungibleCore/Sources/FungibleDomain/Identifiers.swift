import Foundation

// Type-safe identifiers so a ScanID can never be passed where a ScanSetID is
// expected. All are UUID-backed and Codable for the Automerge catalog.
// `init(rawValue:)` takes no default so the no-arg `init()` (fresh id) stays
// unambiguous at call sites like `ScanID()`.

public struct ScanID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct ScanSetID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct MeasurementID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct AnnotationID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

/// Content address (e.g. SHA-256 hex) for an immutable point-cloud blob.
/// Blobs are addressed by content so sync drivers can dedup and verify, and so
/// "conflicts" on large files are resolved by hash/version, never by merge.
public struct ContentHash: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}
