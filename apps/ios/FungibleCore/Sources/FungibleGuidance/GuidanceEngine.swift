import Foundation
import FungibleDomain

// The differentiator (research §7). The engine consumes free native signals
// (ARKit confidence, ARMeshAnchor coverage, TrackingState reasons, lightEstimate)
// plus a voxel coverage grid scoped to the set's region of interest, and emits
// at most one or two prompts at a time (Apple ObjectCaptureSession.Feedback UX
// model). Tuned for outdoor/terrain capture, which competitors don't address.

/// Raw, per-frame signals the app feeds in (sourced from ARKit in the app layer
/// so this module stays framework-free and testable).
public struct CaptureSignals: Equatable, Sendable {
    public enum Tracking: Equatable, Sendable {
        case normal
        case excessiveMotion
        case insufficientFeatures
        case initializing
    }

    public var tracking: Tracking
    /// Fraction [0,1] of the current frame's depth pixels at high confidence.
    public var highConfidenceFraction: Double
    /// ARKit ambient intensity in lux-like units (nil if unavailable).
    public var ambientIntensity: Double?
    /// Estimated device linear speed (m/s) from pose deltas.
    public var deviceSpeed: Double

    public init(tracking: Tracking, highConfidenceFraction: Double, ambientIntensity: Double?, deviceSpeed: Double) {
        self.tracking = tracking
        self.highConfidenceFraction = highConfidenceFraction
        self.ambientIntensity = ambientIntensity
        self.deviceSpeed = deviceSpeed
    }
}

/// A single piece of coaching shown to the user. Severity orders which one wins
/// when several apply (we show at most one or two at once).
public struct Prompt: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case slowDown            // moving too fast
        case moveCloser          // beyond reliable LiDAR range / sparse returns
        case improveLighting     // too dark
        case rescanLowConfidence // observed but noisy → rescan this surface
        case fillGap             // never-observed region inside the ROI
        case coverageComplete    // you've covered enough of the ROI
        case holdSteady          // tracking initializing / lost
    }

    public var kind: Kind
    public var message: String
    public var severity: Int // higher = more important

    public init(kind: Kind, message: String, severity: Int) {
        self.kind = kind
        self.message = message
        self.severity = severity
    }
}

/// Produces prompts from live signals and accumulated coverage.
public protocol GuidanceEngine: Sendable {
    /// Evaluate current state and return the prompts to display (highest
    /// severity first; callers typically show the top 1–2).
    func evaluate(signals: CaptureSignals, coverage: Double, roi: RegionOfInterest?) -> [Prompt]
}

/// A pure, rules-based default implementation. Heavier coverage-gap detection
/// (voxel/TSDF occupancy, Next-Best-View) plugs in later behind the same
/// protocol; this baseline already gives useful real-time coaching.
public struct RuleBasedGuidanceEngine: GuidanceEngine {
    public var fastSpeedThreshold: Double      // m/s
    public var darkAmbientThreshold: Double    // lux-like
    public var lowConfidenceThreshold: Double  // fraction

    public init(fastSpeedThreshold: Double = 0.7, darkAmbientThreshold: Double = 100, lowConfidenceThreshold: Double = 0.5) {
        self.fastSpeedThreshold = fastSpeedThreshold
        self.darkAmbientThreshold = darkAmbientThreshold
        self.lowConfidenceThreshold = lowConfidenceThreshold
    }

    public func evaluate(signals: CaptureSignals, coverage: Double, roi: RegionOfInterest?) -> [Prompt] {
        var prompts: [Prompt] = []

        switch signals.tracking {
        case .excessiveMotion:
            prompts.append(Prompt(kind: .slowDown, message: "Slow down — move the device steadily.", severity: 90))
        case .insufficientFeatures:
            prompts.append(Prompt(kind: .improveLighting, message: "Not enough detail — try better light or a richer surface.", severity: 80))
        case .initializing:
            prompts.append(Prompt(kind: .holdSteady, message: "Hold steady while tracking starts…", severity: 70))
        case .normal:
            break
        }

        if signals.deviceSpeed > fastSpeedThreshold {
            prompts.append(Prompt(kind: .slowDown, message: "Moving too fast — ease off for a cleaner scan.", severity: 85))
        }
        if let lux = signals.ambientIntensity, lux < darkAmbientThreshold {
            prompts.append(Prompt(kind: .improveLighting, message: "It's dark here — add light if you can.", severity: 60))
        }
        if signals.highConfidenceFraction < lowConfidenceThreshold {
            prompts.append(Prompt(kind: .rescanLowConfidence, message: "This surface is noisy — get a bit closer and rescan.", severity: 50))
        }

        if let roi, coverage >= roi.completionThreshold {
            prompts.append(Prompt(kind: .coverageComplete, message: "You've covered enough of this area. ✓", severity: 40))
        }

        return prompts.sorted { $0.severity > $1.severity }
    }
}
