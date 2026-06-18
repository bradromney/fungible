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
