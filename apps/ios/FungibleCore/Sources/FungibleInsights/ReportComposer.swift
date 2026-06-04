import Foundation

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
            parts.append("\(verb) of \(fmt(abs(net))) m³")
            if let area = input.areaSquareMeters {
                parts.append("over \(fmt(area)) m²")
            }
            parts.append("(cut \(fmt(input.cutVolume ?? 0)) m³, fill \(fmt(input.fillVolume ?? 0)) m³).")
            if input.fillTruckloads > 0 {
                parts.append("Fill ≈ \(input.fillTruckloads) truckload\(plural(input.fillTruckloads)).")
            }
            if input.cutTruckloads > 0 {
                parts.append("Cut ≈ \(input.cutTruckloads) truckload\(plural(input.cutTruckloads)).")
            }
        } else if let area = input.areaSquareMeters {
            parts.append("plan area \(fmt(area)) m².")
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
        if let area = input.areaSquareMeters { lines.append("- Plan area: \(fmt(area)) m²") }
        if let cut = input.cutVolume { lines.append("- Cut: \(fmt(cut)) m³") }
        if let fill = input.fillVolume { lines.append("- Fill: \(fmt(fill)) m³") }
        if let net = input.netVolume {
            lines.append("- Net: \(fmt(abs(net))) m³ (\(net >= 0 ? "fill" : "cut"))")
        }
        if input.fillTruckloads > 0 { lines.append("- Fill haul: ~\(input.fillTruckloads) truckloads @ \(fmt(input.truckCapacityCubicMeters)) m³") }
        for fact in input.facts { lines.append("- \(fact.label): \(fact.value)") }
        if input.pointCount > 0 { lines.append("- Point count: \(input.pointCount)") }
        return lines.joined(separator: "\n")
    }

    private static func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
    private static func plural(_ n: Int) -> String { n == 1 ? "" : "s" }
}
