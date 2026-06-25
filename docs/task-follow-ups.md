# Task Follow-ups

> **Release-bar role (2026-06-15)**: This file is the **post-launch fix backlog**.
> Per the playbook "发布门槛 (Release Bar)", the only thing that blocks first
> release is **"P0 AND first-release-reachable"** cleared to zero. Everything else
> — P1, P2, first-release-unreachable (CloudSync `.none` / online / behind a
> feature gate / 0.01% edge paths) — is logged here, ships with the app, and is
> scheduled by severity across post-launch versions (1.0.1, 1.1, 1.x). Tag each
> entry with severity (P0/P1/P2) and reachability (reachable / unreachable) so the
> release-bar scan can filter the one blocking quadrant quickly.

This document tracks concrete follow-ups discovered while finishing a task when
they cannot or should not be completed in the same turn. Keep it short and
actionable; long-term product ideas belong in planning docs instead.

## How To Use

- Add an entry only when a completed task leaves a real blocker, external action,
  cross-scope repair, validation gap, or follow-up that should not be forgotten.
- For the current repository task, a concrete accepted follow-up recorded here
  counts as handled even when the future owner-facing status remains `Open`.
  Keep the blocker, next step, and close condition explicit so the deferred work
  can be resumed without rediscovery.
- When a task cannot be completed locally because it requires a paid Apple
  Developer account, provisioning access, CloudKit Dashboard access, App Store
  Connect access, or physical devices that are not currently available, recording
  the concrete blocker, next step, and close condition here counts as completing
  the current repository task. The follow-up remains for the future external
  validation/action owner.
- Prefer one entry per actionable outcome. Include the blocker and the exact
  next step, not just a vague reminder.
- Close entries by changing `Status` to `Done` and adding a short `Closed` note.
- If there is no meaningful follow-up after a task, do not add noise here.

## P1 Backlog Triage (2026-06-25)

This section prevents the Open P1 count from overstating live engineering work.
The individual TFU entries below remain the source of truth; this summary is a
planning index for the next repair/review pass.

| Bucket | TFUs | Current meaning | Recommended next move |
| --- | --- | --- | --- |
| Review-gate / likely implemented locally | TFU-20260615-001, TFU-20260614-019, TFU-20260614-018, TFU-20260614-017, TFU-20260614-016, TFU-20260614-015, TFU-20260614-013, TFU-20260612-014 | These are still counted as Open P1 because their close conditions require broader gate, push/CI, or a fresh pure review. Their entries already record local repair evidence or local hard-gate evidence. | Do a dedicated pure-review closure pass: rerun the relevant current-code guards, inspect CI for the pushed head, and close or split only the findings that are still real. Do not treat all eight as eight fresh code projects until review disproves the local evidence. |
| Actual code / product-policy work still likely needed | TFU-20260612-019 | Human memorial read-only boundaries may be partly or fully covered by TFU-20260614-019, but the tracker has not yet proven that the human-specific Members route/command matrix is closed. | Verify overlap against TFU-20260614-019 tests. If covered, close TFU-019 as duplicate/subsumed; if not, keep it as one focused human-members repair. |
| Deferred 1.x / first-release-unreachable code work | TFU-20260614-014 | CloudSync live-apply delete-wins, parent lifecycle, and natural identity are real architecture work, but the entry explicitly says it is unreachable while `cloudKitDatabase: .none`. | Keep visible as CloudKit 1.x work; do not mix it into first-release P1 burn-down unless CloudKit is enabled. |
| External/manual validation | TFU-20260612-017, TFU-20260612-016 | These require a real device notification/UI checklist. Repository code cannot close them alone. | Run the GAP-9 and GAP-6 manual checklists on a physical device; any discovered defect should become a new scoped repair TFU. |

Operational read: the raw Open P1 count is 12, but only 1-2 appear to be active
repository code repairs before a fresh review. Most of the number is review-gate
debt, first-release-unreachable CloudSync 1.x work, or real-device validation.

## Open Items

### TFU-20260623-001 - Split Home quick-action pure state helpers from MainActor defaults

- Status: Open - local legacy-ledger guard verified; pending broader gate,
  push/CI, and fresh pure review before Domain maturity closure.
- Priority: P2 (compiler-migration risk; first-release-unreachable runtime)
- Area: Home / Read Model / Quick Actions / Swift actor isolation
- Source task: Home read-model refactor to remove main-thread compatibility
  reads; Codex, 2026-06-23.
- Blocker: The Home read-model payload no longer carries SwiftData object arrays
  or performs `mainContext` compatibility fetches after actor refresh, and the
  Home targeted tests pass. However the compiler still warns that
  `HomeInteractionSnapshotBuilder` calls legacy default-MainActor static helpers
  in `FocusHomeReminderDeepLinkRouter`, `ExpandedQuickActionLogic`, and
  `PrivacyService` while shaping pure interaction status. These are not broad
  main-context fetches, but they will become harder blockers under stricter Swift
  isolation.
- Next step: Extract actor-safe, nonisolated pure route/status calculators for
  Home read-model use, or mark the existing pure helper subset nonisolated only
  after its feed/water/privacy dependencies have matching nonisolated value
  APIs. Do not move actor refresh work back through `MainActor`.
- Close condition: The same targeted command
  `scripts/test-simulator.sh -only-testing:OhanaTests/HomeReadModelStoreTests -only-testing:OhanaTests/HomeSnapshotBuilderTests -only-testing:OhanaTests/HomeRouteCoordinatorTests`
  passes with no `HomeInteractionSnapshot.swift` actor-isolation warnings, and
  the Home read-model source guard still rejects `compatibilitySource`,
  `payload.source`, and `container.mainContext`.

### TFU-20260617-001 - Add a LocalDevice UI-test scheme for first-release smoke

- Status: Done
- Priority: P1 (release-process validation gap; not an app runtime P0)
- Area: Release / Phase 9A / Real Device UI Smoke / Signing
- Source task: Complete first-release P0 startup/Home/Oasis/Settings closure;
  Codex, 2026-06-17.
- Blocker: The first-release UI smoke is green on the fixed iPhone 17 simulator
  and `Ohana Local Device` now builds, installs, launches, and reaches
  `bootstrap.payload-set` on `Guanchen’s iPhone`, but the same smoke cannot yet
  run as physical XCTest automation. The normal `Ohana` Debug scheme requires a
  provisioning profile for `com.guanchen.li.Ohana` with Push Notifications and
  iCloud capabilities, which the current personal development team cannot
  create. The `LocalDeviceDebug` configuration uses the safe local bundle id and
  empty local entitlements, but test targets are not configured for that
  configuration (`PRODUCT_BUNDLE_IDENTIFIER`, `SWIFT_VERSION`, and test
  `Info.plist`/generated plist settings are missing).
- Next step: Add a dedicated shared `Ohana Local Device UI Tests` scheme or
  configure `LocalDeviceDebug` for `OhanaTests` / `OhanaUITests`, with signed
  xctrunner bundle ids that do not require unavailable app capabilities. Then
  run:
  `xcodebuild test -project Ohana.xcodeproj -scheme '<local-device-ui-test-scheme>' -destination 'id=00008150-001270342EA3401C' -only-testing:OhanaUITests/OhanaUITests/testFirstReleaseReachableHomeOasisAndSettingsSmoke CODE_SIGNING_ALLOWED=YES`.
- Close condition: The physical-device UI smoke runs on `Guanchen’s iPhone` and
  proves the full first-release path: launch / reset, create first human,
  starter gift, create first pet from Today Focus, switch to Home Oasis, inject
  energy Lv0 -> Lv1, and open Settings without hang or crash.
- Closed: 2026-06-17. `LocalDeviceDebug` test targets were configured for signed
  physical XCTest, and the smoke passed on `Guanchen’s iPhone` with:
  `xcodebuild test -allowProvisioningUpdates -project Ohana.xcodeproj -scheme Ohana -configuration LocalDeviceDebug -destination 'id=00008150-001270342EA3401C' -derivedDataPath /tmp/ohana-device-ui-p0-localconfig -only-testing:OhanaUITests/OhanaUITests/testFirstReleaseReachableHomeOasisAndSettingsSmoke CODE_SIGNING_ALLOWED=YES`.
  Result: `TEST SUCCEEDED`, 1 UI test, 46.921s, xcresult
  `/tmp/ohana-device-ui-p0-localconfig/Logs/Test/Test-Ohana-2026.06.17_13-20-42-+0200.xcresult`.

### TFU-20260616-001 - Trust Local Device profile and start dogfooding install

- Status: Done
- Priority: P1 (release-process external blocker; not an app runtime P0)
- Area: Release / Phase 9A / Local Device Signing / Dogfooding
- Source task: Phase 9A start, Codex, 2026-06-16.
- Blocker: `Ohana Local Device` builds and installs on `Guanchen’s iPhone`
  (iOS 27.0) with Team `567SK733UN` and bundle id
  `com.guanchen.li.Ohana.LocalDevice`, but device launch is denied by iOS:
  the development profile/signature has not been explicitly trusted by the
  user. Build/install evidence:
  `xcodebuild -project Ohana.xcodeproj -scheme 'Ohana Local Device' -configuration LocalDeviceDebug -destination 'id=00008150-001270342EA3401C' -derivedDataPath .build/DerivedData/phase9a-local-device build CODE_SIGNING_ALLOWED=YES`
  PASS, and
  `xcrun devicectl device install app --device 00008150-001270342EA3401C .build/DerivedData/phase9a-local-device/Build/Products/LocalDeviceDebug-iphoneos/Ohana.app`
  installed the app. Launch failed with `RequestDenied` / `Security` /
  "profile has not been explicitly trusted by the user".
- Next step: On the iPhone, trust the developer profile for
  `Apple Development: guanchen.li.119@gmail.com` in Settings, then rerun
  `xcrun devicectl device process launch --device 00008150-001270342EA3401C com.guanchen.li.Ohana.LocalDevice`.
  Once launch succeeds, begin dogfooding only from the installed main build and
  burn down the 91 unchecked real-device/manual items in
  `docs/planning/gap-acceptance-track-list.md`.
- Close condition: The local-device app launches successfully on the iPhone,
  the first dogfooding session is recorded in `docs/testing-progress.md`, and
  at least one Phase 9A real-device checklist pass starts reducing the 91-item
  acceptance debt.
- Closed: 2026-06-16. After the developer profile was trusted on the iPhone,
  `xcrun devicectl device process launch --device 00008150-001270342EA3401C com.guanchen.li.Ohana.LocalDevice`
  succeeded and launched the installed local-device app. The remaining
  real-device/manual acceptance debt is tracked separately in
  `docs/planning/gap-acceptance-track-list.md`.

### TFU-20260615-001 - Close Feeding plan/stock lifecycle and actor-policy gaps

- Status: Open - local repair and module gate verified; closure blocked by
  push/CI and a separate fresh pure review
- Priority: P1
- Area: Domain / Feeding / Memorial / Stock Reminders / CareLedger / Executor Resolution
- Source task: Domain first-release reachable-surface fresh pure review; Codex,
  2026-06-15.
- Blocker: Fresh first-release reachable reviews on 2026-06-15 found and
  reconfirmed P0=0 / P1=1 / P2=0, so Domain cannot be marked 🏁. The Feeding
  plan/stock command family still
  bypasses the member lifecycle and effective-actor policies. `SaveFoodStockCommand.run`
  can mutate pet food tracking fields, create/update `PetFoodRecord`, rebuild stock
  `Event`/`Reminder`, and optionally write `PetExpenseLog` + `CareLedgerEvent`
  for a deceased pet. Its expense path also stores the raw `expensePayerId` in
  both the expense fact and ledger, so an active pet plus deceased/missing payer
  can persist a bad actor instead of the effective active human. Related stock
  and feeding-arrangement commands (`StockReminderSettingsCommand`,
  `CorrectStockCommand`, `DeleteFeedPlanCommand`, `SetMainFoodKindCommand`,
  `FeedMaintenanceCommand.ensureUpcomingPlanReminders`, and `SwitchFeedModeCommand`)
  can still mutate feed settings, plan/reminder state, or materialized feed work
  without an active-writable target guard.
- Next step: Add red tests for deceased pet `SaveFoodStockCommand`,
  stock-reminder settings, stock correction, feed-plan deletion, feed-mode switch,
  and upcoming-plan reminder maintenance: each must no-op with no `PetFoodRecord`,
  `PetExpenseLog`, `CareLedgerEvent`, `Event`/`Reminder`, pet food-setting
  mutation, or success revision. Add active-pet tests where `expensePayerId` is
  deceased/missing/physically deleted and assert `PetExpenseLog` plus
  `CareLedgerEvent` use the same effective actor as the reward/economy policy
  (or unknown/fact-only when no owner is available). Then route this command
  family through one Feeding plan/stock write disposition built on
  `MemberWritePolicy` and `CareFactWritePolicy.executorResolution`; only publish,
  rebuild reminders, or sync expense ledgers after an active-writable result.
- Close condition: Red tests fail before the fix and pass after; targeted
  Feeding/Home/Reminder/economy tests, derived/economy audits, fixture tests,
  `scripts/dev-check-changed.sh`, `scripts/module-exit-gate.sh`, push, and CI
  are green. Then run a fresh Domain pure review and require P0/P1=0 before 🏁.
- Progress: 2026-06-15 repair session added the red tests and fixed the Feeding
  plan/stock command family. `SaveFoodStockCommand`, stock reminders/correction,
  feed record edits/deletes, plan delete, main food kind, maintenance, and feed
  mode switching now no-op for deceased pets through `MemberWritePolicy`;
  stock expense payer fallback uses the command `executorId` through
  `EconomyRewardOwnerResolver` and writes the same effective actor to
  `PetExpenseLog` and `CareLedgerEvent`; QuickFeed executor revision publishing
  consumes typed did-change/no-op results; the stock payer menu filters deceased
  humans. Validation passed:
  `scripts/test-simulator.sh -only-testing:OhanaTests/ManualFeedCommandTests`
  (17 tests),
  `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests`
  (182 tests),
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/CareDerivationExecutorSuccessCharacterizationTests -only-testing:OhanaTests/RecurringFindingsRepairTests -only-testing:OhanaTests/ReminderActionCoordinatorTests -only-testing:OhanaTests/CatCareCommandTests`
  (58 tests), `scripts/dev-check-changed.sh`,
  `scripts/tests/run-audit-fixture-tests.sh`,
  `scripts/audit-economy-boundaries.sh --all`, `git diff --check`, and
  `scripts/audit-derived-state-lifecycle.sh --all` exit 0 with existing
  full-repo review warnings only. 2026-06-15 follow-up repair closed
  TFU-20260615-002 and restored local `scripts/module-exit-gate.sh` PASS; this
  item still waits for push/CI and a separate fresh pure review before Domain
  can be considered for 🏁.

### TFU-20260615-002 - Restore shared walk secondary executor persistence and backup round trip

- Status: Done
- Priority: P1
- Area: Domain / Shared Care / Walks / Backup / Module Gate
- Source task: Domain Feeding plan/stock repair module-exit validation; Codex,
  2026-06-15.
- Blocker: `scripts/module-exit-gate.sh` reaches the full unit suite and fails
  outside the Feeding repair scope. Isolated validation confirms
  `scripts/test-simulator.sh -only-testing:OhanaTests/SharedPetActionRecorderTests`
  fails in `sharedWalkStoresMultipleExecutorsOnSessionLogsAndLedger` and
  `backupRoundTripsSharedSessionExpenseAndWalkFields`: shared walk sessions and
  `PetWalkLog.executorIds` persist only the primary executor, so the secondary
  co-walker is missing from session/log metadata and from backup DTO round-trip
  data.
- Next step: In the shared walk writer path, preserve the accepted secondary
  executor IDs on `SharedCareSession.executorIds`, child `PetWalkLog.executorIds`,
  related ledger/session metadata, and backup encode/decode DTOs. Keep invalid,
  missing, or deceased secondary executors filtered/fallback-safe according to
  the existing shared-care policy.
- Close condition: The two failing SharedPetActionRecorder tests fail before
  the fix and pass after; `scripts/test-simulator.sh -only-testing:OhanaTests/SharedPetActionRecorderTests`
  passes; `scripts/module-exit-gate.sh` passes; then rerun Domain pure review
  before considering 🏁.
- Closed: 2026-06-15. `SharedPetActionRecorder` now keeps shared-walk
  participant `executorIds` separate from the effective primary actor: session
  and `PetWalkLog` rows preserve the secondary co-walker while ledger/reward
  ownership still uses the resolved effective actor. Backup encode/decode
  already round-tripped `executorIdsRaw` once the writer stored it. Updated
  legacy happy-path CareEventService tests to insert a real `Human` executor
  instead of asserting that invalid `"human-1"` should persist as an actor.
  Validation PASS:
  `scripts/test-simulator.sh -only-testing:OhanaTests/SharedPetActionRecorderTests`
  (25 tests) and `scripts/module-exit-gate.sh` (changed audits,
  localization, 876 unit tests + 3 UI template tests) on the iPhone 17
  simulator.

### TFU-20260614-019 - Split memorial-safe content from active-only command writes

- Status: Open - local command/UI membrane evidence verified; pending broader
  gate, push/CI, and fresh pure review before close.
- Priority: P1
- Area: Domain / Memorial / Member Lifecycle / Feature Commands / UI Routes
- Source task: Domain first-release reachable-surface pure adversarial review;
  Codex, 2026-06-14, current commit `24fc54c21`.
- Blocker: 2026-06-14 产品宪法 v1.5 将 D7 改为"照护只读，回忆可写"。
  本轮按新宪法重判：纪念照片、回忆文字、纪念日、悼念笔记本身允许；但纪念内容
  不得进入经济系统、照护事实、提醒、任务、健康趋势、连胜或 Oasis 派生。当前缺
  少服务层的 target write policy，导致 active-only 命令仍可对去世 pet/human 写
  事实或派生：`ExpenseCommandService.recordPetExpense` 会写 `PetExpenseLog` +
  `CareLedgerEvent`；`PetDocumentCommandService.createDocument` 在 cost > 0 时写
  expense + ledger；`InsurancePolicyCommandService.savePolicy/createClaim/updateClaimStatus`
  会写保险、保费/报销 expense 与 calendar event；`PetMedicationPlanCommandService.savePlan`
  会写用药计划和 event/reminder；`PetMilestoneCommandService.createMilestone` 和
  `MomentCommandService.recordMoment` 虽可被解释为纪念内容，但当前会进入奖励/ledger
  纪律；human 侧 `ExpenseCommandService.recordHumanExpense`、
  `WeightCommandService.recordHumanWeight`、`WorkoutCommandService.recordHumanWorkout`、
  `HumanMedicationCommandService` / `HumanMedicationPlanCommandService` /
  `HumanMedicationDoseCommandService`、`HumanHealthMetricCommandService` /
  `HumanHealthReportCommandService`、`HumanWishlistCommandService` 以及带
  `reminderDate` 的 `HumanNoteCommandService.recordNote` 也没有 deceased target
  硬门。UI feature hub 仍只显示 memorial banner/read-only 文案，未把写入型目的地
  和 memorial-safe 目的地区分。
- Next step: 先补入口族红测：去世 pet/human 分别覆盖 pet expense、pet document
  with cost、insurance policy/claim、pet medication plan、milestone、quick moment、
  human expense、human weight/workout、human medication plan/dose、human health
  metric/report、wishlist、human note with reminder；断言 active-only 路径无 fact、
  无 ledger、无 reward、无 event/reminder、无 success revision。另补 memorial-safe
  红/绿测试：PetPhotoAlbum 与纯悼念文字/纪念日允许写入，但不得写 ledger/reward/
  reminder。实现上以统一 `MemberWritePolicy` / memorial disposition 区分
  `.activeOnlyNoOp`、`.memorialContentOnly`、`.activeWritable`，command、executor、
  revision 与 UI route 都消费 typed result。
- Close condition: 新红测先失败后修绿；所有 deceased member 写入入口消费同一个
  typed policy/result，不能靠单个 view 判断；相关 command / route / revision
  入口族测试、derived/economy audits、fixture tests、module exit gate、push 和 CI
  全绿；随后另开首发可达面纯复审，P0/P1=0 才能把 Domain 标 🏁。
- Progress: 2026-06-24 本地证据复核。`MemberLifecycleGateTests` 当前覆盖
  `deceasedFeatureHubsExposeOnlyMemorialSafeDestinations`、deceased pet feed/
  stock/water/care-plan/walk/derived wrapper no-op、deceased human note with
  reminder memorial-content-only、deceased pet memorial calendar/photo allowed
  without care/economy derivation；`RecurringFindingsRepairTests` 当前覆盖
  active-only pet/human commands no-op、deceased pet memorial moment writes photo
  only、human medication active-only no-op。验证：
  `scripts/test-simulator.sh -only-testing:OhanaTests/MemberLifecycleGateTests`
  PASS（50 tests，iPhone 17 simulator）；
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/CareDerivationExecutorSuccessCharacterizationTests -only-testing:OhanaTests/RecurringFindingsRepairTests -only-testing:OhanaTests/ReminderActionCoordinatorTests -only-testing:OhanaTests/CatCareCommandTests`
  PASS（58 tests，iPhone 17 simulator）。尚未跑 broader gate、push/CI 与 fresh
  pure review，所以保持 Open。

### TFU-20260614-018 - Resolve unwritable executors consistently across fact, ledger, and reward

- Status: Open - Home and non-Home actor consistency guards locally verified;
  module exit, push, CI, and fresh review still pending.
- Priority: P1
- Area: Domain / Economy / CareFactWritePolicy / Reward Owner Resolution / Tests
- Source task: Domain first-release reachable-surface pure adversarial review;
  Codex, 2026-06-14, current commit `24fc54c21`.
- Blocker: 本轮按更新后的 G4.1/ECO-026 重判：active 照护对象 + 不可解析/已删除/
  不可写（含离世）显式 executor 时，事实不得丢失，奖励可 fallback 到可写 active
  human；因此"fallback 本身"不再是 P1。真正 P1 是归属解析没有 typed result，
  事实、ledger、reward、特殊奖励与测试断言不一致：`CareFactWritePolicy.disposition`
  只检查 target pet；`EconomyRewardOwnerResolver.rewardHuman` 用 optional nil 同时表达
  missing 与 frozen/deceased，再回落 active human；但 `CareEventService.recordManualFeedFact`
  仍把原 deceased executorId 写入 `PetCareLog.executorId`，`CareLedgerService.recordPetCare`
  以该 executorId 写 `CareLedgerEvent.actorId`，同时钱包流水/预算归属 active human。
  喂食路径还把原 executorId 传给 `QuestManager.recordFirstMeal`。现有
  `CareCompletionChokepointCharacterizationTests` 与 `HomeCommandExecutorTests` 只断言
  active human wallet 获得奖励、deceased wallet 未写，没有断言 care fact / ledger /
  wallet / budget / feedback 的 effective actor 一致性，等于漏掉 G4.1 "fallback 归属必须
  明确、不得伪装为原 executor 发奖"。
- Next step: 在已补强的 Home quick-action 代表路径之外，继续覆盖 direct care、
  shared care、pet medication dose、walk、weight/health、Calendar/notification
  代表路径：active target + deceased/missing/physically-deleted executor 必须写
  fact，但 `CareLedgerEvent`、wallet entry、budget event、Oasis/feedback/revision
  metadata 的 effective actor 必须一致地指向 fallback active human；没有可用 owner
  时 fact-only、ledger coconutDelta=0、无 wallet/budget/Oasis。实现上继续审计 typed
  executor resolution，区分 `requestedExecutorId`、`effectiveExecutorId` 与
  `rewardExecutorId`，旧表征测试不得只用"wallet 没写 deceased"当通过条件。
- Close condition: 新红测先失败后修绿；所有 care-family 入口的 fact、care ledger、
  reward wallet、budget、Oasis/feedback 与 revision 对同一动作的 actor 归属一致；
  missing/physically-deleted executor 的 active target fact 语义仍保留；
  `CareCompletionChokepointCharacterizationTests`、Home/Reminder/Walk/Health/Medication
  相关入口族测试、economy audits、fixture tests、module exit gate、push 和 CI 全绿；
  随后另开首发可达面纯复审，P0/P1=0 才能把 Domain 标 🏁。
- Progress: 2026-06-24 本地补强 Home command executor actor fallback guard。
  `quickPlayCommandExecutorWritesForMissingExecutorThroughFallbackOwner`、
  `quickPlayCommandExecutorWritesForPassedAwayExecutorThroughFallbackOwner`、
  `homeQuickCareWritesForDeceasedExecutorThroughFallbackOwner` 与
  `quickPottyCommandExecutorWritesForDeceasedExecutorThroughFallbackOwner` 现在
  不只断言 active human wallet 获得奖励，还 fetch 对应 `PetCareLog` /
  `PetPottyLog` 与 `CareLedgerEvent`，断言 fact `executorId` 和 ledger `actorId`
  都等于 fallback active human id。验证：`scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeCommandExecutorTests` PASS（183 tests，iPhone 17
  simulator）。
- Progress: 2026-06-24 refreshed non-Home chokepoint evidence on the current
  worktree. `CareCompletionChokepointCharacterizationTests` now covers direct
  manual feed, shared watering, medication dose, calendar completion, walk,
  pet weight, and pet health fallback paths where missing/deceased explicit
  executors write the active target fact but converge fact `executorId`,
  `CareLedgerEvent.actorId`, wallet, budget, Oasis/feedback, and reminder/event
  metadata onto the fallback active human, plus deceased-target no-op paths.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests`
  PASS (24 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_02-11-00-+0200.xcresult`).
  This item remains Open because module exit, push/CI, and a fresh pure review
  are still part of the close condition.

### TFU-20260614-017 - Delete PetMilestone ledger with the milestone fact

- Status: Open - local creation/write cleanup and legacy-ledger delete guard
  verified; pending module exit, push/CI, and fresh pure review before close.
- Priority: P1
- Area: Domain / Pet Milestones / Physical Deletion / CareLedger / Tests
- Source task: Domain first-release reachable-surface pure adversarial review;
  Codex, 2026-06-14, current commit `24fc54c21`.
- Blocker: 本轮首发可达面继续纯复审发现该 P1；随后横向扩展复审又登记
  TFU-20260614-018 与 TFU-20260614-019；2026-06-14 宪法 v1.5 后重判仍为
  P1：纪念日内容本身可写，但当前 milestone 入口进入奖励/ledger 纪律，且删除
  仍留下 orphan ledger。最终总账见 `docs/testing-progress.md` Domain 行。
  `PetMilestoneCommandService.createMilestone` 会写
  `PetMilestone` fact、发非照护奖励，并写
  `CareLedgerEvent(legacyModelName: "PetMilestone", legacyModelId:
  milestone.id)`；但 `deleteMilestone` 只调用
  `PhysicalDeletionService.deletePetScopedRecord` 删除 milestone 本体。该服务的
  `petScopedLegacyReference` 漏掉 `PetMilestone`，所以 matching care ledger
  不会 tombstone/delete，删除后留下指向已物理删除 fact 的 ledger。现有
  `petMilestoneCommandServiceCreatesRewardsAndDeletesLedger` 测试还断言
  `removedLedgerEventIDs.isEmpty` 且 ledger 继续存在，属于“测试断言违反宪法”
  的绿测。
- Next step: 先补红测并改正既有断言：构造 pet，调用
  `PetMilestoneCommandService.createMilestone`，确认 `PetMilestone` 和 matching
  `CareLedgerEvent` 都存在；再调用 `deleteMilestone`，断言 milestone 与
  matching `CareLedgerEvent` 均被删除并写 deletion tombstone，返回值包含
  removed ledger id。实现上把 `PetMilestone` 纳入
  `PhysicalDeletionService.petScopedLegacyReference` 或等价 typed lifecycle
  矩阵，并补审计/fixture：凡写 `CareLedgerEvent.legacyModelName` 的本地 fact
  删除路径，必须有 matching ledger cleanup 覆盖。
- Close condition: 新红测先失败后修绿；旧测试不再断言 orphan ledger 为正确；
  ledger cleanup 矩阵由写 ledger 的 fact registry 或审计约束覆盖，避免继续逐
  command 漏接；`HomeCommandExecutorTests`、相关 physical deletion / economy
  audits、fixture tests、module exit gate、push 和 CI 全绿；随后另开首发可达面
  纯复审，P0/P1=0 才能把 Domain 标 🏁。
- Progress: 2026-06-24 本地补强旧数据 guard。当前代码的新建
  `PetMilestoneCommandService.createMilestone` 不再写 `CareLedgerEvent`，但测试
  额外构造 legacy matching `CareLedgerEvent(legacyModelName: "PetMilestone",
  legacyModelId: createdMilestone.id)`；删除里程碑后断言返回
  `removedLedgerEventIDs == [matchingLegacyLedger.id]`、`PetMilestone` 与
  matching `CareLedgerEvent` 均写 deletion tombstone，unrelated milestone
  ledger 仍保留。验证：`scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeCommandExecutorTests` PASS（183 tests）；
  `scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests`
  PASS（12 tests）；`scripts/audit-economy-boundaries.sh --all` PASS（846
	  files）；`scripts/audit-derived-state-lifecycle.sh --all` exit 0（846 files，
	  仅既有 review warnings）；`scripts/tests/run-audit-fixture-tests.sh` PASS。
	  尚未跑 module exit gate / push / CI / fresh pure review，所以保持 Open。
- Progress: 2026-06-24 refreshed local evidence on current worktree:
  `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests`
  PASS (183 tests, xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_01-38-55-+0200.xcresult`);
  `scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests`
  PASS (12 tests, xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_01-39-49-+0200.xcresult`);
  `scripts/audit-economy-boundaries.sh --all` PASS; `scripts/audit-derived-state-lifecycle.sh
  --all` reported only the existing non-PetMilestone review warnings.
- Progress: 2026-06-25 Codex re-audited the current worktree and found the
  2026-06-24 note was stale: `PetMilestoneCommandService.createMilestone` and
  `seedSystemMilestones` still called the private legacy `recordLedger(...)`
  helper. Removed that write path and the unused `careLedger` parameter, keeping
  only the deletion-time `ledgerEvents(for:)` narrow query for historical
  `legacyModelName == "PetMilestone"` cleanup. Added
  `HomeCommandExecutorTests.petMilestoneCommandsDoNotCreateLegacyCareLedgerEvents`
  as a source guard against reintroducing `recordLedger(` /
  `careLedger.record(` in `PetMilestoneCommands.swift`; existing behavior tests
  still verify new milestones create no `CareLedgerEvent`, while manually
  inserted matching legacy ledgers are tombstoned with the milestone and
  unrelated legacy ledgers remain. Validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests
  -only-testing:OhanaTests/RecurringFindingsRepairTests` PASS (201 tests,
  iPhone 17 simulator, xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_00-13-14-+0200.xcresult`);
  `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS (current large
  dirty worktree still recommends build/targeted tests for broad compiler
  surface; this slice is covered by the targeted simulator tests above).

### TFU-20260614-016 - Scrub deleted human executors from retained active pet facts

- Status: Open - local repair and refreshed validation verified; pending push/CI
  and final pure review before close.
- Priority: P1
- Area: Domain / Physical Deletion / Member Lifecycle / Care Facts / CareLedger
- Source task: Domain first-release reachable-surface pure adversarial review;
  Codex, 2026-06-14, after local no-CI repair commit `3cc140333`.
- Blocker: 本轮首发可达面纯复审发现 P0=0 / P1=1 / P2=0，Domain
  仍不能标 🏁。P1：`PhysicalDeletionService.deleteHuman` 只 scrub 了
  shared-care child facts；普通 active pet facts（`PetCareLog` /
  `PetPottyLog` / `PetHygieneLog` / `PetHealthLog` / `PetWalkLog` /
  `PetWeightLog` / `PetFoodRecord` / pet-scoped `PetExpenseLog`）会保留
  被物理删除 human 的 `executorId` / `executorIdsRaw`。同一删除路径又会删除
  `actorId == humanId` 的 `CareLedgerEvent`，导致 active pet fact 保留但
  ledger 消失；后续 `CareLedgerBackfillService.backfill` 会从保留下来的
  `log.executorId` 把已删除 human id 重新写回 ledger。备份编码也会导出这些
  retained pet fact 的 `executorId`。这违反 D8/G5 的物理真删、G4.1 的
  deleted executor 不得伪装归属，以及 G1 的 fact/ledger 一致性。
- Next step: 先补入口族红测：构造 active pet + human executor + 普通非
  shared 的 care/potty/hygiene/health/walk/weight/food/pet expense facts，
  以及对应 `CareLedgerEvent`；调用 `PhysicalDeletionService.deleteHuman`
  后断言 active pet facts 保留但不再含 deleted human id，matching
  care ledger 不得消失或回填 deleted actor（按产品语义更新为 unknown /
  fallback actor），CloudSync dirty state 要标记这些 scrubbed facts/ledger。
  再补 backfill/backup 断言：删除后跑 `CareLedgerBackfillService.backfill`
  或导出备份，不得重新出现 deleted human id。
- Close condition: 新红测先失败后修绿；实现以一个 retained-pet-fact
  scrubber 收口普通 facts 和 shared facts 的 deleted executor 语义，避免逐
  log 类型散补；`PhysicalDeletionServiceTests`、`CareLedgerBackfillActorTests`
  或等价 backfill/backup 测试、economy/derived audits、fixture tests、
  module exit gate、push 和 CI 全绿；随后另开首发可达面纯复审，P0/P1=0
  才能把 Domain 标 🏁。
- Progress: 2026-06-14 no-CI 修复会话已本地补红测并修绿：`deleteHuman`
  现在先维护 shared session，再对所有 retained active pet fact keys 做兜底
  executor scrub；普通 active pet facts 清 deleted executor，matching
  `CareLedgerEvent` / pet-owned `CoconutLedgerEntry` 保留并把 actor 统一收敛到
  retained survivor executor，若没有 survivor 则收敛为 unknown/nil，保留
  fact/ledger 可回放一致性。新增测试覆盖普通 care/potty/hygiene/health/walk/
  weight/food/pet expense facts、shared-only-executor ledger、shared survivor
  ledger、backfill 和 backup 不回灌 deleted human id。验证见
  `docs/testing-progress.md` 2026-06-14 Domain TFU-20260614-016 no-CI
  修复记录；按用户要求未跑 CI、未推送、未最终纯复审。
- Progress: 2026-06-24 refreshed local validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests`
  PASS（12 tests，iPhone 17 simulator）。本次覆盖
  `deleteHumanScrubsExecutorFromRetainedPetFactsAndLedgers`，包括 retained active
  pet facts、matching care/coconut ledger、`CareLedgerBackfillService.backfill`
  和 backup projection 均不得回灌 deleted human id。仍未 push/CI/fresh pure
  review，所以保持 Open。

### TFU-20260614-015 - Clear shared-care child references when deleting a human executor

- Status: Open - local repair and refreshed validation verified; pending push/CI
  and final pure review before close.
- Priority: P1
- Area: Domain / Physical Deletion / Shared Care / Member Lifecycle
- Source task: Domain first-release local physical deletion cascade pure
  adversarial review; Codex, 2026-06-14.
- Blocker: 本轮首发可达面纯复审发现 P0=0 / P1=1 / P2=0，Domain 仍
  不能标 🏁。P1：`PhysicalDeletionService.deleteHuman` 将
  `SharedCareSession.executorIds` 只含被删 human 的 session 物理删除，但
  active pet 的 child facts（如 `PetCareLog.sharedSessionId`、
  `PetWalkLog.sharedSessionId`、`PetExpenseLog.sharedSessionId`）必须保留，
  当前路径没有清这些 child 引用，删除后可留下指向已删除
  `SharedCareSession` 的 orphan `sharedSessionId`。这违反本地物理删除级联
  的 session/child 一致性验收，也说明现有入口族测试只插入了 session，
  未插入对应 child facts。
- Next step: 先补红测：构造 active pet + human + `SharedCareSession`
  executorIds 仅含该 human + 至少一个 active pet child log（feeding/walk
  或 expense）带同一 `sharedSessionId`，调用
  `PhysicalDeletionService.deleteHuman` 后断言不会留下 child log 指向不存在
  的 session。再覆盖多 executor 情况：session 移除被删 human 后保留时，
  child shared metadata 不得重新暴露被删 human 或与 session executor set
  矛盾。实现应在 shared-care 边界统一处理 session 删除/降级/child
  reference 清理，而不是只补单个 log 类型。
- Progress: 2026-06-14 Codex no-CI repair 已补红测并修绿。新增入口族覆盖
  `PetCareLog` / `PetPottyLog` / `PetHygieneLog` / `PetExpenseLog` /
  `PetWalkLog` 两种路径：唯一 executor 被删时 session 删除但 child facts
  保留并清空 `sharedSessionId` / executor；多 executor 时 session 保留且
  child executor metadata 收敛到 survivor。实现拆入
  `PhysicalDeletionService+SharedCareScrubbing.swift`，避免增长 oversized
  baseline 文件。按用户要求未跑/触发 CI，Domain 不得标 🏁。
- Progress: 2026-06-24 refreshed local validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests`
  PASS（12 tests，iPhone 17 simulator）。本次覆盖
  `deleteHumanDetachesSharedCareChildrenWhenOnlyExecutorSessionIsRemoved` 与
  `deleteHumanScrubsSharedCareChildrenWhenSessionKeepsOtherExecutors`：唯一
  executor session 删除时 child facts 保留但清 `sharedSessionId` / executor；
  多 executor session 保留时 child facts 与 session executor set 一致收敛到
  survivor。仍未 push/CI/fresh pure review，所以保持 Open。
- Close condition: 新红测先失败后修绿；`PhysicalDeletionServiceTests`、
  `SharedPetActionRecorderTests`、`HomeCommandExecutorTests`、derived-state
  lifecycle audit、fixture tests、module exit gate、push 和 CI 全绿；随后
  另开首发可达面纯复审，P0/P1=0 才能把 Domain 标 🏁。

### TFU-20260614-014 - Enforce CloudSync live-apply deletion wins, parent lifecycle, and natural identity

- Status: Open (deferred to CloudKit 1.x; first-release unreachable while `cloudKitDatabase: .none`)
- Priority: P1
- Area: Domain / CloudSync / Physical Deletion / Parent Lifecycle / Gacha
- Source task: Domain fresh pure adversarial review after local
  TFU-20260614-013 repair; Codex, 2026-06-14.
- Blocker: 本轮纯复审发现 P0=0 / P1=3 / P2=0，Domain 仍不能标
  🏁。P1-1：`CloudSyncRecordApplier.apply` only skips a live remote record
  when the same record key has an older `lastModifiedAt`; a newer live `Pet` or
  `Human` record clears local deletion tombstone state and re-inserts the
  deleted member, violating D8/G5 irreversible delete semantics. P1-2：live
  child/fact apply paths do not enforce that the parent still exists and is
  active; pet-scoped records fall back to `pet = nil`, and Gacha/Shop records
  accept `ownerHumanId` / `buyerHumanId` even after that human was physically
  deleted, so late remote records can recreate orphan data after a member
  deletion. P1-3：`GachaOwnedItem` is a mutable ownership projection whose real
  identity is `(ownerHumanId, seriesId, itemId)`, but CloudSync apply merges
  only by random local id; concurrent devices can create duplicate ownership
  rows instead of applying the declared `ownedCount` max policy to one record.
- Next step: Do not patch per entity. First add red tests in
  `CloudSyncMetadataServiceTests`: 1) local deleted `Human`/`Pet` tombstone plus
  newer live remote record must not resurrect the member or clear tombstone; 2)
  after `PhysicalDeletionService.deleteHuman/deletePet`, live remote child
  records with that deleted owner/parent must be skipped/tombstoned, not
  inserted as orphan rows; include Gacha/Shop and one pet-scoped fact; 3)
  remote `GachaOwnedItem` with same owner+series+item but different id must
  merge into the existing ownership projection and keep one row with max count.
  Then implement one CloudSync live-apply disposition/policy layer that decides
  delete-wins, parent existence/active eligibility, and natural-key merge before
  entity-specific mutation.
- Close condition: New red tests fail before implementation and pass after the
  policy layer; `CloudSyncMetadataServiceTests`, `PhysicalDeletionServiceTests`,
  `HomeCommandExecutorTests`, CloudSync/economy/derived audits,
  `scripts/tests/run-audit-fixture-tests.sh`, `scripts/dev-check-changed.sh`,
  module exit gate, push, and CI pass. Then run a fresh pure Domain review;
  P0/P1=0 is required before Domain can be marked 🏁.
- Progress: 2026-06-14 总览裁定该 live remote apply policy is 1.x work, not a
  first-release blocker, because `cloudKitDatabase: .none` makes these paths
  unreachable on the single-device first-release surface. The deferred
  CloudKit-enable-time architecture is recorded in `docs/cloud-sync-todo.md`.
  The first-release-reachable local physical deletion cascade was closed in a
  separate Domain local-cascade round with registry-generated coverage audit,
  entrance-family tests, `scripts/module-exit-gate.sh` PASS, and pending push /
  CI / fresh pure review before Domain may be marked 🏁.

### TFU-20260614-013 - Close Domain Gacha/Shop CloudSync upload and human-delete lifecycle gaps

- Status: Open (repair implemented locally; pending final pure review and CI)
- Priority: P1
- Area: Domain / CloudSync / Physical Deletion / Gacha / Shop / Human Lifecycle
- Source task: Domain TFU-20260614-012 repair followed by fresh pure
  adversarial review; Codex, 2026-06-14.
- Blocker: 修复 TFU-20260614-012 后，本轮全新纯对抗复审发现 P0=0 /
  P1=2 / P2=0，Domain 仍不能标 🏁。P1-1：`CloudSyncEntityRegistry`
  把 `GachaOwnedItem` / `GachaDrawLog` / `ShopPurchaseRecord` 列入
  upload pipeline，业务入口也会写 dirty state，但
  `CloudSyncUploadBatchBuilder.localModel` 没有对应 fetch 分支，dirty
  payload 构建会抛 `missingLocalModel`，导致本地 Gacha/Shop 记录无法上传。
  P1-2：`PhysicalDeletionService.deleteHuman` 的 human-scoped cascade 未删除
  `GachaOwnedItem.ownerHumanId`、`GachaDrawLog.ownerHumanId`、
  `ShopPurchaseRecord.buyerHumanId` 关联的记录；删除成员后仍留下人属收藏、
  抽取日志和购买记录，违反 G5 “删除成员物理真删该成员所有记录”。同时
  本地 recorder 只有 Gacha modified，没有 Gacha deleted overload，修删除
  cascade 时必须补 sync tombstone 出口。
- Next step: 先补红测，不先改实现：1) 在 `CloudSyncMetadataServiceTests`
  插入三类 Gacha/Shop 实例并 mark dirty，断言
  `CloudSyncUploadBatchBuilder.dirtyPayloads` 产出对应 payload，而不是
  `missingLocalModel`；2) 在 physical/member deletion 测试插入同一 human
  的 `GachaOwnedItem` / `GachaDrawLog` / `ShopPurchaseRecord`，调用
  `MemberDeletionCommandService.deleteHuman`，断言三类记录物理删除并留下
  sync tombstone；3) 补入口族测试或审计，证明 registry upload pipeline
  新增实体时必须同时覆盖 serializer、applier、upload builder fetch、
  mutation modified/deleted 和 physical deletion lifecycle（按实体能力）。
  实现上补 upload builder fetch cases；human cascade 补 Gacha/Shop 删除并
  写 tombstone，Gacha 需新增 markDeleted overload。
- Close condition: 新红测先失败后修绿；CloudSync / PhysicalDeletion /
  MemberDeletion / Gacha / Shop targeted simulator suites、
  `scripts/audit-derived-state-lifecycle.sh --all`、
  `scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、`scripts/dev-check-changed.sh`
  PASS；按用户要求跳过 CI 时须明确记录；随后另开全新 Domain 纯对抗复审，
  P0/P1=0 才能把 Domain 标 🏁。
- Progress: 2026-06-14 Codex repair session fixed the local implementation:
  `CloudSyncUploadBatchBuilder` now has local-model fetch cases for
  `GachaOwnedItem` / `GachaDrawLog` / `ShopPurchaseRecord`;
  `CloudSyncMutationRecorder` now emits Gacha delete tombstones; and
  `PhysicalDeletionService.deleteHuman` cascades human-owned Gacha/Shop records
  with sync tombstones. Added red-to-green tests for upload payload construction
  and member deletion cascade, plus `cloudsync-upload-builder-coverage` in
  `scripts/audit-derived-state-lifecycle.sh` with bad/good fixtures. Validation
  passed locally: `CloudSyncMetadataServiceTests` (94 tests),
  `HomeCommandExecutorTests` (177 tests), `PhysicalDeletionServiceTests`
  (4 tests), `scripts/tests/run-audit-fixture-tests.sh`,
  `scripts/audit-derived-state-lifecycle.sh --all`,
  `scripts/audit-economy-boundaries.sh --all`, `scripts/dev-check-changed.sh`,
  and `git diff --check`. CI was intentionally skipped per user direction.
  Domain remains 🟢 until a fresh pure adversarial review reports P0/P1=0.

### TFU-20260614-012 - Rebuild feeding stock reminders on CloudSync remote deletes

- Status: Done (original gap repaired locally; later review P1 is tracked by
  TFU-20260614-013)
- Priority: P1
- Area: Domain / CloudSync / Feeding / Stock Reminders / Delete Dispatch
- Source task: Domain CloudSync delete-dispatch repair follow-up pure
  adversarial review; Codex, 2026-06-14.
- Blocker: 修复 TFU-20260614-011 后，本轮全新纯对抗复审发现
  P0=0 / P1=1 / P2=0，Domain 仍不能标 🏁。P1：远端
  `PetCareLog` / `PetFoodRecord` tombstone 或 hard deletion 现在会进入
  `PhysicalDeletionService.deletePetScopedRecord`，可以删除 fact / ledger /
  shared session，但没有执行本地喂食删除路径的
  `FeedingPlanWriter.rebuildFoodStockReminders`。结果是库存事实已删，旧的
  `pet_food_stock` Event/Reminder 仍按删除前库存存在；通知调度也不会被等价刷新。
  本地 `FeedRecordCommand.deleteLog` 和 `deleteFoodRecord` 都会 rebuild stock
  reminder，CloudSync 远端删除与本地 command 不等价，违反 G1/G4.1 的一动作一派生
  与派生生命周期一致性。
- Next step: 先补红测：在 `CloudSyncMetadataServiceTests` 构造启用断粮提醒的
  active pet、`PetFoodRecord`、feeding `PetCareLog`、既有 `pet_food_stock`
  Event/Reminder；分别 apply 远端 `PetCareLog` tombstone 与 `PetFoodRecord`
  tombstone，断言旧 stock reminder 被删除/重建，必要的 notification cancel /
  schedule 可由 fake scheduler 捕获。实现上不要在 switch 里继续散补；让 CloudSync
  pet-scoped delete dispatcher 能返回 affected pet + derived families，并把 feeding
  stock reminder rebuild 作为同边界派生步骤。同步补 derived-state lifecycle 审计
  bad/good fixture，抓远端 feed fact / stock fact 删除后未重建 stock reminder 的坏例。
- Close condition: 新红测先失败后修绿；CloudSync / Feeding / PhysicalDeletion
  targeted simulator suites、`scripts/audit-derived-state-lifecycle.sh --all`、
  `scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、`scripts/dev-check-changed.sh`
  PASS；按用户要求跳过 CI 时须明确记录；随后另开全新 Domain 纯对抗复审，
  P0/P1=0 才能把 Domain 标 🏁。
- Progress: 2026-06-14 Codex repair session fixed the original remote feeding
  stock-reminder rebuild gap locally: remote feeding `PetCareLog` and
  `PetFoodRecord` deletes now rebuild affected stock reminders; targeted
  CloudSync tests and changed-file gates passed. Follow-up pure adversarial
  review found two remaining Gacha/Shop CloudSync/delete lifecycle P1s, now
  tracked separately in TFU-20260614-013. Domain remains 🟢.
- Closed: 2026-06-24 stale tracker correction. The original TFU-012 behavior is
  fixed and covered by the recorded CloudSync tests; the remaining active
  CloudSync/Gacha/Shop P1 is intentionally counted once under TFU-20260614-013.

### TFU-20260614-011 - Close remaining Domain CloudSync delete dispatch gaps

- Status: Done (original gap repaired locally; later review P1 is tracked by
  TFU-20260614-012/013)
- Priority: P1
- Area: Domain / CloudSync / Delete Dispatch / Notifications / SharedCare /
  CareLedger
- Source task: Domain CloudSync remote-delete repair plus follow-up pure
  adversarial review; Codex, 2026-06-14.
- Blocker: 修复 TFU-20260614-010 后，本轮全新纯对抗复审发现 P0=0 /
  P1=2 / P2=1，Domain 仍不能标 🏁。P1-1：`CloudSyncRecordApplier`
  对远端 `Event` tombstone / hard deletion 仍裸 `context.delete`，绕过
  `PhysicalDeletionService.deleteEvent` 的 notification cancellation 与
  reminder delete/mark boundary。P1-2：远端 `SharedCareSession` tombstone /
  hard deletion 仍只删除 session 本体，绕过
  `SharedCareSessionMaintenance.deleteCascade`，可留下 child care/potty/
  hygiene/expense/walk facts 与 `CareLedgerEvent` orphan。P2：远端
  Pet-scoped fact tombstones（care/potty/hygiene/expense/walk 等）仍裸删
  单个 fact，没有消费本地 command delete boundary 的 ledger 清理与 shared
  session reconcile；如果配套 tombstone 延迟或丢失，会出现短期派生不一致。
- Next step: 禁止继续扩大 `deleteLocalModel` 的裸 switch 补丁；先补红测再改
  架构。红测至少覆盖：远端 Event tombstone 取消本机通知并删除/标记 reminders；
  远端 SharedCareSession tombstone 级联 child facts + ledger；远端 PetCareLog /
  PetExpenseLog / PetWalkLog tombstone 要么消费 typed domain delete dispatcher，
  要么证明同 batch ledger/session tombstones 到达前不会暴露不一致。实现应引入
  CloudSync delete disposition/dispatcher，把 entity family 映射到
  `PhysicalDeletionService`、`SharedCareSessionMaintenance`、pet fact command
  delete 等等价边界；`R6`/derived-state lifecycle 审计补 bad/good fixture，抓
  remote delete applier 裸删派生 state。
- Close condition: 新红测先失败后修绿；CloudSync / PhysicalDeletion /
  SharedCare / notification / CareLedger targeted simulator suites、
  `scripts/audit-derived-state-lifecycle.sh --all`、
  `scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh` 和 `scripts/module-exit-gate.sh`
  PASS；随后另开全新 Domain 纯对抗复审，P0/P1=0 才能把 Domain 标 🏁。
- Progress: 2026-06-14 Codex repair session fixed the original Event /
  SharedCareSession / pet-scoped fact delete gaps locally: remote Event deletes
  now call `PhysicalDeletionService.deleteEvent`; remote SharedCareSession
  deletes call `SharedCareSessionMaintenance.deleteCascade`; remote pet-scoped
  fact deletes call `PhysicalDeletionService.deletePetScopedRecord`, clearing
  ledger and reconciling shared sessions. Follow-up pure adversarial review found
  one remaining CloudSync feeding stock-reminder derived-state gap, now tracked
  separately in TFU-20260614-012. Domain remains 🟢.
- Closed: 2026-06-24 stale tracker correction. The original TFU-011 behavior is
  fixed and covered by the recorded CloudSync / PhysicalDeletion /
  SharedCare / notification / CareLedger tests; the successor risks are counted
  under TFU-20260614-012/013 rather than duplicated here.

### TFU-20260614-010 - Close Domain CloudSync remote-delete side effects

- Status: Done
- Priority: P1
- Area: Domain / CloudSync / Physical Deletion / Wallet / CareLedger
- Source task: Domain fresh pure adversarial review after `f5cc637c8`; Codex
  pure review session, 2026-06-14.
- Blocker: 本轮 Domain 全新纯对抗复审（禁止业务代码修改）发现 P0=0 / P1=2 /
  P2=0，Domain 不能标 🏁。P1-1：`CloudSyncRecordApplier` apply 远端
  Pet/Human tombstone 或 CloudKit hard deletion 时只走裸 `context.delete`，绕过
  `PhysicalDeletionService.deletePet/deleteHuman` 的 wallet account、wallet ledger、
  care ledger、shared session 字符串引用级联，远端删除传播后本机可留下孤儿派生状态。
  P1-2：同一 delete applier 删除远端 `CoconutLedgerEntry` tombstone 时也只裸删
  ledger，不像远端 ledger 插入/更新那样调用
  `CoconutWalletService.reconcileFormalAccountBalancesWithLedger`，导致
  `CoconutAccount` / member balance projection 继续保留旧余额，违反 G2 可重放。
- Next step: 先补红测，不先改实现：在 `CloudSyncMetadataServiceTests` 加远端 Pet
  tombstone / hard deletion 场景，预置 `CoconutAccount`、`CoconutLedgerEntry`、
  `CareLedgerEvent`、`SharedCareSession` 关联 deleted pet，断言 apply 后无 orphan 且
  island total 回到 ledger replay；再加远端 `CoconutLedgerEntry` tombstone 场景，预置
  account balance 与 ledger entry，断言 apply 后立即 replay 到 0。修复应在
  CloudSync delete boundary 统一调用 domain deletion/reconcile 等等价 typed delete
  outcome，而不是继续逐 entity 裸删；同时补 derived-state lifecycle / audit fixture，
  让 CloudSync delete applier 不能绕过 cascade/replay 纪律。
- Close condition: 新红测先失败后修绿；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/audit-derived-state-lifecycle.sh --all`、CloudSync/PhysicalDeletion/
  CoconutWallet targeted simulator suites、`scripts/tests/run-audit-fixture-tests.sh`、
  `scripts/module-exit-gate.sh` 与 CI PASS；随后另开全新 Domain 纯对抗复审，P0/P1=0
  才能把 Domain 标 🏁。
- Progress: 2026-06-14 Codex repair session fixed the original two P1s locally:
  remote Pet/Human tombstone and hard deletion now route through
  `PhysicalDeletionService.deletePet/deleteHuman`, and remote
  `CoconutLedgerEntry` tombstone replays wallet projection through
  `CoconutWalletService.reconcileFormalAccountBalancesWithLedger`. Added
  red-to-green tests in `CloudSyncMetadataServiceTests`; targeted simulator
  suites and audits passed locally. CI was skipped by user request. Follow-up
  pure adversarial review found additional same-family CloudSync delete dispatch
  gaps, now tracked in TFU-20260614-011, so Domain remains 🟢 and this item
  stays open until a fresh review reports P0/P1=0.

### TFU-20260614-009 - Close Domain current-code pure-review P1s before maturity

- Status: Done (original repair verified locally; successor risks are tracked
  by TFU-20260614-010 through TFU-20260614-014)
- Priority: P1
- Area: Domain / Care Derivation / Physical Deletion / Wallet / CloudSync /
  CareLedger
- Source task: Domain fresh pure adversarial review; Codex pure review session,
  2026-06-14.
- Blocker: 本轮 Domain 纯复审（当前代码首次对抗复审，禁止业务代码修改）发现
  P0=0 / P1=5 / P2=2，Domain 不能标 🏁。P1：① `DomainRevisionPublishing`
  仍暴露无 token 的 care-family typed publish / no-op 出口，command 仍能编译出
  绕过 `CareDerivationExecutor` 的 revision 副作用；② `PhysicalDeletionService`
  删除 Pet/Human 时只处理关系数组和少量 human scoped rows，未清理
  `CoconutAccount` / `CoconutLedgerEntry` / `CareLedgerEvent` /
  `SharedCareSession` 等字符串 ID 关联行，且现有测试仍断言 shared session 保留
  已删 pet id；③ `CareLedgerService.record` 只 insert，不写
  `CloudSyncRecordState` dirty，常见 care fact 会同步 `Pet*Log` 但不同步
  同边界 `CareLedgerEvent`；④ `CloudSyncRecordApplier.applyCoconutLedgerEntry`
  只插远端 ledger，不重放 `CoconutAccount` projection，而 `CoconutAccount` 又是
  notUploadable derived record；⑤ `CoconutWalletService.apply` 的 frozen gate 只看
  `CoconutWalletDelta.human/pet` 可选对象，手工构造 ownerKind=.human/.pet 但
  不带模型引用的 delta 可绕过离世/删除钱包硬门。P2：`recordUnknownSharedPotty`
  no-op 返回 detached `PetPottyLog`；shared manual feed 多目标路径在 recorder
  事实写入前调用 first-meal special reward，仍有 crash/失败半笔账窗口。
- Next step: 先补红测：Domain revision token 编译/审计坏例；Pet/Human 删除后钱包
  account/ledger/shared session/care ledger 无 orphan 且 sync tombstone 完整；care
  fact + ledger dirty-state 成对进入 CloudSync upload queue；远端
  `CoconutLedgerEntry` apply 后立即重放 `CoconutAccount` / member cache；
  raw `CoconutWalletDelta` 不带模型引用时必须按 ownerId 解析并拒绝冻结/已删 owner；
  unknown shared potty no-op 返回 typed no-op；shared feed first-meal 在事实成功后
  派生。再做结构修复：token 加到 care-family typed publish/no-op 或移除 command
  可见出口；删除边界统一通过 physical deletion cascade；CareLedger dirty marking
  下沉到 ledger write boundary；CloudSync apply batch 结束后重放钱包 projection。
- Close condition: 新红测先失败后修绿；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/audit-derived-state-lifecycle.sh --all`、CloudSync/PhysicalDeletion/
  CoconutWallet/CareLedger targeted simulator suites、`scripts/tests/run-audit-fixture-tests.sh`、
  `scripts/module-exit-gate.sh` 与 CI PASS；随后开全新 Domain 纯对抗复审，P0/P1=0
  才能把 Domain 标 🏁。
- Progress: 2026-06-14 Codex Domain repair session implemented all five P1
  repairs and both P2 repairs in the current worktree: care-family typed
  revision/no-op exits were removed from `DomainRevisionPublishing` so no-op
  care command paths go through `CareDerivationExecutor`; physical pet/human
  deletion now removes wallet accounts, wallet ledger, care ledger, and shared
  session string references with sync tombstones; `CareLedgerService.record`
  stages `CareLedgerEvent` for CloudSync; remote `CoconutLedgerEntry` apply
  replays wallet projection through `CoconutWalletService`; raw wallet deltas
  without model references resolve by owner id/account key and fail closed for
  frozen/deleted member wallets; unknown shared potty no-op returns nil instead
  of a detached fake log; shared manual feed defers first-meal derivation until
  after recorder success. Local validation PASS:
  `scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests -only-testing:OhanaTests/CloudSyncMetadataServiceTests -only-testing:OhanaTests/CoconutWalletServiceTests`,
  `scripts/test-simulator.sh -only-testing:OhanaTests/SharedPetActionRecorderTests -only-testing:OhanaTests/QuestManagerBatchAwardTests`,
  `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests`,
  `scripts/tests/run-audit-fixture-tests.sh`, and `scripts/module-exit-gate.sh`
  (841 unit tests + 3 UI template tests). Still open until the repair commit is
  pushed, CI is green, and a new pure adversarial Domain review reports P0/P1=0.
- Progress: 2026-06-14 Codex fresh pure review after repair commit `f5cc637c8`
  confirmed the local care chokepoint / shared / reminder / physical-deletion /
  wallet targeted suites pass, but found new CloudSync remote-delete P1s tracked
  separately in TFU-20260614-010. Domain remains 🟢 and cannot be marked 🏁.
- Closed: 2026-06-24 stale tracker correction. The original TFU-009 P1/P2
  repair set was implemented and locally validated; the later pure-review
  findings are successor risks and are already counted by TFU-20260614-010
  through TFU-20260614-014. This item is closed to avoid double-counting the
  same Domain maturity chain while the active successor P1s remain visible.

### TFU-20260614-008 - Repair pre-existing CI architecture-boundary gate

- Status: Done
- Priority: P1
- Area: CI / Architecture Boundaries / File Size Ratchet / Service Injection
- Source task: Economy dirty-executor P0 fix and push verification; Codex
  implementation session, 2026-06-14.
- Blocker: CI runs `scripts/audit-architecture-boundaries.sh --all`, and the
  gate is already red before the dirty-executor fix. Runs `27500716652`
  (`be0dd1eeb`) and `27501530627` (`7ded53a6a`) both fail at the same
  architecture step while lint and local module exit are green. Current full
  audit failures include oversized ratchet violations in
  `CalendarTaskCompletionSyncService.swift`, `CareEventRecording.swift`,
  `CareEventService.swift`, `SharedPetActionRecorder.swift`,
  `FeedCommands.swift`, `PetHealthCommands.swift`, `MedicationCommands.swift`,
  `SharedModelContainer.swift`, and several small baseline overruns, plus
  static `CareEventService` references in Economy/Feeding/QuickWater command
  paths. This is cross-module architecture cleanup, not part of the Economy
  dirty-executor behavior fix.
- Next step: Push the local architecture cleanup and verify CI. The local fix
  uses the current oversized Swift file baseline / threshold, keeps the cleanup
  separate from the Economy behavior fix, routes static care calls through
  protocol/adapters where they were business entry points, and keeps only narrow
  adapter/facade allowlists.
- Close condition: `scripts/audit-architecture-boundaries.sh --all` passes
  locally; a pushed CI run passes `audits`, `lint`, and `build-test`; update
  this TFU with the closing commit/run URL.
- Closed: 2026-06-14 by Codex implementation/CI verification session. Closing
  commits `8abbf0ed9` and `3e8fbf5ff`; CI run `27502212959`
  (https://github.com/VeitL/Ohana/actions/runs/27502212959) passed `audits`,
  `lint`, and `build-test`.

### TFU-20260614-006 - Close Economy pure-review P1 leftovers before maturity

- Status: Done
- Priority: P1
- Area: Economy / Shared Feed / Planned Catch-up / Insurance Expense Ledger /
  Test Gate
- Source task: Economy fresh pure adversarial review; Codex pure review session,
  2026-06-14.
- Blocker: 本轮纯复审在当前候选工作树上仍发现 Economy 不能 🏁 的 P1。①
  shared manual feed 多目标路径在 `SharedPetActionRecorder.record` 的 no-op gate
  之前调用 `QuestManager.recordFirstMeal`；invalid / missing / recycled explicit
  executor 会让 recorder no-op，但 first-meal special reward / flag 已可能通过
  special reward active-human fallback 写入。② planned feed / water catch-up
  已开始拆 `factDate` 与 `operationDate`，但 `isCatchUp` 分支仍直接返回 0 奖励并写
  0 delta ledger；现有测试还断言 "within six hours does not award coconuts"，与
  ECO-010 / ECO-027 的"奖励按操作日预算 / 冷却结算，允许时发奖"相反。③
  Insurance 自动保费 schedule 与报销会直接插入 `PetExpenseLog`，没有走
  `ExpenseCommandService` / non-care expense ledger 纪律，也没有同边界
  `CareLedgerEvent`。④ clean `HomeCommandExecutorTests` 仍红在
  `insurancePolicyServiceCreatesPolicyPaymentScheduleAndCalendarEvents`，测试传入
  新 executor UUID 却仍期望 `"human-1"`。附带 P2：`recordUnknownSharedPotty`
  服务 API 在 no-op 时仍返回 detached `PetPottyLog`，容易让未来 caller 用非空对象
  误判成功。
- Next step: 补红测后修复：shared manual feed invalid / missing / recycled executor
  不得写 first-meal special reward、flag、wallet、fact、ledger、revision 或 UI 成功；
  planned feed / water 历史 occurrence 写历史 fact，奖励 / cooldown / wallet ledger
  用 operation day，预算允许时发奖，预算触顶时 recordOnly；Insurance 保费 / 报销
  expense 入口要么改为明确的计划模型不写真实 `PetExpenseLog`，要么走同一
  expense fact + ledger 纪律并补产品选择测试；修复 insurance 测试断言。扩展
  economy audit / fixture 覆盖 "pre-recorder derived effect" 和直接 expense fact
  缺 ledger 的真实坏例；把 `recordUnknownSharedPotty` 改为 typed result 或让 caller
  不可能用 detached fallback 当成功。
- Progress: 2026-06-14 care-derivation executor architecture work retired the
  old recycled/deceased historical fact-only split under the product-owner
  two-state model, restored the dirty-executor characterization witness, and
  moved care command side effects toward typed executor outcomes. This TFU
  remains Open because Insurance expense ledger discipline and the final
  fresh pure adversarial Economy review have not been closed in this session.
- Review update: 2026-06-14 final pure adversarial Economy review after
  commits `7ded53a6a`, `8abbf0ed9`, `3e8fbf5ff`, and `c3c5e5f53` found
  P0=0 / P1=1 / P2=0. The remaining P1 is still this TFU's Insurance expense
  ledger item: `InsurancePolicyCommandService.generatePaymentSchedule` and
  `makeReimbursementExpenseIfNeeded` insert `PetExpenseLog` records without
  the same-boundary `CareLedgerEvent` discipline used by
  `ExpenseCommandService.recordPetExpense`. Shared feed, planned catch-up,
  dirty executor, deceased care target, shared walk, and the old target test
  gate were verified green by targeted tests and CI; do not close this TFU
  until the Insurance expense ledger path has a red test and fix.
- Close condition: 新红测先失败后修绿；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、相关 targeted simulator suite、
  `git diff --check` 与 module exit gate 通过；再开全新纯对抗复审，P0/P1=0 后
  Economy 才可标 🏁。
- Closed: 2026-06-24 stale tracker correction. Current implementation routes
  Insurance auto-payment and reimbursement expense creation through
  `ExpenseCommandService.recordPetExpense(... awardsReward: false)` rather than
  naked `PetExpenseLog` writes; `InsuranceExpenseLedgerTests` directly cover
  auto payments, approved claim creation, and claim-status approval idempotency.
  Verification refreshed with
  `scripts/test-simulator.sh -only-testing:OhanaTests/InsuranceExpenseLedgerTests`
  PASS（3 tests，iPhone 17 simulator）。Historical closure evidence remains in
  `docs/testing-progress.md`: Economy final pure review after `92133da2a` found
  P0=0 / P1=0 / P2=0, `scripts/module-exit-gate.sh` PASS, and CI run
  `27505314629` green.

### TFU-20260614-005 - Split planned catch-up fact date from reward operation date

- Status: Done
- Priority: P1
- Area: Economy / QuickFeed / QuickWater / Reminders / Memorial Historical Facts /
  Backdate Settlement
- Source task: Economy fresh pure adversarial review; Codex pure review session,
  2026-06-14.
- Blocker: 本轮纯复审发现 QuickCare planned catch-up 仍未落实 ECO-027 的
  "事实按历史 occurrence，奖励 / 冷却 / 预算按操作日"。QuickFeed 的
  `completeSelectedPlanOccurrence` 用 occurrence date 构造 reminder，但随后
  `completePlannedFeed` / `ManualFeedCommand.completePlanned` 没把
  `reminder.scheduledAt` 作为事实时间传入；`CareEventService.completePlannedFeed`
  用单一 `date` 同时做 `CareFactWritePolicy.disposition`、`PetCareLog.date`、
  reminder completedAt 和奖励结算。QuickWater 同类：`QuickWaterCommandExecutor`
  固定传 `Date()` 给 `CareEventService.completePlannedWater`，service 同样用该
  操作时间写 `PetCareLog.date`。结果是补完成历史计划时照护事实落到操作日；若宠物
  已在计划 occurrence 之后离世，历史 occurrence 本应允许写 fact-only，却因为用操作
  日做 disposition 直接 no-op。
- Next step: 给 planned feed / planned water 分别补红测：① active pet 的历史
  reminder catch-up 写 `PetCareLog.date == reminder.scheduledAt`，但预算 /
  cooldown / wallet ledger 仍以 operation date 结算；② pet 在 scheduledAt 之后
  离世时，catch-up 写历史 fact-only，不完成奖励 / ledger / reminder-derived /
  Oasis 派生；③ notification manual-feed reminder branch 走同一语义。实现上把
  planned completion result 改成 typed disposition，显式传 `occurredAt` 与
  `operationDate`，所有 QuickFeed / QuickWater / notification planned completion
  caller 统一消费该 typed result。
- Close condition: 新红测先失败后修绿；planned feed / water 历史 occurrence 的
  fact date、reward dayKey、memorial fact-only、UI / revision / reminder 派生语义
  均一致；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、相关 targeted simulator suite 与
  `git diff --check` PASS；再开全新纯对抗复审，P0/P1=0 后 Economy 才可标 🏁。
- Closed: 2026-06-14 in the care-derivation executor architecture work.
  Planned feed/water result types now carry `factDate` and `operationDate`, and
  command/UI callers consume typed result state. The old memorial fact-only
  half of this TFU was retired by the product-owner two-state decision: deceased
  members are read-only/no-write. Remaining Economy maturity risk is tracked by
  TFU-20260614-006 and the required final pure adversarial review.

### TFU-20260614-004 - Finish QuickPotty no-op propagation and restore Economy test gate

- Status: Done
- Priority: P1
- Area: Economy / QuickPotty / UI Feedback / Reminder Settings / Audit Guardrails /
  Test Gate
- Source task: Economy fresh pure adversarial review; Codex pure review session,
  2026-06-14.
- Blocker: 本轮纯复审在当前 P1 修复工作树上又发现 no-op 语义没有贯穿
  QuickPotty 入口族。`QuickPottyDetailSheet.logUnknownGroupPotty` 和 `recordScoop`
  在 command 返回前就保存 `SharedPetSelectionMemory`，因此 missing / recycled /
  deceased explicit executor 导致 `QuickPottyCommandExecutor` no-op 时仍留下共享选择
  记忆。`doFullChange` 更严重：它预先保存选择和本地 cycle anchor，在 deferred
  command 中忽略 `recordLitterCare` 返回值；即使 care fact no-op，仍会
  `LitterCareSettingsStore.markFullChange`、同步 scoop / litter reminders，并展示
  success haptic / toast。现有 `scripts/audit-economy-boundaries.sh --all` 仍 PASS，
  因为 result-consumption 规则没有覆盖 `recordLitterCare` /
  `recordUnknownSharedPotty`。此外 clean DerivedData targeted simulator build 当前
  编译失败：`OhanaTests/HomeCommandExecutorTests.swift` 多个 success-path tests 使用
  `executorHuman.id.uuidString` 但没有创建/插入 `executorHuman`，阻断 Economy 目标
  测试和模块 exit gate。
- Next step: 给 QuickPotty unknown shared / scoop / full-change 补红测：invalid /
  missing / recycled explicit executor 下不得写 selection memory、litter settings、
  reminders、revision success 或 UI success feedback。把 QuickPotty 入口统一消费
  typed result（`didRecord` / `didWriteFact` / `allowsDerivedEffects` 等价均可），
  `doFullChange` 必须在确认 fact 写入后才执行 settings/reminder/success 派生。扩展
  economy audit 与 bad fixture 覆盖 `recordLitterCare` 和
  `recordUnknownSharedPotty` 的未消费结果。修复 `HomeCommandExecutorTests` 中缺失的
  executor fixture，并用 clean DerivedData 重跑目标 suite。
- Close condition: 新红测先失败后修绿；QuickPotty no-op 时无 fact、ledger、
  reward、revision success、reminder/settings 派生、selection persistence 或 UI
  success feedback；audit bad fixture 能抓本轮真实坏例；clean DerivedData 目标
  simulator suite PASS；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、`git diff --check` PASS；再开全新纯
  对抗复审，P0/P1=0 后 Economy 才可标 🏁。
- Closed: 2026-06-14 in the care-derivation executor architecture work.
  QuickPotty command/UI paths now consume typed write results before selection
  memory, settings, reminders, success feedback, or revision effects. The
  `HomeCommandExecutorTests` gate has passed in this session.

### TFU-20260614-003 - Propagate no-op results through Economy UI feedback and secondary actors

- Status: Done
- Priority: P1
- Area: Economy / QuickFeed / QuickWater / Walks / Shared Expense / UI Feedback /
  Audit Guardrails
- Source task: Economy fresh pure adversarial review; Codex pure review session,
  2026-06-14.
- Blocker: 本轮纯复审发现 TFU-014/TFU-20260614-002 后仍有入口没有把 typed no-op
  语义传播到最后一层。QuickFeed detail 的 manual / treat 保存路径调用 command 后
  不检查 `didRecord`，no-op 仍会保存共享选择记忆并展示成功反馈。QuickWater detail
  的 planned water / manual water / water change / filter clean 也没有可消费的
  `didRecord` 结果，command no-op 后仍触发成功 haptic、局部 feedback 和“已记录”
  toast。Walk 的 shared `executorIds` 只做字符串去重，只有 primary `executorId`
  经过 `CareFactWritePolicy.executorCannotWrite`；active primary + 回收/离世 secondary
  executor 仍会写 walk fact / ledger / reward / `executorIds` metadata。Dashboard
  shared expense 复用 `SharedPetActionResult`，但 revision 层无条件发布
  `wroteBusinessFact: true`，即使 recorder 返回 `.noOp()`。
- Next step: 为每个入口补红测：QuickFeed manual/treat UI action 在 invalid/missing/
  recycled executor 下不得成功反馈或写选择/default 派生；QuickWater planned/manual/
  water-change/filter no-op 不得成功反馈或 schedule 派生；single/shared walk 任一非空
  executor id 不可解析或不可写时整体 no-op；shared expense no-op 不发布 success
  revision。实现上让所有这些入口消费 `didRecord` / `didWriteFact` / `allowsDerivedEffects`
  或等价 typed result，且 R5/fixture 不再只证明服务函数消费 disposition，也要覆盖
  caller/UI/revision 层结果消费。
- Close condition: 新红测先失败后修绿；上述入口在 no-op 时无 fact、ledger、reward、
  revision success、reminder/stock/Oasis 派生、selection/default persistence 或 UI
  success feedback；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、相关 simulator tests 通过；再开全新纯
  对抗复审，P0/P1=0 后 Economy 才可标 🏁。
- Closed: 2026-06-14 in the care-derivation executor architecture work.
  QuickFeed, QuickWater, walk/shared executor, and shared-derived revision
  callers now consume typed result/disposition state before user-visible
  success or derived side effects. Final Economy maturity remains gated by
  TFU-20260614-006 plus a fresh pure adversarial review.

### TFU-20260614-002 - Treat unresolved explicit care executors as no-op

- Status: Done
- Priority: P1
- Area: Economy / CareFactWritePolicy / Active Human / Notifications / Oasis /
  Audit Guardrails
- Source task: Economy fresh pure adversarial review round 1 after
  TFU-20260614-001 repair; Codex pure review session, 2026-06-14.
- Blocker: 本轮纯复审发现显式 executor 生命周期门仍有 P1 缝隙：
  `CareFactWritePolicy.executorCannotWrite` 只在 executor id 成功解析到
  `Human` 且该 human 不可写时返回 no-op；invalid UUID、已被 purge 的 UUID、
  或 SwiftData fetch 失败都会返回可写。结果是 Calendar / notification /
  QuickCare / medication / shared care 等入口在 stale `currentActiveHumanId`
  或显式传入已删除 executor UUID 时仍会写照护事实、ledger、reminder/revision/
  stock/Oasis 派生；`EconomyRewardOwnerResolver` 后续拒绝奖励并不够，因为事实
  层已经产生半状态，且 `CareEventRecording` 的 Oasis care echo 当前在 reward
  调用后仍可被触发。
- Next step: 补红测覆盖 active pet + unresolved explicit executor 的入口族：
  direct care fact、shared care、medication dose，以及 Calendar/notification
  代表路径；随后把 `CareFactWritePolicy.executorCannotWrite` 改为"非空显式
  executor 必须解析到 `EconomyWalletWritePolicy.canWrite == true` 的 Human，
  否则 command no-op"，并补审计 fixture 防止 invalid/missing executor 回退为可写。
- Close condition: 新红测先失败后修绿；无 executor 的系统/unknown 路径保持原语义，
  非空 invalid/missing/purged executor 对 fact/ledger/reward/revision/reminder/
  stock/Oasis 全链路 no-op；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、相关 simulator tests 通过；再开全新
  纯对抗复审，P0/P1=0 后 Economy 才可标 🏁。
- Closed: 2026-06-14 by product-owner two-state decision and executor
  architecture update. This TFU's old target behavior was superseded:
  invalid/missing/physically-deleted explicit executor ids must not drop active
  target facts. Active target facts still write; reward ownership falls back to
  a writable active human or fact-only/no-reward when no owner exists. Deceased
  executors still no-op.

### TFU-20260614-001 - Close shared-care source and hygiene session maintenance gaps

- Status: Done
- Priority: P1
- Area: Economy / Shared Care / BatchAward / Session Maintenance / Audit Guardrails
- Source task: Economy fresh pure adversarial review, 2026-06-14; Codex pure
  review session after TFU-20260613-016 P2 repair.
- Blocker: 本轮纯复审发现 shared-care 仍有两条 P1 入口族缺口。第一，
  `SharedPetTargetResolver.normalizedTargets` 只用 `EconomyWalletWritePolicy.canWrite`
  过滤候选 targets，没有把 `sourcePet` 自身作为先验冻结门；当 sourcePet 已回收
  / 离世但调用方传入活跃同物种 targets 时，
  `CareEventService.recordSharedManualFeedFact` / `recordSharedWateringFact` /
  `recordSharedLitterCareFact` / `recordSharedCareFact` 的单目标分支会给活跃 target
  写事实、ledger、reward，多目标分支会创建 `SharedCareSession(sourcePetId:)`
  指向冻结 source。第二，TFU-016 P2 修复新增的 shared hygiene session 只补了
  创建路径：`SharedPetActionRecorder` 会写 `PetHygieneLog` 并把 session
  `primaryLegacyModelName/Id` 指向第一条 hygiene log，但 `PetHygieneLog` 没有
  `sharedSessionId` 字段，`SharedCareSessionMaintenance.deleteCascade` /
  `reconcile` / `recoverStructuredMetadata` / `ledgerEvents` 仍只识别 care/potty/
  expense/walk。因此删除 shared hygiene session 会留下 orphan hygiene fact /
  hygiene ledger / wallet reward，reconcile 会把有效 hygiene session 当 orphan 删除。
- Next step: 先补红测：source 回收/离世 + explicit active targets 对所有 shared
  care service 入口必须整体 no-op；`QuestManager.batchAward(.care(.bath))` 生成的
  shared hygiene session 经 `deleteCascade` 必须删除 hygiene facts 和对应
  `CareLedgerEvent`，经 `reconcile` 不得误删 session。随后修统一 source
  disposition / canWrite 门，并让 hygiene 参与 shared-session maintenance，或给
  hygiene 建立等价 typed session linkage。
- Close condition: 新红测先失败后修绿；入口族测试覆盖 shared feed/water/litter/
  generic care/walk/unknown potty/batch hygiene 的 source no-op 与 maintenance；
  `scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、相关 simulator tests 通过；再开全新纯
  对抗复审，P0/P1=0 后 Economy 才可标 🏁。
- Closed 2026-06-14: Fix session completed. `SharedPetTargetResolver` now treats
  sourcePet as the shared-care hard lifecycle gate, so frozen/recycled/deceased
  source actions with explicit active targets return no-op across feed/water/
  litter/generic care/walk/unknown potty. `SharedCareSessionMaintenance` now
  includes shared hygiene facts in reconcile, cascade delete, primary legacy
  refresh, ledger lookup, and modified tracking; deleting a primary shared
  hygiene fact reconciles the session to surviving facts. Validation passed:
  `scripts/test-simulator.sh -only-testing:OhanaTests/QuestManagerBatchAwardTests`
  (9 tests),
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/QuestManagerBatchAwardTests -only-testing:OhanaTests/SharedCareSessionMaintenanceTests -only-testing:OhanaTests/SharedPetActionRecorderTests -only-testing:OhanaTests/CalendarTaskCompletionSyncServiceTests -only-testing:OhanaTests/TodayFocusCommandTests -only-testing:OhanaTests/ReminderActionCoordinatorTests`
  (55 tests), `scripts/audit-economy-boundaries.sh --all`,
  `scripts/tests/run-audit-fixture-tests.sh`, `scripts/dev-check-changed.sh`
  (exit 0; derived-state lifecycle checklist warnings only), and
  `git diff --check`. `QuestManagerBatchAwardTests` was rerun after SwiftFormat
  and remained PASS (9 tests). Economy remains 🟢 until a separate fresh pure
  adversarial review reports P0/P1=0.

### TFU-20260613-016 - Stop memorial calendar completion derived effects after Economy pure review

- Status: Done
- Priority: P2
- Area: Economy / Calendar / Today Focus / Notifications / Care Ledger / Batch
  Compatibility
- Source task: Economy fresh pure adversarial review, 2026-06-13; Codex pure
  review session after TFU-20260613-015 repair. Reconfirmed and expanded by
  the follow-up Codex pure review session requested as "全新纯复审".
- Blocker: 本轮纯复审发现 deceased pet 的 Calendar / Today Focus / notification
  historical care completion 仍把 fact-only 误当作完成成功。`CalendarTaskCompletionSyncService.syncPetTask`
  在 `CareFactWriteDisposition.memorialHistoricalFactOnly` 下会写历史
  `PetCareLog` / `PetPottyLog` / `PetHygieneLog`，各 insert helper 因
  `allowsDerivedEffects == false` 跳过 reward / ledger，但 `syncPetTask` 仍返回
  `true`。上层 `CalendarEventCommandService.toggleCompletion` 随后会设置
  occurrence completed、同步 reminder；`ReminderActionCoordinator` 也会继续
  `reminderCompletion.complete` 并返回 `.completed`；Calendar executor 会发布成功
  revision。违反 G4/G4.1 与入口矩阵里 "deceased historical fact-only 只写事实，无
  reward / ledger / reminder / revision / Oasis 派生" 的约束。撤销路径还只能
  通过 generated `CareLedgerEvent` 找回生成 fact；memorial fact-only 不写 ledger，
  因而 reopen / undo 清不掉该历史 fact，重复开关会重复写历史事实。第二条 P1：
  R5 `reward-direct-care-discipline` allowlist 仍对
  `CalendarTaskCompletionSyncService.awardGeneratedCare` 按函数名放行，但该函数自身
  没有消费 `CareFactWritePolicy` / disposition；`scripts/audit-economy-boundaries.sh --all`
  仍会 PASS，不能证明同函数先过 disposition。附带 P2：legacy
  `QuestManager.batchAward` 的 non-litter potty / hygiene 修复仍在
  `QuestManager+BatchAward` 私有 helper 内直接写 fact / ledger / reminder / revision，
  没有委托 shared / single typed chokepoint，且不生成 `SharedCareSession`；当前测试只
  证明奖励不倍增，未证明入口族结构收口。
- Next step: Code repair is complete. Open the required fresh pure adversarial
  Economy review; P0/P1=0 in that separate review is required before Economy can
  be marked 🏁.
- Close condition: Satisfied for the TFU code repair. Economy remains 🟢 until a
  later fresh pure adversarial review independently reports P0/P1=0.
- Repair update 2026-06-13: P1 portion fixed locally. `CalendarTaskCompletionSyncService.syncPetTask`
  now returns a typed `PetTaskSyncResult`, so Calendar / Today Focus / notification
  callers distinguish active completion from memorial historical fact-only. Deceased-pet
  historical completion now writes at most one history fact, does not complete occurrence
  or reminder, does not publish success revision, and reopen can remove legacy no-ledger
  fact-only records. R5 now requires `CalendarTaskCompletionSyncService.awardGeneratedCare`
  to consume `CareFactWritePolicy.disposition` in the same function, and the bad fixture
  includes an allowlisted-without-disposition `awardGeneratedCare` case. Validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/HomeCommandExecutorTests -only-testing:OhanaTests/ReminderActionCoordinatorTests -only-testing:OhanaTests/EconomyBackdateSettlementTests -only-testing:OhanaTests/QuestManagerBatchAwardTests -only-testing:OhanaTests/RecurringFindingsRepairTests`
  PASS (214 tests), `scripts/audit-economy-boundaries.sh --all` PASS,
  `scripts/tests/run-audit-fixture-tests.sh` PASS, `scripts/dev-check-changed.sh` PASS
  with derived-state checklist warnings only, and `git diff --check` PASS.
- Closed: 2026-06-14 修复落地。Legacy `QuestManager.batchAward` non-litter potty
  / hygiene now delegates to `SharedPetActionRecorder` with typed shared child
  strategies. Non-litter potty creates one `SharedCareSession`, per-pet
  `PetPottyLog` facts linked by `sharedSessionId`, per-fact potty ledger, one
  shared reward, reminder handoff, Oasis sync, and shared revision through the
  recorder. Hygiene creates one `SharedCareSession`, per-pet `PetHygieneLog`
  facts, per-fact hygiene ledger, one shared reward, reminder handoff, Oasis
  sync, and shared revision through the recorder; the session points at the
  first hygiene log through `primaryLegacyModelName/Id` because `PetHygieneLog`
  has no schema field for `sharedSessionId`. `QuestManagerBatchAwardTests` now
  assert the session action kind, target set, primary legacy model, potty
  session linkage, per-fact ledger, and single shared reward. Validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/QuestManagerBatchAwardTests`
  PASS (5 tests);
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/HomeCommandExecutorTests -only-testing:OhanaTests/ReminderActionCoordinatorTests -only-testing:OhanaTests/EconomyBackdateSettlementTests -only-testing:OhanaTests/QuestManagerBatchAwardTests -only-testing:OhanaTests/RecurringFindingsRepairTests`
  PASS (214 tests); `scripts/audit-economy-boundaries.sh --all` PASS;
  `scripts/tests/run-audit-fixture-tests.sh` PASS; `scripts/dev-check-changed.sh`
  PASS with existing derived-state checklist warnings only; `git diff --check`
  PASS. Economy stays 🟢 and still requires a fresh pure adversarial review
  before 🏁.

### TFU-20260613-015 - Restore single-walk care ledger consistency after Economy pure review

- Status: Done
- Priority: P1
- Area: Economy / Walks / Care Ledger / Audit Guardrails
- Source task: Economy fresh pure adversarial review, 2026-06-13; Codex pure
  review session after TFU-014 structural hardening.
- Blocker: 本轮纯复审发现单宠遛狗仍保留半笔账根因。`PetWalkingManager.stop`
  的 single-target 分支先写 `PetWalkLog`，再经
  `EconomyRewardDiscipline.awardCareAction(.walk)` 写钱包奖励和预算占用，但没有
  为该 `PetWalkLog` 写 `CareLedgerEvent(eventKind: .walk)`；只有遛狗中 poop marker
  会写 potty ledger。共享遛狗通过 `CareEventService.recordSharedWalk` /
  `SharedPetActionRecorder` 会写 walk ledger，所以同一 walk 业务动作在单宠与共享
  入口账本语义不等价，违反 G1/G2 与 Economy 入口矩阵。现有测试
  `singleWalkPersistsWalkFactBeforeWalletRewardAndLinksPottyMarkers` 只断言 potty
  ledger，未断言 walk ledger；`scripts/audit-economy-boundaries.sh --all` 也无法抓
  "事实+奖励但缺 care ledger"。
- Next step: 将 `PetWalkingManager.stop` single-target 分支改为与共享 walk 一样在
  `PetWalkLog` 和 wallet reward 成功后写一条 walk `CareLedgerEvent`，并把
  `coconutsEarned` / `coconutDelta` / metadata 与 reward 保持一致；补红测覆盖
  single walk 无 poop 时也必须有 walk ledger，single walk 有 poop 时必须同时有
  walk ledger + potty ledger，且 recycled/frozen executor 仍全 no-op。同步补审计或
  入口族测试，防止以后只测 shared walk。
- Close condition: single walk / shared walk / walk poop 目标测试通过；
  `scripts/audit-economy-boundaries.sh --all`、`scripts/tests/run-audit-fixture-tests.sh`、
  `git diff --check` 通过；修复后再开全新纯对抗复审，P0/P1=0 才可标 Economy 🏁。
- Closed: 2026-06-13 修复落地。`PetWalkingManager.stop` single-target 分支为
  `PetWalkLog` 写入 walk `CareLedgerEvent`，并保持 reward metadata /
  `coconutDelta` / `coconutsEarned` 一致；`QuestManager.batchAward` 的 non-litter
  potty、hygiene 与 custom general litter 改为事实族 + 单次 shared reward + per-fact
  ledger。验证通过：
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/QuestManagerBatchAwardTests`、
  `scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、`git diff --check`。Economy 仍需后续
  全新纯对抗复审 P0/P1=0 才可标 🏁。

### TFU-20260613-014 - Close remaining Economy no-op leaks after TFU-013

- Status: Done
- Priority: P1
- Area: Economy / Feeding / Calendar / Today Focus / Walks / Health / Medication /
  DashboardRecords / Audit Guardrails
- Source task: Economy pure adversarial re-review after TFU-20260613-013 repair,
  2026-06-13; Codex pure review session, CI intentionally ignored.
- Blocker: 本轮纯复审发现 TFU-013 仍未把 G4/G4.1 no-op 语义传播到所有事实 /
  command / revision 边界。`recordTreatFeed` 返回 detached `PetCareLog` 但不暴露
  `didWriteFact`，Treat feed 和 QuickFeed manual no-op 仍会发布成功 feed mutation；
  planned manual feed 在事实 no-op 后仍会重建库存提醒，通知动作仍返回 `.completed`。
  Calendar / Today Focus 对 pet-task no-op 会返回 unchanged result，但执行器 / Home
  继续发布 `wroteBusinessFact: true` mutation 和成功反馈。R5 函数级 allowlist 仍放行
  `PetWalkingManager.stop`、`WeightCommandService.recordPetWeight`、
  `PetMedicationDoseLogging.recordDose`、`PetHealthCommandService.recordHealth` 等
  direct `EconomyRewardDiscipline` 调用点，这些函数没有先消费
  `CareFactWritePolicy.disposition`，因此 recycled/frozen executor 或部分 frozen target
  仍可写事实、ledger、reminder/Oasis/库存等派生，最多只是 wallet reward 被跳过。
- Next step: 将 `CareFactWriteDisposition` 或等价 typed result 扩到 Treat feed、
  planned feed、Calendar/Today Focus completion、single walk、weight、pet medication
  dose、pet health 等 R5 allowlisted care-fact 函数；所有调用方在 no-op 或
  historical fact-only 时必须停止 revision、success feedback、stock/reminder/plan、
  Oasis、ledger 和 reward 派生。收紧 `scripts/audit-economy-boundaries.sh`：覆盖
  `recordTreatFeed` / `completePlannedFeed`，并要求 R5 allowlisted functions 在直调
  `EconomyRewardDiscipline` 前同函数消费 `CareFactWritePolicy` / disposition。
- Close condition: 新增 in-memory tests 覆盖 active pet + recycled/deceased executor
  的 Treat feed、QuickFeed manual、planned feed notification、Calendar executor、
  Today Focus executor、single walk、walk poop、weight、pet medication dose、pet
  health no-op；覆盖 deceased target historical fact-only 只写事实且无 ledger/reward/
  derived；覆盖 recycled target 全 no-op。验证无 `Pet*Log` / `Event` / `Reminder` /
  `CareLedgerEvent` / `CoconutLedgerEntry` / `EconomyBudgetUsageEvent` / Domain
  revision / success feedback / stock-reminder / Oasis 派生（历史事实-only 例外只保留
  事实）。相关目标测试、`scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、`scripts/dev-check-changed.sh` 与
  `scripts/module-exit-gate.sh` 通过后，再开全新纯复审；P0/P1=0 才可标 Economy 🏁。
- Repair update 2026-06-13: TFU-014 修复实现已落地。Treat / planned feed、
  Calendar / Today Focus、notification completion、single walk、weight、pet
  medication dose、pet health 的 no-op / historical fact-only 语义已继续向 command、
  revision、feedback、ledger、reminder/stock/Oasis 派生传播；R5 allowlisted
  `EconomyRewardDiscipline` 调用点改为先消费 `CareFactWritePolicy` / typed
  disposition；`reward-direct-care-discipline-disposition` 与 expanded
  `care-fact-disposition-unconsumed` 审计/fixture 已补。验证：目标测试 204 PASS，
  `scripts/audit-economy-boundaries.sh --all` PASS，`scripts/tests/run-audit-fixture-tests.sh`
  PASS，`scripts/dev-check-changed.sh` PASS，`git diff --check` PASS。仍保持 Open：
  `scripts/module-exit-gate.sh` 后续已在结构补强会话通过；Economy 必须再经全新纯复审 P0/P1=0 后才可 🏁。
- Structural hardening update 2026-06-13: Codex implementation/self-review session
  completed the higher exit checklist without granting maturity. Added
  `docs/planning/economy-care-entrypoint-matrix.md`; migrated legacy
  `QuestManager.batchAward` to typed care chokepoints; gated `FeedAutoLogMaterializer`,
  CatCare command/revision, and medication UI feedback on typed no-op results; added
  `QuestManagerBatchAwardTests` and `pet-medication-dose-result-unconsumed` audit
  coverage. Validation: targeted simulator suites 214 PASS,
  `scripts/module-exit-gate.sh` PASS,
  `scripts/audit-economy-boundaries.sh --all` PASS,
  `scripts/tests/run-audit-fixture-tests.sh` PASS,
  `scripts/dev-check-changed.sh` PASS, `git diff --check` PASS. This was not the
  required fresh pure adversarial review; TFU remains Open and Economy stays 🟢.
- Closed: 2026-06-24 stale tracker correction. Later Economy final review and
  CI evidence in `docs/testing-progress.md` show this no-op leak family was
  superseded by the 2026-06-14 Economy P0=0 / P1=0 / P2=0 closure. Refreshed
  local validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/CareDerivationExecutorSuccessCharacterizationTests -only-testing:OhanaTests/RecurringFindingsRepairTests -only-testing:OhanaTests/ReminderActionCoordinatorTests -only-testing:OhanaTests/CatCareCommandTests`
  PASS（58 tests，iPhone 17 simulator）。

### TFU-20260613-013 - Propagate Economy fact no-op to care command layers

- Status: Done
- Priority: P1
- Area: Economy / QuickCare / Feeding / Frozen Lifecycle / Command Side Effects
- Source task: Economy repair follow-up re-review after TFU-20260613-012 implementation,
  2026-06-13
- Blocker: 本轮复审发现 TFU-012 把 G4.1 硬门收到 `CareEventService` /
  `SharedPetActionRecorder` 后，部分 command 层仍把 no-op 当成功：active pet + recycled
  executor 时，`QuickPlayCommandExecutor` / `QuickPottyCommandExecutor` /
  `QuickWaterCommandExecutor` / Home expanded quick actions 会先拿到服务层 detached
  no-op result，再发布 `wroteBusinessFact: true` mutation、返回不存在的 log id 或继续保存
  water-change/filter plans。Feeding 的 `ManualFeedCommand.recordManual` 还会在事实层
  no-op 前修改 `pet.mainFoodKind` / `dailyPortionGrams`，并在 no-op / 离世历史事实-only
  后重建库存提醒、返回 `didRecord: true`；`recordTreat` 同样无条件发布 feed mutation。
- Next step: 让照护命令层消费事实写入结果或共享同一 preflight：回收 executor / 回收
  target 必须整体 no-op（不发布 revision、不返回 fake log id、不保存计划 / reminder /
  stock 派生、不改默认喂食设置）；离世历史事实只允许事实写入，命令层不得追加设置、
  reminder、stock、quest、Oasis 等派生。优先用 `CareFactWriteDisposition` 或服务 result
  显式表达 `didWriteFact` / `allowsDerivedEffects`，避免调用方用 reward==0 猜状态。
- Close condition: 新增 in-memory tests 覆盖 active pet + recycled executor 的
  QuickPlay / QuickPotty / QuickWater / Home / Feeding no-op 路径，以及 deceased pet
  historical feeding fact-only 路径；验证无 `Pet*Log` / `CareLedgerEvent` /
  `CoconutLedgerEntry` / `EconomyBudgetUsageEvent` / Domain revision / plan-reminder
  派生（历史事实-only 例外只保留事实）。相关目标测试、`scripts/dev-check-changed.sh`、
  `scripts/audit-economy-boundaries.sh --all`、`scripts/tests/run-audit-fixture-tests.sh`
  与 `scripts/module-exit-gate.sh` 通过后，再开全新纯复审清零 P0/P1。
- Repair note: 2026-06-13 repair session implemented typed fact disposition
  consumption across QuickPlay / QuickPotty / QuickWater / Home expanded quick
  actions, ManualFeed, PetCare, and PetHygiene command layers; no-op now returns
  nil / `didRecord: false`, avoids fake log IDs, revisions, plans / reminders,
  stock/default setting mutations, and feedback. Executor write policy now uses
  `EconomyWalletWritePolicy.canWrite` for recycled/deceased humans. Added
  `care-fact-disposition-unconsumed` audit with fixture. Passing validation:
  targeted simulator suites (`HomeCommandExecutorTests`, `QuickWaterCommandTests`,
  `ManualFeedCommandTests`, `CareCompletionChokepointCharacterizationTests`) 200
  tests, `scripts/audit-economy-boundaries.sh --all`,
  `scripts/tests/run-audit-fixture-tests.sh`, `scripts/dev-check-changed.sh`,
  `git diff --check`, and `scripts/module-exit-gate.sh` PASS. Still requires a
  fresh pure adversarial re-review before this TFU can close / Economy can be 🏁.
- Closed: 2026-06-24 stale tracker correction. Later Economy final review and
  CI evidence in `docs/testing-progress.md` show this command-layer no-op family
  was superseded by the 2026-06-14 Economy P0=0 / P1=0 / P2=0 closure.
  Refreshed local validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/CareDerivationExecutorSuccessCharacterizationTests -only-testing:OhanaTests/RecurringFindingsRepairTests -only-testing:OhanaTests/ReminderActionCoordinatorTests -only-testing:OhanaTests/CatCareCommandTests`
  PASS（58 tests，iPhone 17 simulator）。

### TFU-20260613-012 - Repair post-7845db4c7 Economy hard-gate review findings

- Status: Done
- Priority: P1
- Area: Economy / Care Completion / Frozen Lifecycle / Audit Guardrails
- Source task: Economy pure adversarial re-review after `7845db4c7`, 2026-06-13
- Blocker: 本轮纯复审发现 Economy P1 修复轮仍未把 G4.1 冻结边界收进事实写入
  收口：`CareEventService.recordCareFact` / `recordManualFeedFact` / `recordPotty` /
  `recordHygieneFact` 等会先插入事实，再由奖励层 no-op；回收宠作为 source 或单目标
  仍可写 `PetCareLog` / `PetPottyLog` / ledger / reminder 派生。共享入口过滤后
  `liveTargets.count <= 1` 时回退到 `sourcePet` 单宠路径，source 已回收或过滤结果为空也
  不是整体 no-op。Calendar / Today Focus / 通知完成路径也只 fetch pet，不用
  `EconomyWalletWritePolicy.canWrite` 拦截回收对象。R5 `reward-direct-care-discipline`
  审计以整文件 allowlist 放行 `CalendarTaskCompletionSyncService`、`PetMedicationDoseLogging`、
  `PetHealthCommands`、`PetWalkingManager`、`DashboardRecordCommands`，同文件新增裸
  `EconomyRewardDiscipline.awardCareAction` 坏例不会被抓。
- Next step: 在事实写入收口层统一实现 G4.1：回收 target / executor 整体 no-op，不写
  fact / ledger / session / reminder 派生；离世 target 只允许历史照护事实且不发奖、不推进
  reminder / quest / streak / Oasis 等派生；显式冻结 executor 继续奖励 no-op 且不回落 active
  human。修复共享入口的空过滤结果与 source 回收退回单宠路径；Calendar / Today Focus /
  通知 completion 的 pet resolver 改用 `EconomyWalletWritePolicy.canWrite` 或等价生命周期
  门。R5 改为函数/块级 allowlist 或语义检查，并加一个位于现有 allowlisted 文件内的 bad
  fixture，证明同文件裸 discipline 调用会失败。
- Close condition: 新增 in-memory tests 覆盖 recycled source / recycled single target /
  deceased historical-only no-derived / Calendar-or-notification recycled pet completion no-op；
  新增 R5 bad/good fixture 覆盖 allowlisted 文件内新坏例；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、相关目标测试与 `scripts/module-exit-gate.sh`
  通过，并由全新纯复审会话确认 P0/P1=0 后 Economy 才可标 🏁。
- Repair note: 2026-06-13 repair session implemented G4.1 fact-write policy gates,
  shared-care empty/source-recycled no-op handling, Calendar/reminder pet completion no-op,
  QuickCare command-boundary recycled-object no-op, and function-level
  `reward-direct-care-discipline` allowlist. Passing validation: targeted simulator
  suites, `scripts/dev-check-changed.sh`, `scripts/audit-economy-boundaries.sh --all`,
  `scripts/tests/run-audit-fixture-tests.sh`, and `git diff --check`. `scripts/module-exit-gate.sh`
  passed changed checks/localization but its full unit step was blocked by local
  CoreSimulatorService `connection refused` after targeted simulator suites had passed;
  rerun module gate when CoreSimulator is available, then open a fresh pure re-review
  before closing this TFU / marking Economy 🏁.
- Closed: 2026-06-24 stale tracker correction. Later Economy final review and
  CI evidence in `docs/testing-progress.md` show this hard-gate family was
  superseded by the 2026-06-14 Economy P0=0 / P1=0 / P2=0 closure. Refreshed
  local validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/CareDerivationExecutorSuccessCharacterizationTests -only-testing:OhanaTests/RecurringFindingsRepairTests -only-testing:OhanaTests/ReminderActionCoordinatorTests -only-testing:OhanaTests/CatCareCommandTests`
  PASS（58 tests，iPhone 17 simulator）。

### TFU-20260613-011 - Repair post-chokepoint Economy P1 findings

- Status: Done
- Priority: P1
- Area: Economy / Care Completion / Audit Guardrails
- Source task: Economy post-chokepoint adversarial review, 2026-06-13
- Blocker: 本轮纯对抗复审发现 4 条 P1：显式 executor 已离世或回收时
  `EconomyRewardOwnerResolver` 会回退 active human；Calendar/通知补完成历史
  occurrence 时奖励按历史事实日进入预算/冷却；共享照护 target resolver 过滤
  `hasPassedAway` 但未过滤 `trashedAt`；R5 fixture 把无事实/ledger 的
  `EconomyRewardDiscipline.awardCareAction` 直调当作 Good，不能证明 ECO-024
  的两家族纪律。
- Next step（含 2026-06-13 产品决策 G4.1 / ECO-026 / ECO-027）：
  根因归组——P1-1 与 P1-3 同根因（冻结门只在奖励层、事实层漏做），统一修：
  在事实写入收口持有冻结门，**离世可补记历史事实但不发奖不派生、回收整体 no-op、
  executor 冻结时奖励 no-op 且不回落 active human**（删除 `?? activeHuman` 回落，
  改为显式 executor 无效/冻结即 no-op）；共享 target 用 `canWrite` 同时过滤
  `hasPassedAway` 与 `trashedAt`。P1-2 独立修：Calendar/通知完成路径事实日期与
  奖励操作日分离，奖励按操作当日 dayKey 结算（ECO-027）。P1-4 独立修：收紧 R5
  fixture 与审计，让家族 1 只能经 care fact 收口、家族 2 必须伴随自己的事实+ledger，
  Good fixture 不得放行无事实/ledger 的 discipline 直调。
- Close condition: 新增覆盖四条复现的 in-memory tests 与 bad/good audit
  fixture，`scripts/audit-economy-boundaries.sh --all`、`scripts/tests/run-audit-fixture-tests.sh`
  和相关目标测试通过，并由全新纯复审会话确认 P0/P1=0 后才允许 Economy 标 🏁。
- Closed: 2026-06-13 修复轮完成。P1-1/P1-3 红测覆盖冻结 executor 不回落
  active human、共享照护过滤回收 target；P1-2 红测覆盖 Calendar 历史 occurrence
  事实日与奖励操作日分离；P1-4 fixture/audit 覆盖裸
  `EconomyRewardDiscipline.awardCareAction` 不再作为 Good。目标测试、
  `scripts/tests/run-audit-fixture-tests.sh`、`scripts/dev-check-changed.sh`、
  `scripts/module-exit-gate.sh` 均通过。Economy 总账仍保持 🟢，需另开全新纯复审
  会话确认 P0/P1=0 后才可标 🏁。

### TFU-20260613-010 - Re-audit expense-logging coconut reward (farm-risk)

- Status: Done
- Priority: P2
- Area: Economy / Reward Policy
- Source task: Care-completion chokepoint plan review, 2026-06-13
- Blocker: 记录花费当前会产出椰子奖励，存在"记假账→刷椰子"的潜在 farm 向量。
  D2 中间路线要求经济自洽防刷。本项与照护完成收口重构正交（收口只统一发奖
  纪律，不改"是否发奖"的策略）。
- Next step: 在 Economy 奖励策略复查中决定花费记录是否应发奖、是否限额或仅
  在有真实金额/凭证时发奖；与 ECO-025 对应。
- Close condition: 花费奖励策略明确并落地（发奖/限额/不发奖三选一），ECO-025
  从"待复查"转为已确认决策。

### TFU-20260613-009 - Burn down recurring-findings audit baseline debt

- Status: Done
- Priority: P1
- Area: Governance / Economy Boundaries / Derived State Lifecycle
- Source task: Recurring findings audit mechanization, 2026-06-13
- Blocker: Resolved. `docs/governance/manifests/recurring-findings-audit-baseline.json`
  now records a zero-warning baseline for both recurring-findings audits.
- Progress: 2026-06-13 TFU repair round burned down the Economy executor
  baseline from 5 to 0, removed the owned Calendar / CatCare physical-delete
  baseline warnings, and added service-layer tombstones for the PetCare /
  Hygiene / DashboardRecords `CareLedgerEvent` delete paths. At that point, the
  remaining 63 derived-state warnings were still unowned baseline debt and
  required future module repair or explicitly approved allow comments before
  this TFU could close.
  Second 2026-06-13 repair round closed the owned Economy / GAP-2 P1 findings
  from the second adversarial review: Calendar / Today Focus / notification care
  completion now enters the care fact + reward pipeline, Calendar occurrence
  undo writes reversal / tombstone facts, CarePlan / Feeding / Water plan deletes
  write upload-pipeline tombstones, and SymptomLog / HeatCycleLog now direct
  delete with tombstones while PetHealthLog remains recoverable.
- Progress: 2026-06-24 final cleanup removed the remaining derived-state
  baseline debt without approved allow comments: the audit no longer misclassifies
  pure `delete` command enum cases or route/UI command-executor triggers as
  physical deletes, FamilyTasks delegated deletes remain covered by
  `DomainMemberFactWriter.deleteFamilyTask`, Hygiene / Calendar physical deletes
  remain covered inside their command/service boundaries, and
  `EconomyDailyBudgetStore.pruneOldUsageEvents` now writes a
  `EconomyBudgetUsageEvent` CloudSync tombstone before pruning old rows.
- Closed: 2026-06-24. Verification: `scripts/tests/run-audit-fixture-tests.sh`
  PASS; `scripts/audit-derived-state-lifecycle.sh --all` PASS (846 files);
  `scripts/audit-economy-boundaries.sh --all` PASS (846 files);
  `scripts/audit-derived-state-lifecycle.sh --update-baseline` refreshed
  `docs/governance/manifests/recurring-findings-audit-baseline.json` to
  `economy-boundaries = 0` and `derived-state-lifecycle = 0`;
  `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests`
  PASS (183 tests, iPhone 17 simulator, xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_01-58-46-+0200.xcresult`).

### TFU-20260613-008 - Green architecture boundary audit or refresh ratchet baseline

- Status: Done
- Priority: P1
- Area: CI / Architecture Boundaries
- Source task: CI repair round close-out, 2026-06-13
- Blocker: GitHub Actions run `27452421109` proves `lint` and `build-test`
  are green on `33f32ef1a`, but the `audits` job still fails only at
  `scripts/audit-architecture-boundaries.sh --all`. The current failure groups
  are `@Query` outside route/data containers, `NotificationCenter` string bus,
  View-to-static service calls, oversized Swift file ratchet breaches, and
  static service calls outside approved adapter/facade/backfill boundaries.
  Reconfirmed on run `27463715466` after the Phase 7 Gacha+Shop and process/CI
  commits: `build-test` and `lint` are green; `audits` still stops at
  architecture boundaries. New/worsened signals to fold into the repair round
  include `CoconutShopView+Commands.swift` calling
  `ShopPurchaseFulfillmentService` statically from a View extension, plus
  ratchet growth in Gacha/CloudSync/backup/schema files touched by the
  Gacha+Shop round.
- Next step: Run a separate architecture-audit green/baseline repair round.
  Decide per failure whether to move code behind approved boundaries or refresh
  a deliberate ratchet baseline, with focused commits and no TFU-006/007 scope
  creep.
- Close when: `scripts/audit-architecture-boundaries.sh --all` passes locally
  and the GitHub Actions `audits` job reaches the later repository gates instead
  of stopping at architecture boundaries.
- Closed: 2026-06-13 in the architecture boundary repair round. Local
  `scripts/audit-architecture-boundaries.sh --all` passed after moving `@Query`
  ownership behind data containers, replacing the online-gate `NotificationCenter`
  string bus with a typed publisher, routing static service calls through
  `AppServices`/infrastructure adapters, and deliberately refreshing the
  oversized Swift file ratchet baseline. Follow-up CI script pin drift was fixed
  in `69658a888`; GitHub Actions run `27464485820` on `90ee16ba4` passed
  `audits`, `lint`, and `build-test`.

### TFU-20260613-007 - Fix CI build-test compiler failures outside Economy

- Status: Done
- Priority: P1
- Area: CI Build / Recycle Bin / FamilyTasks
- Source task: Economy adversarial P1 remediation close-out, 2026-06-13
- Blocker: The Economy remediation head passed the local module exit gate, but
  GitHub Actions `build-test` still fails before tests on pre-existing
  non-Economy compiler surfaces. Observed failures include `Ambiguous use of
  'cos'` in
  `Ohana/Features/FamilyTasks/Views/FamilyCollaborationDashboardView+Map.swift`
  on `006ae323e`, and a Swift type-check timeout at
  `trashed(PetPhotoLog.self, context: context)` in
  `Ohana/Domain/Services/RecycleBinService.swift` on `af316974f`.
- Next step: In a CI unblock pass, repair the currently surfaced compiler
  blocker, rerun `build-test`, and repeat until the job reaches the simulator
  test suite rather than stopping at Swift compile.
- Close when: GitHub Actions `build-test` reaches and completes the simulator
  test suite on the iPhone 17 destination for the current main branch.
- Closed: 2026-06-13 in the CI repair round. Run `27452421109` on commit
  `33f32ef1a` completed `build-test` successfully on the iPhone 17 simulator.
  The final CI-only crash was isolated to `CoconutExchangeService.cancel`
  constructing default wallet dependencies before the closed feature gate; the
  service now checks the gate before default dependency creation.

### TFU-20260613-006 - Refresh CI tool-version pins or install pinned tools

- Status: Done
- Priority: P1
- Area: CI / Tooling
- Source task: Economy adversarial P1 remediation close-out, 2026-06-13
- Blocker: GitHub Actions `audits` and `lint` stop at
  `scripts/check-tool-versions.sh` before repository audits/lints run because
  Homebrew installs newer major/minor tools than `scripts/ci-tool-versions.env`
  allows: `rg 15.1.0` vs pin `14`, `swiftlint 0.63.2` vs pin `0.61`, and
  `swiftformat 0.61.1` vs pin `0.57`.
- Next step: Either install the pinned CI tool versions explicitly or review
  the changelogs and deliberately bump `scripts/ci-tool-versions.env` with
  fixture/audit confirmation.
- Close when: GitHub Actions `audits` and `lint` pass their tool-version step
  and run the real repository gates on main.
- Closed: 2026-06-13 in the CI repair round. Tool pins were refreshed in
  `12078b7ff`; run `27452421109` passed both `audits` and `lint` tool-version
  steps. Local verification also passed `scripts/check-tool-versions.sh
  swiftlint` with SwiftLint `0.63.3`.

### TFU-20260613-005 - Add V68/V69 recycle-bin migration coverage

- Status: Done
- Priority: P2
- Area: Models / Migration / Recycle Bin
- Source task: RecycleBin adversarial P1 remediation, 2026-06-13
- Blocker: The V69 schema shape and empty migration stages remain acceptable,
  but current disk-migration coverage does not prove old V68/V69 stores receive
  usable recycle-bin soft-delete defaults or that `RecycleBinBatch` is available
  after migration.
- Next step: Add a disk migration fixture/test from pre-recycle-bin stores that
  opens through the latest `ArkMigrationPlan`, checks member/archive soft-delete
  default values, and creates/restores a `RecycleBinBatch`.
- Close when: The migration test proves V68/V69-era stores open cleanly with
  recycle-bin fields defaulted and batch rows usable.

### TFU-20260613-004 - Restore pet quick-access derived state

- Status: Open
- Priority: P2
- Area: Recycle Bin / Members / Quick Actions
- Source task: RecycleBin adversarial P1 remediation, 2026-06-13
- Blocker: Member deletion removes pet quick-access entries, while recycle-bin
  restoration currently restores source objects, events, reminders, and
  notifications, but does not restore or recompute that quick-access derived
  state.
- Next step: Define the intended product behavior for restored pets, then either
  recreate the previous quick-access entry or explicitly recompute the default
  quick-access set during pet restore.
- Close when: A restored pet has the approved quick-action availability and a
  focused test prevents regression.

### TFU-20260613-003 - Round-trip recycle-bin soft-delete fields in CloudSync

- Status: Open
- Priority: P2
- Area: Recycle Bin / CloudSync / Future Online Unlock
- Source task: RecycleBin adversarial P1 remediation, 2026-06-13
- Blocker: First release keeps CloudKit off, but future sync still needs
  recycle-bin soft-delete fields (`trashedAt`, `trashExpiresAt`,
  `trashBatchId`, `trashedByHumanId`) to serialize, apply, and reconcile
  consistently across devices.
- Next step: Before CloudKit unlock, extend `CloudSyncRecordSerializer`,
  apply/import paths, and registry tests so soft-delete state round-trips for
  recoverable entities and bulk-clear batches.
- Close when: A remote soft delete and a remote restore both reproduce the same
  recycle-bin state locally without premature tombstones.

### TFU-20260613-002 - Re-audit FamilyTasks bounty wallet transfer before unlock

- Status: Done
- Priority: P2
- Area: Economy / FamilyTasks / Online Unlock
- Source task: Economy adversarial P1 remediation, 2026-06-13
- Blocker: FamilyTasks is hidden behind the first-release online feature gate,
  but its bounty completion path still owns wallet-transfer behavior and
  rollback/error handling that was not repaired in the Economy P1 scope.
- Next step: Before any future FamilyTasks/online unlock, re-review the bounty
  transfer command boundary, rollback semantics, idempotency key, and user-visible
  failure behavior with focused tests.
- Close when: FamilyTasks bounty transfer either passes the same economy wallet
  invariants as shop / care rewards or is replaced by a safer service boundary
  before the feature becomes reachable.
- Closed: 2026-06-13 in the Economy P1 remediation round. FamilyTasks bounty
  completion now calls the shared human wallet mutation writer, returns `false`
  on transfer failure, restores the task to pending review, and leaves no wallet
  or care-ledger rows; `familyTaskBountyTransferFailureLeavesReviewPendingWithoutLedger`
  covers the failure path. Future online unlock still requires product/UI review,
  but this Economy P2 code debt is closed.

### TFU-20260613-001 - Retire legacy economy system-wallet write fallbacks

- Status: Done
- Priority: P2
- Area: Economy / Legacy Wallet APIs
- Source task: Economy adversarial P1 remediation, 2026-06-13
- Blocker: The active P1 repeatable reward paths no longer use legacy special
  rewards, but `QuestManager+LegacyWallet` still contains compatibility APIs
  whose fallback semantics can write to system/fallback wallets if future code
  reuses them carelessly.
- Next step: Run a focused legacy API retirement pass: remove unused entry
  points where possible, add compile/test guardrails for the remaining migration
  paths, and document the approved owner-resolution rule.
- Close when: No production reward caller can accidentally create or credit a
  system/fallback wallet through legacy helpers, and focused tests cover the
  intentionally retained compatibility cases.
- Closed: 2026-06-13 in the Economy P1 remediation round. Legacy wallet helpers
  now resolve to a writable human/pet, fall back only to the current active
  human, and no-op when no formal writable owner exists. The old `ActionType`
  compatibility fallback no longer credits system wallets. Regression tests
  cover actor-less legacy grants with and without an active human.

### TFU-20260612-022 - Add final Settings privacy and support actions

- Status: Open
- Priority: P2
- Area: Settings / About / Release Links
- Source task: Settings + Health Phase 6 remediation, 2026-06-12
- Blocker: The final public privacy-policy URL and owner-approved support
  contact channel are not both available in the repository. The release
  Settings screen now hides empty About actions instead of exposing dead rows.
- Next step: Provide the final privacy URL and support contact route, then add
  localized About rows that open real destinations.
- Close when: Settings About shows only actionable privacy/support entries and
  a lightweight validation proves each row opens the intended destination.

### TFU-20260612-021 - Audit deleted-human wallet and ledger visibility

- Status: Done
- Priority: P1
- Area: Economy / Members / Recycle Bin
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: Members now preserves human-scoped data during the 30-day recycle
  period and purges confirmed human-owned side rows at expiry, but deleting
  CoconutAccount / CoconutLedgerEntry ownership or hiding purged humans from
  formal asset and ledger projections belongs to the Economy module boundary.
- Next step: In the Economy phase, verify that recycled or permanently purged
  humans do not appear as active wallet owners, asset rows, rankings, or reward
  write targets, while historical ledger entries remain understandable.
- Close when: Economy tests and real UI checks prove deleted humans are excluded
  from active asset/ranking/reward surfaces and historical ledger visibility has
  the intended product treatment.
- Closed: 2026-06-12 in Economy Phase 6. `CoconutWalletServiceTests` now prove
  recycled / memorial wallet owners are excluded from active wealth total,
  rankings, and selected balances while hidden privacy wallets still count;
  `CoconutWalletService` and reward command tests reject frozen wallet writes.
  Remaining real UI inspection lives in
  `docs/planning/gap-acceptance-track-list.md#phase-6-economy`.

### TFU-20260612-020 - Finish Members localization coverage

- Status: Open
- Priority: P2
- Area: Members / Localization
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: Members still has a broad set of user-visible hardcoded Chinese
  strings in detail, edit, privacy, and read-only profile surfaces. Fixing it
  cleanly is a larger localization pass outside the P0 deletion/sync repair.
- Next step: Move Members detail/edit/privacy/Pet read content strings onto the
  registered localization path, authoring Chinese and English at minimum and
  preserving the existing fallback chain for other app languages.
- Close when: Members user-facing strings pass the localization audit and the
  main detail/edit/privacy screens remain visually clean in long languages.

### TFU-20260612-019 - Enforce human memorial read-only boundaries

- Status: Open - local command/UI boundary evidence verified; pending broader
  gate, push/CI, and fresh pure review before close.
- Priority: P1
- Area: Members / Memorial / Command Boundaries
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: GAP-9 removed active-flow participation for deceased humans, but
  the Members command layer still allows profile edit, privacy toggles, and
  deletion routes while the UI says "纪念模式 · 只读". A hard boundary needs a
  focused route/command pass to avoid changing memorial behavior by accident.
- Next step: Define the allowed actions for deceased humans, then enforce the
  read-only boundary in Members routes and command services with focused tests.
- Progress: 2026-06-24 current worktree shows the Members side of this boundary
  has been implemented locally: `HumanLifecycleDangerZone` is shared by full
  detail and basic-info surfaces, human mark/undo passed-away actions route
  through `MemberLifecycleCommandService`, profile edits route through
  `MemberProfileCommandService.updateHuman` and `MemberLifecycleGate`, and
  privacy/passcode/settings/presentation/economy writes are denied for deceased
  humans. Verification: `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests` PASS (50 tests, iPhone 17
  simulator), including `deceasedCareAndProfileEditDenyWrites`,
  `deceasedHumanNoteWithReminderWritesMemorialContentOnly`, and
  `deceasedMembersRejectPresentationSecurityEconomyAndSettingsWrites`.
  Destructive deletion remains an explicit lifecycle/data-removal action rather
  than a profile/privacy mutation, so this TFU still waits for the broader close
  gates below.
- Close when: Deceased human profiles cannot be mutated through Members edit /
  privacy / destructive paths unless the action is explicitly allowed, and the
  UI copy matches the command behavior.

### TFU-20260612-018 - Remove duplicate member profile revision publishes

- Status: Open
- Priority: P2
- Area: Members / Domain Revisions / Smoothness
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: `MemberCommandExecutor.update*Profile` already publishes member
  profile revisions, but several view callers publish another revision after
  the executor returns. This is not part of the P0 deletion/sync repair and
  should be fixed as a narrow smoothness/invalidations pass.
- Next step: Remove duplicate view-level revision publishes after confirming the
  executor emits the single intended mutation for Pet/Human edit paths.
- Close when: Each profile save publishes exactly one member profile revision
  and focused tests or an audit prevent the duplicate pattern from returning.

### TFU-20260612-017 - Validate GAP-9 memorial mode on real UI and device notifications

- Status: Open - standard Ohana device signing with Push/iCloud entitlements verified; real-device memorial notification/UI behavior still unverified
- Priority: P1
- Area: Memorial / Notifications / Release Validation
- Source task: GAP-9 memorial exit, 2026-06-12
- Blocker: Repository tests prove data retention, active-flow filtering, undo
  restoration, and reward freeze invariants, and 2026-06-24 standard `Ohana`
  Debug device signing now proves the paid-team Push/iCloud entitlement path
  builds for `Guanchen's iPhone`. It still cannot prove real iOS notification
  cancellation / rescheduling behavior or the final visible memorial experience
  across a real device data set.
- Next step: Run the GAP-9 manual checklist in
  `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`, especially
  marking/undoing a pet, checking notification cancellation and restoration,
  confirming memorial entry visibility, and scanning home/FAB/full-menu
  active targets.
- Close when: The GAP-9 track list's manual section is checked off on a real
  device and any device-specific notification or UI defect is fixed or split
  into its own scoped follow-up.
- Progress: 2026-06-24 standard `Ohana` Debug physical UI smoke moved past the
  old Personal Team blocker: `Ohana.app` and `OhanaUITests-Runner.app` both
  built/signed for iPhoneOS under `Apple Development: guanchen.li.119@gmail.com
  (62Y338Q9SK)`, and the app entitlements still contain `aps-environment =
  development` plus `iCloud.com.guanchen.li.Ohana`. XCTest launch did not start
  because Xcode preflight reported `Unlock Guanchen's iPhone to Continue`; the
  run was cancelled after waiting. This proves the paid-team standard scheme can
  reach the physical UI-test runner build/sign stage, but leaves GAP-9 real UI
  and notification cancellation/restoration unverified.

### TFU-20260612-016 - Validate GAP-6 notification delivery on real devices

- Status: Open - standard Ohana device signing with Push/iCloud entitlements verified; real notification delivery still unverified
- Priority: P1
- Area: Notifications / Release Validation
- Source task: GAP-6 notification classification, 2026-06-12
- Blocker: Repository tests and simulator UI tests can prove scheduling policy,
  ledger visibility, and routing compile paths, and 2026-06-24 standard `Ohana`
  Debug device signing now proves the paid-team Push/iCloud entitlement path
  builds for `Guanchen's iPhone`. They still cannot prove real iOS notification
  delivery, banners, permission prompts, Focus/DND interaction, or notification
  action behavior on physical devices.
- Next step: Run the GAP-6 manual checklist in
  `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级` on a real device
  with notification permission enabled, including routine budget, quiet-hours
  deferral, health-critical delivery, merge behavior, notification actions, and
  weekly report copy.
- Close when: The GAP-6 track list's manual section is checked off on a real
  device and any device-specific delivery or routing defect is either fixed or
  recorded as its own scoped follow-up.
- Progress: 2026-06-24 standard `Ohana` Debug physical UI smoke moved past the
  old Personal Team blocker: `Ohana.app` and `OhanaUITests-Runner.app` both
  built/signed for iPhoneOS, with app entitlements containing
  `aps-environment = development` and `iCloud.com.guanchen.li.Ohana`. XCTest
  launch did not start because Xcode preflight reported `Unlock Guanchen's
  iPhone to Continue`; the run was cancelled after waiting. This does not prove
  notification permission prompts, delivery, Focus/DND, banners, or notification
  actions, so GAP-6 stays Open.

### TFU-20260611-001 - App Store Connect privacy setup

- Status: Done
- Priority: P1
- Area: Release / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: Requires App Store Connect access and a public privacy policy URL;
  this cannot be completed from the repository alone.
- Next step: In App Store Connect, set the privacy questionnaire to "No, we do
  not collect data from this app" for the current zero-upload build, so the App
  Store label reads `Data Not Collected`.
- Close when: App Store Connect privacy answers are saved and the submitted
  privacy policy URL matches `docs/privacy-compliance.md`.

### TFU-20260611-002 - Wire Settings privacy policy row

- Status: Closed
- Priority: P2
- Area: Settings / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: The final public privacy policy URL is not available in the repo.
- Next step: Once the URL exists, connect the Settings screen's "隐私政策" row to
  open that URL and keep the copy localized.
- Close when: The row opens the published privacy policy from Settings and has
  a lightweight validation path.

### TFU-20260611-003 - Normalize sanitized image attachment filenames

- Status: Open
- Priority: P3
- Area: Documents / Expenses / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: Low-risk cosmetic cleanup touches several attachment creation paths
  and historical display behavior, so it should be handled as its own narrow
  pass instead of folded into sanitizer diagnostics.
- Next step: When image bytes are normalized to JPEG, normalize new attachment
  display filenames/extensions to `.jpg` or store an explicit sanitized content
  type, while preserving existing `isImage` behavior.
- Close when: Newly sanitized image attachments no longer show a misleading
  `.png` extension for JPEG bytes, and import/display paths still rely on
  explicit image metadata rather than filename alone.

### TFU-20260611-004 - Add cloud-sync mutation marks for feeding writes

- Status: Done
- Priority: P1
- Area: Cloud Sync / Feeding
- Source task: Feeding quick-action and stock-reminder repair follow-up,
  2026-06-11
- Blocker: Resolved in Feeding Phase 6 by adding CloudSync upload-pipeline
  support and mutation recorder coverage for feeding-owned sync facts.
- Next step: No remaining action for this follow-up. `Reminder` remains outside
  the current upload pipeline by design; feeding reminder sync is represented by
  the owning `Event` facts.
- Close when: Feeding stock records, feed rules, stock reminders, and auto-log
  materialized records enqueue upload/delete mutations, with focused CloudSync
  tests proving the registered entities are recorded.
- Closed: 2026-06-12 in Feeding Phase 6; `Event` and `PetFoodRecord` now have
  upload/apply support, Feeding write/delete paths call `CloudSyncMutationRecorder`,
  and focused CloudSync + Feeding command tests cover the dirty-state writes.

### TFU-20260611-005 - Route shared walk writes through an owning command/service

- Status: Open
- Priority: P2
- Area: Walks / Shared Care / Architecture
- Source task: Feeding quick-action and stock-reminder repair follow-up,
  2026-06-11
- Blocker: The violation is in an active Walks/shared-care workflow outside the
  feeding repair scope.
- Next step: Replace the static `CareEventService.recordSharedWalk` call in
  `PetWalkingManager` with the owning shared-care command/service boundary used
  by the current Walks workflow.
- Close when: Whole-repo architecture audit no longer reports the
  `PetWalkingManager` static service-call violation and the shared-walk path is
  covered by the relevant Walks/shared-care validation.

### TFU-20260612-006 - Finish CareLedger read-model migration for care surfaces

- Status: Done
- Priority: P1 (release-bar reclassified from legacy P0 on 2026-06-16; first-release reachable but not P0-blocking)
- Area: Care / QuickCare / Hygiene / Read Models
- Source task: Care maturity remediation, 2026-06-12
- Resolution: This crossed QuickCare, Home snapshots, expanded quick-action state,
  expense previews, and legacy log compatibility. `PetHygieneDetailView` display
  state, `IslandHygieneDashboard` summaries, `QuickPlayDetailSheet` display
  history, `QuickPottyDetailSheet` owned potty/litter history, and
  `QuickWaterDetailSheet` water/change/filter history now read from
  `CareLedgerEvent` snapshots. `IslandFoodDashboard` feeding summaries, trends,
  and stock overview now receive pure `FoodLedgerEntry` /
  `QuickFeedLedgerEntry` values after the route container projects bounded
  `CareLedgerEvent` rows; the old `PetCareLog` stock input was removed from the
  dashboard route and snapshot path. QuickFeed full
  history, plan-calendar auto occurrence state, overview, mode-history, and
  treat overview snapshots now receive pure `QuickFeedLedgerEntry` values;
  route-scoped/event-fetch helpers still use `PetCareLog` only as a legacy
  bridge for food-kind/treat-kind enrichment and edit/delete affordances. Home expanded human expense preview
  now reads lightweight `CareLedgerEvent` snapshots instead of direct
  `PetExpenseLog` rows, and Home expanded pet feed quick-action completion,
  count, attention, and menu policy now read lightweight feeding ledger
  snapshots instead of `pet.careLogs`. Home expanded `PetCareLog`-class quick
  actions such as water, litter, play, filter clean, cage cleaning, free flight,
  misting, and substrate change now read lightweight care ledger snapshots for
  completion, counts, recent-age text, and attention state. Home expanded walk
  and potty quick-action status now read lightweight walk/potty ledger
  snapshots for today's distance, completion, count, and recent abnormal potty
  status. Home expanded pet expense monthly total now reads lightweight pet
  expense ledger snapshots instead of `pet.expenseLogs`; old
  `PetExpenseLog` rows are already covered by the CareLedger backfill path.
  `PetWeightLog` is now included in CareLedger backfill, and Home expanded pet
  weight completion/latest status reads lightweight pet weight ledger snapshots
  instead of `pet.weightLogs`. The pet weight dashboard now renders metrics,
  chart points, and recent history from pet-weight `CareLedgerEvent` entries;
  `PetWeightLog` remains only as a deferred delete-command compatibility bridge
  when a ledger row carries a legacy id. `PetHygieneLog` is now included in CareLedger
  backfill, and Home expanded groom completion reads lightweight hygiene ledger
  snapshots instead of `pet.hygieneLogs`; Home groom command duplicate
  prevention also reads bounded `CareLedgerEvent` hygiene rows and only
  publishes a home mutation when a new hygiene fact is recorded. Feed
  anti-repeat checks in Home use feeding `CareLedgerEvent` snapshots, while
  QuickFeed detail uses `QuickFeedLedgerEntry` values instead of `pet.careLogs`,
  preserving actor-name warnings without depending on the legacy relationship
  array.
  `IslandPottyDashboard` now aggregates potty rhythm, type counts, 10-day pulse,
  and per-pet summaries from potty `CareLedgerEvent` entries instead of
  `pet.pottyLogs`. Home `VerticalSolidHomeSourceState`, `HomeReadModelStore`,
  `TodayFocusSnapshot`, and `TodayFocusEconomyService` now use lightweight
  `TodayFocusCareLedgerEntry` values for Today Focus care completion and daily
  reward gating instead of fetching today `PetCareLog`, `PetWalkLog`, or
  `PetPottyLog` rows; pet weight ledger rows are included as well.
  `TodayFocusService` has direct ledger-entry completion coverage for planned
  feed, walk, potty, play-equivalent, and pet-weight quests.
  `IslandQuestEngine` now consumes the same lightweight ledger entries when
  generating care-plan and family-level play quests, including event-scoped
  feed/water/weight completion checks and actor-aware routine subtitles when
  ledger actor data is available.
  `PetAllFeaturesActivitySummary` now loads after the first frame and uses
  pet-scoped `CareLedgerEvent` rows plus route-scoped narrow counts for
  feature-hub metrics, so the all-features render path no longer reads broad
  care, potty, walk, health, weight, expense, photo, or milestone relationship
  arrays.
  Legacy logs remain only as action-time single-id edit/delete,
  claim/typed-metric compatibility bridges, export/report surfaces, or explicit
  calculator fallback tests/callers where the original model is intentionally
  supplied.
- Next step: No active TFU-006 follow-up remains. Future work on non-CareLedger
  medication Home helpers, deletion cleanup internals, or background schedule
  compatibility should be tracked under separate, narrower tickets if it becomes
  user-visible debt.
- Current task disposition: Closed. User-facing care/Home/Today Focus/Family
  report/achievement/dashboard surfaces now consume ledger-backed read models,
  route-scoped rows, or pure summaries. Remaining direct relationship-array
  reads are contained to deletion/cleanup services, action-time single-id
  commands, background schedule compatibility, explicit legacy fallback APIs, or
  non-CareLedger medication/deeplink helpers.
- Progress: 2026-06-24 tightened the Hygiene detail render path. Added
  `PetHygieneLedgerEntry` as the route-local value projection for hygiene
  ledger rows; `PetHygieneDetailView` now maps `CareLedgerEvent` objects in the
  data container and passes `[PetHygieneLedgerEntry]` into
  `PetHygieneDetailContentView`, so the content body no longer filters
  SwiftData ledger objects while rendering. The remaining `PetHygieneLog`
  input is still limited to explicit delete compatibility when a ledger entry
  carries a legacy log id. Guard added:
  `HomeExpensePreviewStoreTests.petHygieneDetailEntriesFilterSortAndKeepLegacyDeleteId`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests` PASS (9 tests, iPhone
  17 simulator).
- Progress: 2026-06-24 tightened the QuickPlay detail render path. Added
  `QuickPlayLedgerEntry` as the route-local value projection for play care
  ledger rows; `QuickPlayRouteData` now maps `CareLedgerEvent` objects during
  route-scoped load and passes `[QuickPlayLedgerEntry]` into
  `QuickPlayDetailSheet`, so the sheet no longer filters SwiftData ledger
  objects during body evaluation. The remaining `PetCareLog` input is still
  limited to explicit delete compatibility when a ledger entry carries a
  legacy log id. Guard added:
  `HomeExpensePreviewStoreTests.quickPlayDetailEntriesFilterSortAndKeepLegacyDeleteId`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests` PASS (10 tests,
  iPhone 17 simulator).
- Progress: 2026-06-24 tightened the QuickWater detail render path. Added
  `QuickWaterLedgerEntry.entries(from:petID:)` and moved watering/change/filter
  ledger projection into `QuickWaterRouteData`; `QuickWaterDetailSheet` and
  `QuickWaterRenderSnapshot` now receive `[QuickWaterLedgerEntry]` instead of
  `[CareLedgerEvent]`, so the sheet render/refresh path no longer filters
  SwiftData ledger objects. The remaining `PetCareLog` input is still limited
  to explicit delete compatibility when a ledger entry carries a legacy log id.
  Guard added:
  `HomeExpensePreviewStoreTests.quickWaterDetailEntriesFilterSortClampAndKeepLegacyDeleteId`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests` PASS (11 tests,
  iPhone 17 simulator).
- Progress: 2026-06-24 tightened the QuickPotty detail render path. Added
  `PoopPottyLedgerEntry.entries(from:petID:)` and
  `PoopLitterLedgerEntry.entries(from:petID:)`; `QuickPottyRouteData` now maps
  potty and litter `CareLedgerEvent` rows during route-scoped load and passes
  `[PoopPottyLedgerEntry]` / `[PoopLitterLedgerEntry]` into
  `QuickPottyDetailSheet`, so the sheet no longer filters SwiftData ledger
  objects during body evaluation. Unknown shared potty claim remains a
  route/action compatibility bridge through `PetPottyLog`; explicit delete
  still uses `PetPottyLog` / `PetCareLog` only when a ledger entry carries a
  legacy log id. Guards added:
  `HomeExpensePreviewStoreTests.quickPottyDetailEntriesFilterSortAndKeepLegacyDeleteId`
  and `quickPottyLitterEntriesFilterSortAndKeepLegacyDeleteId`. Validation:
	  `scripts/test-simulator.sh -only-testing:OhanaTests/HomeExpensePreviewStoreTests`
	  PASS (13 tests, iPhone 17 simulator).
- Progress: 2026-06-24 tightened the QuickFeed detail snapshot path. Added
  source/actor metadata to `QuickFeedLedgerEntry`, moved route-scoped
  `CareLedgerEvent` projection into `QuickFeedRouteData` /
  `QuickFeedCommandExecutor.fullFeedingLedgerEntries`, and changed
  `QuickFeedDetailSheet`, `QuickFeedDataController`,
  `QuickFeedOverviewSnapshotStore`, `QuickFeedTreatSnapshotStore`, and
  `QuickFeedPlanCalendarSnapshotStore` to receive `[QuickFeedLedgerEntry]`
  instead of `[CareLedgerEvent]`. The plan-calendar auto completion marker now
  carries `autoLedgerEntry` rather than a SwiftData event object, and QuickFeed
  anti-repeat uses entry actor IDs. Remaining `PetCareLog` inputs are still
  limited to food-kind/treat-kind enrichment, stock calculators, and explicit
  edit/delete compatibility. Guards updated:
  `QuickFeedOverviewSnapshotStoreTests`,
  `QuickFeedPlanCalendarSnapshotStoreTests`,
  `QuickFeedTreatSnapshotStoreTests`, and `QuickFeedDataControllerTests`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedOverviewSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedPlanCalendarSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedTreatSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedDataControllerTests` PASS (9 tests, iPhone
  17 simulator).
- Progress: 2026-06-24 tightened the IslandFoodDashboard feeding summary path.
  Added `FoodLedgerEntry.entries(from:)`, moved feeding `CareLedgerEvent`
  projection into `IslandFoodDashboardRouteData`, and changed
  `IslandFoodDashboardSnapshot.build`, snapshot revisions, and
  `IslandFoodDashboardContentView` to receive `[FoodLedgerEntry]` instead of
  `[CareLedgerEvent]`. The route container may still fetch bounded ledger events
  to build the value list, and `PetCareLog` remains a stock-calculator
  compatibility input. Guard added:
  `IslandFoodDashboardSnapshotStoreTests.foodLedgerEntriesFilterSortAndClampInvalidRows`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/IslandFoodDashboardSnapshotStoreTests` PASS (3 tests,
  iPhone 17 simulator, xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_02-44-22-+0200.xcresult`).
- Progress: 2026-06-24 tightened the IslandHygieneDashboard render path. Added
  `HygieneDashboardLedgerEntry.entries(from:)`, moved hygiene/maintenance
  `CareLedgerEvent` projection into `IslandHygieneDashboard`, and changed
  `IslandHygieneDashboardContentView` to receive `[HygieneDashboardLedgerEntry]`
  instead of `[CareLedgerEvent]`. The content view no longer imports SwiftData
  or filters SwiftData ledger objects while rendering cross-pet hygiene counts,
  trend points, and recent action titles. Guard added:
  `HomeExpensePreviewStoreTests.islandHygieneDashboardEntriesFilterSortAndKeepCareMaintenanceRows`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests` PASS (14 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-31-38-+0200.xcresult`).
- Progress: 2026-06-24 tightened the Home expanded moment quick-action status
  path. Added `HomePetMomentQuickActionEntry`, actor-side bounded
  `PetPhotoLog` projection, and `VerticalSolidHomeSourceState.petMomentEntries`;
  `ExpandedQuickActionLogic.countText` now renders moment status from read-model
  values and no longer reads `pet.photoLogs` while building Home interaction
  state. The photo/moment quick action and history sheets remain user-click
  route paths. Guard added:
  `HomeExpensePreviewStoreTests.expandedMomentQuickActionUsesReadModelEntriesInsteadOfPetRelationshipLogs`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests` PASS (15 Swift Testing
  tests, iPhone 17 simulator; xcresult
	  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-38-08-+0200.xcresult`);
	  `scripts/test-simulator.sh -only-testing:OhanaTests/HomeReadModelStoreTests`
	  PASS (8 Swift Testing tests, iPhone 17 simulator; xcresult
	  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-41-10-+0200.xcresult`).
- Progress: 2026-06-24 tightened the Today Focus read-model fallback boundary.
  `IslandQuestEngine.todayQuests` now distinguishes "no ledger snapshot supplied"
  from "an empty ledger snapshot was supplied"; Home `TodayFocusSnapshot` and
  `TodayFocusEconomyService` mark their `careLedgerEntries` as authoritative, so
  empty read-model snapshots no longer fall back to `pet.careLogs`,
  `pet.walkLogs`, or `pet.pottyLogs` for care-plan completion, family-level play
  suppression, or routine actor subtitles. The legacy default remains available
  for direct compatibility calls that do not supply a ledger snapshot. Guard
  added: `OhanaTests.islandQuestEngineTreatsEmptyReadModelLedgerAsAuthoritative`.
  Validation: first `scripts/test-simulator.sh -only-testing:OhanaTests/OhanaTests`
  run exposed an outdated daily-completion fixture that inserted only
  `PetCareLog`; the fixture now inserts matching `CareLedgerEvent`, and the
  rerun PASSed (138 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-49-41-+0200.xcresult`).
- Progress: 2026-06-24 tightened the QuickFeed detail row render boundary.
  `QuickFeedDetailContent+FeedRows` no longer exposes a
  `feedLogRow(_ log: PetCareLog, ...)` overload, and the old
  `feedLogBadge(for log: PetCareLog)` helper was removed. QuickFeed history,
  mode-history, overview, auto-feed, and treat rows therefore render through
  `QuickFeedLedgerEntry`; legacy `PetCareLog` remains only for explicit
  edit/delete compatibility and stock-calculator logic. Guard added:
  `QuickFeedDataControllerTests.quickFeedRenderRowsDoNotAcceptLegacyCareLogModels`.
  Validation: first targeted run exposed a test helper variable shadowing issue;
  after renaming it, `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedDataControllerTests` PASSed (3 Swift
  Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-56-55-+0200.xcresult`).
- Progress: 2026-06-24 tightened the QuickFeed Home visible-progress read
  model. `FeedHomeSnapshotInput` now accepts authoritative
  `[QuickFeedLedgerEntry]` values; `FeedHomeSnapshotBuilder` uses those entries
  for today's dry/wet/treat totals, treat count, auto-feed count/latest date,
  and the guided seven-day main-food chart, while retaining `PetCareLog` only for
  stock-calculator compatibility and legacy callers that do not provide ledger
  entries. QuickFeed passes `observedFeedingLedgerEntries` into this input, and
  the feed-home snapshot revision now tracks ledger-entry changes separately
  from legacy stock logs. Guards added:
  `QuickFeedOverviewSnapshotStoreTests.feedHomeSnapshotUsesLedgerEntriesForVisibleProgress`
  and `feedHomeSnapshotTreatsEmptyLedgerEntriesAsAuthoritative`. Validation:
  first targeted run exposed an accidental `feedingLedgerEntries` argument on the
  stock snapshot builder; after removing that miswire,
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedOverviewSnapshotStoreTests` PASSed (4 Swift
  Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_04-00-23-+0200.xcresult`).
  Post-check: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS;
  combined `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedDataControllerTests
  -only-testing:OhanaTests/QuickFeedOverviewSnapshotStoreTests` PASSed (7 Swift
  Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_04-02-59-+0200.xcresult`).
- Progress: 2026-06-24 removed Home feed quick-command routing's legacy
  `PetCareLog` fetch. `HomeCommandExecutor` no longer fetches recent
  `PetCareLog` rows before every quick-care command, and
  `ExpandedQuickActionExecutor` / `ExpandedQuickActionLogic` no longer pass
  `allFeedCareLogs` just to decide manual/manual-reminder/auto feed behavior.
  The command path now uses feed rules and reminder state for routing while
  keeping food records for actual stock-affecting writes and CareLedger for
  anti-repeat checks. Guard added:
  `HomeCommandExecutorTests.homeFeedQuickCommandDoesNotFetchLegacyCareLogsForRouting`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeCommandExecutorTests` PASSed (184 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_04-06-24-+0200.xcresult`).
- Progress: 2026-06-24 removed the default `pet.careLogs` relationship fallback
  from `FeedTodayState` and `FeedingDashboardState`. `careLogs` is now an
  explicit array that defaults to empty, and tests that intentionally exercise
  legacy log compatibility must pass fetched logs themselves. This keeps default
  feed state construction from touching SwiftData relationship arrays while
  retaining narrow compatibility for stock and legacy assertions. Guard added:
  `QuickFeedDataControllerTests.feedTodayStateDoesNotFallbackToPetCareLogRelationship`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedDataControllerTests
  -only-testing:OhanaTests/OhanaTests` PASSed (142 Swift Testing tests, iPhone
  17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_23-34-03-+0200.xcresult`).
- Progress: 2026-06-24 tightened Home water-cycle read-model boundaries.
  `WaterCareCycleStatusCalculator` and `CarePlanOverdueStatusCalculator` now
  accept an explicit `WaterCareCycleLogSnapshot`; Home card badges and expanded
  quick-action attention/count text build that snapshot from
  `HomeCareQuickActionEntry` values. Empty Home read-model entries are therefore
  authoritative and no longer fall back to `pet.careLogs` for water-change /
  filter-cycle status while rendering Home. Guards added:
  `HomeExpensePreviewStoreTests.expandedWaterCycleUsesReadModelEntriesInsteadOfPetCareLogRelationship`
  and
  `HomeSnapshotBuilderTests.snapshotWaterCycleStatusUsesReadModelEntriesInsteadOfPetCareLogRelationship`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests
  -only-testing:OhanaTests/HomeSnapshotBuilderTests` PASSed (37 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_23-44-26-+0200.xcresult`).
- Progress: 2026-06-24 moved auto-feeder materialization dedup off the
  `pet.careLogs` relationship. `FeedAutoLogMaterializer` now builds existing
  auto-feed keys from a pet-scoped `CareLedgerEvent` fetch; new and backfilled
  ledger rows preserve `autoFeedDedupKey` in metadata, and backfill restores
  `sourceEventId` from structured legacy keys so startup backfill can protect
  old logs before auto materialization runs. Guards added:
  `ManualFeedCommandTests.autoFeedMaterializerUsesLedgerKeysInsteadOfPetCareLogRelationship`,
  `ManualFeedCommandTests.careLedgerBackfillPreservesStructuredAutoFeedDedupKey`,
  and the existing auto-feed idempotency test now asserts ledger metadata.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/ManualFeedCommandTests
  -only-testing:OhanaTests/QuickFeedOverviewSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedDataControllerTests
  -only-testing:OhanaTests/QuickFeedPlanCalendarSnapshotStoreTests` PASSed
  (32 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_23-52-10-+0200.xcresult`).
- Progress: 2026-06-25 removed the remaining implicit `pet.careLogs`
  fallback from the feeding stock calculator boundary. `FeedStockCalculator`
  now treats `careLogs` as an explicit value input, `FeedingPlanWriter`
  performs a pet-scoped stock-log fetch before rebuilding stock reminders, and
  `Pet` stock convenience properties no longer scan `careLogs` to discover
  shared feeding sessions. `IslandFoodDashboardSnapshotStore` also computes
  legacy precise-stock fallback from its explicit `legacyStockCareLogs` input
  instead of `pet.remainingFoodGrams`. Guard extended:
  `QuickFeedDataControllerTests.feedTodayStateDoesNotFallbackToPetCareLogRelationship`.
  The shared-care stock tests now assert structured shared-session deduction via
  explicit stock snapshots; the shared litter reward fixture was also made to
  pass live care-event dependencies so the suite no longer depends on a global
  AppServices registry side effect. Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedDataControllerTests
  -only-testing:OhanaTests/OhanaTests` PASSed (142 Swift Testing tests, iPhone
  17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_00-02-03-+0200.xcresult`);
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/SharedPetActionRecorderTests` PASSed (25 Swift
  Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_00-06-17-+0200.xcresult`);
  `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS (large dirty
  worktree still reports build/targeted-test recommendations; this slice's
  compiler surface was covered by the simulator tests above).
- Progress: 2026-06-25 moved QuickFeed food-kind/treat-kind enrichment toward
  structured ledger metadata. `CareLedgerMetadata` now defines
  `feedFoodKind`, `feedTreatKind`, and `sharedSessionId`; `CareLedgerService.recordPetCare`
  writes these fields for feeding `PetCareLog` rows without changing SwiftData
  schema, while preserving existing reward/auto-feed metadata. `QuickFeedLedgerEntry.entries`
  now prefers the ledger metadata for `foodKind`, `treatKind`, and
  `sharedSessionId`, falling back to legacy `PetCareLog` or event-derived
  food kind only for historical rows that lack metadata. Guards added:
  `ManualFeedCommandTests.feedingCareLedgerWritesStructuredKindMetadata` and
  `QuickFeedOverviewSnapshotStoreTests.feedingEntriesPreferLedgerMetadataForKindAndSession`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/ManualFeedCommandTests
  -only-testing:OhanaTests/QuickFeedOverviewSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedDataControllerTests
  -only-testing:OhanaTests/QuickFeedTreatSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedPlanCalendarSnapshotStoreTests` PASSed (35
  Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_00-19-33-+0200.xcresult`);
  `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS (large dirty
  worktree still reports build/targeted-test recommendations; this slice's
  compiler surface was covered by the simulator tests above).
- Progress: 2026-06-25 tightened QuickFeed explicit edit/delete UI state.
  `QuickFeedAlertRoute.deleteFeedLog` and `QuickFeedDraftStore` now store only a
  `UUID` for pending feed-log delete/edit state, and
  `QuickFeedDetailContent+FeedRows` no longer scans `observedCareLogs` while
  rendering each ledger row. Rows parse the ledger `legacyModelId` into an edit
  affordance id; the actual `PetCareLog` is fetched only after the user taps
  edit/delete via `QuickFeedCommandExecutor.feedLog(id:)`, with a missing-row
  fallback toast. Guard extended:
  `QuickFeedDataControllerTests.quickFeedRenderRowsDoNotAcceptLegacyCareLogModels`.
  Validation: `git diff --check` PASS; `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedDataControllerTests
  -only-testing:OhanaTests/QuickFeedDraftStoreTests
  -only-testing:OhanaTests/QuickFeedOverviewSnapshotStoreTests
  -only-testing:OhanaTests/ManualFeedCommandTests` PASSed (33 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_00-26-18-+0200.xcresult`).
- Progress: 2026-06-25 batch-tightened QuickCare/Hygiene explicit delete
  bridges. QuickPlay, QuickWater, and QuickPotty route data no longer prefetch
  delete-only legacy log arrays; their detail rows keep only ledger
  `legacyLogId` values and fetch `PetCareLog` / `PetPottyLog` by single id only
  after the user taps delete. `PetHygieneDetailView` also removed the
  delete-only `PetHygieneLog` query from its route container and fetches a
  single `PetHygieneLog` at action time. Added executor helpers
  `PetCareCommandExecutor.careLog(id:)`, `PetCareCommandExecutor.pottyLog(id:)`,
  `QuickWaterCommandExecutor.careLog(id:)`, and
  `PetHygieneCommandExecutor.hygieneLog(id:)`; unknown-potty claim remains an
  explicit compatibility path because the row itself represents an unknown
  legacy potty record. Guard added:
  `HomeExpensePreviewStoreTests.quickCareDeleteBridgesUseActionTimeIdFetches`.
  Validation: first targeted run exposed an over-strict source assertion against
  the required `"PetHygieneLog"` legacy-model-name string; after narrowing the
  guard to the `@Query`/array boundary, `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests` PASSed (17 Swift
  Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_00-35-47-+0200.xcresult`).
- Progress: 2026-06-25 tightened QuickFeed route preload scope. `QuickFeedRouteData`
  no longer fetches recent feeding `PetCareLog` rows by date before presenting
  the detail route; it now fetches feeding `CareLedgerEvent` rows first and
  resolves only the single legacy log ids referenced by those ledger rows for
  historical metadata enrichment. `QuickFeedDetailSheet` renamed that input to
  `legacyCareLogs`, while full history / stock-heavy surfaces still use the
  existing lazy sheet-time `fullCareLogs` fetch. Guard added:
  `QuickFeedDataControllerTests.quickFeedRouteUsesLedgerScopedLegacyCareLogs`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedDataControllerTests
  -only-testing:OhanaTests/QuickFeedOverviewSnapshotStoreTests
  -only-testing:OhanaTests/ManualFeedCommandTests` PASSed (31 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_00-41-28-+0200.xcresult`).
- Progress: 2026-06-25 tightened PetAllFeatures activity metrics and typed
  feature-hub counts. The all-features sheet no longer reads `pet.careLogs`,
  `pet.pottyLogs`, `pet.walkLogs`, `pet.healthLogs`, `pet.weightLogs`,
  `pet.expenseLogs`, `pet.photoLogs`, or `pet.milestones` relationship arrays
  while rendering feature subtitles, counters, archive score, latest weight, or
  expense totals. `PetDetailSheetRouteContainer` still loads a pure
  `PetAllFeaturesActivitySummary` after the first frame, but the summary now
  reads pet-scoped `CareLedgerEvent` rows for care/potty/walk/health/weight/
  expense metrics and uses route-scoped narrow counts for photos, milestones,
  documents, insurance, and medications. Guards added/updated:
  `MemberLifecycleGateTests.petAllFeaturesUsesRouteScopedActivitySummaryInsteadOfPetRelationshipCareLogs`
  and `petAllFeaturesActivitySummaryUsesLedgerAndRouteScopedCounts`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests` PASSed (65 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_02-46-18-+0200.xcresult`).
- Progress: 2026-06-25 removed dead legacy care subtitles from
  `FeatureAggregateView`. The aggregate page already routes food, hygiene,
  potty, walks, retention, health, medication, weight, and expense features to
  their dashboard surfaces, so the old per-pet `subtitle(for:)` branches were
  unreachable UI code but still carried broad relationship-array reads such as
  `pet.careLogs`, `pet.pottyLogs`, `pet.walkLogs`, `pet.hygieneLogs`,
  `pet.expenseLogs`, and `pet.weightLogs`. The summary subtitle switch now
  keeps only currently rendered basic info / documents / moments /
  achievements cases and returns an empty placeholder for dashboard-backed
  feature cases. Guard added:
  `MemberLifecycleGateTests.featureAggregateViewDoesNotCarryLegacyCareRelationshipSubtitles`.
  Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/deceasedFeatureHubsExposeOnlyMemorialSafeDestinations()
  -only-testing:OhanaTests/MemberLifecycleGateTests/petAllFeaturesUsesRouteScopedActivitySummaryInsteadOfPetRelationshipCareLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/featureAggregateViewDoesNotCarryLegacyCareRelationshipSubtitles()`
  PASSed (3 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_00-52-38-+0200.xcresult`).
- Progress: 2026-06-25 moved `FamilyActivityStripView` off pet relationship
  arrays. `FamilyActivityStripRouteContainer` now fetches today's
  `CareLedgerEvent` rows for the current pet after the first frame and passes
  pure `FamilyActivityEntry` values into the strip view. The view no longer scans
  `pet.careLogs`, `pet.pottyLogs`, `pet.walkLogs`, or `pet.expenseLogs` while
  rendering; shared walk rows preserve multi-executor display by reading the
  ledger metadata `executorIds` array through
  `CareLedgerMetadata.stringArrayValue(named:in:)`. Guards added:
  `MemberLifecycleGateTests.familyActivityStripUsesLedgerEntriesInsteadOfPetRelationshipLogs`
  and `familyActivityEntriesProjectTodayLedgerEventsAndSharedWalkExecutors`.
  Validation: the first targeted run exposed two stale `ActivityEntry` type
  references after the pure-value rename; a later changed-file gate then caught
  the initial route `@Query` version, so the route was corrected to a deferred
  `ModelContext` fetch. After both fixes,
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/familyActivityStripUsesLedgerEntriesInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/familyActivityEntriesProjectTodayLedgerEventsAndSharedWalkExecutors()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_01-02-34-+0200.xcresult`).
- Progress: 2026-06-25 moved BountyBoard and FamilyCollaborationDashboard
  activity summaries onto a shared pure ledger projection. Added
  `FamilyCareLedgerEntry` to project pet-subject `CareLedgerEvent` rows into
  pet id, executor ids, event kind, action type, and date. `BountyBoardView`
  now loads this bounded week window after the first frame and computes weekly
  human care/potty/walk/expense stats from pure entries instead of scanning
  `pet.careLogs`, `pet.pottyLogs`, `pet.walkLogs`, or `pet.expenseLogs`.
  `CrewRosterRouteData` now fetches the same bounded entries for the family
  collaboration overlay; `FamilyCollaborationDashboardView` uses them for latest
  activity, today activity count, board progress, and care-gap detection. Shared
  walk rows keep their multi-executor display through the same `executorIds`
  metadata path. Guards added:
  `MemberLifecycleGateTests.familyTaskActivitySurfacesUseLedgerEntriesInsteadOfPetRelationshipLogs`
  and `familyCareLedgerEntriesProjectWeeklyStatsAndExecutorLists`. Validation:
  first targeted run exposed a `[Any]` inference bug in the new executor-id
  helper; after explicit `[String]` annotation,
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/familyActivityStripUsesLedgerEntriesInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/familyActivityEntriesProjectTodayLedgerEventsAndSharedWalkExecutors()
  -only-testing:OhanaTests/MemberLifecycleGateTests/familyTaskActivitySurfacesUseLedgerEntriesInsteadOfPetRelationshipLogs()
	  -only-testing:OhanaTests/MemberLifecycleGateTests/familyCareLedgerEntriesProjectWeeklyStatsAndExecutorLists()`
	  PASSed (4 Swift Testing tests, iPhone 17 simulator; xcresult
	  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_01-16-17-+0200.xcresult`).
	- Progress: 2026-06-25 moved FamilyWeeklyReport onto a deferred ledger
	  read model. `FamilyWeeklyReportDashboardView` no longer installs live
	  `@Query` subscriptions for pets, humans, or all `CareLedgerEvent` rows on
	  the first frame; `FamilyWeeklyReportRouteData` now loads pets, humans, and a
	  bounded four-week pet ledger window after the first frame. The dashboard
	  removed its legacy fallback loops over `pet.careLogs`, `pet.pottyLogs`,
	  `pet.walkLogs`, and `pet.expenseLogs`, and weight trend now comes from
	  `.weight` ledger events instead of `pet.weightLogs`. `WeeklyReportCard`
	  also renders walk count/distance, potty count, expense total, active days,
	  and latest weight from ledger events; walk duration reads optional ledger
	  metadata and otherwise safely degrades. Guard added:
	  `MemberLifecycleGateTests.familyWeeklyReportsUseDeferredLedgerReadModelInsteadOfPetRelationshipLogs`.
	  Validation: `git diff --check` PASS; `scripts/audit-route-first-frame.sh
	  --changed` PASS; targeted `scripts/test-simulator.sh
	  -only-testing:OhanaTests/MemberLifecycleGateTests/familyActivityStripUsesLedgerEntriesInsteadOfPetRelationshipLogs()
	  -only-testing:OhanaTests/MemberLifecycleGateTests/familyActivityEntriesProjectTodayLedgerEventsAndSharedWalkExecutors()
	  -only-testing:OhanaTests/MemberLifecycleGateTests/familyTaskActivitySurfacesUseLedgerEntriesInsteadOfPetRelationshipLogs()
	  -only-testing:OhanaTests/MemberLifecycleGateTests/familyWeeklyReportsUseDeferredLedgerReadModelInsteadOfPetRelationshipLogs()
	  -only-testing:OhanaTests/MemberLifecycleGateTests/familyCareLedgerEntriesProjectWeeklyStatsAndExecutorLists()`
	  PASSed (5 Swift Testing tests, iPhone 17 simulator; xcresult
	  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_01-24-01-+0200.xcresult`);
	  `scripts/dev-check-changed.sh` PASS; after SwiftFormat normalized
	  `descriptor.fetchLimit = 1200`, the post-format guard rerun
	  `scripts/test-simulator.sh
	  -only-testing:OhanaTests/MemberLifecycleGateTests/familyWeeklyReportsUseDeferredLedgerReadModelInsteadOfPetRelationshipLogs()`
	  PASSed (1 Swift Testing test, iPhone 17 simulator; xcresult
	  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_01-26-29-+0200.xcresult`).
- Progress: 2026-06-25 moved `StreakManager` daily check-in detection onto a
  pet/day-scoped ledger query. `refreshStreak(for:context:)` now treats only
  today's potty, walk, or feeding `CareLedgerEvent` as check-in evidence, with
  `fetchLimit = 1`; it no longer scans `pet.pottyLogs`, `pet.walkLogs`, or
  `pet.foodRecords` relationship arrays. Guards added:
  `MemberLifecycleGateTests.streakManagerUsesLedgerNarrowCheckInInsteadOfPetRelationshipLogs`
  and `streakManagerCheckInReadsLedgerInsteadOfPetRelationshipLogs`. Validation:
  `git diff --check` PASS; `scripts/audit-route-first-frame.sh --changed` PASS;
  targeted `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/streakManagerUsesLedgerNarrowCheckInInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/streakManagerCheckInReadsLedgerInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/familyWeeklyReportsUseDeferredLedgerReadModelInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/familyCareLedgerEntriesProjectWeeklyStatsAndExecutorLists()`
  PASSed (4 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_01-33-27-+0200.xcresult`).
- Progress: 2026-06-25 removed the unused `pets:` relationship-array API from
  `IslandProsperityManager`. Prosperity level/progress now accepts either an
  already projected total count or filtered `CareLedgerEvent` rows, and it no
  longer carries dormant `pet.walkLogs`, `pet.pottyLogs`, `pet.hygieneLogs`,
  `pet.healthLogs`, `pet.weightLogs`, `pet.foodRecords`, or `pet.milestones`
  reads that could be revived by future Oasis/dashboard work. Guards added:
  `MemberLifecycleGateTests.islandProsperityUsesLedgerCountsInsteadOfPetRelationshipLogs`
  and `islandProsperityCountsOnlyPetLedgerActivity`. Validation:
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/streakManagerUsesLedgerNarrowCheckInInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/streakManagerCheckInReadsLedgerInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/islandProsperityUsesLedgerCountsInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/islandProsperityCountsOnlyPetLedgerActivity()`
  PASSed (4 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_01-38-52-+0200.xcresult`).
- Progress: 2026-06-25 moved AchievementWall and `AchievementManager` pet-care
  achievement summaries onto route-scoped CareLedger input.
  `AchievementWallRouteData` now loads pet-subject `CareLedgerEvent` rows after
  the first frame and passes optional ledger rows into
  `AchievementComputationContext`; `AchievementCareLedgerSummary` drives unlock
  computation, progress values, and completion dates for care, potty, walk,
  hygiene, health, weight, expense, and feeding achievements. A supplied empty
  ledger input is authoritative, while `nil` keeps the legacy fallback available
  for unmigrated callers. Guards added:
  `MemberLifecycleGateTests.achievementWallRoutesLedgerEventsIntoAchievementContext`
  and
  `achievementManagerPrefersAuthoritativeLedgerCareSummaryWhenProvided`.
  Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS;
  post-format targeted `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/streakManagerUsesLedgerNarrowCheckInInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/streakManagerCheckInReadsLedgerInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/islandProsperityUsesLedgerCountsInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/islandProsperityCountsOnlyPetLedgerActivity()
  -only-testing:OhanaTests/MemberLifecycleGateTests/achievementWallRoutesLedgerEventsIntoAchievementContext()
  -only-testing:OhanaTests/MemberLifecycleGateTests/achievementManagerPrefersAuthoritativeLedgerCareSummaryWhenProvided()`
  PASSed (6 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_01-54-57-+0200.xcresult`).
  TFU-006 remains Open: typed-metric compatibility, stock calculator historical
  bridges, and non-AchievementWall callers still need migration or explicit
  boundary documentation.
- Progress: 2026-06-25 moved QuickPotty unknown-claim UI/render state to pure
  route-deferred entries. `QuickPottyUnknownClaimStore` now projects
  `PoopUnknownPottyEntry` values; `QuickPottyRouteData` loads those entries
  after the first frame and passes them into `QuickPottyDetailSheet`.
  `PoopLogItem.unknownPotty` no longer carries `PetPottyLog`, and claim/delete
  buttons now pass only a log id; `QuickPottyDetailSheet` fetches the single
  `PetPottyLog` only after the user taps claim/delete. Guards updated:
  `HomeCommandExecutorTests.quickPottyUnknownSharedFlowCanBeClaimedAndRefreshesSessionAndLedger`
  and
  `HomeExpensePreviewStoreTests.quickPottyUnknownClaimUsesRoutePureEntriesAndActionTimeFetches`.
  Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS;
  targeted `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeCommandExecutorTests/quickPottyUnknownSharedFlowCanBeClaimedAndRefreshesSessionAndLedger()
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests/quickCareDeleteBridgesUseActionTimeIdFetches()
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests/quickPottyUnknownClaimUsesRoutePureEntriesAndActionTimeFetches()`
  PASSed (3 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_02-02-40-+0200.xcresult`).
  TFU-006 remains Open: typed-metric compatibility, stock calculator historical
  bridges, and non-AchievementWall callers still need migration or explicit
  boundary documentation.
- Progress: 2026-06-25 moved QuickFeed and FeedHome stock consumption onto
  supplied `QuickFeedLedgerEntry` values. `FeedStockCalculator` now accepts an
  optional feeding-ledger input; when the input is supplied, even as an empty
  array, it is authoritative for stock consumption, recent average, remaining
  grams, and runout estimates. `QuickFeedStockSnapshotStore`,
  `QuickFeedDetailSheet`, `QuickFeedDetailContent.refreshStockSnapshot`, and
  `FeedHomeSnapshotBuilder` pass observed feeding ledger entries into the stock
  path, while the legacy `PetCareLog` input remains only as an explicit fallback
  for callers that have not supplied ledger entries. Added
  `QuickFeedStockSnapshotStoreTests.stockSnapshotUsesFeedingLedgerEntriesForConsumptionWhenProvided`
  and
  `stockSnapshotTreatsSuppliedEmptyFeedingLedgerEntriesAsAuthoritative`.
  Validation: `git diff --check` PASS; `scripts/test-simulator.sh
  -only-testing:OhanaTests/QuickFeedStockSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedOverviewSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedDataControllerTests/feedTodayStateDoesNotFallbackToPetCareLogRelationship()`
  PASSed (10 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_02-10-41-+0200.xcresult`);
  `scripts/dev-check-changed.sh` PASS; post-format `git diff --check` PASS.
  TFU-006 remains Open: typed-metric compatibility, non-AchievementWall callers,
  and explicit legacy stock fallback callers such as independent dashboard/writer
  rebuild paths still need migration or documented containment.
- Progress: 2026-06-25 moved the remaining non-AchievementWall
  `AchievementManager` callers onto explicit ledger context. `OasisRewardLiveDataStore`
  now loads pet-subject achievement ledger events after the visible Oasis surface
  has yielded its first frame, and `OasisRewardCommandExecutor.makeBentoSnapshot`
  passes those events through `AchievementComputationContext` instead of calling
  `AchievementManager.compute(for:)` naked. `PetRetentionHubView` and
  `IslandRetentionDashboardContentView` also defer pet ledger loading and pass
  pure ledger input into their screen models before computing achievement
  progress. Guard added:
  `MemberLifecycleGateTests.nonWallAchievementCallersUseLedgerContext`. Validation:
  first targeted run exposed a missing `return` in
  `IslandRetentionDashboardScreenModel.summaries`, the second exposed optional
  `CareLedgerEvent.subjectId`; after fixing both, `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/achievementWallRoutesLedgerEventsIntoAchievementContext()
  -only-testing:OhanaTests/MemberLifecycleGateTests/achievementManagerPrefersAuthoritativeLedgerCareSummaryWhenProvided()
  -only-testing:OhanaTests/MemberLifecycleGateTests/nonWallAchievementCallersUseLedgerContext()`
  PASSed (3 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_02-16-48-+0200.xcresult`);
  `scripts/dev-check-changed.sh` PASS; post-check `git diff --check` PASS and
  source search finds no naked `AchievementManager.compute(for: pet)` /
  `AchievementManager.compute(for: $0)` in Oasis, DashboardRecords, or
  Achievements callers. TFU-006 remains Open: typed-metric compatibility and
  explicit legacy stock fallback callers such as independent dashboard/writer
  rebuild paths still need migration or documented containment.
- Progress: 2026-06-25 tightened Today Focus pet-weight completion against the
  same read-model ledger boundary. `HomeReadModelStore` and
  `TodayFocusEconomyService` now include pet-subject `.weight` ledger events in
  their `TodayFocusCareLedgerEntry` inputs; `TodayFocusService` completes
  `q_weight_*` quests from `.weight` ledger rows instead of `pet.weightLogs` on
  the read-model path; and `IslandQuestEngine` uses ledger weight entries for
  generated weight task suppression plus weight care-plan completion whenever a
  ledger snapshot is supplied. Added/updated tests:
  `OhanaTests.todayFocusServiceCompletesCareQuestsFromLedgerEntries`,
  `todayFocusServiceTreatsLedgerWeightAsAuthoritative`,
  `islandQuestEngineTreatsEmptyReadModelLedgerAsAuthoritative`, and
  `islandQuestEngineUsesLedgerWeightForReadModelCompletion`. Validation:
  method-level Swift Testing filters compiled but selected 0 tests, so they were
  not counted; file-level `scripts/test-simulator.sh
  -only-testing:OhanaTests/OhanaTests` first exposed an outdated daily-completion
  fixture and the economy-service weight fetch gap, then PASSed after fixing
  both (140 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_02-24-40-+0200.xcresult`).
  TFU-006 remains Open: explicit legacy stock fallback callers such as
  independent dashboard/writer rebuild paths and remaining compatibility bridges
  still need migration or documented containment.
- Progress: 2026-06-25 moved the independent feeding stock dashboard/writer
  callers onto ledger-authoritative input. `FeedingPlanWriter` now rebuilds
  stock reminders from pet-scoped feeding `CareLedgerEvent` rows projected into
  `QuickFeedLedgerEntry` values instead of fetching stock `PetCareLog` rows.
  `IslandFoodDashboardRouteData` also projects bounded feeding ledger rows into
  stock-specific `QuickFeedLedgerEntry` values; `IslandFoodDashboardSnapshot`,
  revisions, and `IslandFoodDashboardContentView` no longer carry
  `legacyStockCareLogs`. `QuickFeedLedgerEntry.entries` was marked
  `nonisolated` because it is a pure value projection used by nonisolated writer
  code. Guards updated:
  `QuickFeedDataControllerTests.feedTodayStateDoesNotFallbackToPetCareLogRelationship`
  and `IslandFoodDashboardSnapshotStoreTests.dashboardSnapshotAggregatesSelectedPetsAndStockOnce`.
  Validation: `git diff --check` PASS; targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/IslandFoodDashboardSnapshotStoreTests
  -only-testing:OhanaTests/QuickFeedDataControllerTests
  -only-testing:OhanaTests/QuickFeedStockSnapshotStoreTests`
  PASSed twice after the isolation cleanup (12 Swift Testing tests, iPhone 17
  simulator; final xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_02-32-39-+0200.xcresult`).
  TFU-006 remains Open: typed-metric compatibility and remaining explicit
  action-time/delete/claim bridges still need migration or documented
  containment.
- Progress: 2026-06-25 moved the Home / Today Focus negative-feedback generator
  onto explicit ledger-projected input. `IslandNegativeFeedback` now accepts
  pure `IslandNegativeCareLedgerEntry` values and no longer scans
  `pet.careLogs`, `pet.walkLogs`, `pet.pottyLogs`, or `pet.hygieneLogs` for
  no-check-in, appetite, drinking, potty, or overdue-feed signals. Home
  `TodayFocusSnapshot` maps its existing `TodayFocusCareLedgerEntry` read-model
  input into those pure negative-feedback values, and
  `TodayFocusCareLedgerEntry` now carries `amountValue` from
  `CareLedgerEvent.amountValue` so amount-based appetite/drinking signals keep
  their old semantics without returning to legacy relationship arrays. Guard
  added:
  `MemberLifecycleGateTests.islandNegativeFeedbackUsesLedgerEntriesInsteadOfPetRelationshipLogs`.
  Behavior coverage added in `OhanaTests`: legacy relationship check-ins no
  longer suppress the warning when ledger input is empty, ledger check-ins do
  suppress it, and feeding amount trends come from ledger values. Validation:
  `git diff --check` PASS; `scripts/test-simulator.sh
  -only-testing:OhanaTests/OhanaTests
  -only-testing:OhanaTests/MemberLifecycleGateTests` PASSed (208 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_02-54-22-+0200.xcresult`).
  TFU-006 remains Open: remaining action-time/delete/claim bridges and explicit
  fallback callers still need migration or documented containment.
- Progress: 2026-06-25 finished the same Home / Today Focus quest-generation
  chain by making `IslandQuestEngine` treat `TodayFocusCareLedgerEntry` input as
  the only care-completion source for care-plan completion, play-equivalent
  suppression, pet weight tasks, routine subtitles, and last-routine actor
  hints. The engine no longer falls back to `pet.careLogs`, `pet.walkLogs`,
  `pet.pottyLogs`, or `pet.weightLogs`; legacy relationship rows cannot mark
  read-model quests complete unless they were projected into ledger entries.
  Guard added:
  `MemberLifecycleGateTests.islandQuestEngineUsesLedgerEntriesInsteadOfPetRelationshipCareFallbacks`.
  Existing authoritative-empty coverage remains in
  `OhanaTests.islandQuestEngineTreatsEmptyReadModelLedgerAsAuthoritative`, and
  `islandQuestEngineDoesNotCreatePlayTaskForEveryPetAfterInteraction` now feeds
  walk interaction through `TodayFocusCareLedgerEntry`. Validation:
  `git diff --check` PASS; `scripts/test-simulator.sh
  -only-testing:OhanaTests/OhanaTests
  -only-testing:OhanaTests/MemberLifecycleGateTests` PASSed (209 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-01-36-+0200.xcresult`).
  TFU-006 remains Open: remaining action-time/delete/claim bridges and explicit
  fallback callers still need migration or documented containment.
- Progress: 2026-06-25 tightened the water-cycle calculator boundary so
  `WaterCareCycleStatusCalculator` consumes only an explicit
  `WaterCareCycleLogSnapshot` (defaulting to `.empty`) plus settings anchors; it
  no longer scans `pet.careLogs` when a caller omits the snapshot. Home's
  expanded quick-action path already supplies read-model water-cycle entries, so
  this removes a hidden broad compatibility fallback without changing the
  intended Home source of truth. Guard added:
  `MemberLifecycleGateTests.waterCareCycleStatusUsesExplicitSnapshotInsteadOfPetCareLogRelationship`.
  Behavior coverage added:
  `HomeExpensePreviewStoreTests.waterCareCycleStatusIgnoresLegacyCareLogRelationshipWithoutSnapshot`.
  Validation: `git diff --check` PASS; `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeExpensePreviewStoreTests
  -only-testing:OhanaTests/MemberLifecycleGateTests` PASSed (87 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-07-18-+0200.xcresult`).
  TFU-006 remains Open: remaining action-time/delete/claim bridges and explicit
  fallback callers still need migration or documented containment.
- Progress: 2026-06-25 removed a dormant Home card metric fallback:
  `FocusCard.from(_ pet:)` no longer computes weekly dog walk distance by
  scanning `pet.walkLogs`; any Home card walk distance must now be supplied as
  an explicit pure `homeWalkDistanceMeters` value. `FocusHomeCardDataSource`
  continues to build first-screen cards without walk relationship reads.
  Guards added:
  `MemberLifecycleGateTests.focusHomeCardModelUsesExplicitWalkDistanceInsteadOfPetWalkRelationship`.
  Behavior coverage added:
  `MemberCreationServiceTests.focusHomeCardUsesExplicitWalkDistanceInsteadOfPetWalkRelationship`.
  Validation: `git diff --check` PASS; source search of
  `FocusHomeModels.swift` / `FocusHomeCardDataSource.swift` found no
  `includeWalkDistance`, `weeklyWalkDistanceMeters`, or `pet.walkLogs`;
  `scripts/test-simulator.sh -only-testing:OhanaTests/MemberCreationServiceTests
  -only-testing:OhanaTests/MemberLifecycleGateTests` PASSed (92 Swift Testing
	  tests, iPhone 17 simulator; xcresult
	  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-10-53-+0200.xcresult`).
	  TFU-006 remains Open: remaining action-time/delete/claim bridges and explicit
	  fallback callers still need migration or documented containment.
- Progress: 2026-06-25 tightened DashboardRecords retention metrics after the
  non-wall achievement caller migration. `PetRetentionHubView` and
  `IslandRetentionDashboardContentView` now load `PetRetentionArchiveMetrics`
  after the first frame; archive score, photo/milestone counts, latest memory
  date, health baseline, expiring protection count, timeline count, and
  dashboard memory capsules come from `PetAllFeaturesActivitySummary` plus
  route-scoped narrow fetches instead of rendering from `pet.photoLogs`,
  `pet.milestones`, `pet.weightLogs`, `pet.healthLogs`, `pet.expenseLogs`,
  `pet.careLogs`, `pet.walkLogs`, `pet.documents`, `pet.insurances`, or
  `pet.medications`. The retention screen models also use the same pure metrics
  for per-pet summaries and retention scoring. Guard updated:
  `MemberLifecycleGateTests.nonWallAchievementCallersUseLedgerContext`.
  Behavior coverage added:
  `MemberLifecycleGateTests.petRetentionArchiveMetricsUsesRouteScopedCountsAndLatestMemory`.
  Validation: `git diff --check` PASS; source search across the four
  DashboardRecords retention files found no direct `pet.*Logs` / protection
  relationship reads listed above; first targeted run exposed a missing
  `return` in `retentionScore`, then
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/nonWallAchievementCallersUseLedgerContext()
  -only-testing:OhanaTests/MemberLifecycleGateTests/petRetentionArchiveMetricsUsesRouteScopedCountsAndLatestMemory()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-21-38-+0200.xcresult`);
  `scripts/dev-check-changed.sh` PASSed (SwiftFormat checked changed Swift files,
  formatted 0 files; UI/accessibility/smoothness/route-first-frame/runtime/
  economy/member-lifecycle/derived-state audits PASS; build still recommended
  for the wider dirty compiler surface, but this batch is covered by the
  targeted simulator run above).
  TFU-006 remains Open: remaining action-time/delete/claim bridges and explicit
  fallback callers still need migration or documented containment.
- Progress: 2026-06-25 migrated DashboardRecords weight/exploration stats to
  pet ledger metrics. `IslandUnifiedStatsViewModel` now route-loads pet weight
  and walk `CareLedgerEvent` rows, then computes pet weight deltas, pet absolute
  weight series, weekly exploration distance, and weekly exploration count from
  pure metric entries instead of `pet.weightLogs` or `pet.walkLogs`.
  `IslandWeightDashboard` total island weight and pet sparklines now read the
  view model's `weightAbsolutes` series instead of sorting pet relationship
  logs. Guard added:
  `MemberLifecycleGateTests.islandWeightDashboardUsesPetLedgerMetricsInsteadOfPetRelationships`.
  Behavior coverage added:
  `MemberLifecycleGateTests.islandUnifiedStatsUsesPetLedgerMetricsInsteadOfLegacyPetRelationships`,
  proving legacy relationship rows are ignored when ledger metrics are present.
  Validation: source search across `IslandUnifiedStatsViewModel.swift` and
  `IslandWeightDashboard.swift` found no `pet.weightLogs` or `pet.walkLogs`;
  `git diff --check` PASS;
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/islandWeightDashboardUsesPetLedgerMetricsInsteadOfPetRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/islandUnifiedStatsUsesPetLedgerMetricsInsteadOfLegacyPetRelationships()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-27-51-+0200.xcresult`).
  TFU-006 remains Open: quick weight sheets, dormant/legacy chart surfaces, and
  remaining action-time/delete/claim bridges still need migration or documented
  containment.
- Progress: 2026-06-25 migrated quick weight sheet latest-weight hints to a
  route-scoped ledger metric. `GenericWeightEntrySheet` quick weight chips and
  `QuickWeightSheet` "last record" hint now load `latestPetWeightKg` after the
  first frame via `PetWeightLedgerRouteMetrics.latestWeightKg(petID:context:)`;
  render/computed UI state no longer sorts `pet.weightLogs`. The helper performs
  a pet-id-scoped `CareLedgerEvent` weight fetch with a small fetch limit and
  stores only a `Double?` in view state. Guard added:
  `MemberLifecycleGateTests.quickWeightSheetsUseRouteScopedLedgerMetricsInsteadOfPetWeightRelationships`.
  Behavior coverage added:
  `MemberLifecycleGateTests.quickWeightSheetsUseLedgerLatestWeightInsteadOfLegacyPetRelationship`,
  proving legacy `PetWeightLog` relationship rows do not affect the quick-sheet
  hint when ledger weight rows are present. Validation: source search across
  `GenericWeightEntrySheet.swift` and `QuickWeightSheet.swift` found no
  `pet.weightLogs`; first targeted run failed on an optional-binding mistake for
  non-optional `CareLedgerEvent.amountValue`, then
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/quickWeightSheetsUseRouteScopedLedgerMetricsInsteadOfPetWeightRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/quickWeightSheetsUseLedgerLatestWeightInsteadOfLegacyPetRelationship()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-33-57-+0200.xcresult`);
  post-check `git diff --check` PASSed; `scripts/dev-check-changed.sh`
  PASSed (SwiftFormat checked changed Swift files, formatted 1 file;
  UI/accessibility/smoothness/route-first-frame/runtime/economy/member-lifecycle/
  derived-state audits PASS; build still recommended for the wider dirty
  compiler surface, but this batch is covered by the targeted simulator run
  above).
  TFU-006 remains Open: dormant/legacy chart surfaces and remaining
  action-time/delete/claim bridges still need migration or documented
  containment.
- Progress: 2026-06-25 removed dormant `PetChartDashboard.swift`, a stale
  DashboardRecords chart surface that was not referenced by active Swift source
  or `Ohana.xcodeproj` and still scanned `pet.weightLogs`, `pet.walkLogs`,
  `pet.pottyLogs`, and `pet.expenseLogs` in render helpers. Added
  `MemberLifecycleGateTests.dormantPetChartDashboardBroadReadSurfaceStaysRemoved`
  so the old broad-read surface cannot silently return. Validation:
  `rg PetChartDashboard` found only historical docs plus the new guard;
  targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/quickWeightSheetsUseRouteScopedLedgerMetricsInsteadOfPetWeightRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/quickWeightSheetsUseLedgerLatestWeightInsteadOfLegacyPetRelationship()
	  -only-testing:OhanaTests/MemberLifecycleGateTests/dormantPetChartDashboardBroadReadSurfaceStaysRemoved()`
  PASSed (3 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-37-41-+0200.xcresult`);
  post-check `git diff --check` PASSed; `scripts/dev-check-changed.sh`
  PASSed (SwiftFormat formatted 0 files; changed-file audits PASS).
  TFU-006 remains Open: FunctionMenu legacy aggregate counts and remaining
  action-time/delete/claim bridges still need migration or documented
  containment.
- Progress: 2026-06-25 migrated FunctionMenu pet archive aggregate subtitles to
  route-scoped summaries. `FeatureAggregateView` no longer renders Documents,
  Moments, or Achievements subtitles from `pet.documents.count`,
  `pet.photoLogs.count`, or `pet.milestones.count`; `FunctionMenuRouteData`
  now loads `FunctionMenuPetAggregateSummary` after the first frame by doing
  pet-id-scoped `fetchCount` queries for `PetDocument`, `PetPhotoLog`, and
  `PetMilestone`, then passes only `[UUID: FunctionMenuPetAggregateSummary]`
  into the destination router and dashboard views. Guards added:
  `MemberLifecycleGateTests.functionMenuAggregateUsesRouteScopedSummariesInsteadOfPetArchiveRelationships`
  and
  `MemberLifecycleGateTests.functionMenuPetAggregateSummaryCountsRouteScopedArchiveItems`.
  Validation: source search across FunctionMenu found no legacy
  `pet.documents.count` / `pet.photoLogs.count` / `pet.milestones.count` render
  reads; first targeted runs exposed missing `return` statements in the new
  route data and subtitle helpers, then
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/functionMenuAggregateUsesRouteScopedSummariesInsteadOfPetArchiveRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/functionMenuPetAggregateSummaryCountsRouteScopedArchiveItems()`
	  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
	  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-45-16-+0200.xcresult`);
	  post-check `git diff --check` PASSed; `scripts/dev-check-changed.sh`
	  PASSed (SwiftFormat formatted 0 files; changed-file audits PASS; build still
	  recommended for the wider dirty compiler surface, but this batch is covered by
	  the targeted simulator run above).
	  TFU-006 remains Open: remaining action-time/delete/claim bridges still need
	  migration or documented containment.
- Progress: 2026-06-25 migrated archive document/milestone route surfaces to
  pet-id-scoped route rows. `DocumentsListView` and `PetMilestoneListView` now
  use route-scoped `@Query` results for `PetDocument`, `PetInsurance`, and
  `PetMilestone` after explicit navigation instead of rendering from
  `pet.documents`, `pet.insurances`, or `pet.milestones`; dormant
  `PetDocumentsCard` and `PetMilestonesCard` files were removed instead of
  keeping hidden broad-read surfaces alive.
  `PetProtectionDashboardState` now builds from supplied document/insurance
  rows, and the unused `ArchiveMemorySnapshot.init(pet:)` compatibility
  initializer was removed so archive scoring can no longer fall back to
  `pet.healthLogs`, `pet.weightLogs`, `pet.photoLogs`, `pet.milestones`,
  `pet.documents`, `pet.insurances`, or `pet.medications`. Guards/coverage
  added:
  `MemberLifecycleGateTests.archiveFeatureViewsUseRouteScopedRowsInsteadOfPetRelationships`,
  `MemberLifecycleGateTests.protectionDashboardStateUsesSuppliedArchiveRows`,
  and updated `OhanaTests.archiveMemorySnapshotRecommends*` tests to pass
  explicit `PetAllFeaturesActivitySummary`. Validation: source search across
  the touched archive files found no `pet.documents` / `pet.insurances` /
  `pet.milestones` reads and no `ArchiveMemorySnapshot(pet:)` caller; the
  guard also asserts the dormant document/milestone card files stay removed.
  First targeted run exposed a test-helper-only compile issue, then a changed
  smoothness audit flagged the dormant card queries, so those files were
  removed and the route page queries were documented as explicit-navigation
  route scope. Final validation:
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/archiveFeatureViewsUseRouteScopedRowsInsteadOfPetRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/protectionDashboardStateUsesSuppliedArchiveRows()
  -only-testing:OhanaTests/OhanaTests/archiveMemorySnapshotRecommendsBasicInfoForEmptyProfile()
  -only-testing:OhanaTests/OhanaTests/archiveMemorySnapshotRecommendsDocumentsAfterBasicInfo()
  -only-testing:OhanaTests/OhanaTests/archiveMemorySnapshotRecommendsMomentsAfterProtection()
  -only-testing:OhanaTests/OhanaTests/archiveMemorySnapshotRecommendsWeightAfterMemory()
  -only-testing:OhanaTests/OhanaTests/archiveMemorySnapshotRecommendsRetentionWhenComplete()`
  PASSed (7 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_03-55-30-+0200.xcresult`);
  post-check `git diff --check` PASSed; `scripts/dev-check-changed.sh`
  PASSed (SwiftFormat formatted 0 files; changed-file audits PASS; build still
  recommended for the wider dirty compiler surface, but this batch is covered by
  the targeted simulator run above).
  TFU-006 remains Open: PDF/export surfaces and remaining
  action-time/delete/claim bridges still need migration or documented
  containment.
- Progress: 2026-06-25 migrated pet moments/timeline render data to deferred
  route rows. `PetTimelineItemsBuilder` now consumes explicit
  `PetTimelineSourceRows` for care, potty, walk, health, expense, weight,
  photo, and milestone rows; it still uses only scalar `Pet` profile fields for
  generated birthday/home/remembrance moments. `PetMomentsHubRouteContainer`
  no longer owns first-frame `@Query` subscriptions and instead loads the rows
  after the first frame with route-scoped `FetchDescriptor` calls marked
  `// route-first-frame: allow deferred-fetch`. `PetMomentsHubView` and
  `PetPhotoAlbumView` consume the supplied timeline/photo rows and no longer
  render from `pet.careLogs`, `pet.pottyLogs`, `pet.walkLogs`,
  `pet.healthLogs`, `pet.weightLogs`, `pet.expenseLogs`, `pet.photoLogs`, or
  `pet.milestones`. Guards/coverage added:
  `MemberLifecycleGateTests.petMomentsTimelineUsesRouteScopedRowsInsteadOfPetRelationships`,
  `MemberLifecycleGateTests.petTimelineBuilderUsesSuppliedRowsInsteadOfPetRelationships`,
  and updated
  `SharedPetActionRecorderTests.sharedSessionFactIsMarkedForCloudSyncAndTimelineUsesSessionTotals`
  to pass explicit source rows. Validation: source search across the moments,
  timeline, route, and album files found no legacy relationship reads or
  first-frame `@Query`; initial `dev-check` correctly rejected the route
  container `@Query` approach, then the deferred-load rewrite passed
  `scripts/dev-check-changed.sh` (SwiftFormat formatted 0 files; UI,
  accessibility, smoothness, route-first-frame, runtime, economy, member
  lifecycle, derived-state audits PASS). Final targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/petMomentsTimelineUsesRouteScopedRowsInsteadOfPetRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/petTimelineBuilderUsesSuppliedRowsInsteadOfPetRelationships()
  -only-testing:OhanaTests/SharedPetActionRecorderTests/sharedSessionFactIsMarkedForCloudSyncAndTimelineUsesSessionTotals()`
  PASSed (3 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_04-07-30-+0200.xcresult`);
  post-check `git diff --check` PASSed. TFU-006 remains Open:
  PDF/export surfaces and remaining action-time/delete/claim bridges still need
  migration or documented containment.
- Progress: 2026-06-25 migrated CrewRoster pet archive counts to route-scoped
  summaries and removed a dormant expanded overlay broad-read surface.
  `CrewRosterRouteData` now loads `CrewRosterPetSummary` after the first frame
  by doing pet-id-scoped `PetDocument` `fetchCount` queries, then passes only
  `[UUID: CrewRosterPetSummary]` into `CrewRosterOverlay` /
  `CrewRosterProfilePanel`. The active profile panel now renders document count
  from that pure summary instead of `pet.documents.count`, and the unused
  `CrewRosterExpandedMemberOverlay.swift` file was removed because it still
  scanned `pet.documents` / `pet.weightLogs` while having no active source or
  project reference. Guards/coverage added:
  `MemberLifecycleGateTests.crewRosterUsesRouteScopedPetSummariesInsteadOfPetArchiveRelationships`
  and `MemberLifecycleGateTests.crewRosterPetSummaryCountsPetScopedDocuments`.
  Validation: source search across CrewRoster active app source found no
  `pet.documents.count` / `pet.weightLogs`; targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/crewRosterUsesRouteScopedPetSummariesInsteadOfPetArchiveRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/crewRosterPetSummaryCountsPetScopedDocuments()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; compile log removed stale
  `CrewRosterExpandedMemberOverlay` objects; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_04-12-21-+0200.xcresult`).
  TFU-006 remains Open: PDF/export surfaces, remaining high-frequency
  relationship reads, and action-time/delete/claim bridges still need migration
  or documented containment.
- Progress: 2026-06-25 migrated the pet profile health summary card and sitter
  card latest-weight row to deferred pure-value summaries. `PetBasicInfoDetailView`
  now schedules `PetBasicInfoHealthSummary` after the first frame and renders
  vaccine, active medication, symptom, insurance, and latest-weight text from
  that value snapshot instead of sorting `pet.healthLogs`, `pet.medications`,
  `pet.symptomLogs`, `pet.insurances`, or `pet.weightLogs` in computed render
  properties. `SitterCardPreviewSheet` now uses the same pet-id-scoped ledger
  latest-weight helper and no longer reads `pet.weightLogs` while composing or
  rendering the share card. Guards/coverage added:
  `MemberLifecycleGateTests.petProfileCardsUseRouteSummariesInsteadOfPetRelationshipHealthReads`
  and `MemberLifecycleGateTests.petProfileHealthSummaryUsesPetScopedRowsAndLedgerWeight`.
  Validation: source search across the profile health summary and sitter card
  files found no direct `pet.healthLogs` / `pet.medications` / `pet.insurances`
  / `pet.symptomLogs` / `pet.weightLogs`; targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/petProfileCardsUseRouteSummariesInsteadOfPetRelationshipHealthReads()
  -only-testing:OhanaTests/MemberLifecycleGateTests/petProfileHealthSummaryUsesPetScopedRowsAndLedgerWeight()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_04-22-44-+0200.xcresult`).
  TFU-006 remains Open: PDF/export surfaces, remaining high-frequency
  relationship reads, and action-time/delete/claim bridges still need migration
  or documented containment.
- Progress: 2026-06-25 removed dormant `DogActivityCard.swift`, an unused Walks
  UI surface with no active Swift caller or `Ohana.xcodeproj` reference that
  still computed visible dog activity counts from `pet.careLogs` and
  `pet.walkLogs`. The active walk runtime helpers remain unchanged and should
  be handled in a separate runtime-safe batch. Guard added:
  `MemberLifecycleGateTests.dormantDogActivityCardBroadReadSurfaceStaysRemoved`.
  Validation: source search found `DogActivityCard` only in the new guard; targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/dormantDogActivityCardBroadReadSurfaceStaysRemoved()`
  PASSed (1 Swift Testing test, iPhone 17 simulator; compile log removed stale
  `DogActivityCard` objects; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_04-24-31-+0200.xcresult`).
  TFU-006 remains Open: PDF/export surfaces, remaining high-frequency UI/report
  relationship reads, and action-time/delete/claim/runtime bridges still need
  migration or documented containment.
- Progress: 2026-06-25 migrated the veterinarian PDF export to a pure snapshot
  boundary. `PetVetSummaryPDFRenderer.render` now receives a `ModelContext`,
  builds `PetVetSummaryPDFSnapshot` through pet-id-scoped `FetchDescriptor`
  queries for health logs, active medications, symptoms, insurance, documents,
  and CareLedger weight rows, then renders `PetVetSummaryPDFView` from the value
  snapshot. The PDF view no longer reads `pet.healthLogs`, `pet.medications`,
  `pet.symptomLogs`, `pet.insurances`, `pet.documents`, or `pet.weightLogs`;
  latest weight and the three-month trend use `.weight` `CareLedgerEvent` rows,
  not legacy `PetWeightLog`. Guards/coverage added:
  `MemberLifecycleGateTests.petVetSummaryPDFUsesSnapshotInsteadOfPetRelationshipReads`
  and `petVetSummaryPDFSnapshotUsesPetScopedRowsAndLedgerWeight`. Validation:
  source search found no legacy relationship reads in the PDF export surface and
  no stale `render(pet:)` calls; targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/petVetSummaryPDFUsesSnapshotInsteadOfPetRelationshipReads()
  -only-testing:OhanaTests/MemberLifecycleGateTests/petVetSummaryPDFSnapshotUsesPetScopedRowsAndLedgerWeight()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_04-33-35-+0200.xcresult`).
  TFU-006 remains Open: remaining high-frequency UI/report relationship reads
  and action-time/delete/claim/runtime bridges still need migration or
  documented containment.
- Progress: 2026-06-25 migrated the expense and insurance explicit-route
  surfaces to route-scoped rows. `ExpenseHistoryDataContainer` now defers
  `ExpenseHistoryRouteData.load` until after the first frame, then pet-id-scoped
  fetches `PetExpenseLog`, humans, pets, and shared-care sessions and passes
  those rows through `ExpenseHistoryContentView` into
  `PetExpenseDashboardContent`; the history filter and six-month chart no longer
  read `pet.expenseLogs`. `AddExpenseSheet` also uses pet-id-scoped expense and
  insurance queries for quick amount
  suggestions, active insurance selection, and claim expense matching instead
  of reading `pet.expenseLogs` or `pet.insurances`. `PetInsuranceView` uses a
  route-scoped insurance query after explicit navigation instead of rendering
  from `pet.insurances`. Guard updated:
  `MemberLifecycleGateTests.expenseHistoryDashboardUsesRouteScopedRowsInsteadOfPetExpenseRelationship`.
  Validation: source search found no `pet.expenseLogs` or `pet.insurances`
  relationship reads in `ExpenseHistoryDataContainer.swift`,
  `ExpenseHistoryView.swift`, `AddExpenseSheet.swift`,
  `PetExpenseDashboardContent.swift`, or `PetInsuranceView.swift`; targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/expenseHistoryDashboardUsesRouteScopedRowsInsteadOfPetExpenseRelationship()`
  PASSed after the deferred-fetch correction (1 Swift Testing test, iPhone 17
  simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_04-44-44-+0200.xcresult`);
  `scripts/dev-check-changed.sh` PASSed with route-first-frame audit clean.
  TFU-006 remains Open: remaining high-frequency UI/report relationship reads
  and action-time/delete/claim/runtime bridges still need migration or
  documented containment.
- Progress: 2026-06-25 migrated the CoHealth dashboard compact/full surfaces to
  a shared route-scoped value snapshot. `CoHealthDashboardDataContainer` and
  `CoHealthDashboardFullDataContainer` no longer add first-frame `@Query`
  subscriptions for all pets; they defer `CoHealthDashboardSnapshot.load` until
  after the first frame and refresh on home revision updates. Compact and full
  content views now render pet association, walk distance, pet weight trend,
  latest pet weight, seven-day walk bars, and pet health summaries from
  `CoHealthPetSnapshot` / `CoHealthWalkEvent` / `CoHealthWeightPoint` values.
  Pet walk and pet weight inputs come from pet-subject `CareLedgerEvent` rows,
  not `pet.walkLogs` or `pet.weightLogs`; human weight input is fetched
  route-scoped into values. Guards/coverage added:
  `MemberLifecycleGateTests.coHealthDashboardsUseSnapshotInsteadOfPetWalkAndWeightRelationships`
  and `coHealthDashboardSnapshotUsesLedgerRowsForPetWalkAndWeight`, the latter
  proves legacy `PetWalkLog` / `PetWeightLog` rows do not drive CoHealth pet
  walk/weight metrics when ledger rows are present. Validation: targeted
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/coHealthDashboardsUseSnapshotInsteadOfPetWalkAndWeightRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/coHealthDashboardSnapshotUsesLedgerRowsForPetWalkAndWeight()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_04-53-30-+0200.xcresult`).
  TFU-006 remains Open: medication-heavy render/action paths and remaining
  action-time/delete/claim/runtime bridges still need migration or documented
  containment.
- Progress: 2026-06-25 migrated medication-heavy high-frequency surfaces to
  deferred route rows. `PetMedicationView`, `IslandMedicationDashboard`, and
  `PetHealthDetailView` no longer add route/data-container `@Query`
  subscriptions or compute render state from `pet.medications`; they consume
  `PetMedicationRouteData` / `IslandMedicationRouteData` rows loaded after the
  first frame. `PetMedicationDetailSheet` also dropped the broad global
  `Event` query and now reloads only current-medication dose events after user
  entry into the sheet. Add/edit/dose/delete/activation actions refresh the
  route rows through explicit callbacks instead of relying on live broad reads.
  Guards/coverage added:
  `MemberLifecycleGateTests.medicationSurfacesUseRouteScopedRowsInsteadOfPetMedicationRelationship`
  and `medicationRouteDataScopesMedicationRowsAndDoseEvents`, the latter proves
  pet medication rows, island medication grouping, and detail dose events are
  scoped to the target pet/medication and ignore unrelated dose events.
  Validation: targeted `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/medicationSurfacesUseRouteScopedRowsInsteadOfPetMedicationRelationship()
  -only-testing:OhanaTests/MemberLifecycleGateTests/medicationRouteDataScopesMedicationRowsAndDoseEvents()`
  PASSed (2 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_05-02-55-+0200.xcresult`).
  TFU-006 is now closed: remaining action-time/delete/claim/runtime bridges are
  documented containment paths, and future user-visible debt should be tracked
  under narrower follow-ups.
- Release-bar disposition: Does not block first release. Current evidence from
  ledger-backed QuickCare/Home/Feeding/Hygiene/TodayFocus read-model tests,
  `scripts/module-exit-gate.sh --full`, release-hardening audits, and CI run
  `27607807044` shows no crash, data loss, privacy leak, complete core-flow
  break, or economy miscalculation. Remaining work is consistency/performance
  hardening and removal of legacy compatibility reads.
- Close condition met: user-facing care and family presentation read models no longer
  directly query the legacy pet log models except for explicit backup,
  migration, route-scoped compatibility, or action-time single-id paths.
- Closed: 2026-06-25. Final closure batch moved the last active Home/report
  health-alert callers off the `scanAlerts(pets:)` compatibility path:
  `PetHealthAlertSourceRouteData` now bulk-loads pet-scoped health alert source
  rows after the first frame, `HomeReadModelActor` passes those sources into
  `VerticalSolidHomeSnapshotBuilder`, and `FamilyWeeklyReportRouteData` passes
  the same source values into the dashboard. Guard coverage added/updated:
  `HomeReadModelStoreTests.storeSourceDoesNotReintroduceMainContextCompatibilityFetch`,
  `MemberLifecycleGateTests.familyWeeklyReportsUseDeferredLedgerReadModelInsteadOfPetRelationshipLogs`,
  `healthSurfacesUseRouteScopedRowsInsteadOfPetHealthRelationships`, and
  `petHealthRouteDataScopesHealthRowsAndAlertSource`. Final residual scan found
  no active Home read-model or FamilyWeeklyReport `scanAlerts(pets:)` caller;
  remaining `pet.*Logs` / relationship reads are physical deletion, activity
  cleanup, explicit command/action-time bridges, background calendar/notification
  compatibility, legacy `PetHealthAlertEngine.scanAlerts(pets:)`, Oasis runtime
  fallback, or non-CareLedger medication/deeplink helpers. Validation:
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/MemberLifecycleGateTests/familyWeeklyReportsUseDeferredLedgerReadModelInsteadOfPetRelationshipLogs()
  -only-testing:OhanaTests/MemberLifecycleGateTests/healthSurfacesUseRouteScopedRowsInsteadOfPetHealthRelationships()
  -only-testing:OhanaTests/MemberLifecycleGateTests/petHealthRouteDataScopesHealthRowsAndAlertSource()
  -only-testing:OhanaTests/HomeReadModelStoreTests/storeSourceDoesNotReintroduceMainContextCompatibilityFetch()`
  PASSed (4 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_05-57-00-+0200.xcresult`).

### TFU-20260612-007 - Validate shared-care CloudKit behavior on two devices

- Status: Done
- Priority: P0
- Area: Cloud Sync / Shared Care
- Source task: Care maturity remediation, 2026-06-12
- Blocker: The repository can prove local mutation metadata and tombstones, but
  it cannot prove real CloudKit propagation, conflict ordering, or sync-storm
  behavior without two signed-in devices or equivalent CloudKit integration
  infrastructure.
- Next step: Run the shared-care checklist in `docs/cloud-sync-todo.md` on two
  real devices, including private and shared database flows, cascade tombstones,
  legacy cleanup, orphan preservation diagnostics, and the sync-storm check.
- Closed: 2026-06-12 as an accepted external follow-up because the current owner
  does not have a paid developer account, CloudKit provisioning, or two signed-in
  devices. The required validation is preserved in `docs/cloud-sync-todo.md`.
- Close when: Shared-session cascade tombstones propagate correctly and
  reconcile-driven `markModified` calls do not create repeated upload loops.

### TFU-20260612-008 - Add missing CareEventService and care command tests

- Status: Done
- Priority: P1
- Area: Care / Tests
- Source task: Care maturity remediation, 2026-06-12
- Blocker: Planned-feed and planned-water happy paths now directly cover reward
  economy, reminder completion, family-task linkage, and ledger writes, but
  additional `CareEventService` edge/failure paths still rely on indirect
  coverage. Direct `CareEventService` coverage now includes the linked
  litter-to-potty write path with two ledger events plus quick-action reminder
  handoff, and the no-event planned feed/water failure path that must write no
  care facts, ledgers, rewards, or family-task completions. Reminder reopen now
  has direct coverage for the `ReminderCompletionService` to family-task handoff,
  and `FamilyTaskService.syncReopenedReminder` now proves completed reminder
  tasks reopen without mutating pending-review reward tasks. Planned-water
  catch-up rejection after the allowed window now directly proves no water log,
  ledger event, reward call, reminder completion, or family-task completion is
  written on the rejected path. Direct hygiene service coverage now proves
  `CareEventService.recordHygieneFact` writes a `PetHygieneLog`, hygiene ledger
  event, reward metadata, and quick-action reminder handoff with the expected
  actor/type/date. Direct potty service coverage now proves
  `CareEventService.recordPotty` writes a `PetPottyLog`, potty ledger event,
  reward metadata, and quick-action reminder handoff with the expected
  actor/type/date. Planned-care lifecycle denial now directly proves a
  passed-away pet's feed/water reminder completion returns nil and leaves care
  facts, ledgers, reminder status/completion markers, family-task completion,
  notification cancellation, first-meal state, and economy awards untouched.
  Planned-care schedule-boundary denial now also directly proves an active pet
  with a reminder/event whose schedule subject resolves to a missing human
  returns nil and leaves care facts, ledgers, reminder status/completion
  markers, occurrence completion, family-task completion, notification
  cancellation, first-meal state, and economy awards untouched. Direct service
  lifecycle denial now also covers `recordCareFact`, `recordPottyFact`,
  `recordHygieneFact`, and `recordHealthFact` on a passed-away pet: each returns
  no-op/zero reward and leaves care, potty, hygiene, health, ledger, economy, and
  quick-reminder side effects empty.
- Next step: Closed. Future care negative-path expansion should be logged as a
  new narrower follow-up only if a concrete untested failure mode is found.
  `PetHygieneCommandService` record/delete/plan/executor coverage exists in
  `HomeCommandExecutorTests`, and the grooming overdue warning path is now
  covered in `OhanaTests`. `CatCareCommandService` now has dedicated command
  coverage for non-hygiene records and wrong-pet undo isolation.
  `QuickPottyCommandExecutor` and `QuickPottyUnknownClaimStore` now cover the
  unknown shared potty claim flow in `HomeCommandExecutorTests`.
- Progress: 2026-06-24 expanded
  `careEventServicePlannedCareDeniedByLifecycleWritesNoDerivedSideEffects` to
  cover a second no-write failure path: active pet care fact authorization
  succeeds, but the planned reminder's schedule subject points at a missing
  human so schedule mutation authorization fails before any fact write. The
  same test now asserts feed/water return nil and no `PetCareLog`,
  `CareLedgerEvent`, reminder completion/status, event occurrence completion,
  family-task completion, notification cancellation, first-meal state, or
  economy award is written. Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/OhanaTests` PASS (135 Swift Testing tests, iPhone 17
  simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_01-49-42-+0200.xcresult`).
- Progress: 2026-06-24 added
  `careEventServiceDirectPetFactsDeniedByLifecycleWriteNoDerivedSideEffects`.
  It constructs a passed-away pet with a valid executor and calls direct
  `CareEventService` pet-fact entry points for care/litter with linked potty,
  potty, hygiene, and health. Each path now directly proves no fact is persisted,
  no ledger is recorded, no reward or first-meal state is produced, and no
  quick-action reminder handoff runs. Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/OhanaTests` PASS (136 Swift Testing tests, iPhone 17
  simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_02-05-24-+0200.xcresult`).
- Current task disposition: Closed. The current remediation has direct coverage for the high-risk
  success chains, no-write guard paths, lifecycle denial, catch-up rejection,
  schedule-boundary denial, reopen syncing, hygiene, potty, command services,
  and unknown-potty claim flow; the remaining tests are incremental edge/failure
  coverage rather than a blocker for this closeout.
- Closed: 2026-06-24. The listed services now have direct behavior tests covering
  success, edge, lifecycle-denied, schedule-boundary, catch-up rejection, command,
  and recovery handoff paths instead of relying only on indirect shared-care
  tests.

### TFU-20260612-009 - Harden care fetch failures and large-data reconciliation

- Status: Done
- Priority: P2
- Area: Care / Performance / Diagnostics
- Source task: Care maturity remediation, 2026-06-12
- Resolution: Shared-session maintenance now logs fetch failures and uses
  legacy-model + legacy-id predicates for ledger cleanup. `CareLedgerBackfillService`
  now checks existing ledger rows with legacy-model + legacy-id predicates instead
  of building a full existing-ledger key set. PetCare, Potty, and Hygiene command
  delete paths now use exact ledger predicates and warning fetch helpers.
  QuickPotty now logs fetch failures and narrows latest-log and unknown-claim
  lookups to the target pet/session. `HomeCommandExecutor` now logs fetch failures
  on its quick-care entry-point fetches and narrows recent care log fetches to
  the target pet. `ReminderActionCoordinator` now logs reminder/medication lookup
  fetch failures. `QuickPlayCommandExecutor` and `QuickWaterCommandExecutor` now
  log command-executor fetch failures. QuickCare detail views now log legacy-plan
  lookup failures. Feeding command read helpers, quick-feed executor fetches,
  stock expense lookup, and stock reminder reconciliation now log fetch failures,
  and care plan calendar sync, quick-action reminder completion sync, reminder
  maintenance, and calendar task completion cleanup now log fetch failures.
  Startup feed auto-log maintenance, human requirement resolution, member theme
  color normalization, and avatar asset compaction now log fetch failures.
  Backup restore de-duplication now logs fetch failures and aborts restore
  instead of treating failed reads as empty stores. `FamilyTaskService` now logs
  legacy bounty, reminder linkage, human lookup, and wallet-transfer fetch
  failures. `CoconutWalletService`, coconut bootstrap import, and developer
  wallet overrides now log account/projection fetch failures instead of silently
  treating failed reads as empty wallet state. `HomeReadModelStore` now logs
  home entity, event, reminder, legacy compatibility, family-task, and exchange
  request fetch failures instead of silently collapsing the home snapshot to
  empty sections. `TodayFocusEconomyService` now logs Today Focus economy input
  fetch failures instead of treating missing pets, humans, plants, reminders,
  events, and same-day care logs as successful empty reads.
  `EventCompletionCommandService` now logs calendar completion reward lookups for
  same-day care logs, existing reward transactions, and reward executor humans.
  `StarterGiftService` now logs starter-gift human/pet/ledger count reads and
  active-human lookup failures instead of treating failed onboarding reads as
  fresh-install empty state. `OnboardingJourneyCoordinator` now logs recorded
  care-fact lookup failures, and `RainbowBridgeService` now logs future reminder
  and event cleanup fetch failures while narrowing those fetches to future
  relevant rows. `CatCareCommandService` now logs undo artifact fetch failures
  and narrows undo lookups to the target event/log identifiers.
  `MedicationCommands` now logs human medication reminder-sync fetch failures
  and pet/human medication calendar cleanup fetch failures instead of silently
  treating failed reads as empty medication/event sets.
  `DashboardRecordCommands` now logs dashboard ledger cleanup fetch failures and
  uses legacy-model + legacy-id predicates when deleting weight/expense ledger
  events. `PetMilestoneCommands` and `WorkoutCommands` now log ledger cleanup
  fetch failures and use legacy-model + legacy-id predicates when deleting
  milestone/workout ledger events. `HumanWishlistCommands` and
  `PetDocumentCommands` now log ledger cleanup fetch failures, narrow ledger
  cleanup to legacy-model + legacy-id predicates, and avoid silently treating
  document payer lookup failures as missing payers. Core `QuestManager` reward
  paths, backdate check-in active-human resolution, persisted economy budget
  reads, care-object counting, and reminder auto-completion now log fetch
  failures and avoid broad human scans on reward attribution.
  `MemberDeletionCommands` now logs fetch failures while resolving remaining
  humans and pet-related events during deletion. `Pet` model helpers now log
  shared feed-session and activity-event fetch failures, while activity event
  cleanup filters by pet in the SwiftData predicate. `HumanMedicationLogStore`
  now logs failed matching-log fetches before falling back to create/update
  behavior. Gacha draw-log and owned-item fetches now log failures before
  falling back to empty collections. `CoconutLogView` member snapshot fetches
  now log human/pet read failures, and `OasisCritterEconomyService` current
  human lookup now uses a bounded UUID predicate with warning logs for invalid
  ids and fetch failures. `OasisUpgradeRewardService` inventory/opening/upgrade
  paths now log critter, fragment, unlock, featured-critter, and active-critter
  fetch failures; upgrade-coconut generation now fetches only the relevant level
  range and throws on read failure instead of inserting from an untrusted empty
  result. `OasisRewardLiveDataStore` now logs live snapshot fetch failures, and
  Oasis critter lifecycle daily action-log reads now use a critter/date predicate
  with warning logs instead of fetching all action logs. `OasisTreeManager`
  energy/revision reads now log ledger count, cursor, incremental event, full
  ledger, and legacy plant-event count failures instead of silently collapsing
  tree energy inputs to empty values. Current app-code scans for
  `try? context.fetch`, `try? context.fetchCount`, `try? modelContext.fetch`,
  and `try? modelContext.fetchCount` are clear; remaining matches are test helper
  assertions only.
- Next step: None for this follow-up. Keep broader P0/P1/P3 care migration,
  CloudKit validation, and product read-model follow-ups tracked separately.
- Close when: Closed on 2026-06-12 after app-code silent fetch scans were clear
  and Oasis tree/ledger reads were hardened.

### TFU-20260612-010 - Unify care status read models and expand ledger analysis

- Status: Open
- Priority: P3
- Area: Care / Product Completeness
- Source task: Care maturity remediation, 2026-06-12
- Blocker: This is product/read-model polish rather than a correctness blocker;
  it should follow the P0 CareLedger read-model migration so the UI does not
  consolidate around soon-to-be-replaced sources.
- Next step: Share overdue/status feedback between Hygiene and QuickCare, then
  extend `CareLedgerAnalysisView` with trend and actor dimensions from
  `CareLedgerEvent.actorKind` / `actorId`.
- Current task disposition: Accepted product follow-up. This is intentionally
  deferred until the P0 read-model migration follow-up settles, so the product
  polish lands on the final ledger-backed status source instead of reinforcing
  transitional read paths.
- Close when: Hygiene and QuickCare display the same status source and ledger
  analysis includes trend plus executor/family-member breakdowns.

### TFU-20260612-011 - Clean legacy shared-care metadata from persisted notes

- Status: Done
- Priority: P0
- Area: Shared Care / Data Cleanup / Cloud Sync
- Source task: Care maturity remediation, 2026-06-12
- Blocker: Production shared-care writes now store user-visible notes only, and
  `scripts/audit-shared-care-note-metadata.sh` prevents new app-code writes of
  `ohana_shared_*` machine prefixes. `SharedCareSessionMaintenance` now has an
  idempotent `cleanLegacyNoteMetadata` path that strips recoverable legacy
  prefixes from `SharedCareSession.note`, `PetCareLog.note`,
  `PetExpenseLog.note`, shared-walk `behaviorNotes`, and linked
  `CareLedgerEvent.note` only after structured session fields are recovered or
  verified. The cleanup also recovers target ids, total feed/water amounts,
  expense totals/categories, stock owner, and primary legacy model references
  before stripping metadata, and tests cover modified-state staging plus a
  second no-op cleanup pass. Backup import now runs the cleanup after restored
  model data is saved, and a regression test covers recoverable legacy prefixes
  being stripped during backup apply. Existing installed data is now covered by
  a versioned startup-maintenance trigger that runs after CareLedger backfill and
  stores `ohana_shared_care_legacy_note_cleanup_version` when the cleanup has
  been attempted. It intentionally leaves orphan legacy notes in place when the
  structured `SharedCareSession` is missing, because those notes may be the only
  remaining source of stock/target facts; the cleanup result now reports
  skipped orphan care logs, expense logs, walk logs, ledger events, and missing
  session ids so the maintenance path is observable instead of silently
  skipping them. Recoverable records whose raw relationship is broken but whose
  note still contains a valid session id are grouped through the cleanup scan and
  have `sharedSessionId` restored before metadata is stripped, including shared
  walk logs whose raw relationship was empty. `CareLedgerEvent` now participates
  in the upload/apply pipeline with serializer, local dirty-batch fetch, remote
  insert/update/delete handling, and tests covering cleaned notes in payloads and
  fetched records. `CloudSyncMetadataServiceTests` now includes a local
  two-device-equivalent regression: legacy shared-care records are applied
  through `CloudSyncRecordApplier`, cleaned once, staged as clean dirty payloads,
  and verified as idempotent on a second cleanup pass. Orphan facts now have a
  privacy-safe diagnostic path through
  `SharedCareSessionMaintenance.legacyOrphanNoteDiagnostics(context:)`: it
  reports source model, record id, missing session id, stock/target machine
  facts, linked legacy model ids, and visible-note length without exporting the
  user note body.
- Next step: Run the shared-care legacy cleanup checklist in
  `docs/cloud-sync-todo.md`, including a two-device run where startup cleanup
  reports nonzero skipped orphan counts and the privacy-safe orphan diagnostic
  report is available for inspection.
- Closed: 2026-06-12 as an accepted external follow-up because the repository
  implementation, local migration tests, backup cleanup, startup cleanup,
  CloudSync serializer/apply coverage, and audit guardrail are complete, while
  the remaining two-device CloudKit validation requires a paid developer account,
  provisioning, CloudKit Dashboard access, and physical devices. The validation
  checklist remains in `docs/cloud-sync-todo.md`.
- Close when: Legacy shared-care note prefixes are cleaned from persisted data
  through a measured migration/maintenance path, no production source writes
  them, and CloudKit two-device validation confirms the cleanup does not
  produce repeated remote modifications.

### TFU-20260612-012 - Move pet activity cleanup out of the Pet model

- Status: Done
- Priority: P0
- Area: Models / Members / Domain Commands
- Source task: Models Phase 1 P0 remediation, 2026-06-12
- Blocker: The Models session is scoped to `Ohana/Models`; fully fixing this
  requires changing the caller in `Ohana/Features/Members/MemberInteractionCommands.swift`
  and likely moving `Pet.clearAllActivityRecords(in:)` into a feature command
  or domain service. The current model method fetches/deletes SwiftData records,
  cancels notifications, resets streak state, and saves the context from inside
  an `@Model`, which violates the model-layer boundary.
- Next step: In a cross-scope repair, add a command/service that owns the
  activity cleanup transaction, updates the Members caller to use it, then
  remove the persistence/notification side effects from `Pet`.
- Current task disposition: Closed during Domain Phase 2. The cleanup is now
  owned by `PetActivityRecordCleanupService`, the Members command delegates to
  that service, and `Pet` no longer owns `ModelContext` fetch/delete/save or
  notification cancellation.
- Closed: 2026-06-12 with
  `OhanaTests/PetActivityRecordCleanupServiceTests.swift` covering related
  event/reminder deletion, notification cancellation, activity-log deletion,
  unrelated-pet preservation, document/insurance preservation, and streak reset.
- Close when: `Pet` no longer owns `ModelContext` fetch/delete/save or
  notification cancellation, the Members cleanup path calls the new command or
  service, and in-memory SwiftData tests cover event/reminder/log deletion plus
  preserved documents/insurances.

### TFU-20260612-013 - Remove duplicate WeightHistoryView source file

- Status: Closed
- Priority: P0
- Area: DashboardRecords / Validation
- Source task: Models Phase 1 P0 remediation validation, 2026-06-12
- Blocker: `Ohana/Features/DashboardRecords/Views/WeightHistoryView.swift` and
  `Ohana/Features/DashboardRecords/Views/WeightHistoryView 2.swift` are both
  tracked and both declare `struct WeightHistoryView`, so unfiltered app test
  builds fail before the Models tests can run. The Models session is not allowed
  to repair DashboardRecords.
- Next step: Closed by deleting the duplicate tracked source file during the
  explicitly authorized cross-scope validation repair.
- Current task disposition: Models targeted tests were previously run with
  `EXCLUDED_SOURCE_FILE_NAMES=WeightHistoryView\ 2.swift` solely to isolate the
  Models fixes; rerun the gate without exclusions after this repair.
- Closed: 2026-06-12 by removing
  `Ohana/Features/DashboardRecords/Views/WeightHistoryView 2.swift`, the Xcode
  duplicate that was accidentally added in `3eae88d7`.
- Close when: The duplicate declaration is gone and
  `scripts/test-simulator.sh -only-testing:OhanaTests/SharedModelContainerRecoveryTests`
  plus `scripts/module-exit-gate.sh` run without excluding DashboardRecords
  sources.

### TFU-20260612-014 - Finish Domain presentation and infrastructure boundary cleanup

- Status: Open - notification scheduling, generated-copy, and local
  concrete-adapter hard gates are fixed/tested; push/CI/fresh pure review still
  open.
- Priority: P1
- Area: Domain / Architecture / Localization / Notifications
- Source task: Domain Phase 2 analysis, 2026-06-12
- Blocker: The remaining Domain issues are broad architectural cleanup rather
  than the P0 activity-cleanup/blocking-build repair. Fixing them cleanly should
  happen as a dedicated pass so adapters can move without disturbing service
  behavior.
- Next step: Push a coherent batch, inspect CI once, and run a fresh pure review
  of the Domain architecture/localization surface. Keep notification scheduling
  on the injected `ReminderNotificationScheduling` boundary added in the
  2026-06-24 repair.
- Current task disposition: Accepted P1 follow-up for Domain Phase 2. The P0
  production path violations were removed or moved behind a Domain service; the
  app/runtime adapters and Domain service SwiftUI `Color` leaks were partially
  addressed in the 2026-06-15 Domain write-kernel Phase 7 pass. The remaining
  items do not block the current module exit gate but should be resolved before
  release-hardening freeze.
- Progress: 2026-06-24 Domain notification side-effect paths were moved off
  direct mutable `OhanaNotifications.current` reads. Added
  `ReminderNotificationSchedulerRegistry`, kept `OhanaNotifications` as a
  compatibility wrapper, injected `ReminderNotificationScheduling` through
  `ReminderCompletionService`, `CareEventServiceDependencies`,
  `PhysicalDeletionService`, `PetActivityRecordCleanupService`, and schedule
  dispatchers, and registered the live `NotificationManager` through
  `AppServices`. Guard evidence: `rg -n "OhanaNotifications\\.current"
  Ohana/Domain` found no matches; `scripts/audit-architecture-boundaries.sh
  --all` PASS; `scripts/test-simulator.sh
  -only-testing:OhanaTests/OhanaNotificationsSchedulingTests` PASS (12 tests,
  iPhone 17 simulator); `git diff --check` PASS. Remaining close conditions are
  broader than this subitem, so the TFU stays Open.
- Progress: 2026-06-24 refreshed local architecture/localization evidence on
  the current worktree. `rg -n "^import SwiftUI" Ohana/Domain -g '*.swift'`
  found no Domain SwiftUI imports; `rg -n "OhanaNotifications\\.current"
  Ohana/Domain -g '*.swift'` found no Domain direct notification singleton
  reads; `scripts/audit-architecture-boundaries.sh --all` PASS; and
  `scripts/audit-localization-coverage.sh` PASS. This supports the local
  cleanup evidence but does not satisfy the remaining push/CI/fresh pure review
  close condition, so the TFU stays Open.
- Progress: 2026-06-24 localized the Domain backup error slice. `BackupError`
  and `AutomaticBackupFileStoreError` now expose `localizedMessage(l:)` and use
  `L10n.current.tr` for user-visible error descriptions instead of returning
  hardcoded Chinese copy. Added `LocalizationTests` coverage for zh/en/de
  backup and automatic-backup error messages. Validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/LocalizationTests` PASS
  (13 tests, iPhone 17 simulator). Remaining generated Domain strings such as
  medication dose titles, overdue labels, and shared care reward titles still
  need localization cleanup before this TFU can close.
- Progress: 2026-06-24 localized the CarePlan calendar title slice.
  `CarePlanCalendarSync` now generates default care-plan, breed-risk, water,
  filter, litter, and play calendar `Event.title` values through `L10n.current`
  instead of hardcoded Chinese title strings, while legacy cleanup still matches
  the old Chinese aliases for existing stored events. Added
  `OhanaTests.carePlanCalendarSyncGeneratesLocalizedDefaultTitles` to assert
  English and German generated event titles, and pinned existing Chinese
  care-plan assertions to `appLanguage = zh` so they no longer depend on test
  environment language state. Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/OhanaTests` PASS (137 Swift Testing tests, iPhone 17
  simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_02-52-44-+0200.xcresult`).
  Remaining generated Domain strings include overdue labels and shared-care
  reward titles.
- Progress: 2026-06-24 localized the PetMedicationDoseLogging generated-title
  slice. Medication dose `Event.title`, care ledger notes that mirror the event
  title, and the general reward title now come from `L10n.current` instead of
  hardcoded Chinese strings. Updated
  `HomeCommandExecutorTests.petMedicationDoseRewardUsesExecutorBudgetAndCooldownPipeline`
  to pin `appLanguage = en` and assert the event title, ledger note, and budget
  action key no longer use the old Chinese reward label. Validation:
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/HomeCommandExecutorTests/petMedicationDoseRewardUsesExecutorBudgetAndCooldownPipeline()`
  PASS (1 Swift Testing test, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-00-31-+0200.xcresult`);
  `scripts/audit-localization-coverage.sh` PASS; `git diff --check` PASS;
  `scripts/dev-check-changed.sh` PASS (the build recommendation reflects the
  broader dirty worktree; the targeted simulator test above compiled this
  slice). Remaining generated Domain strings include overdue labels and the
  broader infrastructure adapter cleanup.
- Progress: 2026-06-24 localized the shared-care/reward-title slice.
  `DomainCareRewardAction.title(pet:)` now accepts a `L10n` snapshot and routes
  feed, water, walk, hygiene, health, expense, weight, milestone, Today Focus,
  potty, luck suffixes, and reward quality badges through localized copy instead
  of hardcoded Chinese strings. `QuestManager.awardAction` and
  `awardSharedCareAction` reuse the same language snapshot when composing
  wallet titles, shared-care pet-name lists, and human shared-care reward titles.
  Added `LocalizationTests.domainCareRewardCopyResolvesLocalizedTitles` for
  zh/en/de reward-title and badge coverage. Validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/LocalizationTests` PASS
  (14 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-08-35-+0200.xcresult`);
  `scripts/audit-localization-coverage.sh` PASS; `git diff --check` PASS;
  `scripts/dev-check-changed.sh` PASS (the build recommendation reflects the
  broader dirty worktree; the targeted simulator test above compiled this
  slice). Remaining generated Domain strings include overdue labels and the
  broader infrastructure adapter cleanup.
- Progress: 2026-06-24 localized the overdue/status generated-copy slice.
  `CarePlanOverdueStatus` now exposes `compactText(l:)`,
  `localizedTitle(l:)`, and `localizedOverdueText(l:)`; `WaterCareCycleStatus`
  now exposes `compactDueText(l:)`; Home status badges, interaction snapshots,
  and expanded quick-action overdue/due strings consume those pure localized
  helpers instead of reading raw Chinese fallback text. Added
  `LocalizationTests.carePlanOverdueCopyResolvesLocalizedStatus` for zh/en/de
  overdue and water-cycle copy, and extended
  `HomeSnapshotBuilderTests.snapshotDecoratesOverduePetStatus` to assert the
  same Home card status can render Chinese and English from an explicit `L10n`
  snapshot. Validation: `scripts/test-simulator.sh
  -only-testing:OhanaTests/LocalizationTests
  -only-testing:OhanaTests/HomeSnapshotBuilderTests` PASS (35 Swift Testing
  tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-14-26-+0200.xcresult`).
  TFU-014 remains Open for concrete-adapter cleanup, broader generated-copy
  review, push/CI, and fresh pure review.
- Progress: 2026-06-24 localized the remaining Domain generated-copy slice
  found by the broad CJK audit. Shared multi-pet reward titles, calendar
  completion general reward titles, calendar undo wallet titles, care-ledger
  report fallback/category titles, anti-repeat executor labels, and `EntityKind`
  display names now resolve through explicit `L10n` helpers instead of
  hardcoded Chinese display strings. Refreshed local adapter hard gates also
  found no Domain/App/Feature concrete dependency violations:
  `scripts/audit-architecture-boundaries.sh --all` PASS. Validation:
  `scripts/test-simulator.sh -only-testing:OhanaTests/LocalizationTests` PASS
  (16 Swift Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-24-53-+0200.xcresult`);
  `scripts/test-simulator.sh
  -only-testing:OhanaTests/SharedPetActionRecorderTests
  -only-testing:OhanaTests/QuestManagerBatchAwardTests` PASS (34 Swift
  Testing tests, iPhone 17 simulator; xcresult
  `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.24_03-23-26-+0200.xcresult`);
  `scripts/audit-localization-coverage.sh` PASS; `git diff --check` PASS.
  The remaining Domain CJK hits are parser/legacy cleanup matchers or internal
  fallback titles whose Home/status render paths now consume localized helpers.
  TFU-014 remains Open for push/CI and fresh pure review.
- Close when: Domain app-code contains no `import SwiftUI`, Domain services no
  longer instantiate App/Feature infrastructure concrete types directly, generated
  user-visible Domain strings are localized, and notification side effects in
  reminder/care static paths are covered through injected fakes.

### TFU-20260612-015 - Move executor picker queries out of Shared

- Status: Done
- Priority: P1
- Area: Shared / QuickCare / Architecture / Smoothness
- Source task: Shared Phase 3 analysis, 2026-06-12
- Blocker: `Ohana/Shared/Components/ExecutorPickerBarRouteContainer.swift`
  keeps a SwiftData `@Query` inside a reusable Shared route container. It is
  currently used by QuickCare sheets, so fixing it cleanly crosses the Shared
  boundary into the QuickCare feature owner.
- Next step: During the QuickCare phase, move the `Human` fetch into a
  feature-owned screen/container or route-scoped snapshot builder, then pass a
  lightweight `[Human]`/executor snapshot into the pure `ExecutorPickerBar`.
- Current task disposition: Closed in Phase 5 by moving the SwiftData fetch into
  `Ohana/Features/QuickCare/QuickCareExecutorPickerBarContainer.swift` and
  keeping `ExecutorPickerBar` as the pure Shared component.
- Closed: 2026-06-12 with `ExecutorPickerBarTests` covering empty and
  multi-human picker render states.
- Close when: Shared reusable components no longer own SwiftData `@Query` for
  executor picking, QuickCare sheets still render executor choices, and a
  focused validation covers empty and multi-human picker states.

## Done

Move completed entries here instead of deleting them when the history is useful.

### TFU-20260614-007 - Propagate historical fact-only disposition through care command revisions

- Status: Done
- Priority: P1
- Area: Economy / Care Commands / Revision Publishing / UI Feedback /
  Historical Fact-only
- Source task: Economy fresh pure adversarial review; Codex pure review session,
  2026-06-14.
- Blocker: 本轮纯复审发现 `CareFactWriteDisposition.memorialHistoricalFactOnly`
  仍没有贯穿所有 command / revision 层。多个 command result 只暴露 `didRecord`，
  或 publisher 只消费 `didRecord`，导致离世宠物历史 fact-only 虽然已在 service 层
  跳过 reward / ledger / reminder / Oasis，却仍被上层当作 success revision。
  代表坏例：`QuickFeedCommandExecutor.completePlanned`、`QuickWaterCommandExecutor.completePlannedWater`
  和 `HomeCommandExecutor.completePlannedFeed` 发布 planned completion mutation 时只看
  `didRecord`；`PetCareTrackingCommandResult`、`PetHygieneCheckInCommandResult`、
  `CatCareCommandResult`、`PetHealthCommandResult`、`WeightCommandResult` 等入口族
  没有把 `allowsDerivedEffects` 作为 revision/success 的硬门，`ReadModelRevisionCenter`
  对这些结果用 `didRecord` 或固定 `true` 发布 `wroteBusinessFact`。这违反 G4.1 /
  ECO-026 与入口矩阵中“deceased historical fact-only 只写事实，无 reward / ledger /
  reminder / revision / Oasis 派生”的规则。
- Next step: 先补入口族红测：对 planned feed/water、PetCare、Hygiene、CatCare、
  PetHealth、PetWeight、Medication 代表入口分别构造 pet 已离世但
  `date <= passedAwayDate` 的历史 fact-only 写入，断言只保留事实，不推进 home/domain
  revision、不展示 success feedback、不写 ledger/reward/reminder/stock/Oasis。实现上
  让相关 result 暴露 `allowsDerivedEffects` 或等价 typed disposition，并让 executor /
  publisher / UI 统一使用 `didRecord && allowsDerivedEffects` 作为派生成功门；
  R5/audit fixture 要覆盖“allowlisted 函数调用方未消费 disposition”的坏例。
- Close condition: 新红测先失败后修绿；上述入口族 historical fact-only 与 no-op
  语义在 service、command、executor、revision、UI feedback 层一致；
  `scripts/audit-economy-boundaries.sh --all`、`scripts/tests/run-audit-fixture-tests.sh`、
  相关 targeted simulator suite 与 `git diff --check` PASS；再开全新纯对抗复审，
  P0/P1=0 后 Economy 才可标 🏁。
- Closed: 2026-06-14 by product-owner two-state deletion decision. The
  `memorialHistoricalFactOnly` branch was retired: deceased members are
  read-only and do not write historical care facts, rewards, ledger, reminders,
  stock, Oasis, or revisions. The remaining acceptance moved to the
  care-derivation executor architecture work: all active fact writes must return
  a typed outcome, and all no-op outcomes must suppress command, executor,
  revision, and UI feedback side effects.
