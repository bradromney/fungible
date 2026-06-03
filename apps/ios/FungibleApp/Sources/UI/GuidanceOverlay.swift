import SwiftUI
import FungibleGuidance

/// Live coaching, patterned on Apple's ObjectCaptureSession feedback UX: show at
/// most the top one or two prompts so a novice isn't overwhelmed (research §7).
struct GuidanceOverlay: View {
    let prompts: [Prompt]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(prompts.prefix(2).enumerated()), id: \.offset) { _, prompt in
                Label(prompt.message, systemImage: icon(for: prompt.kind))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .animation(.easeInOut(duration: 0.2), value: prompts.map(\.message))
    }

    private func icon(for kind: Prompt.Kind) -> String {
        switch kind {
        case .slowDown: return "tortoise"
        case .moveCloser: return "arrow.down.forward.and.arrow.up.backward"
        case .improveLighting: return "lightbulb"
        case .rescanLowConfidence: return "arrow.triangle.2.circlepath"
        case .fillGap: return "square.dashed"
        case .coverageComplete: return "checkmark.circle"
        case .holdSteady: return "hand.raised"
        }
    }
}
