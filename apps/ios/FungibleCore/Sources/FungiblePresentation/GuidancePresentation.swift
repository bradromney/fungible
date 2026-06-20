import Foundation
import FungibleDomain
import FungibleGuidance

// Presentation mapping for live-capture coaching. The SF Symbol per prompt and
// the "show at most the top 1–2" rule were inline in the app's GuidanceOverlay;
// centralizing them here makes the mapping unit-testable and keeps the overlay a
// thin binding. The coaching vocabulary itself is owned by the GuidanceEngine —
// this only decides how each kind is drawn.
public enum GuidancePresentation {

    /// SF Symbol for a coaching prompt. Mirrors the engine's `Prompt.Kind` 1:1
    /// so a new kind forces a decision here (exhaustive switch, no default).
    public static func symbolName(for kind: Prompt.Kind) -> String {
        switch kind {
        case .slowDown:            return "tortoise"
        case .moveCloser:          return "arrow.down.forward.and.arrow.up.backward"
        case .improveLighting:     return "lightbulb"
        case .rescanLowConfidence: return "arrow.triangle.2.circlepath"
        case .fillGap:             return "arrow.up.forward.square"
        case .coverageComplete:    return "checkmark.circle"
        case .holdSteady:          return "hand.raised"
        }
    }

    /// The (at most) two prompts to display: highest-severity first as the solid
    /// "primary" capsule, the next as a quieter "secondary". The engine already
    /// returns prompts sorted by descending severity; we just take the top two.
    public static func displayed(_ prompts: [Prompt]) -> (primary: Prompt?, secondary: Prompt?) {
        let top = Array(prompts.prefix(2))
        return (top.first, top.count > 1 ? top[1] : nil)
    }

    /// How a prompt should read: a finished area is reassuring (green), a tracking
    /// or motion problem is a call to act, everything else is neutral coaching.
    /// Drives the overlay's colour without baking SwiftUI into the engine.
    public enum Tone: Equatable, Sendable { case normal, urgent, positive }

    public static func tone(for prompt: Prompt) -> Tone {
        switch prompt.kind {
        case .coverageComplete:
            return .positive
        case .slowDown, .holdSteady, .improveLighting, .rescanLowConfidence:
            return .urgent
        case .moveCloser, .fillGap:
            return .normal
        }
    }

    /// Screen heading (radians, clockwise from straight-up) for a fill-gap arrow,
    /// from the gap's world direction. Maps the horizontal plane: forward (−Z) is
    /// up/0, right (+X) is +π/2. A rotation applied to an upward-pointing arrow so
    /// it points the user toward the uncovered area. Honest — the direction comes
    /// from the engine's `Prompt.direction`, not a guess.
    public static func headingRadians(forGapDirection dir: Vector3) -> Double {
        atan2(Double(dir.x), -Double(dir.z))
    }
}
