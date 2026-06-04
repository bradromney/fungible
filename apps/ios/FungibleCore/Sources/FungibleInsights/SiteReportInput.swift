import Foundation

// Structured, measured facts about a scan/set — the input to report generation.
// Deliberately primitive (no dependency on the measure/domain volume types) so
// it's market-agnostic: a landscaping cut/fill report, an AEC as-built summary,
// or a general 3D capture summary all populate the same struct. The numbers come
// from the (tested) measurement engine; this module never invents them.
public struct SiteReportInput: Equatable, Sendable {
    public var siteName: String
    /// Plan (footprint) area in m², if computed.
    public var areaSquareMeters: Double?
    /// Earthwork volumes in m³, if computed (cut = remove, fill = add).
    public var cutVolume: Double?
    public var fillVolume: Double?
    public var pointCount: Int
    /// Extra labelled facts (e.g. "Max slope": "12°", "Ceiling height": "2.7 m").
    public var facts: [(label: String, value: String)]
    /// Haul capacity for truckload estimates (m³ per load).
    public var truckCapacityCubicMeters: Double

    public init(
        siteName: String,
        areaSquareMeters: Double? = nil,
        cutVolume: Double? = nil,
        fillVolume: Double? = nil,
        pointCount: Int = 0,
        facts: [(label: String, value: String)] = [],
        truckCapacityCubicMeters: Double = 10
    ) {
        self.siteName = siteName
        self.areaSquareMeters = areaSquareMeters
        self.cutVolume = cutVolume
        self.fillVolume = fillVolume
        self.pointCount = pointCount
        self.facts = facts
        self.truckCapacityCubicMeters = truckCapacityCubicMeters
    }

    /// Net volume (fill − cut): positive = net material added.
    public var netVolume: Double? {
        guard cutVolume != nil || fillVolume != nil else { return nil }
        return (fillVolume ?? 0) - (cutVolume ?? 0)
    }

    public var fillTruckloads: Int { loads(fillVolume) }
    public var cutTruckloads: Int { loads(cutVolume) }

    private func loads(_ volume: Double?) -> Int {
        guard let v = volume, v > 0, truckCapacityCubicMeters > 0 else { return 0 }
        return Int((v / truckCapacityCubicMeters).rounded(.up))
    }

    public static func == (a: SiteReportInput, b: SiteReportInput) -> Bool {
        a.siteName == b.siteName && a.areaSquareMeters == b.areaSquareMeters &&
        a.cutVolume == b.cutVolume && a.fillVolume == b.fillVolume &&
        a.pointCount == b.pointCount && a.truckCapacityCubicMeters == b.truckCapacityCubicMeters &&
        a.facts.map(\.label) == b.facts.map(\.label) && a.facts.map(\.value) == b.facts.map(\.value)
    }
}
