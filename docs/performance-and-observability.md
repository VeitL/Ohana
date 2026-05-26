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

## Required Measurement Scenarios

For performance-sensitive changes, validate at least the relevant subset:

- Cold launch.
- Warm launch.
- First route open.
- Reopen after background.
- Low Power Mode.
- Reduce Motion.
- Smallest supported iPhone.
- Long localized German text.
- Large local dataset.
- Missing images.
- Offline or degraded network.
- Long session after repeated route open/dismiss.

