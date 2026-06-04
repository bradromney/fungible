# Device build runbook (M1 capture loop)

The one step that needs your hardware: building `FungibleApp` onto a LiDAR
iPhone/iPad. ~30–45 min, mostly one-time signing setup. Everything below is
prepared so this is copy-paste.

## Prerequisites
- A Mac with **Xcode 15+**.
- A **LiDAR device**: iPhone 12 Pro/Pro Max or later Pro, or iPad Pro (2020+).
  (The simulator can't do `sceneDepth` — you need the real sensor.)
- A free **Apple ID** (no paid account needed for development install).

## Steps

```sh
# 1. Tools
brew install xcodegen

# 2. Generate the Xcode project from the committed spec
cd apps/ios/FungibleApp
xcodegen generate          # creates FungibleApp.xcodeproj
open FungibleApp.xcodeproj
```

In Xcode:
3. Select the **FungibleApp** target → **Signing & Capabilities** → check
   *Automatically manage signing* → pick your **Team** (your Apple ID).
   Xcode sets a unique bundle id if needed.
4. Plug in your device, select it as the run destination.
5. **⌘R** to build & run. First launch: approve the developer cert on-device
   (Settings → General → VPN & Device Management) and grant camera permission.

## What you should see (M1 acceptance)
- Live camera with the guidance overlay (slow-down / lighting / coverage prompts).
- A running **point count** as you scan.
- **Finish Scan** saves the scan locally (auto-save, no manual step).

## If something's off
- *Build error about FungibleCore*: ensure the repo is intact; the app references
  the sibling `../FungibleCore` Swift package by relative path.
- *No depth / black overlay*: confirm a LiDAR device (not simulator).
- *Signing error*: pick your Team in Signing & Capabilities; change the bundle id
  prefix if `ai.fungible` collides.

## After it runs — what we tune with real capture
- Confirm the Metal unprojection matches the CPU spec on-device (axis/sign).
- Profile registration latency on real scans → confirms the Swift ICP target
  (ADR-0008) or tells us to wire GICP.
- Add the live Metal point-cloud preview (currently a camera passthrough).
- Wire **Finish → assemble → export** (PLY/LAS/OBJ/glTF — all already in core).
