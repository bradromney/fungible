import Foundation

// A triangle mesh — the deliverable for general 3D modeling and AEC use cases
// (ADR-0007), distinct from a point cloud. ARKit scene reconstruction
// (ARMeshAnchor) already yields meshes directly, so we can export them without
// surface reconstruction; reconstructing a mesh *from* a raw point cloud
// (Poisson/ball-pivoting) is the heavier, cloud-worker path. Y-up, matching the
// OBJ/glTF/USDZ convention (no plan-view remap — that's only for survey formats).
public struct TriangleMesh: Equatable, Sendable, Codable {
    public var vertices: [Vector3]
    /// Per-vertex normals; empty if absent (must match `vertices` count if present).
    public var normals: [Vector3]
    /// Optional per-vertex RGB in [0,1]; nil if absent.
    public var colors: [Vector3]?
    /// Flat triangle index list (length is a multiple of 3, 0-based).
    public var indices: [Int]

    public init(vertices: [Vector3] = [], normals: [Vector3] = [], colors: [Vector3]? = nil, indices: [Int] = []) {
        self.vertices = vertices
        self.normals = normals
        self.colors = colors
        self.indices = indices
    }

    public var triangleCount: Int { indices.count / 3 }
    public var hasNormals: Bool { !normals.isEmpty && normals.count == vertices.count }
    public var hasColors: Bool { (colors?.count ?? 0) == vertices.count && !vertices.isEmpty }

    /// True if the index buffer is well-formed (multiple of 3, all in range).
    public var isValid: Bool {
        guard indices.count % 3 == 0 else { return false }
        return indices.allSatisfy { $0 >= 0 && $0 < vertices.count }
    }
}
