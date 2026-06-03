import SwiftUI
import ARKit
import SceneKit

/// Hosts an `ARSCNView` bound to the capture session so the user sees the live
/// camera feed during capture. A dedicated Metal point-cloud preview (rendering
/// the accumulating cloud with LOD) is the next step — it will live in
/// `FungibleRendering` and replace this passthrough view.
struct ARViewContainer: UIViewRepresentable {
    let session: ARDepthCaptureSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session.session
        view.automaticallyUpdatesLighting = true
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
