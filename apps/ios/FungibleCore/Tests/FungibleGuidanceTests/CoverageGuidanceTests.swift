import XCTest
import FungibleDomain
@testable import FungibleGuidance

final class CoverageGuidanceTests: XCTestCase {
    private let engine = RuleBasedGuidanceEngine()
    private func cleanSignals() -> CaptureSignals {
        CaptureSignals(tracking: .normal, highConfidenceFraction: 1, ambientIntensity: 500, deviceSpeed: 0.2)
    }

    func testEmitsDirectionalFillGapWhenIncomplete() {
        var grid = CoverageGrid(bounds: BoundingBox(min: .zero, max: Vector3(2, 2, 2)), voxelSize: 1)
        grid.observe(Vector3(0.5, 0.5, 0.5)) // 1/8 covered

        let prompts = engine.evaluate(signals: cleanSignals(), coverage: grid,
                                      cameraPosition: Vector3(0.5, 0.5, 0.5))
        let gap = try! XCTUnwrap(prompts.first { $0.kind == .fillGap })
        let dir = try! XCTUnwrap(gap.direction)
        XCTAssertEqual(dir.length, 1, accuracy: 1e-9) // unit arrow
        XCTAssertFalse(prompts.contains { $0.kind == .coverageComplete })
    }

    func testEmitsCompleteAndNoGapWhenCovered() {
        var grid = CoverageGrid(bounds: BoundingBox(min: .zero, max: Vector3(2, 2, 2)), voxelSize: 1)
        for z in 0..<2 { for y in 0..<2 { for x in 0..<2 {
            grid.observe(Vector3(Double(x) + 0.5, Double(y) + 0.5, Double(z) + 0.5))
        }}}
        let prompts = engine.evaluate(signals: cleanSignals(), coverage: grid, cameraPosition: .zero)
        XCTAssertTrue(prompts.contains { $0.kind == .coverageComplete })
        XCTAssertFalse(prompts.contains { $0.kind == .fillGap })
    }

    func testMotionPromptStillWinsOverGap() {
        var grid = CoverageGrid(bounds: BoundingBox(min: .zero, max: Vector3(2, 2, 2)), voxelSize: 1)
        grid.observe(Vector3(0.5, 0.5, 0.5))
        let fast = CaptureSignals(tracking: .excessiveMotion, highConfidenceFraction: 1,
                                  ambientIntensity: 500, deviceSpeed: 1.5)
        let prompts = engine.evaluate(signals: fast, coverage: grid, cameraPosition: .zero)
        XCTAssertEqual(prompts.first?.kind, .slowDown) // highest severity first
    }
}
