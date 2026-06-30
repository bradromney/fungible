import SwiftUI
import UIKit
import MetalKit
import FungibleDomain
import FungibleStorage

/// SwiftUI host for the Metal point-cloud renderer. Paused + redraw-on-demand;
/// pan orbits, pinch zooms. Re-uploads only when the cloud actually changes.
struct PointCloudMetalView: UIViewRepresentable {
    let geometry: CloudGeometry

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.07, green: 0.07, blue: 0.085, alpha: 1)
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        if let device = view.device, let renderer = PointCloudRenderer(device: device) {
            context.coordinator.renderer = renderer
            view.delegate = renderer
        }
        context.coordinator.attach(to: view)
        context.coordinator.apply(geometry, to: view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.apply(geometry, to: view)
    }

    final class Coordinator: NSObject {
        var renderer: PointCloudRenderer?
        private weak var view: MTKView?
        private var appliedCount = -1

        func attach(to view: MTKView) {
            self.view = view
            view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onPan(_:))))
            view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:))))
        }

        func apply(_ geo: CloudGeometry, to view: MTKView) {
            guard geo.vertices.count != appliedCount else { return }
            appliedCount = geo.vertices.count
            renderer?.setGeometry(geo, on: view)
        }

        @objc func onPan(_ g: UIPanGestureRecognizer) {
            guard let view = view, let r = renderer else { return }
            let t = g.translation(in: view)
            r.azimuth -= Float(t.x) * 0.006
            r.elevation = Swift.min(Swift.max(r.elevation + Float(t.y) * 0.006, -1.45), 1.45)
            g.setTranslation(.zero, in: view)
            view.setNeedsDisplay()
        }

        @objc func onPinch(_ g: UIPinchGestureRecognizer) {
            guard g.state == .changed, let view = view, let r = renderer else { return }
            r.distance = Swift.max(r.distance / Float(g.scale), 0.05)
            g.scale = 1
            view.setNeedsDisplay()
        }
    }
}

/// Loads a project's cloud from the store and renders it, with loading / empty
/// states. Replaces the gray viewer placeholder in Project Detail.
struct ProjectCloudViewer: View {
    let scans: [Scan]
    let store: any ScanStore

    @State private var geometry: CloudGeometry = .empty
    @State private var isLoading = true

    var body: some View {
        ZStack {
            PointCloudMetalView(geometry: geometry)
            if isLoading {
                ProgressView().tint(.white)
            } else if geometry.vertices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 44)).foregroundStyle(.white.opacity(0.35))
                    Text("No points to display")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .task(id: scans.map(\.id)) {
            isLoading = true
            geometry = await PointCloudLoader.load(scans: scans, from: store)
            isLoading = false
        }
    }
}
