import SwiftUI
import FungibleGuidance
import FungiblePresentation

/// Live coaching, patterned on Apple's ObjectCaptureSession feedback UX: show at
/// most the top one or two prompts so a novice isn't overwhelmed (research §7).
/// The top (highest-severity) prompt gets the solid "primary" capsule; the
/// symbol-per-kind and top-two selection live in `GuidancePresentation` (tested).
struct GuidanceOverlay: View {
    let prompts: [Prompt]

    var body: some View {
        let shown = GuidancePresentation.displayed(prompts)
        return VStack(spacing: 8) {
            if let primary = shown.primary {
                capsule(for: primary, isPrimary: true)
            }
            if let secondary = shown.secondary {
                capsule(for: secondary, isPrimary: false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: prompts.map(\.message))
    }

    private func capsule(for prompt: Prompt, isPrimary: Bool) -> some View {
        Label(prompt.message, systemImage: GuidancePresentation.symbolName(for: prompt.kind))
            .font(.callout.weight(.medium))
            .foregroundStyle(isPrimary ? Color.white : Color.white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isPrimary ? AnyShapeStyle(Color.accentColor.opacity(0.9))
                          : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
    }
}
