# Domain Write Kernel Phase 0 写入矩阵

> 工作协议：本文件是 Phase 0 产物，只做全 app 扫描和分类，不修改业务代码。Phase 内只跑本地验证；Phase 结束后才允许按 `docs/planning/domain-write-kernel-progress.md` 记录一次 CI。
> 状态图例：⬜ 未收口 ｜ 🔵 已有局部内核/待扩展 ｜ 🟡 高风险旁路 ｜ 🟢 当前可作为目标形态 ｜ ⛔ 阻塞待决策
> 当前状态：🏁 已完成。本文档作为 Domain write-kernel Phase 0 全 app 写入地图归档；Phase 0-7 的实施、CI、复审结果以 `docs/planning/domain-write-kernel-progress.md` 为准。

## 扫描范围

| 项目 | 结果 | 说明 |
|---|---:|---|
| App Swift 文件 | 809 | `rg --files Ohana -g '*.swift'` |
| Unit test Swift 文件 | 74 | `rg --files OhanaTests -g '*.swift'` |
| SwiftData `@Model` | 44 | `Ohana/Models` |
| persistence 写入相关行 | 498 | `context/modelContext insert/delete/save/safeSave` |
| `insert/delete` 调用行 | 497 | 包含数组等非 persistence 用法，作为粗扫上限 |
| `Event/Reminder` 直接构造行 | 9 | 已集中到 schedule writer + restore/sync decode/apply |
| raw subject/effect 字段行 | 1982 | `relatedEntity*`、`assigneeId`、`executorId(s)`、`subject*`、`actor*`、`affectedEntityIDs` |
| policy/helper 命中行 | 395 | member lifecycle、care fact、economy、schedule writer/token 等 |

## 热点分布

| 范围 | 写入相关行 | raw subject/effect 字段行 | 判断 |
|---|---:|---:|---|
| `Ohana/Domain` | 201 | 831 | 既有内核雏形在这里，但 restore/sync/effects 也在这里绕过 |
| `Ohana/Features` | 292 | 1060 | 大量 feature command 仍持有直接 SwiftData 写权 |
| `Ohana/App` | 3 | 0 | 非主要风险面 |
| `Ohana/Models` | 1 | 91 | 模型仍暴露 raw string/id 语义 |
| `Ohana/Shared` | 1 | 0 | 非主要风险面 |

Top direct insert files:

| 文件 | insert 行数 | Phase 0 判断 |
|---|---:|---|
| `Ohana/Domain/Services/DataBackupManager.swift` | 45 | 🟡 restore raw insert，Phase 5 |
| `Ohana/Domain/Services/CloudSyncRecordApplier.swift` | 20 | 🟡 cloud apply raw insert，Phase 5 |
| `Ohana/Domain/Services/SharedPetActionRecorder.swift` | 7 | 🟡 care fact/effects，Phase 4 |
| `Ohana/Features/Oasis/OasisUpgradeRewardService+Upgrades.swift` | 6 | 🟡 economy/effects，Phase 4 |
| `Ohana/Domain/Services/DomainScheduleWriteKernel.swift` | 5 | 🟢 schedule 目标形态，Phase 3 已成型 |

## 全 App 写入矩阵

| Area | Model / Record | Current write entry | Subject / effect fields | Policy today | Current writer | Target writer / phase | Risk / notes |
|---|---|---|---|---|---|---|---|
| Schedule | `Event`, `Reminder` | Calendar、Feeding、Medication、Insurance、HumanNote、MemberCreation、CarePlanCalendarSync 等 command/service | `relatedEntityType`、`relatedEntityId`、`assigneeId`、recurrence/reminder fields | `MemberLifecycleGate`、`MemberWritePolicy`、`MemberLifecycleActiveScheduleResolver`、`DomainEntityLinkRegistry` | `DomainScheduleWriter` + `AuthorizedDomainScheduleWrite` | 🟢 `DomainScheduleWriter` / Phase 3；rehydrate 进 Phase 5 | 用户 command 面已基本收口；剩余 direct constructor 只应存在于 writer 或 restore/sync decode/apply |
| Schedule rehydrate | `Event`, `Reminder` | `DataBackupManager+Decode.decodeEvent/decodeReminder`、`CloudSyncRecordApplier.applyEvent` | raw related/assignee fields from DTO/CKRecord | 局部 normalize，未强制 lifecycle/effects disposition | Direct decode/apply + `context.insert` | `RehydrateWriter` / Phase 5 | 🟡 这是 Phase 3 后最清晰 schedule bypass，不能按普通 user command gate 处理 |
| Care facts | `PetCareLog`, `WaterLog`, `PetPottyLog`, `PetWalkLog`, `PetWeightLog`, `PetHealthLog`, `PetHygieneLog`, `PetFoodRecord`, `PlantCareLog` | `CareEventService`、`SharedPetActionRecorder`、QuickCare/Home executors、Walks、Health/Hygiene/Feeding/Plants commands | pet relationship、`executorId`、`executorIds`、shared session ids、source event/reminder ids | `CareFactWritePolicy`、`MemberLifecycleGate`、`EconomyWalletWritePolicy`、局部 executor checks | Feature/domain services directly insert facts | `DomainFactWriter` + `AuthorizedMutationPlan` / Phase 4 | 🟡 同一事实常伴随 ledger/reward/reminder/revision，必须一张 plan 驱动全部 effects |
| Care derivation | generated care from schedule/reminder/task | `CalendarTaskCompletionSyncService`、`QuickActionReminderCompletionSyncService`、`ReminderActionCoordinator`、TodayFocus/Home commands | source event/reminder id、related entity、executor id、completion kind | `CareDerivationExecutor`、`CareWriteOutcome` | Partial token pattern | Extend token from derivation to persistence/effects / Phase 4 | 🔵 现有 token 是好雏形，但还不是全 app write capability |
| Ledger | `CareLedgerEvent` | `CareLedgerService.record*`、care/economy/expense completion paths | `actorKind/id`、`subjectKind/id`、source ids、legacy model ids、privacy field | Caller-supplied subject; some lifecycle/economy checks upstream | `CareLedgerService` direct insert | `DomainLedgerWriter` + typed subject resolution / Phase 4 | 🟡 `CareLedgerService.subjectInfo(from:)` 仍按 raw `relatedEntityType` 推 subject |
| Wallet / economy | `CoconutAccount`, `CoconutLedgerEntry`, `EconomyBudgetUsageEvent`, reward logs/projections | `CoconutWalletService`、`QuestManager`、`CoconutEconomyPolicyV2`、Gacha/Shop/Oasis services | owner human id、pet bond id、source ids、budget subject | `EconomyWalletWritePolicy`、cofund/frozen checks | Economy services directly insert/update | `DomainEconomyWriter` + `DomainEffectsDispatcher` / Phase 4 | 🟡 wallet write is already policy-rich but not yet fed by one authorized app-level plan |
| Family tasks | `FamilyCollaborationTask` | `FamilyTaskService`、Home/TodayFocus/Calendar task completion | assignee/creator/member ids, completion actor, generated care links | Feature-local checks + member/economy policy at call sites | Feature service direct insert/update/delete | `DomainTaskWriter` + typed assignee/owner resolution / Phase 4 | 🟡 Task owner vs assignee must not be re-derived by reminders, home, calendar, ledger separately |
| Member profiles | `Pet`, `Human`, `Plant`, `PetRelationship`, profile fields | `MemberCreationService`、member edit/delete commands、privacy/profile commands | member id, lifecycle flags, privacy fields, relationship links | `MemberLifecycleGate` / deletion commands | Feature/domain commands direct mutate/insert | `MemberScopedWriter` + `DomainPolicyAuthorizer` / Phase 2 + 7 | 🟡 Profiles are capability roots; commands should submit intents, not hold broad write power |
| Member deletion | member roots + dependent records + tombstones | `PhysicalDeletionService`, `AppResetService`, CloudSync tombstone helpers | member id, actor/subject/source ids, raw related links | Service-level cascade rules | Deletion service direct deletes/inserts tombstones | `AuthorizedDeletionPlan` + `DeletionWriter` / Phase 5 + 7 | 🟡 Delete/effects/revision must consume the same resolved target set |
| Documents | `PetDocument`, `PetDocumentAttachment` | `PetDocumentCommands`, backup restore, cloud apply | pet id/document id, attachment ownership | Feature-local pet checks | Feature command direct insert/update/delete | `DomainDocumentWriter` or generic member content writer / Phase 4 + 5 | 🔵 Classify as member-owned content; attachments inherit parent document authorization |
| Milestones | `PetMilestone` | `PetMilestoneCommands`, backup/cloud paths | pet id/milestone id | Feature-local pet checks | Feature command direct insert/update/delete | Generic member content writer / Phase 4 + 5 | 🔵 Classify as member-owned content with no default derived effects |
| Insurance | `PetInsurance`, `InsuranceClaim`, derived expenses/schedules | `InsuranceCommands`, backup/cloud paths | pet id, insurance id, claim id, schedule related link, expense subject | Member lifecycle + expense/economy policy in separate paths | Feature command direct inserts across models | Fact/content writer + schedule writer + ledger/economy plan / Phase 4 + 5 | 🟡 Composite write: policy content, claim, schedule, and expense ledger must be one authorized transaction plan |
| Wishlist | `WishlistItem` | `HumanWishlistCommands`, backup/cloud paths | human id/wishlist id | Feature-local human checks | Feature command direct insert/update/delete | Generic member content writer / Phase 4 + 5 | 🔵 Classify as human-owned content; no schedule/economy effect unless future feature adds one |
| Health / medication | `PetMedication`, `HumanMedication`, `HumanMedicationLog`, `HumanHealthReport`, `HumanHealthMetricLog`, `SymptomLog`, `HeatCycleLog` | Medication/Health/HumanHealth commands, reminder service, backup/cloud paths | pet/human ids, medication ids, schedule links, actor/executor ids | Lifecycle gate + feature checks, schedule writer where migrated | Direct feature writes + schedule writer | Fact/content writer + schedule writer / Phase 4 + 5 | 🟡 Direct medication facts and schedule reminders need the same typed owner/assignee result |
| Expenses | `PetExpenseLog`, insurance payments/claims, ledger/economy effects | `ExpenseCommands`, `InsuranceCommands`, backup/cloud paths | pet id, payer/actor ids, subject ids, source ids | Economy policy + some lifecycle checks | Feature command direct insert + ledger service | Expense writer + ledger/economy dispatcher / Phase 4 | 🟡 Expense fact without same-boundary ledger/economy was a prior recurring class |
| Walks / workouts | `PetWalkLog`, `HumanWorkoutLog`, generated potty/care/ledger | `PetWalkingManager`, `WorkoutCommands`, backup/cloud paths | pet/human ids, executor ids, route/session ids | Care fact/economy policy at call sites | Feature command direct insert | Fact writer + effects dispatcher / Phase 4 + 5 | 🟡 Multi-executor semantics must be typed once, then reused by fact, ledger, reward |
| Photos / moments | `PetPhotoLog`, moment/photo records | `PetPhotoAlbumCommands`, `MomentCommands`, backup/cloud paths | pet/member/media ids | Feature-local checks | Feature direct insert | Generic member content writer / Phase 4 + 5 | 🔵 Member-owned content; privacy/media cleanup should be effect of authorized write/delete |
| Oasis / Gacha / Shop | Oasis progression/inventory/purchase/draw records | Oasis upgrade/reward services, Gacha models/services, Shop purchase store | owner wallet ids, purchase/draw/source ids, island/cofund members | Economy/cofund/frozen policies | Feature services direct insert/update | Economy writer + effects dispatcher / Phase 4 + 7 | 🟡 Not always member lifecycle, but benefits from the same capability/write-plan frame |
| Cloud metadata | `CloudSyncRecordState`, tombstones, dirty marks | `CloudSyncMetadataService`, mutation recorder, record serializer/applier | entity name, local record id, household id, modified/deleted timestamps | Registry descriptor checks | Cloud services direct insert/update/delete | Infrastructure writer called by authorized plans / Phase 5 + 7 | 🟡 Metadata can legit bypass member policy only as an effect of an authorized domain mutation |
| Backup restore | nearly all persisted models | `DataBackupManager.restoreBackup` and decode helpers | raw DTO ids and relationship fields | Duplicate checks and legacy compatibility | Direct decode + `context.insert` | `RehydrateWriter(mode:)` / Phase 5 | 🟡 Must support normalize/quarantine/legacyHistoryOnly/dropEffects modes, not user-command gate semantics |
| Cloud apply | synced persisted models | `CloudSyncRecordApplier` | CKRecord raw fields, entity names, related/actor/subject ids | Registry and last-modified semantics | Direct construct/update/insert | `RehydrateWriter(mode: .cloudApply)` / Phase 5 | 🟡 Remote apply must not re-enable direct raw constructors after command writers are sealed |
| Read-model revisions | revision publish events and affected ids | `ReadModelRevisionCenter+FeaturePublishing`, domain publishing helpers | affected entity ids, feature command result ids | Some token gating around domain publishing | Effect publisher interprets ids | `DomainEffectsDispatcher` / Phase 4 + 6 | 🟡 Effects must consume authorized resolution; no second owner interpreter |
| Notifications / deep links | reminder scheduling, completion, routing | `ReminderSchedulingService`, `NotificationManager`, `FocusHomeReminderDeepLinkRouter`, reminder action coordinator | event/reminder ids, related links, assignee id | Mixed resolver/helper calls | Service/view models interpret raw ids | Typed `DomainSubjectResolution` + effects dispatcher / Phase 1 + 6 | 🟡 No persistence sometimes, but user-visible effects can still leak lifecycle state |
| Filters / overdue / dashboards | Home, Calendar, TodayFocus, read-model stores | view/read-model filters and query builders | raw related/assignee/subject/executor ids | Mixed helper use | Consumers often self-match | Typed resolution read API / Phase 1 + 6 | 🟡 Audit must forbid second owner matcher, not just require a helper somewhere nearby |

## Current Classification For Formerly Ambiguous Areas

| Area | Default classification | Reason |
|---|---|---|
| Documents | member-owned content | Parent `PetDocument` owns authorization; attachment inherits it and should not authorize independently |
| Milestones | member-owned content | Pet-scoped historical content with no default economy/schedule effect |
| Insurance | composite member content + schedule + expense/ledger | One command can create policy content, reminders, expenses, claims, and ledger effects |
| Wishlist | human-owned content | Human-scoped content with no default derived effect today |

## Phase 0 Judgement

The previous member-lifecycle conclusion still holds, but scoped to the whole app:

- Schedule writes already show the target shape: intent -> typed link/resolution -> authorized token -> writer.
- The rest of the app still has broad direct write capability in feature/domain services.
- Raw subject/effect interpretation is larger than persistence writes, so a write-only audit is insufficient.
- Restore/sync/import are first-class writers and must be treated as rehydrate modes, not exceptions.
- Effects are part of the write boundary: ledger, reward, notification, revision, sync dirty mark, and deep link routing must consume the same typed resolution/plan.

Phase 0 exit criterion is satisfied. The matrix has served its planning purpose and is now a completed reference map. Implementation and closeout proceeded through Phase 1-7 and are tracked in `docs/planning/domain-write-kernel-progress.md`.
