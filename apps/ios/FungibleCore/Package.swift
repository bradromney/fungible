// swift-tools-version: 5.9
import PackageDescription

// FungibleCore — the device-independent core of the Fungible iOS app.
//
// Design rule: these modules depend INWARD on FungibleDomain and on protocol
// modules, and must NOT import ARKit / Metal / RealityKit. The ARKit + Metal
// implementations live in the app target (added in Xcode on macOS) and conform
// to the protocols defined here. That keeps the whole core buildable and
// testable on Linux CI, with no device required.
let package = Package(
    name: "FungibleCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FungibleCore", targets: [
            "FungibleDomain",
            "FungibleCapture",
            "FungibleStorage",
            "FungibleSync",
            "FungibleRegistration",
            "FungibleGuidance",
            "FungibleMeasure",
            "FungibleExport",
            "FungibleInsights",
            "FungibleEntitlements",
        ]),
        .library(name: "FungibleDomain", targets: ["FungibleDomain"]),
    ],
    targets: [
        // Pure value types — no dependencies, no frameworks.
        .target(name: "FungibleDomain"),

        // Device-independent capture math (ARKit/Metal-free).
        .target(name: "FungibleCapture", dependencies: ["FungibleDomain"]),

        // Protocol seams; each depends only on the domain (storage also on capture).
        .target(name: "FungibleStorage", dependencies: ["FungibleDomain", "FungibleCapture"]),
        .target(name: "FungibleSync", dependencies: ["FungibleDomain"]),
        .target(name: "FungibleRegistration", dependencies: ["FungibleDomain"]),
        .target(name: "FungibleGuidance", dependencies: ["FungibleDomain"]),
        .target(name: "FungibleMeasure", dependencies: ["FungibleDomain"]),
        .target(name: "FungibleExport", dependencies: ["FungibleDomain", "FungibleCapture", "FungibleStorage"]),
        .target(name: "FungibleInsights", dependencies: ["FungibleDomain"]),
        .target(name: "FungibleEntitlements", dependencies: ["FungibleDomain"]),

        // Tests for the device-independent core.
        .testTarget(name: "FungibleDomainTests", dependencies: ["FungibleDomain"]),
        .testTarget(name: "FungibleSyncTests", dependencies: ["FungibleSync", "FungibleDomain"]),
        .testTarget(name: "FungibleEntitlementsTests", dependencies: ["FungibleEntitlements", "FungibleDomain"]),
        .testTarget(name: "FungibleMeasureTests", dependencies: ["FungibleMeasure", "FungibleDomain"]),
        .testTarget(name: "FungibleGuidanceTests", dependencies: ["FungibleGuidance", "FungibleDomain"]),
        .testTarget(name: "FungibleCaptureTests", dependencies: ["FungibleCapture", "FungibleDomain"]),
        .testTarget(name: "FungibleStorageTests", dependencies: ["FungibleStorage", "FungibleCapture", "FungibleDomain"]),
        .testTarget(name: "FungibleRegistrationTests", dependencies: ["FungibleRegistration", "FungibleDomain"]),
        .testTarget(name: "FungibleExportTests", dependencies: ["FungibleExport", "FungibleStorage", "FungibleCapture", "FungibleDomain"]),
        .testTarget(name: "FungibleInsightsTests", dependencies: ["FungibleInsights", "FungibleDomain"]),
        .testTarget(name: "FungibleIntegrationTests", dependencies: [
            "FungibleDomain", "FungibleCapture", "FungibleStorage",
            "FungibleRegistration", "FungibleMeasure", "FungibleExport",
        ]),
    ]
)
