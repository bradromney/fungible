import SwiftUI
import FungibleDomain
import FungiblePresentation

/// Screen 01 — Projects (home). The root library of `ScanSet`s: search, sort, a
/// list of project rows, and a pinned primary "New scan". Stack-based nav; this
/// is the root, capture is a modal, project detail pushes. Shows an empty state
/// when there are no projects yet.
struct ProjectsHomeView: View {
    @ObservedObject var viewModel: ProjectsViewModel
    /// Presents the capture modal (owned by RootView).
    var onNewScan: () -> Void

    var body: some View {
        Group {
            if viewModel.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { newScanButton }
    }

    // MARK: - List

    private var projectList: some View {
        List {
            Section {
                ForEach(viewModel.rows, id: \.id) { row in
                    NavigationLink(value: row.id) {
                        ProjectRow(model: row)
                    }
                }
            } header: {
                sortRow
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchText, prompt: "Search projects")
    }

    private var sortRow: some View {
        HStack {
            Text("\(viewModel.sets.count) projects")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(ProjectsViewModel.SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Label("Sort: \(viewModel.sortOrder.rawValue)", systemImage: "arrow.up.arrow.down")
                    .font(.footnote)
            }
        }
        .textCase(nil)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            Text("No projects yet")
                .font(.title3.weight(.semibold))
            Text("Capture a space to start your first project. Add as many passes as you like — there's no limit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Primary action

    private var newScanButton: some View {
        Button(action: onNewScan) {
            Label("New scan", systemImage: "viewfinder")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

/// One project row: stylized point-cloud thumbnail, AI-generated name, then pass
/// count (never a cap), total points, a precise timestamp, and a sync glyph.
struct ProjectRow: View {
    let model: ProjectRowModel

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(model.passCountLabel)
                    Text("·")
                    Text(model.pointCountLabel)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text(model.timestampLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: model.sync.symbolName)
                .font(.footnote)
                .foregroundStyle(model.sync.isError ? Color.orange : Color.secondary)
                .accessibilityLabel(model.sync.label)
        }
        .padding(.vertical, 4)
    }

    /// Grayscale point-cloud stand-in (the live render is Metal, device-only).
    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(white: 0.13))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.5))
            )
    }
}
