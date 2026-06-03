import XCTest
import FungibleDomain
@testable import FungibleRegistration

// Stub aligners let us prove the orchestration control flow without the real
// (bridged) registration engines.
private struct StubCoarse: CoarseAligner {
    func align(source: PointSample, target: PointSample) async throws -> RegistrationResult {
        RegistrationResult(transform: .identity, fitness: 0.5, inlierRMSE: 0.1)
    }
}

private struct StubFine: FineAligner {
    let transform: Transform
    func refine(source: PointSample, target: PointSample, initial: Transform) async throws -> RegistrationResult {
        RegistrationResult(transform: transform, fitness: 0.9, inlierRMSE: 0.01)
    }
}

final class IncrementalRegistrarTests: XCTestCase {
    private func registrar(fineTransform: Transform) -> IncrementalRegistrar {
        IncrementalRegistrar(coarse: StubCoarse(),
                             fine: StubFine(transform: fineTransform),
                             optimizer: ChainPoseGraphOptimizer())
    }

    func testFirstScanAnchorsAtIdentity() async throws {
        var set = ScanSet(name: "Site")
        let a = Scan()
        set.append(a)

        let result = try await registrar(fineTransform: .identity)
            .register(newScan: a.id, samples: PointSample(points: []), against: nil, in: &set)

        XCTAssertNil(result, "first scan has no constraint")
        XCTAssertEqual(set.scan(a.id)?.pose, .identity)
        XCTAssertEqual(set.poseGraph.nodes.count, 1)
    }

    func testSecondScanGetsRegisteredPoseAndEdge() async throws {
        var set = ScanSet(name: "Site")
        let a = Scan()
        let b = Scan()
        set.append(a)
        set.append(b)

        // First scan anchors at origin.
        _ = try await registrar(fineTransform: .identity)
            .register(newScan: a.id, samples: PointSample(points: []), against: nil, in: &set)

        // Second scan aligns +1 in z relative to the first.
        let offset = Transform(translation: Vector3(0, 0, 1))
        let result = try await registrar(fineTransform: offset)
            .register(newScan: b.id,
                      samples: PointSample(points: []),
                      against: (id: a.id, samples: PointSample(points: [])),
                      in: &set)

        XCTAssertEqual(result?.fitness ?? 0, 0.9, accuracy: 1e-9)
        XCTAssertEqual(set.poseGraph.constraints.count, 1)
        // After optimization the second scan sits at the composed offset.
        XCTAssertEqual(set.scan(b.id)?.pose.translation.z ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(set.scan(a.id)?.pose, .identity)
    }

    func testManyScansStayBoundedToOneEdgePerScan() async throws {
        // Sanity: registering well past the incumbent's 10-scan cap keeps the
        // graph linear (one sequential edge per new scan), not O(N²).
        var set = ScanSet(name: "Big Site")
        let reg = registrar(fineTransform: Transform(translation: Vector3(0, 0, 1)))

        var previousID: ScanID?
        var previousSamples = PointSample(points: [])
        for _ in 0..<50 {
            let scan = Scan()
            set.append(scan)
            let prev = previousID.map { (id: $0, samples: previousSamples) }
            _ = try await reg.register(newScan: scan.id, samples: PointSample(points: []), against: prev, in: &set)
            previousID = scan.id
            previousSamples = PointSample(points: [])
        }

        XCTAssertEqual(set.scanCount, 50)
        XCTAssertEqual(set.poseGraph.constraints.count, 49, "linear chain, not all-pairs")
        // Last scan accumulated 49 unit z-steps via chain composition.
        XCTAssertEqual(set.scans.last?.pose.translation.z ?? 0, 49, accuracy: 1e-6)
    }
}
