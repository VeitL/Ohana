# OS Support Matrix

Mature apps explicitly choose which OS versions they support, balancing reach
against engineering cost. Ohana must make this an intentional, reviewed decision
— not an accident of the default Xcode template.

## Current State (action required)

- `IPHONEOS_DEPLOYMENT_TARGET = 26.2` for all targets (see `Ohana.xcodeproj`).
- Effect: only devices running iOS 26.2+ can install Ohana — a near-empty
  installable base at launch. This is almost certainly unintentionally narrow.
- Tension: `AGENTS.md` already tells agents to "preserve older-iOS fallbacks with
  availability checks," which only makes sense with a lower deployment target.

## Policy

1. **Pick an intentional minimum.** The product owner sets the minimum supported
   iOS major version. The mature default for a consumer app is **N-1 to N-2**
   major versions (i.e., support the two newest majors), unless a required API
   forces a higher floor.
2. **Justify any high floor.** If the floor stays at a very recent version, record
   the specific APIs that require it (e.g., iOS 26 Liquid Glass, a SwiftData
   feature, a Swift Charts API) in this file.
3. **Guard newer APIs.** Features above the floor must use `if #available` /
   `@available` with a graceful fallback, never an unconditional dependency.
4. **CI must run on the floor.** Tests should run at least on the minimum
   supported major and the latest major (see `.github/workflows/ci.yml`).

## Lowering the Deployment Target Is a Migration, Not a Setting

Dropping `IPHONEOS_DEPLOYMENT_TARGET` is **not** a one-line change here, because
the codebase uses iOS 26-era APIs (Liquid Glass, recent SwiftUI/SwiftData/Charts)
in many places. Doing it safely requires:

1. Decide the target floor (e.g., iOS 18).
2. Audit usages of APIs introduced after the floor; wrap each in availability
   checks with fallbacks, or gate the feature.
3. Lower `IPHONEOS_DEPLOYMENT_TARGET` in all targets.
4. Build + test on a simulator at the floor version, not just the latest.
5. Re-run the runtime/UI audits and a full smoke pass.

Until that migration is scheduled, this file records the gap. Do not silently
lower the target in an unrelated change — it will break the build.

## Device Matrix for Testing

Per `docs/performance-and-observability.md`, performance-sensitive changes must be
checked on the **smallest supported iPhone** as well as a current device, at the
minimum and maximum supported OS where feasible.
