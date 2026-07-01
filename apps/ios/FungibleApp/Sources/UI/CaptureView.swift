import SwiftUI
import FungiblePresentation

/// The M1 capture screen: live camera with guidance overlay, a running point
/// count, and a single capture/finish control. Deliberately minimal — the goal
/// of M1 is "walk a space, watch the cloud build with live coaching, scan saved."
struct CaptureView: View {
    @StateObject var viewModel: CaptureViewModel
    @State private var isSaving = false
    /// Cancel (X) exits the capture flow; finish advances to the handoff.
    let onCancel: () -> Void
    let onFinish: () -> Void

    init(viewModel: CaptureViewModel, onCancel: @escaping () -> Void, onFinish: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCancel = onCancel
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            ARViewContainer(session: viewModel.session)
                .ignoresSafeArea()

            // Live cloud painted over the camera feed, locked to the world —
            // the "watch the scan build" layer (Phase 2).
            LiveCloudOverlayView(arSession: viewModel.session.session,
                                 geometry: viewModel.liveGeometry)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                GuidanceOverlay(prompts: viewModel.prompts)
                    .padding(.bottom, 12)
                controls
            }
            .padding()
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .foregroundStyle(.primary)
            .accessibilityLabel("Cancel capture")

            Label(DisplayFormat.pointCountLabel(viewModel.pointCount), systemImage: "circle.grid.3x3.fill")
                .font(.subheadline.monospacedDigit())
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var controls: some View {
        // "Finish pass" — one pass appended to the growing project (ADR-0005).
        // The AR session stays alive so the next pass shares this world frame.
        Button {
            Task {
                isSaving = true
                let saved = await viewModel.finishPass()
                isSaving = false
                if saved { onFinish() }   // empty pass: stay, status explains
            }
        } label: {
            Text(isSaving ? "Saving…" : "Finish pass")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isCapturing ? Color.accentColor : Color.gray, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .disabled(!viewModel.isCapturing || isSaving)
    }
}
