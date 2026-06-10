# Ohana Release Hardening Plan

> Current baseline: 2026-06-10, `ArkSchemaV58`, Xcode 26.5, iOS Simulator SDK 26.5.

## Goal

Ship a stable first release before adding large new surfaces such as iCloud sync, Apple Watch, AI health assistant, or real-time family collaboration.

## Simulator Availability

- `scripts/build-debug-fast.sh` uses `-sdk iphonesimulator` and resolves the `iPhone 17` simulator BY NAME on the newest installed iOS runtime (no hardcoded UDID; override with `OHANA_SIMULATOR_NAME` / `OHANA_SIMULATOR_UDID`).
- In sandboxes where `CoreSimulatorService` is unavailable, the script fails fast during preflight; `OHANA_SKIP_SIMULATOR_PREFLIGHT=1` falls back to a name-based destination.

If the preflight reports no `iPhone 17` simulator:

1. Open Xcode.
2. Confirm the iOS simulator runtime is installed in Xcode Settings > Platforms.
3. Create an `iPhone 17` simulator in Devices and Simulators (any UDID — the script resolves by name).
4. Rerun `scripts/build-debug-fast.sh`.

## Hardening Ratchet Roadmap (dated — a deadline-free exemption is a permanent exemption)

P0 — target 2026-07-01:

- [x] `AppWorkloadPolicy`: add `ProcessInfo.thermalState` gating (downgrade ambient + interaction motion budgets at `.serious`, pause ambient work at `.critical`). New runtime surfaces consume the thermal budget instead of reading thermal state locally.
- [x] Memory-pressure eviction for decoded-image/snapshot caches (`FocusPopoutImageCache`, `FocusWalletAvatarCache`, avatar pipeline, map snapshot caches); register eviction stories in `cache-ownership.json`.
- [x] Migrate `HomeReadModelStore` aggregation off the main actor per the Off-Main Aggregation Law (clears the `main-actor-aggregation` baseline entry).
- [x] Promote the five highest-value probes (cold launch, home first render, card expand, tab switch, walk session) from the in-app recorder to `OSSignposter`, keeping probe names.

P1 — target 2026-08-01:

- [ ] Dense-data fixture tests (per `docs/performance-and-observability.md`) for Home, Today Focus, and Calendar snapshot builders, with wall-clock budgets.
- [ ] `XCTApplicationLaunchMetric` baseline test in `OhanaUITests` so cold-launch regressions fail CI instead of relying on prose.
- [ ] SwiftFormat baseline: run `swiftformat .`, commit, remove `continue-on-error` from the CI SwiftFormat step.
- [ ] SwiftLint: clean warning baseline, then flip CI to `swiftlint lint --strict`.
- [ ] Drive `full-scope-audit-baseline.json` (1380 warnings as of 2026-06-10: ui-v4 1309 — mostly legacy corner-radius literals and raw TextFields behind the new construction-consistency rules — accessibility 60, smoothness 11) back to zero, then promote CI to direct `--all` strict gates. Migrate radius/input debt file-by-file when touching those features (UI Debt Policy below), not in one big-bang pass.

P2 — target before App Store submission:

- [ ] MetricKit diagnostics local-export page under 设置 > 开发者工具 (privacy-first: no upload, user-triggered export).
- [ ] Oldest-supported-device smoke run (real hardware) on the core release paths below.
- [ ] Full git-history secret scan (`gitleaks detect` without `--no-git`) and history cleanup if needed; CI currently scans the working tree.

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

- `scripts/release-hardening-check.sh` (runs the full ordered suite below)
- `scripts/tests/run-audit-fixture-tests.sh`
- `scripts/audit-release-data-safety.sh`
- `scripts/build-debug-fast.sh`
- `scripts/audit-runtime-guardrails.sh --all`
- `scripts/audit-architecture-boundaries.sh --all`
- `scripts/audit-full-scope-ratchet.sh` (UI V4 + accessibility + smoothness vs baseline)
- `gitleaks detect --no-git --config .gitleaks.toml`

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

- Verify the current `ArkSchemaV*` (see `Ohana/Models/SharedModelContainer.swift`) opens existing stores.
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
