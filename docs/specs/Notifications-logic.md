# Notifications 规则书（GAP-6 通知分级）

确认日期：2026-06-12

本规则书覆盖宪法 D15 的首发本地通知语义。首发版本只使用本地通知；不启用远程推送、CloudKit 通知、联机协作通知或多主人指派通知。

## 已确认产品决定

- 通知分三级：健康关键 > 日常 > 氛围。
- 健康关键通知不受每日限额影响；用药等用户指定时间的健康关键通知按原时间发送。
- 日常通知每日最多 4 条，氛围通知每日最多 1 条，非关键通知总量每日最多 5 条。
- 默认夜间免打扰窗口为 22:00-08:00；非关键通知落入窗口时延后到 08:30 后发送。
- 同一天、同成员、同类别的通知合并为一条；用药剂量不合并，避免漏服风险。
- 超过预算时跳过系统推送，但 App 内提醒保持 pending，并写调度账本。
- 周报通知保留为氛围通知；文案只指向照护周报，不再出现悬赏榜或多人协作语义。

## 通知预算表

| 层级 | 类型 | 首发预算 |
|---|---|---|
| 健康关键 | 用药、疫苗 / 驱虫 / 就医到期、断粮风险 | 不限额，不受夜间免打扰 |
| 日常 | 喂食、饮水、清洁、护理、植物、普通日历、保险缴费 | 每日最多 4 条；参与非关键总量 5 条 |
| 氛围 | 周报、连胜保护 | 每日最多 1 条；参与非关键总量 5 条 |

## 业务不变量

- NTF-001：任何本地通知在进入系统通知队列前必须归类为健康关键、日常或氛围。
- NTF-002：健康关键通知永远不因每日预算被跳过。
- NTF-003：日常与氛围通知必须受每日预算约束；超额只跳过系统推送，不删除 `Reminder`，不改变 App 内待办状态。
- NTF-004：同一天、同成员、同类别的非用药通知必须合并，避免同类连续轰炸。
- NTF-005：夜间免打扰只延后非关键通知；健康关键通知保持用户设定的时间。
- NTF-006：预算跳过、同类合并、夜间延后都必须在调度账本中可见，不能静默。
- NTF-007：周报通知属于氛围通知；首发文案不得指向悬赏榜、指派、多人协作或“谁最勤快”的竞争语义。
- NTF-008：通知策略不改变业务事实。调度策略只能影响系统推送是否发出 / 何时发出，不能完成、跳过、删除或奖励任何照护事实。

## 当前代码来源

- `NotificationManager` 负责本地通知权限、类别、系统队列注册、取消和通知动作路由：`Ohana/Features/Notifications/NotificationManager.swift:40`。
- `ReminderSchedulingService` 是普通 `Reminder` 的可测调度入口，当前已负责缺失事件、过期提醒、重复 notification id、同事件同分钟去重与账本记录：`Ohana/Features/Notifications/ReminderSchedulingService.swift:16`。
- `MedicationReminderService` 当前直接注册宠物 / 人类用药通知，未经过普通 `Reminder` 调度入口：`Ohana/Features/Medication/MedicationReminderService.swift:118`。
- `FamilyWeeklyReportService` 当前直接注册每周日 20:00 周报通知：`Ohana/Features/FamilyReports/FamilyWeeklyReportService.swift:19`。
- 启动维护在首帧后延迟注册周报通知，并在之后补注册 pending reminders：`Ohana/App/StartupMaintenanceCoordinator.swift:50`。

## 状态机

单条通知候选：

1. `candidate`：来自 `Reminder`、用药计划或周报服务的通知候选。
2. `classified`：已归类为健康关键、日常或氛围。
3. `policyEvaluated`：已完成预算、合并、夜间免打扰判定。
4. `scheduled`：进入系统通知队列。
5. `skippedByBudget`：因日常 / 氛围预算不足跳过系统推送，App 内提醒仍 pending。
6. `merged`：因同日同成员同类已有通知而合并，App 内提醒仍 pending。
7. `deferred`：非关键通知落入夜间免打扰，系统推送时间延后，App 内提醒原时间不变。
8. `cancelled`：对应提醒完成、跳过、删除、回收或成员退场时取消系统通知。

允许迁移：

- `candidate -> classified -> policyEvaluated`
- `policyEvaluated -> scheduled`
- `policyEvaluated -> skippedByBudget`
- `policyEvaluated -> merged`
- `policyEvaluated -> deferred -> scheduled`
- `scheduled -> cancelled`

## 边界

- 本轮不改 SwiftData schema。
- 本轮不启用 CloudKit、远程推送、后台推送或联机协作通知。
- 本轮不新增通知设置页大改；真实系统通知授权、到达和点击路由放入人工验收 track list。
- 本轮只处理首发本地通知克制策略；更细的用户自定义预算、按成员静音、按类别开关可作为后续增强。
