import XCTest
import FungibleDomain
@testable import FungibleRegistration

final class ICPFineAlignerTests: XCTestCase {
    // A spread, distinctive grid so nearest-neighbour correspondences are clean.
    private func gridCloud() -> [Vector3] {
        var pts: [Vector3] = []
        for x in 0..<4 { for y in 0..<3 { for z in 0..<3 {
            pts.append(Vector3(Double(x) * 0.3, Double(y) * 0.3, Double(z) * 0.3))
        }}}
        return pts
    }

    private func sample(_ pts: [Vector3]) -> PointSample { PointSample(points: pts) }

    func testConvergesOnSmallRigidMotionFromIdentity() async throws {
        let src = gridCloud()
        let half = (3.0 * Double.pi / 180.0) / 2.0 // ~3° about y
        let q = Quaternion(w: cos(half), x: 0, y: sin(half), z: 0).normalized()
        let truth = Transform(rotation: q, translation: Vector3(0.05, 0, 0.02))
        let tgt = src.map { truth.apply(to: $0) }

        let result = try await ICPFineAligner().refine(source: sample(src), target: sample(tgt), initial: .identity)

        XCTAssertEqual(result.fitness, 1.0, accuracy: 1e-9) // all points matched
        XCTAssertLessThan(result.inlierRMSE, 1e-3)
        // The recovered transform maps source onto target.
        for p in src {
            XCTAssertLessThan(result.transform.apply(to: p).distance(to: truth.apply(to: p)), 1e-2)
        }
    }

    func testRefinesFromAGoodInitialGuessToNearZero() async throws {
        let src = gridCloud()
        let truth = Transform(translation: Vector3(0.1, -0.05, 0.0))
        let tgt = src.map { truth.apply(to: $0) }
        // Initial guess already near truth → ICP should polish to tiny RMSE.
        let result = try await ICPFineAligner().refine(source: sample(src), target: sample(tgt), initial: truth)
        XCTAssertLessThan(result.inlierRMSE, 1e-6)
    }

    func testReportedRMSEMatchesReturnedTransform() async throws {
        let src = gridCloud()
        let half = (5.0 * Double.pi / 180.0) / 2.0
        let q = Quaternion(w: cos(half), x: 0, y: sin(half), z: 0).normalized()
        let truth = Transform(rotation: q, translation: Vector3(0.08, 0.02, -0.04))
        let tgt = src.map { truth.apply(to: $0) }

        let aligner = ICPFineAligner()
        let result = try await aligner.refine(source: sample(src), target: sample(tgt), initial: .identity)

        // Recompute the inlier RMSE directly under the *returned* transform; the
        // reported number must describe that pose, not the previous iteration's.
        var sqSum = 0.0
        var inliers = 0
        for p in src {
            let tp = result.transform.apply(to: p)
            let nearest = tgt.map { tp.distance(to: $0) }.min() ?? .greatestFiniteMagnitude
            if nearest <= aligner.maxCorrespondenceDistance {
                inliers += 1
                sqSum += nearest * nearest
            }
        }
        let recomputed = (sqSum / Double(inliers)).squareRoot()
        XCTAssertEqual(result.inlierRMSE, recomputed, accuracy: 1e-9)
        XCTAssertEqual(result.fitness, Double(inliers) / Double(src.count), accuracy: 1e-9)
    }

    func testRejectsTooFewPoints() async {
        do {
            _ = try await ICPFineAligner().refine(
                source: sample([Vector3(0, 0, 0)]), target: sample(gridCloud()), initial: .identity)
            XCTFail("expected notEnoughPoints")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .notEnoughPoints)
        }
    }

    func testEndToEndWithIncrementalRegistrar() async throws {
        // The real pure-Swift pipeline: PassthroughCoarse + ICP fine + chain graph.
        var set = ScanSet(name: "ICP Site")
        let a = Scan(); let b = Scan()
        set.append(a); set.append(b)

        let src = gridCloud()
        let offset = Transform(translation: Vector3(0.1, 0, 0))
        let tgt = src.map { offset.apply(to: $0) }

        let registrar = IncrementalRegistrar(
            coarse: PassthroughCoarseAligner(), fine: ICPFineAligner(), optimizer: ChainPoseGraphOptimizer())

        _ = try await registrar.register(newScan: a.id, samples: sample(src), against: nil, in: &set)
        let result = try await registrar.register(
            newScan: b.id, samples: sample(tgt), against: (id: a.id, samples: sample(src)), in: &set)

        XCTAssertEqual(set.poseGraph.constraints.count, 1)
        XCTAssertGreaterThan(result?.fitness ?? 0, 0.9)
    }
}
