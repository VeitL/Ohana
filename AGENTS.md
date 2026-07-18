# Repository Guidelines

Ohana is a local-first iOS app built with SwiftUI and SwiftData. Keep light
interactions light and changes focused.

## Start Here

- The current user request has highest priority.
- Product behavior comes from `docs/specs/product-foundation.md`.
- Use `README.md` and `docs/README.md` to find task-relevant sources. Read only
  what the task needs; current source and tests decide implementation truth.
- `AGENTS.md` is the only root agent rule file. Do not create parallel root or
  editor rule files.

## Product Scope

- The first release is local-first Solo. It has no Ohana account,
  developer-hosted backend, or account data collection. iCloud Drive backup is
  not app authentication; deferred planning does not authorize implementation.
- Do not change capabilities, entitlements, signing, or release scope unless the
  user explicitly asks.
- Derive the current SwiftData schema and registered languages from
  `Ohana/Models/SharedModelContainer.swift` and
  `Ohana/Shared/LocalizationSettings.swift` rather than dated documentation.

## Work Safely

- Before editing, inspect `git status --short` and preserve unrelated work.
- Review, audit, diagnosis, explanation, and status requests are read-only.
- Implement requested changes surgically. Do not widen the repair because an
  unrelated file, test, or shared-worktree process fails.
- Commit, push, PR, remote CI, branch/worktree creation, signing, release, file
  deletion, and destructive Git operations require explicit user approval.

## Non-Negotiable Engineering Boundaries

- Views own visual state and emit intents; domain services or command executors
  own persistent business facts and invariants.
- Views never edit coconut balances, rewards, reminders, family tasks, or ledger
  side effects directly. Coconut rewards use the existing economy chokepoints.
- High-frequency UI reads use bounded queries, snapshots, or read models rather
  than broad reusable-view `@Query` aggregation.
- Before changing a SwiftData model, inspect the latest schema, add the next
  schema, and append it to the migration plan.
- `@ModelActor` work returns `Sendable` identifiers or value DTOs, never live
  SwiftData models.
- `AppWorkloadPolicy` owns power, thermal, timer, refresh, and repeating-motion
  decisions.

## UI And Localization

- Prefer native semantic SwiftUI controls and existing shared components.
- Use `ui规范.selection.json` and the UI reference docs only when the changed
  surface needs those decisions; a small local edit does not require loading or
  revalidating the whole design system.
- Preserve Dynamic Type, accessibility, dark mode, RTL, and localized Chinese
  and English copy through the existing localization APIs.
- Finger feedback and route state update first; persistence and heavier work
  start after the visual handoff.

## Validation

- Use the narrowest trustworthy proof after code stabilizes. Do not repeat an
  unchanged passing command or validate merely for reassurance.
- Use three test environments instead of forcing every test into one mutable
  Simulator: an isolated SwiftData container for Unit/Integration tests, a
  disposable clean Simulator/store for destructive flows, and the pinned
  `iPhone 17 Dogfood` Simulator for one long-lived synthetic user.
- Dogfood is the default second-stage acceptance environment after narrow tests
  pass for a stabilized change that can affect persisted facts or stateful
  existing-user behavior. This includes schema/migration compatibility,
  persistent commands and projections, recurring plans/reminders, wallet and
  economy flows, route restoration, upgrade readback, and accumulated-data
  performance. Run one relevant normal-UI journey against the final Release
  artifact; this is standing authorization and needs no per-task confirmation.
  It never authorizes destructive actions. Run at most once per stabilized
  change batch unless the first journey fails or the user explicitly requests
  another run; do not overlay on every edit.
- Follow `docs/dogfood-testing.md` for persistent Dogfood journeys. Use only
  `scripts/run-dogfood-simulator.sh`, its Release overlay, and normal product UI;
  seal the ready user's hashed SwiftData identity before the first overlay;
  never use XCTest, UI-test/reset/seed arguments, direct store/defaults writes,
  Debug economy tools, erase, uninstall, reset, or destructive
  onboarding/migration/restore scenarios on that virtual phone.
- Use a disposable clean environment for onboarding, migration, backup restore,
  app reset, deletion, permissions, and any test that assumes empty state.
  Physical-device validation still owns notification delivery, permissions,
  background behavior, energy, and other hardware-dependent evidence.
- Automated Simulator work uses only `iPhone 17 Tests`; every local test
  entrypoint must reject the pinned Dogfood UDID. Destructive Simulator setup
  goes through `scripts/reset-test-simulator.sh` and may target only that test
  device.
- Reuse `.build/DerivedData/tests`, `.build/DerivedData/dogfood`, and
  `.build/DerivedData/release`; do not create task-, TFU-, branch-, or
  timestamp-named DerivedData. Build/test preflight stops below 20 GiB free and
  reports oversized `.build` or Simulator caches before doing work.
- Documentation-only changes need `git diff --check` and only the relevant
  documentation or governance audit; never build the app for them.
- Small visual changes use path-scoped UI/accessibility checks when applicable;
  they do not require a build, Simulator run, or screenshots by default.
- Logic changes use the narrowest relevant Unit/Integration test. A successful
  targeted test that compiles the affected target replaces a separate build.
- Skip Dogfood for documentation-only work, isolated logic with no runtime or
  persistence effect, unchanged artifacts, destructive/empty-state flows, and
  hardware-only behavior. When a normally relevant change cannot safely use
  Dogfood, report the concrete reason and remaining existing-data risk.
- Use Simulator for an explicit visual/flow request, a simulator-only defect,
  or the default Dogfood acceptance above. Target `iPhone 17 Tests` for
  automated/disposable work and the pinned `iPhone 17 Dogfood` only through its
  guarded existing-data workflow; capture only final evidence, not every step.
- Report commands actually run, their results, and any unverified risk. Stop
  when the requested behavior has trustworthy evidence.

## Detailed References

Open these only when the task reaches their scope:

- Architecture and runtime: `docs/app-architecture-governance.md`
- UI design: `docs/design/ohana-ui-spec.md`
- Privacy and data safety: `docs/privacy-compliance.md`
- Release evidence: `docs/release-quality-gates.md`
- Long-lived synthetic user: `docs/dogfood-testing.md`
- Status and deferred work: `docs/status-ledger-map.md` and
  `docs/task-follow-ups.md`
