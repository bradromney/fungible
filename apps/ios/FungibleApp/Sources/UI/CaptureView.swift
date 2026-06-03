import SwiftUI

/// The M1 capture screen: live camera with guidance overlay, a running point
/// count, and a single capture/finish control. Deliberately minimal — the goal
/// of M1 is "walk a space, watch the cloud build with live coaching, scan saved."
struct CaptureView: View {
    @StateObject var viewModel: CaptureViewModel
    @State private var isSaving = false

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
            Label("\(viewModel.pointCount) pts", systemImage: "circle.grid.3x3.fill")
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
        Button {
            Task {
                isSaving = true
                await viewModel.finishScan()
                isSaving = false
            }
        } label: {
            Text(isSaving ? "Saving…" : "Finish Scan")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isCapturing ? Color.accentColor : Color.gray, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .disabled(!viewModel.isCapturing || isSaving)
    }
}
