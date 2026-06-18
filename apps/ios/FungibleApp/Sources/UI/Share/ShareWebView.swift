import SwiftUI
import UIKit
import FungibleDomain

/// Screen 09 — Share to web (the webShare capability). Publish the project to the
/// browser viewer so anyone with the link can orbit the cloud — no app, no
/// account. This is the iOS hand-off flow (create link → set access → share
/// sheet); the web viewer itself is separate. Sharing is reversible: replace
/// mints a new URL, stop sharing takes it offline.
///
/// Minting/revoking a real hosted link is the sync/API integration; here the
/// link is generated locally and handed off via the native share sheet.
struct ShareWebView: View {
    let project: ScanSet
    @Environment(\.dismiss) private var dismiss

    @State private var created = false
    @State private var anyoneWithLink = true
    @State private var allowDownload = false
    @State private var expiry: Expiry = .never
    @State private var views = 0
    @State private var suffix = String(UUID().uuidString.prefix(4)).lowercased()

    enum Expiry: String, CaseIterable, Identifiable {
        case never = "Never", week = "In 7 days", month = "In 30 days"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    linkRow
                    accessSection
                    if created { manageSection }
                }
                .padding()
            }
            bottomBar
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
            Spacer()
            Text("Share project").font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 1)
        }
        .padding()
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.13)).frame(height: 150)
            Image(systemName: "rotate.3d").font(.largeTitle).foregroundStyle(.white.opacity(0.6))
            VStack { Spacer()
                Text("Orbitable in any browser").font(.caption).foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Link row

    private var linkRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEB LINK").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(linkString).font(.subheadline.monospaced()).lineLimit(1)
                    Text(created ? "Live since just now · \(views) views" : "Live · view-only · opens in browser")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = "https://" + linkString
                } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .font(.subheadline)
            }
            .padding(12)
            .background(Color(white: 0.95), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Access

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCESS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            toggleRow("Anyone with the link", "No sign-in needed to view", isOn: $anyoneWithLink, soft: false)
            toggleRow("Allow download", "Viewers can export the cloud", isOn: $allowDownload, soft: true)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Link expires").font(.subheadline)
                    Text("Auto-disable after a set time").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker("Expiry", selection: $expiry) {
                        ForEach(Expiry.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: { Text(expiry.rawValue).font(.subheadline) }
            }
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>, soft: Bool) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.subheadline)
                    if soft {
                        Text("Pro").font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Manage

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MANAGE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Button {
                suffix = String(UUID().uuidString.prefix(4)).lowercased()
                views = 0
            } label: { Label("Replace link (revoke old)", systemImage: "arrow.triangle.2.circlepath") }
                .font(.subheadline)
            Button(role: .destructive) {
                created = false
            } label: { Label("Stop sharing", systemImage: "xmark.circle") }
                .font(.subheadline)
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder private var bottomBar: some View {
        if created {
            ShareLink(item: shareURL) {
                Text("Send link").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding()
        } else {
            Button { created = true } label: {
                Text("Share link").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding()
        }
    }

    // MARK: - Derived link

    private var slug: String {
        let base = project.name.lowercased().replacingOccurrences(of: " ", with: "-")
        let filtered = base.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return filtered.isEmpty ? "project" : String(filtered.prefix(20))
    }
    private var linkString: String { "share.fungible.app/\(slug)-\(suffix)" }
    private var shareURL: URL { URL(string: "https://" + linkString) ?? URL(string: "https://share.fungible.app")! }
}
