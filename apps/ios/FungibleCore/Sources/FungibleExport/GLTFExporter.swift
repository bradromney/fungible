import Foundation
import FungibleDomain

// glTF 2.0 mesh export — the modern, web-native 3D interchange (three.js, Blender,
// Babylon, model-viewer, AR Quick Look via USDZ conversion). Emits a
// self-contained `.gltf` (JSON) with a single embedded base64 buffer holding
// POSITION (+ optional NORMAL, COLOR_0) and UNSIGNED_INT indices. Y-up,
// right-handed — matching both our frame and glTF's, so no remap. Pure Swift +
// Foundation; complements OBJExporter for the 3D/AEC/interop use cases (ADR-0007).
public struct GLTFExporter {
    public init() {}

    public func data(for mesh: TriangleMesh) -> Data {
        // 1) Pack the binary blob: positions, [normals], [colors], indices.
        var blob = Data()
        let withNormals = mesh.hasNormals
        let withColors = mesh.hasColors

        let positionOffset = blob.count
        for v in mesh.vertices { appendVec3(&blob, v) }
        let positionLen = blob.count - positionOffset

        var normalOffset = 0, normalLen = 0
        if withNormals {
            normalOffset = blob.count
            for n in mesh.normals { appendVec3(&blob, n) }
            normalLen = blob.count - normalOffset
        }

        var colorOffset = 0, colorLen = 0
        if withColors, let colors = mesh.colors {
            colorOffset = blob.count
            for c in colors { appendVec3(&blob, c) }
            colorLen = blob.count - colorOffset
        }

        let indexOffset = blob.count
        for i in mesh.indices { appendU32(&blob, UInt32(i)) }
        let indexLen = blob.count - indexOffset

        // 2) bufferViews + accessors.
        var bufferViews: [BufferView] = []
        var accessors: [Accessor] = []
        var attributes: [String: Int] = [:]

        let (lo, hi) = bounds(mesh.vertices)
        bufferViews.append(BufferView(buffer: 0, byteOffset: positionOffset, byteLength: positionLen, target: 34962))
        attributes["POSITION"] = accessors.count
        accessors.append(Accessor(bufferView: bufferViews.count - 1, componentType: 5126,
                                   count: mesh.vertices.count, type: "VEC3", min: lo, max: hi))

        if withNormals {
            bufferViews.append(BufferView(buffer: 0, byteOffset: normalOffset, byteLength: normalLen, target: 34962))
            attributes["NORMAL"] = accessors.count
            accessors.append(Accessor(bufferView: bufferViews.count - 1, componentType: 5126,
                                       count: mesh.vertices.count, type: "VEC3", min: nil, max: nil))
        }
        if withColors {
            bufferViews.append(BufferView(buffer: 0, byteOffset: colorOffset, byteLength: colorLen, target: 34962))
            attributes["COLOR_0"] = accessors.count
            accessors.append(Accessor(bufferView: bufferViews.count - 1, componentType: 5126,
                                       count: mesh.vertices.count, type: "VEC3", min: nil, max: nil))
        }

        bufferViews.append(BufferView(buffer: 0, byteOffset: indexOffset, byteLength: indexLen, target: 34963))
        let indicesAccessor = accessors.count
        accessors.append(Accessor(bufferView: bufferViews.count - 1, componentType: 5125,
                                   count: mesh.indices.count, type: "SCALAR", min: nil, max: nil))

        // 3) Assemble the glTF JSON with the buffer as a data URI.
        let uri = "data:application/octet-stream;base64," + blob.base64EncodedString()
        let doc = GLTF(
            asset: Asset(version: "2.0", generator: "Fungible"),
            scene: 0,
            scenes: [SceneNode(nodes: [0])],
            nodes: [Node(mesh: 0)],
            meshes: [Mesh(primitives: [Primitive(attributes: attributes, indices: indicesAccessor, mode: 4)])],
            buffers: [Buffer(byteLength: blob.count, uri: uri)],
            bufferViews: bufferViews,
            accessors: accessors
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(doc)) ?? Data()
    }

    private func bounds(_ verts: [Vector3]) -> ([Double], [Double]) {
        guard let first = verts.first else { return ([0, 0, 0], [0, 0, 0]) }
        var lo = first, hi = first
        for v in verts {
            lo = Vector3(min(lo.x, v.x), min(lo.y, v.y), min(lo.z, v.z))
            hi = Vector3(max(hi.x, v.x), max(hi.y, v.y), max(hi.z, v.z))
        }
        return ([lo.x, lo.y, lo.z], [hi.x, hi.y, hi.z])
    }

    private func appendVec3(_ d: inout Data, _ v: Vector3) {
        appendF32(&d, Float(v.x)); appendF32(&d, Float(v.y)); appendF32(&d, Float(v.z))
    }
    private func appendF32(_ d: inout Data, _ v: Float) {
        var le = v.bitPattern.littleEndian; withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
    private func appendU32(_ d: inout Data, _ v: UInt32) {
        var le = v.littleEndian; withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
}

// MARK: - glTF 2.0 JSON model (minimal). Optional min/max are omitted when nil.

private struct GLTF: Encodable {
    let asset: Asset
    let scene: Int
    let scenes: [SceneNode]
    let nodes: [Node]
    let meshes: [Mesh]
    let buffers: [Buffer]
    let bufferViews: [BufferView]
    let accessors: [Accessor]
}
private struct Asset: Encodable { let version: String; let generator: String }
private struct SceneNode: Encodable { let nodes: [Int] }
private struct Node: Encodable { let mesh: Int }
private struct Mesh: Encodable { let primitives: [Primitive] }
private struct Primitive: Encodable { let attributes: [String: Int]; let indices: Int; let mode: Int }
private struct Buffer: Encodable { let byteLength: Int; let uri: String }
private struct BufferView: Encodable { let buffer: Int; let byteOffset: Int; let byteLength: Int; let target: Int }
private struct Accessor: Encodable {
    let bufferView: Int
    let componentType: Int
    let count: Int
    let type: String
    let min: [Double]?
    let max: [Double]?
}
