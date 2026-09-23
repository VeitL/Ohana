# Plant Care Logic

> 状态：1.0 当前规则。
> Owner：`docs/specs/product-foundation.md` D1 / D9 / D15 / D20 / D21 / D27 与第 10 节。
> 最近核对：2026-08-09，依据 Plants 命令、护理计划、历史快照、备份与删除边界。

## Product Contract

标准模式在 Lv.4「生命树冠」解锁植物护理；已有植物数据继续 grandfather。Free 最多同时管理 5 株活跃植物，Personal 不限。两档都永久保留已有日志的查看、纠错、手动导出、备份恢复和基础本地提醒；额度或降级不得锁住已有事实。

佛系模式只复用 Plant 档案、Presence 状态与共用基础资料，不因此提前开放标准模式的 Dashboard、护理计划、提醒或时间线。门禁和可达性由 `PlantFeatureGate` 与 `PlantUnlockPolicy` 统一决定，护理服务不得自行复制等级判断。

## Canonical Facts And Write Boundaries

- `PlantCareLog` 是一次植物护理或观察的主事实；`Plant` 上的 `lastWateredDate`、`lastFertilizedDate`、`lastHealthCheckDate` 是可重建摘要，不是第二份独立事实。
- 用户动作只通过 `PlantCareCommandService`、`PlantBatchCareCommandService`、`PlantCareHistoryCommandService` 或计划/提醒完成服务写入。View 只提交 typed intent，不直接改日志、计划、账本、奖励或通知。
- 单次护理使用 caller-owned `operationID`。同一 operation 与同一 payload 重试返回原结果，不再写日志、完成事项、账本或奖励；同一 operation 携带不同 payload 必须拒绝。
- 护理事实、完成 Event、CareLedger 和由该事实更新的护理计划先在同一 `ModelContext` 中准备并一次提交。通知、UserDefaults 指针、经济反馈和其他外部副作用只能在提交成功后执行。
- 奖励是主事实提交后的幂等结算。奖励 transaction key 源自主事实 operation，不得因崩溃、重试或通知失败重复发放；奖励结算失败不得回滚已经可靠提交的护理事实。批量护理必须先完整经过撤销窗口，窗口内任何前台任务或启动对账都不得提前结算奖励。
- 护理事实日期与奖励操作日必须分开保存。历史补记仍按用户选择日期进入 `PlantCareLog` / CareLedger；钱包流水、每日预算与冷却一律按用户提交命令的 operation date 结算，崩溃恢复也必须复用该日期。

## Batch Care

批量护理遵循 D27：一次确认前重验全部目标，任一目标缺失、归档、不再到期或不受支持则整批零写。每次用户确认先生成 caller-owned operation ID，并将它作为该次稳定 batch ID；只有同一 ID 与完整相同 payload 的重试才返回原结果，同日对相同对象再次确认必须生成新 ID 并允许形成新的真实护理。成功批次只有一次保存、一个结果摘要和一个撤销 token；所有覆盖日志共享该 batch ID。

统计同时保留 operation count 与 target coverage。一次给五株浇水是一笔现实操作、五个对象覆盖。任何入口都不得用逐株循环冒充批量命令；已退役的 Today Focus 不重新成为产品入口。

## History Correction And Deletion

- 历史页面必须允许用户纠错。手工/legacy 日志可改护理类型、日期、备注、照片和当时的健康观察；执行人和 transaction ID 不可改。
- 计划或提醒生成的日志锁定护理类型、发生日期和执行人；删除此类日志等价于重新打开对应 occurrence/reminder，而不是删除整个护理计划。
- `defer:` / `skip:` 等系统反馈不进入普通历史编辑、成长日记或照片入口。
- 编辑或删除只重建受影响的浇水、施肥或健康检查摘要与后续计划。日志中的健康状态是当时观察，不覆盖用户独立维护的当前 `Plant.healthStatus`。
- 历史纠错不重新发奖；删除不退回已经发放的椰子，也不释放已经占用的当日预算。缺乏精确 wallet/budget provenance 时不得猜测冲销。
- 奖励仍处于 pending 的日志暂不允许编辑或删除；必须先由幂等对账完成结算，避免改变奖励质量或遗失已持久化但尚未投影回护理账本的结果。
- 同 payload 再次编辑是 no-op；重复删除返回 already-deleted。保存失败时日志、摘要、Event/Reminder、账本和计划整体 rollback，通知只在提交成功后取消或重排。

## Care Plan And Reminder Identity

自动植物计划以稳定 Event ID、Plant link、护理 `TaskCareKind` 和日历形态共同识别。标题只用于展示，不得作为新数据的主键、去重键或业务分类。旧版本中文 marker 仅作为迁移兼容；下一次安全同步应写入结构化身份并生成当前语言标题。

计划标题、安全提示和通知正文使用注册语言的 `L10n` 路径。业务逻辑不得依赖某一种语言，也不得把中文 marker 或中文安全后缀带到其他语言。提醒只在 SwiftData 提交后通过 `ReminderSchedulingManaging` 调度；最终 scheduled / merged / budget / disabled / failed 结果进入既有提醒 CareLedger 观测链。

## Bounded Reads And Export

高频详情和聚合页只读取有序、可取消的有界窗口。首屏不得 fetch 全部 Plant 后遍历所有日志，也不得为了显示最近几行而预生成全量 Markdown 或解码所有照片。

历史使用分页/增量窗口，旧记录必须仍可继续加载。计数、最早/最近日期和 30 日信号用独立轻量查询计算。手动导出是显式操作，可按需读取完整日志；UI 窗口上限不得静默截断导出。

## Lifecycle And Data Safety

- 归档保留档案、历史和导出，停止未来计划、Reminder 和本地通知；恢复后按当前设置重建计划。
- 物理删除 Plant 时清理从属日志、计划、Reminder、CareLedger 与附件，并保留仅供未来同步传播删除的不可恢复 tombstone。
- 受限备份/恢复覆盖 Plant、PlantCareLog、计划偏好和必要附件索引；恢复后重建派生计划，不重复护理事实或奖励。

## Acceptance

自动化至少覆盖：单次 operation 重放与 payload 冲突；核心一次提交和保存失败零写；正式批量全成全败、同 operation 重放/冲突、同日新 operation 可再次护理及一次撤销；历史 edit/delete/reopen 与摘要重建；结构化计划身份和 legacy 升级；九语言标题；提醒 post-commit 观测；密集历史分页与完整导出。

最终 Release 还需在长期已有数据用户上走正常 UI：创建/打开植物、记录、编辑历史、批量照护、提醒路由、重启回读和导出。通知真实送达、权限、后台行为、照片权限与能耗属于签名真机证据，Simulator 通过不能替代。

## Explicitly Deferred

以下不属于 1.0 欠账：真实植物/病害 AI 识别，天气与季节联动，结构化药剂/病虫治疗和高级健康趋势，Family 跨设备协作与共享提醒。它们分别受 Personal / Family / Care+ 已批准边界约束，未实现能力不得出现在销售文案中。
