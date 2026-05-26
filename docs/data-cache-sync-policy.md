# Data, Cache, Prefetch, and Sync Policy

Ohana uses SwiftData for persistence, but rendering should consume small value snapshots. Expensive reads, aggregation, privacy filtering, and sync fan-out belong in services or snapshot builders.

## Read Model Rule

Screens render from scoped read models:

- `RenderState`: minimal value state required by the UI.
- `SnapshotBuilder`: converts SwiftData/service state into render state.
- `Repository` or domain service: owns persistence reads/writes.
- View: binds to render state and emits typed intents.

Views must not perform broad aggregation in `body`.

## Cache Policy

Each cache or snapshot must declare:

- Source of truth.
- Owner.
- Scope: screen, feature, family, member, pet, or global.
- Staleness rule.
- Invalidation triggers.
- Privacy filter.
- Memory cost.
- Persistence behavior.
- Recovery behavior after failed write.
- Whether it can be shown while stale.

## Prefetch Policy

Prefetch only when it has a clear user benefit and a budget gate.

Allowed examples:

- Next likely route after an explicit navigation intent.
- Adjacent detail data for visible carousel/card stack.
- Small thumbnails for visible or near-visible rows.
- Cached dashboard snapshot after a successful business write.
- Notification target snapshot before opening a route.

Not allowed:

- Prefetch all feature dashboards on launch.
- Decode every avatar because the home screen might need one later.
- Refresh all reports after a quick check-in.
- Start network or SwiftData prefetch from reusable row/card body.
- Prefetch while app is backgrounded unless a scheduled task explicitly owns it.
- Prefetch under Low Power Mode, memory pressure, heavy scrolling, or active animation unless the result is needed for the current visible interaction.

## Device-Aware Gate

Prefetch and cache warmup must consider:

- `AppWorkloadPolicy`.
- Scene phase.
- Low Power Mode.
- Reduce Motion where motion-related.
- Current route visibility.
- Memory pressure if available.
- Scroll/animation activity.
- Network availability when networking exists.

## Invalidation Rule

A business write invalidates only the smallest affected read models. Do not use one write to rebuild every dashboard, report, reminder list, inventory view, and widget unless the service explicitly proves those outputs depend on the changed fact.

