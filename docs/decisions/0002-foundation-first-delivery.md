# 0002 — Foundation-first delivery over a rushed launch

- **Status:** Accepted
- **Date:** 2026-06-03
- **Deciders:** Founder + engineering

## Context

The incumbent shuts down at the end of the month, creating pressure to ship
immediately. But App Store review, LiDAR capture polish, and a trustworthy
registration pipeline are not same-week work, and a buggy first impression in a
pro tool (where a bad scan wastes a site visit) is expensive to recover from.

Options: ship a narrow MVP ASAP and iterate live; or invest in the architecture
first and ship a robust v1 slightly later (early July).

## Decision

**Foundation first.** Invest up front in the architecture that removes the
incumbent's structural limits — no scan ceiling, incremental registration, a
local-first sync layer — and target an early-July launch rather than a
last-week-of-June scramble.

## Consequences

- ✅ v1 ships without the incumbent's known pain points baked in.
- ✅ We avoid painting ourselves into a corner that a rushed batch-of-10
  architecture would create.
- ⚠️ A short gap between the incumbent's shutdown and our launch. Mitigate with a
  landing page / waitlist and, if useful, a TestFlight beta during the gap so we
  capture migrating users early.
- ⚠️ "Foundation first" is not a license to gold-plate. Each milestone must
  produce something demoable; we cut scope, not robustness.
