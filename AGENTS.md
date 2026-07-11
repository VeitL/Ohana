# Repository Guidelines

In Ohana, a light interaction must stay light. Visual feedback, route mutation,
data aggregation, persistence, background work, timers, and animation loops
have explicit ownership and handoff points.

## Authority And Orientation

`AGENTS.md` is the only root agent and repository-navigation rule file. Do not
create a parallel `CONTEXT.md`, `UIRules.md`, `.cursorrules`, `.cursor/`,
`.windsurf/`, or another root/editor rule copy.

Rule precedence:

1. Current user request.
2. Product and acceptance truth: `docs/specs/product-foundation.md`.
3. Engineering workflow and agent conduct: `AGENTS.md`.
4. UI tokens and component choices: `ui规范.selection.json`.
5. Task-relevant active governance or feature specifications under `docs/`.
6. Current source and tests.
7. Dated plans, audits, reference exports, and archives.

Start at `README.md`. Use `docs/README.md` to distinguish active truth from
historical evidence. Read only the documents required by the task; do not load
the whole documentation tree by default.

`docs/specs/product-foundation.md` decides what Ohana should do. `AGENTS.md`
decides how to change and verify it. Historical material never overrides either.

Use `docs/task-follow-ups.md` only for real blockers, external actions,
cross-scope repairs, meaningful validation gaps, or important deferred work.
Use `docs/status-ledger-map.md` to route durable status updates.

## Current Project Facts

- Ohana is an iOS SwiftUI app using SwiftData and Swift Charts.
- The first release is local-first Solo. Capability truth comes from current
  project configuration and `docs/specs/product-foundation.md`.
- The app declares no App Group entitlement. A future extension uses
  `group.com.guanchen.li.Ohana`; never revive an older `Ark` identifier.
- The latest SwiftData schema is derived from
  `Ohana/Models/SharedModelContainer.swift`; never copy a version number here.
- Registered languages are derived from
  `Ohana/Shared/LocalizationSettings.swift`. Chinese and English are mandatory
  when authoring user-facing copy; other languages use the defined fallback.

Main layout:

- `Ohana/App/`: shell, routes, lifecycle, startup, and runtime policy.
- `Ohana/Features/<Feature>/`: feature UI, commands, services, and read models.
- `Ohana/Domain/`: cross-feature commands, events, services, and economy gates.
- `Ohana/Models/`: SwiftData models only.
- `Ohana/Shared/`: localization, reusable components, design, media, utilities.
- `OhanaTests/`, `OhanaUITests/`, `docs/`, `scripts/`, and `Resources/` own
  tests, documentation, automation, and active resources.

Do not recreate root-level `Views/`, `ViewModels/`, or `Utilities/` trees.
`DesignExports/archive/`, `docs/archive/`, `docs/audits/`, `docs/reference/`,
and `ohana-design-system/` are historical/reference unless explicitly targeted.
Whole-repo audits scan the complete `Ohana/` tree; fixture scope floors protect
against directory-refactor scan collapse.

## Scope, Authorization, And Git Safety

- Start every editing task with `git status --short`.
- Preserve unrelated work. Work around overlapping dirty files or report the
  conflict; never overwrite or revert another change.
- Review, audit, diagnose, explain, and status requests are read-only unless the
  user explicitly requests a report file.
- Change, fix, build, or refactor requests authorize focused in-repository work,
  not commit, push, PR, remote CI, signing, provisioning, entitlements, release,
  App Store Connect, file deletion, or destructive Git operations.
- Commit, push, PR, remote CI, signing, capability, and release actions require
  an explicit current-user request for that action.
- Do not use `git reset --hard`, `git checkout --`, or destructive cleanup
  without explicit approval.
- Do not create a branch or worktree by default. Ask before isolation unless the
  user explicitly requested it.
- `.codex/config.toml` may remove shell prompts; it does not expand authority.
- If a failure is outside the task or owned files, report it as an external
  blocker instead of widening the repair.

## Non-Negotiable Business And Data Boundaries

- Views do not directly mutate coconut balances, reminders, family tasks,
  rewards, ledger side effects, or other persistent business facts.
- Quick care enters one domain service or command executor, writes one business
  fact, then synchronizes rewards, reminders, tasks, ledger, enabled external
  projections, and read-model revisions through owned services.
- Coconut rewards flow through `QuestManager`, `EconomyRewardDiscipline`, and
  `CareEventEconomyAwarding`; views never edit balances ad hoc.
- High-frequency UI reads use bounded container queries, snapshots, or read
  models. Reusable rows, cards, popups, dashboards, and motion scenes do not own
  broad `@Query` aggregation.
- Before changing or adding a SwiftData model, inspect the latest `ArkSchemaV*`,
  add the next schema, append it to `ArkMigrationPlan.schemas`, and prefer
  lightweight-migration-friendly defaults. Add custom stages only when needed.
- `@ModelActor` code may fetch models internally but returns `Sendable` values
  only: identifiers or explicit value DTOs, never live SwiftData models.
- Save, delete, reset, export, restore, privacy, memorial, and backup behavior
  follows the relevant product rules and release-data-safety gates.

## Architecture And Runtime Boundaries

Use `docs/app-architecture-governance.md` as the main detailed engineering
reference. Route further by risk:

- module ownership: `docs/feature-module-contract.md`
- startup/routes: `docs/startup-and-lazy-loading-policy.md`
- concurrency/errors: `docs/concurrency-and-error-policy.md`
- cache/sync: `docs/data-cache-sync-policy.md`
- performance/runtime: `docs/performance-and-observability.md`
- privacy/security: `docs/privacy-compliance.md`
- dependencies/OS: `docs/dependency-governance.md`, `docs/os-support-matrix.md`
- release evidence: `docs/release-quality-gates.md`

Core ownership:

- Views own ephemeral visual state and emit typed intents.
- Route hosts own typed route, sheet, popup, deep-link, notification, and App
  Intent handoff state; they do not write domain facts.
- Snapshot builders/read models produce small stable value state.
- Domain services own invariants, persistence, privacy filters, synchronization,
  deletion/memorial behavior, and user-recoverable errors; they do not import
  SwiftUI.
- `AppWorkloadPolicy` is the only source for foreground/background, Low Power,
  Reduce Motion, app power-saving mode, thermal, timer, refresh, and repeating
  animation decisions.

Keep startup limited to the shell, root routes, model container, localization,
tokens, runtime policy, and required migration checks. Heavy feature scans,
aggregation, image decoding, reconciliation, map warmup, timers, media preload,
and broad service setup remain lazy.

Navigation is typed and data-driven. Routes carry stable identifiers and small
parameters, not SwiftData models or prebuilt views. Dismissal cancels route work
and releases frozen snapshots.

Core Location remains centralized in `LocationManager` and `PetWalkingManager`.
Only an active dog walk may hold background location. New caches need an owner,
invalidation/eviction policy, and applicable memory-warning registration.

## UI, Smoothness, Accessibility, And Localization

Read `ui规范.selection.json` before changing UI. It is the machine source of
truth; `docs/design/ui规范.md` is explanatory. New pages and major refactors use
`docs/ui-v4-new-page-template.md` and existing shared components/tokens.

- Finger-first interaction mutates local visual/route/frozen state first.
- Business and data work starts after visual handoff and is cancellable,
  cacheable, batchable, or deferred.
- Hidden surfaces are unmounted, inert, or snapshot-only; they do not retain
  broad queries, timers, image decoding, or aggregation.
- Motion scenes animate values and geometry, not SwiftData or business commands.
- Repeating work is visible, intentional, and `AppWorkloadPolicy`-gated.
- Liquid Glass is adopted only when explicitly requested and follows the
  existing UI template and OS fallback rules.

Strict smoothness work uses the compliance matrix in
`docs/design/ohana-ui-spec.md`; do not call it complete while any required row
is `Partial` or `Not compliant`.

Interactive UI requires localized accessibility labels, 44x44pt hit areas,
Dynamic Type, non-color-only state, and applicable Reduce Motion behavior.
Run changed UI and accessibility audits before handoff.

Use `L10n`, `AppLanguage`, and `AppLocalizedText` from
`Ohana/Shared/Localization.swift` for dynamic/interpolated strings and
formatters. Static keys live in `*.lproj/Localizable.strings`; `en` is the
parity reference. Do not add direct language ternaries in views.

## Canonical Validation Lanes

The validation entrypoints are intentionally layered:

1. Fast changed lane: `scripts/dev-check-changed.sh`.
   It is read-only by default, lints formatting, runs applicable changed-file
   audits, and recommends escalation. Source formatting requires explicit
   `--fix-format` and explicit file/directory targets.
2. Feature/module lane: `scripts/module-exit-gate.sh` with targeted `--test`,
   `--unit`, or `--full`. Normal module work uses relevant Unit/Integration
   proof and at most one high-value UI path.
3. Release lane: `scripts/release-hardening-check.sh`. Default runs all static
   release gates plus the full unit suite; `--static-only` skips simulator work
   and `--with-ui` adds sequential full UI shards. Signed WMO Archive and
   physical-device acceptance remain separate.

Other commands:

- Debug compiler proof: `scripts/build-debug-fast.sh`
- Optimized incremental simulator proof: `scripts/build-release-fast.sh`
- Targeted simulator tests: `scripts/test-simulator.sh`
- Signed local WMO Archive: `scripts/archive-release-local.sh`
- Long-session dogfood: `scripts/run-dogfood-simulator.sh`
- Scheme discovery: `xcodebuild -list -project Ohana.xcodeproj`

All local command-line builds/tests target the `iPhone 17` simulator by name
with `-sdk iphonesimulator`. Never hardcode a simulator UDID or silently switch
to a physical/generic/different destination.

Validation must match risk:

- Docs-only: `git diff --check` plus relevant Markdown/JSON/shell/governance
  checks; no app build.
- Pure UI/token/layout: changed UI and accessibility audits; compile only for
  Swift API/type, shared component, route/sheet, runtime, or localization risk.
- Feature logic: the narrowest relevant Unit/Integration test.
- Cross-feature, persistence, runtime, startup, privacy, routes, rewards,
  reminders, notifications, SwiftData, App Intents, or shared components:
  targeted tests plus compiler proof unless the same test already compiled it.
- Simulator-only UI bug: own one reproduce-fix-verify loop on the pinned
  simulator, prefer accessibility identifiers, and report coordinate fallback.
- Runtime/energy changes: run `scripts/audit-runtime-guardrails.sh`.
- UI changes: run `scripts/audit-ui-v4.sh` and
  `scripts/audit-accessibility.sh` at changed/path scope.

## Test And Evidence Rules

- Unit/Integration tests prove business rules; UI tests do not audit database
  internals, ledgers, migrations, rewards, or caches.
- Normal module work retains one high-value UI path, not every button variant.
- Every P0/P1 repair proves failure, recovery/retry, and repeat/idempotency at
  the lowest trustworthy layer.
- Test frequency follows risk; visual trivia does not start full-app suites.
- Tests use Swift Testing and in-memory SwiftData where appropriate.
- A build proves compilation only. It does not prove product behavior,
  persistence safety, runtime smoothness, privacy, permissions, background
  delivery, iCloud, signing, real-device energy, or App Store readiness.
- Report commands actually run, results, simulator/device, and what remains
  unverified. Never convert missing evidence into a pass.

## CI And Release Boundaries

CI runs strict whole-repo audits, fixture self-tests, lint/format lint, and the
full unit suite. Treat red CI as blocking. The full UI portfolio is a local or
scheduled nightly/RC lane, not a per-push assumption.

When push is explicitly requested, run relevant local gates first, push only a
coherent tree, inspect the newest run once, and record the URL/result. Do not
poll a known external blocker repeatedly.

Do not ship high-risk persistence, privacy, startup, background, or cross-
feature changes with build-only evidence. Follow `docs/release-quality-gates.md`
and the real-device plan for device-owned behavior.

## Advisory Skills

`.codex/skills/ui-ux-pro-max/` is advisory. Translate useful guidance into
Ohana tokens and shared components; do not import web palettes, fonts, or
landing-page conventions.

`.codex/skills/self-improving/` is advisory. It may produce evidence-backed
proposals after repeated misses, but it never mutates source, tests, scripts,
skills, `AGENTS.md`, or governance without explicit user approval.

Use local animation-memory documents as pattern inspiration, not vendored code.

## Agent Conduct

- Think before editing; state assumptions only when they affect the outcome.
- Reuse current models, routes, services, assets, and components before adding
  structure.
- Keep changes surgical and avoid broad formatting or speculative abstraction.
- Use current Apple documentation for new platform APIs and App Store-sensitive
  system surfaces.
- Prefer executable tests/audits with bad and good fixtures over new prose.
- Verify the concrete success criterion with the narrowest trustworthy gate,
  then escalate only by demonstrated risk.
- Update durable status only when release truth or a real follow-up changed.
- Preserve long-term rules as Markdown only when the user requests durable
  memory; do not treat conversation history as repository authority.
