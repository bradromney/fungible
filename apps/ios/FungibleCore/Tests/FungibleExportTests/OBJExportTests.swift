import XCTest
import FungibleDomain
@testable import FungibleExport

final class OBJExportTests: XCTestCase {
    private func triangle() -> TriangleMesh {
        TriangleMesh(
            vertices: [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)],
            indices: [0, 1, 2]
        )
    }

    func testEmitsVerticesAndOneOneIndexedFace() {
        let obj = OBJExporter().string(for: triangle())
        XCTAssertEqual(obj.components(separatedBy: "\nv ").count - 1, 3) // 3 vertex lines
        XCTAssertTrue(obj.contains("v 1.0 0.0 0.0"))
        XCTAssertTrue(obj.contains("\nf 1 2 3\n")) // 1-indexed, no normals
    }

    func testEmitsNormalsAndNormalIndexedFaces() {
        var mesh = triangle()
        mesh.normals = [Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1)]
        let obj = OBJExporter().string(for: mesh)
        XCTAssertEqual(obj.components(separatedBy: "\nvn ").count - 1, 3)
        XCTAssertTrue(obj.contains("\nf 1//1 2//2 3//3\n"))
    }

    func testEmitsVertexColors() {
        var mesh = triangle()
        mesh.colors = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
        let obj = OBJExporter().string(for: mesh)
        XCTAssertTrue(obj.contains("v 0.0 0.0 0.0 1.0 0.0 0.0")) // xyz + rgb
    }

    func testTriangleCountAndValidity() {
        let mesh = triangle()
        XCTAssertEqual(mesh.triangleCount, 1)
        XCTAssertTrue(mesh.isValid)

        let bad = TriangleMesh(vertices: [Vector3(0, 0, 0)], indices: [0, 1, 2]) // out of range
        XCTAssertFalse(bad.isValid)
    }

    func testEmptyMeshHeaderOnly() {
        let obj = OBJExporter().string(for: TriangleMesh())
        XCTAssertEqual(obj, "# Fungible OBJ export\n")
    }
}
