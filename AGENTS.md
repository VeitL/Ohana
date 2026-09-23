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

- The 1.0 Free / Personal release is local-first Solo, with no Ohana account,
  developer-hosted care backend, or account data collection. iCloud Drive
  backup is not app authentication.
- Ohana Family in-app guardian is the sole approved developer-hosted online
  capability, but is excluded from 1.0 and remains behind its runtime and
  release gates. Follow D4/D25/D31 in `docs/specs/product-foundation.md`;
  broader account, CloudKit sync, and cross-device collaboration plans do not
  authorize implementation.
- Do not change capabilities, entitlements, signing, or release scope unless the
  user explicitly asks.
- Derive the current SwiftData schema and registered languages from
  `Ohana/Models/SharedModelContainer.swift` and
  `Ohana/Shared/LocalizationSettings.swift` rather than dated documentation.

## Work Safely

- Before editing, inspect `git status --short` and preserve unrelated work.
- In a dirty worktree, identify the current task's files and baseline before
  editing; do not attribute results from mixed, unreviewed changes to the task.
- Review, audit, diagnosis, explanation, and status requests are read-only.
- Implement requested changes surgically. Do not widen the repair because an
  unrelated file, test, or shared-worktree process fails.
- In-scope edits, read-only checks, and guarded local tests need no separate
  approval. Commit, push, PR creation, remote CI, branch/worktree creation,
  signing, release, file deletion, and destructive Git operations require
  explicit user approval.

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
- Preserve Dynamic Type, accessibility, dark mode, RTL, and copy in every
  language registered by `AppLanguage.supported` through the existing
  localization APIs and fallback rules.
- Update touch feedback and non-persistent route state immediately. When a
  success state or route depends on a persistent fact, wait for the domain
  command to commit. Start independent heavier work after the visual handoff.

## Validation

- Use the narrowest trustworthy proof after code stabilizes. Do not repeat an
  unchanged passing command or validate merely for reassurance.
- For changes needing runtime acceptance, define the shortest relevant journey
  before editing. Include existing-user cold launch, resume, or media readback
  when affected; check these on `iPhone 17 Tests` where possible before the
  stabilized batch's guarded Dogfood or physical-device acceptance. Reserve
  Release overlays and authorized archives for stabilized batches and necessary
  final acceptance.
- For build-speed changes, inspect build timing summaries before changing
  targets, compiler settings, or caches; retain only measured improvements to
  the edit-to-feedback cycle without weakening required validation.
- Do not add tests for reversible, low-impact changes when they would merely
  mirror the implementation.
- Documentation-only changes need `git diff --check` and a relevant
  documentation or governance audit, never an app build. Small visual changes
  use path-scoped UI/accessibility checks when applicable; no build, Simulator,
  or screenshots by default. Logic changes use the narrowest relevant
  Unit/Integration test; a passing targeted test that compiles the affected
  target replaces a separate build.
- Keep test environments separate: isolated SwiftData containers for
  Unit/Integration tests; the disposable `iPhone 17 Tests` Simulator/store for
  onboarding, migration, restore, reset, deletion, permissions, and empty-state
  flows; and the pinned `iPhone 17 Dogfood` Simulator for one long-lived
  synthetic user. Automated Simulator work uses only `iPhone 17 Tests`; reset
  it only through `scripts/reset-test-simulator.sh`. Test entrypoints must
  reject the Dogfood UDID.
- Run local Xcode tests only through `scripts/xcode-test.sh`, not ad hoc
  `xcodebuild test`. Its default is a narrow smoke suite; full Unit, UI,
  coverage, repetition, and parallel workers require explicit options. Use
  Simulator for an explicit visual/flow request, a Simulator-only defect, or
  the Dogfood acceptance below. Capture only final evidence.
- Dogfood is the default second-stage acceptance after narrow proof for a
  stabilized change affecting persisted facts or existing-user state: schema
  and migration, persistent commands and projections, recurring plans and
  reminders, wallet and economy, route restoration, upgrade readback, or
  accumulated-data performance. Through `scripts/run-dogfood-simulator.sh`,
  run one relevant normal-UI journey against the final Release artifact per
  stabilized batch. This is standing authorization; repeat only after failure
  or an explicit user request.
- Follow `docs/dogfood-testing.md` before a Dogfood journey. Seal the ready
  user's hashed SwiftData identity before the first overlay. Never use XCTest,
  UI-test/reset/seed arguments, direct store/defaults writes, Debug economy
  tools, erase, uninstall, reset, or destructive flows on Dogfood. Skip it for
  documentation-only work, isolated logic with no runtime or persistence
  effect, unchanged artifacts, destructive/empty-state flows, and hardware-only
  behavior. Report any unsafe skip and its remaining existing-data risk.
- Physical-device validation owns notification delivery, permissions,
  background behavior, energy, and other hardware-dependent evidence.

### Xcode Storage Safety

- Use the repository build/test entrypoints' shared hashed cache outside the
  source tree and their atomic project lock. Never make task-specific
  DerivedData or bypass the lock without explicit user acceptance of concurrent
  shared-cache risk. Honor `.build/xcode-cache-parent`; stop if its volume is
  unavailable. Build/test preflight stops below 20 GiB free.
- Follow the entrypoints' bounded xcresult and Simulator-cache retention. Audit
  storage with `scripts/xcode-storage-audit.sh` before cleanup; apply only a
  reviewed token from `scripts/cleanup-local-build-storage.sh`. Never globally
  delete Xcode, Simulator, runtime, Archive, or DeviceSupport data. Never
  remove the pinned Dogfood Simulator, app data, SwiftData store, identity seal,
  or evidence. After two failures or abnormal-growth runs of one test, audit
  storage before retrying.
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
