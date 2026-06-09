# Round 4 Runtime and Energy Evidence

> Date: 2026-06-08
>
> Scope: runtime loops, timers, TimelineView, Canvas, maps, location, background behavior, and energy ownership.

## Inventory

Command:

`rg` inventory over `Ohana/**/*.swift`.

Findings:

| Runtime class | Count | Mature-app expectation |
|---|---:|---|
| `repeatForever` | 44 | Must be visible, policy gated, and removable without breaking business state. |
| `TimelineView(.animation...)` | 5 | Must be paused or reduced by visibility/workload policy. |
| `TimelineView(.periodic...)` | 4 | Must be visible-page scoped; active walk clocks may use active-walk exception. |
| `Timer.publish` | 1 | Must be route/surface scoped and workload-policy aware. |
| `Canvas(...)` | 1 | Must be static or policy gated when used in app surfaces. |
| `CLLocationManager(...)` | 1 | Must remain centralized. |
| `allowsBackgroundLocationUpdates = true` | 1 | Must be active-walk only. |
| `requestAlwaysAuthorization(...)` | 1 | Must remain behind the walking/location owner. |

## Repair 1 - Runtime/Energy Ownership Manifest

Added `docs/governance/manifests/runtime-energy-ownership.json`.

The manifest now records owner, scope, runtime classes, visibility gate, Low Power Mode gate, Reduce Motion gate, background gate, policy gate, evidence, and real source paths for:

- `app-workload-policy-root`
- `active-walk-location`
- `home-high-traffic-ambient-motion`
- `app-background-ambient-surfaces`
- `route-presentation-deferrals`
- `design-preview-labs`

`scripts/audit-governance-manifests.sh` now treats the runtime/energy manifest as a required hard gate and validates those fields and paths.

## Repair 2 - Streak Flame Runtime Gate

Interaction class: `runtime`, `ambient motion`, `home high-traffic surface`.

Non-negotiable invariants:

- The streak particle loop must not run in background, Low Power Mode, Reduce Motion, or user power-saving mode.
- The loop must be decorative only and hidden from VoiceOver.
- The changed file must pass runtime, smoothness, and accessibility ratchets.

Implemented structure:

`StreakFlameParticles -> AppWorkloadPolicy.ambientMotionBudget -> repeatForever or static phase`

Code changes:

- Replaced local power/reduce-motion checks with `AppWorkloadPolicy`.
- Added `onChange` handling so policy changes stop/restart the loop.
- Converted the decorative emoji font to an `OhanaFont` token.
- Marked the particle cluster as noninteractive decorative content for accessibility audit clarity.

## Compliance Matrix

| Gate | Status | Evidence |
|---|---|---|
| Runtime ownership | Compliant | `runtime-energy-ownership.json` is required by governance manifest audit. |
| Visibility gating | Compliant | Runtime surfaces declare visibility gates; Streak particles ask ambient motion budget. |
| Low Power Mode | Compliant | `AppWorkloadPolicy.ambientMotionBudget` returns static under Low Power Mode. |
| Reduce Motion | Compliant | `AppWorkloadPolicy.ambientMotionBudget` returns static under Reduce Motion. |
| Background pause | Compliant | `ambientMotionBudget` pauses ambient motion when not foreground. |
| Active-walk exception | Compliant | Location/background behavior remains centralized and documented under `active-walk-location`. |
| Changed-file smoothness | Compliant | `scripts/audit-smoothness-risk.sh --changed` passed. |
| Full runtime guardrails | Compliant | `scripts/audit-runtime-guardrails.sh --all` passed on 435 Swift files. |
| Fixed simulator build | Compliant | Fixed iPhone 17 simulator Debug build passed after the Swift runtime-gate change. |

## Validation

- `scripts/audit-governance-manifests.sh` passed.
- `scripts/audit-runtime-guardrails.sh --changed` passed.
- `scripts/audit-runtime-guardrails.sh --all` passed.
- `scripts/audit-smoothness-risk.sh --changed` passed.
- `scripts/audit-accessibility.sh --changed` passed.
- `scripts/release-hardening-check.sh --skip-build` passed.
- `DERIVED_DATA_PATH=/tmp/OhanaDD-fullscore-round4-runtime scripts/build-debug-fast.sh` passed on `platform=iOS Simulator,name=iPhone 17` with `-sdk iphonesimulator`.

Remaining Round 4 work:

- The manifest makes ownership auditable, but future rounds should still inspect individual runtime surfaces when they are touched, especially `TimelineView(.animation)` and map refresh paths.
