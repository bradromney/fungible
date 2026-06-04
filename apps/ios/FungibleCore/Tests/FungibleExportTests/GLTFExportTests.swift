import XCTest
import FungibleDomain
@testable import FungibleExport

// Decode just the fields we assert on — type-safe, no NSNumber bridging.
private struct GLTFDoc: Decodable {
    struct Asset: Decodable { let version: String }
    struct Buffer: Decodable { let byteLength: Int; let uri: String }
    struct Accessor: Decodable { let type: String; let componentType: Int; let count: Int; let min: [Double]?; let max: [Double]? }
    struct Mesh: Decodable {
        struct Primitive: Decodable { let attributes: [String: Int]; let mode: Int; let indices: Int }
        let primitives: [Primitive]
    }
    let asset: Asset
    let buffers: [Buffer]
    let accessors: [Accessor]
    let meshes: [Mesh]
}

final class GLTFExportTests: XCTestCase {
    private func triangle(colors: Bool = false) -> TriangleMesh {
        TriangleMesh(
            vertices: [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)],
            colors: colors ? [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)] : nil,
            indices: [0, 1, 2]
        )
    }

    private func decode(_ mesh: TriangleMesh) throws -> GLTFDoc {
        try JSONDecoder().decode(GLTFDoc.self, from: GLTFExporter().data(for: mesh))
    }

    func testProducesValidGLTFStructure() throws {
        let doc = try decode(triangle())
        XCTAssertEqual(doc.asset.version, "2.0")
        XCTAssertEqual(doc.meshes.count, 1)
        let prim = doc.meshes[0].primitives[0]
        XCTAssertEqual(prim.mode, 4) // TRIANGLES
        XCTAssertNotNil(prim.attributes["POSITION"])
    }

    func testBufferLengthAndDataURI() throws {
        let data = GLTFExporter().data(for: triangle())
        let doc = try JSONDecoder().decode(GLTFDoc.self, from: data)
        // 3 vertices × 3 floats × 4 bytes + 3 indices × 4 bytes = 48.
        XCTAssertEqual(doc.buffers[0].byteLength, 48)
        let prefix = "data:application/octet-stream;base64,"
        XCTAssertTrue(doc.buffers[0].uri.hasPrefix(prefix))
        let b64 = String(doc.buffers[0].uri.dropFirst(prefix.count))
        XCTAssertEqual(Data(base64Encoded: b64)?.count, 48)
    }

    func testPositionAccessorHasFloatTypeAndBounds() throws {
        let doc = try decode(triangle())
        let pos = doc.accessors[0]
        XCTAssertEqual(pos.type, "VEC3")
        XCTAssertEqual(pos.componentType, 5126) // FLOAT
        XCTAssertEqual(pos.count, 3)
        XCTAssertEqual(pos.max, [1, 1, 0])
        XCTAssertEqual(pos.min, [0, 0, 0])
    }

    func testIndicesAccessorIsUnsignedIntScalar() throws {
        let doc = try decode(triangle())
        let prim = doc.meshes[0].primitives[0]
        let idx = doc.accessors[prim.indices]
        XCTAssertEqual(idx.type, "SCALAR")
        XCTAssertEqual(idx.componentType, 5125) // UNSIGNED_INT
        XCTAssertEqual(idx.count, 3)
    }

    func testColorsAddAttributeAndGrowBuffer() throws {
        let doc = try decode(triangle(colors: true))
        XCTAssertNotNil(doc.meshes[0].primitives[0].attributes["COLOR_0"])
        // + 3 vertices × 3 floats × 4 bytes of color = 48 + 36 = 84.
        XCTAssertEqual(doc.buffers[0].byteLength, 84)
    }
}
