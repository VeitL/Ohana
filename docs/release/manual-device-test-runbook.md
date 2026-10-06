# 负责人 × Codex 手工设备测试手册

负责人：产品负责人；源码核对：2026-09-25。先在[轮次文件](runs/_template.md)填同一 RC 的 version/build/commit/Archive 与设备/OS；每次只做下列**一个小组**，负责人实际观察后 Codex 才记录结果。Test ID 来自[能力矩阵](feature-test-matrix.md)；真机系统细节与 R0–R7 的权威步骤见[首发真机计划](../release-true-device-test-plan.md)。此处是会话操作层，不能用源码/Simulator 自动结果代签真机。未准备好环境时写 `BLOCKED`，不要猜 PASS。

## 开始前的共用卡片

- 所有案例：先记日期/时区、RC hash、App version/build、安装渠道、设备型号和 iOS 版本；用匿名合成 Human/Pet/Plant，不用主力家庭数据。执行者：人做真实操作，Codex 指引、记录、核对业务预期。每步只在成功后继续；截图或日志只留脱敏关键状态。
- `iPhone 17 Tests` 可按[脚本](../../scripts/reset-test-simulator.sh)重置，用于空库、删除、失败恢复。`iPhone 17 Dogfood` **只能**按[保护规则](../dogfood-testing.md)执行非破坏性正常 UI 读回；不得 reset、卸载、seed、XCTest、删除、恢复、直接改 store/defaults。第二设备恢复必须是可擦除测试机。
- 证据存储位置由轮次文件登记，不要把真实健康值、精确路线、原始数据库、收据、Apple Account ID、个人照片或未遮盖截图发给 Codex。裁去通知内容与状态栏账号，模糊姓名、金额、地点和人脸；记录状态词、计数、匿名代号及哈希即可。脱敏前的资料留在负责人私有设备。
- 每例 `PASS` = 本例**全部步骤**在同一 build 上符合可见和持久/业务预期，且有观察证据。`FAIL` 按下文模板记录首次失败；无法执行用 `BLOCKED`，不存在功能/入口才用 `NOT APPLICABLE` 并说明源码/产品依据。结束后 Codex 只更新当前轮次的对应 Test IDs。

## 会话 1：空装与首启

**案例 MD-01 / OHANA-ONBOARD-001、OHANA-PET-001、OHANA-ECON-001。** 目的：确认第一条本机生命与礼物资格从真实 UI 建立；首启错误会污染所有后续测试。设备：仅一次性 Tests Simulator 或可擦除测试 iPhone；无需账号。前置：确认空库，准备匿名 Human `H1` 与 Pet `P1`。**破坏风险高：不在 Dogfood 或个人主力机清空。**

1. 干净安装，选 Standard，输入 `H1`；留意是否在保存前索要通知/定位/相机权限。
2. 在 Pet 创建页选“稍后”；看 Home 的 Human 卡与 Task Center Pet 系统旅程。完全退出再打开，核对二者仍在。
3. 由旅程创建 `P1`；返回 Home，核对 Pet 卡、首位 Human 的 `+50🥥` 是**可领取**而未自动入账。
4. 手动领取一次，记录钱包数字；立刻再进、重启再进，核对没有第二次领取或额外记录。另用新空库单独走 Zen，不把 Standard 数据复用为首启证据。

预期：Human/Pet 和模式持久，Pet 建议不算奖励/普通任务；礼物只有一次 island ledger。证据：模式、匿名卡、Task Center/钱包的脱敏前后计数、重启观察。清理：保存合成样本供会话 3，不要在此删除；另开空库测 Zen。失败时 Codex 记录 `BUG` 与最短步骤，负责人保留现场并停止该组；通过后 Codex 只给这三个 ID 的本次手工层登记结果。

## 会话 2：既有用户覆盖升级

**案例 MD-02 / OHANA-MIGRATE-001、OHANA-AVATAR-001、OHANA-LIFE-001。** 目的：新装通过不能证明旧数据安全。设备：签名 Release 可覆盖安装的测试 iPhone；Dogfood 只允许[规定](../dogfood-testing.md)的守护 overlay。前置：先在旧 build 建匿名成员、照护、计划、头像、账本，记脱敏计数与 build。**破坏风险高：不可卸载/重置旧用户。**

1. 在旧 build 冷启动，读回成员、历史、余额、提醒和图像；记录基线计数。
2. 安装同签名身份的新 RC **覆盖**旧 App，不清容器；第一次冷启动、后台恢复、再次冷启动。
3. 逐页读回原对象/照护/附件；核对没有重复奖励、空白新身份或丢失计划。若持久库打不开，应只见 recovery/retry 壳，不应创建另一个可写空库。

预期：已提交事实及图片保持，迁移/恢复不重奖。证据：两 build 身份、前后匿名计数与 UI 观察；不提交原始 store。清理：保留测试数据供回归；若失败不要重装以免破坏现场。Codex 下一步比对迁移/启动根因与旧 store fixture，负责人提供脱敏错误/操作顺序。

## 会话 3：核心照护与多入口

**案例 MD-03 / OHANA-QUICK-001、OHANA-FEED-001、OHANA-WATER-001/002、OHANA-POTTY-001、OHANA-WEIGHT-001、OHANA-ECON-001。** 目的：一意图一事务和账本可重放。设备：Tests Simulator 先走，最终在同 RC 真机走关键入口；无需外部账号。前置：`H1/P1`、食物库存、水碗、今日计划；记 Event/钱包/任务基线。破坏风险低但会写合成照护事实；Dogfood 只允许普通非破坏读写且先符合 Dogfood 门。

1. Home 快捷喂食一次，返回详情历史，核对事实、库存、任务、钱包；重启读回。另在新独立 fixture 由详情、Task Center、Calendar 系统事件入口分别完成同一类事。
2. 在 Task Center 找到默认每日“补充饮水 / Water refill”任务并完成；核对任务 occurrence 完成，Water 历史出现一条 250 ml watering 事实。若界面提供同一任务的重放入口，再重复请求并确认没有第二条事实；不要把 Water 详情的直接饮水记录说成独立的“加满水碗”事实。另从 Home 或 Water 详情直接记录饮水一次，分别读回两条路径。
3. 记录一次 potty/猫砂，再记录体重；看各自历史及 Calendar。退出重开，逐项比对。

预期：默认饮水计划完成按当前命令合同写一条 watering 事实（250 ml），命令重放不重复派生；直接饮水记录仍按自己的路径读回。该计划任务目前没有直接自动 UI 证明，需在本会话真实观察；若找不到入口，记 `BLOCKED` 或缺陷线索，不能用 Unit/Integration 结果替代。其余适用入口落同一种业务事实；Event、CareLedgerEvent、CoconutLedgerEntry/余额、提醒、任务、库存与 revision 只随一次成功提交变化。Widget Today 只读，不要求它写入。证据：入口、提交前后匿名计数、历史和钱包最终 UI；无需给 Codex 原始数据库。清理：保留合成事实。失败时先标出“入口差异”与首次不一致字段，Codex 精确选目标测试和 shard，不扩修整个照护模块。

## 会话 4：用药、提醒和通知动作

**案例 MD-04 / OHANA-MED-001、OHANA-REMIND-001、OHANA-HEALTH-001/002。** 目的：真机系统交付与隐私。设备：主测试 iPhone、可接收通知；Human HealthKit 子项需要有合成/允许共享的真实设备数据；不使用私人健康截图。前置：匿名 Pet/Human 的用药计划与到期提醒；记录授权状态。破坏风险低；拒绝/撤销权限会影响此测试机其他通知。

1. 在 App 内建测试药计划和提醒，核对列表与系统授权请求；等待真正交付，分别在前台、后台、锁屏观察标题/私密内容。
2. 从通知执行 Complete、Skip、Snooze，每个动作使用独立测试提醒；重新打开 App 核对剂量日志、任务、下一次提醒及奖励/账本，没有重复完成。
3. 在系统设置拒绝再允许或撤销通知/HealthKit 权限，回到 App 看可理解的状态与恢复入口；对 Pet 健康新增/取消各一次。Human HealthKit 只读，扫描报告仅在 Personal 且只保存人工确认结构化项。

预期：交付/动作/取消与持久状态一致，锁屏不漏健康详情；拒绝不假装成功。证据：脱敏通知状态与时间、权限页面状态词、App 内读回；不传输药名/剂量/Health 值。清理：在测试机撤销测试提醒。失败时 Codex 区分调度、系统交付、动作路由；负责人描述设备 Focus/DND/通知设置而不交出私人资料。

## 会话 5：Task Center、Calendar、本机分工

**案例 MD-05 / OHANA-TODAY-001、OHANA-TASK-001、OHANA-CALENDAR-001、OHANA-FAMILY-001。** 目的：来源不同但同一事项只完成一次。设备：Tests Simulator 与一台真机；无需远程家庭账号。前置：两名匿名 Human、普通任务、健康关键任务、手工日历 Event、零/正数奖励本机 FamilyTask。破坏风险低。

1. 在 Task Center 建普通任务，查看 Calendar，再从一个入口完成；返看 Home/Calendar/详情并重启。
2. 为 Pet 建手工标题“饮水”和系统生成的饮水计划；分别点两行，确认手工 Event 不误入照护详情，系统行到正确模块。
3. 在同设备两名 Human 间提交一条 0 奖励与一条正奖励任务；正奖励仅在主理人确认后转移一次，发布时不扣款；检查两个钱包和 ledger。

预期：任务/Reminder/Event 完成状态一致，无远程邀请或在线登录；付费状态不锁健康关键提醒。证据：匿名事项代号、各页完成状态、钱包差额和重启。清理：保留样本用于会话 10。失败时 Codex 记录来源 Event 与错误路由，负责人停止追加同类任务以保留现场。

## 会话 6：备份导出、加密和恢复

**案例 MD-06 / OHANA-BACKUP-001/002、OHANA-RESTORE-001/002、OHANA-PRIVACY-001。** 目的：数据安全命脉与失败回滚。设备：可擦除第二 iPhone、测试 iCloud Drive 和合成资料；无需 Dogfood。前置：匿名成员、照护、附件、测试健康字段和本机任务；先记录数量。**破坏风险高：恢复/错误密码/系统备份只能在一次性设备；绝不在 Dogfood。**

1. 在测试机手动导出；在负责人私有环境核对文件/加密方式与**受限范围**：不含 Human 健康、PIN、自由文本家庭任务、派生经济账本；只向 Codex报告“包括/排除”布尔结果。
2. 建自动 iCloud Drive 备份，确认成功/失败提示与版本策略；失败时旧库和上次可用备份仍可访问。
3. 在第二设备先装合成旧数据，再导入正确包，核对警告“旧备份可能恢复已删除内容”和恢复后对象、照护、附件、投影关系。
4. 在另一个隔离 fixture 用损坏文件或错密码故意失败；完全退出重开，比对导入前数据/附件计数无变化。R6b 加密**系统**备份/恢复排除边界按[真机计划 R6b](../release-true-device-test-plan.md)另记，不由本例的 iCloud 文件备份替代。

预期：恢复原子、范围受限、失败可恢复；不复制秘密字段。证据：文件 checksum/大小、匿名计数和“排除/存在”结论，不上传包/数据库/收据。清理：由负责人按测试机流程清理合成文件。失败时 Codex 先记录原包/错误类别与设备身份，负责人保留私有样本供安全复现。

## 会话 7：StoreKit 与恢复购买

**案例 MD-07 / OHANA-STOREKIT-001、OHANA-OASIS-001。** 目的：本地商品模拟不能证明真实 Storefront。设备：专用测试 iPhone、Sandbox Apple Account、必要时 TestFlight；需 ASC 产品配置。前置：确认 `Monthly/Yearly/Lifetime` 在 ASC 的地区、价格、trial 状态；旧 Supporter 仅在确有历史商品时测。破坏风险中：不用真实 Apple Account/真实付款。

1. 先确认 Free 基础照护可记录、导出、看历史；打开 Personal 页，看价格来自 StoreKit、月/年/Lifetime 和 Restore 可触达。
2. 在 Sandbox/TestFlight 分别使用独立账号状态测购买成功、取消、pending、验证失败/离线、Restore；每步返回 App，核对 entitlement 与 Free 数据未损失。
3. 在测试环境推进订阅到期、退款/撤销和 Lifetime；重启或换测试机恢复，核对配额只限制**新增超额**，已有数据仍可读/编辑/导出；椰子商店所有权独立。

预期：真实本地化价格/商品与 ASC 一致，交易状态机无假成功，购买恢复可重现。证据：脱敏产品 ID、环境、交易**状态**和 build，绝不分享 receipt 或账号标识。清理：结束 Sandbox 测试会话，不在生产购买。失败时 Codex 区分本地配置与 Sandbox/ASC 问题，负责人确认账号协议/商品状态。

## 会话 8：遛狗、后台定位与权限

**案例 MD-08 / OHANA-WALK-001、OHANA-LIFE-001、OHANA-POWER-001。** 目的：锁屏/后台只有 running walk 可以持续定位。设备：真 iPhone、可安全行走地点；不用精确路线记录给 Codex。前置：匿名 Pet，定位权限从未允许/允许/撤销三状态。破坏风险低但会生成测试位置资料。

1. 在无 walk 时观察定位指示，不应持续请求；从 Home 开始 walk、暂停、恢复、结束并读回总结。
2. 对运行中的 walk 锁屏/后台 30–60 分钟（时长与安全路线按[真机 R5](../release-true-device-test-plan.md)）；打开 App，核对距离/时间连续但没有重复事实。
3. 暂停/结束后核对持续定位停止；系统设置撤销权限后重返 App，看错误/恢复说明；另在 Low Power Mode 比较核心点击和装饰刷新。

预期：仅 running 继续定位；路线不出现在锁屏/日志/Widget；已完成 walk、奖励和账本一致。证据：脱敏总时长/粗粒度距离、定位指示时间、状态变化，不提供路线点。清理：结束测试 walk、确认活动消失。失败时 Codex 对照 `LocationManager`/`PetWalkingManager` 与 `AppWorkloadPolicy`，负责人留系统设置与时间线描述。

## 会话 9：Widget、Live Activity 与锁屏隐私

**案例 MD-09 / OHANA-WIDGET-001、OHANA-LIVE-001、OHANA-PRIVACY-001。** 目的：签名 App Group 与 SpringBoard 行为只能真机证明。设备：含 Dynamic Island 的测试 iPhone 与锁屏；Personal/Free 各一状态。前置：同一 Distribution/TestFlight build，匿名待办、已锁定 Human 与正在遛狗。破坏风险低。

1. 安装 Today Widget 到主屏/锁屏；分别观察 Personal/Free、无项目、过期 snapshot、隐私锁定时的显示，不应出现药名、健康值、附件、自由文本或路线。
2. 点 Widget，分别从冷启动/热启动进入 App，核对目标路由；删除测试事项后 Widget 不显示旧内容。
3. 开始、暂停、恢复和结束 walk，观察 Live Activity 的锁屏/Dynamic Island 状态；重启 App 一次，确认不复制活动或泄露路线；结束后活动消失。

预期：App/Widget 共享投影新鲜且最小化，Live Activity 只读状态正确。证据：完全脱敏截图或文字描述、包和设备身份。清理：移除测试 Widget/结束 walk。失败时 Codex 对照签名 entitlement 和 snapshot generation，负责人核对设备型号/设置。

## 会话 10：语言、外观和辅助功能

**案例 MD-10 / OHANA-L10N-001、OHANA-APPEAR-001、OHANA-A11Y-001、OHANA-MOTION-001。** 目的：关键动作对不同语言/阅读方式仍可完成。设备：真 iPhone；无需账号，商品价格部分沿会话 7。前置：Home、喂食、Task Center、Personal、Settings 已有合成样本。破坏风险低。

1. 在 App 中轮流选注册的 9 种语言（以[语言源码](../../Ohana/Shared/LocalizationSettings.swift)为准），重点看中文、英文、长德语及 RTL 系统方向；重启核对选择。
2. 切明/暗色、最大标准 Dynamic Type、Reduce Motion；逐页打开 Home 卡、记录 sheet、任务、Calendar、Personal，确保按钮可触达、反馈可理解。
3. 打开 VoiceOver，按阅读顺序完成一次非敏感测试记录；用 Accessibility Inspector 辅助找无标签/对比问题，最终以人的操作观察为准。

预期：无关键裁切、误读/无标签、纯颜色状态；Reduce Motion 仍显示成功/错误，业务写入只一次。证据：脱敏文字/局部截图，记语言/字体/外观/焦点顺序。清理：恢复测试机设置。失败时 Codex 指向具体屏幕与语言，负责人提供匿名按钮文案和操作阻塞点。

## 会话 11：密集数据与性能

**案例 MD-11 / OHANA-DENSE-001、OHANA-MEDIA-001、OHANA-PERF-001。** 目的：新装顺畅不能代表多年本机数据。设备：已授权的测试 iPhone 和可重复合成 fixture；Release-like 同一 RC。前置：按[性能政策](../performance-and-observability.md)的密集规模准备多成员、18k+ Event、200+ Reminder、500+ ledger、50+ 图/附件含缺口；不用个人资料。破坏风险低但样本很大，不放 Dogfood seed。

1. 固定冷/暖启动、Home 展开、Task Center 今日与 Calendar 月视图的起止点；各跑可比较的重复次数，记录屏幕可交互时间/卡顿。
2. 连续打开/关闭历史、图像、文档与 walk 总结，检查缺图安全占位、数值正确与内存增长；必要时采同路径 Instruments/MetricKit 和 memgraph。
3. 开 Low Power Mode 重做核心点击；观察装饰停止但事实保存与读回不受影响。

预期：不出现 O(n²) 级明显退化、app-owned 保留对象无法释放、缺图崩溃或隐私日志。具体阈值须在本轮记录可比较基线；没有基线不能随意宣布“很快”。证据：设备/OS/build/fixture 规模/起止点/测量文件及脱敏汇总。清理：保留测试样本供复测。失败时 Codex 先作 code-first 路径定位再聚焦 profile，负责人反馈触发动作与设备状态。

## 会话 12：Distribution Archive 与 App Store Connect

**案例 MD-12 / OHANA-RELEASE-001、OHANA-STOREKIT-001。** 目的：提交的就是验收过的同一包。设备：Mac/Xcode、Developer Portal/ASC 账号与测试 iPhone。前置：已冻结 RC，仓库/Unit/UI/真机结果齐；签名、上传、提交由负责人明确授权。破坏风险：外部不可逆发布动作；本手册本身不授权执行。

1. 负责人核对 version/build、Bundle ID、App/Widget App Group 与 Distribution profile；生成 Archive，保存 checksum 和签名检查。
2. 从该 Archive 生成 Xcode Privacy Report，对照 manifest、隐私答案、受限备份、截图、9 语言、年龄、出口问卷和 Review Notes。
3. 获授权上传后等处理；核对 TestFlight 与待审 build ID 完全对应；查看警告/错误，完成内部/必要外部测试，再做[发布手册](app-store-release-runbook.md)的 GO 门。

预期：包身份、账号记录、产品元数据和真实 UI 一致；无未解释硬门失败。证据：脱敏的 Archive/checksum、报告、ASC build 状态与负责人签收，不共享证书/账号凭据。清理：保存本轮历史材料；若新包生成，另起 RC。失败时 Codex 标明具体门禁，负责人决定修复/重新冻结。

## 会话 13：成员生命周期、植物与媒体

**案例 MD-13 / OHANA-MEMBER-001/002、OHANA-PET-002、OHANA-PLANT-001、OHANA-AVATAR-001、OHANA-MEDIA-001、OHANA-DOC-001。** 目的：确认隐藏、纪念、删除与资源缺失不会留下可操作入口或漏私密内容。设备：一次性 Tests Simulator 先做破坏性部分；最终真机只做照片选择、可读性与安全取消。无需账号。前置：匿名 `H1/P1/Plant1`、测试头像/PDF、一个缺失图片占位及未来提醒。**破坏风险高：删除只能在 disposable 环境，禁止 Dogfood。**

1. 编辑 Human/Pet/Plant 名称及头像，先取消再确认；从 Home、详情与重启后分别核对，缺图应有占位，文档打开/关闭不崩溃。
2. 隐藏 Human/Pet 卡、归档 Plant，确认不计活跃额度且历史仍按规则可查；取消隐藏/恢复归档后应重新出现。
3. 分别对合成 Human/Pet 发起纪念，先取消再确认；回到 Home、Task Center、Calendar，看未来照护/提醒入口停止，纪念内容仍可读。另用独立 fixture 测错误确认名与实际物理删除，重启后不复活。

预期：取消不写、保存后持久、缺失媒体不伤业务事实；纪念不可再写照护/领奖，物理删除后关联投影安全。证据：匿名卡数量、状态词、未来任务/提醒数量、缺图占位的脱敏局部截图；不发原图/PDF。清理：保留失败 fixture 供诊断，成功样本按 Tests 环境后续统一处理。失败时 Codex 记录具体成员生命周期阶段及入口，负责人描述可见状态，不提供私人媒体。

## 会话 14：健康、体重、花费和本机隐私

**案例 MD-14 / OHANA-WEIGHT-001、OHANA-HEALTH-001/002、OHANA-EXPENSE-001、OHANA-PRIVACY-001。** 目的：敏感本机事实准确、金额合法、锁定状态不旁路。设备：Tests Simulator 做非法输入与删除，真机做 HealthKit/Face ID/相机权限；无远程 Ohana 账号。前置：匿名 Human/Pet、两名本机付款人、合法与非法金额、测试报告；不要用私人健康/收据。破坏风险中，权限改变仅在测试机。

1. 分别记 Human/Pet 体重和 Pet 健康事实，取消一次、保存一次、重启读回；在 Human 功能页手动添加/编辑观察值。HealthKit 仅展示只读授权数据，撤权后不伪造成功。
2. Personal 测试状态中取消一次 lab 扫描，核对无原图/OCR 残留；确认一次合成结构化结果并降回 Free，已有记录应可读/编辑。
3. 创建合法多人分摊费用，核对总额与明细；输入 0、负数、非有限值，保存前应拒绝。切到另一名本机 Human，核对受保护资料与 PIN/Face ID 门不能旁路。

预期：有效事实持久、无效金额零写入、健康/扫描原件不进导出/Widget/日志、隐私锁定生效。证据：匿名记录数、错误/成功状态、权限状态和脱敏金额类别，不发数值/报告/收据。清理：移除测试权限/保留匿名事实供备份范围检验。失败时 Codex 选对应命令与隐私测试，负责人只反馈状态和操作步骤。

## 观察与失败记录（复制进轮次）

```text
观察：案例/Test ID；RC SHA/version(build)/Archive checksum；日期时区；设备/OS；
前置匿名数据；步骤编号；实际可见状态；重启后持久/业务结果；
证据类别 HUMAN OBSERVATION；脱敏证据引用；PASS/FAIL/BLOCKED；执行者。

失败：BUG-ID；首次失败步骤；预期 vs 实际；错误文案（去标识）；
是否重试/重试结果；产品/测试/环境初判及理由；受影响 Test IDs；
现场保留方式；负责人下一步；Codex 下一步；复测所需新 RC。
```
