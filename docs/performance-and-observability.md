# Performance and Observability

Ohana performance work is user-flow driven. Do not optimize random code because it looks suspicious; optimize measured user pain, hot paths, launch paths, interaction paths, scrolling paths, and battery-heavy paths.

## Core Quality Domains

Every significant feature must consider:

- Launch performance.
- First meaningful render.
- Tap-to-first-visible-feedback.
- Route transition latency.
- Scroll smoothness and hitch risk.
- Memory growth over long sessions.
- SwiftData query count and query scope.
- Image/avatar decode cost.
- Timer, animation, map, and location energy.
- Correctness of user-visible state.
- Crash and recovery behavior.
- Privacy-safe diagnostics.

## Performance Budget Template

For every new high-traffic flow, document:

```text
Flow:
Entry point:
Critical user action:
First visual feedback:
Heavy work deferred to:
SwiftData reads:
SwiftData writes:
Images decoded:
Timers/repeating work:
Route-scoped tasks:
Cancellation behavior:
Offline/empty/error state:
Low Power behavior:
Reduce Motion behavior:
Metrics/signposts:
Tests:
```

## Suggested Starting Budgets

These are starting targets, not fake guarantees:

- Tap-to-first-visible-feedback: immediate local state change in the same interaction turn.
- Heavy data refresh: after first frame, route presentation, or animation handoff.
- Cold launch: must not regress without explicit review.
- Warm launch: must not perform feature-wide recomputation.
- Route transition: destination shell appears before expensive aggregation.
- Scroll: no broad SwiftData query, image decode, or service fan-out inside row rendering.
- Animation: one user action owns one progress value.
- Background: no repeating UI work unless required by a user-visible active session.

If a budget cannot be met, write the reason and fallback: placeholder, cached snapshot, progressive loading, reduced media quality, or deferred refresh.

## Instrumentation Rule

Critical flows should emit privacy-safe signposts or diagnostics for:

- `flow_start`
- `first_render`
- `first_interaction_feedback`
- `data_ready`
- `write_success`
- `write_failure`
- `route_dismiss`
- `cancellation`
- `recovery_path`

Diagnostics must not include pet names, human names, private notes, PIN, health values, precise routes, or raw user text.

## Probe Naming Convention

Probes registered in `docs/governance/manifests/performance-slo.json` use the
existing `flow.<feature>.<step>` naming (for example `flow.home.card_expand`,
`flow.calendar.open`) and must exist as literals in Swift source — the
governance manifest audit fails when a declared probe disappears. When a probe
graduates from the in-app recorder to `OSSignposter`, keep the same name as the
signpost name so historical notes stay comparable.

## Dense-Data Fixture Standard

"Works on a fresh install" is not validation for aggregation code. The standard
dense-data fixture for snapshot builder and read-model tests is:

- 4 pets + 4 humans + 2 electronic pets.
- 3 years of daily care events per pet (feeding, water, potty, walks)
  ≈ 4,500–6,000 `Event` rows per pet, ≥ 18,000 total.
- 200+ reminders (mixed recurring/one-shot, some overdue).
- 100+ family tasks across states, 500+ ledger entries.
- 50+ photos/attachments with missing-image gaps.
- At least one memorial-mode member and one privacy-locked member.

Aggregation-path tests (snapshot builders, read models, dashboard stores) must
include at least one in-memory test on a dense fixture with an explicit upper
bound on wall-clock build time. Treat the bound as a budget, not a benchmark:
generous enough to be CI-stable (for example 500 ms for a full home snapshot on
a CI runner), tight enough to catch accidental O(n²) regressions.

## Off-Main Aggregation

Deferred work that runs on the main actor still steals scroll frames as data
grows. Snapshot builders and read models for high-frequency surfaces follow the
Off-Main Aggregation Law in `AGENTS.md`: fetch + aggregate in `@ModelActor` or
a background context, deliver small `Equatable` snapshots to the `MainActor`.
The `main-actor-aggregation` smoothness audit rule and the
`main_actor_read_model_refresh` SwiftLint rule flag the anti-pattern; existing
violations are ratcheted in the full-scope audit baseline.

## Required Measurement Scenarios

For performance-sensitive changes, validate at least the relevant subset:

- Cold launch.
- Warm launch.
- First route open.
- Reopen after background.
- Low Power Mode.
- Reduce Motion.
- Elevated thermal state (Instruments or thermal-state override; the
  `AppWorkloadPolicy` thermal budget is tracked in
  `docs/release-hardening-plan.md`).
- Smallest supported iPhone.
- Long localized German text.
- Dense local dataset (see Dense-Data Fixture Standard above).
- Missing images.
- Offline or degraded network.
- Long session after repeated route open/dismiss (memory growth).

