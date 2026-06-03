import Foundation

// Lightweight georeferencing (research §9 / competitive gap): get a set into a
// real-world CRS without an RTK rig. The user anchors the local scan frame to a
// known coordinate — a GPS fix, a surveyed control point, or a benchmark — and
// we carry the translation. Full datum/projection math (UTM, State Plane) is
// applied server-side via PROJ; this is the on-device anchor that makes export
// georeferenced. Rotation-to-true-north and scale are future refinements (scale
// is already metric from LiDAR).

public extension CoordinateReference {
    /// Map a point from the local scan frame into CRS coordinates (meters).
    func toCRS(_ point: Vector3) -> Vector3 { point + originOffset }

    /// Map a CRS coordinate back into the local scan frame.
    func toLocal(_ point: Vector3) -> Vector3 { point - originOffset }

    /// Build a reference by anchoring a known local point to its real-world CRS
    /// coordinate. `originOffset` is chosen so `toCRS(localPoint) == crsPoint`.
    static func anchored(epsg: String?, localPoint: Vector3, crsPoint: Vector3) -> CoordinateReference {
        CoordinateReference(epsg: epsg, originOffset: crsPoint - localPoint)
    }
}
