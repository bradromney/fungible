import SwiftUI
import UIKit
import MetalKit
import ARKit

/// Phase 2 — the live capture overlay: paints the accumulating point cloud on
/// top of the camera feed, locked to the world. Reuses PointCloudRenderer with
/// the AR camera driving the MVP each frame instead of the orbit gestures.
///
/// Frame convention: accumulated points are in RAW ARKit world coordinates (the
/// capture pipeline folds its pinhole-axis flip into CAMERA space before
/// applying `camera.transform`), so ARKit's own view/projection matrices apply
/// directly — no correction term. The device walk-around is the ground-truth
/// check that points paint where the world is.
struct LiveCloudOverlayView: UIViewRepresentable {
    let arSession: ARSession
    let geometry: CloudGeometry

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        // Transparent over the camera feed; never steal touches.
        view.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.isUserInteractionEnabled = false
        // Continuous (the camera moves every frame); 30 fps saves battery.
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 30

        if let device = view.device, let renderer = PointCloudRenderer(device: device) {
            renderer.pointSize = 4
            renderer.mvpProvider = { [weak arSession] _, drawableSize in
                // Grabbing currentFrame briefly is the documented renderer
                // pattern; the footgun is RETAINING frames, so it never leaves
                // this closure. Portrait-only app (project.yml).
                guard let camera = arSession?.currentFrame?.camera,
                      drawableSize.width > 0, drawableSize.height > 0 else { return nil }
                let viewM = camera.viewMatrix(for: .portrait)
                let projM = camera.projectionMatrix(for: .portrait,
                                                    viewportSize: drawableSize,
                                                    zNear: 0.05, zFar: 100)
                return projM * viewM
            }
            context.coordinator.renderer = renderer
            view.delegate = renderer
        }
        context.coordinator.apply(geometry, to: view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.apply(geometry, to: view)
    }

    final class Coordinator {
        var renderer: PointCloudRenderer?
        private var appliedCount = -1

        func apply(_ geo: CloudGeometry, to view: MTKView) {
            guard geo.vertices.count != appliedCount else { return }
            appliedCount = geo.vertices.count
            renderer?.setGeometry(geo, on: view)
        }
    }
}
