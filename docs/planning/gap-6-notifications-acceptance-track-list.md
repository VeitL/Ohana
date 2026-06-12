# GAP-6 通知分级验收 Track List

日期：2026-06-12

范围：宪法 D15 通知分级。首发只使用本地通知，不启用远程推送、CloudKit 通知、联机协作通知或多主人指派通知。

## Codex 已自动验收

- [x] 规则书已写入 `docs/specs/Notifications-logic.md`，覆盖三级分类、每日预算、同类合并、夜间免打扰、周报语义和不启用联机通知的边界。
- [x] 红测已证明旧行为会超发：5 条同日 routine 提醒会全部注册系统通知，且账本没有 `scheduleSkippedBudget`。
- [x] 绿测已证明 routine 每日预算：同日 5 条 routine 提醒只注册 4 条系统通知，第 5 条保持 App 内 pending，并写 `scheduleSkippedBudget`。
- [x] 绿测已证明夜间免打扰：22:00-08:00 的非关键提醒系统推送延后到次日 08:30，App 内提醒仍保持原始待办时间，并写 `scheduleDeferred`。
- [x] 绿测已证明健康关键不受限额/合并/免打扰影响：7 条夜间用药提醒全部按原时间注册系统通知，账本均为 `scheduleSuccess`。
- [x] 绿测已证明同类合并：同日、同成员、同类别的非用药提醒只注册第一条系统通知，后续提醒保持 App 内 pending，并写 `scheduleMerged`。
- [x] 绿测已证明氛围预算：同日 2 条 ambient 提醒只注册 1 条系统通知，超额项写 `scheduleSkippedBudget`。
- [x] 绿测已证明周报通知归类为 ambient/weeklyReport，中文文案只指向照护周报，不含“悬赏”或“勤快”竞争语义。
- [x] `rg` 已核查判定点收束：`notificationTier` / `notificationCategory` / 预算常量只在 `NotificationDeliveryPolicy` 定义和产出；业务入口只调用 `NotificationDeliveryPolicy.plan(...)` 或 `NotificationDeliveryPolicy.userInfo(...)`。
- [x] `scripts/test-simulator.sh -only-testing:OhanaTests/OhanaNotificationsSchedulingTests`：8 tests / 1 suite passed。
- [x] `scripts/test-simulator.sh -only-testing:OhanaTests/PetActivityRecordCleanupServiceTests -only-testing:OhanaTests/RecycleBinServiceTests`：5 tests / 2 suites passed。
- [x] `scripts/dev-check-changed.sh`：SwiftFormat、UI V4、Accessibility、Smoothness、Runtime guardrails、Shared-care note metadata 均 passed。
- [x] `scripts/module-exit-gate.sh`：PASS；全量单测 713 tests passed；UI 测试 3 tests passed。Xcode 输出的实体设备 `notification_proxy` / debugger snapshot 信息为环境噪声，命令目标仍为 iPhone 17 simulator。

## 人工验收

- [ ] 真机允许通知权限后，创建 5 条同一天 routine 提醒，确认系统通知最多到达 4 条；第 5 条仍在 App 内待办中可见，不被自动完成、跳过或删除。
- [ ] 真机创建 22:00-08:00 之间的非关键提醒，确认系统通知延后到 08:30 后；App 内提醒列表仍显示原始计划时间。
- [ ] 真机创建夜间用药 / 疫苗 / 就医类健康关键提醒，确认系统通知按用户设定时间到达，不被预算和免打扰延后。
- [ ] 真机创建同一天、同成员、同类别的非用药提醒，确认系统通知只到达第一条；App 内后续提醒仍 pending。
- [ ] 真机点击普通提醒通知以及“完成 / 跳过 / 明天再说”等通知动作，确认仍能进入正确提醒处理路径。
- [ ] 真机等待或临时触发周报通知，确认标题/正文只表达照护周报，不出现悬赏榜、指派、多人竞争或“谁更勤快”的语义。
- [ ] 在开发/观测面板查看提醒调度账本，确认能看到“夜间延后”“预算跳过”“同类合并”等中文动作名。

## 备注

- 本轮没有改 SwiftData schema。
- 本轮没有启用 CloudKit、远程推送、后台推送或联机协作通知。
- 系统通知真实到达、横幅展示和点击动作属于 iOS 真机/系统权限行为，已保留为人工验收项。
