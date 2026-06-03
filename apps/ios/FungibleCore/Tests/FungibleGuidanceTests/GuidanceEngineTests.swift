import XCTest
import FungibleDomain
@testable import FungibleGuidance

final class GuidanceEngineTests: XCTestCase {
    private let engine = RuleBasedGuidanceEngine()

    private func signals(
        tracking: CaptureSignals.Tracking = .normal,
        confidence: Double = 1.0,
        ambient: Double? = 500,
        speed: Double = 0.2
    ) -> CaptureSignals {
        CaptureSignals(tracking: tracking, highConfidenceFraction: confidence, ambientIntensity: ambient, deviceSpeed: speed)
    }

    func testCleanCaptureProducesNoUrgentPrompts() {
        let prompts = engine.evaluate(signals: signals(), coverage: 0.1, roi: nil)
        XCTAssertTrue(prompts.isEmpty)
    }

    func testExcessiveMotionIsHighestSeverity() {
        let prompts = engine.evaluate(
            signals: signals(tracking: .excessiveMotion, confidence: 0.2, speed: 1.5),
            coverage: 0,
            roi: nil
        )
        XCTAssertFalse(prompts.isEmpty)
        // Several issues apply at once; the most important is shown first.
        XCTAssertEqual(prompts.first?.kind, .slowDown)
        XCTAssertEqual(prompts.first?.severity, 90)
    }

    func testDarknessPrompts() {
        let prompts = engine.evaluate(signals: signals(ambient: 10), coverage: 0, roi: nil)
        XCTAssertTrue(prompts.contains { $0.kind == .improveLighting })
    }

    func testLowConfidenceTriggersRescan() {
        let prompts = engine.evaluate(signals: signals(confidence: 0.1), coverage: 0, roi: nil)
        XCTAssertTrue(prompts.contains { $0.kind == .rescanLowConfidence })
    }

    func testCoverageCompletePromptWhenThresholdMet() {
        let roi = RegionOfInterest(
            bounds: BoundingBox(min: .zero, max: Vector3(10, 5, 10)),
            completionThreshold: 0.9
        )
        let prompts = engine.evaluate(signals: signals(), coverage: 0.95, roi: roi)
        XCTAssertTrue(prompts.contains { $0.kind == .coverageComplete })
    }

    func testPromptsAreSortedBySeverityDescending() {
        let prompts = engine.evaluate(
            signals: signals(tracking: .excessiveMotion, confidence: 0.1, ambient: 10, speed: 1.5),
            coverage: 0,
            roi: nil
        )
        let severities = prompts.map(\.severity)
        XCTAssertEqual(severities, severities.sorted(by: >))
    }
}
