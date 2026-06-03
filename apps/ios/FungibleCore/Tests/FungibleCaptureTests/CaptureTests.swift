import XCTest
import FungibleDomain
@testable import FungibleCapture

final class UnprojectionTests: XCTestCase {
    private let eps = 1e-9

    func testCenterPixelMapsToDepthAlongZ() {
        // Principal-point pixel unprojects straight out at the depth distance.
        let intr = CameraIntrinsics(fx: 500, fy: 500, cx: 320, cy: 240)
        let p = Unprojection.cameraPoint(u: 320, v: 240, depth: 2, intrinsics: intr)
        XCTAssertEqual(p.x, 0, accuracy: eps)
        XCTAssertEqual(p.y, 0, accuracy: eps)
        XCTAssertEqual(p.z, 2, accuracy: eps)
    }

    func testOffCenterPixelScalesWithDepthAndFocal() {
        let intr = CameraIntrinsics(fx: 500, fy: 500, cx: 320, cy: 240)
        let p = Unprojection.cameraPoint(u: 420, v: 240, depth: 5, intrinsics: intr)
        // x = (420-320)*5/500 = 1.0
        XCTAssertEqual(p.x, 1.0, accuracy: eps)
        XCTAssertEqual(p.z, 5, accuracy: eps)
    }

    func testWorldPointAppliesCameraTransform() {
        let intr = CameraIntrinsics(fx: 1, fy: 1, cx: 0, cy: 0)
        let cameraToWorld = Transform(rotation: .identity, translation: Vector3(10, 0, 0))
        let world = Unprojection.worldPoint(u: 0, v: 0, depth: 2, intrinsics: intr, cameraToWorld: cameraToWorld)
        XCTAssertEqual(world.x, 10, accuracy: eps)
        XCTAssertEqual(world.z, 2, accuracy: eps)
    }
}

final class ConfidenceFilterTests: XCTestCase {
    func testRejectsLowConfidence() {
        let filter = ConfidenceFilter(minConfidence: .medium, maxRangeMeters: 5)
        XCTAssertFalse(filter.keep(confidence: .low, depthMeters: 2))
        XCTAssertTrue(filter.keep(confidence: .medium, depthMeters: 2))
        XCTAssertTrue(filter.keep(confidence: .high, depthMeters: 2))
    }

    func testRejectsOutOfRange() {
        let filter = ConfidenceFilter(minConfidence: .low, maxRangeMeters: 5)
        XCTAssertFalse(filter.keep(confidence: .high, depthMeters: 6))
        XCTAssertFalse(filter.keep(confidence: .high, depthMeters: 0))
        XCTAssertTrue(filter.keep(confidence: .high, depthMeters: 5))
    }
}

final class VoxelAccumulatorTests: XCTestCase {
    private func point(_ x: Double, _ y: Double, _ z: Double, _ c: DepthConfidence) -> CapturedPoint {
        CapturedPoint(position: Vector3(x, y, z), confidence: c)
    }

    func testPointsInSameVoxelDeduplicate() {
        var acc = VoxelAccumulator(voxelSize: 1.0, capacity: 100)
        XCTAssertTrue(acc.insert(point(0.1, 0.1, 0.1, .low)))   // opens voxel (0,0,0)
        XCTAssertFalse(acc.insert(point(0.9, 0.2, 0.3, .low)))  // same voxel
        XCTAssertEqual(acc.count, 1)
    }

    func testHigherConfidenceReplacesWithinVoxel() {
        var acc = VoxelAccumulator(voxelSize: 1.0, capacity: 100)
        acc.insert(point(0.1, 0.1, 0.1, .low))
        acc.insert(point(0.5, 0.5, 0.5, .high))
        XCTAssertEqual(acc.count, 1)
        XCTAssertEqual(acc.points().first?.confidence, .high)
    }

    func testDistinctVoxelsAccumulate() {
        var acc = VoxelAccumulator(voxelSize: 1.0, capacity: 100)
        XCTAssertTrue(acc.insert(point(0.5, 0, 0, .high)))
        XCTAssertTrue(acc.insert(point(1.5, 0, 0, .high)))
        XCTAssertTrue(acc.insert(point(-0.5, 0, 0, .high))) // floor(-0.5) = -1
        XCTAssertEqual(acc.count, 3)
    }

    func testCapacityIsBounded() {
        var acc = VoxelAccumulator(voxelSize: 1.0, capacity: 2)
        XCTAssertTrue(acc.insert(point(0.5, 0, 0, .high)))
        XCTAssertTrue(acc.insert(point(1.5, 0, 0, .high)))
        XCTAssertFalse(acc.insert(point(2.5, 0, 0, .high)), "new voxel past capacity is dropped")
        XCTAssertEqual(acc.count, 2)
        XCTAssertTrue(acc.isFull)
        // An existing voxel can still be updated even when full.
        XCTAssertFalse(acc.insert(point(0.5, 0, 0, .high)))
        XCTAssertEqual(acc.count, 2)
    }

    func testNegativeCoordinatesKeyByFloor() {
        let acc = VoxelAccumulator(voxelSize: 0.5, capacity: 10)
        // floor(-0.1 / 0.5) = floor(-0.2) = -1
        XCTAssertEqual(acc.key(for: Vector3(-0.1, 0, 0)).x, -1)
        XCTAssertEqual(acc.key(for: Vector3(0.1, 0, 0)).x, 0)
    }
}
