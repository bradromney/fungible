import SwiftUI
import FungibleEntitlements

/// Screen 10 — Settings & Account (shell). Entitlement seams are surfaced as
/// "what's included" (everything on — free MVP, ADR-0004), not a locked paywall.
/// Storage is local-first (ADR-0003). The plan note is honest about future
/// pricing without a hard upsell.
struct SettingsView: View {
    private let entitlements = EntitlementsService(entitlements: .mvpFreeEverything)

    var body: some View {
        List {
            Section {
                ForEach(Capability.allCases, id: \.self) { cap in
                    HStack {
                        Text(label(for: cap))
                        Spacer()
                        if entitlements.isEnabled(cap) {
                            Label("On", systemImage: "checkmark")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.subheadline)
                }
            } header: {
                Text("What's included")
            } footer: {
                Text("Everything is on during the beta. We'll be upfront before anything becomes a paid plan.")
            }

            Section("Storage") {
                row("On this iPhone", "iphone")
                row("Hosted storage", "cloud")
                row("Bring your own cloud", "externaldrive.badge.icloud")
            }

            Section("Plan") {
                Button {
                    // Soft interest capture — not "Upgrade now".
                } label: {
                    Label("Notify me about Pro", systemImage: "bell")
                }
            }

            Section("Account") {
                row("Default units — US feet", "ruler")
                row("Export all my data", "square.and.arrow.up")
                Button(role: .destructive) {} label: { Text("Sign out") }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.subheadline)
    }

    /// Friendly label for a capability seam (presentation-side for the shell).
    private func label(for cap: Capability) -> String {
        switch cap {
        case .unlimitedScansPerSet: return "Unlimited passes per project"
        case .exportLAZ:            return "Export LAZ / COPC / PLY / USDZ"
        case .exportE57:            return "Export E57"
        case .exportDXF:            return "Export DXF"
        case .exportIFC:            return "Export IFC (BIM)"
        case .exportLandXML:        return "Export LandXML"
        case .cutFillVolume:        return "Cut / fill volumes"
        case .hostedStorage:        return "Hosted storage"
        case .byoCloud:             return "Bring your own cloud"
        case .cloudProcessing:      return "Cloud processing"
        case .webShare:             return "Share to web"
        }
    }
}
