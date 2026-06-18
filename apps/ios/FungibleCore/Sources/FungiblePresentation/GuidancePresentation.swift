import Foundation
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
}
