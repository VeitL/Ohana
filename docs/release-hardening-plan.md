# Ohana Release Hardening Plan

> Current baseline: 2026-06-02, `ArkSchemaV56`, Xcode 26.5, iOS Simulator SDK 26.5.

## Goal

Ship a stable first release before adding large new surfaces such as iCloud sync, Apple Watch, AI health assistant, or real-time family collaboration.

## Current Blocker

- `scripts/build-debug-fast.sh` must use `-sdk iphonesimulator` and the fixed local destination `-destination 'platform=iOS Simulator,id=EC2C2B3B-3135-4427-89B7-F4B6A6049D66'`.
- In the current Codex sandbox, `CoreSimulatorService` is unavailable, so the fixed simulator build cannot reach compilation.
- The build script now fails fast during preflight when CoreSimulator or the `iPhone 17` simulator is unavailable.

Required local remediation before compile validation:

1. Open Xcode.
2. Confirm the iOS 26.5 simulator runtime is installed in Xcode Settings > Platforms.
3. Confirm the local simulator `iPhone 17 (EC2C2B3B-3135-4427-89B7-F4B6A6049D66)` exists in Devices and Simulators. If it was deleted, recreate an `iPhone 17` simulator and deliberately update `REQUIRED_SIMULATOR_UDID` in `scripts/build-debug-fast.sh`.
4. Rerun `scripts/build-debug-fast.sh`.

## Frozen First-Release Scope

Keep:

- Onboarding and member creation.
- Home card stack and quick care actions.
- Today Focus.
- Calendar reminders and completion.
- Family tasks.
- Coconut rewards and Oasis economy basics.
- Backup and restore.

Defer:

- Multi-device iCloud sync.
- Apple Watch app.
- AI health assistant.
- Real-time family invitation/collaboration.
- Broad visual redesigns outside core routes.

## Required Gates

Baseline:

- `scripts/release-hardening-check.sh`
- `scripts/audit-release-data-safety.sh`
- `scripts/build-debug-fast.sh`
- `scripts/audit-runtime-guardrails.sh --all --soft`
- `scripts/audit-ui-v4.sh --changed`

When CoreSimulator is unavailable in a sandbox, use:

- `scripts/release-hardening-check.sh --skip-build`

This is not a release substitute; it only runs the checks that do not require the fixed `iPhone 17` simulator.

Current non-simulator baseline:

- `scripts/release-hardening-check.sh --skip-build` passed on 2026-06-02.
- Runtime guardrails passed across 412 Swift files.
- Release data safety audit passed; it now checks backup schema version, Human memorial state, HumanHealthMetricLog backup coverage, and PIN hash/salt exclusion.
- Changed UI audit passed for 2 SwiftUI files.
- Backup restore tests were extended for Human memorial state and HumanHealthMetricLog, but `xcodebuild test` is still pending the fixed simulator.
- Git size audit reported repository size around 2.1G and `.git/objects` around 565M, with no tracked tmp files.

Core release paths:

- New pet and new human creation.
- First home load after onboarding.
- Quick feed, water, potty, weight, expense, and walk entry points.
- Today Focus selection and completion.
- Calendar reminder creation, completion, snooze, and overdue compensation.
- Family task create, claim, complete, review, and reward transfer.
- Backup export and import.
- Memorial/privacy deletion boundaries.

Data safety:

- Verify `ArkSchemaV56` opens existing stores.
- Verify fallback disk store behavior.
- Verify backup does not include PIN hash/salt recovery material.
- Verify backup includes human memorial state and HumanHealthMetricLog values.
- Verify future reminders/tasks are removed or hidden after memorial mode.

## UI Debt Policy

Do not attempt a whole-repo V4 cleanup in one pass. Fix UI audit warnings only on routes touched by release validation:

- Onboarding.
- Home.
- Quick action sheets/inline overlays.
- Calendar.
- Settings and backup.
- Memorial/privacy flows.

If a hardcoded color, material, shadow, or loop is intentional, add a local allow comment with a concrete reason.

## Release Report Template

```text
Change:
Risk level:
Affected flows:
Affected data:
Affected permissions:
Affected background work:
Validation commands:
Simulator/device:
Screenshots/recording:
Known limitations:
Rollback/fallback:
```
