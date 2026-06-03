import Foundation
import FungibleDomain

// Minimal, dependency-free DXF (R12 ASCII) writer — the CAD interchange the
// consumer scanners skip (research §9). It emits LINE/POINT/TEXT entities, which
// every CAD/GIS tool reads. Higher-level callers turn measurements and contour
// segments into these primitives. LandXML/IFC are separate (IFC via the bridged
// IfcOpenShell, run server-side).
//
// Coordinate mapping: our frame is X=east, Y=up, Z=north. DXF is a plan view, so
// we map → DXF X=east(x), DXF Y=north(z), DXF Z=elevation(y). That yields a
// correct top-down survey drawing with elevation as the Z ordinate.
public struct DXFDrawing {
    public struct Line { public var a: Vector3; public var b: Vector3; public var layer: String }
    public struct Point { public var position: Vector3; public var layer: String }
    public struct Text { public var position: Vector3; public var content: String; public var height: Double; public var layer: String }

    public var lines: [Line] = []
    public var points: [Point] = []
    public var texts: [Text] = []

    public init() {}

    public mutating func addLine(_ a: Vector3, _ b: Vector3, layer: String = "0") {
        lines.append(Line(a: a, b: b, layer: layer))
    }

    public mutating func addPoint(_ p: Vector3, layer: String = "0") {
        points.append(Point(position: p, layer: layer))
    }

    public mutating func addText(_ content: String, at p: Vector3, height: Double = 0.25, layer: String = "0") {
        texts.append(Text(position: p, content: content, height: height, layer: layer))
    }

    /// Add a polyline as connected LINE segments (R12-universal).
    public mutating func addPolyline(_ vertices: [Vector3], layer: String = "0") {
        guard vertices.count >= 2 else { return }
        for i in 1..<vertices.count {
            addLine(vertices[i - 1], vertices[i], layer: layer)
        }
    }
}

public struct DXFExporter {
    public init() {}

    public func data(for drawing: DXFDrawing) -> Data {
        Data(encode(drawing).utf8)
    }

    public func encode(_ drawing: DXFDrawing) -> String {
        var s = "0\nSECTION\n2\nENTITIES\n"
        for line in drawing.lines {
            s += "0\nLINE\n8\n\(line.layer)\n"
            s += pair(10, 20, 30, line.a)
            s += pair(11, 21, 31, line.b)
        }
        for point in drawing.points {
            s += "0\nPOINT\n8\n\(point.layer)\n"
            s += pair(10, 20, 30, point.position)
        }
        for text in drawing.texts {
            s += "0\nTEXT\n8\n\(text.layer)\n"
            s += pair(10, 20, 30, text.position)
            s += "40\n\(num(text.height))\n1\n\(text.content)\n"
        }
        s += "0\nENDSEC\n0\nEOF\n"
        return s
    }

    // DXF group-code triples, applying the plan-view coordinate mapping.
    private func pair(_ xCode: Int, _ yCode: Int, _ zCode: Int, _ v: Vector3) -> String {
        "\(xCode)\n\(num(v.x))\n\(yCode)\n\(num(v.z))\n\(zCode)\n\(num(v.y))\n"
    }

    private func num(_ d: Double) -> String {
        String(format: "%.6f", d)
    }
}
