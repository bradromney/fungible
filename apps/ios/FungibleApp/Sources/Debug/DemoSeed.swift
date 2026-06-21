#if DEBUG
import Foundation
import FungibleDomain
import FungibleCapture
import FungibleStorage

/// Debug-only sample data so the app is explorable without first capturing —
/// handy in the Simulator (no LiDAR) and on a fresh device. Seeds one project per
/// market (site / interior / object, mirroring the market-variants screen) with
/// real but tiny synthetic point-cloud blobs and a few measurements/annotations,
/// so every screen has something to show. Gated to DEBUG: it never ships, and it
/// no-ops the moment any real project exists (including after you capture one).
enum DemoSeed {
    static func seedIfEmpty(_ store: any ScanStore) async {
        guard let sets = try? await store.loadSets(), sets.isEmpty else { return }
        for spec in specs { try? await seed(spec, into: store) }
    }

    private struct Spec {
        let name: String
        let type: ProjectType
        let passes: Int
        let span: (x: Double, z: Double, h: Double)   // meters
        let measurements: [FungibleDomain.Measurement]
        let annotations: [Annotation]
    }

    private static let specs: [Spec] = [
        Spec(name: "Back Garden Regrade", type: .site, passes: 3,
             span: (18.0, 17.6, 0.6),
             measurements: [
                FungibleDomain.Measurement(
                    kind: .area,
                    points: [Vector3(0, 0, 0), Vector3(18, 0, 0), Vector3(18, 0, 17.6), Vector3(0, 0, 17.6)],
                    label: "Lawn footprint"),
                FungibleDomain.Measurement(kind: .volumeCutFill, points: [], label: "Net 86 yd³ cut @ +2.50 ft"),
             ],
             annotations: [
                Annotation(position: Vector3(4, 0, 3), text: "Low spot — pools after rain", category: .issue),
                Annotation(position: Vector3(12, 0, 9), text: "Tie into existing patio grade", category: .todo),
             ]),
        Spec(name: "Maple St. — Kitchen", type: .interior, passes: 2,
             span: (4.5, 4.4, 2.7),
             measurements: [
                FungibleDomain.Measurement(
                    kind: .area,
                    points: [Vector3(0, 0, 0), Vector3(4.5, 0, 0), Vector3(4.5, 0, 4.4), Vector3(0, 0, 4.4)],
                    label: "Floor area"),
                FungibleDomain.Measurement(kind: .distance, points: [Vector3(0, 0, 0), Vector3(4.5, 0, 0)], label: "North wall"),
             ],
             annotations: [
                Annotation(position: Vector3(1, 0, 1), text: "Relocate outlet to this wall", category: .spec),
             ]),
        Spec(name: "Ceramic Vase", type: .object, passes: 1,
             span: (0.2, 0.2, 0.285),
             measurements: [
                FungibleDomain.Measurement(kind: .distance, points: [Vector3(0, 0, 0), Vector3(0, 0.284, 0)], label: "Height"),
             ],
             annotations: []),
    ]

    private static func seed(_ spec: Spec, into store: any ScanStore) async throws {
        var set = ScanSet(name: spec.name, type: spec.type,
                          measurements: spec.measurements, annotations: spec.annotations)
        for i in 0..<spec.passes {
            let id = ScanID()
            let ref = try await store.writeBlob(points: cloud(2_000, span: spec.span, salt: UInt64(i + 1)), for: id)
            set.append(Scan(id: id, deviceModel: "Demo Seed", pointCloud: ref,
                            quality: QualityReport(coverage: 0.9, highConfidenceFraction: 0.82),
                            status: .registered))
        }
        try await store.save(set)
    }

    /// A deterministic synthetic cloud filling the span — enough for a real point
    /// count and a working export, without pretending to be a captured surface.
    private static func cloud(_ n: Int, span: (x: Double, z: Double, h: Double), salt: UInt64) -> [CapturedPoint] {
        var s = 0x9E37_79B9_7F4A_7C15 ^ salt
        func rnd() -> Double {
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(s >> 11) / Double(UInt64(1) << 53)
        }
        var pts: [CapturedPoint] = []
        pts.reserveCapacity(n)
        for _ in 0..<n {
            let p = Vector3(rnd() * span.x, (rnd() - 0.5) * span.h, rnd() * span.z)
            pts.append(CapturedPoint(position: p, confidence: rnd() > 0.2 ? .high : .medium))
        }
        return pts
    }
}
#endif
