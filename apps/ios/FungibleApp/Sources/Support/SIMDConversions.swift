import simd
import FungibleDomain

// Bridges ARKit's simd types to FungibleDomain's framework-free math. Kept tiny
// and isolated so the conversion (and ARKit's axis conventions) live in one place.

extension Vector3 {
    init(_ v: SIMD3<Float>) { self.init(Double(v.x), Double(v.y), Double(v.z)) }
    var simd3: SIMD3<Float> { SIMD3<Float>(Float(x), Float(y), Float(z)) }
}

extension Transform {
    /// Build from an ARKit 4×4 column-major transform (camera/anchor → world).
    init(_ m: simd_float4x4) {
        let q = simd_quatf(m)
        let t = m.columns.3
        self.init(
            rotation: Quaternion(w: Double(q.real),
                                 x: Double(q.imag.x),
                                 y: Double(q.imag.y),
                                 z: Double(q.imag.z)).normalized(),
            translation: Vector3(Double(t.x), Double(t.y), Double(t.z))
        )
    }

    /// 180° rotation about X. Folding this into `cameraToWorld` lets us reuse the
    /// generic pinhole `Unprojection` (which assumes +Z forward, +Y up) with
    /// ARKit camera space (−Z forward, −Y down in image coords). Verify on device.
    static let arkitAxisFlip = Transform(rotation: Quaternion(w: 0, x: 1, y: 0, z: 0))
}
