import SwiftUI
import FungibleDomain
import FungibleMeasure
import FungiblePresentation

/// Screen 06 — Cut / Fill (site vertical, the cutFillVolume capability). Set a
/// reference surface, drag the grade, and read cut vs. fill volumes computed
/// live on-device, plus a plan-view cut/fill map.
///
/// The cut/fill numbers are the REAL CutFillEngine math. On device the terrain
/// DEM comes from the captured cloud; here it's a deterministic synthetic
/// surface so the engine has something to integrate — the slider genuinely
/// recomputes against it. `project` (not `set`) to avoid the `set`-keyword trap.
struct CutFillView: View {
    let project: ScanSet
    /// Persist the computed result as a `volumeCutFill` measurement (ADR-0009).
    var onSave: (FungibleDomain.Measurement) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    enum Step { case surface, grade, map }
    enum Reference: String, CaseIterable, Identifiable {
        case flatPlane, bestFit, importDesign
        var id: String { rawValue }
        var title: String {
            switch self {
            case .flatPlane:    return "Flat plane at elevation"
            case .bestFit:      return "Best-fit to existing grade"
            case .importDesign: return "Import design surface"
            }
        }
        var blurb: String {
            switch self {
            case .flatPlane:    return "A level grade you set by height. Best for pads, lots, and level cuts."
            case .bestFit:      return "Fit a smooth surface through the current terrain — change vs. as-found."
            case .importDesign: return "Bring a LandXML / DXF target grade from your civil software."
            }
        }
        var soft: Bool { self == .importDesign }
    }

    @State private var step: Step = .surface
    @State private var reference: Reference = .flatPlane
    @State private var gradeY: Double = 0.762   // +2.5 ft default

    /// Synthetic terrain DEM (stand-in for the captured cloud's surface).
    private let terrain = CutFillView.sampleTerrain()

    // MARK: Real cut/fill math

    private var result: CutFillResult {
        CutFillEngine.compare(existing: terrain, toReferenceElevation: gradeY)
    }
    private var existingAverage: Double {
        let vals = terrain.heights.compactMap { $0 }
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }
    private var terrainAreaSqMeters: Double { Double(terrain.filledCellCount) * terrain.cellArea }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch step {
            case .surface: surfaceStep
            case .grade:   gradeStep
            case .map:     mapStep
            }
        }
    }

    private var header: some View {
        HStack {
            if step == .surface {
                Button("Cancel") { dismiss() }
            } else {
                Button { step = step == .map ? .grade : .surface } label: { Label("Back", systemImage: "chevron.left") }
            }
            Spacer()
            Text("Cut / Fill").font(.headline)
            Spacer()
            Button("Done") { dismiss() }.opacity(step == .map ? 1 : 0).disabled(step != .map)
        }
        .padding()
    }

    // MARK: - A: reference surface

    private var surfaceStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("REFERENCE SURFACE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(Reference.allCases) { ref in referenceRow(ref) }

                    Text("AREA").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 8)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Whole project").font(.subheadline.weight(.medium))
                            Text("\(DisplayFormat.areaFeetSquared(terrainAreaSqMeters)) · or draw a boundary")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Draw area") {}.font(.subheadline).disabled(true)
                    }

                    Label("Cut/Fill needs terrain captured as a surface. This is a site project, so it's available — interior and object scans won't show this tool.",
                          systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            }
            primaryButton("Set grade") { step = .grade }
        }
    }

    private func referenceRow(_ ref: Reference) -> some View {
        Button { reference = ref } label: {
            HStack(spacing: 12) {
                Image(systemName: reference == ref ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(reference == ref ? Color.accentColor : Color.secondary.opacity(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(ref.title).font(.subheadline.weight(.medium))
                        if ref.soft {
                            Text("Pro").font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(ref.blurb).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - B: grade slider + live cut/fill

    private var gradeStep: some View {
        VStack(spacing: 0) {
            section
            primaryButton("Contours") { step = .map }
        }
    }

    private var section: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cutFillReadout
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Grade elevation").font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%+.2f ft", Units.feet(gradeY)))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    Slider(value: $gradeY, in: -1.524...1.524)
                    HStack {
                        Text(String(format: "%.0f ft", Units.feet(-1.524)))
                        Spacer()
                        Button { gradeY = existingAverage } label: { Text("existing avg").underline() }
                        Spacer()
                        Text(String(format: "+%.0f ft", Units.feet(1.524)))
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
                Button { saveResult(); step = .map } label: { Label("Save result", systemImage: "tray.and.arrow.down") }
                    .font(.subheadline)
            }
            .padding()
        }
    }

    private var cutFillReadout: some View {
        let cutYd = Units.cubicYards(result.cutVolume)
        let fillYd = Units.cubicYards(result.fillVolume)
        let net = result.netVolume          // m³ (fill − cut)
        let netCut = net < 0
        let netYd = Units.cubicYards(abs(net))
        let loads = DisplayFormat.truckLoads(abs(net))
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                volumeCard("Cut", value: Int(cutYd.rounded()), caption: "yd³ · remove")
                volumeCard("Fill", value: Int(fillYd.rounded()), caption: "yd³ · add")
            }
            VStack(spacing: 2) {
                Text("Net — \(netCut ? "export off site" : "import to site")")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(Int(netYd.rounded())) yd³ \(netCut ? "cut" : "fill")"
                     + (loads.map { " · \($0)" } ?? ""))
                    .font(.headline)
            }
        }
    }

    private func volumeCard(_ title: String, value: Int, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(value)").font(.system(size: 40, weight: .semibold)).monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.95), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - C: plan-view cut/fill map

    private var mapStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Contour map · 1 ft interval").font(.subheadline.weight(.medium))
                    cutFillMap
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 16) {
                        legendSwatch("Cut zones", white: 0.25)
                        legendSwatch("Fill zones", white: 0.72)
                    }
                    Text("Balance at grade \(String(format: "%+.2f ft", Units.feet(gradeY))) · \(Int(Units.cubicYards(abs(result.netVolume)).rounded())) yd³ net \(result.netVolume < 0 ? "cut" : "fill")")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button { } label: { Label("Export DXF", systemImage: "square.and.arrow.up") }
                        Spacer()
                        Button { } label: { Label("Add to report", systemImage: "doc.text") }
                    }
                    .font(.subheadline).padding(.top, 4)
                }
                .padding()
            }
        }
    }

    private var cutFillMap: some View {
        Canvas { ctx, size in
            let cols = terrain.columns, rows = terrain.rows
            let w = size.width / Double(cols), h = size.height / Double(rows)
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let e = terrain.height(col: c, row: r) else { continue }
                    let diff = gradeY - e                       // >0 fill, <0 cut
                    let mag = min(1.0, abs(diff) / 1.0)
                    let white = diff < 0 ? 0.25 : 0.72          // cut darker, fill lighter
                    let rect = CGRect(x: Double(c) * w, y: Double(r) * h, width: w + 1, height: h + 1)
                    ctx.fill(Path(rect), with: .color(Color(white: white).opacity(0.35 + 0.55 * mag)))
                }
            }
        }
        .background(Color(white: 0.5))
    }

    private func legendSwatch(_ label: String, white: Double) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(Color(white: white)).frame(width: 16, height: 16)
            Text(label).font(.caption)
        }
    }

    // MARK: - Reusable

    private func primaryButton(_ title: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding()
    }

    /// Persist the live cut/fill result as a labeled `volumeCutFill` measurement.
    /// `Measurement` carries geometry + a label (not volumes), so the headline
    /// numbers ride in the label until a richer result type lands.
    private func saveResult() {
        let net = result.netVolume
        let netYd = Int(Units.cubicYards(abs(net)).rounded())
        let label = "Net \(netYd) yd³ \(net < 0 ? "cut" : "fill") @ "
            + String(format: "%+.2f ft", Units.feet(gradeY))
        onSave(FungibleDomain.Measurement(kind: .volumeCutFill, points: [], label: label))
    }

    // MARK: - Synthetic terrain

    static func sampleTerrain() -> HeightGrid {
        let cols = 22, rows = 22, cell = 0.85   // ~18.7 m span ≈ 350 m²
        var heights: [Double?] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let x = Double(c) / Double(cols), z = Double(r) / Double(rows)
                let slope = (x * 0.9 - 0.4) + (z * 0.5 - 0.25)
                let undulation = sin(x * 6) * 0.12 + cos(z * 5) * 0.10
                heights.append(slope + undulation)
            }
        }
        return HeightGrid(originX: 0, originZ: 0, cellSize: cell, columns: cols, rows: rows, heights: heights)
    }
}
