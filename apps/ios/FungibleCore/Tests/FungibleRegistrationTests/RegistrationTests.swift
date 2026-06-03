import XCTest
import FungibleDomain
@testable import FungibleRegistration

final class ChainPoseGraphOptimizerTests: XCTestCase {
    func testChainComposesTranslationsOutward() async throws {
        let a = ScanID(), b = ScanID(), c = ScanID()
        var graph = PoseGraph()
        // Each relativePose maps the `to` scan's frame +1 in z within `from`.
        graph.addConstraint(PoseConstraint(from: a, to: b, relativePose: Transform(translation: Vector3(0, 0, 1))))
        graph.addConstraint(PoseConstraint(from: b, to: c, relativePose: Transform(translation: Vector3(0, 0, 1))))

        let poses = try await ChainPoseGraphOptimizer().optimize(graph)
        XCTAssertEqual(poses[a]?.translation, Vector3(0, 0, 0))
        XCTAssertEqual(poses[b]?.translation.z ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(poses[c]?.translation.z ?? 0, 2, accuracy: 1e-9)
    }

    func testIsolatedNodesGetIdentity() async throws {
        let a = ScanID(), b = ScanID()
        let graph = PoseGraph(nodes: [a, b], constraints: [])
        let poses = try await ChainPoseGraphOptimizer().optimize(graph)
        XCTAssertEqual(poses[a], .identity)
        XCTAssertEqual(poses[b], .identity)
    }

    func testReverseEdgeDirectionUsesInverse() async throws {
        let a = ScanID(), b = ScanID()
        // Edge stored from a→b, but b is the root we reach a from: pose(a) must
        // be the inverse offset.
        var graph = PoseGraph()
        graph.addConstraint(PoseConstraint(from: a, to: b, relativePose: Transform(translation: Vector3(0, 0, 5))))
        let poses = try await ChainPoseGraphOptimizer().optimize(graph)
        // Root is `a` (first node), so b is +5; verify composition consistency:
        // pose(b) ∘ inverse(rel) == pose(a).
        let reconstructedA = poses[b]!.composed(with: graph.constraints[0].relativePose.inverse())
        XCTAssertEqual(reconstructedA.translation.z, poses[a]!.translation.z, accuracy: 1e-9)
    }
}

final class SubmapSelectorTests: XCTestCase {
    /// Build a simple chain n0 - n1 - n2 - ... and return the ids.
    private func chain(_ count: Int) -> (PoseGraph, [ScanID]) {
        let ids = (0..<count).map { _ in ScanID() }
        var graph = PoseGraph()
        for i in 1..<count {
            graph.addConstraint(PoseConstraint(from: ids[i - 1], to: ids[i], relativePose: .identity))
        }
        return (graph, ids)
    }

    func testNeighborhoodRespectsHopLimit() {
        let (graph, ids) = chain(6)
        let selector = SubmapSelector(maxHops: 2, maxNeighbors: 10)
        let nb = selector.neighborhood(of: ids[0], in: graph)
        // From an end node, 2 hops reach ids[1] and ids[2] only.
        XCTAssertEqual(Set(nb), Set([ids[1], ids[2]]))
    }

    func testNeighborhoodRespectsMaxNeighbors() {
        let (graph, ids) = chain(10)
        let selector = SubmapSelector(maxHops: 9, maxNeighbors: 3)
        let nb = selector.neighborhood(of: ids[0], in: graph)
        XCTAssertEqual(nb.count, 3)
    }

    func testExcludesSelf() {
        let (graph, ids) = chain(3)
        let nb = SubmapSelector().neighborhood(of: ids[1], in: graph)
        XCTAssertFalse(nb.contains(ids[1]))
    }
}
