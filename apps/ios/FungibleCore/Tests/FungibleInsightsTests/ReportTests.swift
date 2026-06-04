import XCTest
@testable import FungibleInsights

final class SiteReportInputTests: XCTestCase {
    func testNetVolumeAndTruckloads() throws {
        let input = SiteReportInput(
            siteName: "Backyard", areaSquareMeters: 350,
            cutVolume: 5, fillVolume: 47, pointCount: 1_200_000,
            truckCapacityCubicMeters: 10
        )
        let net = try XCTUnwrap(input.netVolume)
        XCTAssertEqual(net, 42, accuracy: 1e-9)             // 47 - 5
        XCTAssertEqual(input.fillTruckloads, 5)             // ceil(47/10)
        XCTAssertEqual(input.cutTruckloads, 1)              // ceil(5/10)
    }

    func testNilVolumesGiveNilNet() {
        XCTAssertNil(SiteReportInput(siteName: "X", areaSquareMeters: 10).netVolume)
        XCTAssertEqual(SiteReportInput(siteName: "X").fillTruckloads, 0)
    }
}

final class ReportComposerTests: XCTestCase {
    private let input = SiteReportInput(
        siteName: "North Lot", areaSquareMeters: 350.4,
        cutVolume: 5.2, fillVolume: 47.0, pointCount: 1000,
        facts: [("Max slope", "12°")]
    )

    func testDeterministicSummaryStatesTheNumbers() {
        let s = ReportComposer.summary(input)
        XCTAssertTrue(s.hasPrefix("North Lot:"))
        XCTAssertTrue(s.contains("net fill of 41.8 m³")) // 47.0 - 5.2
        XCTAssertTrue(s.contains("350.4 m²"))
        XCTAssertTrue(s.contains("truckload"))
        XCTAssertTrue(s.contains("Max slope: 12°"))
        XCTAssertTrue(s.contains("1000 points"))
    }

    func testSummaryHandlesCutDominant() {
        let cutHeavy = SiteReportInput(siteName: "Pad", cutVolume: 30, fillVolume: 2)
        XCTAssertTrue(ReportComposer.summary(cutHeavy).contains("net cut of 28.0 m³"))
    }

    func testPromptIsFactsOnlyAndIncludesNumbers() {
        let p = ReportComposer.prompt(input)
        XCTAssertTrue(p.contains("Use ONLY the measured facts"))
        XCTAssertTrue(p.contains("- Cut: 5.2 m³"))
        XCTAssertTrue(p.contains("- Fill: 47.0 m³"))
        XCTAssertTrue(p.contains("- Max slope: 12°"))
    }
}

final class ReportServiceTests: XCTestCase {
    private struct ShoutingGenerator: LLMReportGenerator {
        func narrative(for input: SiteReportInput) async throws -> String { "ENHANCED: \(input.siteName)" }
    }
    private struct FailingGenerator: LLMReportGenerator {
        struct Boom: Error {}
        func narrative(for input: SiteReportInput) async throws -> String { throw Boom() }
    }

    private let input = SiteReportInput(siteName: "Site", fillVolume: 10)

    func testFallsBackToDeterministicWithNoGenerator() async {
        let text = await ReportService().report(for: input)
        XCTAssertEqual(text, ReportComposer.summary(input))
    }

    func testUsesGeneratorWhenPresent() async {
        let text = await ReportService(generator: ShoutingGenerator()).report(for: input)
        XCTAssertEqual(text, "ENHANCED: Site")
    }

    func testFallsBackWhenGeneratorThrows() async {
        let text = await ReportService(generator: FailingGenerator()).report(for: input)
        XCTAssertEqual(text, ReportComposer.summary(input))
    }
}
