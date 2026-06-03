import XCTest
import FungibleDomain
import FungibleCapture
import FungibleStorage
import FungibleRegistration
import FungibleMeasure
import FungibleExport

// End-to-end proof that the on-device modules compose: synthetic site capture →
// unproject/accumulate → store round-trip → incremental two-scan registration →
// DEM → cut/fill + contours → export. Uses only the CI-tested core (no ARKit).

private struct IdentityCoarse: CoarseAligner {
    func align(source: PointSample, target: PointSample) async throws -> RegistrationResult {
        RegistrationResult(transform: .identity, fitness: 0.8, inlierRMSE: 0.02)
    }
}
private struct IdentityFine: FineAligner {
    func refine(source: PointSample, target: PointSample, initial: Transform) async throws -> RegistrationResult {
        RegistrationResult(transform: .identity, fitness: 0.95, inlierRMSE: 0.005)
    }
}

final class PipelineIntegrationTests: XCTestCase {
    /// A 4×4 m ground patch with a 1 m conical mound centered at (2,2).
    private func sitePoints() -> [CapturedPoint] {
        var points: [CapturedPoint] = []
        var x = 0.0
        while x <= 4 {
            var z = 0.0
            while z <= 4 {
                let dx = x - 2, dz = z - 2
                let dist = (dx * dx + dz * dz).squareRoot()
                let h = max(0, 1.0 - dist / 2.0)
                points.append(CapturedPoint(position: Vector3(x, h, z), confidence: .high,
                                            r: 200, g: 200, b: 200))
                z += 0.1
            }
            x += 0.1
        }
        return points
    }

    func testUnprojectionFeedsAccumulator() {
        // A flat synthetic depth patch unprojects to a bounded set of voxels.
        let intr = CameraIntrinsics(fx: 100, fy: 100, cx: 8, cy: 8)
        var acc = VoxelAccumulator(voxelSize: 0.05, capacity: 1_000_000)
        for v in 0..<16 {
            for u in 0..<16 {
                let world = Unprojection.worldPoint(u: Double(u), v: Double(v), depth: 2.0,
                                                    intrinsics: intr, cameraToWorld: .identity)
                acc.insert(CapturedPoint(position: world, confidence: .high))
            }
        }
        XCTAssertGreaterThan(acc.count, 0)
        XCTAssertLessThanOrEqual(acc.count, 256)
    }

    func testCaptureStoreExportRoundTrip() async throws {
        let points = sitePoints()
        var acc = VoxelAccumulator(voxelSize: 0.05, capacity: 2_000_000)
        for p in points { acc.insert(p) }
        let accumulated = acc.points()
        XCTAssertGreaterThan(accumulated.count, 0)

        // Store round-trip.
        let store = InMemoryScanStore()
        let scanID = ScanID()
        let ref = try await store.writeBlob(points: accumulated, for: scanID)
        let readBack = try await store.readBlob(ref)
        XCTAssertEqual(readBack.count, accumulated.count)

        // Export produces non-empty PLY and XYZ.
        XCTAssertFalse(PLYExporter(binary: true).data(for: accumulated).isEmpty)
        XCTAssertFalse(XYZExporter().data(for: accumulated).isEmpty)
    }

    func testIncrementalRegistrationOfTwoScans() async throws {
        var set = ScanSet(name: "Integration Site")
        let a = Scan(); let b = Scan()
        set.append(a); set.append(b)

        let registrar = IncrementalRegistrar(coarse: IdentityCoarse(), fine: IdentityFine(),
                                             optimizer: ChainPoseGraphOptimizer())
        let samples = PointSample(points: sitePoints().map { $0.position })

        _ = try await registrar.register(newScan: a.id, samples: samples, against: nil, in: &set)
        _ = try await registrar.register(newScan: b.id, samples: samples,
                                         against: (id: a.id, samples: samples), in: &set)

        XCTAssertEqual(set.poseGraph.constraints.count, 1)
        XCTAssertEqual(set.scan(a.id)?.pose, .identity)
        XCTAssertEqual(set.scan(b.id)?.pose, .identity) // identity aligners → overlaid
    }

    func testDEMCutFillAndContoursAndDXF() throws {
        let positions = sitePoints().map { $0.position }
        let dem = try XCTUnwrap(HeightGrid.topSurface(from: positions, cellSize: 0.5))

        // The mound sits above a 0 reference → net cut, no fill.
        let result = CutFillEngine.compare(existing: dem, toReferenceElevation: 0)
        XCTAssertGreaterThan(result.cutVolume, 0)
        XCTAssertEqual(result.fillVolume, 0, accuracy: 1e-9)

        // Contours around the mound, exported to DXF.
        let segments = Contours.segments(from: dem, interval: 0.2)
        XCTAssertFalse(segments.isEmpty)

        var drawing = DXFDrawing()
        for s in segments { drawing.addLine(s.a, s.b, layer: "CONTOUR") }
        let dxf = DXFExporter().data(for: drawing)
        XCTAssertFalse(dxf.isEmpty)
        XCTAssertEqual(drawing.lines.count, segments.count)
    }
}
