# Task Follow-ups

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

## Open Items

### TFU-20260614-008 - Repair pre-existing CI architecture-boundary gate

- Status: Open
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
- Next step: Run `scripts/audit-architecture-boundaries.sh --all`, split or
  shrink oversized files without raising the ratchet baseline, and either route
  the static service calls through injected protocols/adapters or justify a
  narrow architecture-boundary allowlist with tests. Keep the cleanup in a
  separate commit from Economy behavior fixes.
- Close condition: `scripts/audit-architecture-boundaries.sh --all` passes
  locally; a pushed CI run passes `audits`, `lint`, and `build-test`; update
  this TFU with the closing commit/run URL.

### TFU-20260614-006 - Close Economy pure-review P1 leftovers before maturity

- Status: Open
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
- Close condition: 新红测先失败后修绿；`scripts/audit-economy-boundaries.sh --all`、
  `scripts/tests/run-audit-fixture-tests.sh`、相关 targeted simulator suite、
  `git diff --check` 与 module exit gate 通过；再开全新纯对抗复审，P0/P1=0 后
  Economy 才可标 🏁。

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

- Status: Open
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

### TFU-20260613-013 - Propagate Economy fact no-op to care command layers

- Status: Open
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

### TFU-20260613-012 - Repair post-7845db4c7 Economy hard-gate review findings

- Status: Open
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

- Status: Open
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

- Status: Open
- Priority: P1
- Area: Governance / Economy Boundaries / Derived State Lifecycle
- Source task: Recurring findings audit mechanization, 2026-06-13
- Blocker: `docs/governance/manifests/recurring-findings-audit-baseline.json`
  intentionally registers existing full-repo recurring-findings debt so the new
  audits can enter CI without blocking unrelated work. Current baseline:
  `economy-boundaries` has 0 warnings;
  `derived-state-lifecycle` has 63 warnings across 56 files
  (`derived-state-lifecycle-checklist`: 50,
  `physical-delete-without-tombstone`: 13). The ratchet blocks new or increased
  debt but does not by itself fix the existing files.
- Progress: 2026-06-13 TFU repair round burned down the Economy executor
  baseline from 5 to 0, removed the owned Calendar / CatCare physical-delete
  baseline warnings, and added service-layer tombstones for the PetCare /
  Hygiene / DashboardRecords `CareLedgerEvent` delete paths. The remaining 63
  derived-state warnings are still unowned baseline debt and require future
  module repair or explicitly approved allow comments before this TFU can close.
  Second 2026-06-13 repair round closed the owned Economy / GAP-2 P1 findings
  from the second adversarial review: Calendar / Today Focus / notification care
  completion now enters the care fact + reward pipeline, Calendar occurrence
  undo writes reversal / tombstone facts, CarePlan / Feeding / Water plan deletes
  write upload-pipeline tombstones, and SymptomLog / HeatCycleLog now direct
  delete with tombstones while PetHealthLog remains recoverable.
- Next step: During Economy, RecycleBin, and Phase 7 module repair/review rounds,
  resolve the owned baseline warnings as real behavior fixes or approved local
  exceptions, then refresh the baseline downward with the matching audit command
  only after review.
- Close when: Both `scripts/audit-economy-boundaries.sh --all` and
  `scripts/audit-derived-state-lifecycle.sh --all` pass with a zero baseline, or
  every remaining warning has an explicit approved allow comment and the
  manifest records no unowned recurring-findings debt.

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

- Status: Open
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

- Status: Open
- Priority: P1
- Area: Members / Memorial / Command Boundaries
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: GAP-9 removed active-flow participation for deceased humans, but
  the Members command layer still allows profile edit, privacy toggles, and
  deletion routes while the UI says "纪念模式 · 只读". A hard boundary needs a
  focused route/command pass to avoid changing memorial behavior by accident.
- Next step: Define the allowed actions for deceased humans, then enforce the
  read-only boundary in Members routes and command services with focused tests.
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

- Status: Open
- Priority: P1
- Area: Memorial / Notifications / Release Validation
- Source task: GAP-9 memorial exit, 2026-06-12
- Blocker: Repository tests prove data retention, active-flow filtering, undo
  restoration, and reward freeze invariants, but they cannot fully prove real
  iOS notification cancellation / rescheduling behavior or the final visible
  memorial experience across a real device data set.
- Next step: Run the GAP-9 manual checklist in
  `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`, especially
  marking/undoing a pet, checking notification cancellation and restoration,
  confirming memorial entry visibility, and scanning home/FAB/full-menu
  active targets.
- Close when: The GAP-9 track list's manual section is checked off on a real
  device and any device-specific notification or UI defect is fixed or split
  into its own scoped follow-up.

### TFU-20260612-016 - Validate GAP-6 notification delivery on real devices

- Status: Open
- Priority: P1
- Area: Notifications / Release Validation
- Source task: GAP-6 notification classification, 2026-06-12
- Blocker: Repository tests and simulator UI tests can prove scheduling policy,
  ledger visibility, and routing compile paths, but they cannot prove real iOS
  notification delivery, banners, permission prompts, Focus/DND interaction, or
  notification action behavior on physical devices.
- Next step: Run the GAP-6 manual checklist in
  `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级` on a real device
  with notification permission enabled, including routine budget, quiet-hours
  deferral, health-critical delivery, merge behavior, notification actions, and
  weekly report copy.
- Close when: The GAP-6 track list's manual section is checked off on a real
  device and any device-specific delivery or routing defect is either fixed or
  recorded as its own scoped follow-up.

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

- Status: Open
- Priority: P0
- Area: Care / QuickCare / Hygiene / Read Models
- Source task: Care maturity remediation, 2026-06-12
- Blocker: This crosses QuickCare, Home snapshots, expanded quick-action state,
  expense previews, and legacy log compatibility. `PetHygieneDetailView` display
  state, `IslandHygieneDashboard` summaries, `QuickPlayDetailSheet` display
  history, `QuickPottyDetailSheet` owned potty/litter history, and
  `QuickWaterDetailSheet` water/change/filter history now read from
  `CareLedgerEvent` snapshots. `IslandFoodDashboard` feeding summaries and
  trends also read from `CareLedgerEvent`; its old `PetCareLog` input remains a
  stock-calculator compatibility source because food-kind/stock consumption
  semantics have not yet moved fully into ledger metadata. QuickFeed full
  history, plan-calendar auto occurrence state, overview, mode-history, and
  treat overview snapshots now aggregate `CareLedgerEvent` entries, with
  `PetCareLog` retained only as a legacy bridge for food-kind/treat-kind
  enrichment and edit/delete affordances. Home expanded human expense preview
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
  anti-repeat checks in Home and QuickFeed detail now use feeding
  `CareLedgerEvent` snapshots instead of `pet.careLogs`, preserving actor-name
  warnings without depending on the legacy relationship array.
  `IslandPottyDashboard` now aggregates potty rhythm, type counts, 10-day pulse,
  and per-pet summaries from potty `CareLedgerEvent` entries instead of
  `pet.pottyLogs`. Home `VerticalSolidHomeSourceState`, `HomeReadModelStore`,
  `TodayFocusSnapshot`, and `TodayFocusEconomyService` now use lightweight
  `TodayFocusCareLedgerEntry` values for Today Focus care completion and daily
  reward gating instead of fetching today `PetCareLog`, `PetWalkLog`, or
  `PetPottyLog` rows. `TodayFocusService` has direct ledger-entry completion
  coverage for planned feed, walk, potty, and play-equivalent quests.
  `IslandQuestEngine` now consumes the same lightweight ledger entries when
  generating care-plan and family-level play quests, including event-scoped
  feed/water completion checks and actor-aware routine subtitles when ledger
  actor data is available.
  Legacy logs remain only as delete/claim/stock/typed-metric compatibility
  bridges where old commands or calculators still require the original model.
  Remaining fallback branches in Today Focus still read legacy relationship
  arrays only when no ledger-entry snapshot has been supplied.
- Next step: Move remaining moment expanded quick-action consumers, feeding
  stock calculators, and command/delete/claim compatibility paths off direct
  `PetCareLog`, `PetPottyLog`, `PetWalkLog`, and `PetExpenseLog` queries where
  `CareLedgerEvent` has enough structured metadata, then cover each migrated
  surface with targeted tests. Reason not completed in the same round: feeding
  stock calculators still need legacy food-kind/stock metadata until that data
  is represented structurally in ledger metadata; Today Focus still retains
  legacy relationship-array fallbacks for compatibility when a caller has not
  supplied ledger snapshots; hygiene delete/detail compatibility still needs
  the original `PetHygieneLog` record for explicit user deletion; moment/photo
  status is a separate media-history read path rather than a CareLedgerEvent
  surface, so it needs its own scoped migration and tests.
- Current task disposition: Accepted follow-up for future migration scope. The
  current care-maturity remediation is complete because remaining direct legacy
  reads are either explicit compatibility bridges or cross-surface migrations
  documented here with exact next steps and close conditions.
- Close when: QuickCare and Hygiene user-facing read models no longer directly
  query the four legacy pet log models except for explicit backup/migration
  compatibility paths.

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

- Status: Open
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
  actor/type/date.
- Next step: Add focused tests for the remaining `CareEventService` error and
  service failure paths not covered by the planned-feed/planned-water chains,
  the hygiene and potty service tests, the reopen tests, no-event tests, or the
  existing catch-up/rejected planned-care tests.
  `PetHygieneCommandService` record/delete/plan/executor coverage exists in
  `HomeCommandExecutorTests`, and the grooming overdue warning path is now
  covered in `OhanaTests`. `CatCareCommandService` now has dedicated command
  coverage for non-hygiene records and wrong-pet undo isolation.
  `QuickPottyCommandExecutor` and `QuickPottyUnknownClaimStore` now cover the
  unknown shared potty claim flow in `HomeCommandExecutorTests`.
- Current task disposition: Accepted follow-up for future negative-path
  expansion. The current remediation has direct coverage for the high-risk
  success chains, no-write guard paths, catch-up rejection, reopen syncing,
  hygiene, potty, command services, and unknown-potty claim flow; the remaining
  tests are incremental edge/failure coverage rather than a blocker for this
  closeout.
- Close when: The listed services have direct behavior tests covering success,
  edge, and migration/recovery paths instead of relying only on indirect shared
  care tests.

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

- Status: Open
- Priority: P1
- Area: Domain / Architecture / Localization / Notifications
- Source task: Domain Phase 2 analysis, 2026-06-12
- Blocker: The remaining Domain issues are broad architectural cleanup rather
  than the P0 activity-cleanup/blocking-build repair. Fixing them cleanly should
  happen as a dedicated pass so adapters can move without disturbing service
  behavior.
- Next step: Move app/feature infrastructure adapters out of
  `Ohana/Domain/Services/AppInfrastructureAdapters.swift` or invert them behind
  Domain-owned protocols; replace Domain `SwiftUI.Color` outputs in
  `CareLedgerStatsService` and `HealthMetricCatalog` with semantic tokens; move
  user-visible generated titles/status text onto the localization path; and
  make reminder notification scheduling dependency-injected instead of relying
  on the mutable `OhanaNotifications.current` global from static service paths.
- Current task disposition: Accepted P1 follow-up for Domain Phase 2. The P0
  production path violations were removed or moved behind a Domain service; the
  remaining items do not block the current module exit gate but should be
  resolved before release-hardening freeze.
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
