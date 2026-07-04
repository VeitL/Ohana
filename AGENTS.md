# Repository Guidelines

In Ohana, a light interaction must stay light: visual feedback, route mutation,
data aggregation, persistence writes, background work, timers, and animation
loops are separate systems with explicit handoff points.

## Rule Authority

`AGENTS.md` is the only root agent/navigation rule file for this repository. Do
not maintain a parallel `CONTEXT.md`, `UIRules.md`, `.cursorrules`, `.cursor/`,
`.windsurf/`, or other root/editor rule copy. Historical plans may exist, but
when they conflict with the current rule stack, treat them as stale.

Rule precedence and domain boundaries:

1. Current user request.
2. Product behavior and acceptance truth: `docs/specs/product-foundation.md`.
3. Engineering workflow, repository navigation, and agent conduct: `AGENTS.md`.
4. UI tokens and component choices: `ui规范.selection.json`.
5. Governance docs in `docs/` for detailed quality gates.
6. Current source code.
7. Historical planning/reference documents.

`docs/specs/product-foundation.md` decides what Ohana should do. `AGENTS.md`
decides how agents should change, validate, and navigate the code. Keep product
rules and engineering rules in their own lanes instead of treating one as a
replacement for the other.

## Follow-up Tracking

Use `docs/task-follow-ups.md` only for real blockers, external actions,
cross-scope repairs, validation gaps, or important deferred work discovered
during a task. Keep entries actionable with status, priority, blocker, next
step, and close condition. Do not add noise when no meaningful follow-up remains.

## Current App Facts

- Ohana is an iOS SwiftUI app using SwiftData and Swift Charts.
- The app declares no App Group entitlement. If a widget or extension later
  needs one, use `group.com.guanchen.li.Ohana`; never revive older `Ark`
  app-group identifiers.
- The latest SwiftData schema lives in
  `Ohana/Models/SharedModelContainer.swift`. As of this consolidation it is
  `ArkSchemaV82`, but always verify the current `ArkSchemaV*` in that file and
  update this line whenever a schema version lands.
- Before changing a SwiftData model or adding one, inspect the latest
  `ArkSchemaV*`, add the next schema version, append it to
  `ArkMigrationPlan.schemas`, and keep added fields lightweight-migration
  friendly with defaults when possible. Keep `ArkMigrationPlan.stages` empty
  unless custom migration logic is actually needed.
- User-facing copy must support the registered app languages in
  `Ohana/Shared/LocalizationSettings.swift` (currently Chinese, English,
  German, Spanish, Portuguese, French, Japanese, Korean, Italian). Chinese and
  English are mandatory at authoring time; other languages may fall back.

## Business Fact Rules

- Views must not directly mutate `pet.coconutBalance`, `human.coconutBalance`,
  reminders, family tasks, rewards, or ledger side effects.
- Quick care actions enter one domain service or command executor, write one
  business fact, then let services synchronize rewards, reminders, tasks,
  ledger entries, widgets, and read-model revisions.
- Coconut rewards are awarded through `QuestManager` under the audited economy
  chokepoints `EconomyRewardDiscipline` and `CareEventEconomyAwarding`, not by
  ad-hoc balance edits in views.
- High-frequency UI reads must use narrow screen-container queries, snapshot
  builders, or read models. Do not put broad `@Query` reads in reusable rows,
  cards, popups, dashboards, or motion scenes.

## Project Layout

Main app code lives in `Ohana/`:

- `App/`: app shell, route containers, lifecycle, startup, runtime policy.
- `Features/<FeatureName>/`: feature views, commands, services, screen models,
  and read models.
- `Domain/`: cross-feature commands, events, revision publishing, services, and
  economy boundaries.
- `Models/`: SwiftData models only.
- `Shared/`: localization, reusable components, design, media, utilities.

Do not recreate root-level `Views/`, `ViewModels/`, or `Utilities/` trees.
Localized resources live in `*.lproj/`, catalog assets in `Assets.xcassets/`,
active non-catalog resources in `Resources/`, unit tests in `OhanaTests/`, UI
tests in `OhanaUITests/`, docs and manifests in `docs/`, active UI machine
tokens in `ui规范.selection.json`, and helper automation in `scripts/`.
`DesignExports/archive/`, `docs/archive/`, and `ohana-design-system/` are
reference/history unless the task explicitly targets them.

Audit scripts must scan the whole `Ohana/` tree, never a narrow allowlist. The
fixture self-tests protect against scan-scope collapse.

## Commands And Validation

- Open project: `open Ohana.xcodeproj`
- Cheap changed-file gate: `scripts/dev-check-changed.sh`
- Quick Debug build: `scripts/build-debug-fast.sh`
- Simulator tests: `scripts/test-simulator.sh`
- Direct build fallback:
  `xcodebuild -project Ohana.xcodeproj -scheme Ohana -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Direct test fallback:
  `xcodebuild test -project Ohana.xcodeproj -scheme Ohana -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO`
- Scheme discovery: `xcodebuild -list -project Ohana.xcodeproj`

Local command-line builds and tests target the `iPhone 17` simulator by name
with `-sdk iphonesimulator`. Never hardcode a simulator UDID in scripts or docs.
Do not switch to a physical device, `generic/platform=iOS`, `Any iOS Device`, a
different simulator, or a pinned older `OS=` unless the user explicitly asks.
Passcode-protected physical-device warnings are environment noise when the
command is still using the pinned simulator destination.

Validation route:

- Start every editing task with `git status --short` and preserve unrelated
  work.
- Default to fast-change mode: read task-relevant files, make focused edits,
  run `scripts/dev-check-changed.sh`, and follow its build/test recommendation.
- Documentation-only changes use `git diff --check` plus relevant syntax or
  governance checks; do not run app builds for docs-only work unless asked.
- Pure UI/token/layout edits use `scripts/audit-ui-v4.sh --changed` or a
  path-specific UI audit first. Compile only when the change touches Swift
  types/APIs, shared components, navigation/sheets/routes, runtime policy,
  localization plumbing, or the user asks.
- Feature-local logic uses the narrowest relevant unit test or one quick build.
- Cross-feature, persistence, runtime, startup, privacy, route, reward,
  reminder, notification, SwiftData, App Intent, or shared-component changes use
  targeted tests plus `scripts/build-debug-fast.sh`, unless a targeted
  `scripts/test-simulator.sh` already compiled the same surface.
- Medium/high-risk changes follow `docs/release-quality-gates.md`. A successful
  build alone is not enough for persistence, privacy, runtime, startup, or
  cross-feature behavior.
- If validation fails outside the task scope or outside files changed in this
  conversation, report it as an external blocker instead of fixing across
  another task.

For simulator-only UI bugs, own one reproduce-fix-verify loop: build/run,
confirm launch with a screenshot or UI snapshot, drive the reported path, patch
the smallest fix, and rerun the same path. Prefer accessibility identifiers over
coordinates; report coordinate fallbacks as testability gaps.

## CI And Push Cadence

CI runs on push and pull request:

- `audits`: audit fixture self-tests, whole-repo UI V4, accessibility,
  smoothness, runtime guardrails, architecture boundaries, recurring findings,
  localization, release data safety, governance manifests, resource integrity,
  xattr pre-sign checks, git size, and gitleaks.
- `lint`: SwiftLint strict and SwiftFormat lint with pinned tool versions.
- `build-test`: unit tests on the `iPhone 17` simulator by name. The UI suite is
  real but not a per-push gate; grow UI coverage through local module-exit work
  or a scheduled UI job before treating it as CI-proven.

Treat red CI as blocking. Encode new rules as audits, lint rules, or tests with
bad/good fixtures whenever possible.

Push every completed work item or coherent fix batch promptly after local cheap
gates pass. `main` must not lead `origin` by more than one completed work item
or one working day. Do not push broken or mid-task trees just to sample CI, and
do not repeatedly poll known tracked external blockers. After a push, inspect
the newest run once and record the URL/result.

## Parallel Work And Git Safety

Do not create a new worktree or branch by default. Stay in the current worktree
unless the user asks for isolation, or unless you explain a concrete parallel
blocker and get approval.

Each conversation owns only its current worktree. If a file has unrelated
changes, work around them or report the conflict; do not overwrite or revert
user work. Do not use destructive git commands such as `git reset --hard` or
`git checkout --` unless the user explicitly asks.

Use stable per-worktree/per-task DerivedData paths and the repository scripts'
locks. Only choose a new build cache path for real lock conflicts, cache
corruption, signing-risk xattrs, or an explicitly isolated validation need.
For long-session dogfood simulator checks, use
`scripts/run-dogfood-simulator.sh`; it preserves app data on the pinned
simulator and stores build products under `.build/DerivedData/dogfood`.

## iOS Agent Workflow

Treat this as an existing SwiftUI Xcode project, not a greenfield scaffold.
Reuse `Ohana.xcodeproj`, scheme `Ohana`, existing models, routes, assets, shared
components, and local service patterns before adding structure.

Classify the change before implementation:

- UI-only: tokens, components, page layout, visual interaction.
- Feature-local: one feature route, screen, read model, or service command.
- Cross-feature: dashboards, reminders, tasks, rewards, widgets, App Intents,
  notifications, or two-plus features.
- Persistence: SwiftData schema, migration, write command, delete behavior, or
  recovery path.
- Runtime: timer, map, location, background refresh, repeating animation,
  startup, prefetch, or cache warmup.
- Design-system: token, shared component, page template, motion helper,
  navigation chrome, sheet/popup pattern.
- Release-risk: privacy, account, PIN, memorial mode, background permission,
  data loss, startup regression, or large refactor.

Use current Apple Developer documentation and Human Interface Guidelines for
new Apple platform APIs or system surfaces, especially App Intents, Liquid
Glass, Instruments/SwiftUI performance, memory diagnostics, privacy, and App
Store-sensitive capabilities.

App Intents should expose high-value actions first: quick pet-care logging,
opening a pet or human profile, viewing today's care focus, and creating or
jumping to reminders. Keep `AppEntity` surfaces smaller than SwiftData models,
state whether each intent completes inline or opens the app, and route
app-opening intents through one typed route handoff. See
`docs/specs/AppIntents-logic.md`.

Only adopt iOS 26 Liquid Glass APIs when explicitly asked. Migrate one
high-traffic flow at a time, keep older-iOS fallbacks, prefer native glass APIs
over custom blur stacks, use `GlassEffectContainer` for multiple glass elements,
and reserve `.interactive()` for interactive elements.

## Startup And Routes

Keep startup skinny. App launch may initialize only the shell, root route host,
model container, localization, design tokens, runtime policy, and required
migration checks. Do not add feature scans, image decoding, dashboard
aggregation, notification reconciliation, reward synchronization, route-tree
construction, map warmup, timers, media preload, or broad service registration
to startup unless `docs/startup-and-lazy-loading-policy.md` explicitly allows it.

Navigation must be typed and data-driven:

- Prefer `AppRoute`, `SheetRoute`, `PopupRoute`, or feature-local route types
  over scattered booleans.
- App Intents, deep links, notifications, widgets, and shortcuts translate into
  route values first.
- Route state carries stable identifiers and lightweight parameters, not full
  SwiftData objects or prebuilt destination views.
- Building a route must not eagerly build all destinations, scan global data, or
  refresh unrelated dashboards.
- Dismissing a route cancels route-scoped work and releases frozen animation
  snapshots.

## SwiftUI Structure And Smoothness

Use existing Swift and SwiftUI conventions: four-space indentation,
`PascalCase` types, `camelCase` properties/functions, descriptive service/view
names, and `MARK:` sections in larger files. Keep views focused. Move business
logic into command/service files, feature-local read models, snapshot builders,
or `Domain/Services/`. Avoid broad reformatting outside the task.

Split oversized SwiftUI files by responsibility before adding behavior:
render-only surfaces, state/coordinator objects, route hosts, command
executors, snapshot builders, and reusable subviews should not all live in one
giant view.

Smoothness laws:

- Finger-first frame: a tap, drag, selection, sheet presentation, hero
  transition, or quick check-in may mutate only local visual state, route value,
  frozen snapshot, animation progress, focus/pressed/selected state, or
  hit-testing state.
- Business/data work happens after the visual handoff and must be cancellable,
  cacheable, batchable, or deferred.
- Hidden surfaces are unmounted, inert, or snapshot-only; they must not keep
  broad queries, `TimelineView`, timers, image decoding, or dashboard
  aggregation alive.
- Motion scenes animate frozen value snapshots and geometry only. They must not
  import SwiftData, access `ModelContext`, execute commands, decode images, or
  rebuild unrelated view trees during animation.
- Repeating work and ambient motion must be visible, intentional, and governed
  by `AppWorkloadPolicy`.
- Render components receive small value snapshots. SwiftUI `body` is not the
  aggregation engine.

When the user asks for strict smoothness, treat these as acceptance gates. State
the interaction class, invariants, intended structure, and final compliance for
finger frame, frozen handoff, deferred work, visual/business separation, runtime
budget, thaw timing, safe area/hit testing, and validation. Do not call a change
complete while any row is knowingly partial.

Before reporting completion for strict smoothness work, include a compliance
matrix. Each row must be marked exactly `Compliant`, `Partial`, or
`Not compliant`, with brief evidence:

- Finger-first frame.
- Frozen render or snapshot handoff.
- Heavy work deferred and cancellable.
- Visual/business separation.
- Runtime budget and visibility gating.
- Thaw timing.
- Safe area and hit testing.
- Validation performed.

If any row is `Partial` or `Not compliant`, do not present the task as complete.
State the remaining gap, why it remains, and the next concrete step.

## Architecture And Runtime Ownership

Use `docs/app-architecture-governance.md` as the main engineering reference for
architecture boundaries, background behavior, privacy, energy, runtime
observability, and maintainability. Use `docs/feature-module-contract.md`,
`docs/startup-and-lazy-loading-policy.md`, `docs/performance-and-observability.md`,
`docs/data-cache-sync-policy.md`, `docs/release-quality-gates.md`,
`docs/design-system-governance.md`, `docs/accessibility-governance.md`,
`docs/reliability-slo.md`, `docs/privacy-compliance.md`,
`docs/concurrency-and-error-policy.md`, `docs/dependency-governance.md`, and
`docs/os-support-matrix.md` for detailed gates.

Ownership rules:

- `Views/`: compose UI, own ephemeral visual state, emit typed user intents, and
  bind to snapshots. They do not own persistence writes, cross-page business
  rules, background policy, or broad aggregation.
- Render components: pure visual surfaces with value inputs. They do not import
  SwiftData, own navigation, start timers, call services, or observe global app
  state unless explicitly required.
- Route hosts/coordinators: own navigation stacks, sheet/popup routes, deep
  links, notification routes, and App Intent openings. They do not write domain
  facts.
- Snapshot builders/read models: convert SwiftData/service state into small,
  stable, preferably `Equatable` render state. They do not animate, navigate, or
  mutate business facts.
- Domain services: own invariants, persistence writes, privacy filters,
  task/reminder/reward synchronization, and deletion/memorial edge cases. They
  must not import SwiftUI.
- Runtime policy: `AppWorkloadPolicy` is the only source for foreground,
  background, Low Power Mode, Reduce Motion, app power-saving mode, thermal
  state, timer, refresh, and repeating-animation decisions.

SwiftData is a persistence/model layer, not a render-time aggregation engine.
New high-frequency read models or snapshot builders should fetch and aggregate
off the main actor with `@ModelActor` or a background `ModelContext`, then send
small value snapshots back to `MainActor`. Do not add new main-actor
fetch-and-aggregate loops in read-model stores.

SwiftData `@ModelActor` boundaries must return `Sendable` values only. A
`@ModelActor` may fetch and aggregate `PersistentModel` objects internally, but
must not return live SwiftData models, model arrays, or result structs/snapshots
that contain them across the actor boundary. Return `PersistentIdentifier`,
UUID/string/date/number fields, or explicit value DTOs instead; `MainActor`
code may rehydrate a single model from its own `ModelContext` for detail, edit,
or delete flows.

Core Location stays centralized in `LocationManager` and `PetWalkingManager`.
Only a running dog walk may keep background location active. Do not create a
new `CLLocationManager`, set `allowsBackgroundLocationUpdates = true`, or
request Always authorization outside that flow.

Before reporting runtime, energy, background-location, or animation-loop work
complete, run `scripts/audit-runtime-guardrails.sh` and fix warnings or add a
specific `// runtime-guardrail: allow <reason>`.

## UI Rules

`ui规范.selection.json` is the single machine-readable UI source of truth. Read
it before changing app views, shared UI components, colors, cards, buttons,
inputs, sheets, charts, calendars, or motion. `docs/design/ui规范.md` explains
the same selection for humans; the JSON wins on token conflicts.

For new pages or major view refactors, start from
`docs/ui-v4-new-page-template.md`. Use `OhanaAppBackground()`, semantic Ohana
text colors, shared card/button/sheet helpers, `ScaleButtonStyle()`, `GoMotion`
tokens, `OhanaTextField` or project input helpers, `OhanaRadius`, and shared
sheet detent helpers instead of local one-off styling.

High-risk UI reminders:

- Color semantics are reserved; do not reuse semantic colors outside their
  allowed roles.
- Sheets and popups use independent `sheet*` tokens.
- Key spatial interactions use stable ZStack motion scenes and frozen snapshots.
- Navigation chrome, settings rows, cards, and short popups follow explicit
  token families.
- Motion should be restrained, numeric where relevant, and meaningful. Use
  `ohanaNumericMotion`, `contentTransition(.numericText())`, `symbolEffect`,
  staged entrances, ping/shine/shake/pop-style effects, and `GoMotion` only
  where they clarify rewards, attention, counters, progress, validation,
  pending review, or success. Respect Reduce Motion and runtime budgets.

Before reporting UI work complete, run `scripts/audit-ui-v4.sh --changed` or a
path-specific scan, plus `scripts/audit-accessibility.sh --changed` for touched
interactive UI. Icon-only controls need localized accessibility labels,
interactive targets need 44x44pt hit areas, text should use Dynamic Type, and
state must not be color-only. Use allow comments only for deliberate exceptions.

## Advisory Skills

`.codex/skills/ui-ux-pro-max/` and `docs/ui-ux-pro-max-ohana-adaptation.md` are
advisory only. Use them for UX review, accessibility checks, SwiftUI
form/chart/sheet guidance, and product-category inspiration, then translate
ideas into Ohana V4 tokens and shared components. Do not import generated
palettes, Google Fonts, landing-page structures, or web-specific rules.

`.codex/skills/self-improving/` is advisory only. It may propose improvements
after user corrections, failed gates, repeated misses, or reusable workflow
discoveries, but it must not mutate source, tests, scripts, skills, `AGENTS.md`,
or governance docs without explicit user approval.

Use `docs/open-swiftui-animations-memory.md` and
`docs/pow-animation-memory.md` as local motion-pattern memory and inspiration,
not vendored source code.

## Localization

Use `Ohana/Shared/Localization.swift` (`L10n`, `AppLanguage`, and
`AppLocalizedText`) for dynamic strings, interpolated text, formatter labels,
alerts, sheet titles, button labels, and text built outside static SwiftUI
localization keys. Chinese and English are mandatory at authoring time; other
languages may use the fallback chain.

Static SwiftUI keys live in per-language `Ohana/<code>.lproj/Localizable.strings`
files, with `en` as the parity reference. Do not leak Chinese text into
non-Chinese resources. Avoid new direct language ternaries in views; prefer
`L10n(...).tr(zh:en:...)`, `L10n.current`, or `AppLocalizedText(zh:en:...)`.
Use localized helpers for dates, numbers, currency, units, and relative labels.

## Performance And Observability

For high-traffic flows, report the user flow, measurement method, and whether
the change affects launch, first render, tap response, route transition,
scrolling, memory, SwiftData reads, image decoding, timers, or background work.
Use `docs/performance-and-observability.md` for budgets, dense-data fixtures,
probe names, Instruments/ETTrace guidance, and memgraph leak evidence.

`AppWorkloadPolicy` already gates foreground/background, Low Power Mode, Reduce
Motion, user power-saving mode, and `ProcessInfo.thermalState`. New runtime
surfaces must consume that policy instead of reading thermal state locally.

Every cache needs an owner entry in
`docs/governance/manifests/cache-ownership.json` with an eviction story. Caches
holding decoded images or large snapshots must register with
`MemoryWarningEvictionRegistry` and rederive lazily after pressure.

MetricKit hang/launch summaries flow through `Ohana/App/MetricKitObserver.swift`.
For perf-sensitive changes, check the next payload instead of assuming success.

## Testing

Tests use Swift Testing (`import Testing`) with `@Test` and `#expect`. Add unit
coverage in `OhanaTests/` for service, model, persistence, privacy, route, and
runtime behavior. Add `OhanaUITests/` only for user-facing navigation or launch
behavior that unit tests cannot prove. Use in-memory SwiftData containers for
persistence tests.

Choose the smallest reliable test:

- Domain service tests for business facts, invariants, sync, privacy, deletion,
  and memorial behavior.
- Snapshot/read-model tests for aggregation, sorting, filtering, empty states,
  dense data, and privacy placeholders.
- Route tests for typed routes, deep links, App Intents, notifications, and
  route cancellation.
- Runtime policy tests for Low Power, Reduce Motion, scene phase, visibility,
  timers, animation, and map gating.
- UI tests for high-value flows where layout, keyboard, or route behavior needs
  an app run.

For high-frequency flows, include the relevant subset of empty data, dense data,
missing images, long German text, locked/private state, failed write, background
reopen, Low Power Mode, Reduce Motion, and migration compatibility.

## Commits And PRs

Prefer concise imperative commits, often Conventional Commit style such as
`feat(scope):`, `fix(scope):`, or `chore(scope):`. Pull requests should include
a summary, validation results or simulator used, linked issues when applicable,
and screenshots/recordings for visible UI changes.

For medium/high-risk work, include a release-quality note from
`docs/release-quality-gates.md`. Do not ship high-risk persistence, privacy,
startup, background, or cross-feature changes with only a successful build.

## Security And Local Automation

Do not commit personal provisioning profiles, signing secrets, derived data, or
local simulator state. Coordinate bundle identifiers, entitlements, background
task identifiers, and SwiftData migration-sensitive changes with Xcode project
settings.

This repository tracks `.codex/config.toml` with `approval_policy = "never"` for
low-friction local automation. That removes shell approval prompts; it does not
authorize destructive commands, cross-scope rewrites, `git reset --hard`,
`git checkout --`, or file deletion without an explicit user request.

## Agent Conduct

- Think before coding: state assumptions when they matter, surface ambiguity,
  and ask when the answer cannot be safely inferred from repo evidence.
- Keep changes surgical: solve the requested problem, match local style, avoid
  speculative abstraction, and clean up only artifacts introduced by your own
  change.
- Verify against a concrete success criterion with the narrowest trustworthy
  gate first, then escalate by risk.
- Preserve confirmed long-term practices, durable rules, and repeated mistakes
  as Markdown notes when the user asks for memory-backed continuity; do not rely
  on chat context alone for rules that future tasks must remember.
