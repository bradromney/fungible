import XCTest
import FungibleDomain
@testable import FungibleRegistration

/// Fine aligner scripted per test: fixed transform + fitness, no geometry.
private struct ScriptedFine: FineAligner {
    var transform: Transform = .identity
    var fitness: Double = 0.9
    func refine(source: PointSample, target: PointSample, initial: Transform) async throws -> RegistrationResult {
        RegistrationResult(transform: transform, fitness: fitness, inlierRMSE: 0.01)
    }
}

final class ProximityLoopCloserTests: XCTestCase {
    private let empty = PointSample(points: [])

    /// Seven scans: 0 at the origin, 1–5 far away, 6 back near the origin —
    /// the shape of a walked loop.
    private func loopedSet() -> ScanSet {
        var set = ScanSet(name: "Loop Site")
        for i in 0..<7 {
            var scan = Scan()
            switch i {
            case 0: scan.pose = .identity
            case 6: scan.pose = Transform(translation: Vector3(0.5, 0, 0))
            default: scan.pose = Transform(translation: Vector3(Double(i) * 10, 0, 0))
            }
            set.append(scan)
        }
        return set
    }

    func testDetectsARevisitAndEmitsALoopClosure() async throws {
        let set = loopedSet()
        let sample = empty
        let closer = ProximityLoopCloser(fine: ScriptedFine(), samples: { _ in sample })

        let closures = try await closer.detectClosures(in: set, newScan: set.scans[6].id)

        XCTAssertEqual(closures.count, 1)
        XCTAssertEqual(closures.first?.from, set.scans[0].id, "only the origin scan is near AND far back in sequence")
        XCTAssertEqual(closures.first?.to, set.scans[6].id)
        XCTAssertEqual(closures.first?.kind, .loopClosure)
    }

    func testNearInSequenceScansAreNotClosures() async throws {
        // Scan 1 is 10 m out; move it next to scan 6 — it's within maxDistance
        // but only 5 positions back with a gap requirement of 6: not a loop.
        var set = loopedSet()
        set.scans[1].pose = Transform(translation: Vector3(0.4, 0, 0))
        let sample = empty
        let closer = ProximityLoopCloser(fine: ScriptedFine(), minSequenceGap: 6, samples: { _ in sample })

        let closures = try await closer.detectClosures(in: set, newScan: set.scans[6].id)
        XCTAssertEqual(closures.map(\.from), [set.scans[0].id])
    }

    func testWeakAlignmentsAreRejected() async throws {
        let set = loopedSet()
        let sample = empty
        let closer = ProximityLoopCloser(
            fine: ScriptedFine(fitness: 0.3), minFitness: 0.5, samples: { _ in sample })
        let closures = try await closer.detectClosures(in: set, newScan: set.scans[6].id)
        XCTAssertTrue(closures.isEmpty, "a bad closure is worse than none")
    }

    func testMissingSamplesAreSkipped() async throws {
        let set = loopedSet()
        let originID = set.scans[0].id
        let sample = empty
        let closer = ProximityLoopCloser(fine: ScriptedFine(), samples: { id in
            id == originID ? nil : sample // candidate's cloud not resident
        })
        let closures = try await closer.detectClosures(in: set, newScan: set.scans[6].id)
        XCTAssertTrue(closures.isEmpty)
    }

    func testRegistrarWiresClosuresIntoTheGraph() async throws {
        // End-to-end: register six scans whose odometry says "didn't move"
        // (identity steps), so every scan sits at the origin — the sixth is a
        // textbook revisit of the first. The registrar must add a .loopClosure
        // edge and still optimize cleanly with the Gauss–Newton back-end.
        var set = ScanSet(name: "Walked Loop")
        let scans = (0..<6).map { _ in Scan() }
        for scan in scans { set.append(scan) }

        let registrar = IncrementalRegistrar(
            coarse: PassthroughCoarseAligner(),
            fine: ScriptedFine(),
            optimizer: GaussNewtonPoseGraphOptimizer(),
            loopCloser: ProximityLoopCloser(fine: ScriptedFine(), minSequenceGap: 4, samples: { _ in PointSample(points: []) })
        )

        var previous: (id: ScanID, samples: PointSample)?
        for scan in scans {
            _ = try await registrar.register(newScan: scan.id, samples: empty, against: previous, in: &set)
            previous = (id: scan.id, samples: empty)
        }

        let closures = set.poseGraph.constraints.filter { $0.kind == .loopClosure }
        XCTAssertFalse(closures.isEmpty, "revisiting the origin must close the loop")
        XCTAssertEqual(closures.last?.to, scans[5].id)
        XCTAssertEqual(set.poseGraph.constraints.filter { $0.kind == .sequential }.count, 5)
        // Consistent identity odometry + identity closures → everyone at origin.
        for scan in set.scans {
            XCTAssertEqual(scan.pose.translation.length, 0, accuracy: 1e-6)
        }
    }
}
