import XCTest
import FungibleDomain
@testable import FungibleRegistration

final class GaussNewtonPoseGraphOptimizerTests: XCTestCase {
    private func t(_ x: Double, _ y: Double, _ z: Double) -> Transform {
        Transform(translation: Vector3(x, y, z))
    }

    /// Information-weighted total squared residual — the quantity GN minimizes.
    private func cost(_ poses: [ScanID: Transform], _ graph: PoseGraph) -> Double {
        var total = 0.0
        for c in graph.constraints {
            let predicted = (poses[c.from] ?? .identity).composed(with: c.relativePose)
            let error = predicted.inverse().composed(with: poses[c.to] ?? .identity)
            let rot = PoseGraphMath.logRot(error.rotation)
            let squared = error.translation.dot(error.translation) + rot.dot(rot)
            total += c.information * squared
        }
        return total
    }

    /// A square loop with 0.2 m of drift on one leg and a loop-closure edge
    /// carrying the truth. Node order: a → b → c → d, closure d → a.
    private func driftedSquare(closureInformation: Double = 1.0) -> (PoseGraph, [ScanID]) {
        let ids = (0..<4).map { _ in ScanID() }
        var graph = PoseGraph()
        for id in ids { graph.addNode(id) }
        graph.addConstraint(PoseConstraint(from: ids[0], to: ids[1], relativePose: t(1, 0, 0), kind: .sequential))
        graph.addConstraint(PoseConstraint(from: ids[1], to: ids[2], relativePose: t(0, 0, 1.2), kind: .sequential))
        graph.addConstraint(PoseConstraint(from: ids[2], to: ids[3], relativePose: t(-1, 0, 0), kind: .sequential))
        graph.addConstraint(PoseConstraint(
            from: ids[3], to: ids[0], relativePose: t(0, 0, -1),
            information: closureInformation, kind: .loopClosure))
        return (graph, ids)
    }

    func testLoopClosureDistributesDrift() async throws {
        let (graph, ids) = driftedSquare()

        let chain = try await ChainPoseGraphOptimizer().optimize(graph)
        let chainCost = cost(chain, graph)
        XCTAssertEqual(chainCost, 0.04, accuracy: 1e-9, "chain leaves the whole 0.2² on the closure")

        let optimized = try await GaussNewtonPoseGraphOptimizer().optimize(graph)
        let gnCost = cost(optimized, graph)

        // Validated against the Python reference implementation: the SE(3)
        // optimum (rotation absorbs part of the drift) reaches ≈0.008, at or
        // below the translation-only optimum of 0.01.
        XCTAssertLessThanOrEqual(gnCost, 0.0101)
        let dz = optimized[ids[3]]?.translation.z ?? 0
        XCTAssertLessThan(dz, 1.1, "closure must pull d back from the chain's drifted 1.2")
        XCTAssertGreaterThan(dz, 0.95)
        // Gauge: the first node stays anchored.
        XCTAssertEqual(optimized[ids[0]], .identity)
    }

    func testInformationWeightingPullsTowardTheConfidentEdge() async throws {
        let (weak, weakIDs) = driftedSquare(closureInformation: 1)
        let (strong, strongIDs) = driftedSquare(closureInformation: 100)

        let weakOpt = try await GaussNewtonPoseGraphOptimizer().optimize(weak)
        let strongOpt = try await GaussNewtonPoseGraphOptimizer().optimize(strong)

        let weakDZ = weakOpt[weakIDs[3]]?.translation.z ?? 0
        let strongDZ = strongOpt[strongIDs[3]]?.translation.z ?? 0
        // The closure says the loop height is 1.0; trusting it 100× must land
        // d much closer to 1.0 than the evenly-weighted solution does.
        XCTAssertLessThan(abs(strongDZ - 1.0), abs(weakDZ - 1.0))
        XCTAssertEqual(strongDZ, 1.0, accuracy: 0.02)
    }

    func testDisagreeingRedundantEdgesSettleBetween() async throws {
        // Two nodes, two constraints that disagree: GN must settle between
        // them; the chain baseline just takes the first.
        let a = ScanID(), b = ScanID()
        var graph = PoseGraph()
        graph.addNode(a); graph.addNode(b)
        let yaw90 = PoseGraphMath.expRot(Vector3(0, Double.pi / 2, 0))
        let yawMore = PoseGraphMath.expRot(Vector3(0, Double.pi / 2 + 0.1, 0))
        graph.addConstraint(PoseConstraint(
            from: a, to: b, relativePose: Transform(rotation: yaw90, translation: Vector3(1, 0, 0)), kind: .sequential))
        graph.addConstraint(PoseConstraint(
            from: a, to: b, relativePose: Transform(rotation: yawMore, translation: Vector3(1.05, 0, 0)), kind: .submap))

        let optimized = try await GaussNewtonPoseGraphOptimizer().optimize(graph)
        let pose = try XCTUnwrap(optimized[b])
        let yaw = PoseGraphMath.logRot(pose.rotation).y
        XCTAssertGreaterThan(yaw, Double.pi / 2 - 1e-6)
        XCTAssertLessThan(yaw, Double.pi / 2 + 0.1 + 1e-6)
        XCTAssertEqual(pose.translation.x, 1.025, accuracy: 0.02)

        let chainCost = cost(try await ChainPoseGraphOptimizer().optimize(graph), graph)
        XCTAssertLessThan(cost(optimized, graph), chainCost)
    }

    func testPureChainIsReturnedUntouched() async throws {
        // A tree has an exact solution; GN must return the chain result as-is.
        let ids = (0..<3).map { _ in ScanID() }
        var graph = PoseGraph()
        for id in ids { graph.addNode(id) }
        graph.addConstraint(PoseConstraint(from: ids[0], to: ids[1], relativePose: t(1, 0, 0), kind: .sequential))
        graph.addConstraint(PoseConstraint(from: ids[1], to: ids[2], relativePose: t(0, 0, 1), kind: .sequential))

        let chain = try await ChainPoseGraphOptimizer().optimize(graph)
        let gn = try await GaussNewtonPoseGraphOptimizer().optimize(graph)
        XCTAssertEqual(gn, chain)
    }

    func testRotationExpLogRoundTrip() {
        for v in [Vector3.zero, Vector3(0.1, -0.2, 0.3), Vector3(0, Double.pi / 2, 0), Vector3(2.5, 0.5, -1)] {
            let back = PoseGraphMath.logRot(PoseGraphMath.expRot(v))
            XCTAssertEqual(back.x, v.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, v.y, accuracy: 1e-9)
            XCTAssertEqual(back.z, v.z, accuracy: 1e-9)
        }
    }

    func testSolverSolvesAKnownSystem() {
        // 2x + y = 5; x + 3y = 10 → x = 1, y = 3.
        let solution = GaussNewtonPoseGraphOptimizer.solve([[2, 1], [1, 3]], [5, 10])
        XCTAssertEqual(solution?[0] ?? 0, 1, accuracy: 1e-12)
        XCTAssertEqual(solution?[1] ?? 0, 3, accuracy: 1e-12)
        // Singular system → nil, not garbage.
        XCTAssertNil(GaussNewtonPoseGraphOptimizer.solve([[1, 1], [1, 1]], [1, 2]))
    }
}
