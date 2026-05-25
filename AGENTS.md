# Repository Guidelines

In Ohana, a light interaction must stay light: visual feedback, route mutation, data aggregation, persistence writes, background work, timers, and animation loops are separate systems with explicit handoff points.

## Project Structure & Module Organization

This repository contains the Ohana iOS app. Main SwiftUI app code lives in `Ohana/`, with `Models/`, `ViewModels/`, `Views/`, `Utilities/`, localized resources in `en.lproj/`, and app assets in `Assets.xcassets/`. Unit tests are in `OhanaTests/`; UI tests are in `OhanaUITests/`. Project-level documentation and design references live at the repository root, while helper automation belongs in `scripts/`. `Ai_Studio_New_UI/` and `ohana-design-system/` are separate design/reference projects; avoid changing them unless the task explicitly targets those folders.

## Build, Test, and Development Commands

- `open Ohana.xcodeproj` opens the app in Xcode for local development.
- `xcodebuild -project Ohana.xcodeproj -scheme Ohana -configuration Debug build` builds the app from the command line.
- `scripts/build-debug-fast.sh` is the default quick Debug build. It intentionally uses `platform=iOS Simulator,name=iPhone 17` without an `OS=` pin so Xcode uses the installed default iOS 26.5 simulator runtime and does not try to download or resolve an older runtime.
- `xcodebuild test -project Ohana.xcodeproj -scheme Ohana -destination 'platform=iOS Simulator,name=iPhone 16'` runs unit and UI tests on a simulator; adjust the device name to one installed locally.
- `xcodebuild -list -project Ohana.xcodeproj` lists available targets, schemes, and configurations.

## iOS Agent Workflow

Treat this repository as an existing SwiftUI Xcode project, not a greenfield scaffold. Reuse `Ohana.xcodeproj`, the `Ohana` scheme, existing models, navigation patterns, assets, and shared utilities before adding new structure.

Keep the development loop CLI-first. Start with the narrowest trustworthy check for the code touched, then expand only when needed:
- Use `xcodebuild -list -project Ohana.xcodeproj` when schemes or targets are unclear.
- Use `xcodebuild -project Ohana.xcodeproj -scheme Ohana -configuration Debug build` for a general app build.
- Use `scripts/build-debug-fast.sh` for day-to-day validation; do not hardcode older simulator OS versions such as `OS=26.4.1`. Let Xcode select the installed default iOS 26.5 runtime unless a task explicitly requires another destination.
- Use `xcodebuild test -project Ohana.xcodeproj -scheme Ohana -destination 'platform=iOS Simulator,name=iPhone 16'` for test validation when behavior or persistence changes.
- For UI changes, prefer a simulator build/run and screenshots after the code compiles; if deeper simulator control is available through XcodeBuildMCP or similar tooling, use it to launch, inspect logs, and capture screenshots.

For iPhone and iPad work, keep the implementation focused on those platforms unless the task explicitly asks for broader Apple-platform support. When reporting completion, include the scheme, simulator destination, and validation commands that were actually used.

For simulator-only UI bugs, keep one failure mode per run and own the reproduce-fix-verify loop. Build and launch the app, confirm the starting screen with a screenshot or UI snapshot, drive the reported path with taps, typing, scrolling, or swipes, capture relevant screenshots/logs, make the smallest fix, then rerun the same path. Prefer accessibility labels and identifiers over raw coordinates; if a control can only be reached by coordinates, call that out as a testability gap.

When adding App Intents, start from Ohana's highest-value external actions rather than mirroring the whole app. Good first candidates are quick pet-care logging, openingep high-frequency UI paths lightweight. Taps, hero transitions, sha specific pet or human profile, viewing today's care focus, and creating or jumping to reminders. Keep `AppEntity` surfaces smaller than the SwiftData model layer, add `AppShortcutsProvider` entries only for discoverable user-facing actions, and route intent-driven app openings into the existing navigation/state model cleanly.

Only adopt iOS 26 Liquid Glass APIs when a task explicitly asks for that migration. Audit one high-traffic flow at a time, preserve older-iOS fallbacks with availability checks, and prefer native glass APIs over custom blur stacks once the deployment target and Xcode toolchain support them.

### Route Contract

Navigation must be typed and data-driven.

- Prefer route enums/structs such as `AppRoute`, `SheetRoute`, `PopupRoute`, or feature-local route types over ad-hoc booleans scattered across views.
- App Intents, deep links, notifications, widgets, and shortcuts must translate into route values first, then let the route host present the destination.
- Route state should carry stable identifiers and lightweight parameters, not full SwiftData object graphs or prebuilt destination views.
- Building a route must not eagerly build all destination trees, scan global data, or refresh unrelated dashboards.
- Dismissing a route should cancel route-scoped tasks and release frozen animation snapshots.

## Coding Style & Naming Conventions

Use Swift and SwiftUI conventions already present in the project: four-space indentation, `PascalCase` for types, `camelCase` for properties/functions, and descriptive service/view names such as `ReminderSchedulingService` or `FocusStackHomeTestView`. Keep views focused and move business logic into `Utilities/`, `ViewModels/`, or domain services. Prefer `MARK:` sections for larger Swift files. Do not introduce broad reformatting in unrelated files.

Avoid oversized Swift files, especially giant SwiftUI view files. When a view grows into a compile/runtime hot spot, split it by responsibility before adding more behavior: pure visual surfaces, state/coordinator objects, route hosts, business executors, data snapshot builders, and reusable subviews should live in separate files. Card stacks, hero animations, Today Focus, FAB menus, sheets, charts, and quick actions should not all be owned by one massive view. This protects incremental build time, SwiftUI diffing cost, first-frame responsiveness, animation smoothness, and energy usage.

Keep high-frequency UI paths lightweight and two-phase. Phase 1 is visual: update only local interaction state, typed route state, frozen render snapshots, and token-driven animation state needed to start the visible response. Phase 2 is business/data: after the first frame, route presentation, or animation handoff, run cancellable service or snapshot refresh work. Do not decode images, scan large SwiftData collections, build complex route trees, start timers, synchronize tasks/reminders/rewards, or recompute unrelated dashboards in the same frame as a tap, drag, sheet presentation, hero transition, or quick check-in.

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

Use `docs/app-architecture-governance.md` as the engineering source of truth for app architecture boundaries, App Store-sensitive background behavior, privacy, energy, runtime observability, and long-term maintainability. UI-specific rules still come from `ui规范.selection.json`.

Cross-page runtime policy belongs in `Ohana/Utilities/AppRuntimePolicy.swift`. Do not create parallel low-power, Reduce Motion, scene phase, performance monitor, or background-work policies inside individual views. Views should consume `AppWorkloadPolicy` and keep foreground visible interactions visually unchanged. Interaction motion and ambient work are separate budgets. Visible taps, selections, card expansion, FAB reveal, and popup presentation use `interactionMotionBudget`; decorative loops, particles, breathing glows, Canvas, and repeating effects use `ambientMotionBudget`; timers, maps, countdowns, polling, and refresh use `refreshBudget`. Do not substitute one budget for another.

### SwiftData, Read Models, and ViewModels

Use SwiftData as the persistence/model layer, not as a render-time aggregation engine.

- Do not place broad `@Query` reads inside reusable cards, rows, animation layers, popups, or hero transition views.
- Screen containers may query narrowly scoped data, then pass value snapshots into render components.
- Expensive grouping, sorting, filtering, privacy filtering, task synchronization, and dashboard aggregation should live in services or snapshot builders, not in `body`.
- ViewModels are allowed only for one screen's complex read-only aggregation or interaction coordination. They must not hide SwiftData write logic or cross-page business rules.
- Persistence writes go through domain services. A user action writes one business fact once, then services synchronize derived states.

Core Location must stay centralized in `LocationManager` and `PetWalkingManager`. Only a running dog walk may keep background location active; paused, stopped, or non-walk app states must stop location updates. Do not create `CLLocationManager`, set `allowsBackgroundLocationUpdates = true`, or request Always authorization outside that flow.

Repeating work must be visible and intentional. New `Timer.publish`, `TimelineView(.animation)`, `repeatForever`, Canvas loops, particle loops, or Map live updates must be paused or downgraded through `AppWorkloadPolicy` when the page is invisible, app is backgrounded, Low Power Mode is on, Reduce Motion is enabled, or app power-saving mode is enabled. Use elapsed-time calculations instead of background timers for durations.

Before reporting runtime, energy, background-location, or animation-loop work complete, run `scripts/audit-runtime-guardrails.sh`. Fix warnings or add `// runtime-guardrail: allow <reason>` only for deliberate exceptions.

### Interaction Performance Review Checklist

Before reporting an interaction-heavy change complete, verify:

- The tap/drag/selection handler mutates only the minimal state required for immediate feedback.
- No reusable visual component owns `ModelContext`, broad `@Query`, timers, location, analytics fan-out, or cross-page services.
- Heavy data refresh is deferred until after first frame, route presentation, or animation handoff.
- Route-scoped `.task(id:)` work is cancellable when the route disappears.
- Repeating work uses `AppWorkloadPolicy` and stops or downgrades when invisible, backgrounded, Low Power Mode, Reduce Motion, or app power-saving mode applies.
- Animation layers use frozen snapshots and do not scan SwiftData, decode images, or insert/remove complex view trees during transition.
- If business state changes, add or update a SwiftData in-memory test proving the service writes one fact and synchronizes derived task/reminder/reward state.

## UI Design Source of Truth

Use `ui规范.selection.json` at the repository root as the single machine-readable source of truth for Ohana UI design tokens. Before changing app views, shared UI components, colors, cards, buttons, inputs, sheets, charts, calendars, or motion, read this file first and apply its selected tokens.

Treat `ui规范.md` as the human-readable companion that explains the rules, rationale, and usage constraints for the same selection. If it appears to conflict with `ui规范.selection.json`, the JSON token selection wins and the Markdown should be updated to match.

The in-app UI guidelines console under `设置 > 开发者工具 > UI/UX 规范查看` is an editor, preview, and export surface only. Its AppStorage state is not authoritative until the exported V4 JSON is copied back into `ui规范.selection.json` and the companion Markdown is updated.

Implementation files such as `Ohana/Utilities/ColorExtensions.swift`, `Ohana/Views/OhanaDesignSystem.swift`, and `Ohana/Views/Details/DesignSpecTypesV4.swift` are consumers or mirrors of the design source. Do not treat hardcoded defaults in Swift as a separate design source; update them only to reflect `ui规范.selection.json`.

Color semantics are reserved. `goPrimary` resolves to `goLime` in dark mode and `goBlue` in light mode; these colors are for global brand/system primary actions only. Pet/human theme colors and domain-specific colors such as feeding modes, food kinds, stock, chart series, and status groups must not reuse `goLime`, `goBlue`, or their primary aliases.

Sheets and popups are their own design system. Always read the `sheet*` tokens from `ui规范.selection.json` and keep popup background, popup card, popup input, popup button, and popup chrome independent from global card/input/button tokens.

Short record, confirmation, restock, and lightweight management popups must follow the confirmed inline popup spec: `sheetImplementation=inlineOverlay`, `sheetHorizontalInset=6pt`, `sheetCornerRadius=52pt`, `sheetPosition=bottomNearSafeEdge`, `sheetMaxHeight=contentAdaptive`, `sheetGlass=nativeRegular`, `sheetShadow=liftedAlert`, `sheetBackdrop=scrimGradient`, and `sheetAnimation=bottomSpringScaleFade`. Use an in-page overlay inside the current `ZStack` so the glass samples the real screen behind it; reserve system `.sheet` / `.large` for overview pages, history, long lists, and complex editors.

Key animated interactions must use Ohana's stable ZStack motion scene pattern. For hero cards, FAB/menu reveal, inline popups, reward reveals, gacha/Oasis rewards, role creation cards, and chart range switches, keep visual layers mounted, freeze the UI snapshot before animation, and drive transform/mask/opacity/zIndex/hit-testing from one progress value. Do not insert/remove complex views, decode images, scan SwiftData, or run multiple delayed animations during the same transition. Ordinary static forms and long lists can remain `VStack`/`ScrollView`/`List`.

Motion is a render-layer concern. Business services must not depend on animation state, animation delays, or view lifetimes.

For spatial transitions, freeze the render snapshot before animation starts, mutate only motion-scene state during the transition, and refresh heavier business/read-model state only after visual handoff. Do not fix animation glitches by adding scattered async delays, route rebuilds, service calls, or SwiftData fetches inside the transition.

Use change-driven effects for semantic feedback only: success, reward, attention, validation error, selected state, and confirmation. Decorative loops must be gated by `AppWorkloadPolicy`; Reduce Motion must replace or suppress problematic motion.
Expandable hero card stacks have an extra geometry rule: one motion scene must own both collapsed and expanded frames plus internal alignment, padding, avatar source, quick-action bounds, zIndex, hit-testing, and ambient floating. Verify both stable end states before tuning spring/progress values. Do not fix off-center cards with scattered `x`, padding, or offset tweaks until you have checked the outer `CGRect.midX`, inner alignment, leading/trailing padding, overlay bounds, avatar crop transparency, and frozen/live source consistency. During collapse, return selected zIndex/hit-testing to the collapsed stack before clearing frozen visual sources; keep the frozen card/avatar source for one extra frame and resume floating only after the live collapsed card has taken over.

Navigation chrome and settings rows are explicit tokens too. Use `settingIcon` for Settings-style leading icons, `pageBackButton` for non-sheet back controls, `pageCloseButton` for non-sheet close controls, and `sheetChrome` only for popup/sheet close controls.

Cards are reserved for tappable, navigable, expandable, or editable grouped surfaces. Pure information summaries should use unframed layouts, inline metrics, or lightweight separators instead of card chrome.

For new pages or major view refactors, start from `docs/ui-v4-new-page-template.md`. New SwiftUI views should use `OhanaAppBackground()`, semantic Ohana text colors, shared card/button/sheet helpers, `ScaleButtonStyle()`, and `GoMotion` tokens by default.

Before reporting UI work complete, run `scripts/audit-ui-v4.sh --changed` or a path-specific scan such as `scripts/audit-ui-v4.sh Ohana/Views/Components/NewView.swift`. Fix warnings, or add an inline `// ui-v4: allow <reason>` only for intentional exceptions like modal scrims or asset-specific ink colors.

## UI UX Pro Max Advisory Skill

The repository may include `.codex/skills/ui-ux-pro-max/`, installed from `nextlevelbuilder/ui-ux-pro-max-skill`, and the local companion note `docs/ui-ux-pro-max-ohana-adaptation.md`. Treat this skill as an advisory UI/UX review and idea-generation layer only.

`ui规范.selection.json` remains the single machine-readable UI source of truth. If `ui-ux-pro-max` suggests colors, fonts, shadows, sheets, navigation, or component behavior that conflicts with Ohana V4, ignore the suggestion or translate it into existing V4 tokens instead. Do not import generated palettes, Google Fonts, landing-page structures, or web-specific rules into the app.

Use `ui-ux-pro-max` for broad UX questions, accessibility checks, SwiftUI form/chart/sheet guidance, and product-category inspiration. Then implement through Ohana shared components and verify with `scripts/audit-ui-v4.sh` and `scripts/build-debug-fast.sh`.

## Animation Pattern Memory

Use `docs/open-swiftui-animations-memory.md` and `docs/pow-animation-memory.md` as Ohana's local memory for patterns learned from `amosgyamfi/open-swiftui-animations` and `EmergeTools/Pow`. Treat them as inspiration and implementation guidance, not as vendored source code.

When adding motion, prefer the shared helpers in `Ohana/Views/Components/OhanaMotionEffects.swift`, `Ohana/Views/Components/OhanaZStackMotionScene.swift`, and existing `GoMotion` tokens. Reuse `PhaseAnimator`, `contentTransition(.numericText())`, `symbolEffect`, `dashPhase`, staged spring entrances, ping, shine, shake, and pop-style transitions where they add clear meaning: rewards, attention states, counters, FAB/menu reveal, chart/progress entry, validation errors, pending task review, and success feedback. Respect Reduce Motion and avoid decorative loops on high-frequency screens.

## Localization Source of Truth

Ohana must support Chinese, English, and German across user-facing pages. Use `Ohana/Models/Localization.swift` (`L10n`, `AppLanguage`, and `AppLocalizedText`) as the code source of truth for dynamic strings, interpolated text, formatter labels, alerts, sheet titles, button labels, and any text built outside a static SwiftUI `Text("...")` key.

Use `Ohana/en.lproj/Localizable.strings` and `Ohana/de.lproj/Localizable.strings` as the resource source for static SwiftUI localization keys. Chinese is the source language in code/base UI, while English and German resources must avoid leaking Chinese text. If a German translation is not ready, use a clear English fallback rather than Chinese.

Do not add new direct language ternaries such as `appLanguage == "zh" ? ... : ...` or `AppLanguage.isEnglish ? ... : ...` in views. Prefer `L10n(appLanguage).tr(zh:en:de:)`, `L10n.current`, or `AppLocalizedText(zh:en:de:)`. For legacy APIs that only accept `isEnglish`, pass `L10n(...).isEn` so German falls back to English instead of Chinese.

When adding or refactoring pages, include Chinese, English, and German copy at the same time. For dates, numbers, currency, units, and relative labels, use `AppLanguage.effectiveLocale`, `AppLanguage.compactMonthDayFormat`, `AppLanguage.fullMonthYearFormat`, or a localized helper instead of hardcoded Chinese date formats.



## Testing Guidelines

Tests use Swift Testing (`import Testing`) with `@Test` functions and `#expect` assertions. Add unit coverage in `OhanaTests/` for service, model, and persistence behavior; add UI flows in `OhanaUITests/` only when validating user-facing navigation or launch behavior. Name tests after the behavior under test, for example `reminderSchedulingServiceDeduplicatesEventAndScheduledMinute`. Use in-memory SwiftData containers for persistence tests to avoid touching real app data.

## Commit & Pull Request Guidelines

Recent history uses concise imperative commits, often Conventional Commit style such as `feat(home): ...` and `fix(theme): ...`. Prefer `feat(scope):`, `fix(scope):`, `chore(scope):`, or a short imperative sentence when no scope fits. Pull requests should include a summary of changes, test results or simulator used, linked issues when applicable, and screenshots or recordings for visible UI changes.

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
