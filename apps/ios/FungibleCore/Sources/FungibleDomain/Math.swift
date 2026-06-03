import Foundation

// Minimal, dependency-free linear algebra. We intentionally do NOT use `simd`
// here so the domain compiles and tests on Linux CI. The on-device Metal/ARKit
// layer can bridge these to `simd_float3` / `simd_float4x4` cheaply.

/// A 3D vector / point in some frame's coordinates (meters).
public struct Vector3: Equatable, Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(0, 0, 0)

    public static func + (a: Vector3, b: Vector3) -> Vector3 { Vector3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vector3, b: Vector3) -> Vector3 { Vector3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static func * (v: Vector3, s: Double) -> Vector3 { Vector3(v.x * s, v.y * s, v.z * s) }

    public func dot(_ o: Vector3) -> Double { x * o.x + y * o.y + z * o.z }
    public func cross(_ o: Vector3) -> Vector3 {
        Vector3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x)
    }
    public var length: Double { (x * x + y * y + z * z).squareRoot() }
    public func distance(to o: Vector3) -> Double { (self - o).length }
    public func normalized() -> Vector3 {
        let l = length
        return l > 0 ? self * (1.0 / l) : .zero
    }
}

/// A unit quaternion representing a rotation (w + xi + yj + zk).
public struct Quaternion: Equatable, Hashable, Codable, Sendable {
    public var w: Double
    public var x: Double
    public var y: Double
    public var z: Double

    public init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    public static let identity = Quaternion(w: 1, x: 0, y: 0, z: 0)

    public var length: Double { (w * w + x * x + y * y + z * z).squareRoot() }

    public func normalized() -> Quaternion {
        let l = length
        guard l > 0 else { return .identity }
        return Quaternion(w: w / l, x: x / l, y: y / l, z: z / l)
    }

    /// Hamilton product (self then `o` when applied right-to-left to vectors).
    public static func * (a: Quaternion, b: Quaternion) -> Quaternion {
        Quaternion(
            w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
            x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w
        )
    }

    public func inverse() -> Quaternion {
        // For a unit quaternion the inverse is the conjugate.
        let n = normalized()
        return Quaternion(w: n.w, x: -n.x, y: -n.y, z: -n.z)
    }

    /// Rotate a vector by this quaternion.
    public func act(_ v: Vector3) -> Vector3 {
        let q = normalized()
        let u = Vector3(q.x, q.y, q.z)
        let s = q.w
        // v' = 2(u·v)u + (s² - u·u)v + 2s(u×v)
        let t1 = u * (2.0 * u.dot(v))
        let t2 = v * (s * s - u.dot(u))
        let t3 = u.cross(v) * (2.0 * s)
        return t1 + t2 + t3
    }
}

/// A rigid-body transform (rotation + translation) mapping points from one
/// frame into another. Scale is fixed at 1 — LiDAR capture is metric.
public struct Transform: Equatable, Hashable, Codable, Sendable {
    public var rotation: Quaternion
    public var translation: Vector3

    public init(rotation: Quaternion = .identity, translation: Vector3 = .zero) {
        self.rotation = rotation
        self.translation = translation
    }

    public static let identity = Transform()

    /// Apply this transform to a point.
    public func apply(to point: Vector3) -> Vector3 {
        rotation.act(point) + translation
    }

    /// Compose: `self` applied after `other` (self ∘ other).
    public func composed(with other: Transform) -> Transform {
        Transform(
            rotation: (rotation * other.rotation).normalized(),
            translation: rotation.act(other.translation) + translation
        )
    }

    public func inverse() -> Transform {
        let invRot = rotation.inverse()
        return Transform(rotation: invRot, translation: invRot.act(translation) * -1.0)
    }
}
