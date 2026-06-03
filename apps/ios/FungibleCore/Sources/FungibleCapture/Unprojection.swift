import Foundation
import FungibleDomain

// The device-independent core of the capture pipeline (M1). ARKit/Metal live in
// the app target; this module holds the *math* — depth→world unprojection and
// bounded voxel accumulation — as pure Swift so it is unit-tested on CI and the
// Metal compute shader can mirror it exactly. The app's ARFrame→DepthFrame
// adapter feeds these types.

/// Pinhole camera intrinsics (pixels), as provided by ARKit's camera.
public struct CameraIntrinsics: Equatable, Sendable {
    public var fx: Double
    public var fy: Double
    public var cx: Double
    public var cy: Double

    public init(fx: Double, fy: Double, cx: Double, cy: Double) {
        self.fx = fx
        self.fy = fy
        self.cx = cx
        self.cy = cy
    }
}

/// ARKit per-pixel depth confidence (`ARConfidenceLevel`: 0 low … 2 high).
public enum DepthConfidence: Int, Codable, Sendable, Comparable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: DepthConfidence, rhs: DepthConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single unprojected point with color and confidence, in the set's frame.
public struct CapturedPoint: Equatable, Sendable {
    public var position: Vector3
    public var confidence: DepthConfidence
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(position: Vector3, confidence: DepthConfidence, r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0) {
        self.position = position
        self.confidence = confidence
        self.r = r
        self.g = g
        self.b = b
    }
}

public enum Unprojection {
    /// Back-project a depth-map pixel into camera space (meters). Camera looks
    /// down +Z here; the supplied `cameraToWorld` carries ARKit's actual
    /// orientation/sign convention, so this stays a pure pinhole transform.
    public static func cameraPoint(u: Double, v: Double, depth: Double, intrinsics: CameraIntrinsics) -> Vector3 {
        let x = (u - intrinsics.cx) * depth / intrinsics.fx
        let y = (v - intrinsics.cy) * depth / intrinsics.fy
        return Vector3(x, y, depth)
    }

    /// Back-project a depth-map pixel directly into the world/set frame.
    public static func worldPoint(
        u: Double, v: Double, depth: Double,
        intrinsics: CameraIntrinsics,
        cameraToWorld: Transform
    ) -> Vector3 {
        cameraToWorld.apply(to: cameraPoint(u: u, v: v, depth: depth, intrinsics: intrinsics))
    }
}

/// Decides which depth samples survive (research §1: confidence + range are the
/// two cheapest, highest-value filters; iPhone LiDAR degrades badly past ~5 m).
public struct ConfidenceFilter: Sendable {
    public var minConfidence: DepthConfidence
    public var maxRangeMeters: Double

    public init(minConfidence: DepthConfidence = .medium, maxRangeMeters: Double = 5.0) {
        self.minConfidence = minConfidence
        self.maxRangeMeters = maxRangeMeters
    }

    /// Keep a sample only if it is confident enough and within reliable range.
    public func keep(confidence: DepthConfidence, depthMeters: Double) -> Bool {
        confidence >= minConfidence && depthMeters > 0 && depthMeters <= maxRangeMeters
    }
}
