# 0004 — Free MVP, monetization-ready architecture

- **Status:** Accepted
- **Date:** 2026-06-03
- **Deciders:** Founder + engineering

## Context

Monetization model (subscription vs per-scan vs paid storage/export) is a
genuine open question best answered with real usage data. But retrofitting
accounts and entitlements after launch is painful.

## Decision

Ship the MVP **free**, with **no billing**, but build the seams now:

- An `Account` concept (even if anonymous/device-local at first).
- An `Entitlements` service that gates features behind capability flags
  (e.g. `canExportE57`, `hostedStorageQuotaBytes`, `cloudProcessing`). In the
  MVP every flag is open; flipping to paid later is a config + StoreKit change,
  not a refactor.
- Analytics on the actions that could become paywall lines (exports by format,
  storage consumed, scans per set) so we price from evidence.

## Consequences

- ✅ Fast, friction-free adoption during the land-grab window.
- ✅ We can turn on StoreKit subscriptions, credits, or storage tiers later by
  changing entitlement values, not plumbing.
- ⚠️ We must resist building billing UI prematurely; the discipline is to keep
  the *seams* without the *machinery*.
