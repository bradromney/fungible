# 0003 — Local-first storage with a pluggable sync layer

- **Status:** Accepted
- **Date:** 2026-06-03
- **Deciders:** Founder + engineering

## Context

Point clouds are large (hundreds of MB to multiple GB per session). Storage cost
and upload reliability are real constraints. The founder wants flexibility:
hosted storage for convenience, but also the option to let users bring their own
cloud (Google Drive, iCloud) to offload cost — and the app must work in the
field with no connectivity.

## Decision

**Local-first.** Scans are written to and remain usable on the device; the app is
fully functional offline. Sync is an opt-in layer behind a single
`SyncProvider` interface, with interchangeable drivers:

- `LocalOnly` (default, always available)
- `ICloudProvider` (CloudKit / iCloud Drive — native, zero extra cost to us)
- `GoogleDriveProvider` (BYO — user's storage, user's cost)
- `HostedProvider` (our managed object storage — S3/R2 — for convenience tiers)

The capture, storage, and processing layers never call a cloud SDK directly;
they depend only on the `SyncProvider` abstraction. Uploads are chunked/resumable
and run on background transfers.

## Consequences

- ✅ Cheapest, fastest path to a working app; no server dependency to capture or
  review a scan.
- ✅ The hybrid model (hosted + BYO) the founder wants is reachable by adding
  drivers, not re-architecting.
- ✅ Removing the cloud from the capture critical path is also what lets us drop
  the scan-count ceiling (see ADR-0005).
- ⚠️ Multiple sync drivers = more surface to test (auth, quotas, conflict
  handling). We ship `LocalOnly` + one cloud driver first, add the rest behind
  the same interface.
- ⚠️ Local-first means we own a real on-device storage/format strategy (see the
  architecture doc) rather than treating the server as the source of truth.
