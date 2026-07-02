import SwiftUI
import FungibleDomain
import FungibleStorage
import FungibleEntitlements
import FungiblePresentation

/// Screen 05 — Convert / Export. The interop hero: pick a target format from the
/// real `ExportCatalog`, set options, export and share. On-device formats
/// (LAS/PLY/XYZ) write a real file and hand it to the iOS share sheet; the
/// compressed/native codecs (LAZ/COPC/E57) are built server-side and route
/// through processing/sync. Formats are never locked in the free MVP.
struct ExportSheet: View {
    let set: ScanSet
    let store: any ScanStore
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
    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var exportError: String?

    // MARK: Derived

    private var selected: ExportFormat {
        ExportCatalog.all.first { $0.id == selectedID } ?? ExportCatalog.all[0]
    }
    // `self.` is required: a computed-property body starting with the bare token
    // `set` is parsed as a setter accessor, not the `set` property.
    private var totalPoints: Int { self.set.visibleScans.reduce(0) { $0 + $1.pointCloud.pointCount } }
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
                Button("Done") { dismiss() }.disabled(isExporting)
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
        case .exporting:  return isExporting ? "Exporting" : (exportedURL != nil ? "Ready to share" : "Export")
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

    @ViewBuilder private var exportingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            if !selected.onDevice {
                cloudFormatState
            } else if isExporting {
                exportingState
            } else if let url = exportedURL {
                readyState(url)
            } else if let error = exportError {
                errorState(error)
            }
            Spacer()
        }
        .padding()
        .task { await runExport() }
    }

    private var exportingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("Writing \(selected.ext)…").font(.headline)
            Text("Merging \(DisplayFormat.pointCount(totalPoints)) points from \(DisplayFormat.passCount(set.visibleScans.count)).")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
    }

    private func readyState(_ url: URL) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54)).foregroundStyle(Color.accentColor)
            Text("\(selected.ext) ready").font(.headline)
            VStack(spacing: 4) {
                Text(url.lastPathComponent).font(.subheadline.weight(.medium))
                Text(fileSizeText(url)).font(.caption).foregroundStyle(.secondary)
                if selected.ext == "LAS" {
                    Text("Each point tagged with its pass — splits back in CloudCompare")
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            // Native share — AirDrop, Files, Mail, other apps — of the real file.
            ShareLink(item: url) {
                Text("Share").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal).padding(.top, 4)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundStyle(.orange)
            Text("Couldn't export").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button("Back") { step = .options }.font(.headline).padding(.top, 4)
        }
    }

    private var cloudFormatState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("\(selected.ext) is built in the cloud").font(.headline)
            Text("Compressed and cloud-optimized formats are converted server-side by the processing worker. That runs once cloud sync is set up — LAS, PLY, and XYZ export right here on device today.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 28)
            Button("Choose an on-device format") { step = .pickFormat }
                .font(.headline).padding(.top, 4)
        }
    }

    // MARK: - Actions

    private func startExport() {
        exportedURL = nil
        exportError = nil
        step = .exporting
    }

    /// Real export: assemble the visible cloud and write the file, then the
    /// share sheet takes over. Cloud-only formats short-circuit to their note.
    private func runExport() async {
        guard selected.onDevice, exportedURL == nil, exportError == nil, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            exportedURL = try await ExportRunner.export(set, ext: selected.ext, store: store)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func fileSizeText(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return DisplayFormat.fileSize(bytes)
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
