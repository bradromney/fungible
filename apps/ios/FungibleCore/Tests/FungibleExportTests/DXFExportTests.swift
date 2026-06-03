import XCTest
import FungibleDomain
@testable import FungibleExport

final class DXFExportTests: XCTestCase {
    func testEncodesEntitiesAndStructure() {
        var d = DXFDrawing()
        d.addLine(Vector3(1, 2, 3), Vector3(4, 5, 6), layer: "CONTOUR")
        d.addPoint(Vector3(7, 8, 9), layer: "POINTS")
        d.addText("12.5m", at: Vector3(0, 0, 0), height: 0.5, layer: "LABELS")

        let dxf = DXFExporter().encode(d)

        XCTAssertTrue(dxf.hasPrefix("0\nSECTION\n2\nENTITIES\n"))
        XCTAssertTrue(dxf.hasSuffix("0\nENDSEC\n0\nEOF\n"))
        XCTAssertTrue(dxf.contains("0\nLINE\n8\nCONTOUR\n"))
        XCTAssertTrue(dxf.contains("0\nPOINT\n8\nPOINTS\n"))
        XCTAssertTrue(dxf.contains("0\nTEXT\n8\nLABELS\n"))
        XCTAssertTrue(dxf.contains("12.5m"))
    }

    func testPlanViewCoordinateMapping() {
        // Vector3(x=1 east, y=2 up, z=3 north) → DXF (X=1, Y=3, Z=2).
        var d = DXFDrawing()
        d.addPoint(Vector3(1, 2, 3))
        let dxf = DXFExporter().encode(d)
        XCTAssertTrue(dxf.contains("10\n1.000000\n20\n3.000000\n30\n2.000000\n"),
                      "X=east, Y=north(our z), Z=elevation(our y)")
    }

    func testPolylineExpandsToConnectedLines() {
        var d = DXFDrawing()
        d.addPolyline([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)], layer: "L")
        XCTAssertEqual(d.lines.count, 2)
        let dxf = DXFExporter().encode(d)
        XCTAssertEqual(dxf.components(separatedBy: "0\nLINE\n").count - 1, 2)
    }

    func testEmptyDrawingIsWellFormed() {
        let dxf = DXFExporter().encode(DXFDrawing())
        XCTAssertEqual(dxf, "0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n")
    }
}
