import SwiftUI
import FungiblePresentation

/// Screen 08A — optional Region of Interest before scanning. Drag four corner
/// handles to bound the work area; the live ft² readout scopes the capture
/// coverage meter. Entirely skippable (Skip is first-class) — open scans need no
/// ROI, matching the no-ceiling, low-friction philosophy.
struct ROISetupView: View {
    var onSkip: () -> Void
    var onStart: () -> Void

    @State private var corners: [CGPoint] = [
        CGPoint(x: 80, y: 280), CGPoint(x: 300, y: 280),
        CGPoint(x: 300, y: 560), CGPoint(x: 80, y: 560),
    ]
    /// Screen-point → meters (matches the measure tools' synthetic scale).
    private let scale = 0.012

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ZStack {
                Color(white: 0.11)
                boundary
                ForEach(corners.indices, id: \.self) { i in handle(i) }
                VStack {
                    Spacer()
                    Text("Drag the corners to fit your work area · \(DisplayFormat.areaFeetSquared(areaSqMeters))")
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 16)
                }
            }
            .coordinateSpace(name: "roi")
            startButton
        }
        .preferredColorScheme(.dark)
    }

    private var navBar: some View {
        HStack {
            Text("Set scan area").font(.headline)
            Spacer()
            Button("Skip", action: onSkip).font(.subheadline.weight(.medium))
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var boundary: some View {
        Path { p in
            guard let first = corners.first else { return }
            p.move(to: first)
            for c in corners.dropFirst() { p.addLine(to: c) }
            p.closeSubpath()
        }
        .fill(Color.accentColor.opacity(0.18))
        .overlay(
            Path { p in
                guard let first = corners.first else { return }
                p.move(to: first)
                for c in corners.dropFirst() { p.addLine(to: c) }
                p.closeSubpath()
            }
            .stroke(Color.accentColor, lineWidth: 2)
        )
    }

    private func handle(_ i: Int) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
            .position(corners[i])
            .gesture(
                DragGesture(coordinateSpace: .named("roi"))
                    .onChanged { corners[i] = $0.location }
            )
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text("Start scanning")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    /// Plan area of the dragged quad (shoelace in points → m²).
    private var areaSqMeters: Double {
        guard corners.count >= 3 else { return 0 }
        var s = 0.0
        for i in 0..<corners.count {
            let a = corners[i], b = corners[(i + 1) % corners.count]
            s += Double(a.x * b.y - b.x * a.y)
        }
        return abs(s) / 2 * scale * scale
    }
}
