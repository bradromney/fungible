import SwiftUI
import FungiblePresentation

/// Screen 08B/C — post-capture handoff. The pass auto-saved into the growing
/// project (session-alive, ADR-0005). First pass: name the new project (editable
/// suggestion). Later passes: confirmation that the pass was added — same
/// project, same world frame — with "Scan again" one tap away.
///
/// The earlier overlap-based "add here vs new project" chooser was presentation
/// only; it returns in M3 when overlap detection is real. Reversible regardless
/// via hide/split (ADR-0010).
struct PostCaptureHandoffView: View {
    let pointCount: Int
    /// 1-based pass number within the project this capture session grew.
    let passCount: Int
    let projectName: String
    var onScanAgain: () -> Void
    /// Called with the (possibly edited) project name; closes the flow.
    var onConfirm: (String) -> Void

    @State private var name: String

    init(pointCount: Int, passCount: Int, projectName: String,
         onScanAgain: @escaping () -> Void, onConfirm: @escaping (String) -> Void) {
        self.pointCount = pointCount
        self.passCount = passCount
        self.projectName = projectName
        self.onScanAgain = onScanAgain
        self.onConfirm = onConfirm
        _name = State(initialValue: projectName)
    }

    private var isFirstPass: Bool { passCount <= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if isFirstPass {
                nameField
            } else {
                addedSummary
            }
            Spacer()
            buttons
        }
        .padding()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isFirstPass ? "Pass saved — new project" : "Pass \(passCount) saved")
                .font(.title2.weight(.bold))
            Text(isFirstPass
                 ? "\(DisplayFormat.pointCount(pointCount)) points · scan again to keep growing it"
                 : "\(DisplayFormat.pointCount(pointCount)) points · added to “\(projectName)”")
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
            TextField("Name this project", text: $name).textFieldStyle(.roundedBorder)
        }
    }

    private var addedSummary: some View {
        Label {
            Text("Every pass this session shares one aligned frame — keep scanning until the site's covered. No pass limit.")
                .font(.subheadline).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "square.stack.3d.up")
                .foregroundStyle(Color.accentColor)
        }
    }

    private var buttons: some View {
        HStack {
            Button(action: onScanAgain) {
                Label("Scan again", systemImage: "viewfinder")
                    .font(.headline).padding(.vertical, 14).padding(.horizontal, 20)
                    .background(Color(white: 0.92), in: RoundedRectangle(cornerRadius: 12))
            }
            Button { onConfirm(name) } label: {
                Text(isFirstPass ? "Confirm" : "Done")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
    }
}
