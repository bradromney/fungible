import XCTest
import FungibleDomain
import FungibleCapture
@testable import FungibleExport

final class ExportTests: XCTestCase {
    private let points = [
        CapturedPoint(position: Vector3(1, 2, 3), confidence: .high, r: 10, g: 20, b: 30),
        CapturedPoint(position: Vector3(-4, 5, -6), confidence: .low, r: 40, g: 50, b: 60),
    ]

    func testPLYASCIIHasHeaderAndOneLinePerPoint() {
        let data = PLYExporter(binary: false).data(for: points)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("ply\nformat ascii 1.0\n"))
        XCTAssertTrue(text.contains("element vertex 2"))
        let body = text.components(separatedBy: "end_header\n")[1]
        let lines = body.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "1.0 2.0 3.0 10 20 30")
    }

    func testPLYBinarySizeMatchesFormat() {
        let data = PLYExporter(binary: true).data(for: points)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("ply\nformat binary_little_endian 1.0\n"))
        // Header bytes + 2 vertices × (3 float32 + 3 uchar = 15 bytes).
        guard let headerRange = data.range(of: Data("end_header\n".utf8)) else {
            return XCTFail("missing end_header")
        }
        let payload = data.count - headerRange.upperBound
        XCTAssertEqual(payload, 2 * 15)
    }

    func testXYZIsOneLinePerPoint() {
        let data = XYZExporter().data(for: points)
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[1], "-4.0 5.0 -6.0 40 50 60")
    }

    func testEmptyExportsHeaderOnly() {
        let text = String(decoding: PLYExporter(binary: false).data(for: []), as: UTF8.self)
        XCTAssertTrue(text.contains("element vertex 0"))
        XCTAssertTrue(text.hasSuffix("end_header\n"))
        XCTAssertTrue(XYZExporter().data(for: []).isEmpty)
    }

    func testFactoryMapsFormats() {
        XCTAssertEqual(Exporters.make(.plyBinary).format, .plyBinary)
        XCTAssertEqual(Exporters.make(.plyASCII).format, .plyASCII)
        XCTAssertEqual(Exporters.make(.xyz).format, .xyz)
    }
}
