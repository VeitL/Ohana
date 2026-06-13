# Repository Guidelines

In Ohana, a light interaction must stay light: visual feedback, route mutation, data aggregation, persistence writes, background work, timers, and animation loops are separate systems with explicit handoff points.

## Single Rule File

`AGENTS.md` is the only root agent/navigation rule file for this repository. Do not maintain a parallel `CONTEXT.md`, `UIRules.md`, or other root Markdown as a second source of instructions. Legacy planning/reference documents may exist for history, but when they conflict with this file, `ui规范.selection.json`, the governance docs listed below, or the current code, treat the legacy document as stale.

Do not keep editor-specific rule folders such as `.cursor/` or `.windsurf/` in this repository. If a tool needs local onboarding, it should read `AGENTS.md` and the governance docs below instead of carrying a separate rule copy.

Rule precedence:

1. Current user request.
2. `AGENTS.md`.
3. `ui规范.selection.json` for UI tokens and component choices.
4. Governance docs in `docs/` for detailed quality gates.
5. Current source code.
6. Historical planning/reference documents.

## Task Follow-up Tracking

Use `docs/task-follow-ups.md` for concrete follow-ups discovered while completing
a task when they cannot or should not be handled in the same turn. Add an entry
only for real blockers, external actions, cross-scope repairs, validation gaps,
or important deferred work; keep each entry actionable with status, priority,
blocker, next step, and close condition. If a task leaves no meaningful
follow-up, do not add noise to the document.

## Current App Facts

- Ohana is an iOS SwiftUI app using SwiftData and Swift Charts.
- The app currently declares no App Group entitlement. If a future widget or extension needs one, use `group.com.guanchen.li.Ohana`; do not reintroduce older `Ark` app-group identifiers.
- The latest SwiftData schema is defined in `Ohana/Models/SharedModelContainer.swift`; as of this consolidation it is `ArkSchemaV71`. Always verify the current `ArkSchemaV*` in that file rather than trusting this number — bump this line whenever a schema version lands.
- Before changing any SwiftData model field or adding a model, inspect the latest `ArkSchemaV*`, add the next schema version, append it to `ArkMigrationPlan.schemas`, and keep added fields lightweight-migration friendly with defaults when possible.
- Keep `ArkMigrationPlan.stages` empty for add-only/lightweight changes. Add an explicit migration stage only when there is real custom migration logic.
- User-facing copy must support the registered app languages (currently Chinese, English, German, Spanish, Portuguese, French, Japanese, Korean, Italian — see `Ohana/Shared/LocalizationSettings.swift`) through the localization rules below. Chinese and English are mandatory at authoring time; the others resolve through the fallback chain.

## Business Fact Rules

- Views should not directly mutate `pet.coconutBalance`, `human.coconutBalance`, reminders, family tasks, rewards, or ledger side effects.
- Quick care actions should enter a domain service such as `CareEventService`, `FamilyTaskService`, or a feature command executor, write one business fact, then let services synchronize rewards, reminders, tasks, ledger entries, widgets, and read-model revisions.
- Coconut rewards are awarded through the existing reward pipeline (`CoconutEconomyService` / `QuestManager`) from domain services, not by ad-hoc balance edits in views.
- SwiftData relationship arrays such as `pet.walkLogs` may be useful for local model navigation, but high-frequency live UI must read through narrow screen-container queries, snapshot builders, or read models. Do not put broad `@Query` reads in reusable rows, cards, popups, or motion scenes.

## Project Structure & Module Organization

This repository contains the Ohana iOS app. Main SwiftUI app code lives in `Ohana/`, organized into `App/` (app shell, route containers, lifecycle, startup, runtime policy, and app infrastructure), `Features/<FeatureName>/` (feature modules, each with its own `Views/`, services, commands, screen models, and read models), `Domain/` (cross-feature commands, events, revision publishing, services, and the economy), `Models/` (SwiftData models only), and `Shared/` (localization plus reusable `Components/`, `Design/`, `Media/`, and `Utilities/`). Do not recreate root-level `Views/`, `ViewModels/`, or `Utilities/` trees; place new files in the owning app, domain, feature, or shared folder. Localized resources live in `*.lproj/`, and catalog assets in `Assets.xcassets/`. Audit scripts must always scan the whole `Ohana/` tree, never a subdirectory allowlist — a directory refactor once silently removed 88% of files from three "whole repo" gates, which is why `scripts/tests/run-audit-fixture-tests.sh` enforces a scanned-file floor. Active non-catalog app resources live under `Resources/` and must stay referenced through `Ohana.xcodeproj`. Unit tests are in `OhanaTests/`; UI tests are in `OhanaUITests/`. Project documentation, planning notes, design references, archived backups, and governance manifests live under `docs/`; active UI machine tokens stay at the repository root in `ui规范.selection.json`. Helper automation belongs in `scripts/`. `DesignExports/archive/` and `docs/archive/` hold historical artifacts only. `ohana-design-system/` is a separate design/reference project; avoid changing it unless the task explicitly targets that folder.

## Build, Test, and Development Commands

- `open Ohana.xcodeproj` opens the app in Xcode for local development.
- `scripts/build-debug-fast.sh` is the default quick Debug build. It uses `-sdk iphonesimulator` and resolves the `iPhone 17` simulator BY NAME at run time (newest installed iOS runtime), so it survives new Macs, Xcode reinstalls, and device resets. It does not pin an `OS=` so Xcode uses the installed default runtime instead of downloading an older one.
- `scripts/dev-check-changed.sh` runs the default cheap local validation for changed files. It formats touched Swift files, runs applicable changed-file audits, validates shell/JSON syntax, and reports when a full build or targeted test should be used as an escalation. It does not run `xcodebuild` unless called with `--build`.
- `scripts/test-simulator.sh` is the default local simulator test entrypoint. It resolves the `iPhone 17` simulator by name, uses a stable per-worktree DerivedData path outside File Provider-managed workspace folders, disables simulator code signing by default, and strips signing-risk extended attributes before and after the test run.
- `xcodebuild -project Ohana.xcodeproj -scheme Ohana -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build` builds the app directly when the script is not appropriate.
- `xcodebuild test -project Ohana.xcodeproj -scheme Ohana -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` is the direct fallback when the script is not appropriate; use a stable `-derivedDataPath` and run `scripts/strip-build-xattrs.sh` on the DerivedData products if signing-risk xattrs appear.
- `xcodebuild -list -project Ohana.xcodeproj` lists available targets, schemes, and configurations.

### Pinned Simulator Build Rule

Local command-line builds and tests must target the `iPhone 17` simulator with `-sdk iphonesimulator`. The simulator is pinned by NAME, not by UDID: `scripts/build-debug-fast.sh` resolves the device named `iPhone 17` on the newest installed iOS runtime; `OHANA_SIMULATOR_UDID` or `OHANA_SIMULATOR_NAME` override the resolution when a task explicitly needs a different device. Never hardcode a UDID in scripts or docs — a UDID is machine-local state and becomes a single point of failure on any other machine.

Do not build against a connected physical iPhone, `generic/platform=iOS`, `Any iOS Device`, or an auto-selected non-iPhone-17 device. Do not switch simulator model or pin an older `OS=` unless the user explicitly asks for that validation. If Xcode prints passcode-protected physical-device discovery warnings while the command is still using `-sdk iphonesimulator` and the iPhone 17 simulator destination, treat those warnings as environment noise; do not change the destination to a physical device to "fix" them.

## Continuous Integration & Automated Gates

Rules in this file and `docs/` are enforced mechanically, not only by memory.
`.github/workflows/ci.yml` runs on every push and pull request:

- `audits`: audit self-tests first (`scripts/tests/run-audit-fixture-tests.sh`
  proves every audit rule still fires and that scan scope has not collapsed),
  then direct strict whole-repo UI V4, accessibility, and smoothness audits,
  whole-repo strict runtime guardrails and architecture boundaries,
  localization coverage, release data-safety, governance manifests, resource
  integrity / xattr pre-sign checks, git size, and a gitleaks secret scan
  (`.gitleaks.toml`).
- `lint`: SwiftLint (`.swiftlint.yml`) and SwiftFormat (`.swiftformat`), with
  tool versions pinned via `scripts/ci-tool-versions.env` and
  `scripts/check-tool-versions.sh`. SwiftLint runs with `--strict`, and
  SwiftFormat runs as a required lint gate.
- `build-test`: `xcodebuild test` on the `iPhone 17` simulator (by name). This
  per-push gate runs the **unit suite only** (`-only-testing:OhanaTests`)
  because the current UI tests are Xcode template stubs with ~zero coverage and
  a high cold-runner cost. The local
  `scripts/module-exit-gate.sh` still runs the full plan; do not assume CI
  covers UI flows until real UITests + a nightly job exist. Build intermediates
  are cached (`actions/cache` on `DerivedData/Build`) and logs use `-quiet`
  instead of an `xcbeautify` brew install; the raw `.xcresult` is uploaded.

Treat a red CI as a blocking failure. Do not merge around it. When you add a new
rule, prefer encoding it as a lint rule, audit script check, or test so it is
enforced automatically rather than as prose — and add a bad/good fixture pair in
`scripts/tests/fixtures/` so the rule cannot silently die. The `build-test` job
requires a runner whose Xcode ships the iOS 26 SDK and an iPhone 17 simulator;
see `docs/os-support-matrix.md`.

CI push cadence (solo-developer reality). The governing fact: SwiftLint
`--strict`, SwiftFormat, and the whole-repo audits run **only in CI** — the
default local gate does not run them. So completed work that has not reached CI
is work whose lint/format/audit gates have not actually run. Therefore **push
every completed work-item promptly** (module exit, CI-fix verification, a GAP
item, a fix batch) and keep going — do not wait on the run. The hard bound:
**`main` must not lead `origin` by more than one completed work-item or one
working day.** A larger backlog means those CI-only gates are dormant and a
later red bisects across many commits — the exact failure the reconciliation log
flagged twice (9 and 14 commits ahead). This is a solo project: CI minutes,
notification noise, and contending for shared runners are not real costs here,
so the old "batch to a natural handoff / don't push per checkpoint" guidance is
retired — it manufactured the backlog it warned against.

"Not a heartbeat" is now narrow and still holds: do not push a broken or
mid-task tree just to watch Actions run, and do not re-trigger a run for a
**known, already-tracked red external blocker** (record the run URL + TFU and
stop until that blocker enters a repair round). After any push, inspect the
newest run once and record the URL/result; do not keep `gh run watch` looping.

UI/accessibility/smoothness are full-repo strict gates. CI runs
`scripts/audit-ui-v4.sh --all`, `scripts/audit-accessibility.sh --all`, and
`scripts/audit-smoothness-risk.sh --all`; the zero baseline is retained in
`docs/governance/manifests/full-scope-audit-baseline.json` as promotion
evidence, not as a debt allowance. SwiftLint strict mode and SwiftFormat lint
mode are required gates after the P1 warning and formatting baseline cleanup.

## Parallel Agent & Build Isolation

Do not run multiple active Codex conversations against the same worktree for large refactors. Each parallel task should get its own git worktree and branch, for example `git worktree add ../Ohana-feeding -b codex/feeding`, `git worktree add ../Ohana-water -b codex/water`, or `git worktree add ../Ohana-potty -b codex/potty`.

Do not create a new worktree or branch by default. Stay in the current worktree unless the user explicitly asks for an isolated worktree/branch, or unless you first explain a concrete parallel-work blocker and get approval.

Each conversation owns only its current worktree. Before editing, run `git status --short` and keep changes inside the requested task scope. If a file is already being changed for an unrelated task, do not patch it to satisfy the current build unless the user explicitly asks you to take over that blocker.

Use `scripts/build-debug-fast.sh` for local Debug builds and `scripts/test-simulator.sh` for local simulator tests. The scripts use `-sdk iphonesimulator`, resolve the `iPhone 17` simulator by name, keep stable per-worktree/per-branch DerivedData and matching locks under `.build/locks/`, and strip signing-risk extended attributes from build products. If you must call `xcodebuild` directly, reuse a stable per-worktree/per-task `-derivedDataPath` instead of inventing a fresh path for each validation run; only choose a new unique path when there is an actual parallel-build lock conflict, cache corruption, signing-risk xattr contamination, or an explicitly isolated validation need.

When validation fails in files outside the current task scope or outside the files changed by this conversation, report it as an external blocker. Do not “fix forward” into another conversation's feature area just to make the build green unless the user explicitly authorizes that cross-task repair.

## iOS Agent Workflow

Treat this repository as an existing SwiftUI Xcode project, not a greenfield scaffold. Reuse `Ohana.xcodeproj`, the `Ohana` scheme, existing models, navigation patterns, assets, and shared utilities before adding new structure.

### Default Fast-Change Mode

Default to fast-change mode unless the user explicitly asks for exhaustive validation or the change is medium/high risk by the classification below.

- Start with one `git status --short` to understand the local change boundary.
- Read only task-relevant files and avoid broad repository archaeology.
- Make focused edits and avoid checkpoint builds after every small step.
- Treat local app builds as an expensive validation step, not as a heartbeat. Batch related edits first, use cheap checks while iterating, and run `scripts/build-debug-fast.sh` only at meaningful handoff points: after a coherent compiler-surface change, after fixing a build failure, before reporting medium/high-risk implementation complete, or when the user explicitly asks for a build.
- Do not run repeated build-debug loops just to regain confidence after every small patch. If the previous build succeeded and the next change is documentation-only, comment-only, formatting-only, audit-only, copy-only, or a narrow visual modifier change that does not alter Swift types/APIs/control flow, skip another build and say which lighter validation was used instead.
- Do not routinely run `scripts/build-debug-fast.sh` immediately after a successful `scripts/test-simulator.sh` run for the same change when the test command already compiled the app on the pinned `iPhone 17` simulator. Treat that successful test run as satisfying the app compile check unless the task touched project settings, entitlements, signing, assets/resources, Info.plist, app launch packaging, scheme/build configuration, or another surface that needs a standalone app build; if a standalone build is skipped, say that the simulator test covered compilation.
- When using long type-check diagnostics, run them as a scoped performance investigation: one baseline when needed and one verification after a batch of type-check-oriented edits. Do not leave `-warn-long-function-bodies` / `-warn-long-expression-type-checking` builds in the normal edit loop.
- Do not let “focused” become under-fixing. When the root cause crosses helper, call-site, or state boundaries inside the task scope, fix that root cause decisively, update the affected paths, and add or adjust the narrow guardrail that prevents recurrence. A fix is not complete if it merely hides the symptom, leaves a known broken path in place, or creates a plausible new failure mode.
- Prefer cheap validation first: `rg`, path-specific audits, targeted tests, or a focused compiler check.
- Use `scripts/dev-check-changed.sh` as the default first-pass local gate for changed files. Treat its build/test recommendation as the escalation boundary: follow it for compiler-surface, behavior, persistence, route, runtime, or shared-component changes, and skip app builds when it reports no build recommendation unless the user or risk class requires one.
- For pure UI changes, default to no compile/build. Pure UI means copy, spacing, padding, color/token usage, view composition, static layout, icon choice, simple animation parameters, and visual-only SwiftUI modifier changes that do not change data flow, route state, public APIs, model/service calls, generated assets, or shared component contracts. Validate with `rg`, visual reasoning, and `scripts/audit-ui-v4.sh --changed` or a path-specific UI audit instead.
- Escalate a UI change to compile validation when it introduces or renames Swift types/properties/functions, changes generic/component APIs, touches shared design-system helpers, changes navigation/sheet/route behavior, changes inline overlay or custom sheet presentation, changes safe-area/hit-testing behavior, changes runtime policy/timers/maps/Canvas/TimelineView, changes localization plumbing, or the user explicitly asks for a build.
- For documentation-only changes, do not run app builds or audits unless the user asks.
- For single-file logic changes, run the narrowest relevant test or one quick build only when the compiler surface changed.
- For new types, changed public APIs, SwiftData, routing, reminders, notifications, rewards, runtime policy, startup, or cross-feature behavior, upgrade validation to targeted tests plus `scripts/build-debug-fast.sh`, unless the targeted `scripts/test-simulator.sh` run already compiled the app and the change does not touch a standalone-build-only surface listed above.
- If validation fails in unrelated files, report it as an external blocker instead of fixing outside the task scope.

Keep the development loop CLI-first. Start with the narrowest trustworthy check for the code touched, then expand only when needed:
- Use `xcodebuild -list -project Ohana.xcodeproj` when schemes or targets are unclear.
- Use `scripts/build-debug-fast.sh` for day-to-day validation; do not hardcode older simulator OS versions such as `OS=26.4.1`. Let Xcode select the newest installed iOS runtime for the iPhone 17 simulator unless a task explicitly requires another destination.
- Use `xcodebuild -project Ohana.xcodeproj -scheme Ohana -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build` only when a direct app build is necessary.
- Use `scripts/test-simulator.sh` for test validation when behavior or persistence changes. Pass through targeted filters such as `-only-testing:OhanaTests/FooTests`; when calling `xcodebuild test` directly, include `CODE_SIGNING_ALLOWED=NO`.
- When calling `xcodebuild` repeatedly during one task, keep the same stable `-derivedDataPath` for the task so module, asset, and test-build caches stay warm. Do not create a new `.build/DerivedData/...` directory for every retry unless cache corruption or a real parallel-build conflict requires it.
- For pure UI changes, do not build by default. If a UI change has already been escalated to compile validation or the user asks for visual verification, prefer the fixed iPhone 17 simulator build/run and screenshots; if deeper simulator control is available through XcodeBuildMCP or similar tooling, use it to launch, inspect logs, and capture screenshots.

For iPhone and iPad work, keep the implementation focused on those platforms unless the task explicitly asks for broader Apple-platform support. When reporting completion, include the scheme, simulator destination, and validation commands that were actually used.

For simulator-only UI bugs, keep one failure mode per run and own the reproduce-fix-verify loop. Build and launch the app, confirm the starting screen with a screenshot or UI snapshot, drive the reported path with taps, typing, scrolling, or swipes, capture relevant screenshots/logs, make the smallest fix, then rerun the same path. Prefer accessibility labels and identifiers over raw coordinates; if a control can only be reached by coordinates, call that out as a testability gap.

When adding App Intents, start from Ohana's highest-value external actions rather than mirroring the whole app. Good first candidates are quick pet-care logging, opening a specific pet or human profile, viewing today's care focus, and creating or jumping to reminders. Keep `AppEntity` surfaces smaller than the SwiftData model layer, add `AppShortcutsProvider` entries only for discoverable user-facing actions, and route intent-driven app openings into the existing navigation/state model cleanly.

Only adopt iOS 26 Liquid Glass APIs when a task explicitly asks for that migration. Audit one high-traffic flow at a time, preserve older-iOS fallbacks with availability checks, and prefer native glass APIs over custom blur stacks once the deployment target and Xcode toolchain support them.

### Mature App Change Classification

Before implementing, classify the change:

- UI-only: token/component/page layout or visual interaction.
- Feature-local: one feature route, screen, read model, or service command.
- Cross-feature: affects two or more features, dashboards, reminders, tasks, rewards, widgets, App Intents, or notifications.
- Persistence: SwiftData schema, migration, write command, delete behavior, or recovery path.
- Runtime: timer, map, location, background refresh, repeating animation, startup, prefetch, or cache warmup.
- Design-system: token, shared component, page template, motion helper, navigation chrome, sheet/popup pattern.
- Release-risk: privacy, account, PIN, memorial mode, background permission, data loss, startup regression, or large refactor.

Use the narrowest safe validation for low-risk changes. Use `docs/release-quality-gates.md` for medium/high-risk changes. Do not treat a successful build as sufficient validation for cross-feature, persistence, runtime, privacy, or startup changes.

### Startup Path and Lazy Feature Loading

Keep app startup skinny. The startup path may initialize only the app shell, root route host, model container, localization, design tokens, runtime policy, and required migration checks.

Do not add feature-specific SwiftData scans, image decoding, dashboard aggregation, notification reconciliation, reward synchronization, route tree construction, map warmup, timer startup, media preload, or broad service registration to app launch unless `docs/startup-and-lazy-loading-policy.md` explicitly allows it.

Feature code should activate from typed routes, visible tabs, explicit user actions, App Intents, widgets, notifications, or narrowly scoped refresh tasks. Startup work must be measured before and after any change that touches app launch.

### Route Contract

Navigation must be typed and data-driven.

- Prefer route enums/structs such as `AppRoute`, `SheetRoute`, `PopupRoute`, or feature-local route types over ad-hoc booleans scattered across views.
- App Intents, deep links, notifications, widgets, and shortcuts must translate into route values first, then let the route host present the destination.
- Route state should carry stable identifiers and lightweight parameters, not full SwiftData object graphs or prebuilt destination views.
- Building a route must not eagerly build all destination trees, scan global data, or refresh unrelated dashboards.
- Dismissing a route should cancel route-scoped tasks and release frozen animation snapshots.

## Coding Style & Naming Conventions

Use Swift and SwiftUI conventions already present in the project: four-space indentation, `PascalCase` for types, `camelCase` for properties/functions, and descriptive service/view names such as `ReminderSchedulingService` or `FocusStackHomeTestView`. Keep views focused and move business logic into feature command/service files, feature-local read models, or `Domain/Services/`. Prefer `MARK:` sections for larger Swift files. Do not introduce broad reformatting in unrelated files.

Avoid oversized Swift files, especially giant SwiftUI view files. When a view grows into a compile/runtime hot spot, split it by responsibility before adding more behavior: pure visual surfaces, state/coordinator objects, route hosts, business executors, data snapshot builders, and reusable subviews should live in separate files. Card stacks, hero animations, Today Focus, FAB menus, sheets, charts, and quick actions should not all be owned by one massive view. This protects incremental build time, SwiftUI diffing cost, first-frame responsiveness, animation smoothness, and energy usage.

Keep high-frequency UI paths lightweight and two-phase. Phase 1 is visual: update only local interaction state, typed route state, frozen render snapshots, and token-driven animation state needed to start the visible response. Phase 2 is business/data: after the first frame, route presentation, or animation handoff, run cancellable service or snapshot refresh work. Do not decode images, scan large SwiftData collections, build complex route trees, start timers, synchronize tasks/reminders/rewards, or recompute unrelated dashboards in the same frame as a tap, drag, sheet presentation, hero transition, or quick check-in.

### Mature App Smoothness Laws

These laws apply to every page, sheet, card, dashboard, and route. A mature Ohana feature may be functionally complex, but the frame touched by the user's finger must stay simple.

- Mature app smoothness wins over decorative fidelity. When smoothness conflicts with ambient flourishes, always-on previews, hidden-but-mounted decks, broad live dependency tracking, or preserving a visual flourish, smoothness wins. Rebuild the flourish inside a lightweight frozen/render layer later, or remove it.
- First ask whether work can be avoided entirely. For high-frequency surfaces such as Home cards, Today Focus, Tab pages, sheets, quick actions, calendar agenda, dashboards, and Oasis, the default mature-app move is: do not render it when hidden, do not animate it when static, do not refresh it because an unrelated tap happened, and do not keep it live just in case.
- Hidden means unmounted or inert, not merely transparent. A surface that is fully covered, faded out, off-tab, behind an expanded card, or outside the active route must not keep building complex SwiftUI trees, running `TimelineView`, evaluating broad signatures, observing wide `@Query` results, decoding images, or aggregating dashboards. Keep only a tiny placeholder or prepared snapshot if continuity requires it.
- Decorative runtime loops are opt-in. Ambient `TimelineView(.animation)`, `Timer.publish`, `repeatForever`, Canvas particles, breathing glows, and floating cards are off by default on high-traffic screens. They may be re-enabled only when visible, user-valued, policy-gated, and proven not to compete with tap/scroll/hero frames.
- Dependency keys must be cheap. Values used in `.task(id:)`, `.onChange`, identity, or animation-driving state on high-frequency screens may include stable IDs, counts, explicit revision tokens, and small visibility flags. They must not rebuild full content signatures, call `Date()` buckets, localize display names, hash image data, scan relationship collections, or aggregate reminders/events/medications during body evaluation. Full diffing belongs in deferred snapshot refresh work.
- Finger-first frame law: the frame triggered by the user's finger must always do only the smallest visual state change needed for immediate feedback. Complexity may still exist, but it must be moved to places the user cannot see, and it must be cancellable, cacheable, batchable, or deferred until after the visual handoff. In practice, tap/drag/selection frame 0 may update only local render state, frozen snapshots, animation progress, route value, pressed/focused/selected state, or hit-testing state.
- Keep the interaction path ultra-light. A button tap, Tab switch, card expansion, drag, or sheet presentation may mutate only local UI state such as selected, pressed, focused, route value, frozen snapshot, or animation progress. It must not also query SwiftData, rebuild destination trees, decode images, synchronize reminders/tasks/rewards, refresh dashboards, or fan out to unrelated services.
- Separate visuals from business state. The user sees a render snapshot, not raw persistence objects. Complex data must be shaped first by a snapshot builder, read model, or route-scoped store into small, stable, preferably `Equatable` values. SwiftUI `body` should compose those values; it should not be the aggregation engine.
- Prepare pages before the switch is visible. Do not make a route feel like "tap, blank, then load." When a target page is likely or explicitly requested, mount or preflight it off the visible path, prepare layout, decode critical images, and capture its first-screen snapshot before the transition presents it. The visible transition should slide or reveal a ready page.
- Freeze the world during hero and spatial animations. A hero transition should not animate while SwiftData, image decoding, dashboard refresh, or service state changes are mutating the same surface. Freeze the visual inputs, drive one stable ZStack or motion scene through transform, opacity, mask, zIndex, and hit testing, then thaw after completion.
- Defer heavy work and make it cancellable. After a page enters, it may load more data, reconcile services, or refresh snapshots, but that work must be route-scoped and cancelled when the page disappears. A single Tab tap must not refresh home, calendar, Oasis, plants, reminders, rewards, and dashboards together.
- Treat caching as experience infrastructure. Home cards, Today Focus, calendar agenda, avatars, Oasis tree state, and other high-traffic surfaces should use lightweight caches, render snapshots, or prepared read models. Data sources may be complex; repeated rendering must not re-derive everything from scratch.
- Enforce runtime budgets. Animations, timers, maps, particles, Canvas, TimelineView, and repeatForever loops must be visible, intentional, and governed by `AppWorkloadPolicy`. Run them while visible, downgrade or pause them when hidden, and be stricter in Low Power Mode, Reduce Motion, background, or app power-saving mode.
- Keep the architecture split explicit. Finger path: `tap -> local visual state -> route/snapshot handoff -> first frame`. Background path: `data load -> service sync -> snapshot refresh -> next idle frame`.

### Strict Smoothness Compliance Mode

When the user asks to strictly follow rules, avoid compromise, fully comply with Mature App Smoothness Laws, make an interaction truly smooth, or rebuild a high-traffic interaction such as home card expansion, Tab switching, sheets, dashboards, Today Focus, quick actions, calendar agenda changes, Oasis animations, or other motion-heavy flows, treat compliance as a hard acceptance gate rather than an optimization preference.

Before implementing in this mode:

- State the applicable interaction class, such as `interaction-heavy`, `motion scene`, `snapshot handoff`, `route transition`, `runtime`, `persistence`, or `design-system`.
- Write the non-negotiable invariants for the change. Examples: finger frame 0 mutates only local visual state; animation uses frozen render snapshots; live data, SwiftData, image decoding, service fan-out, dashboard refresh, timers, and route tree construction are not allowed in the visible interaction path; thaw happens only after animation completion.
- Define the intended compliance structure before editing code, for example `PreparedSnapshot -> HeroMotionScene -> ThawCoordinator -> RouteScopedRefresh`, or explain why a different structure is required by the existing system.
- If strict compliance conflicts with preserving an existing visual flourish, do not make a hidden compromise. Either rebuild the flourish inside the compliant render/motion layer or explicitly report the tradeoff and the remaining non-compliance.

During implementation in this mode:

- Make the mature-app first pass before tuning. Remove or disable hidden live surfaces, broad `.task(id:)` signatures, decorative runtime loops, live avatar/image fallback in motion, and any always-mounted heavy deck before adjusting springs, shadows, delays, or token values. Do not spend time optimizing work that should not happen.
- Do not call a partial improvement "compliant" if any live tree, broad query, image decode, service call, timer start, dashboard refresh, route construction, or uncancellable background task remains in the user-triggered first frame or visible hero/transition path.
- Motion scenes should be mechanically isolated where practical: they receive frozen value snapshots, precomputed geometry, and prepared assets, and animate only transform, frame, scale, opacity, mask, zIndex, and hit testing. They must not import SwiftData, access `ModelContext`, execute commands, decode images, or rebuild unrelated view trees.
- Inline overlays, custom sheets, full-screen popups, and any route presented outside the system sheet host must be treated as their own presentation scene. The host must pass explicit `safeTop` and `safeBottom` values from `GeometryProxy`, `FocusHomeSafeAreaController`, or another stable safe-area source; child content must not assume the system sheet will reserve status bar, Dynamic Island, or home-indicator space. Top chrome and close controls must begin below the safe area, bottom controls must clear the home indicator, and hit testing must be disabled during entry/exit handoff.
- Custom presentation scenes must include both entry and exit mechanics before they are called smooth: first frame shows a lightweight shell or frozen snapshot, heavy content mounts after the visual handoff, close/select actions start an exit animation first, and route clearing happens only after the exit handoff. If a screenshot or simulator/manual interaction cannot verify safe area and close-button hit testing, report that gap instead of claiming the interaction is fully fixed.
- Keep old micro-motion quality only if it can live inside the compliant layer. Premium details such as numeric motion, restrained scale pulses, quick-action reveal, and Today Focus fades should start in the same interaction frame, but they must be driven by frozen snapshots or lightweight local progress, not by thawing live business state.
- Prefer making incorrect architecture difficult to express: use typed snapshots, read models, command executors, thaw coordinators, route-scoped tasks, and explicit `isAnimating`/`isFrozen` gates instead of ad-hoc booleans scattered through views.

Before reporting completion in this mode, include a short compliance matrix with `Compliant`, `Partial`, or `Not compliant` for:

- Finger-first frame.
- Frozen render or snapshot handoff.
- Heavy work deferred and cancellable.
- Visual/business separation.
- Runtime budget and visibility gating.
- Thaw timing.
- Safe area and hit testing.
- Validation performed.

If any row is `Partial` or `Not compliant`, do not present the task as complete. Describe the remaining gap, the reason it remains, and the next concrete step needed to reach full compliance.

## Interaction Architecture & Isolation

Every user action must be classified before implementation:

- Visual-only interaction: may mutate local `@State`, `@Binding`, `@Bindable`, focus state, pressed/selected state, and token-driven animation state only. It must not fetch SwiftData, decode images, rebuild dashboards, start timers, create routes for unrelated screens, or call cross-page services.
- Navigation-only interaction: updates a typed route, sheet route, popup route, or `NavigationPath` through the route host/coordinator. Destination data loading must be lazy and scoped to that destination.
- Business command: calls exactly one domain service entry point that writes one business fact. Cross-feature fan-out, such as task/reminder/reward synchronization, belongs inside domain services after the fact is committed, not in the View.
- Runtime/ambient work: timers, map refresh, location, repeating animations, particles, Canvas, and background refresh must go through `AppWorkloadPolicy`.

Tap handlers, hero transitions, sheet presentations, quick check-ins, and card expansion must make the visible interaction responsive first. Heavy work should run after the first frame, after animation handoff, or in a cancellable task. Prefer `OhanaFrameScheduler.runAfterNextFrame`, animation completion, or a route-scoped `.task(id:)` instead of doing route mutation, SwiftData scans, image decoding, service fan-out, analytics, timers, and animation state changes in the same frame.

A light interaction must never awaken a heavy system by accident. If a tap visually opens a card, that tap should not also recompute Today Focus, refetch all care events, rebuild all routes, normalize theme colors, refresh widgets, and start repeating animations.

## Layer Ownership Matrix

Keep ownership strict:

- `Views/`: compose UI, own ephemeral visual state, emit typed user intents, and bind to render snapshots. Views do not own cross-page business rules, persistence writes, background policies, or broad data aggregation.
- Render components: pure visual surfaces that receive value snapshots. They must not import SwiftData, access `ModelContext`, call services, own navigation, start timers, or observe global app state unless explicitly required.
- Route hosts/coordinators: own `NavigationStack`, `NavigationPath`, sheet routes, popup routes, deep links, notification routes, and App Intent openings. They do not perform domain writes.
- Snapshot builders/read models: convert SwiftData/service state into small, stable, preferably `Equatable` render state. They do not animate, navigate, or mutate business facts.
- Domain services: own invariants, persistence writes, privacy filters, task/reminder/reward synchronization, and deletion/memorial edge cases. They must not import SwiftUI.
- Runtime policy: `AppWorkloadPolicy` is the only source for foreground/background, Low Power Mode, Reduce Motion, app power-saving mode, timer, refresh, and repeating-animation decisions.
- Motion scenes: own visual progress, frozen snapshots, transform, mask, opacity, zIndex, and hit testing. They do not query SwiftData or execute business commands during animation.

## Architecture, Compliance & Energy Guardrails

Use `docs/app-architecture-governance.md` as the engineering source of truth for app architecture boundaries, App Store-sensitive background behavior, privacy, energy, runtime observability, and long-term maintainability. Use `docs/feature-module-contract.md`, `docs/startup-and-lazy-loading-policy.md`, `docs/performance-and-observability.md`, `docs/data-cache-sync-policy.md`, `docs/release-quality-gates.md`, `docs/design-system-governance.md`, `docs/accessibility-governance.md`, `docs/reliability-slo.md`, `docs/privacy-compliance.md`, `docs/concurrency-and-error-policy.md`, `docs/dependency-governance.md`, and `docs/os-support-matrix.md` for mature-app quality gates. UI-specific rules still come from `ui规范.selection.json`.

Cross-page runtime policy belongs in `Ohana/App/AppRuntimePolicy.swift`. Do not create parallel low-power, Reduce Motion, scene phase, performance monitor, or background-work policies inside individual views. Views should consume `AppWorkloadPolicy` and keep foreground visible interactions visually unchanged. Interaction motion and ambient work are separate budgets. Visible taps, selections, card expansion, FAB reveal, and popup presentation use `interactionMotionBudget`; decorative loops, particles, breathing glows, Canvas, and repeating effects use `ambientMotionBudget`; timers, maps, countdowns, polling, and refresh use `refreshBudget`. Do not substitute one budget for another.

### SwiftData, Read Models, and ViewModels

Use SwiftData as the persistence/model layer, not as a render-time aggregation engine.

- Do not place broad `@Query` reads inside reusable cards, rows, animation layers, popups, or hero transition views.
- Screen containers may query narrowly scoped data, then pass value snapshots into render components.
- Expensive grouping, sorting, filtering, privacy filtering, task synchronization, and dashboard aggregation should live in services or snapshot builders, not in `body`.
- ViewModels are allowed only for one screen's complex read-only aggregation or interaction coordination. They must not hide SwiftData write logic or cross-page business rules.
- Persistence writes go through domain services. A user action writes one business fact once, then services synchronize derived states.

### Off-Main Aggregation Law

Deferring heavy work past the first frame is necessary but NOT sufficient: deferred work that still runs on the main actor steals scroll and animation frames as data grows. The finger-first frame law moves cost out of the tap frame; this law moves it off the main thread entirely.

- New read models, snapshot stores, and snapshot builders for high-frequency surfaces must perform SwiftData fetching and aggregation off the main actor — use `@ModelActor` (as `DataBackupRuntime` and `CareLedgerBackfillService` already do) or a background `ModelContext` — and deliver small, `Equatable` value snapshots back to the `MainActor` for rendering.
- `Task { @MainActor in ... fetch ... aggregate ... }` inside a `*ReadModelStore`, `*SnapshotStore`, or `*SnapshotBuilder` is the anti-pattern this law exists to stop. It is flagged by the `main-actor-aggregation` smoothness audit rule and the `main_actor_read_model_refresh` SwiftLint rule.
- Existing main-actor aggregation (for example `HomeReadModelStore`) is ratcheted debt in `docs/governance/manifests/full-scope-audit-baseline.json`: do not add more, and migrate the existing cases when touching those features.
- Aggregation cost must be bounded by data-scale budgets: snapshot builders are tested against the dense-data fixture standard in `docs/performance-and-observability.md`, not only against fresh-install data.
- The snapshot handoff remains main-actor: only the prepared value crosses back. Never pass live `@Model` objects across actors into render layers.

Core Location must stay centralized in `LocationManager` and `PetWalkingManager`. Only a running dog walk may keep background location active; paused, stopped, or non-walk app states must stop location updates. Do not create `CLLocationManager`, set `allowsBackgroundLocationUpdates = true`, or request Always authorization outside that flow.

Repeating work must be visible and intentional. New `Timer.publish`, `TimelineView(.animation)`, `repeatForever`, Canvas loops, particle loops, or Map live updates must be paused or downgraded through `AppWorkloadPolicy` when the page is invisible, app is backgrounded, Low Power Mode is on, Reduce Motion is enabled, or app power-saving mode is enabled. Use elapsed-time calculations instead of background timers for durations.

Before reporting runtime, energy, background-location, or animation-loop work complete, run `scripts/audit-runtime-guardrails.sh`. Fix warnings or add `// runtime-guardrail: allow <reason>` only for deliberate exceptions.

### Interaction Performance Review Checklist

Before reporting an interaction-heavy change complete, verify:

- The user-triggered first frame contains only the minimum visual state mutation; any complex data, route, persistence, service, or refresh work is invisible, cancellable, cacheable, batchable, or deferred.
- The tap/drag/selection handler mutates only the minimal state required for immediate feedback.
- Hidden, covered, faded, off-tab, or inactive surfaces are unmounted, inert, or snapshot-only; they are not merely transparent while still aggregating data or rendering complex view trees.
- Decorative loops and ambient motion are absent by default on high-frequency screens, or explicitly opt-in through `AppWorkloadPolicy` with visibility gating.
- High-frequency `.task(id:)`, `.onChange`, identity, and animation-driving dependencies are cheap tokens, not full content signatures or time buckets.
- No reusable visual component owns `ModelContext`, broad `@Query`, timers, location, analytics fan-out, or cross-page services.
- Heavy data refresh is deferred until after first frame, route presentation, or animation handoff.
- Route-scoped `.task(id:)` work is cancellable when the route disappears.
- Repeating work uses `AppWorkloadPolicy` and stops or downgrades when invisible, backgrounded, Low Power Mode, Reduce Motion, or app power-saving mode applies.
- Animation layers use frozen snapshots and do not scan SwiftData, decode images, or insert/remove complex view trees during transition.
- Inline overlays, custom sheets, and full-screen popups have verified entry and exit animations, explicit safe-area insets, top controls outside the status bar/Dynamic Island region, bottom controls outside the home-indicator region, and disabled hit testing while the presentation is entering or exiting.
- If a system sheet is replaced with an inline overlay, validate the actual route with a simulator screenshot, accessibility/semantic tap, or manual-device run when reachable. If the app cannot reach that route because seed data/onboarding blocks it, say so explicitly and do not present visual verification as complete.
- If business state changes, add or update a SwiftData in-memory test proving the service writes one fact and synchronizes derived task/reminder/reward state.

## UI Design Source of Truth

Use `ui规范.selection.json` at the repository root as the single machine-readable source of truth for Ohana UI design tokens. Before changing app views, shared UI components, colors, cards, buttons, inputs, sheets, charts, calendars, or motion, read this file first and apply its selected tokens.

Treat `docs/design/ui规范.md` as the human-readable companion that explains the rules, rationale, and usage constraints for the same selection. If it appears to conflict with `ui规范.selection.json`, the JSON token selection wins and the Markdown should be updated to match.

The in-app UI guidelines console under `设置 > 开发者工具 > UI/UX 规范查看` is an editor, preview, and export surface only. Its AppStorage state is not authoritative until the exported V4 JSON is copied back into `ui规范.selection.json` and the companion Markdown is updated.

Implementation files such as `Ohana/Shared/Design/ColorExtensions.swift`, `Ohana/Shared/Design/OhanaDesignSystem.swift`, and `Ohana/Features/Settings/DesignLab/DesignSpecTypesV4.swift` are consumers or mirrors of the design source. Do not treat hardcoded defaults in Swift as a separate design source; update them only to reflect `ui规范.selection.json`.

Keep this file as workflow guidance, not a second UI spec. The detailed token values for primary colors, member/domain colors, card usage, navigation chrome, sheet/popup geometry, chart style, and motion behavior belong in `ui规范.selection.json` and are explained in `docs/design/ui规范.md`.

High-risk reminders for agents:
- Color semantics are reserved; do not reuse `goPrimary`, `goLime`, `goBlue`, or their aliases outside the roles allowed by the JSON tokens.
- Sheets and popups use independent `sheet*` tokens; do not infer popup styling from normal card/input/button tokens.
- Key spatial interactions use the stable ZStack motion scene pattern; motion is a render-layer concern and must not trigger SwiftData scans, image decoding, service fan-out, or route rebuilds during the visible transition.
- Navigation chrome, settings rows, card usage, and short popup behavior must follow their explicit token families instead of local one-off styling.

For new pages or major view refactors, start from `docs/ui-v4-new-page-template.md`. New SwiftUI views should use `OhanaAppBackground()`, semantic Ohana text colors, shared card/button/sheet helpers, `ScaleButtonStyle()`, and `GoMotion` tokens by default.

Construction-level consistency (`Ohana/Shared/Components/OhanaFormControls.swift`): text inputs use `OhanaTextField` (or `InlineNumericInput`/`GoDraftInput`) instead of raw `TextField`; corner radii come from the `OhanaRadius` semantic scale instead of literals; system sheet detents come from `OhanaSheetDetents` presets or the shared `ohanaSheetPagePresentation`/`ohanaCompactSheetPresentation` helpers instead of per-sheet `.height(<number>)`. The `raw-textfield`, `hardcoded-corner-radius`, and `hardcoded-detent-height` audit rules enforce this for new code; legacy literals are ratcheted in the full-scope baseline and migrate when their files are touched. `ohana-design-system/` is reference-only — its README carries a repo notice that V4 tokens win on conflict.

Before reporting UI work complete, run `scripts/audit-ui-v4.sh --changed` or a path-specific scan such as `scripts/audit-ui-v4.sh Ohana/Shared/Components/NewView.swift`. Fix warnings, or add an inline `// ui-v4: allow <reason>` only for intentional exceptions like modal scrims or asset-specific ink colors.

Also run `scripts/audit-accessibility.sh --changed` and follow `docs/accessibility-governance.md`: icon-only controls need localized `accessibilityLabel`s, interactive targets need a 44x44pt hit area, text uses Dynamic Type (`OhanaFont.*`, not fixed `.system(size:)`), state is never conveyed by color alone, and high-traffic flows get a VoiceOver + largest-Dynamic-Type pass. Use `// a11y: allow <reason>` only for genuinely decorative or non-interactive exceptions.

## UI UX Pro Max Advisory Skill

The repository may include `.codex/skills/ui-ux-pro-max/`, installed from `nextlevelbuilder/ui-ux-pro-max-skill`, and the local companion note `docs/ui-ux-pro-max-ohana-adaptation.md`. Treat this skill as an advisory UI/UX review and idea-generation layer only.

`ui规范.selection.json` remains the single machine-readable UI source of truth. If `ui-ux-pro-max` suggests colors, fonts, shadows, sheets, navigation, or component behavior that conflicts with Ohana V4, ignore the suggestion or translate it into existing V4 tokens instead. Do not import generated palettes, Google Fonts, landing-page structures, or web-specific rules into the app.

Use `ui-ux-pro-max` for broad UX questions, accessibility checks, SwiftUI form/chart/sheet guidance, and product-category inspiration. Then implement through Ohana shared components and verify with `scripts/audit-ui-v4.sh` and `scripts/build-debug-fast.sh`.

## Animation Pattern Memory

Use `docs/open-swiftui-animations-memory.md` and `docs/pow-animation-memory.md` as Ohana's local memory for patterns learned from `amosgyamfi/open-swiftui-animations` and `EmergeTools/Pow`. Treat them as inspiration and implementation guidance, not as vendored source code.

When adding motion, prefer the shared helpers in `Ohana/Shared/Components/OhanaMotionEffects.swift`, `Ohana/Shared/Components/OhanaZStackMotionScene.swift`, and existing `GoMotion` tokens. Reuse `PhaseAnimator`, `contentTransition(.numericText())`, `symbolEffect`, `dashPhase`, staged spring entrances, ping, shine, shake, and pop-style transitions where they add clear meaning: rewards, attention states, counters, FAB/menu reveal, chart/progress entry, validation errors, pending task review, and success feedback. Respect Reduce Motion and avoid decorative loops on high-frequency screens.

### Premium Micro-Motion Law

Ohana's default motion taste is restrained, elastic, and legible: never stiff, never cartoony. The preferred feel is the light spring used by `CoconutBalanceCapsule`, `ohanaNumericMotion`, and the Ohana wealth/island coconut counters: tiny scale response, numeric text interpolation, and a crisp one-shot feedback pulse.

- Animate numbers as numbers. Any visible count, currency, coconut balance, streak, progress total, badge, calendar agenda count, or dashboard metric should use `.ohanaNumericMotion(value)` or `contentTransition(.numericText())` with an existing `GoMotion` token. Real positive/negative deltas may use the `CoconutBalanceCapsule` style floating delta; context switches must not pretend to be earned/spent deltas.
- Animate context changes with snapshot handoff. Switching family members, pets, calendar owners, dashboard filters, or segmented modes should first update only the selected local UI state, then transition the already-built render snapshot with `GoMotion.selection` or `GoMotion.stateChange`. Use a subtle opacity/offset/scale handoff, such as 0.985 to 1.0 or 1.0 to 0.985, not a hard reload, spinner, or abrupt content replacement.
- Keep scale tiny and meaningful. Selection/context feedback should stay around 1.01-1.05; reward or success pulses may reach about 1.08-1.12. Avoid large bounce, rubber-band effects, repeated wobble, or unrelated decorative motion on work-focused screens.
- Make related changes start together. For a tap that changes a selected chip, visible number, chart, card, and detail content, the first visible feedback must begin in the same interaction frame. Heavy data refresh or persistence still runs later through cancellable snapshot builders or command executors.
- Avoid two-step page motion. A route/tab/content switch should not animate horizontally and then resize/reflow vertically. Keep the page frame stable, prepare the destination snapshot, and animate one coherent transition.
- Respect runtime budgets. Premium micro-motion is interaction motion, not ambient motion. It must respect Reduce Motion and `AppWorkloadPolicy.interactionMotionBudget`; background loops, breathing effects, particles, and timers remain governed by ambient/refresh budgets.
- Before reporting UI work complete, do a motion pass: counters use numeric motion, selected/filter/member changes use snapshot handoff, content does not pop in abruptly, related animated elements start together, and no animation masks slow data work.

## Localization Source of Truth

Ohana must support all registered app languages (currently zh-Hans, en, de, es, pt, fr, ja, ko, it; the registry is `Ohana/Shared/LocalizationSettings.swift`) across user-facing pages. Use `Ohana/Shared/Localization.swift` (`L10n`, `AppLanguage`, and `AppLocalizedText`) as the code source of truth for dynamic strings, interpolated text, formatter labels, alerts, sheet titles, button labels, and any text built outside a static SwiftUI `Text("...")` key. Chinese and English are mandatory at authoring time (`L10n.tr(zh:en:...)`); other languages are optional parameters that resolve through the fallback chain, with curated static translations for high-traffic strings.

Use the per-language `Ohana/<code>.lproj/Localizable.strings` files as the resource source for static SwiftUI localization keys, with `en` as the parity reference (`scripts/audit-localization-coverage.sh` checks key parity against `en.lproj`). Chinese is the source language in code/base UI; non-Chinese resources must avoid leaking Chinese text. If a translation is not ready for a language, use a clear English fallback rather than Chinese.

Do not add new direct language ternaries such as `appLanguage == "zh" ? ... : ...` or `AppLanguage.isEnglish ? ... : ...` in views. Prefer `L10n(appLanguage).tr(zh:en:...)`, `L10n.current`, or `AppLocalizedText(zh:en:...)`. For legacy APIs that only accept `isEnglish`, pass `L10n(...).isEn` so other languages fall back to English instead of Chinese.

When adding or refactoring pages, include at least Chinese and English copy at the same time and add other languages where translations are available. For dates, numbers, currency, units, and relative labels, use `AppLanguage.effectiveLocale`, `AppLanguage.compactMonthDayFormat`, `AppLanguage.fullMonthYearFormat`, or a localized helper instead of hardcoded Chinese date formats.

## Performance & Observability Gates

For high-traffic flows, do not report "feels fast" as validation. Report the user flow, the measurement method, and whether the change affects launch, first render, tap response, route transition, scrolling, memory, SwiftData reads, image decoding, timers, or background work.

Use `docs/performance-and-observability.md` for flow budgets, the dense-data fixture standard, and probe naming. Add privacy-safe probes/signposts for critical flows when measurement would otherwise be guesswork; flows listed in `docs/governance/manifests/performance-slo.json` must keep their `probeNames` present in source (the governance manifest audit enforces this).

### Thermal, Memory, and Energy Budgets

- `AppWorkloadPolicy` is the single budget arbiter. It currently gates on foreground/background, Low Power Mode, Reduce Motion, and the user power-saving mode; extending it with `ProcessInfo.thermalState` gating (downgrade ambient and interaction motion budgets at `.serious`, pause ambient work at `.critical`) is tracked as P0 work in `docs/release-hardening-plan.md`. New runtime surfaces must consume the thermal budget once it exists rather than reading `thermalState` locally.
- Every cache (image, avatar, snapshot, read-model) must have an owner entry in `docs/governance/manifests/cache-ownership.json` with an eviction story. Caches holding decoded images or large snapshots must evict on memory-pressure warnings; adding that eviction path to the existing caches is tracked as P0 work in `docs/release-hardening-plan.md`.
- MetricKit hang/launch summaries flow through `Ohana/App/MetricKitObserver.swift`. When a perf-sensitive change ships, check the next MetricKit payload rather than assuming success.

## Testing Guidelines

Tests use Swift Testing (`import Testing`) with `@Test` functions and `#expect` assertions. Add unit coverage in `OhanaTests/` for service, model, and persistence behavior; add UI flows in `OhanaUITests/` only when validating user-facing navigation or launch behavior. Name tests after the behavior under test, for example `reminderSchedulingServiceDeduplicatesEventAndScheduledMinute`. Use in-memory SwiftData containers for persistence tests to avoid touching real app data.

### Test Pyramid and Scenario Matrix

Use the smallest reliable test that catches the failure:

- Domain service tests: business facts, invariants, task/reminder/reward synchronization, privacy filters, delete/memorial behavior.
- Snapshot/read-model tests: aggregation, sorting, filtering, empty states, dense data, privacy placeholders.
- Route tests: typed route creation, deep link/App Intent/notification route mapping, route cancellation.
- Runtime policy tests: Low Power, Reduce Motion, scene phase, visible/invisible state, timer/animation/map gating.
- UI tests: only for high-value flows where layout, navigation, keyboard, or route behavior cannot be trusted through unit tests.

For high-frequency user flows, test at least the relevant subset: empty data, dense data, missing images, long German text, private/locked state, failed write, reopen after background, Low Power Mode behavior if runtime work exists, Reduce Motion behavior if animated, and in-memory SwiftData migration or compatibility when schema changes.

## Commit & Pull Request Guidelines

Recent history uses concise imperative commits, often Conventional Commit style such as `feat(home): ...` and `fix(theme): ...`. Prefer `feat(scope):`, `fix(scope):`, `chore(scope):`, or a short imperative sentence when no scope fits. Pull requests should include a summary of changes, test results or simulator used, linked issues when applicable, and screenshots or recordings for visible UI changes.

For medium/high-risk changes, include a release quality note using `docs/release-quality-gates.md`. Do not ship high-risk persistence, privacy, startup, background, or cross-feature changes with only a successful build.

## Security & Configuration Tips

Do not commit personal provisioning profiles, signing secrets, derived data, or local simulator state. Keep bundle identifiers, entitlements, background task identifiers, and SwiftData migration-sensitive changes coordinated with the Xcode project settings.

## Agent Behavioral Guidelines

These behavioral rules apply when writing, reviewing, or refactoring code.


# Karpathy behavioral guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
