# 1.0 能力与测试追踪矩阵

负责人：产品负责人；源码核对：2026-09-25，`116ea499f1d005c55d49332db63ded7bc428dafc`。本表从[当前路由](../../Ohana/App/AppRouteCoordinator.swift)、`Ohana/Features/`、`Ohana/Domain/`、`OhanaWidgets/`、[UI shard 清单](../../scripts/ui-test-shards.tsv)及 `OhanaTests/` 重建。产品预期由[产品基石](../specs/product-foundation.md)裁决。`U:` 后是 `OhanaTests/` 下**已存在的测试文件名**；`UI:` 后是 shard 名或 manifest 中的确切方法名，表示**有测试源码**，不表示当前 HEAD 已执行或通过。`—` 是自动化证据缺口。

下面两张表以同一 Test ID 连接：表 A 记行为合同（含前置、fixture、可见/持久/副作用），表 B 记风险、发布相关性、现有自动覆盖、必须补的环境、变体、破坏风险与当前结果。表 B 每个开放 Test ID 的默认跟踪字段为：负责人 `Codex（源码/自动化/Tests Simulator）+ 产品负责人（真机、第二设备与外部账号）`；阻塞为当前 HEAD 缺少同 SHA 执行收据，且 `M/P/A=是` 的相应环境尚无本轮观察；最后核对日 `2026-09-25`。每行最后一列是下一步，退出条件是表 A 所列可见、持久和副作用合同均在同一 RC 上满足并有可定位证据。当前结果一律 `NOT RUN`，因为没有与本 HEAD 绑定的可核实执行收据；证据引用均是 `SOURCE VERIFIED` 的测试/源码位置，**不是** `EXECUTED PASS`。`M`=一次性 Tests Simulator 手工，`P`=真机，`A`=Sandbox/ASC 账号；`是/否` 为是否需要。没有当前证据的完整功能不能标 PASS。

## A. 用户入口、事实与预期

| Test ID | 能力 / 用户入口 | 前置与合成 fixture | 可见结果；重启后持久结果 | 账本、奖励、提醒、任务、库存、revision 等副作用 |
| --- | --- | --- | --- | --- |
| OHANA-ONBOARD-001 | Standard/Zen 首启 / 打开 App | 空 Tests store；无权限 | 先选模式并输入 Human 名字；Standard 可建/推迟 Pet，Zen 进三页 Shell；重启不丢已提交 Human | 第一位在世 Human 只创建可**手领** starter gift 资格；Pet 建议零奖励；不能自动领椰子 |
| OHANA-MEMBER-001 | Human 创建/编辑/隐藏 / Home 卡与资料页 | 一个合成 Human | 卡片和资料更改即时可读；取消不保存、确认后重启保留；隐藏不删除 | 更新成员 revision；不凭隐藏行为发奖或改变历史 |
| OHANA-MEMBER-002 | Human 纪念与删除 / 资料危险操作 | 现役 Human + 替代操作者 | 确认文字错误/取消无变化；离世可看纪念但不可照护；物理删除后重启消失 | 离世停止未来提醒/任务/奖励；删除清理关联事实，不能留下可行动入口 |
| OHANA-PET-001 | Pet 创建/编辑/隐藏 / 首启、Home、基本资料 | Human 已有，Free 未满额 | 自定义物种/品种、生日、外观等确认后持久；取消不提交；被隐藏卡可按设置恢复 | 不重复发 starter gift；成员 revision 与 Free 配额正确 |
| OHANA-PET-002 | Pet 纪念与删除 / 基本资料 | 合成 Pet，含历史和计划 | 纪念只读照护，纪念内容仍可看；取消/错名安全；删除后重启不从日历重开活体路径 | 未来提醒/任务/奖励停；物理删除清关联内容与派生投影 |
| OHANA-PLANT-001 | Plant 创建/编辑/归档/删除 / 植物入口 | Lv.4 或 Personal；一株合成植物 | 列表、房间、资料和照护正确；归档不计活跃额度；删除后不回现 | 浇水计划/提醒/日历一致，植物奖励只一次；revision 更新 |
| OHANA-AVATAR-001 | 头像与图片回退 / 成员卡、照片选择器 | 合成图、一张缺失图 | 选图后 Home/详情一致，重启可读；缺失图显示安全 fallback，不露私人原图 | 无椰子/任务副作用；附件路径受隐私/备份规则保护 |
| OHANA-HOME-001 | Home 卡、展开与排序 / 首页 | Human+Pet+Plant；自定义顺序 | 卡片可展开、导航；顺序/隐藏重启后不意外重置；隐私卡不泄露 | 只更新视图偏好/必要 read-model revision，不写照护事实 |
| OHANA-TODAY-001 | Today Focus/当前 Task Center 聚合 / 首页、待办 | 当日 Event+Reminder+本机 FamilyTask | 只显示应出现的到期项，完成后首页/列表/日历一致；重启正确 | 与来源同一完成事实；系统建议不冒充付费/奖励任务 |
| OHANA-TASK-001 | Task Center 创建/完成/撤销 / 清单 | 普通与关键健康任务各一 | 列表状态与日历一致；编辑/取消/完成读回 | 普通计划按逻辑计划计 Free 额度；关联提醒/奖励只变一次 |
| OHANA-CALENDAR-001 | Calendar 创建/编辑/删除/筛选 / 日历页 | 手工 Event 与 Pet 系统 Event | 手工行进详情，系统照护行到对应模块；筛选不混；重启保持 | 只影响对应 Event/计划/提醒；手工标题不误判为系统照护 |
| OHANA-QUICK-001 | 多入口同一照护意图 / Home、详情、Task Center、Calendar、通知 action、Widget | 同一合成对象/事项，各入口各独立 fixture | 最终 UI 与历史显示同一种完成状态 | 比较 business fact、Event、`CareLedgerEvent`、`CoconutLedgerEntry`、余额、提醒、任务、库存、revision；一个事务只派生一次；通知/Widget 入口若未提供写动作写 N/A |
| OHANA-FEED-001 | 喂食及补记 / Home 快捷、Feeding 详情、Calendar 系统行 | Pet、食物/库存、计划 | 当次/补记在历史正确，取消不写，重启仍在 | `Event`、库存、任务、提醒、椰子奖、两类 ledger、revision 一致，重复提交不重复奖励 |
| OHANA-WATER-001 | 直接记录饮水 / Home 快捷、Water 详情 | Pet、水碗和饮水计划 | 直接饮水记录与当日状态读回；饮水计划可建/删，重启读回一致 | 直接饮水事实按命令规则写入；不要用 Water 详情的快速记录替代计划任务完成路径的验证 |
| OHANA-WATER-002 | 默认计划“补充饮水 / Water refill” / Task Center 或 Calendar 的关联任务完成 | Pet 与一个到期的默认每日饮水计划 | 对应 occurrence 完成，并读回一条 watering 事实；同一完成请求重放为 already applied，不新增事实 | 当前命令测试合同为 `PetCareLog.careType == .watering`、`amountMl == 250`、恰有一条 `CareLedgerEvent`；并未证明会另写独立 refill 事实，也未证明可见 UI 路径 |
| OHANA-POTTY-001 | 便便/猫砂 / Home、QuickCare、详情 | 狗和猫各一，猫砂计划 | 记录、铲砂、全换可读回；重复点击被阻止 | 相应 Event、计划/Reminder、奖励/ledger 与 revision 对齐 |
| OHANA-WALK-001 | 遛狗与路线 / Home 快捷、Walk 全屏、总结 | 可定位的测试狗；允许权限 | 开始/暂停/恢复/结束、重启恢复、总结和路线一致 | `PetWalkLog`/照护事实、距离/便便、奖励/账本、任务、Live Activity 与 revision 只提交一次 |
| OHANA-WEIGHT-001 | Pet/Human 体重 / 快捷与详情 | 两类对象，各一记录 | 单位/趋势/编辑取消正确；重启数值不丢 | 不误写健康或椰子；只刷新对应趋势 |
| OHANA-HEALTH-001 | Pet 健康/免疫 / 功能页 | Pet、症状/疫苗测试数据 | 保存/取消、历史与提醒正确；离世后不可写照护 | Event/健康记录、关键提醒、任务、revision 按事实变化 |
| OHANA-HEALTH-002 | Human 健康、HealthKit、lab import / Human 功能页 | 合成 Human，授权/拒绝分支、测试报告 | 手动记录 Free 可用；Personal 才可扫描；仅确认后的结构化结果持久，原图/OCR 不持久；HealthKit 只读 | 不将 HealthKit 私密值放进备份、Widget、日志；降级保留已有记录 |
| OHANA-MED-001 | Pet/Human 用药与剂量 / 详情、快捷、提醒 action | 药品计划、应服时点 | 记录服/漏/延迟后状态读回，取消不假成功 | 剂量日志、库存、Reminder/Task、奖励和账本适用时只一次；隐私通知不露敏感详情 |
| OHANA-REMIND-001 | 提醒计划、通知 Complete/Skip/Snooze / Settings、任务、通知 | 已授权/拒绝各一设备状态 | 创建、触发、动作、撤销/重复回执可见；重启不复活过期任务 | 调度/取消、任务、照护 Event 和奖励去重；真机交付另验 |
| OHANA-EXPENSE-001 | 花费/多人分摊 / 成员详情、日历 | 金额 >0 与 0/NaN 反例；两名付款人 | 有效事实和分摊持久；非法值在写前拒绝 | 费用 Event/报告、付款明细相加，普通费用不得伪造负报销 |
| OHANA-DOC-001 | 文档、收据、附件 / Pet/Human 资料 | 合成 PDF/图像、缺失附件 | 添加、打开、删除后重启一致；损坏文件给安全错误 | 附件存储/排除系统备份；不误纳入受限导出与 Widget |
| OHANA-PRIVACY-001 | 本机 PIN、锁定与隐私遮罩 / Human 资料、App switcher | 两名本机 Human，锁定一位 | 非本人或锁屏不能旁路，返回前台正确遮罩；PIN 不能当强账号认证 | 私密字段/图不入 Widget、通知、日志、外部备份 |
| OHANA-FAMILY-001 | 本机家庭分工 / FamilyTask、Task Center | 同设备两名 Human，正/零奖励任务 | 创建、指派、提交、确认可读；无远程邀请或第二在线用户要求 | 正奖励确认时才转账一次；零奖励直接完成；提醒/任务/ledger 一致 |
| OHANA-ECON-001 | 椰子钱包、starter gift、奖励账本 / Home 钱包 | 第一 Human、一次照护、多次点击 | 手动领取 +50 后余额/历史读回；不重复领取 | `CoconutAccount` 与 `CoconutLedgerEntry` 可重放；预算/冷却抑制奖但不阻止记录 |
| OHANA-OASIS-001 | Oasis、商店、收藏 / Home、功能菜单 | 已领 starter gift，余额足/不足 | 未领前 Oasis 关闭；购买成功物品/余额重启一致；不足提示 | 椰子扣款、库存/所有权、ledger 和 revision 原子；Personal 降级不回收椰子物品 |
| OHANA-STOREKIT-001 | Personal Monthly/Yearly/Lifetime、恢复、旧 Supporter / 设置付费页 | 本地 fixture 后再真实 Sandbox 商品 | 本地价格来自 StoreKit；取消/待处理/失败不破坏 Free；验证购买/恢复后能力正确，过期/撤销降级保数据 | entitlement 与本地配额正确；不修改 Coconut/Shop 所有权；Family SKU 不展示 |
| OHANA-BACKUP-001 | 手动受限导出 / Settings 备份 | 合成 Human 健康、任务文本、PIN、附件 | 可取得文件并读回批准范围，排除敏感类 | 不含健康、PIN、自由文本家庭任务、派生经济账本；不改源库 |
| OHANA-BACKUP-002 | 加密自动备份 / Settings/iCloud Drive | 测试 iCloud Drive，合成数据 | 成功/失败提示准确，按 Free/Personal 版本策略保留 | 文件受保护且范围受限；失败不删原库或声称成功 |
| OHANA-RESTORE-001 | 另一设备恢复 / Settings | 第二台可擦除 iPhone，合成档案 | 提示旧档可能含已删除数据；恢复后批准范围、附件和关系完整 | 钱包/任务/提醒/投影从源事实安全重建，不复制受限敏感字段 |
| OHANA-RESTORE-002 | 失败恢复回滚 / Settings | 故意损坏/错误密码的合成包 | 明确错误；原有 Home、成员、事实重启后不变 | 没有半导入、孤儿附件、重复奖励或错误 revision |
| OHANA-MIGRATE-001 | 旧用户升级 / 覆盖安装后冷启动 | 固定旧 store fixture/合成旧用户 | 旧记录、头像、计划可读；启动失败保持 recovery shell，不另建空身份 | V99 迁移后 Event、ledger、Reminder、附件关系不丢/不重奖 |
| OHANA-WIDGET-001 | Today Care Widget / Home、锁屏、深链 | Personal / Free、锁定、过期 snapshot | 正确、空/过期/隐私状态；冷/热深链到对应路由 | App Group 仅最小有界投影，删除/重置后旧代际不得回写；无直接照护写动作 |
| OHANA-LIVE-001 | Walk Live Activity / 锁屏、Dynamic Island | 正在 running 的 dog walk | 暂停/恢复/结束同步，锁屏不暴露路线，重启不重复 | 仅最小 session/距离/计时数据；结束/重置清理活动 |
| OHANA-LIFE-001 | 前后台、冷/热启动与权限撤销 / 系统设置 | 既有用户，通知/定位/HealthKit 拒绝或撤销 | 重新进入可用且有恢复提示；无凭空成功或额外事实 | 后台只保留必要调度；撤权后停止相关工作和敏感投影 |
| OHANA-POWER-001 | Low Power Mode / 系统设置 | 长列表、Home、活跃/非活跃 walk | 核心点击即时，装饰降级，状态准确 | `AppWorkloadPolicy` 降低预取/刷新；已提交照护不丢 |
| OHANA-MOTION-001 | Reduce Motion / 系统设置 | Onboarding、奖励、Oasis | 空间/重复动效停，成功/错误反馈仍可懂 | 不缩减数据刷新和业务提交 |
| OHANA-APPEAR-001 | 明暗色 / 系统设置 | Home、付费、隐私、日历 | 文本/控件有对比、状态非仅颜色，重启仍可读 | 无持久业务副作用 |
| OHANA-L10N-001 | 9 种注册语言和 RTL / Settings | zh/en/de/es/pt/fr/ja/ko/it，长德语与 RTL 系统方向 | 关键照护/购买文案及权限提示可懂；布局不裁操作 | 语言设置持久；价格用 StoreKit locale，不写死欧元 |
| OHANA-A11Y-001 | Dynamic Type、VoiceOver / 系统设置 | 最大标准字体、VoiceOver | 44pt 目标、读序、标签/状态正确，重要按钮可到达 | 无业务副作用；语音动作只在明确确认后提交 |
| OHANA-DENSE-001 | 多年密集数据 / 既有用户 Home/Task Center/历史 | 性能政策的 18k+ Event 等合成 fixture | 首屏、滚动、查询与内存不过度恶化，真实值正确 | 有界读取、revision 不全局无故重算 |
| OHANA-MEDIA-001 | 缺失/损坏图片与媒体读回 / 卡片、相册、文档 | 50+ 图/附件含缺口 | 占位可用，不崩溃；修复/重启后读回正确 | 不丢原照护事实，不把路径或私密图写日志 |
| OHANA-PERF-001 | 冷启动、长会话、后台唤醒 / App | 新/旧合成用户，固定设备 | 能到可交互 Home；反复进出无 app-owned 泄漏 | 启动不全表聚合；后台无装饰 timer；附可比 Instruments/MetricKit 证据 |
| OHANA-RELEASE-001 | App Store 包与元数据 / Xcode、ASC | 冻结 RC 与 Distribution profile | 版本/build、截图、隐私/年龄/出口/审核文案与实际可达 UI 一致 | App/Widget entitlement、manifest、App Group、签名、Archive checksum 一致；Family 不可达 |

## B. 自动覆盖、人工门与开放动作

每行的 `证据` 当前均为 `SOURCE VERIFIED（所列源/测试），EXECUTED 缺失`；`PASS` 退出条件是 A 表预期全部满足并有同一 RC 的可定位结果。高价值动作还必须做下节的**多入口等价比较**。`变体` 中 `L`=9 语言抽样至少中/英/长德语，`A11y`=Dynamic Type/VoiceOver，`R`=RTL；`D高` 表示只能用 Tests Simulator 或可擦除第二设备。最后核对日 2026-09-25 适用于每行。

| Test ID | 风险 / 1.0 | 已有 Unit/Integration；已有 UI | M/P/A；变体；破坏性 | 当前状态 / 证据 | 下一步；退出条件 |
| --- | --- | --- | --- | --- | --- |
| OHANA-ONBOARD-001 | 高/必需 | U: `MemberCreationServiceTests.swift`；UI: `testHumanFirstOnboardingWithProductionOverlaysCompletes` | 是/是/否；L,A11y,R；D高 | NOT RUN / SOURCE VERIFIED | 首启+重启；Human 与礼物资格只一次 |
| OHANA-MEMBER-001 | 高/必需 | U: `MemberCreationServiceTests.swift`；UI: `testPetBasicInfoEditCancelDoesNotPersistAndSaveDoes`（Pet 编辑；Human 对应自动证明待补） | 是/是/否；L,A11y；D中 | NOT RUN / SOURCE VERIFIED | Human 编辑/隐藏读回；取消零写入 |
| OHANA-MEMBER-002 | 高/必需 | U: `MemberLifecycleGateTests.swift`；UI: `testHumanMemorialMarkCancelConfirmAndUndoFlow`, `testHumanPermanentDeleteWithExactNamePersistsAcrossRelaunch` | 是/是/否；L,A11y；D高 | NOT RUN / SOURCE VERIFIED | Tests 环境删除/纪念；活体入口与计划清零 |
| OHANA-PET-001 | 高/必需 | U: `MemberCreationServiceTests.swift`；UI: `testHumanFirstOnboardingCustomSpeciesAndBreedSelectorsPersistAcrossBackNavigation` | 是/是/否；L,A11y；D中 | NOT RUN / SOURCE VERIFIED | 创建/编辑/隐藏及 Free 配额 |
| OHANA-PET-002 | 高/必需 | U: `MemberLifecycleGateTests.swift`；UI: `testPetMemorialMarkCancelConfirmAndUndoFlow`, `testPetPermanentDeleteCancelAndWrongNameAreSafe` | 是/是/否；L,A11y；D高 | NOT RUN / SOURCE VERIFIED | 纪念/删除后重启与日历反向路由 |
| OHANA-PLANT-001 | 中/等级可达 | U: `PlantLaunchTests.swift`；UI: `testPlantModuleUnlockCreateCareReminderCalendarAndDelete` | 是/是/否；L,A11y；D高 | NOT RUN / SOURCE VERIFIED | 植物计划/房间/额度读回 |
| OHANA-AVATAR-001 | 中/必需 | U: `AvatarAssetMaintenanceServiceTests.swift`；UI: `testMemberCardAvatarEditorUsesPhotoControlsWithoutExposingFallbackEmoji` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 照片/缺失图跨页与重启 |
| OHANA-HOME-001 | 中/必需 | U: `TodayFocusTaskProjectionTests.swift`（投影）；UI: `testPetExpandedCardShowsQuickActionsWithoutSecondTap` | 是/是/否；L,A11y,R；D低 | NOT RUN / SOURCE VERIFIED | 排序/隐私/卡片展开；偏好保留 |
| OHANA-TODAY-001 | 高/必需 | U: `TodayFocusTaskProjectionTests.swift`；UI: `testFirstCareCompletedByHomeWaterBeforeOpeningJourneyBecomesClaimable` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 同一事项跨 Home/清单/日历一致 |
| OHANA-TASK-001 | 高/必需 | U: `TaskActionCommandExecutorTests.swift`；UI: `testSkippedPetCreationMovesToTasksAndCompletesFromSystemJourney` | 是/是/否；L,A11y；D中 | NOT RUN / SOURCE VERIFIED | 完成/撤销/配额/奖励等价 |
| OHANA-CALENDAR-001 | 高/必需 | U: `CalendarSnapshotBuilderTests.swift`；UI: `testManualCalendarEventRowOpensDetailEditsAndDeletes` | 是/是/否；L,A11y；D中 | NOT RUN / SOURCE VERIFIED | 手工/系统事件与筛选无串线 |
| OHANA-QUICK-001 | 高/必需 | U: `TaskCareKindEventMarkerTests.swift`；UI: `testPetRealUserLongSessionCoversCareCalendarEconomyAndSafeguards`（部分入口） | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 按下节表逐入口比较，缺口不得合并 PASS |
| OHANA-FEED-001 | 高/必需 | U: `ManualFeedCommandTests.swift`；UI: `testFeedingManualPlanAndHomeQuickActionSmoke`, `testFeedingManualHistoryAddOpensBackdateLogSheetAndRecords` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 保存/补记/重复及库存和账本对齐 |
| OHANA-WATER-001 | 高/必需 | U: `QuickWaterCommandTests.swift`；UI: `testPetWaterRecordPersistsFromQuickCareDetail` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 直接饮水记录与计划读回 |
| OHANA-WATER-002 | 高/必需 | U/Integration: `TaskActionCommandExecutorTests.swift`，`localizedDefaultWaterRefillCompletionWritesOneWateringFact`；UI: 未找到直接完成该计划任务的 UI 证明，需手工验证 | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 在 Task Center 完成默认饮水计划，核对任务完成、一条 250 ml watering 事实和一条 CareLedgerEvent；重放不得重复 |
| OHANA-POTTY-001 | 高/必需 | U: `TaskCareKindEventMarkerTests.swift`；UI: `testPetPottyRecordPersistsFromQuickCareDetail`, `testPetLitterScoopPersistsAndRepeatSubmitIsBlocked` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 狗/猫与重复提交结果一致 |
| OHANA-WALK-001 | 高/必需 | U: `WalksLogicTests.swift`；UI: `testPetWalkQuickActionPersistsAndSummaryReadback` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | Simulator 流程 + 真机锁屏/定位 30–60 分钟 |
| OHANA-WEIGHT-001 | 中/必需 | U: `HealthMetricCatalogTests.swift`；UI: `testHumanRecordOperationsPersistFromCurrentUI`（部分） | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 双对象单位、趋势与重启读回 |
| OHANA-HEALTH-001 | 高/必需 | U: `TestPetHealthAlerts.swift`；UI: `testPetHealthRecordCancelAndSavePersistsFromFeatureHub` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 健康事实/关键提醒/纪念边界 |
| OHANA-HEALTH-002 | 高/必需 | U: `HumanHealthConditionCommandTests.swift`, `HumanLabBackupCompatibilityTests.swift`；UI: `testPersonalLabImportCancelLeavesNoArtifacts` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 真机 HealthKit/Camera、原图/OCR 不持久、降级读回 |
| OHANA-MED-001 | 高/必需 | U: `HumanMedicationReminderReliabilityTests.swift`, `MedicationNotificationPrivacyTests.swift`；UI: `testHumanExtendedModuleOperationsPersistFromCurrentUI`（部分） | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 剂量/库存/提醒真机交付与隐私 |
| OHANA-REMIND-001 | 高/必需 | U: `ReminderActionCoordinatorTests.swift`, `ReminderMaintenanceServiceTests.swift`；UI: `testSettingsAdvancedNotificationControlsMountOnlyWhenExpanded`（入口） | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 真机交付/锁屏 action 与取消、去重 |
| OHANA-EXPENSE-001 | 高/必需 | U: `ExpenseAmountPolicyTests.swift`, `ExpensePayerContributionPolicyTests.swift`；UI: `testHumanRecordOperationsPersistFromCurrentUI`（部分） | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 非法金额写前拒绝，分摊合计正确 |
| OHANA-DOC-001 | 中/必需 | U: `DataBackupCoverageTests.swift`（导出边界）；UI: `testPetIdentityDocumentCancelReviewedThenRealSaveSupersedesResolutionAcrossRelaunch` | 是/是/否；L,A11y；D中 | NOT RUN / SOURCE VERIFIED | 附件读回/缺失/删除与备份边界 |
| OHANA-PRIVACY-001 | 高/必需 | U: `MemberLifecycleGateTests.swift`（部分）；UI: `testHumanSettingsInlineSwitcherHidesLocalPrivacyControls` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 真机锁屏/切换/Widget 与通知遮罩 |
| OHANA-FAMILY-001 | 高/本机必需 | U: `FamilyTaskCollaborationTests.swift`；UI: `testPetRealUserLongSessionCoversCareCalendarEconomyAndSafeguards`（部分） | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 本机双 Human 转账一次；远程入口保持关闭 |
| OHANA-ECON-001 | 高/必需 | U: `CoconutWalletServiceTests.swift`；UI: `testStarterGiftCeremonyResumesAfterRelaunchWithoutDuplicateReward` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 礼物/照护后重放余额与账本一致 |
| OHANA-OASIS-001 | 高/等级可达 | U: `CoconutShopPresentationTests.swift`；UI: `testPetCoconutShopEffectPurchaseSpendsHumanBalanceFromFunctionMenu` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 余额足/不足及权益降级，所有权不丢 |
| OHANA-STOREKIT-001 | 高/必需 | U: `SupporterPackEntitlementTests.swift`；UI: `testIsolatedStorefrontPersonalPlansShowPricesTrialAndEmptyRestoreWithoutPurchase` | 是/是/是；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | Sandbox/TestFlight 多生命周期+旧 Supporter 条件核实 |
| OHANA-BACKUP-001 | 高/必需 | U: `DataBackupCoverageTests.swift`；UI: — | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 受限导出逐类审阅，源库不变 |
| OHANA-BACKUP-002 | 高/必需 | U: `AutomaticBackupServiceTests.swift`；UI: — | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 真机 iCloud 文件成功/失败提示 |
| OHANA-RESTORE-001 | 高/必需 | U: `TestDataBackupManagerProjection.swift`；UI: — | 是/是/否；L,A11y；D高 | NOT RUN / SOURCE VERIFIED | 第二设备合成恢复，范围/关系/投影正确 |
| OHANA-RESTORE-002 | 高/必需 | U: `DataBackupAtomicRestoreTests.swift`；UI: — | 是/是/否；L,A11y；D高 | NOT RUN / SOURCE VERIFIED | 故意失败后旧库及附件完全不变 |
| OHANA-MIGRATE-001 | 高/必需 | U: `FamilyTaskV95CompatibilityTests.swift`、V90 旧 store fixture；UI: `testPersistentStoreFailureFailsClosedAndRetryRecovers`（失败壳） | 是/是/否；L,A11y；D高 | NOT RUN / SOURCE VERIFIED | 旧 store 覆盖升级冷启动/读回 |
| OHANA-WIDGET-001 | 高/Personal 可达 | U: 参见 `OhanaTests/` Widget/系统表面契约（精确选择器待核）；UI: — | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 签名 App Group 真机桌面/锁屏/深链 |
| OHANA-LIVE-001 | 高/Free 可达 | U: `WalksLogicTests.swift`（walk；Live Activity 专项待核）；UI: — | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 真机 Dynamic Island/锁屏/relaunch/结束 |
| OHANA-LIFE-001 | 高/必需 | U: `ReminderMaintenanceServiceTests.swift`（部分）；UI: `testPersistentStoreRepeatedFailuresStayClosedUntilSuccessfulRetry` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 撤权、冷启动/恢复、后台无错误事实 |
| OHANA-POWER-001 | 中/必需 | U: `WalletHeroMotionPolicyTests.swift`（部分）；UI: — | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 真机低电与关键点击/事实可读 |
| OHANA-MOTION-001 | 中/必需 | U: `WalletHeroMotionPolicyTests.swift`；UI: `testReduceMotionKeepsHumanFirstValueLoopInteractive` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 重复动效停，反馈保留 |
| OHANA-APPEAR-001 | 中/必需 | U: —；UI: — | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 明暗色主路径人工核对对比 |
| OHANA-L10N-001 | 中/必需 | U: `LocalizationTests.swift`；UI: `testSettingsLanguageSelectionSurvivesImmediateCloseAndRelaunch` | 是/是/是（价格）；L,R,A11y；D低 | NOT RUN / SOURCE VERIFIED | 注册语言、长德语、RTL、StoreKit 真实价格 |
| OHANA-A11Y-001 | 高/必需 | U: —；UI: `testHumanFirstOnboardingAccessibilityContract` | 是/是/否；L,A11y,R；D低 | NOT RUN / SOURCE VERIFIED | 真机 VoiceOver 顺序与最大字无阻塞 |
| OHANA-DENSE-001 | 高/必需 | U: `DenseDataSnapshotPerformanceTests.swift`；UI: `testPetRealUserLongSessionCoversCareCalendarEconomyAndSafeguards`（长会话，非 18k fixture） | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 固定密集样本测真实值/延迟/内存 |
| OHANA-MEDIA-001 | 高/必需 | U: `AvatarAssetMaintenanceServiceTests.swift`；UI: — | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 缺失/损坏 50+ 媒体不崩溃 |
| OHANA-PERF-001 | 高/必需 | U: `DenseDataSnapshotPerformanceTests.swift`；UI: `testLaunchPerformance` | 是/是/否；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | 同设备 Release-like 冷/暖/长会话对比 |
| OHANA-RELEASE-001 | 高/必需 | U: —；UI: `testFirstReleaseReachableHomeOasisAndSettingsSmoke`（仅可达性） | 否/是/是；L,A11y；D低 | NOT RUN / SOURCE VERIFIED | Distribution Archive、隐私报告与 ASC metadata 同包通过 |

## 多入口等价对照（每次单独合成事务）

| 动作 | Home quick action | 详情页 | Task Center | Calendar | 通知 action | Widget/系统表面 |
| --- | --- | --- | --- | --- | --- | --- |
| Feed / Water / Potty | 必测写入与即时反馈 | 必测持久读回/编辑 | 有对应计划时必测完成 | 系统事件应跳正确详情；手工同名事件不可误判 | 有对应动作时测去重 | 当前 Today Widget 是只读投影，写动作 `NOT APPLICABLE` |
| Medication / Reminder | 快捷入口存在时测 | 必测剂量/计划 | 必测完成/跳过 | 必测正确事项 | 真机 Complete/Skip/Snooze 必测 | Widget 只读；Live Activity 仅 walk 状态 |
| Walk | Home 开始与最小化 | Summary 读回 | 有计划时核对 | 有关联事件时核对 | 若无 walk 写动作标 N/A | Live Activity/深链只展示与路由；不直接提交照护 |
| Family task / coconut | Home/钱包读回 | 任务详情确认 | 必测完成 | 可见时核对 | 若通知无可达动作标 N/A | Widget 最小投影不提供写入 |

每个可写入口都比较 **business fact → SwiftData Event/模型 → CareLedgerEvent → CoconutLedgerEntry/余额 → Reminder → Task → 库存 → revision → 最终 UI**；不适用的列写 `NOT APPLICABLE` 和理由，缺少自动化证据写“待补”，不能用“点到按钮”代替保存/读回。手工小组在[设备手册](manual-device-test-runbook.md)，实际结果只进当前[轮次](runs/current-candidate.md)。
