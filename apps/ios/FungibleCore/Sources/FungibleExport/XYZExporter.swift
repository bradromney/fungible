import Foundation
import FungibleDomain
import FungibleCapture

/// ASCII XYZ: one `x y z r g b` line per point. The universal lowest-common-
/// denominator format — every point-cloud tool reads it.
public struct XYZExporter: PointCloudExporter {
    public var format: ExportFormat { .xyz }

    public init() {}

    public func data(for points: [CapturedPoint]) -> Data {
        var text = ""
        text.reserveCapacity(points.count * 24)
        for p in points {
            text += "\(Float(p.position.x)) \(Float(p.position.y)) \(Float(p.position.z)) \(p.r) \(p.g) \(p.b)\n"
        }
        return Data(text.utf8)
    }
}
