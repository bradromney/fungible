import XCTest
@testable import FungibleDomain

final class ScanSetTests: XCTestCase {
    func testAppendHasNoScanCeiling() {
        // ADR-0005: a set grows without limit. Push well past the incumbent's
        // 10-scan cap and confirm every scan is retained and graphed.
        var set = ScanSet(name: "Big Site")
        for _ in 0..<250 {
            set.append(Scan())
        }
        XCTAssertEqual(set.scanCount, 250)
        XCTAssertEqual(set.poseGraph.nodes.count, 250)
    }

    func testCoverageAveragesAcrossScans() {
        var set = ScanSet()
        set.append(Scan(quality: QualityReport(coverage: 0.4)))
        set.append(Scan(quality: QualityReport(coverage: 0.8)))
        XCTAssertEqual(set.coverage, 0.6, accuracy: 1e-9)
    }

    func testIsCompleteRequiresRegionOfInterest() {
        var set = ScanSet()
        set.append(Scan(quality: QualityReport(coverage: 1.0)))
        XCTAssertFalse(set.isComplete, "No ROI means completeness is undefined → false")

        let roi = RegionOfInterest(
            bounds: BoundingBox(min: .zero, max: Vector3(10, 5, 10)),
            completionThreshold: 0.9
        )
        set.regionOfInterest = roi
        XCTAssertTrue(set.isComplete)
    }

    func testPoseGraphNeighborhoodLookup() {
        let a = ScanID(), b = ScanID(), c = ScanID()
        var graph = PoseGraph()
        graph.addConstraint(PoseConstraint(from: a, to: b, relativePose: .identity))
        graph.addConstraint(PoseConstraint(from: b, to: c, relativePose: .identity, kind: .loopClosure))
        XCTAssertEqual(graph.constraints(touching: b).count, 2)
        XCTAssertEqual(graph.constraints(touching: a).count, 1)
        XCTAssertTrue(graph.hasLoopClosures)
    }

    func testMeasurementPolylineLength() {
        let m = Measurement(kind: .distance, points: [Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(3, 0, 4)])
        XCTAssertEqual(m.polylineLength, 7, accuracy: 1e-9)
    }

    func testScanSetCodableRoundTrip() throws {
        var set = ScanSet(name: "Codable Site")
        set.append(Scan(deviceModel: "iPhone16,1"))
        let data = try JSONEncoder().encode(set)
        let decoded = try JSONDecoder().decode(ScanSet.self, from: data)
        XCTAssertEqual(decoded.name, "Codable Site")
        XCTAssertEqual(decoded.scanCount, 1)
        XCTAssertEqual(decoded.id, set.id)
    }

    // MARK: - Editing & persisted UI state (ADR-0009)

    func testUpsertMeasurementReplacesByID() {
        var set = ScanSet()
        let m = Measurement(kind: .distance, points: [.zero, Vector3(1, 0, 0)])
        set.upsert(m)
        set.upsert(m)   // same id → replace, never duplicate
        XCTAssertEqual(set.measurements.count, 1)

        var edited = m
        edited.points = [.zero, Vector3(2, 0, 0)]
        set.upsert(edited)
        XCTAssertEqual(set.measurements.count, 1)
        XCTAssertEqual(set.measurements.first?.polylineLength, 2, accuracy: 1e-9)

        set.removeMeasurement(m.id)
        XCTAssertTrue(set.measurements.isEmpty)
    }

    func testUpsertAnnotationCarriesCategoryAndRemoves() {
        var set = ScanSet()
        let a = Annotation(position: .zero, text: "Drainage", category: .issue)
        set.upsert(a)
        set.upsert(a)
        XCTAssertEqual(set.annotations.count, 1)
        XCTAssertEqual(set.annotations.first?.category, .issue)
        set.removeAnnotation(a.id)
        XCTAssertTrue(set.annotations.isEmpty)
    }

    func testTypeAndShareRoundTrip() throws {
        let share = ShareSettings(isEnabled: true, allowDownload: true, expiry: .month, linkSlug: "7f3a")
        let set = ScanSet(name: "S", type: .object, share: share)
        let decoded = try JSONDecoder().decode(ScanSet.self, from: JSONEncoder().encode(set))
        XCTAssertEqual(decoded.type, .object)
        XCTAssertEqual(decoded.share, share)
    }

    /// A set written by an older build (no `type` / `share` / annotation
    /// `category`) must still load, defaulting the new fields (ADR-0009).
    func testTolerantDecodeDefaultsNewFields() throws {
        let set = ScanSet(
            name: "Legacy",
            type: .interior,
            annotations: [Annotation(position: .zero, text: "x", category: .issue)],
            share: ShareSettings(isEnabled: true)
        )
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as! [String: Any]
        obj.removeValue(forKey: "type")
        obj.removeValue(forKey: "share")
        if var anns = obj["annotations"] as? [[String: Any]], !anns.isEmpty {
            anns[0].removeValue(forKey: "category")
            obj["annotations"] = anns
        }
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(ScanSet.self, from: stripped)
        XCTAssertEqual(decoded.type, .site)                        // defaulted
        XCTAssertFalse(decoded.share.isEnabled)                    // defaulted
        XCTAssertEqual(decoded.annotations.first?.category, .note) // defaulted
    }
}
