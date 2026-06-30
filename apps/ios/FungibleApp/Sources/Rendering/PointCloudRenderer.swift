import Foundation
import MetalKit
import simd

/// Draws a point cloud with a simple orbit camera. Paired with an MTKView that's
/// paused + redraw-on-demand, so it only renders when the geometry or camera
/// changes (cheap for a static cloud). Phase 2 reuses this with the AR camera
/// driving the view matrix instead of the orbit gestures.
final class PointCloudRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState

    private var vertexBuffer: MTLBuffer?
    private var vertexCount = 0

    // Orbit camera state (mutated by the view's gesture handlers).
    var azimuth: Float = .pi * 0.25
    var elevation: Float = .pi * 0.18
    var distance: Float = 3

    private var target: SIMD3<Float> = .zero
    private var radius: Float = 1
    private var aspect: Float = 1

    init?(device: MTLDevice) {
        guard let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vfn = library.makeFunction(name: "pc_vertex"),
              let ffn = library.makeFunction(name: "pc_fragment") else { return nil }
        self.commandQueue = queue

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vfn
        desc.fragmentFunction = ffn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.depthAttachmentPixelFormat = .depth32Float
        guard let state = try? device.makeRenderPipelineState(descriptor: desc) else { return nil }
        self.pipeline = state

        let dsd = MTLDepthStencilDescriptor()
        dsd.depthCompareFunction = .less
        dsd.isDepthWriteEnabled = true
        guard let ds = device.makeDepthStencilState(descriptor: dsd) else { return nil }
        self.depthState = ds

        super.init()
    }

    func setGeometry(_ geo: CloudGeometry, on view: MTKView) {
        vertexCount = geo.vertices.count
        if geo.vertices.isEmpty {
            vertexBuffer = nil
        } else {
            vertexBuffer = view.device?.makeBuffer(
                bytes: geo.vertices,
                length: MemoryLayout<PointVertex>.stride * geo.vertices.count,
                options: .storageModeShared)
        }
        target = geo.center
        radius = Swift.max(geo.radius, 0.01)
        distance = radius * 2.6
        view.setNeedsDisplay()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspect = size.height > 0 ? Float(size.width / size.height) : 1
    }

    func draw(in view: MTKView) {
        guard let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmd = commandQueue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }

        if let buffer = vertexBuffer, vertexCount > 0 {
            var uniforms = PCUniforms(mvp: mvp(), pointSize: 7)
            enc.setRenderPipelineState(pipeline)
            enc.setDepthStencilState(depthState)
            enc.setVertexBuffer(buffer, offset: 0, index: 0)
            enc.setVertexBytes(&uniforms, length: MemoryLayout<PCUniforms>.stride, index: 1)
            enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertexCount)
        }
        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    private func eye() -> SIMD3<Float> {
        let ce = cos(elevation), se = sin(elevation)
        let ca = cos(azimuth), sa = sin(azimuth)
        return target + SIMD3<Float>(ce * sa, se, ce * ca) * distance
    }

    private func mvp() -> simd_float4x4 {
        let near = Swift.max(radius * 0.02, 0.01)
        let far = distance + radius * 8
        let proj = makePerspective(fovyRadians: .pi / 3, aspect: aspect, near: near, far: far)
        let viewM = makeLookAt(eye: eye(), center: target, up: SIMD3<Float>(0, 1, 0))
        return proj * viewM
    }
}
