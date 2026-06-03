import SwiftUI
import FungibleStorage

// App entry. Wires the local-first store and drops the user into the capture
// screen. Sync drivers, accounts, and entitlements gating attach here later
// (ADR-0003 / ADR-0004) — all behind the protocols FungibleCore already defines.
@main
struct FungibleAppApp: App {
    private let store: any ScanStore = Self.makeStore()

    var body: some Scene {
        WindowGroup {
            CaptureView(viewModel: CaptureViewModel(store: store))
        }
    }

    private static func makeStore() -> any ScanStore {
        // Local-first: scans live in Application Support and work fully offline.
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fungible", isDirectory: true)
        do {
            return try FileScanStore(root: base)
        } catch {
            assertionFailure("Falling back to in-memory store: \(error)")
            return InMemoryScanStore()
        }
    }
}
