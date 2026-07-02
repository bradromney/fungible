# FungibleApp (iOS app target — M1 capture loop)

> ⚠️ **Xcode / macOS only.** These sources import ARKit, Metal, and SwiftUI, so
> they are **not** part of the `FungibleCore` Swift package and are **not** built
> by CI. They compile and run only from Xcode on macOS, on a LiDAR device
> (iPhone 12 Pro+ / iPad Pro 2020+). They are written against — and validated by
> — the CI-tested `FungibleCore` (capture math, storage, guidance), so the risky
> parts are already proven; this layer is the ARKit/Metal/UI shell on top.

## What's here (milestone M1 — single-scan capture loop)

```
Sources/FungibleApp/
  FungibleAppApp.swift            @main entry, app-level dependencies
  Capture/
    ARDepthCaptureSession.swift   ARKit session: sceneDepth + confidence + mesh
    PointCloudUnprojector.metal   GPU unprojection (mirrors FungibleCapture math)
    DepthUnprojector.swift        CPU unprojection → CapturedPoint buffer (the
                                  Metal compute kernel exists but is not yet dispatched)
    CaptureSignalsBuilder.swift   ARFrame → FungibleGuidance.CaptureSignals
  UI/
    CaptureView.swift             SwiftUI capture screen
    CaptureViewModel.swift        Owns session + accumulator + guidance + save
    ARViewContainer.swift         UIViewRepresentable hosting the ARView
    GuidanceOverlay.swift         Live coaching prompts (ObjectCapture-style)
  Resources/
    Info.plist                    NSCameraUsageDescription, ARKit requirement
project.yml                       XcodeGen spec (reproducible .xcodeproj)
```

## Generating the Xcode project

This directory ships an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec so
the `.xcodeproj` is reproducible and not committed:

```sh
brew install xcodegen
cd apps/ios/FungibleApp
xcodegen generate          # produces FungibleApp.xcodeproj
open FungibleApp.xcodeproj
```

The project references the sibling `FungibleCore` package by relative path, so
the app and core build together. Select a LiDAR device (not the simulator —
`sceneDepth` requires the hardware sensor) and run.

## How it maps to the architecture

- Capture follows [ADR-0005](../../../docs/decisions/0005-no-scan-ceiling.md):
  every finished scan auto-saves via `FungibleStorage.ScanStore`; M1 captures one
  scan, M3 adds incremental multi-scan registration.
- The Metal unprojection (`PointCloudUnprojector.metal`) is the GPU mirror of
  `FungibleCapture.Unprojection`; the CPU path is the spec and test oracle.
- Guidance prompts come straight from `FungibleGuidance.RuleBasedGuidanceEngine`
  fed by `CaptureSignalsBuilder`.
