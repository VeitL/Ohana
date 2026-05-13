# Repository Guidelines

## Project Structure & Module Organization

This repository contains the Ohana iOS app. Main SwiftUI app code lives in `Ohana/`, with `Models/`, `ViewModels/`, `Views/`, `Utilities/`, localized resources in `en.lproj/`, and app assets in `Assets.xcassets/`. Unit tests are in `OhanaTests/`; UI tests are in `OhanaUITests/`. Project-level documentation and design references live at the repository root, while helper automation belongs in `scripts/`. `Ai_Studio_New_UI/` and `ohana-design-system/` are separate design/reference projects; avoid changing them unless the task explicitly targets those folders.

## Build, Test, and Development Commands

- `open Ohana.xcodeproj` opens the app in Xcode for local development.
- `xcodebuild -project Ohana.xcodeproj -scheme Ohana -configuration Debug build` builds the app from the command line.
- `xcodebuild test -project Ohana.xcodeproj -scheme Ohana -destination 'platform=iOS Simulator,name=iPhone 16'` runs unit and UI tests on a simulator; adjust the device name to one installed locally.
- `xcodebuild -list -project Ohana.xcodeproj` lists available targets, schemes, and configurations.

## iOS Agent Workflow

Treat this repository as an existing SwiftUI Xcode project, not a greenfield scaffold. Reuse `Ohana.xcodeproj`, the `Ohana` scheme, existing models, navigation patterns, assets, and shared utilities before adding new structure.

Keep the development loop CLI-first. Start with the narrowest trustworthy check for the code touched, then expand only when needed:
- Use `xcodebuild -list -project Ohana.xcodeproj` when schemes or targets are unclear.
- Use `xcodebuild -project Ohana.xcodeproj -scheme Ohana -configuration Debug build` for a general app build.
- Use `xcodebuild test -project Ohana.xcodeproj -scheme Ohana -destination 'platform=iOS Simulator,name=iPhone 16'` for test validation when behavior or persistence changes.
- For UI changes, prefer a simulator build/run and screenshots after the code compiles; if deeper simulator control is available through XcodeBuildMCP or similar tooling, use it to launch, inspect logs, and capture screenshots.

For iPhone and iPad work, keep the implementation focused on those platforms unless the task explicitly asks for broader Apple-platform support. When reporting completion, include the scheme, simulator destination, and validation commands that were actually used.

For simulator-only UI bugs, keep one failure mode per run and own the reproduce-fix-verify loop. Build and launch the app, confirm the starting screen with a screenshot or UI snapshot, drive the reported path with taps, typing, scrolling, or swipes, capture relevant screenshots/logs, make the smallest fix, then rerun the same path. Prefer accessibility labels and identifiers over raw coordinates; if a control can only be reached by coordinates, call that out as a testability gap.

When adding App Intents, start from Ohana's highest-value external actions rather than mirroring the whole app. Good first candidates are quick pet-care logging, opening a specific pet or human profile, viewing today's care focus, and creating or jumping to reminders. Keep `AppEntity` surfaces smaller than the SwiftData model layer, add `AppShortcutsProvider` entries only for discoverable user-facing actions, and route intent-driven app openings into the existing navigation/state model cleanly.

Only adopt iOS 26 Liquid Glass APIs when a task explicitly asks for that migration. Audit one high-traffic flow at a time, preserve older-iOS fallbacks with availability checks, and prefer native glass APIs over custom blur stacks once the deployment target and Xcode toolchain support them.

## Coding Style & Naming Conventions

Use Swift and SwiftUI conventions already present in the project: four-space indentation, `PascalCase` for types, `camelCase` for properties/functions, and descriptive service/view names such as `ReminderSchedulingService` or `FocusStackHomeTestView`. Keep views focused and move business logic into `Utilities/`, `ViewModels/`, or domain services. Prefer `MARK:` sections for larger Swift files. Do not introduce broad reformatting in unrelated files.

## UI Design Source of Truth

Use `ui规范.selection.json` at the repository root as the single machine-readable source of truth for Ohana UI design tokens. Before changing app views, shared UI components, colors, cards, buttons, inputs, sheets, charts, calendars, or motion, read this file first and apply its selected tokens.

Treat `ui规范.md` as the human-readable companion that explains the rules, rationale, and usage constraints for the same selection. If it appears to conflict with `ui规范.selection.json`, the JSON token selection wins and the Markdown should be updated to match.

The in-app UI guidelines console under `设置 > 开发者工具 > UI/UX 规范查看` is an editor, preview, and export surface only. Its AppStorage state is not authoritative until the exported V4 JSON is copied back into `ui规范.selection.json` and the companion Markdown is updated.

Implementation files such as `Ohana/Utilities/ColorExtensions.swift`, `Ohana/Views/OhanaDesignSystem.swift`, and `Ohana/Views/Details/DesignSpecTypesV4.swift` are consumers or mirrors of the design source. Do not treat hardcoded defaults in Swift as a separate design source; update them only to reflect `ui规范.selection.json`.

Color semantics are reserved. `goPrimary` resolves to `goLime` in dark mode and `goBlue` in light mode; these colors are for global brand/system primary actions only. Pet/human theme colors and domain-specific colors such as feeding modes, food kinds, stock, chart series, and status groups must not reuse `goLime`, `goBlue`, or their primary aliases.

Sheets and popups are their own design system. Always read the `sheet*` tokens from `ui规范.selection.json` and keep popup background, popup card, popup input, popup button, and popup chrome independent from global card/input/button tokens.

Short record, confirmation, restock, and lightweight management popups must follow the confirmed inline popup spec: `sheetImplementation=inlineOverlay`, `sheetHorizontalInset=6pt`, `sheetCornerRadius=52pt`, `sheetPosition=bottomNearSafeEdge`, `sheetMaxHeight=contentAdaptive`, `sheetGlass=nativeRegular`, `sheetShadow=liftedAlert`, `sheetBackdrop=scrimGradient`, and `sheetAnimation=bottomSpringScaleFade`. Use an in-page overlay inside the current `ZStack` so the glass samples the real screen behind it; reserve system `.sheet` / `.large` for overview pages, history, long lists, and complex editors.

Navigation chrome and settings rows are explicit tokens too. Use `settingIcon` for Settings-style leading icons, `pageBackButton` for non-sheet back controls, `pageCloseButton` for non-sheet close controls, and `sheetChrome` only for popup/sheet close controls.

Cards are reserved for tappable, navigable, expandable, or editable grouped surfaces. Pure information summaries should use unframed layouts, inline metrics, or lightweight separators instead of card chrome.

For new pages or major view refactors, start from `docs/ui-v4-new-page-template.md`. New SwiftUI views should use `OhanaAppBackground()`, semantic Ohana text colors, shared card/button/sheet helpers, `ScaleButtonStyle()`, and `GoMotion` tokens by default.

Before reporting UI work complete, run `scripts/audit-ui-v4.sh --changed` or a path-specific scan such as `scripts/audit-ui-v4.sh Ohana/Views/Components/NewView.swift`. Fix warnings, or add an inline `// ui-v4: allow <reason>` only for intentional exceptions like modal scrims or asset-specific ink colors.

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

description: Behavioral guidelines to reduce common LLM coding mistakes. Use when writing, reviewing, or refactoring code to avoid overcomplication, make surgical changes, surface assumptions, and define verifiable success criteria.
alwaysApply: true
---

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
