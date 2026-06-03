import Foundation
import FungibleDomain
import FungibleCapture

/// CPU unprojection of a depth frame into the shared voxel accumulator. This is
/// the correct, tested path (it calls `FungibleCapture.Unprojection`, the same
/// math the Metal shader mirrors). It samples on a pixel stride to stay cheap;
/// the Metal path (`PointCloudUnprojector.metal`) is the throughput optimization
/// for later. RGB sampling from the captured image is a follow-up — points are
/// shaded by confidence for now.
enum DepthUnprojector {
    static func accumulate(
        frame: DepthFrameData,
        filter: ConfidenceFilter,
        pixelStride: Int = 2,
        into accumulator: inout VoxelAccumulator
    ) {
        let w = frame.width
        let h = frame.height
        var v = 0
        while v < h {
            var u = 0
            while u < w {
                let i = v * w + u
                let depth = Double(frame.depth[i])
                let conf = DepthConfidence(rawValue: Int(frame.confidence[i])) ?? .low
                if filter.keep(confidence: conf, depthMeters: depth) {
                    let world = Unprojection.worldPoint(
                        u: Double(u), v: Double(v), depth: depth,
                        intrinsics: frame.intrinsics,
                        cameraToWorld: frame.cameraToWorld
                    )
                    let shade = UInt8(85 * (conf.rawValue + 1)) // 85/170/255
                    accumulator.insert(CapturedPoint(position: world, confidence: conf,
                                                     r: shade, g: shade, b: shade))
                }
                u += pixelStride
            }
            v += pixelStride
        }
    }
}
