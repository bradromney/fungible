import SwiftUI
import FungibleDomain
import FungiblePresentation

/// Screen 03 — Project Detail / 3D viewer (shell). The orbitable combined point
/// cloud is the live Metal render (device-only), stood in here by a placeholder.
/// Below it: the contextual action toolbar and a Passes / Details segmented view
/// over the project's real `Scan` data. Measure / Export / Cut-Fill / Report /
/// Share open from the toolbar (built out screen-by-screen).
struct ProjectDetailView: View {
    /// The project is owned by the view-model and persisted through the store
    /// (ADR-0009). We read the live set by id so edits made in the editor sheets
    /// round-trip and re-render here; `initialSet` is the navigation snapshot and
    /// a safe fallback if the catalog reloads.
    @ObservedObject var viewModel: ProjectsViewModel
    let initialSet: ScanSet
    private var set: ScanSet { viewModel.set(for: initialSet.id) ?? initialSet }

    @State private var tab: Tab = .passes
    @State private var showExport = false
    @State private var showReport = false
    @State private var showCutFill = false
    @State private var showShare = false
    @State private var measureMode: MeasureAnnotateView.Mode?

    enum Tab: String, CaseIterable, Identifiable { case passes = "Passes", details = "Details"; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                viewer
                toolbar
                Picker("View", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch tab {
                case .passes:  passesList
                case .details: detailsList
                }
            }
        }
        .navigationTitle(set.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { typeMenu }
        }
        .sheet(isPresented: $showExport) { ExportSheet(set: set) }
        .sheet(isPresented: $showReport) { NavigationStack { SiteReportView(set: set) } }
        .sheet(isPresented: $showCutFill) {
            CutFillView(project: set) { viewModel.addMeasurement($0, to: set.id) }
        }
        .sheet(isPresented: $showShare) {
            ShareWebView(project: set) { viewModel.updateShare($0, for: set.id) }
        }
        .fullScreenCover(item: $measureMode) { mode in
            MeasureAnnotateView(
                initialMode: mode,
                onSaveMeasurement: { viewModel.addMeasurement($0, to: set.id) },
                onSaveAnnotation: { viewModel.addAnnotation($0, to: set.id) }
            )
        }
    }

    // MARK: - Viewer placeholder

    private var viewer: some View {
        ZStack {
            Rectangle().fill(Color(white: 0.12))
            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.4))
            // Non-blocking background-registration banner (ADR-0005).
            if let registering = set.scans.firstIndex(where: { $0.status.isInProgress }) {
                VStack {
                    Spacer()
                    Label("Pass \(registering + 1) registering — project stays usable",
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                }
            }
        }
        .frame(height: 280)
    }

    // MARK: - Action toolbar

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                action("Measure", "ruler", softPro: false) { measureMode = .distance }
                action("Annotate", "mappin.and.ellipse", softPro: false) { measureMode = .annotate }
                action("Export", "square.and.arrow.up", softPro: true) { showExport = true }
                // Contextual slot — Cut/Fill for site, Floorplan for interior, Mesh for object.
                action(set.type.contextualToolLabel, set.type.contextualToolSymbol, softPro: true) {
                    if set.type == .site { showCutFill = true }
                }
                action("Share", "link", softPro: true) { showShare = true }
                action("Report", "doc.text", softPro: true) { showReport = true }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private func action(_ title: String, _ symbol: String, softPro: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbol)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .background(Color(white: 0.92), in: RoundedRectangle(cornerRadius: 12))
                    if softPro {
                        // Quiet paywall-candidate dot — never a lock in the MVP.
                        Circle().fill(Color.secondary).frame(width: 6, height: 6).offset(x: 3, y: -3)
                    }
                }
                Text(title).font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: - Passes

    private var passesList: some View {
        VStack(spacing: 0) {
            if set.scans.isEmpty {
                Text("No passes yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding()
            }
            ForEach(Array(set.scans.enumerated()), id: \.element.id) { index, scan in
                passRow(index: index, scan: scan)
                Divider().padding(.leading)
            }
        }
    }

    private func passRow(index: Int, scan: Scan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: scan.status.symbolName)
                .foregroundStyle(scan.status.needsAttention ? Color.orange : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text("Pass \(index + 1)").font(.subheadline.weight(.semibold))
                Text(DisplayFormat.preciseTimestamp(scan.capturedAt))
                    .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                HStack(spacing: 6) {
                    Text(scan.status.displayLabel)
                    Text("·")
                    Text(DisplayFormat.coverage(scan.quality.coverage))
                    if let drift = DisplayFormat.drift(scan.quality.driftEstimateMeters) {
                        Text("·"); Text(drift)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(DisplayFormat.pointCount(scan.pointCloud.pointCount))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 10)
    }

    // MARK: - Details

    private var detailsList: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Market-specific facts (screen 11): the same Project Detail screen,
            // with the vocabulary switching on project type (ADR-0007). The
            // values come from the same cloud; geometry-derived ones need capture.
            VStack(alignment: .leading, spacing: 10) {
                Text(set.type.factsSectionTitle.uppercased())
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(set.type.factLabels, id: \.self) { label in
                    detailRow(label, marketFactValue(for: label))
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                detailRow("Project type", set.type.chipLabel)
                detailRow("Passes", DisplayFormat.passCount(set.scanCount))
                detailRow("Measurements", "\(set.measurements.count)")
                detailRow("Annotations", "\(set.annotations.count)")
                detailRow("Coordinate system", set.crs?.epsg ?? "Local (set at export)")
                detailRow("Created", DisplayFormat.preciseTimestamp(set.createdAt))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Market facts share one cloud; the area lead fills from an area measurement
    /// when present, the geometry-derived facts await on-device DEM computation.
    private func marketFactValue(for label: String) -> String {
        switch label {
        case "Plan area", "Floor area":
            if let area = set.measurements.filter({ $0.kind == .area }).map(\.planArea).max() {
                return DisplayFormat.areaFeetSquared(area)
            }
            return "Add a measurement"
        default:
            return "—"
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private var typeBinding: Binding<ProjectType> {
        Binding(get: { set.type }, set: { viewModel.setType($0, for: set.id) })
    }

    private var typeMenu: some View {
        Menu {
            Picker("Project type", selection: typeBinding) {
                ForEach(ProjectType.allCases, id: \.self) { Text($0.chipLabel).tag($0) }
            }
        } label: {
            Text(set.type.chipLabel).font(.subheadline)
        }
    }
}
