# Repository Guidelines

## Project Structure & Module Organization

This repository contains the Ohana iOS app. Main SwiftUI app code lives in `Ohana/`, with `Models/`, `ViewModels/`, `Views/`, `Utilities/`, localized resources in `en.lproj/`, and app assets in `Assets.xcassets/`. Unit tests are in `OhanaTests/`; UI tests are in `OhanaUITests/`. Project-level documentation and design references live at the repository root, while helper automation belongs in `scripts/`. `Ai_Studio_New_UI/` and `ohana-design-system/` are separate design/reference projects; avoid changing them unless the task explicitly targets those folders.

## Build, Test, and Development Commands

- `open Ohana.xcodeproj` opens the app in Xcode for local development.
- `xcodebuild -project Ohana.xcodeproj -scheme Ohana -configuration Debug build` builds the app from the command line.
- `xcodebuild test -project Ohana.xcodeproj -scheme Ohana -destination 'platform=iOS Simulator,name=iPhone 16'` runs unit and UI tests on a simulator; adjust the device name to one installed locally.
- `xcodebuild -list -project Ohana.xcodeproj` lists available targets, schemes, and configurations.

## Coding Style & Naming Conventions

Use Swift and SwiftUI conventions already present in the project: four-space indentation, `PascalCase` for types, `camelCase` for properties/functions, and descriptive service/view names such as `ReminderSchedulingService` or `FocusStackHomeTestView`. Keep views focused and move business logic into `Utilities/`, `ViewModels/`, or domain services. Prefer `MARK:` sections for larger Swift files. Do not introduce broad reformatting in unrelated files.

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