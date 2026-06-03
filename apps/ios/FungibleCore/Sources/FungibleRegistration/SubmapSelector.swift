import Foundation
import FungibleDomain

// The mechanism that removes the scan-count ceiling (ADR-0005). Instead of
// registering a new scan against every prior scan (≈O(N²), the reason incumbents
// cap at ~10), we register it only against a bounded local neighborhood — the
// scans within a few graph hops. Per-scan cost stays roughly constant as a set
// grows. This is pure graph logic; the actual alignment uses the bridged
// CoarseAligner/FineAligner.
public struct SubmapSelector: Sendable {
    /// How many graph hops out to consider "nearby".
    public var maxHops: Int
    /// Hard cap on how many neighbors to register against, nearest first.
    public var maxNeighbors: Int

    public init(maxHops: Int = 2, maxNeighbors: Int = 8) {
        precondition(maxHops >= 1)
        precondition(maxNeighbors >= 1)
        self.maxHops = maxHops
        self.maxNeighbors = maxNeighbors
    }

    /// Scans the given scan should be registered against: the nearest nodes by
    /// graph distance, excluding the scan itself, capped at `maxNeighbors`.
    /// Returned nearest-first (closest hop distance first).
    public func neighborhood(of scan: ScanID, in graph: PoseGraph) -> [ScanID] {
        var adjacency: [ScanID: Set<ScanID>] = [:]
        for c in graph.constraints {
            adjacency[c.from, default: []].insert(c.to)
            adjacency[c.to, default: []].insert(c.from)
        }

        var visited: Set<ScanID> = [scan]
        var result: [ScanID] = []
        var frontier: [ScanID] = [scan]

        for _ in 0..<maxHops {
            var next: [ScanID] = []
            for node in frontier {
                for neighbor in (adjacency[node] ?? []).sorted(by: { $0.rawValue.uuidString < $1.rawValue.uuidString })
                where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    result.append(neighbor)
                    next.append(neighbor)
                    if result.count >= maxNeighbors { return result }
                }
            }
            if next.isEmpty { break }
            frontier = next
        }
        return result
    }
}
