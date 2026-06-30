import simd
import FungibleDomain
import FungibleCapture
import FungibleStorage

/// One renderable point: position in the set's world frame (meters) + RGB color.
/// Packed POD so an array uploads straight into a Metal vertex buffer.
struct PointVertex {
    var position: SIMD3<Float>
    var color: SIMD3<Float>
}

/// Matches `PCUniforms` in PointCloud.metal (float4x4 + float).
struct PCUniforms {
    var mvp: simd_float4x4
    var pointSize: Float
}

/// A renderable cloud plus the framing the orbit camera needs.
struct CloudGeometry {
    var vertices: [PointVertex]
    var center: SIMD3<Float>
    var radius: Float

    static let empty = CloudGeometry(vertices: [], center: .zero, radius: 1)
}

/// Reads a project's point-cloud blobs from the store and turns them into a
/// renderable cloud. Colour is a height/confidence ramp for now (real captured
/// RGB lands in Phase 4). Off the main actor so large reads don't jank the UI.
enum PointCloudLoader {
    static func load(scans: [Scan], from store: any ScanStore, maxPoints: Int = 1_500_000) async -> CloudGeometry {
        var points: [CapturedPoint] = []
        for scan in scans {
            if let p = try? await store.readBlob(scan.pointCloud) {
                points.append(contentsOf: p)
            }
        }
        return geometry(from: points, maxPoints: maxPoints)
    }

    static func geometry(from points: [CapturedPoint], maxPoints: Int) -> CloudGeometry {
        guard !points.isEmpty else { return .empty }

        // Deterministic subsample if the cloud exceeds the cap.
        let step = Swift.max(1, points.count / Swift.max(maxPoints, 1))

        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var kept: [SIMD3<Float>] = []
        var confs: [Float] = []
        kept.reserveCapacity(points.count / step + 1)

        var i = 0
        while i < points.count {
            let p = points[i]
            let v = SIMD3<Float>(Float(p.position.x), Float(p.position.y), Float(p.position.z))
            lo = simd_min(lo, v); hi = simd_max(hi, v)
            kept.append(v)
            confs.append(p.confidence == .high ? 1.0 : (p.confidence == .medium ? 0.8 : 0.55))
            i += step
        }

        let center = (lo + hi) * 0.5
        let radius = Swift.max(simd_length(hi - lo) * 0.5, 0.01)
        let span = Swift.max(hi.y - lo.y, 0.001)

        var verts: [PointVertex] = []
        verts.reserveCapacity(kept.count)
        for idx in kept.indices {
            let v = kept[idx]
            let t = (v.y - lo.y) / span
            verts.append(PointVertex(position: v, color: colormap(t) * confs[idx]))
        }
        return CloudGeometry(vertices: verts, center: center, radius: radius)
    }

    /// Blue (low) → green (mid) → amber (high). A readable elevation ramp.
    static func colormap(_ t: Float) -> SIMD3<Float> {
        let x = Swift.min(Swift.max(t, 0), 1)
        let blue = SIMD3<Float>(0.22, 0.45, 0.95)
        let green = SIMD3<Float>(0.25, 0.85, 0.45)
        let amber = SIMD3<Float>(0.96, 0.74, 0.22)
        if x < 0.5 {
            return lerp(blue, green, x / 0.5)
        } else {
            return lerp(green, amber, (x - 0.5) / 0.5)
        }
    }

    private static func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ u: Float) -> SIMD3<Float> {
        a + (b - a) * u
    }
}
