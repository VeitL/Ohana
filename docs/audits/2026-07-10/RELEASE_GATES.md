# Ohana Release Gates

> Baseline: `4d434d5354efdfb0eb7864cadad9ccf3df3825b5`
>
> Date: 2026-07-10
>
> Scope: Solo 1.0, local-first, CloudKit/Family capabilities disabled
> This file classifies release risk; it does not authorize implementation or publication.

## Decision

- **Internal development:** proceed.
- **Controlled internal TestFlight using synthetic/non-sensitive data:** possible only after a signed Release build and the minimum smoke checklist; it is not evidence of App Store readiness.
- **External TestFlight with real personal/health data:** blocked by `SEC-001`, `SEC-002`, `SEC-003`, and `DATA-001`.
- **App Store submission:** not ready. The four blockers, production identity/metadata, signed Archive, and mandatory device validation must close first.

Classification is based on user harm, privacy/data loss, reachability, recoverability, market value, and proof quality—not severity labels alone.

## BLOCKER

| Finding ID | Classification reason | Evidence | User / technical impact | Risk if deferred | Latest stage | Acceptance criteria |
|---|---|---|---|---|---|---|
| `SEC-001` | The control gap is confirmed even though the actual device-backup payload is unverified. Human-health data resides under Application Support and no backup-exclusion control is present; current public policy makes a stronger promise. Apple currently states that personal health information may not be stored in iCloud. | `SharedModelContainer`, `HumanNoteAttachmentStore`, repository-wide absence of `isExcludedFromBackup`; [Apple App Review 5.1.3](https://developer.apple.com/app-store/review/guidelines/), [Foundation backup exclusion](https://developer.apple.com/documentation/foundation/urlresourcekey/isexcludedfrombackupkey) | Privacy promise may be inaccurate; sensitive store/attachments may enter regular device backup. | App Review rejection, privacy breach of trust, forced post-release data-policy change. | Before any external TestFlight containing real data. | Every sensitive store, sidecar, fallback store, and Human Notes root has a verified exclusion policy after creation/migration/fallback; automated URL-resource tests pass; real-device backup/restore confirms no personal-health payload; public policy and App Store privacy answers match behavior. |
| `SEC-002` | A reachable race exists between in-flight automatic backup and Reset. `isRunning` prevents duplicate backup only; Reset uses an independent cleaner and cannot cancel/wait for an old run. | `AutomaticBackupService.runNow`, `AppResetService.resetInternal` | A user can be told deletion completed while an old-generation backup is recreated afterward. | Explicit deletion intent is violated; stale status can overwrite reset status. | Before external TestFlight. | Deterministic interleaving tests cover export/reset/write orders; Reset cancels and awaits the shared coordinator; old generations cannot write files or mark success after Reset returns; timeout and post-reset new backup are correct. |
| `SEC-003` | Successfully saved Human Note attachments have no deletion owner. Cleanup exists only for failed/pending saves, not note deletion, Human deletion, or Reset. | `HumanNoteAttachmentStore.deletePendingAttachments`, `HumanNoteCommands.deleteNote`, `PhysicalDeletionService`, `AppResetService` | Private photos/documents remain after the corresponding record is deleted; storage grows invisibly. | Incomplete deletion promise and orphan-file accumulation. | Before external TestFlight if attachments are reachable. | Note, Human, and Reset deletion remove only unreferenced owned files after database commit; shared-reference and save-failure cases do not lose live files; tests inspect the file system; reset leaves no Human Notes root. |
| `DATA-001` | Restore commits multiple checkpoints, then can still throw; required UUID/date fields are widely defaulted to random IDs/current time. Failure can therefore mutate the live store and silently alter identity/history. | `DataBackupManager.applyBackup`, `saveRestoreCheckpoint`, `DataBackupManager+Decode` | A safety feature can leave partial, duplicated, or incorrectly dated data while reporting failure. | Irrecoverable relationship corruption and loss of confidence in backups. | Before external TestFlight if Restore remains exposed. | All required IDs/dates/relationships are strictly validated before the first live write; restore is atomic via staging or an equally strong transaction boundary; every injected failure preserves the pre-restore store and defaults; duplicate restore is idempotent; disk/memory budgets and cancellation are tested. |

## SHOULD FIX BEFORE RELEASE

| Finding ID | Classification reason | Evidence | User / technical impact | Risk if deferred | Latest stage | Acceptance criteria |
|---|---|---|---|---|---|---|
| `TEST-001` | The visual first-pet entry exists, but 68 UI tests fail at the same XCUI identity and setup accepts an ambiguous post-save state. This is a release-proof failure, not a confirmed product-entry bug. | 8/80 UI tests passed; targeted rerun and recording; `OhanaUITests.openFirstPetCreationFromTodayFocus`, `createMember`, `TodayFocusCard+ContentCards` | Major routes are hidden behind one broken bootstrap; real regressions are indistinguishable from harness failures. | A release can regress onboarding, care, calendar, or deletion without a usable automated smoke signal. | Before RC sign-off; a controlled internal TestFlight may temporarily use a documented manual smoke run. | First-pet test passes 10 consecutive times; helper requires a stable post-save marker; accessibility role/reading order remains correct; full suite has no common bootstrap failure and residual failures are individually triaged. |
| `RULE-002`, `MARKET-001` | Authoritative product rule says pet-first in 90 seconds, but current code requires four intro pages and a Human profile first. This is a product-implementation conflict and activation gap, not a safety bug. | `product-foundation.md` D17; `OnboardingView.introPageCount = 4`, `FlowStep.profile`; Finch/Planta/Reminders public first-value patterns | Users work before receiving the promised pet-care value. | Lower activation and an App Store promise that the running product does not meet. | Before public 1.0 unless the Product Owner explicitly changes D17. | Ten clean installs complete first pet + first care + saved fact + first reward in median <=90 seconds; Human can be deferred; interruption/relaunch is idempotent; no sensitive permission blocks the path. |
| `MARKET-006`, `DOC-004` | Production identity is inconsistent: project version 1.0, Settings text `v4.5.0`, unverified review Apple ID, and no confirmed DE/US page for the Bundle ID. | Xcode settings, `SettingsView+MainSections`, Apple Lookup on 2026-07-10 | Users may not know which Ohana app/version they are using or reach the correct review page. | Broken ratings/support path, same-name confusion, Store rejection or metadata correction. | Before uploading the release candidate. | About reads `CFBundleShortVersionString`; Apple ID/review link matches App Store Connect; Bundle/developer/support/privacy URLs cross-check; screenshots only show shipped capabilities. |
| `A11Y-001` | Reduce Motion maps to an efficient mode and some callers only inspect broad motion allowance. Runtime harm is unverified, but core care/reward motion needs a deterministic minimum mode. | Runtime policy and callers; static accessibility audit alone cannot prove motion behavior | Motion-sensitive users may still receive repeated or spatial animation. | Accessibility dissatisfaction and inconsistent energy policy. | Before App Store RC if affected flows are high-frequency. | Full/efficient/minimal behavior tests pass; Reduce Motion removes nonessential spatial/repeating motion; reward feedback remains understandable without animation. |
| `A11Y-002` | App registers nine languages but system/bundle localization lists only en/de/zh-Hans; permission rationale coverage is narrower than in-app language coverage. | `LocalizationSettings`, `Info.plist`, localized resources | A user can see a localized app and an unexpected-language permission dialog. | Trust loss and incomplete localization claim. | Before claiming all nine languages in Store metadata. | Each marketed locale has localized usage descriptions and long-text smoke evidence, or the Store language list is intentionally narrowed. |
| `LOGIC-003` | UI validation is not a domain invariant; backup/rehydrate or alternate command paths can admit non-positive or non-finite expense values. | Expense domain/restore paths | Invalid totals and charts can persist despite a correct form. | Corrupt aggregates and difficult cleanup. | Before 1.0 if expense entry is shipped. | Domain and restore boundaries reject NaN, infinity, zero/negative values according to product rule; tests cover locale decimal inputs and corrupt backups. |
| `DOC-002`, `DOC-003` | Active status and capability documents currently understate the newly confirmed reachable risks and contain old capability language. Static ledger governance still passes, showing it checks structure rather than semantic truth. | `task-follow-ups.md`, `testing-progress.md`, `permission-rationale-draft.md`, `privacy-ownership.json`; current audit rerun | Future agents can treat the project as release-ready or revive disabled capability assumptions. | Repeat regressions and misleading release decisions. | In the same release batch that closes blockers. | Status ledgers contain all open release findings; capability docs match Solo entitlements/profile; governance audit adds semantic fixtures for required release categories. |

## CAN SHIP AND FIX LATER

| Finding ID | Why it can wait | Evidence / impact | Latest reasonable stage | Acceptance criterion |
|---|---|---|---|---|
| `CONC-001`, `CONC-002` | Strict-concurrency diagnostics are real, but current Swift 5 build succeeds and no runtime corruption is proven. | Actor/Sendable/ModelContext warnings; migration risk rather than demonstrated incident. | Before Swift 6 language-mode migration. | Boundary returns IDs/value DTOs only; focused strict-concurrency build is clean for touched modules. |
| `ARCH-001` | Dual instance DI/static registries reduce lifecycle clarity but current architecture audits and 1509 unit tests pass. | Maintenance/test isolation cost. | Incrementally when each registry is touched. | New service dependencies use `AppServices`; registry use count decreases with behavior tests intact. |
| `PERF-001` | Cursor/budget/cancellation is desirable for large maintenance work, but no dense-data runtime regression has been measured. | Static scale risk in backup/restore/reset. | After correctness blockers, before large public data sets. | Dense-data budget, cancellation, Low Power, and memory-pressure tests meet documented limits. |
| `PERF-002` | Scoped Home invalidation and covered-surface gating already exist; legacy broad revision remains only a migration tail. | Potential unnecessary refresh, not confirmed user-visible jank. | Incremental performance phase. | Remaining broad consumers migrate only after measurement; no refresh while covered; dismiss coalesces one refresh. |
| `CONC-003`, `CONC-004` | Registry/task ownership is imperfect, but current safeguards reduce immediate risk and no incident is reproduced. | Test isolation, late callback, route-lifetime risk. | When notification/QuickFeed modules are next changed. | Instance injection and route-owned cancellable tasks with leave/reopen tests. |
| `ARCH-002` | File size alone is not an architecture failure. | 40 files >1000 lines; only split when responsibilities or change diffusion justify it. | Opportunistic. | A split is accepted only with a concrete owner/testability benefit. |
| `TEST-002` | Source-string assertions are useful guardrails even though they are not behavior tests. | About 32 files. | Replace gradually when behavior tests exist. | No source assertion is removed without equivalent behavior/audit protection. |
| `CONC-005` | Toast cleanup race has limited user impact and no data consequence. | Stale task can clear a newer toast. | Next feedback/toast change. | Generation-scoped cleanup test. |

## PRODUCT DECISION

| Finding ID | Decision required | Evidence | Recommended default | Deadline / acceptance |
|---|---|---|---|---|
| `SEC-004` | Does Reset delete the 45-day local anti-abuse budget history, or must the UI/policy disclose retention? | `AppResetService` intentionally retains `EconomyBudgetUsageEvent`. | For a literal “delete all,” delete it and prevent reset farming by a non-personal device-local cooldown or remove the absolute phrase. | Decide before final privacy/delete copy; code, UI and policy use one definition. |
| `RULE-001`, `DATA-004` | What does “complete export” mean when restricted backup intentionally omits human health, free-text tasks, and economy sidecars? | Restricted export code is more privacy-safe than the absolute documentation. | Define a manifest listing included/excluded categories; do not loosen the restricted package merely to satisfy wording. | Decide before Store metadata and support documentation. |
| `RULE-002` | Keep authoritative pet-first behavior or revise the product foundation to Human-first. | D17 conflicts with current code/tests. | Keep pet-first; defer Human profile. | Before onboarding PR acceptance. |
| `COMPAT-001` | Minimum iOS and actual iPad support. | Deployment target is iOS 26.2; support matrix marks action required. | Choose based on reachable users and API fallback cost; do not lower the setting without availability audit. | Before App Store target/device metadata and RC matrix. |

## MARKET EXPERIMENT

| Finding ID | Hypothesis | Why code cannot prove it | Minimum experiment | Decision threshold |
|---|---|---|---|---|
| `MARKET-003` | A tighter Today Care Board increases daily completion without making Home feel like a super-app. | Existing Today Focus is technically capable; the remaining question is comprehension and prioritization. | Five task-based usability sessions with due/overdue/failed states; instrument completion only after privacy approval. | Users identify next action and previous completion without opening detail; no increase in wrong-subject completion. |
| `MARKET-007` | “Who did what, when” is sufficient willingness-to-pay for Family. | Competitors show need signals, not Ohana conversion. Family is not shipped. | Concept test with 5–8 multi-caregiver households before CloudKit enablement. | Repeated willingness to pay for duplicate-care prevention, not generic chat/features. |
| `MARKET-009` | Cross-life plant care increases retention without diluting pet-first activation. | Code depth does not prove market demand. | Show pet-first onboarding and Lv.4 plant unlock concepts to current target users. | Pet task comprehension remains intact and plant value is understood without AI claims. |
| `MARKET-005` | A privacy-safe Widget/App Intent materially reduces missed logging. | Public competitor support and system integration show plausibility, not Ohana usage. | Prototype read-only next-care Widget after blockers; measure open/complete intent in dogfood. | Meaningful repeat use without lock-screen privacy complaints or duplicate facts. |

## MANUAL VALIDATION

These are validation gates, not newly invented product findings.

| Validation ID / related finding | Why automation here is insufficient | Shortest valid procedure | Expected result | Release effect |
|---|---|---|---|---|
| `VERIFY-001` / `SEC-001` | Simulator cannot prove physical-device iCloud Backup contents. | On a real signed build, create Human health data and note attachment; enable device backup; inspect backup/restore on a second clean device/account test environment. | No prohibited personal-health store or attachment is restored from OS backup; approved restricted file backup behaves as documented. | Blocker. |
| `VERIFY-002` / `SEC-002` | Real iCloud Drive latency and account state can differ from injected unit tests. | Start automatic backup, trigger Reset at controlled phases, lock/background/reopen, inspect iCloud Drive and status. | No old-generation package reappears; pending cleanup is visible and retryable. | Blocker. |
| `VERIFY-003` / `DATA-001` | Disk pressure and large media behavior need hardware/storage reality. | Restore valid/corrupt/large backup under low storage; cancel/background during staging. | Failure leaves prior data unchanged; success is complete; user receives actionable error. | Blocker. |
| `VERIFY-004` / `TEST-001`, `A11Y-*` | XCUI success does not prove VoiceOver order, focus, touch target, or subjective motion comfort. | VoiceOver through onboarding, first pet, quick care, failed save, PDF share, delete; maximum Dynamic Type and Reduce Motion. | Logical reading/focus order, no trapped modal, all actions named, state not color-only, motion safely reduced. | Should fix before release. |
| `VERIFY-005` / release baseline | Signing/profile/entitlement expansion cannot be proven by unsigned simulator build. | Produce signed Release Archive; inspect exported entitlements, privacy manifest, usage strings, bundle version, background modes. | Only Solo capabilities are present; bundle/version/profile match App Store Connect; archive validates. | Blocker for TestFlight/App Store, not a source-code Finding. |
| `VERIFY-006` / runtime blind spots | HealthKit, notification actions, Always Location and lock-screen walk depend on real services/sensors. | Execute R1–R6 on a real iPhone, including permission changes, notification action, 30–60 minute locked walk, Low Power and relaunch. | No lost fact, stale success, unauthorized background work, or unacceptable energy use. | Blocker for App Store; controlled internal TestFlight may limit scope. |
| `VERIFY-007` / performance | Simulator launch and static audits cannot establish real-device energy/memory. | Release build: 10 rapid cares, two-minute covered sheet, 500-image scroll, memory warning, thermal/Low Power observation. | No hang/crash, bounded memory, hidden surfaces inert, one coalesced refresh after dismiss. | Should fix if threshold fails. |
| `VERIFY-008` / Store | App Store Connect is not in the repository. | Verify app name/subtitle, Apple ID, support/privacy URL, age rating, privacy labels, screenshots, review notes and Storefront pricing. | Metadata matches shipped behavior and German/US values are not mixed. | Blocker for App Store submission. |

## NOT WORTH DOING

| Item / related finding | Reason |
|---|---|
| Whole-app rewrite to TCA, Redux, Clean Architecture, or a new persistence framework (`ARCH-001/002`) | Existing domain boundaries, typed routes, V85 migrations and 1509 passing unit tests are valuable. The release risks are localized lifecycle defects. |
| Mass splitting every >1000-line Swift file (`ARCH-002`) | Line count alone does not prove modification diffusion; it would create review noise before data-safety fixes. |
| Enable CloudKit/Family to match competitors (`MARKET-007`) | It expands privacy, conflict, APNs and multi-device risk before Solo is trustworthy. Capability gates should remain closed. |
| Add ads/tracking, paid Coconut, FOMO, or basic-care paywalls | Conflicts with Ohana’s trust-based positioning and the strongest differentiation. |
| Add AI diagnosis before core release safety (`MARKET-009`) | Medical/plant diagnosis creates new correctness and review risk without solving today’s release blockers. |

## Gate Exit Checklist

App Store status can move to **Ready for Submission** only when all are true:

1. `SEC-001`, `SEC-002`, `SEC-003`, and `DATA-001` are closed with automated and required real-device evidence.
2. A signed Release Archive validates with the production profile and Solo entitlements.
3. `TEST-001` no longer causes a common bootstrap failure; a small release smoke suite is green.
4. Privacy policy, App Store privacy answers, deletion/export wording, version, Apple ID, support and screenshots match the binary.
5. R1–R6 true-device validation, VoiceOver core path, notification actions, HealthKit, and locked background walk are recorded.
6. Any failure discovered in manual validation is either fixed or explicitly reclassified here with an accountable release decision.
