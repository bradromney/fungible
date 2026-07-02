import Foundation
import FungibleDomain

// A dependency-free baseline pose-graph "optimizer": it composes relative-pose
// constraints outward from a root via breadth-first traversal, assigning each
// scan a global pose. It does NOT do least-squares loop-closure correction —
// use GaussNewtonPoseGraphOptimizer for that (it seeds itself from this
// baseline). This remains the fast exact answer for drift-free chains and the
// seed for the real optimizer.
public struct ChainPoseGraphOptimizer: PoseGraphOptimizer {
    public init() {}

    public func optimize(_ graph: PoseGraph) async throws -> [ScanID: Transform] {
        // Adjacency: node -> [(neighbor, transform mapping neighbor's frame into node's frame)].
        var adjacency: [ScanID: [(ScanID, Transform)]] = [:]
        for node in graph.nodes { adjacency[node] = [] }
        for c in graph.constraints {
            // Stored edge: relativePose maps `to`'s frame into `from`'s frame.
            adjacency[c.from, default: []].append((c.to, c.relativePose))
            adjacency[c.to, default: []].append((c.from, c.relativePose.inverse()))
        }

        var poses: [ScanID: Transform] = [:]
        // Each connected component is rooted at its first-seen node (identity).
        for start in graph.nodes where poses[start] == nil {
            poses[start] = .identity
            var queue = [start]
            var head = 0
            while head < queue.count {
                let current = queue[head]; head += 1
                let currentPose = poses[current]!
                for (neighbor, edge) in adjacency[current] ?? [] where poses[neighbor] == nil {
                    // pose(neighbor) = pose(current) ∘ (neighbor → current)
                    poses[neighbor] = currentPose.composed(with: edge)
                    queue.append(neighbor)
                }
            }
        }
        return poses
    }
}
