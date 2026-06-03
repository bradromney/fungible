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
}
