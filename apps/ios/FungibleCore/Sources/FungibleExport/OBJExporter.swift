import Foundation
import FungibleDomain

// Wavefront OBJ writer for triangle meshes — the universal mesh interchange
// format (read by Blender, MeshLab, CloudCompare, SketchUp, every 3D tool).
// Pure Swift. Emits vertices (with optional vertex colors, the widely-read
// extended `v x y z r g b` form), optional normals, and 1-indexed faces. glTF/
// GLB and USDZ are the next mesh formats (USDZ is native via ModelIO on-device).
public struct OBJExporter {
    public init() {}

    public func data(for mesh: TriangleMesh) -> Data {
        Data(string(for: mesh).utf8)
    }

    public func string(for mesh: TriangleMesh) -> String {
        var out = "# Fungible OBJ export\n"
        let withColors = mesh.hasColors
        let withNormals = mesh.hasNormals

        for (i, v) in mesh.vertices.enumerated() {
            if withColors, let c = mesh.colors?[i] {
                out += "v \(v.x) \(v.y) \(v.z) \(c.x) \(c.y) \(c.z)\n"
            } else {
                out += "v \(v.x) \(v.y) \(v.z)\n"
            }
        }

        if withNormals {
            for n in mesh.normals { out += "vn \(n.x) \(n.y) \(n.z)\n" }
        }

        var t = 0
        while t + 2 < mesh.indices.count {
            // OBJ is 1-indexed.
            let a = mesh.indices[t] + 1
            let b = mesh.indices[t + 1] + 1
            let c = mesh.indices[t + 2] + 1
            if withNormals {
                out += "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n"
            } else {
                out += "f \(a) \(b) \(c)\n"
            }
            t += 3
        }
        return out
    }
}
