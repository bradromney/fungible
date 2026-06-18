import SwiftUI
import FungibleDomain
import FungibleEntitlements
import FungiblePresentation

/// Screen 05 — Convert / Export. The interop hero: pick a target format from the
/// real `ExportCatalog`, set options, choose a destination, export in the
/// background. Three steps in one modal (pick → options → exporting). Formats are
/// never locked in the free MVP — paywall candidates get a quiet ✦ badge.
///
/// The exporting step shows the wireframe's background-progress state. Wiring it
/// to the real FungibleExport writers + the iOS share sheet (UIActivityViewController)
/// is the next integration; the progress here is the UI state, not a real write.
struct ExportSheet: View {
    let set: ScanSet
    @Environment(\.dismiss) private var dismiss
    private let entitlements = EntitlementsService(entitlements: .mvpFreeEverything)

    enum Step { case pickFormat, options, exporting }

    enum Destination: String, CaseIterable, Identifiable {
        case shareSheet, hostedLink, cadHandoff
        var id: String { rawValue }
        var title: String {
            switch self {
            case .shareSheet: return "Share sheet"
            case .hostedLink: return "Hosted link"
            case .cadHandoff: return "CAD handoff"
            }
        }
        var subtitle: String {
            switch self {
            case .shareSheet: return "AirDrop, Files, Mail, other apps"
            case .hostedLink: return "Web viewer URL anyone can open"
            case .cadHandoff: return "Send to a connected cloud drive"
            }
        }
        var symbol: String {
            switch self {
            case .shareSheet: return "square.and.arrow.up"
            case .hostedLink: return "link"
            case .cadHandoff: return "externaldrive.badge.icloud"
            }
        }
        /// hostedLink → webShare, cadHandoff → byoCloud (paywall candidates).
        var soft: Bool { self != .shareSheet }
    }

    @State private var step: Step = .pickFormat
    @State private var filter: ExportFormat.Intent? = nil   // nil = All
    @State private var selectedID: String = ExportCatalog.all[0].id
    @State private var cropToRegion = false
    @State private var includeAnnotations = true
    @State private var units: UnitSystem = .imperial
    @State private var destination: Destination = .shareSheet
    @State private var progress: Double = 0

    // MARK: Derived

    private var selected: ExportFormat {
        ExportCatalog.all.first { $0.id == selectedID } ?? ExportCatalog.all[0]
    }
    private var totalPoints: Int { set.scans.reduce(0) { $0 + $1.pointCloud.pointCount } }
    private var estimatedBytes: Int { totalPoints * 8 }   // rough per-point estimate
    private var fileName: String {
        let base = set.name.isEmpty ? "Untitled" : set.name
        return base + "." + selected.ext.lowercased()
    }
    private var fallback: String? {
        ExportCatalog.unsupportedFallback(for: selected, pointCount: totalPoints)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch step {
            case .pickFormat: pickFormatStep
            case .options:    optionsStep
            case .exporting:  exportingStep
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            switch step {
            case .pickFormat:
                Button("Cancel") { dismiss() }
            case .options:
                Button { step = .pickFormat } label: { Label("Back", systemImage: "chevron.left") }
            case .exporting:
                Spacer().frame(width: 44)
            }
            Spacer()
            Text(titleText).font(.headline)
            Spacer()
            if step == .exporting {
                Button("Done") { dismiss() }.disabled(progress < 1)
            } else {
                Spacer().frame(width: 44)
            }
        }
        .padding()
    }

    private var titleText: String {
        switch step {
        case .pickFormat: return "Export"
        case .options:    return "Export options"
        case .exporting:  return progress < 1 ? "Exporting" : "Ready to share"
        }
    }

    // MARK: - Step A: pick a format

    private var pickFormatStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                filterChips
                VStack(spacing: 22) {
                    ForEach([ExportFormat.Intent.pointCloud, .cadBim, .model3D], id: \.self) { intent in
                        if filter == nil || filter == intent {
                            formatGroup(intent)
                        }
                    }
                    softNote
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            primaryButton("Continue — \(selected.ext)") { step = .options }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", active: filter == nil) { filter = nil }
                ForEach(ExportFormat.Intent.allCases, id: \.self) { intent in
                    chip(intent.filterLabel, active: filter == intent) { filter = intent }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private func chip(_ label: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(active ? Color.accentColor : Color(white: 0.92), in: Capsule())
                .foregroundStyle(active ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func formatGroup(_ intent: ExportFormat.Intent) -> some View {
        let formats = ExportCatalog.formats(in: intent)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(intent.groupLabel).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(formats.count) formats").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(formats) { format in
                formatCard(format)
            }
        }
    }

    private func formatCard(_ format: ExportFormat) -> some View {
        let isSelected = format.id == selectedID
        let soft = ExportCatalog.isSoftPro(format, entitlements: entitlements)
        return Button {
            selectedID = format.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(format.ext).font(.system(.headline, design: .monospaced))
                        if soft { Text("✦").foregroundStyle(.secondary) }
                    }
                    Text(format.blurb).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(format.tag)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(white: 0.93), in: Capsule())
                    .foregroundStyle(.secondary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color(white: 0.88),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var softNote: some View {
        Text("✦ formats are part of Fungible Pro — included free during beta. Nothing is locked today.")
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step B: options & destination

    private var optionsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    optionSection("Format") {
                        infoRow("Export as", selected.ext)
                    }

                    if let fallback {
                        caveat("\(selected.ext) needs surface geometry this project doesn't have yet.",
                               suggestion: fallback)
                    }

                    optionSection("Scope") {
                        infoRow("Source", DisplayFormat.passCount(set.scanCount))
                        Toggle("Crop to region", isOn: $cropToRegion)
                            .disabled(set.regionOfInterest == nil)
                        Toggle("Include annotations", isOn: $includeAnnotations)
                            .disabled(set.annotations.isEmpty)
                    }

                    optionSection("Format options") {
                        infoRow("Density", "Full · \(DisplayFormat.pointCount(totalPoints)) pts")
                        infoRow("Coordinate system", set.crs?.epsg ?? "Local")
                        Picker("Units", selection: $units) {
                            Text("US feet").tag(UnitSystem.imperial)
                            Text("Metric").tag(UnitSystem.metric)
                        }
                        .pickerStyle(.menu)
                    }

                    optionSection("Send to") {
                        ForEach(Destination.allCases) { dest in
                            destinationRow(dest)
                        }
                    }
                }
                .padding()
            }
            primaryButton("Export & share", disabled: fallback != nil) { startExport() }
        }
    }

    private func destinationRow(_ dest: Destination) -> some View {
        Button { destination = dest } label: {
            HStack(spacing: 12) {
                Image(systemName: dest.symbol).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dest.title)
                        if dest.soft { Text("✦").foregroundStyle(.secondary).font(.caption) }
                    }
                    Text(dest.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if destination == dest {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.subheadline)
    }

    // MARK: - Step C: exporting

    private var exportingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().stroke(Color(white: 0.9), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                Text("\(Int(progress * 100))%").font(.title2.monospacedDigit().weight(.semibold))
            }
            .frame(width: 132, height: 132)

            Text(progress < 1 ? "Writing \(selected.ext)…" : "Ready to share")
                .font(.headline)
            Text(progress < 1
                 ? "Converting \(DisplayFormat.pointCount(totalPoints)) points. You can leave this screen — we'll save the file when it's done."
                 : "Saved \(fileName).")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)

            VStack(spacing: 6) {
                Text(fileName).font(.subheadline.weight(.medium))
                Text("~ \(DisplayFormat.fileSize(estimatedBytes))").font(.caption).foregroundStyle(.secondary)
                if includeAnnotations && !set.annotations.isEmpty {
                    Text("Annotations · \(set.annotations.count)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)

            Spacer()
            if progress >= 1 {
                // Real share happens here (UIActivityViewController) once the
                // FungibleExport write path is wired — that's the next step.
                primaryButton("Share") { dismiss() }
            }
        }
        .padding()
        .task { await runProgress() }
    }

    // MARK: - Actions

    private func startExport() {
        progress = 0
        step = .exporting
    }

    /// Drives the wireframe's background-progress state. Placeholder for the real
    /// FungibleExport conversion; deliberately not claiming a real file write.
    private func runProgress() async {
        while true {
            try? await Task.sleep(nanoseconds: 120_000_000)
            let done = await MainActor.run { () -> Bool in
                progress = min(1, progress + 0.08)
                return progress >= 1
            }
            if done { break }
        }
    }

    // MARK: - Reusable bits

    private func optionSection<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private func caveat(_ message: String, suggestion: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.caption)
                Button("Switch to \(suggestion)") {
                    if let f = ExportCatalog.all.first(where: { $0.ext == suggestion }) { selectedID = f.id }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func primaryButton(_ title: String, disabled: Bool = false, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? Color.gray : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .disabled(disabled)
        .padding()
    }
}
