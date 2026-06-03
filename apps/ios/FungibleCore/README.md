# FungibleCore

The device-independent core of the Fungible iOS app, as a Swift Package. See the
[architecture overview](../../../docs/architecture/overview.md) for the full
picture.

## Why a package (and not just an app)

Everything here is **pure Swift with no ARKit / Metal / RealityKit imports**, so
it builds and unit-tests on Linux CI with no Apple device. The ARKit capture and
Metal rendering live in the Xcode app target (added on macOS) and *conform to the
protocols defined here*. Dependencies point **inward** to `FungibleDomain`.

## Modules

| Module | What it holds |
| --- | --- |
| `FungibleDomain` | Pure value types: `Vector3`/`Quaternion`/`Transform`, IDs, `Scan`, `ScanSet`, `PoseGraph`, `RegionOfInterest`, `Measurement`, `Annotation`. |
| `FungibleStorage` | `ScanStore` protocol (local-first catalog + blob persistence). |
| `FungibleSync` | `SyncProvider` protocol + working `LocalOnlyProvider`. |
| `FungibleRegistration` | Protocols for the no-ceiling pipeline (coarse/fine aligners, pose-graph optimizer, loop closer, `Registrar`). |
| `FungibleGuidance` | `GuidanceEngine` + a working `RuleBasedGuidanceEngine`. |
| `FungibleMeasure` | `HeightGrid` DEM + working `CutFillEngine` (the earthwork moat). |
| `FungibleEntitlements` | `Capability` flags + `EntitlementsService` (monetization seams). |

What's **real** today (with tests): the domain model + math, `LocalOnlyProvider`,
the rules-based guidance engine, the cut/fill volume math, and entitlements.
What's **protocol-only** today (implemented later, on-device or via C++/Rust
bridge): capture, registration, the concrete store, and cloud sync drivers.

## Build & test

```sh
cd apps/ios/FungibleCore
swift build
swift test
```

Requires a Swift 5.9+ toolchain. CI runs this on every push (see
`.github/workflows/ci.yml`). The full app (ARKit + Metal + SwiftUI) is built from
Xcode on macOS with a LiDAR device.
