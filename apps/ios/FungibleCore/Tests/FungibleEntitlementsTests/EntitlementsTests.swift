import XCTest
@testable import FungibleEntitlements

final class EntitlementsTests: XCTestCase {
    func testMVPGrantsEveryCapability() {
        let service = EntitlementsService() // defaults to .mvpFreeEverything
        for capability in Capability.allCases {
            XCTAssertTrue(service.isEnabled(capability), "MVP should enable \(capability)")
        }
        XCTAssertNil(service.storageQuota.bytes, "MVP storage is unlimited")
    }

    func testRestrictedTierGatesPaidCapabilities() {
        // Simulate a future free tier: capture is open, pro exports are not.
        let free = EntitlementSet(
            enabled: [.unlimitedScansPerSet, .exportLAZ, .webShare],
            storage: Quota(bytes: 5_000_000_000)
        )
        let service = EntitlementsService(entitlements: free)
        XCTAssertTrue(service.isEnabled(.unlimitedScansPerSet))
        XCTAssertTrue(service.isEnabled(.exportLAZ))
        XCTAssertFalse(service.isEnabled(.exportE57))
        XCTAssertFalse(service.isEnabled(.cutFillVolume))
        XCTAssertEqual(service.storageQuota.bytes, 5_000_000_000)
    }

    func testEntitlementSetCodableRoundTrip() throws {
        let original = EntitlementSet.mvpFreeEverything
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EntitlementSet.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
