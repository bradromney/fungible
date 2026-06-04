import Foundation
import FungibleDomain

// Two pure functions over SiteReportInput:
//  • `summary` — a deterministic, no-AI plain-language report. The feature works
//    fully offline and is unit-tested; this is the floor, not a placeholder.
//  • `prompt` — a strict, facts-only instruction for an LLM to *enhance* the
//    narrative (richer phrasing, next-steps), constrained to the measured
//    numbers so it can't invent figures. This is the "is the LLM actually
//    useful" seam: the deterministic output is always available; the LLM is an
//    optional polish layer (ADR — AI as enhancement, not dependency).
public enum ReportComposer {
    public static func summary(_ input: SiteReportInput) -> String {
        var parts: [String] = []
        parts.append("\(input.siteName):")

        if let net = input.netVolume {
            let verb = net >= 0 ? "net fill" : "net cut"
            parts.append("\(verb) of \(vol(abs(net), input.units))")
            if let area = input.areaSquareMeters {
                parts.append("over \(area2(area, input.units))")
            }
            parts.append("(cut \(vol(input.cutVolume ?? 0, input.units)), fill \(vol(input.fillVolume ?? 0, input.units))).")
            if input.fillTruckloads > 0 {
                parts.append("Fill ≈ \(input.fillTruckloads) truckload\(plural(input.fillTruckloads)).")
            }
            if input.cutTruckloads > 0 {
                parts.append("Cut ≈ \(input.cutTruckloads) truckload\(plural(input.cutTruckloads)).")
            }
        } else if let area = input.areaSquareMeters {
            parts.append("plan area \(area2(area, input.units)).")
        }

        for fact in input.facts {
            parts.append("\(fact.label): \(fact.value).")
        }

        if input.pointCount > 0 {
            parts.append("Captured from \(input.pointCount) points.")
        }

        return parts.joined(separator: " ")
    }

    public static func prompt(_ input: SiteReportInput) -> String {
        var lines = [
            "Write a concise, client-ready site summary for a construction/landscaping/3D-capture professional.",
            "Use ONLY the measured facts below — do not invent or round beyond one decimal. Output 2–3 sentences then a short bulleted next-steps list.",
            "",
            "Facts:",
            "- Site: \(input.siteName)",
        ]
        if let area = input.areaSquareMeters { lines.append("- Plan area: \(area2(area, input.units))") }
        if let cut = input.cutVolume { lines.append("- Cut: \(vol(cut, input.units))") }
        if let fill = input.fillVolume { lines.append("- Fill: \(vol(fill, input.units))") }
        if let net = input.netVolume {
            lines.append("- Net: \(vol(abs(net), input.units)) (\(net >= 0 ? "fill" : "cut"))")
        }
        if input.fillTruckloads > 0 { lines.append("- Fill haul: ~\(input.fillTruckloads) truckloads @ \(fmt(input.truckCapacityCubicMeters)) m³") }
        for fact in input.facts { lines.append("- \(fact.label): \(fact.value)") }
        if input.pointCount > 0 { lines.append("- Point count: \(input.pointCount)") }
        return lines.joined(separator: "\n")
    }

    private static func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
    private static func plural(_ n: Int) -> String { n == 1 ? "" : "s" }

    /// Volume string in the requested units (m³ metric, yd³ imperial).
    private static func vol(_ cubicMeters: Double, _ system: UnitSystem) -> String {
        switch system {
        case .metric: return "\(fmt(cubicMeters)) m³"
        case .imperial: return "\(fmt(Units.cubicYards(cubicMeters))) yd³"
        }
    }

    /// Area string in the requested units (m² metric, ft² imperial).
    private static func area2(_ sqMeters: Double, _ system: UnitSystem) -> String {
        switch system {
        case .metric: return "\(fmt(sqMeters)) m²"
        case .imperial: return "\(fmt(Units.squareFeet(sqMeters))) ft²"
        }
    }
}
