# Notifications 规则书（GAP-6 通知分级）

确认日期：2026-07-22

本规则书覆盖宪法 D15 的本机通知语义，以及受独立开关控制的 Ohana Family 亲友守护
APNs。CloudKit 通知、跨设备任务协作和多主人指派通知仍不启用。Family APNs 不改变
本机日常通知预算，详细事件规则见
[`GuardianSafety-logic.md`](GuardianSafety-logic.md)。

## 已确认产品决定

- 通知分三级：健康关键 > 日常 > 氛围。
- 健康关键通知不受每日限额影响；用药等用户指定时间的健康关键通知按原时间发送。
- 日常通知每日最多 4 条，氛围通知每日最多 1 条，非关键通知总量每日最多 5 条。
- 默认夜间免打扰窗口为 22:00-08:00；非关键通知落入窗口时延后到 08:30 后发送。
- 同一天、同成员、同类别的通知合并为一条；用药剂量不合并，避免漏服风险。
- 超过预算时跳过系统推送，但 App 内提醒保持 pending，并写调度账本。
- 周报通知保留为氛围通知；文案只指向照护周报，不再出现悬赏榜或多人协作语义。
- 佛系截止提醒属于日常通知。权限只在用户主动启用时请求；首次引导不预请求。
- 佛系通知的“我没事”是显式用户动作，可调用本人打卡命令；通知调度、后台刷新和
  静默唤醒本身绝不能写打卡事实。
- Free 可配置一个每日截止时间；Personal 可按星期配置，并设置 15–180 分钟宽限期
  与第二次本机提醒。切回普通模式取消佛系提醒。
- Family 守护顺序固定为本机提醒 → 截止与宽限 → 服务端通知已安装、登录、接受邀请且
  通知可用的 Ohana 守护人。Free / Personal 不提供跨设备通知；任何套餐都不得自动短信、
  电话、邮件或外部消息。
- Family 第 1 个连续漏签守护日只记录，第 2 日最多一次首次推送，第 3 日最多一次跟进，
  此后同一事件不再重复。本人恢复最多一次恢复推送，守护人确认只关闭事件。
- APNs / SNS 是尽力而为。UI 区分“已提交、已打开、已确认、不可达”，不能把 provider
  接受请求描述为对方已收到。

## 通知预算表

| 层级 | 类型 | 首发预算 |
|---|---|---|
| 健康关键 | 用药、疫苗 / 驱虫 / 就医到期、断粮风险 | 不限额，不受夜间免打扰 |
| 日常 | 喂食、饮水、清洁、护理、植物、普通日历、保险缴费 | 每日最多 4 条；参与非关键总量 5 条 |
| 氛围 | 周报、连胜保护 | 每日最多 1 条；参与非关键总量 5 条 |
| Family 远端守护 | 第 2 / 3 连续漏签守护日、本人恢复、守护停止 | 独立事件上限，不进入本机 5 条预算；同一事件最多首次 + 跟进 + 恢复 |

## 业务不变量

- NTF-001：任何本地通知在进入系统通知队列前必须归类为健康关键、日常或氛围。
- NTF-002：健康关键通知永远不因每日预算被跳过。
- NTF-003：日常与氛围通知必须受每日预算约束；超额只跳过系统推送，不删除 `Reminder`，不改变 App 内待办状态。
- NTF-004：同一天、同成员、同类别的非用药通知必须合并，避免同类连续轰炸。
- NTF-005：夜间免打扰只延后非关键通知；健康关键通知保持用户设定的时间。
- NTF-006：预算跳过、同类合并、夜间延后都必须在调度账本中可见，不能静默。
- NTF-007：周报通知属于氛围通知；首发文案不得指向悬赏榜、指派、多人协作或“谁最勤快”的竞争语义。
- NTF-008：通知策略不改变业务事实。调度策略只能影响系统推送是否发出 / 何时发出，不能完成、跳过、删除或奖励任何照护事实。
- NTF-009：只有 `PRESENCE_OKAY` 等明确通知动作可发出本人打卡意图；重复动作按
  主体/自然日幂等。
- NTF-010：亲友守护只使用 Ohana App 内关系与普通 APNs；产品路径不得采集电话号码、
  邮箱或打开短信编辑器。锁屏只表达“连续 N 个守护日尚未收到打卡，请主动联系确认”，
  不得宣称急救、死亡检测、实际未打卡或保证送达。
- NTF-011：远端推送前必须重新验证签到、事件、确认、暂停、关系、设备可达与 Family
  权益；事件键和条件写保证第 2 / 3 日不会因并发重复提交。
- NTF-012：远端静默唤醒只能刷新守护投影，不能写签到、奖励或照护事实。

## 当前代码来源

- `NotificationManager` 负责本地通知权限、类别、系统队列注册、取消和通知动作路由：`Ohana/Features/Notifications/NotificationManager.swift:40`。
- `ReminderSchedulingService` 是普通 `Reminder` 的可测调度入口，当前已负责缺失事件、过期提醒、重复 notification id、同事件同分钟去重与账本记录：`Ohana/Features/Notifications/ReminderSchedulingService.swift:16`。
- `MedicationReminderService` 当前直接注册宠物 / 人类用药通知，未经过普通 `Reminder` 调度入口：`Ohana/Features/Medication/MedicationReminderService.swift:118`。
- `FamilyWeeklyReportService` 当前直接注册每周日 20:00 周报通知：`Ohana/Features/FamilyReports/FamilyWeeklyReportService.swift:19`。
- 启动维护在首帧后延迟注册周报通知，并在之后补注册 pending reminders：`Ohana/App/StartupMaintenanceCoordinator.swift:50`。
- `GuardianSafetyCoordinator` 负责可选账号、设备端点、最小远端投影和 Presence outbox；
  `backend/guardian/` 负责守护日评估、事件幂等与 SNS / APNs 提交。

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

- V93 的 `SafetyContact` 只作旧版本本机兼容；新界面不创建、不编辑、不使用，只提供
  一次性本地清理。旧电话号码绝不上传或静默删除。
- 本机提醒时间、星期、宽限和第二次提醒仍是设备本地设置，不进入备份或同步。
- Family 使用 V96 本机投影和 outbox；账号 / APNs token / 投影 / outbox 不进入备份、
  用户导出或现有 CloudSync。
- 只有用户主动启用本机提醒或 Family 守护时才请求通知权限。真实授权、到达、打开、
  action、卸载 token 失效和双账号流程必须真机验收。
- `OHANAGuardianSafetyEnabled` 默认 false；AWS、Associated Domains、隐私、StoreKit 与
  双真机门禁未完成时，不注册可用服务、不开放 Family 商品或宣传。
- 本轮只处理首发本地通知克制策略；更细的用户自定义预算、按成员静音、按类别开关可作为后续增强。
