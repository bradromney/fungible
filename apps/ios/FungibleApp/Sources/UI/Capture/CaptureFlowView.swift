import SwiftUI
import FungibleStorage

/// Sequences the capture modal (screen 08 connective tissue): optional ROI setup
/// → live capture → post-capture handoff. Owns the CaptureViewModel so the model
/// survives across the steps. Cancelling or finishing the handoff closes the flow
/// (RootView reloads the project list).
struct CaptureFlowView: View {
    var onClose: () -> Void
    @StateObject private var viewModel: CaptureViewModel
    @State private var step: Step = .roi
    @State private var savedPoints = 0

    enum Step { case roi, capturing, handoff }

    init(store: any ScanStore, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: CaptureViewModel(store: store))
    }

    var body: some View {
        switch step {
        case .roi:
            ROISetupView(onSkip: { step = .capturing }, onStart: { step = .capturing })
        case .capturing:
            CaptureView(
                viewModel: viewModel,
                onCancel: onClose,
                onFinish: { savedPoints = viewModel.pointCount; step = .handoff }
            )
        case .handoff:
            // Every pass this flow saves grows ONE project (session-alive,
            // ADR-0005); "Scan again" resumes the same AR session/world frame.
            PostCaptureHandoffView(
                pointCount: savedPoints,
                passCount: viewModel.project?.scanCount ?? 1,
                projectName: viewModel.project?.name ?? "Untitled Site",
                onScanAgain: { step = .capturing },
                onConfirm: { name in
                    viewModel.renameProject(name)
                    onClose()
                }
            )
        }
    }
}
