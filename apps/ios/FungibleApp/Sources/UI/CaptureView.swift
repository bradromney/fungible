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
        // "Finish pass" — a capture is one pass appended to a project (ADR-0005),
        // not a standalone "scan". On save, dismiss back to the project list.
        Button {
            Task {
                isSaving = true
                await viewModel.finishScan()
                isSaving = false
                onFinish()
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
