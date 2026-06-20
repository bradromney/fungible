import SwiftUI
import FungibleDomain
import FungibleGuidance
import FungiblePresentation

/// Live coaching, patterned on Apple's ObjectCaptureSession feedback UX: show at
/// most the top one or two prompts so a novice isn't overwhelmed (research §7).
/// The top (highest-severity) prompt gets the solid "primary" capsule, tinted by
/// tone (green when an area is done). A fill-gap prompt also raises a directional
/// arrow pointing at the uncovered area — rotated by the engine's real
/// `Prompt.direction`, not a guess. Symbol/tone/heading math live in
/// `GuidancePresentation` (tested); the overlay stays a thin binding.
struct GuidanceOverlay: View {
    let prompts: [Prompt]
    @State private var pulse = false

    var body: some View {
        let shown = GuidancePresentation.displayed(prompts)
        return VStack(spacing: 10) {
            if let primary = shown.primary {
                if primary.kind == .fillGap, let direction = primary.direction {
                    gapArrow(direction)
                }
                capsule(for: primary, isPrimary: true)
            }
            if let secondary = shown.secondary {
                capsule(for: secondary, isPrimary: false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: prompts.map(\.message))
    }

    /// Arrow pointing the user toward the uncovered area. Rotation comes from the
    /// gap's world direction (honest); the gentle pulse draws the eye without nag.
    private func gapArrow(_ direction: Vector3) -> some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.white)
            .padding(16)
            .background(Color.accentColor.opacity(0.9), in: Circle())
            .rotationEffect(.radians(GuidancePresentation.headingRadians(forGapDirection: direction)))
            .scaleEffect(pulse ? 1.0 : 0.88)
            .onAppear {
                pulse = false
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }
            .onDisappear { pulse = false }
            .accessibilityLabel("Move toward the uncovered area")
    }

    private func capsule(for prompt: Prompt, isPrimary: Bool) -> some View {
        Label(prompt.message, systemImage: GuidancePresentation.symbolName(for: prompt.kind))
            .font(.callout.weight(.medium))
            .foregroundStyle(isPrimary ? Color.white : Color.white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background(for: prompt, isPrimary: isPrimary), in: Capsule())
            .accessibilityLabel(prompt.message)
    }

    private func background(for prompt: Prompt, isPrimary: Bool) -> AnyShapeStyle {
        guard isPrimary else { return AnyShapeStyle(.ultraThinMaterial) }
        switch GuidancePresentation.tone(for: prompt) {
        case .positive: return AnyShapeStyle(Color.green.opacity(0.9))
        case .urgent:   return AnyShapeStyle(Color.accentColor.opacity(0.95))
        case .normal:   return AnyShapeStyle(Color.accentColor.opacity(0.9))
        }
    }
}
