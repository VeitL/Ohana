# Oasis 规则书

确认日期：2026-06-12

本规则书覆盖 Oasis 生命树、升级椰子、电子宠物、打卡与椰子收支的首发语义。最高裁判标准仍是 `docs/specs/product-foundation.md`。

## 已确认产品决定

- Oasis 是椰子的核心消费出口与情感反馈层，不是独立经济系统。
- 首发正式版中，Oasis 椰子读写必须绑定当前主人钱包；没有当前主人时，不得回退到 `system` / `system:legacy` 账户。
- Oasis 的重复性产出必须计入操作日预算 / 冷却；一次性升级椰子、唯一里程碑等奖励可作为幂等的非预算 grant，但必须可由钱包账本重放。
- 电子宠物首发不做永久死亡；长期无人照顾或高龄只进入低压的休眠 / 纪念状态，可被唤回，不因用户没打开 App 造成不可逆损失。
- DailyStreak 是唯一打卡事实源；Oasis 只复用同一份打卡数据和命令，不建立第二套 streak。
- 生命树是历史记忆。历史照护产生的树 XP 不因成员离世而回退；删除成员是不可恢复物理删除，未来活跃生成由对应模块的离世 / 删除规则控制。隐私删除一切数据除外。
- 树注入是正式消费出口，首发允许无限次使用，只受当前主人钱包余额限制。

## 业务不变量

- OAS-001：Oasis 任意椰子收支必须通过钱包 / 账本写入，禁止视图直接修改 `coconutBalance`。
- OAS-002：没有当前主人或当前主人无效时，Oasis 的余额显示、消费、重复奖励、一次性奖励均不得读写 `system` / `system:legacy`。
- OAS-003：树注入、电子宠物互动、升星、碎片唤醒等消费必须从当前主人钱包扣除；余额不足时失败且不得产生负余额。
- OAS-004：每日打卡、树上每日椰子、生命树每日馈赠、电子宠物每日愿望等重复性产出必须进入操作日预算 / 冷却；触顶后可记录事实或状态，但不额外产出椰子。
- OAS-005：升级椰子与唯一里程碑奖励必须幂等。重复打开、重复领取或保存失败重试，不得重复发放。
- OAS-006：生命树等级只由历史 `growthXP`、`injectedXP` 与兼容 baseline 推导；同一照护事实不得重复增加树 XP。
- OAS-007：首页 Oasis tab 的首帧只能展示冻结树或轻量壳；真实 SwiftData fetch、生命周期归一化、奖励检查、打卡写入必须在可取消的 frame handoff 后执行。
- OAS-008：隐藏或离开 Oasis 后必须取消 route-scoped 任务并释放 live snapshot；环境动画必须受 `AppWorkloadPolicy` / Reduce Motion / 可见性控制。
- OAS-009：电子宠物生命周期不得因未打开 App 进入不可逆死亡；低状态可进入需要救援 / 休眠 / 纪念展示，但用户可通过救援或互动唤回。
- OAS-010：真实照护行为只能给当前展示的非归档、非休眠最终态电子宠物一次轻量 `careEcho` 反馈；不得复活不可交互对象，也不得重复写多条回声。
- OAS-011：DailyStreak 与 Oasis 打卡读写同一份 `CheckInStreakStore` 数据；从 Oasis 或 DailyStreak 进入当天，只能产生一次当天打卡奖励。
- OAS-012：生命树历史 XP 不因成员离世而回退；只有成员不可恢复删除、隐私真删或全量重置会清除对应数据。

## 状态机

生命树：

1. `preview`：冻结或准备态，只读取快照，不做奖励 / 打卡写入。
2. `visiblePrepared`：首帧后刷新 bounded live snapshot。
3. `live`：刷新树能量、生成待开升级椰子、允许注入 / 收获 / 打卡。
4. `hidden`：取消任务、停止动画、释放 live snapshot。

允许迁移：

- `preview -> visiblePrepared -> live`
- `live -> hidden`
- `visiblePrepared -> hidden`

升级椰子：

1. `missing`：等级已达到但升级椰子尚未生成。
2. `pending`：升级椰子已生成，未打开。
3. `opened`：奖励已应用，`openedAt` 已写入。
4. `failed`：写入失败，事务回滚，仍可重试。

允许迁移：

- `missing -> pending`
- `pending -> opened`
- `pending -> failed -> pending`

电子宠物：

1. `healthy`
2. `needsCare`
3. `atRisk`
4. `sick`
5. `critical`
6. `restingRemembered`：首发复用现有 `dead` 存储值作为“休眠 / 纪念中”的展示态，不代表永久死亡。

允许迁移：

- `healthy <-> needsCare`
- `needsCare -> atRisk -> sick -> critical -> restingRemembered`
- `atRisk/sick/critical/restingRemembered -> healthy`（救援或唤回）

打卡：

1. `notCheckedToday`
2. `checkedToday`
3. `makeupApplied`
4. `milestoneClaimed`

允许迁移：

- `notCheckedToday -> checkedToday`
- `notCheckedToday -> makeupApplied`
- `checkedToday -> milestoneClaimed`

## 当前代码来源

- Oasis 首页嵌入通过 `OasisHomeTabHost` 先渲染冻结树，live 后再挂载 `OasisRewardView`：`Ohana/Features/Oasis/Views/OasisHomeTabHost.swift`。
- Oasis live 数据通过 `OasisRewardLiveDataStore` bounded fetch 刷新，不在主 View 使用 broad `@Query`：`Ohana/Features/Oasis/OasisRewardSnapshots.swift`。
- 生命树 XP 从 `CareLedgerEvent.metadataJSON` 中的 `growthXP` / `injectedXP` 重建并缓存：`Ohana/Features/Oasis/OasisTreeManager.swift`。
- Oasis 椰子收支集中在 `OasisCritterEconomyService` 与 `OasisRewardCommandExecutor`：`Ohana/Features/Oasis/OasisCritterEconomyService.swift`、`Ohana/Features/Oasis/OasisRewardCommandExecutor.swift`。
- 升级椰子生成与打开在 `OasisUpgradeRewardService+Opening.swift`。
- 电子宠物互动、升星、碎片唤醒、真实照护回声在 `OasisUpgradeRewardService+Interaction.swift` 与 `OasisUpgradeRewardService+Upgrades.swift`。
- Oasis 与 DailyStreak 共享 `CheckInStreakStore`，命令边界在 `OasisRewardCommandExecutor`。

## 边界

- 本轮不改 SwiftData schema。
- 本轮不启用 CloudKit，不修改联机同步语义。
- 本轮不改变 Oasis / Shop / Gacha / Achievements 的成长解锁等级；只保证锁住时不可达、解锁后命令合规。
- `system:legacy` 可继续存在于数据库中用于迁移兼容，但 Oasis 首发正式行为不得依赖它。

## 验收映射

- OAS-001~005：用 Oasis 经济 / 命令测试覆盖。
- OAS-006、OAS-012：用生命树 XP 重建与缓存测试覆盖。
- OAS-007~008：用现有 mount policy / runtime audit 覆盖，并保留人工 Reduce Motion 目检。
- OAS-009~010：用电子宠物生命周期与 care echo 测试覆盖。
- OAS-011：用 Oasis / DailyStreak 共享命令测试覆盖。
