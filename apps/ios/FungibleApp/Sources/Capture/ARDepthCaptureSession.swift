import ARKit
import FungibleDomain
import FungibleCapture

/// A snapshot of one ARKit depth frame, copied out of the `ARFrame` immediately
/// (the frame-pool retention footgun — research §1) so downstream work never
/// holds the frame. All `Sendable` value data.
struct DepthFrameData: @unchecked Sendable {
    let width: Int
    let height: Int
    let depth: [Float]          // meters, row-major, length width*height
    let confidence: [UInt8]     // 0/1/2, same layout
    let intrinsics: CameraIntrinsics // scaled to the depth-map resolution
    /// camera→world already composed with the ARKit axis flip, so it feeds
    /// `Unprojection.worldPoint` directly.
    let cameraToWorld: Transform
    let rawCameraTransform: simd_float4x4
    let ambientIntensity: Double?
    let trackingState: ARCamera.TrackingState
    let timestamp: TimeInterval
}

/// Owns the `ARSession` and streams throttled `DepthFrameData` to a handler.
final class ARDepthCaptureSession: NSObject, ARSessionDelegate {
    let session = ARSession()
    /// Process roughly every Nth frame to bound CPU/thermals during capture.
    var frameStride = 3
    var onFrame: ((DepthFrameData) -> Void)?

    private var frameIndex = 0

    func start() {
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        session.delegate = self
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() { session.pause() }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        frameIndex += 1
        guard frameIndex % frameStride == 0 else { return }
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }
        guard let snapshot = Self.snapshot(frame: frame, depth: depthData) else { return }
        onFrame?(snapshot)
    }

    // MARK: - Extraction

    private static func snapshot(frame: ARFrame, depth: ARDepthData) -> DepthFrameData? {
        let depthMap = depth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let depthValues = copyFloatBuffer(depthMap, count: width * height)
        guard !depthValues.isEmpty else { return nil }

        let confidenceValues: [UInt8]
        if let conf = depth.confidenceMap {
            confidenceValues = copyByteBuffer(conf, count: width * height)
        } else {
            confidenceValues = [UInt8](repeating: 2, count: width * height) // assume high
        }

        // ARKit intrinsics are in captured-image pixels; scale to depth-map res.
        let image = frame.camera.imageResolution
        let k = frame.camera.intrinsics
        let sx = Double(width) / Double(image.width)
        let sy = Double(height) / Double(image.height)
        let intrinsics = CameraIntrinsics(
            fx: Double(k[0][0]) * sx, fy: Double(k[1][1]) * sy,
            cx: Double(k[2][0]) * sx, cy: Double(k[2][1]) * sy
        )

        let cameraToWorld = Transform(frame.camera.transform).composed(with: .arkitAxisFlip)

        var ambient: Double?
        if let light = frame.lightEstimate { ambient = Double(light.ambientIntensity) }

        return DepthFrameData(
            width: width, height: height,
            depth: depthValues, confidence: confidenceValues,
            intrinsics: intrinsics,
            cameraToWorld: cameraToWorld,
            rawCameraTransform: frame.camera.transform,
            ambientIntensity: ambient,
            trackingState: frame.camera.trackingState,
            timestamp: frame.timestamp
        )
    }

    private static func copyFloatBuffer(_ pb: CVPixelBuffer, count: Int) -> [Float] {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return [] }
        let ptr = base.assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: ptr, count: count))
    }

    private static func copyByteBuffer(_ pb: CVPixelBuffer, count: Int) -> [UInt8] {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return [] }
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: ptr, count: count))
    }
}
