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

## Code-First Performance Triage

Before profiling, inspect the target SwiftUI path for the common high-impact
smells:

- Broad `@Observable`, `ObservableObject`, `@Environment`, or `@Query` fan-out.
- Unstable identity in `ForEach`, lists, grids, sheets, or route paths.
- Sorting, filtering, formatting, localization, image decode, or service calls in
  `body` / view builders / row rendering.
- Top-level conditional view swapping that churns the root tree for small state
  changes.
- Layout thrash from nested `GeometryReader`, preference chains, or custom scroll
  containers where `List`, `LazyVStack`, or `LazyHGrid` would suffice.
- Animation or transition work attached to too broad a subtree.

If code review explains the symptom, fix the root cause and validate the same
flow. Use runtime traces only when code review is inconclusive, the path is
high-traffic, or before/after numbers are needed.

## Instruments and ETTrace Evidence

Runtime performance evidence must be one focused user-visible flow, not "use the
app for a while."

- Record start and stop points before capturing.
- Prefer Release or release-like builds when possible; call out Debug-only
  caveats.
- For ETTrace, link the tracing framework only as a temporary simulator/debug
  profiling patch, collect UUID-matched dSYMs, preserve fresh processed
  `output_*.json` files, and analyze only symbolicated first-party stacks.
- Treat meaningful first-party "have library but no symbol" output as a failed
  trace. Do not draw product conclusions from unsymbolicated flamegraphs.
- Report artifacts, simulator/device, run count, top first-party stacks, sample
  weights, and caveats. Before/after deltas require comparable setup.

## Leak and Memory-Growth Evidence

Long-session memory growth and retained route snapshots are release-risk issues.
A credible leak report includes:

- The exact flow and simulator/app build.
- Before/after memgraph paths for the same flow when a fix is made.
- App-owned leaked types and counts.
- A trace-tree ownership path, grouped leak tree, or source-level retaining edge.
- The specific edge removed or lifetime narrowed.
- Remaining framework/runtime noise called out separately.

Do not claim a leak fix from smaller total memory alone. The app-owned type or
ownership path must disappear or be explained.

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
- Elevated thermal state (Instruments or thermal-state override through
  `AppWorkloadPolicy`).
- Smallest supported iPhone.
- Long localized German text.
- Dense local dataset (see Dense-Data Fixture Standard above).
- Missing images.
- Offline or degraded network.
- Long session after repeated route open/dismiss (memory growth).
