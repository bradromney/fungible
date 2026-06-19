import SwiftUI
import FungibleDomain
import FungibleStorage

/// The app's navigation root (stack-based, no tab bar). Projects is the root;
/// capture is a full-screen modal so the AR viewfinder owns the screen; tapping a
/// project pushes its detail. Finishing a capture (or dismissing it) reloads the
/// project list so the new pass appears.
struct RootView: View {
    @StateObject private var projects: ProjectsViewModel
    @State private var path: [ScanSetID] = []
    @State private var showCapture = false

    init(store: any ScanStore) {
        _projects = StateObject(wrappedValue: ProjectsViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ProjectsHomeView(viewModel: projects, onNewScan: { showCapture = true })
                .navigationDestination(for: ScanSetID.self) { id in
                    if let set = projects.set(for: id) {
                        ProjectDetailView(viewModel: projects, initialSet: set)
                    } else {
                        Text("Project not found").foregroundStyle(.secondary)
                    }
                }
        }
        .task { await projects.load() }
        .fullScreenCover(isPresented: $showCapture, onDismiss: {
            Task { await projects.load() }
        }) {
            CaptureFlowView(store: projects.store) { showCapture = false }
        }
    }
}
