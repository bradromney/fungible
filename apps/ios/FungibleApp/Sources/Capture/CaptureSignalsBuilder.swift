import ARKit
import FungibleGuidance

/// Translates an ARKit depth frame + device motion into the framework-free
/// `CaptureSignals` the (CI-tested) `GuidanceEngine` consumes.
enum CaptureSignalsBuilder {
    static func build(frame: DepthFrameData, deviceSpeed: Double) -> CaptureSignals {
        CaptureSignals(
            tracking: mapTracking(frame.trackingState),
            highConfidenceFraction: highConfidenceFraction(frame.confidence),
            ambientIntensity: frame.ambientIntensity,
            deviceSpeed: deviceSpeed
        )
    }

    private static func mapTracking(_ state: ARCamera.TrackingState) -> CaptureSignals.Tracking {
        switch state {
        case .normal:
            return .normal
        case .notAvailable:
            return .initializing
        case .limited(let reason):
            switch reason {
            case .excessiveMotion: return .excessiveMotion
            case .insufficientFeatures: return .insufficientFeatures
            case .initializing, .relocalizing: return .initializing
            @unknown default: return .initializing
            }
        }
    }

    private static func highConfidenceFraction(_ confidence: [UInt8]) -> Double {
        guard !confidence.isEmpty else { return 0 }
        let high = confidence.reduce(0) { $0 + ($1 >= 2 ? 1 : 0) }
        return Double(high) / Double(confidence.count)
    }
}
