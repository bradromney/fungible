import SwiftUI
import FungibleDomain
import FungibleInsights
import FungiblePresentation

/// Screen 07 — Site Report. The FungibleInsights deliverable: a generated,
/// plain-language site summary (imperial) with a key-facts grid, a narrative,
/// and findings pulled from the project (measurements + annotations). A view of
/// project data, never a re-entry.
///
/// The narrative is the REAL deterministic `ReportService` output computed from
/// the ScanSet — the offline floor. The LLM-enhanced version is the `/report`
/// API path (when ANTHROPIC_API_KEY is set). Sharing a PDF/web link via the iOS
/// share sheet is the next integration.
struct SiteReportView: View {
    let set: ScanSet
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0          // generation progress (0…4)
    @State private var narrative = ""
    @State private var ready = false

    private let steps = [
        "Analyzed combined point cloud",
        "Pulled in measurements & notes",
        "Computing site facts & volumes",
        "Writing the summary",
    ]

    // MARK: Real report input derived from the project

    // `self.` required: a computed-property body starting with the token `set`
    // is parsed as a setter accessor.
    private var totalPoints: Int { self.set.scans.reduce(0) { $0 + $1.pointCloud.pointCount } }
    private var areaMeasurement: Double? {
        self.set.measurements.filter { $0.kind == .area }.map(\.planArea).max()
    }
    private var reportInput: SiteReportInput {
        SiteReportInput(
            siteName: set.name.isEmpty ? "Untitled site" : set.name,
            areaSquareMeters: areaMeasurement,
            pointCount: totalPoints,
            units: .imperial
        )
    }

    var body: some View {
        Group {
            if ready { report } else { generating }
        }
        .navigationTitle("Site report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .task { await generate() }
    }

    // MARK: - Generating

    private var generating: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Writing your site report").font(.title3.weight(.semibold))
            Text("Reading the cloud, your measurements, and notes — then summarizing in plain language.")
                .font(.subheadline).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                    HStack(spacing: 12) {
                        Image(systemName: index < step ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(index < step ? Color.green : Color.secondary.opacity(0.4))
                        Text(label)
                            .foregroundStyle(index < step ? .primary : .secondary)
                        if index == step { ProgressView().scaleEffect(0.8) }
                    }
                    .font(.subheadline)
                }
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Report

    private var report: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                factsGrid
                summarySection
                findings
                disclaimer
                shareButton
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FUNGIBLEINSIGHTS")
                .font(.caption2.weight(.bold)).foregroundStyle(Color.accentColor)
                .tracking(1.5)
            Text(set.name.isEmpty ? "Untitled site" : set.name)
                .font(.title2.weight(.bold))
            Text(provenance).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var provenance: String {
        var parts = [DisplayFormat.passCount(set.scanCount)]
        let date = set.scans.map(\.capturedAt).max() ?? set.createdAt
        parts.append("captured " + shortDate(date))
        if let area = areaMeasurement { parts.append(DisplayFormat.areaFeetSquared(area)) }
        return parts.joined(separator: " · ")
    }

    private var factsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            factCard("Plan area", areaMeasurement.map(DisplayFormat.areaFeetSquared) ?? "Add a measurement")
            factCard("Points", DisplayFormat.pointCount(totalPoints))
            factCard("Passes", "\(set.scanCount)")
            factCard("Annotations", "\(set.annotations.count)")
        }
    }

    private func factCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(white: 0.95), in: RoundedRectangle(cornerRadius: 12))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Summary").font(.headline)
                Spacer()
                Label("Generated · review before sharing", systemImage: "sparkles")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(narrative.isEmpty ? "—" : narrative)
                .font(.body).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var findings: some View {
        if !set.measurements.isEmpty || !set.annotations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !set.measurements.isEmpty {
                    Text("Measurements & earthwork").font(.headline)
                    ForEach(set.measurements) { m in measurementRow(m) }
                }
                if !set.annotations.isEmpty {
                    Text("Flagged on site").font(.headline).padding(.top, 4)
                    ForEach(Array(set.annotations.enumerated()), id: \.element.id) { i, a in
                        annotationRow(number: i + 1, text: a.text)
                    }
                }
            }
        } else {
            Text("Add measurements and notes (Measure & Annotate) to enrich this report — it updates from the same project data.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func measurementRow(_ m: FungibleDomain.Measurement) -> some View {
        let value: String
        switch m.kind {
        case .distance:      value = DisplayFormat.feetInches(m.polylineLength)
        case .area:          value = DisplayFormat.areaFeetSquared(m.planArea)
        case .volumeCutFill: value = DisplayFormat.areaFeetSquared(m.planArea) + " footprint"
        }
        return HStack {
            Text(m.label ?? defaultLabel(m.kind)).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 6)
    }

    private func defaultLabel(_ kind: FungibleDomain.Measurement.Kind) -> String {
        switch kind {
        case .distance:      return "Distance"
        case .area:          return "Plan area"
        case .volumeCutFill: return "Volume"
        }
    }

    private func annotationRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption2.bold()).foregroundStyle(.white)
                .frame(width: 22, height: 22).background(Color.accentColor, in: Circle())
            Text(text).font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About this report").font(.caption.weight(.semibold))
            Text("Figures are derived from a LiDAR capture and may vary from a stamped survey. Units: US feet & cubic yards. Generated by FungibleInsights — review before sending to a client.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(white: 0.95), in: RoundedRectangle(cornerRadius: 12))
    }

    private var shareButton: some View {
        Button {
            // Real share (PDF / web link via UIActivityViewController) is next.
        } label: {
            Label("Share report", systemImage: "square.and.arrow.up")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Generation

    private func generate() async {
        for s in 1...steps.count {
            try? await Task.sleep(nanoseconds: 450_000_000)
            await MainActor.run { step = s }
        }
        let text = await ReportService().report(for: reportInput)
        await MainActor.run {
            narrative = text
            ready = true
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
