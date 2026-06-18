import SwiftUI
import FungiblePresentation

/// Screen 08B/C — post-capture handoff. The pass auto-saved; the app proposes an
/// AI name and states where the pass went, with the alternative one tap away
/// (signal, don't gate). The default flips on geometry: overlapping → "added to
/// current project"; non-overlapping → "looks like a new area" recommends a new
/// project. Always reversible later via split/merge (Screen 03B).
///
/// Overlap detection + applying the assignment/rename to the store is M3
/// (multi-scan registration); here the decision is presented and Confirm closes.
struct PostCaptureHandoffView: View {
    let pointCount: Int
    let overlaps: Bool
    var existingProjectName: String = "your current project"
    var onScanAgain: () -> Void
    var onDone: () -> Void

    enum Assignment { case existing, newProject }
    @State private var assignment: Assignment
    @State private var name: String

    init(pointCount: Int, overlaps: Bool, existingProjectName: String = "your current project",
         onScanAgain: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.pointCount = pointCount
        self.overlaps = overlaps
        self.existingProjectName = existingProjectName
        self.onScanAgain = onScanAgain
        self.onDone = onDone
        _assignment = State(initialValue: overlaps ? .existing : .newProject)
        // A content-derived name from FungibleInsights is the follow-up; default
        // to an editable placeholder tagged "Suggested".
        _name = State(initialValue: "Untitled site")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            nameField
            VStack(spacing: 10) {
                if overlaps {
                    optionRow(.existing, title: existingProjectName,
                              subtitle: "overlaps existing scans", recommended: false)
                    optionRow(.newProject, title: "Start a new project",
                              subtitle: "Keep this pass on its own", recommended: false)
                } else {
                    optionRow(.newProject, title: "New project — “\(name)”",
                              subtitle: "keeps sites separate", recommended: true)
                    optionRow(.existing, title: "Add to \(existingProjectName)",
                              subtitle: "Keep everything in one project", recommended: false)
                }
            }
            Spacer()
            buttons
        }
        .padding()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(overlaps ? "Pass saved" : "Looks like a new area")
                .font(.title2.weight(.bold))
            Text(overlaps
                 ? "\(DisplayFormat.pointCount(pointCount)) points · added to \(existingProjectName)"
                 : "This pass didn't overlap your other scans")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Name").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("Suggested").font(.caption2.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            TextField("Name this pass", text: $name).textFieldStyle(.roundedBorder)
        }
    }

    private func optionRow(_ value: Assignment, title: String, subtitle: String, recommended: Bool) -> some View {
        Button { assignment = value } label: {
            HStack(spacing: 12) {
                Image(systemName: assignment == value ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(assignment == value ? Color.accentColor : Color.secondary.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.subheadline.weight(.medium))
                        if recommended {
                            Text("Recommended").font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(assignment == value ? Color.accentColor : Color(white: 0.88),
                                  lineWidth: assignment == value ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var buttons: some View {
        HStack {
            Button(action: onScanAgain) {
                Label("Scan again", systemImage: "viewfinder")
                    .font(.headline).padding(.vertical, 14).padding(.horizontal, 20)
                    .background(Color(white: 0.92), in: RoundedRectangle(cornerRadius: 12))
            }
            Button(action: onDone) {
                Text(overlaps ? "Open project" : "Confirm")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
    }
}
