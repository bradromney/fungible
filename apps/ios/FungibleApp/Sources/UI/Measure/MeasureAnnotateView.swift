import SwiftUI
import FungibleDomain
import FungiblePresentation

/// Screen 04 — Measure & Annotate. Tap the cloud to measure distance / plan area
/// / volume, or drop annotation pins with a note + category. Both attach to the
/// project (ScanSet), so they survive new passes and feed the Site Report.
///
/// On device, taps hit-test against the live Metal point cloud. Here (no device)
/// taps map to synthetic world points at a fixed scale chosen so the readouts
/// reproduce the wireframe's numbers — the measurement math itself is the real
/// `Measurement` geometry from FungibleDomain. Saving emits a real domain
/// `Measurement`/`Annotation` via callbacks; the detail view-model upserts it
/// onto the `ScanSet` and persists through the local-first store (ADR-0009).
struct MeasureAnnotateView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case distance, area, volume, annotate
        var id: String { rawValue }
        var title: String {
            switch self {
            case .distance: return "Distance"
            case .area:     return "Area"
            case .volume:   return "Volume"
            case .annotate: return "Annotate"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    /// Persist callbacks (ADR-0009). The detail view routes these into the
    /// view-model, which upserts onto the `ScanSet` and saves through the store.
    let onSaveMeasurement: (FungibleDomain.Measurement) -> Void
    let onSaveAnnotation: (Annotation) -> Void

    @State private var mode: Mode
    @State private var tapLocations: [CGPoint] = []
    @State private var pins: [PinItem] = []
    @State private var draftPin: CGPoint?
    @State private var noteText = ""
    @State private var category: AnnotationCategory = .issue
    @State private var hasPhoto = false
    @State private var savedCount = 0

    /// Screen-point → meters. 0.012 makes a ~375 pt tap read ≈ 4.5 m (14′9″),
    /// matching the wireframe example. Replaced by real hit-testing on device.
    private let scale = 0.012

    struct PinItem: Identifiable { let id = UUID(); let location: CGPoint; let number: Int }

    init(
        initialMode: Mode,
        onSaveMeasurement: @escaping (FungibleDomain.Measurement) -> Void = { _ in },
        onSaveAnnotation: @escaping (Annotation) -> Void = { _ in }
    ) {
        _mode = State(initialValue: initialMode)
        self.onSaveMeasurement = onSaveMeasurement
        self.onSaveAnnotation = onSaveAnnotation
    }

    // MARK: Derived geometry (real Measurement math)

    private var worldPoints: [Vector3] {
        tapLocations.map { Vector3(Double($0.x) * scale, 0, Double($0.y) * scale) }
    }
    // Fully qualified: `Measurement` alone is ambiguous in the app (Foundation's
    // Measurement<Unit> via SwiftUI vs. FungibleDomain.Measurement).
    private var measurement: FungibleDomain.Measurement {
        FungibleDomain.Measurement(kind: mode == .distance ? .distance : .area, points: worldPoints)
    }
    private var hasEnoughPoints: Bool {
        mode == .distance ? worldPoints.count >= 2 : worldPoints.count >= 3
    }

    var body: some View {
        ZStack {
            viewer
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomPanel
                    .padding()
                    .background(.ultraThinMaterial)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Viewer (dark cloud placeholder + taps + drawing)

    private var viewer: some View {
        ZStack {
            Color(white: 0.11)
            cloudPattern
            polyline
            ForEach(Array(tapLocations.enumerated()), id: \.offset) { _, loc in
                Circle().fill(.white).frame(width: 11, height: 11)
                    .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
                    .position(loc)
            }
            ForEach(pins) { pin in pinView(number: pin.number, at: pin.location, active: false) }
            if let draftPin { pinView(number: pins.count + 1, at: draftPin, active: true) }
            if mode != .annotate && tapLocations.isEmpty {
                Image(systemName: "plus").font(.title3).foregroundStyle(.white.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture(coordinateSpace: .local).onEnded { handleTap($0.location) })
        .ignoresSafeArea()
    }

    private var cloudPattern: some View {
        GeometryReader { geo in
            let cols = Int(geo.size.width / 16), rows = Int(geo.size.height / 16)
            ForEach(0..<max(1, rows), id: \.self) { r in
                ForEach(0..<max(1, cols), id: \.self) { c in
                    Circle().fill(.white.opacity(0.10))
                        .frame(width: 2, height: 2)
                        .position(x: CGFloat(c) * 16 + 8, y: CGFloat(r) * 16 + 8)
                }
            }
        }
    }

    private var polyline: some View {
        Path { path in
            guard let first = tapLocations.first else { return }
            path.move(to: first)
            for p in tapLocations.dropFirst() { path.addLine(to: p) }
            if mode != .distance && tapLocations.count > 2 { path.addLine(to: first) }
        }
        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func pinView(number: Int, at location: CGPoint, active: Bool) -> some View {
        Text("\(number)")
            .font(.caption2.bold())
            .foregroundStyle(active ? .white : .black)
            .frame(width: 24, height: 24)
            .background(active ? Color.accentColor : .white, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: active ? 0 : 1))
            .position(location)
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                Spacer()
                if savedCount > 0 {
                    Label("\(savedCount)", systemImage: "checkmark.seal")
                        .font(.caption).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                if !tapLocations.isEmpty || draftPin != nil {
                    Button { undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                        .font(.subheadline)
                }
            }
            modePicker
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: mode) { _ in resetInputs() }
    }

    // MARK: - Bottom panel

    @ViewBuilder private var bottomPanel: some View {
        if mode == .annotate {
            annotatePanel
        } else if hasEnoughPoints {
            measureReadout
        } else {
            Text(prompt).font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var prompt: String {
        switch mode {
        case .distance: return "Tap two points to measure a distance."
        case .area:     return "Tap to add points · tap the first point to close."
        case .volume:   return "Tap to outline an area for a quick volume."
        case .annotate: return "Tap to place a pin."
        }
    }

    private var measureReadout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(readoutTitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(readoutHeadline).font(.largeTitle.weight(.semibold))
            Text(readoutEcho).font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Button { save() } label: {
                    Text(mode == .distance ? "Save measurement" : "Close & save")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                Button { resetInputs() } label: {
                    Text("New").font(.headline).padding(.vertical, 14).padding(.horizontal, 20)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var readoutTitle: String {
        switch mode {
        case .area:   return "PLAN AREA"
        case .volume: return "VOLUME (QUICK)"
        default:      return "DISTANCE"
        }
    }
    private var readoutHeadline: String {
        switch mode {
        case .distance: return DisplayFormat.feetInches(measurement.polylineLength)
        case .area, .volume: return DisplayFormat.areaFeetSquared(measurement.planArea)
        case .annotate: return ""
        }
    }
    private var readoutEcho: String {
        switch mode {
        case .distance:
            return DisplayFormat.metersEcho(measurement.polylineLength) + " · point-to-point"
        case .area:
            return DisplayFormat.areaMeters(measurement.planArea)
                 + " · perimeter " + DisplayFormat.feetDecimal(measurement.closedPerimeter)
        case .volume:
            return "Footprint only — use Cut/Fill for grade-based volume."
        case .annotate:
            return ""
        }
    }

    // MARK: - Annotate panel

    private var annotatePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if draftPin == nil {
                Text(prompt).font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("New annotation").font(.headline)
                    Spacer()
                    Text("Pinned to project").font(.caption).foregroundStyle(.secondary)
                }
                TextField("Add a note", text: $noteText, axis: .vertical)
                    .lineLimit(1...3).textFieldStyle(.roundedBorder)
                HStack(spacing: 8) {
                    ForEach(AnnotationCategory.allCases, id: \.self) { cat in
                        Button { category = cat } label: {
                            Label(cat.label, systemImage: cat.symbolName)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(category == cat ? Color.accentColor : Color.white.opacity(0.12), in: Capsule())
                                .foregroundStyle(category == cat ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    Button { hasPhoto.toggle() } label: {
                        Label(hasPhoto ? "Photo attached" : "Add photo",
                              systemImage: hasPhoto ? "photo.fill" : "photo")
                            .font(.subheadline)
                    }
                    Spacer()
                    Button { save() } label: {
                        Text("Save").font(.headline).padding(.vertical, 12).padding(.horizontal, 28)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .disabled(noteText.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleTap(_ loc: CGPoint) {
        if mode == .annotate {
            draftPin = loc
            return
        }
        if mode == .distance && tapLocations.count >= 2 { tapLocations = [] }
        tapLocations.append(loc)
    }

    private func undo() {
        if mode == .annotate { draftPin = nil; return }
        if !tapLocations.isEmpty { tapLocations.removeLast() }
    }

    private func resetInputs() {
        tapLocations = []
        draftPin = nil
        noteText = ""
        hasPhoto = false
    }

    /// Emits the measurement/annotation as a real domain object; the detail
    /// view-model upserts it onto the `ScanSet` and persists (ADR-0009).
    private func save() {
        switch mode {
        case .annotate:
            guard let draftPin else { return }
            let world = Vector3(Double(draftPin.x) * scale, 0, Double(draftPin.y) * scale)
            onSaveAnnotation(Annotation(position: world, text: noteText, category: category))
            pins.append(PinItem(location: draftPin, number: pins.count + 1))
        default:
            guard hasEnoughPoints else { return }
            onSaveMeasurement(measurement)
        }
        savedCount += 1
        resetInputs()
    }
}
