import SwiftUI
import FungibleDomain
import FungibleStorage
import FungiblePresentation

/// Backs the Projects home (screen 01): loads the local-first catalog of
/// `ScanSet`s and exposes display-ready rows. Sorting/searching is pure over the
/// loaded sets; the heavy logic (formatting, sync glyphs) lives in
/// `FungiblePresentation` so it's unit-tested off-device.
@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published private(set) var sets: [ScanSet] = []
    @Published private(set) var isLoading = false
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .recent

    let store: any ScanStore

    enum SortOrder: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case name = "Name"
        case passes = "Passes"
        var id: String { rawValue }
    }

    init(store: any ScanStore) { self.store = store }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { sets = try await store.loadSets() }
        catch { sets = [] }
    }

    /// Display rows for the (filtered, sorted) sets. Sync is local-only for now —
    /// the resting state until a `SyncProvider` driver is wired (ADR-0003).
    var rows: [ProjectRowModel] {
        visibleSets.map { ProjectRowModel(from: $0, sync: .localOnly) }
    }

    var isEmpty: Bool { sets.isEmpty }

    func set(for id: ScanSetID) -> ScanSet? { sets.first { $0.id == id } }

    // MARK: - Editing (ADR-0009)
    // The editor screens hand results back here; we mutate the in-memory set
    // (so any open detail re-renders) and persist it through the local-first
    // store. Mutating in place keeps `rows` and the detail view in sync.

    /// Apply a pure mutation to the set with `id`, then save it.
    func update(_ id: ScanSetID, _ mutate: (inout ScanSet) -> Void) {
        guard let i = sets.firstIndex(where: { $0.id == id }) else { return }
        mutate(&sets[i])
        let snapshot = sets[i]
        Task { try? await store.save(snapshot) }
    }

    func addMeasurement(_ m: FungibleDomain.Measurement, to id: ScanSetID) { update(id) { $0.upsert(m) } }
    func addAnnotation(_ a: Annotation, to id: ScanSetID) { update(id) { $0.upsert(a) } }
    func setType(_ type: ProjectType, for id: ScanSetID) { update(id) { $0.type = type } }
    func updateShare(_ share: ShareSettings, for id: ScanSetID) { update(id) { $0.share = share } }

    // MARK: - Reversible multi-scan curation (ADR-0010)

    /// Hide/show a pass in the combined cloud — O(1) metadata, never data loss.
    func setScanHidden(_ scanID: ScanID, hidden: Bool, for id: ScanSetID) {
        update(id) { $0.setScan(scanID, hidden: hidden) }
    }

    /// Move one pass into a brand-new project (split). The blob is content-
    /// addressed and referenced by the child, so nothing is lost; the child
    /// carries the scan's optimized pose and stands alone.
    func splitScan(_ scanID: ScanID, from id: ScanSetID, name: String) {
        guard let i = sets.firstIndex(where: { $0.id == id }) else { return }
        let child = sets[i].split(scanIDs: [scanID], name: name)
        guard !child.scans.isEmpty else { return }
        sets[i].removeScan(scanID)
        sets.append(child)
        let parent = sets[i]
        Task {
            try? await store.save(parent)
            try? await store.save(child)
        }
    }

    // MARK: - Filtering & sorting (pure)

    private var visibleSets: [ScanSet] {
        let filtered = searchText.isEmpty
            ? sets
            : sets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        switch sortOrder {
        case .recent:
            return filtered.sorted { latestActivity($0) > latestActivity($1) }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .passes:
            return filtered.sorted { $0.scanCount > $1.scanCount }
        }
    }

    private func latestActivity(_ s: ScanSet) -> Date {
        s.scans.map(\.capturedAt).max() ?? s.createdAt
    }
}
