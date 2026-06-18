import XCTest
import FungibleDomain
import FungibleGuidance
import FungibleEntitlements
@testable import FungiblePresentation

final class ProjectPresentationTests: XCTestCase {

    // MARK: SyncState

    func testLocalOnlyIsNotAnError() {
        XCTAssertFalse(SyncState.localOnly.isError)
        XCTAssertFalse(SyncState.synced.isError)
        XCTAssertTrue(SyncState.needsAttention.isError)
    }

    // MARK: ProjectType detection

    func testDetectObjectFromSmallExtent() {
        let b = BoundingBox(min: Vector3(0, 0, 0), max: Vector3(0.8, 0.5, 0.6))
        XCTAssertEqual(ProjectType.detect(bounds: b), .object)
    }

    func testDetectSiteFromWideShallowFootprint() {
        // 30 m × 25 m ground, only 3 m tall → open site.
        let b = BoundingBox(min: Vector3(0, 0, 0), max: Vector3(30, 3, 25))
        XCTAssertEqual(ProjectType.detect(bounds: b), .site)
    }

    func testDetectInteriorFromRoomScale() {
        // 6 m × 4 m room, 2.7 m ceiling → interior (footprint 24 m² < 100).
        let b = BoundingBox(min: Vector3(0, 0, 0), max: Vector3(6, 2.7, 4))
        XCTAssertEqual(ProjectType.detect(bounds: b), .interior)
    }

    func testContextualToolSwapsPerType() {
        XCTAssertEqual(ProjectType.site.contextualToolLabel, "Cut/Fill")
        XCTAssertEqual(ProjectType.interior.contextualToolLabel, "Floorplan")
        XCTAssertEqual(ProjectType.object.contextualToolLabel, "Mesh")
    }

    // MARK: ProjectRowModel

    func testRowModelDerivesFromScanSet() {
        let s1 = Scan(
            capturedAt: Date(timeIntervalSince1970: 1_781_792_040),  // Jun 18 14:14 UTC
            pointCloud: PointCloudRef(pointCount: 800_000)
        )
        let s2 = Scan(
            capturedAt: Date(timeIntervalSince1970: 1_781_795_640),  // Jun 18 15:14 UTC (later)
            pointCloud: PointCloudRef(pointCount: 400_000)
        )
        var set = ScanSet(name: "North Lot")
        set.append(s1)
        set.append(s2)

        let row = ProjectRowModel(
            from: set,
            sync: .synced,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "UTC")!
        )

        XCTAssertEqual(row.name, "North Lot")
        XCTAssertEqual(row.passCountLabel, "2 passes")
        XCTAssertEqual(row.pointCountLabel, "1.2M pts")          // 800k + 400k
        XCTAssertEqual(row.timestampLabel, "Jun 18, 2026 · 3:14 PM")  // latest pass
        XCTAssertEqual(row.sync, .synced)
    }

    func testScanStatusDisplay() {
        XCTAssertEqual(ScanStatus.registered.displayLabel, "Registered")
        XCTAssertFalse(ScanStatus.registered.needsAttention)
        XCTAssertFalse(ScanStatus.registered.isInProgress)
        XCTAssertTrue(ScanStatus.registering.isInProgress)
        XCTAssertTrue(ScanStatus.failed.needsAttention)
        for s in ScanStatus.allCases {
            XCTAssertFalse(s.displayLabel.isEmpty)
            XCTAssertFalse(s.symbolName.isEmpty)
        }
    }

    func testEmptyProjectFallsBackToCreatedAt() {
        let set = ScanSet(name: "Fresh", createdAt: Date(timeIntervalSince1970: 1_781_792_040))
        let row = ProjectRowModel(
            from: set,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertEqual(row.passCountLabel, "0 passes")
        XCTAssertEqual(row.pointCountLabel, "0 pts")
        XCTAssertEqual(row.timestampLabel, "Jun 18, 2026 · 2:14 PM")
        XCTAssertEqual(row.sync, .localOnly)  // default resting state
    }
}

final class GuidancePresentationTests: XCTestCase {

    func testEveryPromptKindMapsToASymbol() {
        // Exhaustive: each kind yields a non-empty SF Symbol name.
        let kinds: [Prompt.Kind] = [
            .slowDown, .moveCloser, .improveLighting,
            .rescanLowConfidence, .fillGap, .coverageComplete, .holdSteady,
        ]
        for k in kinds {
            XCTAssertFalse(GuidancePresentation.symbolName(for: k).isEmpty)
        }
    }

    func testDisplayedTakesTopTwoBySeverity() {
        // Engine returns severity-sorted; presentation takes the top two.
        let high = Prompt(kind: .slowDown, message: "slow", severity: 90)
        let mid = Prompt(kind: .fillGap, message: "gap", severity: 45)
        let low = Prompt(kind: .rescanLowConfidence, message: "rescan", severity: 50)
        let (primary, secondary) = GuidancePresentation.displayed([high, low, mid])
        XCTAssertEqual(primary, high)
        XCTAssertEqual(secondary, low)
    }

    func testDisplayedHandlesEmptyAndSingle() {
        let none = GuidancePresentation.displayed([])
        XCTAssertNil(none.primary)
        XCTAssertNil(none.secondary)

        let one = Prompt(kind: .holdSteady, message: "hold", severity: 70)
        let single = GuidancePresentation.displayed([one])
        XCTAssertEqual(single.primary, one)
        XCTAssertNil(single.secondary)
    }
}

final class ExportCatalogTests: XCTestCase {

    func testAllFormatsGroupedByIntent() {
        XCTAssertEqual(ExportCatalog.formats(in: .pointCloud).map(\.ext),
                       ["LAZ", "COPC", "E57", "PLY"])
        XCTAssertEqual(ExportCatalog.formats(in: .cadBim).map(\.ext),
                       ["DXF", "IFC", "LandXML"])
        XCTAssertEqual(ExportCatalog.formats(in: .model3D).map(\.ext),
                       ["USDZ", "OBJ", "glTF"])
    }

    func testEveryFormatHasACardTag() {
        for f in ExportCatalog.all {
            XCTAssertFalse(f.tag.isEmpty, "\(f.ext) missing a card tag")
        }
    }

    func testUnsupportedFallbackRedirectsMeshOnEmptyProject() {
        let usdz = ExportCatalog.all.first { $0.ext == "USDZ" }!
        let laz = ExportCatalog.all.first { $0.ext == "LAZ" }!
        // A mesh format on a project with no geometry → redirect to PLY.
        XCTAssertEqual(ExportCatalog.unsupportedFallback(for: usdz, pointCount: 0), "PLY")
        // With geometry, the mesh format is fine.
        XCTAssertNil(ExportCatalog.unsupportedFallback(for: usdz, pointCount: 1000))
        // Point-cloud formats are always fine.
        XCTAssertNil(ExportCatalog.unsupportedFallback(for: laz, pointCount: 0))
    }

    func testSoftProBadgingUnderFreeMVP() {
        let ent = EntitlementsService(entitlements: .mvpFreeEverything)
        let e57 = ExportCatalog.all.first { $0.ext == "E57" }!
        let laz = ExportCatalog.all.first { $0.ext == "LAZ" }!
        // E57 is a paywall candidate → soft-badged (but still enabled & usable).
        XCTAssertTrue(ExportCatalog.isSoftPro(e57, entitlements: ent))
        XCTAssertTrue(ent.isEnabled(e57.capability))
        // LAZ is core interop → never badged.
        XCTAssertFalse(ExportCatalog.isSoftPro(laz, entitlements: ent))
    }
}
