import Foundation

// The seam for AI-enhanced reports. The app/worker provides an `LLMReportGenerator`
// backed by the Claude API (prompt = ReportComposer.prompt). If no generator is
// configured, or a call fails, `ReportService` falls back to the deterministic
// summary — so the feature always works (offline, no key), and the LLM is purely
// additive. This is how we keep AI honest: it earns its place by improving the
// output, never by being required for it.
public protocol LLMReportGenerator: Sendable {
    func narrative(for input: SiteReportInput) async throws -> String
}

/// Always-available generator: returns the deterministic summary. Useful as the
/// default and for tests/previews.
public struct DeterministicReportGenerator: LLMReportGenerator {
    public init() {}
    public func narrative(for input: SiteReportInput) async throws -> String {
        ReportComposer.summary(input)
    }
}

public struct ReportService: Sendable {
    private let generator: (any LLMReportGenerator)?

    /// Pass an LLM-backed generator to enhance reports; omit for deterministic-only.
    public init(generator: (any LLMReportGenerator)? = nil) {
        self.generator = generator
    }

    /// Produce a report, preferring the LLM but always falling back to the
    /// deterministic summary on absence or error.
    public func report(for input: SiteReportInput) async -> String {
        guard let generator else { return ReportComposer.summary(input) }
        do {
            let text = try await generator.narrative(for: input)
            return text.isEmpty ? ReportComposer.summary(input) : text
        } catch {
            return ReportComposer.summary(input)
        }
    }
}
