import XCTest
import FungibleDomain
import FungibleCapture
@testable import FungibleExport

final class LASExportTests: XCTestCase {
    private let points = [
        CapturedPoint(position: Vector3(1, 2, 3), confidence: .high, r: 255, g: 0, b: 0),
        CapturedPoint(position: Vector3(4, 5, 6), confidence: .high, r: 0, g: 128, b: 0),
    ]

    // Little-endian readers over the produced Data.
    private func u16(_ d: Data, _ o: Int) -> UInt16 { UInt16(d[o]) | (UInt16(d[o + 1]) << 8) }
    private func u32(_ d: Data, _ o: Int) -> UInt32 {
        UInt32(d[o]) | (UInt32(d[o + 1]) << 8) | (UInt32(d[o + 2]) << 16) | (UInt32(d[o + 3]) << 24)
    }
    private func i32(_ d: Data, _ o: Int) -> Int32 { Int32(bitPattern: u32(d, o)) }
    private func f64(_ d: Data, _ o: Int) -> Double {
        var bits: UInt64 = 0
        for k in 0..<8 { bits |= UInt64(d[o + k]) << (8 * k) }
        return Double(bitPattern: bits)
    }

    func testHeaderFieldsAndSize() {
        let d = LASExporter().data(for: points)
        XCTAssertEqual(String(decoding: d[0..<4], as: UTF8.self), "LASF")
        XCTAssertEqual(d[24], 1); XCTAssertEqual(d[25], 2)        // version 1.2
        XCTAssertEqual(u16(d, 94), 227)                          // header size
        XCTAssertEqual(u32(d, 96), 227)                          // offset to points
        XCTAssertEqual(d[104], 2)                                // point format 2
        XCTAssertEqual(u16(d, 105), 26)                          // record length
        XCTAssertEqual(u32(d, 107), 2)                           // point count
        XCTAssertEqual(d.count, 227 + 2 * 26)
    }

    func testFirstPointDecodesBackToSourceCoordinates() {
        let d = LASExporter(scale: 0.001).data(for: points)
        let scaleX = f64(d, 131), scaleY = f64(d, 139), scaleZ = f64(d, 147)
        let offX = f64(d, 155), offY = f64(d, 163), offZ = f64(d, 171)

        let base = 227
        let lasX = Double(i32(d, base + 0)) * scaleX + offX
        let lasY = Double(i32(d, base + 4)) * scaleY + offY
        let lasZ = Double(i32(d, base + 8)) * scaleZ + offZ
        // Reverse the plan-view mapping: our (x,y,z) = (LAS X, LAS Z, LAS Y).
        XCTAssertEqual(lasX, 1, accuracy: 1e-6)   // our x
        XCTAssertEqual(lasZ, 2, accuracy: 1e-6)   // our y (elevation)
        XCTAssertEqual(lasY, 3, accuracy: 1e-6)   // our z (north)
    }

    func testColorScaledTo16Bit() {
        let d = LASExporter().data(for: points)
        // First record's RGB at record offset 20/22/24.
        XCTAssertEqual(u16(d, 227 + 20), 65535) // red 255 → 65535
        XCTAssertEqual(u16(d, 227 + 22), 0)
    }

    func testBoundsRecorded() {
        let d = LASExporter().data(for: points)
        XCTAssertEqual(f64(d, 179), 4, accuracy: 1e-6)  // max X (east)
        XCTAssertEqual(f64(d, 187), 1, accuracy: 1e-6)  // min X
    }

    func testEmptyCloudHeaderOnly() {
        let d = LASExporter().data(for: [])
        XCTAssertEqual(u32(d, 107), 0)
        XCTAssertEqual(d.count, 227)
    }

    func testFactoryMapping() {
        XCTAssertEqual(Exporters.make(.las).format, .las)
        XCTAssertEqual(ExportFormat.las.fileExtension, "las")
    }
}
