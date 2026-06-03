# 0001 — iOS-native stack (Swift / ARKit / Metal)

- **Status:** Accepted
- **Date:** 2026-06-03
- **Deciders:** Founder + engineering

## Context

The product captures real-world spaces as point clouds using LiDAR. Consumer
LiDAR with a usable API exists almost exclusively on Apple hardware (iPhone 12
Pro and later, iPad Pro 2020 and later) through **ARKit** (`sceneDepth`,
`smoothedSceneDepth`, scene-reconstruction mesh anchors, per-pixel confidence).
Android's depth story is fragmented and largely ToF/stereo, not comparable for
site-scale metric capture. The incumbent we're replacing is iOS-only for this
reason.

Options considered:

1. **iOS native (Swift / ARKit / Metal)** — direct hardware access, best capture
   quality, lowest latency, idiomatic UX.
2. Cross-platform (Flutter / React Native) + a native Swift capture module —
   reuse for a future Android/web, but a glue-code tax and we'd still write the
   hard part natively.
3. Unity / AR Foundation — strong 3D rendering and engine portability, but a
   heavy runtime, larger binary, and less idiomatic iOS.

## Decision

Build the capture app **iOS-native in Swift**, using **ARKit** for depth/mesh
capture and **Metal** for point-cloud processing and rendering. Heavy/portable
algorithms (registration, tiling, export) live in cross-platform C++/Rust where
that buys us reuse on the server, but the app shell and capture loop are native.

## Consequences

- ✅ Best possible capture fidelity and capture-time UX; full access to ARKit
  features as Apple ships them.
- ✅ Metal gives us the headroom to render millions of points on-device.
- ✅ Portable compute core (C++/Rust via bridging) can be shared with cloud
  workers, avoiding a total rewrite for server-side processing.
- ⚠️ No Android/web capture in v1. We mitigate the reach concern with a **web
  viewer** for sharing/desktop planning (read-only consumption is cross-platform).
- ⚠️ Requires macOS + Apple hardware to build and device-test. CI for the iOS
  target needs macOS runners.
