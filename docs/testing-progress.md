# Testing and Release Status

> Active validation dashboard only. The verbose pre-audit-sync ledger is
> archived at
> [`docs/archive/testing-progress-2026-07-10-pre-audit-sync.md`](archive/testing-progress-2026-07-10-pre-audit-sync.md).
> Older history is at
> [`docs/archive/testing-progress-full-2026-06-25.md`](archive/testing-progress-full-2026-06-25.md).
>
> Workflow: [`docs/ai-module-test-playbook.md`](ai-module-test-playbook.md).
>
> Status ownership: [`docs/status-ledger-map.md`](status-ledger-map.md).
>
> True-device plan: [`docs/release-true-device-test-plan.md`](release-true-device-test-plan.md).

## Current Release Read

- Last compacted: 2026-07-11.
- Release bar: **Open P0 = 0; first-release-reachable P1 = 3**.
- Active phase: **release hardening before RC**, status 🟡 while first-release
  P1 decisions and proof remain open.
- Open follow-ups: 12 total in `docs/task-follow-ups.md`.
- Open P1: 8 total: 3 first-release code/proof/product gaps, 1 deferred
  CloudKit 1.x item, and 4 physical-device validation items.
- Current decision: continue development; do not submit to App Store or call the
  app RC-ready until TFU-20260710-007 through TFU-20260710-009 are
  dispositioned.

## Evidence Reconciliation

Dated results describe different surfaces and must not be collapsed into a
single “all tests pass” claim:

| Evidence date | Surface | Result | Current meaning |
| --- | --- | --- | --- |
| 2026-07-11 TFU-20260710-006 closure | SwiftData primary-store identity, startup failure/retry UI, and risk-based test routing | Store recovery Unit/Integration tests passed 9/9; the fail-closed/retry UI path passed 1/1; the dedicated Unit and UI schemes each resolve to App plus one test target | Production no longer opens a second writable disk or memory store. Migration-plan fallback retries the same primary identity; total open failure mounts a non-writable recovery shell. TFU-20260710-006 is closed locally. |
| 2026-07-11 D17 Pet-first closure | Clean-install Pet-first journey, optional-Human compatibility, interruption/idempotency units, and relaunch-isolated timing | D17 stability passed 10/10; median 29.97 seconds, mean 30.61, range 29.03–32.93; later optional-Human UI flow and legacy Human-fixture smoke passed | TFU-20260710-005 is closed for repository-local acceptance. Signed-device touch latency, VoiceOver traversal, energy, and permission dialogs remain physical-device evidence, not part of this closure. |
| 2026-07-11 UI smoke closure | Fast release smoke, relaunch-isolated first-pet stability, and 47-failure root-cause disposition | Fast smoke passed 3/3; first-pet path passed 10/10 repetitions; all 47 historical failures map to 14 named clusters with representative reruns | Repository-local UI smoke gate is restored. The full 81-test suite was not rerun, so this is not an 81/81 claim; physical VoiceOver traversal remains true-device evidence. |
| 2026-07-10 pre-audit baseline | CI-equivalent unit scheme and static/local gates | Archived ledger records 1,509 unit tests passing, lint/audits passing, and a Release simulator build passing | Strong unit/static baseline for that commit; not proof of current uncommitted changes or device behavior |
| 2026-07-10 independent audit | Full UI suite | 8/80 passed; 68 failures shared the first-pet bootstrap/accessibility identity | Historical pre-repair evidence; it proves the old shared bootstrap failure, not that the visible first-pet entry was absent or that the current fast gate is red |
| 2026-07-10 UI gate recovery | First-pet stability plus a post-repair full UI run | First-pet smoke passed 10/10; the full run executed 81 tests, with 34 passed and 47 failed across roughly 13 root-cause clusters | Historical full-suite checkpoint, now triaged by the 2026-07-11 closure. It remains the newest full-suite run and is not a green 81/81 result. |
| 2026-07-10 privacy/document repair | OS backup exclusion, delete-all semantics, public identity, permission localization, and rules/status consolidation | Changed-file/static audits passed; 14 targeted tests passed with 0 failures; Debug simulator build succeeded | Local implementation evidence only; OS backup behavior, signed capability identity, and release-device paths still require TFU-20260709-001 |
| 2026-07-10 atomic restore repair | Strict manifest/media preflight and one SwiftData transaction without nested saves | 24 unique targeted unit regressions passed; final post-change atomic/plant run passed 7/7; release-data-safety audit and Debug simulator build passed | Repository P0 is closed locally; process termination, low-storage, and signed-device behavior remain separate device evidence |

## Validation Ladder

1. `git diff --check` and syntax/manifest checks.
2. `scripts/dev-check-changed.sh` for the changed-file recommendation.
3. Risk-specific audits and targeted unit tests.
4. `scripts/build-debug-fast.sh` for compiler/runtime/persistence/privacy changes.
5. Full module/release gates only at an appropriate handoff.
6. Physical-device, signed capability, backup/restore, energy, location, Health,
   notification, and accessibility checks remain separate evidence.

## Phase Overview

| Area | Status | Current note |
| --- | --- | --- |
| Product and documentation authority | 🟢 | Authority is consolidated and the D17 Pet-first implementation now matches the product source of truth. |
| Privacy and delete-all contract | 🟡 | OS backup exclusion, automatic-backup/Reset generation fencing, and post-commit Human Note attachment deletion are implemented and locally verified; signed-device backup evidence remains external. |
| Backup restore | 🟢 | Strict bounded preflight rejects malformed identities, dates, duplicates, required relations, and media; one SwiftData transaction rolls back every injected phase/save/cancellation failure before publishing defaults or notifications. |
| Unit/static baseline | 🟡 | Current privacy and restore repairs passed targeted unit/static gates and Debug simulator builds; this does not replace the broader dated baseline or nightly full-suite depth. |
| UI automation | 🟢 | D17 Pet-first smoke covers no-Human care/reward/Oasis, production overlays, and accessibility semantics; the clean-install path passed 10/10 relaunch-isolated repetitions with a 29.97-second median. The historical 47 failures remain mapped to 14 root-cause clusters. The full 83-test suite was not rerun and is not claimed green. |
| Domain data validation | 🟡 | Invalid expense values need a service/restore invariant. |
| Store recovery identity | 🟢 | All automatic production opens target one primary identity; migration/default-open failure, disk-full recovery, repeated operation, relaunch persistence, fail-closed startup, and retry are covered locally. |
| Accessibility/runtime policy | 🟡 | Permission-localization coverage is implemented locally; Reduce Motion semantics and device assistive checks remain. |
| Device/OS product scope | 🟡 | Minimum iOS and iPad launch support require an approved release decision and matching evidence. |
| Simulator manual coverage | 🟡 | Broad historical coverage exists; remaining depth is non-blocking P2. |
| Physical-device acceptance | 🟡 | Notification, Memorial, HealthKit, signed Release, backup, location, energy, and accessibility checks remain open. |
| CloudKit/Family | ⚪ | Future-only; Solo capability profile remains closed. |

## Active Module Pointers

| Surface | Follow-up | Required evidence |
| --- | --- | --- |
| Expense invariant | TFU-20260710-007 | Domain/restore rejection of zero, negative, NaN, and infinity |
| Reduce Motion | TFU-20260710-008 | Full/efficient/minimal policy tests plus core-flow device acceptance |
| Supported device matrix | TFU-20260710-009 | Approved iOS/iPhone/iPad scope, signed Archive, and oldest-device smoke |
| Future CloudKit live apply | TFU-20260614-014 | Two-device shared-zone conflict/delete proof after capability enablement |
| Memorial | TFU-20260612-017 | Real-device UI and notification acceptance |
| Notifications | TFU-20260612-016 | Real-device delivery/action/privacy acceptance |
| Human Workout | TFU-20260706-001 | Real HealthKit permission/read/import/revocation evidence |
| Solo signed Release/public identity | TFU-20260709-001 | R1-R6, verified App Store Apple ID/storefront, OS backup exclusion, and energy/location paths |
| Pet GUI depth | TFU-20260629-004 | Remaining release-relevant negative/stale-route paths |
| Long-language layouts | TFU-20260612-020 | German/max-Dynamic-Type dense-screen sweep |
| Concurrency/global lifecycle | TFU-20260710-010 | Incremental strict-concurrency, task cancellation, and DI proof |
| Maintenance/Home invalidation | TFU-20260710-011 | Bounded work and measured scoped-invalidation migration |

## Recent Validation Snapshots

| Date | Scope | Result |
| --- | --- | --- |
| 2026-07-11 | TFU-20260710-006 primary-store identity and test-lane repair | Closed locally. Every automatic production attempt now uses the same primary SwiftData store identity: first with the migration plan, then without it. If both opens fail, startup mounts a non-writable recovery shell with Retry and Support instead of silently creating a second disk store or an in-memory writable session. Fault-injected failure, recovery/retry, repeated disk-full behavior, and real cross-launch persistence tests passed 9/9 under `OhanaUnitTests`; the startup fail-closed/retry user path passed 1/1 under `OhanaUITests`. UI shard completeness passed with 83 tests assigned exactly once. Final artifacts: `.build/TestResults/2026-07-11/tfu-006-store-identity-unit-postformat.xcresult` and `.build/TestResults/2026-07-11/tfu-006-store-recovery-ui-final.xcresult`. The full Unit and 83-test UI suites were not rerun because this closure uses risk-targeted lanes. |
| 2026-07-11 | TFU-20260710-005 D17 Pet-first implementation | Closed locally. Onboarding now requires the first Pet, then opens the Pet quick-weight entry for one persisted care fact, grants the deterministic one-time starter gift to the active Human wallet when present or the Pet wallet otherwise, and exposes Oasis Lv0 without requiring or silently creating a Human. Human name is required only when a Human is later added; gender and birthday default to absent. Targeted onboarding, starter-gift, member-lifecycle, reset, and route tests passed 25/25; the handoff regression suite passed 9/9. The D17 clean-install UI path passed 10/10 relaunch-isolated repetitions with median 29.97 seconds, mean 30.61, and range 29.03–32.93 seconds. Production-overlay and accessibility variants passed; later optional-Human creation passed, and the legacy Human-fixture first-release smoke passed. `scripts/dev-check-changed.sh`, UI V4, accessibility, localization, release-data-safety, smoothness, route-first-frame, runtime, economy, lifecycle, shard, and diff gates passed. Primary stability artifact: `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.11_10-03-07-+0200.xcresult`. Signed-device touch latency, VoiceOver traversal, energy, and permission-dialog acceptance remain physical-device work. |
| 2026-07-11 | TFU-20260710-004 UI smoke closure | Closed for the repository-local gate. The current fast release smoke passed 3/3, covering first-pet creation without and with production overlays plus the first-pet accessibility action contract. The first-pet path then passed 10/10 repetitions with App relaunch enabled; the xcresult reports ten passed repetitions with an average duration of 39 seconds. The historical 47 failures are individually mapped into 14 root-cause clusters, with representative Human, Pet, Calendar, walk, litter, health, hygiene, feed, Plant, Settings, Daily Streak, profile, and quick-menu reruns recorded in `docs/audits/2026-07-11/UI_SMOKE_GATE_CLOSURE.md`. A confirmed Settings `LazyVStack` layout loop was removed; Plant reminder and bulk-edit routes passed afterward. Artifacts: `.build/TestResults/2026-07-11/ui-release-smoke-v3.xcresult`, `.build/TestResults/2026-07-11/first-pet-stability-10x.xcresult`, and the focused bundles listed in the closure report. The full 81-test suite was not rerun, so no 81/81 claim is made. Physical VoiceOver traversal remains true-device acceptance. |
| 2026-07-10 | TFU-20260710-004 UI smoke recovery | Historical checkpoint, superseded by the 2026-07-11 closure row. First-pet smoke passed 10 consecutive runs. The next full UI run executed 81 tests: 34 passed and 47 failed, clustered into roughly 13 root causes rather than one shared bootstrap failure. Recording inspection confirmed Daily Streak visibly opened, so that failure was a stale selector/assertion rather than a route failure; its revised selector had not yet been rerun at this checkpoint. The Calendar flow progressed past the former duplicate `Done` ambiguity, but its long CRUD rerun was interrupted after exceeding the short validation budget and was not counted as pass/fail. Three targeted route/rail policy unit tests passed; one selector was initially mistyped and executed zero tests, then was corrected and passed in a separate run. VoiceOver order was unverified at this checkpoint because the available runtime inspection exposed no usable accessibility tree. Full-suite artifact: `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_21-35-04-+0200.xcresult`; 10-run first-pet artifact: `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_18-54-32-+0200.xcresult`; policy artifacts: `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_23-58-26-+0200.xcresult` and `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_23-59-40-+0200.xcresult`. |
| 2026-07-10 | TFU-20260710-003 strict and atomic backup restore | Closed locally. Required versions, identities, dates, duplicates, relations, media metadata/content, and bounded sizes are validated before live mutation. Restore now requires a clean context and uses one SwiftData transaction with autosave disabled and no nested saves; defaults, notifications, projections, and plant reminder side effects publish only after commit. Fault injection at all six phases, transaction-save failure, cancellation, malformed/oversized/tampered input, repeated idempotent restore, localization, and 17 existing backup compatibility regressions passed 24/24 unique targeted tests. The final post-overlay atomic/plant run passed 7/7. `git diff --check`, `scripts/dev-check-changed.sh`, release-data-safety, and `scripts/build-debug-fast.sh` passed. Artifacts: `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_16-58-14-+0200.xcresult`, `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_17-03-22-+0200.xcresult`, and `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_17-08-37-+0200.xcresult`. Process termination, low-storage, and signed-device behavior are not simulator-proven and remain part of device/reliability acceptance rather than this closed repository P0. |
| 2026-07-10 | TFU-20260710-002 Human Note attachment lifecycle | Closed locally. Note deletion now removes only post-commit unreferenced files; Human deletion clears owned/orphan files while preserving surviving shared references; Reset removes the entire managed root only after the SwiftData commit. Injected-save rollback, repeated-delete, shared-reference, Note/Human/Reset, original command, and automatic-backup/Reset regressions passed 18/18 with 0 failures. `scripts/dev-check-changed.sh`, release-data-safety, UI V4, accessibility, localization, smoothness, route-first-frame, runtime, lifecycle, and status-ledger gates passed; `scripts/build-debug-fast.sh` succeeded. Artifact: `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_16-33-30-+0200.xcresult`. Filesystem behavior is simulator-local; signed-device backup inspection remains TFU-20260709-001. |
| 2026-07-10 | TFU-20260710-001 automatic backup + Delete-All Reset | Closed locally. One shared service now owns the run task, generation checkpoints and managed-file cleanup; Settings awaits the coordinated Reset. Deterministic non-cooperative-export, in-flight-write, cleanup-failure and new-generation tests passed. The combined targeted run passed 25 tests with 0 failures; `scripts/dev-check-changed.sh`, release-data-safety, architecture and runtime audits passed; `scripts/build-debug-fast.sh` succeeded. Artifact: `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_16-04-06-+0200.xcresult`. Real iCloud Drive timing remains part of TFU-20260709-001, not this repository P0. |
| 2026-07-10 | Current documentation/privacy repair | `git diff --check`, manifest/plist syntax, status-ledger, governance, agent/skill, release-data-safety, strict localization, audit-fixture, and `scripts/dev-check-changed.sh` gates passed. `LocalBackupExclusionPolicyTests`, `AppResetServiceTests`, and `SettingsRouteContainerTests` passed 14/14 with 0 failures. `scripts/build-debug-fast.sh` succeeded for the iPhone 17 simulator. Test artifact: `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_15-25-45-+0200.xcresult`. |
| 2026-07-10 | Independent Phase A-D audit | Confirmed 3 release-blocking code findings, one broken UI gate, and the D17 implementation conflict; generated the dated package under `docs/audits/2026-07-10/`. |
| 2026-07-10 | Pre-audit unit/static baseline | See the archived pre-audit ledger for exact commands and artifact paths; do not reuse it as proof for this worktree. |

## Update Rules

- This file answers only: current release gate, current phase, latest high-signal
  validation, and where the active work lives.
- Open work belongs in `docs/task-follow-ups.md`; this file points to it.
- Keep detailed command output and old snapshots in dated audit/archive files.
- Never turn a static/build result into a runtime, device, cloud, energy, or App
  Store claim.
- Update this dashboard only after durable status changes, then run
  `scripts/audit-doc-status-ledgers.sh`.
