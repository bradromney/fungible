import Foundation

/// Measurements and annotations attach to a ScanSet and are exportable to
/// DXF/IFC/LandXML. They reference points in the set's coordinate frame.
public struct Measurement: Identifiable, Equatable, Codable, Sendable {
    public enum Kind: Equatable, Codable, Sendable {
        case distance        // polyline length over `points`
        case area            // planar area of the polygon `points`
        case volumeCutFill   // cut/fill vs a reference surface (see CutFill)
    }

    public let id: MeasurementID
    public var kind: Kind
    /// Ordered vertices defining the measurement, in the set's frame (meters).
    public var points: [Vector3]
    public var label: String?
    public var createdAt: Date

    public init(
        id: MeasurementID = MeasurementID(),
        kind: Kind,
        points: [Vector3],
        label: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.points = points
        self.label = label
        self.createdAt = createdAt
    }

    /// Total length of the polyline through `points` (meters). Zero for <2 pts.
    public var polylineLength: Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            total += points[i].distance(to: points[i - 1])
        }
        return total
    }

    /// Plan-view (horizontal) area of the polygon `points`, projected onto the
    /// XZ ground plane via the shoelace formula (m²). This is the footprint area
    /// surveyors/landscapers quote — independent of slope. Zero for <3 points.
    public var planArea: Double {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        for i in 0..<points.count {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            sum += a.x * b.z - b.x * a.z
        }
        return abs(sum) / 2.0
    }

    /// Closed-loop perimeter of `points` (m): the polyline length plus the
    /// segment back to the start. Zero for <3 points.
    public var closedPerimeter: Double {
        guard points.count >= 3 else { return 0 }
        return polylineLength + points[points.count - 1].distance(to: points[0])
    }
}

/// A free-form note pinned to a location in the set (for sharing/handoff).
public struct Annotation: Identifiable, Equatable, Codable, Sendable {
    public let id: AnnotationID
    public var position: Vector3
    public var text: String
    public var createdAt: Date

    public init(
        id: AnnotationID = AnnotationID(),
        position: Vector3,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.position = position
        self.text = text
        self.createdAt = createdAt
    }
}
