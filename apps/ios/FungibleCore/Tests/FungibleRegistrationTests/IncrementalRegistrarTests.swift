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

    func testPosePriorEnablesRegistrationBeyondICPGate() async throws {
        // Real ICP this time. The second scan sits 5 m away — far beyond the
        // 1 m correspondence gate — so registration from identity MUST fail;
        // an ARKit-style pose prior near the truth must recover it exactly.
        var pts: [Vector3] = []
        for x in 0..<4 { for y in 0..<3 { for z in 0..<3 {
            pts.append(Vector3(Double(x) * 0.3, Double(y) * 0.3, Double(z) * 0.3))
        }}}
        let truth = Transform(translation: Vector3(5, 0, 0))
        let target = pts.map { truth.apply(to: $0) }

        let reg = IncrementalRegistrar(
            coarse: PassthroughCoarseAligner(), fine: ICPFineAligner(), optimizer: ChainPoseGraphOptimizer())

        var set = ScanSet(name: "Prior Site")
        let a = Scan(); let b = Scan()
        set.append(a); set.append(b)
        _ = try await reg.register(newScan: a.id, samples: PointSample(points: target), against: nil, in: &set)

        var withoutPrior = set
        do {
            _ = try await reg.register(
                newScan: b.id, samples: PointSample(points: pts),
                against: (id: a.id, samples: PointSample(points: target)), in: &withoutPrior)
            XCTFail("expected insufficientOverlap when seeding from identity")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .insufficientOverlap)
        }

        let prior = Transform(translation: Vector3(4.9, 0.05, -0.05))
        let result = try await reg.register(
            newScan: b.id, samples: PointSample(points: pts),
            against: (id: a.id, samples: PointSample(points: target)), prior: prior, in: &set)

        XCTAssertGreaterThan(result?.fitness ?? 0, 0.99)
        XCTAssertEqual(set.scan(b.id)?.pose.translation.x ?? 0, 5, accuracy: 1e-3)
    }

    func testSubmapNeighborsAddRedundantConstraints() async throws {
        // Chain a–b–c, then register c while supplying neighbor samples: the
        // submap selector finds a (two hops via b) and the registrar adds a
        // redundant a→c edge tagged .submap alongside the sequential one.
        var set = ScanSet(name: "Submap Site")
        let a = Scan(); let b = Scan(); let c = Scan()
        set.append(a); set.append(b); set.append(c)
        let reg = registrar(fineTransform: Transform(translation: Vector3(0, 0, 1)))
        let empty = PointSample(points: [])

        _ = try await reg.register(newScan: a.id, samples: empty, against: nil, in: &set)
        _ = try await reg.register(newScan: b.id, samples: empty, against: (id: a.id, samples: empty), in: &set)
        _ = try await reg.register(
            newScan: c.id, samples: empty, against: (id: b.id, samples: empty),
            neighborSamples: { _ in empty }, in: &set)

        let submapEdges = set.poseGraph.constraints.filter { $0.kind == .submap }
        XCTAssertEqual(submapEdges.count, 1)
        XCTAssertEqual(submapEdges.first?.from, a.id)
        XCTAssertEqual(submapEdges.first?.to, c.id)
        XCTAssertEqual(set.poseGraph.constraints.filter { $0.kind == .sequential }.count, 2)
    }

    func testNeighborsWithoutSamplesAreSkipped() async throws {
        // Default neighborSamples returns nil → the graph stays a pure chain.
        var set = ScanSet(name: "Chain Site")
        let a = Scan(); let b = Scan(); let c = Scan()
        set.append(a); set.append(b); set.append(c)
        let reg = registrar(fineTransform: Transform(translation: Vector3(0, 0, 1)))
        let empty = PointSample(points: [])

        _ = try await reg.register(newScan: a.id, samples: empty, against: nil, in: &set)
        _ = try await reg.register(newScan: b.id, samples: empty, against: (id: a.id, samples: empty), in: &set)
        _ = try await reg.register(newScan: c.id, samples: empty, against: (id: b.id, samples: empty), in: &set)

        XCTAssertTrue(set.poseGraph.constraints.allSatisfy { $0.kind == .sequential })
        XCTAssertEqual(set.poseGraph.constraints.count, 2)
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
