# 首发真机测试清单

更新日期：2026-07-22

本文件给真机执行使用，目的是让你一眼看清：哪些已经由自动化或模拟器预检覆盖，哪些还必须由你在真实 iPhone 上签收。

状态源不变：

- 当前发布状态看 `docs/testing-progress.md`。
- 详细人工验收记录看 `docs/planning/gap-acceptance-track-list.md`。
- 发现新问题时写入 `docs/task-follow-ups.md`。
- 本文件只是执行清单，不替代上面三个状态源。

## 怎么读

- “已测过”表示已有单元测试、审计、模拟器 UI 测试或既有真机 smoke 证据。
- “真机还要测”表示模拟器不能证明的系统行为、真实硬件手感、权限弹窗、真实数据样本、长列表滚动、键盘、通知、相册和文件选择器等。
- “通过标准”是你真机测试时的判定标准。
- 完成与否先在“完成打卡板”勾选；如果失败，保持未勾并把缺陷同步到 `docs/task-follow-ups.md`。

## 本轮结论

当前已知首发仓库代码层 P0 为 0，首发可达的实现 / 证明 P1 为 2。状态总账还剩
13 个 follow-up：1 个 Free / Personal 与 Storefront 项、1 个 Widget / Dynamic
Island 能力与真机项、1 个 Family 守护专项、1 个 CloudKit 1.x 延后项、4 个其他
真机 P1、4 个非阻塞 P2 和 1 个未来 P3。Family 守护在开关关闭时不阻塞本地
Free / Personal 发布，但任何 Family 发布必须先关闭其专项 P1。
设备范围已经批准为 iPhone-only / iOS 26.2+；签名
Archive、App Store Connect 和最小实体 iPhone 证明并入下方 R0。下方 17 项
是给人执行的合并验收清单，不等于 17 个独立 open follow-up；第 15 项
CloudKit live apply 在首发继续关闭 CloudKit 时只需确认本轮不测。开始新的真机
RC 签收前，先关闭 `TFU-20260715-003` 与 `TFU-20260720-001`；旧 Pet-first
真机结果不能替代当前流程。

建议分两轮完成：

1. 第一轮：只跑首发硬门和系统权限。先验证 R0 设备矩阵与签名包，再覆盖首启、覆盖安装、Settings、PIN/隐私、通知、纪念模式通知、相册/文件选择器。
2. 第二轮：跑模块视觉和手感签收。覆盖宠物、人类、日历账本、费用文档、成就心愿、照片周报、植物/纪念历史、RC。

## 校对状态

本清单已按 2026-07-15 当前源头校对：

- 17 项把当前真机/人工债按用户路径合并，状态数量以
  `docs/task-follow-ups.md` 为准。
- GAP-6、GAP-7、GAP-9 的详细要求来自 `docs/planning/gap-acceptance-track-list.md`。
- CloudKit live apply 来自 TFU-20260614-014 和 `docs/cloud-sync-todo.md`，首发关闭 CloudKit 时不进入真机测试轮。
- D24、`docs/os-support-matrix.md` 和机器清单已经固定 iPhone-only / iOS
  26.2+；R0 只负责核实最终签名产物、App Store Connect 与实体设备，没有重新
  打开 iPad 或原生 Watch 产品范围。
- 本清单只用于你执行和打勾；最终通过 / 失败状态仍要同步回对应总账。

## 2026-07-11 历史模拟器预检

- 当时的快速发布 UI smoke 已通过 3/3；Pet-first 首宠创建路径在每轮重启 App 的条件下
  连续通过 10/10。证据见
  `docs/audits/2026-07-11/UI_SMOKE_GATE_CLOSURE.md`。
- 当时的自动辅助功能契约已确认首宠 Today Focus 卡片只有一个具名主动作，保留
  Button role、完整标题/说明和稳定 activation frame。
- XCUITest 的调试树仍会列出 SwiftUI 用于绘制的 `Text`，即使父辅助功能元素
  已声明忽略子元素；因此模拟器自动化不能替代真实 VoiceOver 的逐项朗读顺序、
  焦点移动、Voice Control 或 Switch Control 验收。
- 上述证据只关闭当时的 UI smoke gate。Today Focus 与 Pet-first 首启现已被
  Human-first + Task Center 系统旅程替代，不能据此勾选当前首启、待办或 Oasis 项。
- TFU-20260710-007/008 的仓库内预检已关闭：费用命令和恢复路径对无效金额的
  失败/恢复/重复用例通过 14/14，运行时策略用例通过 6/6；开启中央 Reduce
  Motion 策略的 Pet-first 照护 → 奖励 → Oasis 路径在 iPhone 17 模拟器通过
  1/1。该结果不替代真机 VoiceOver、Voice Control、Switch Control、触感和
  能耗验收。

## 2026-07-15 当前流程前置条件

- 当前首启必须是 `Human 名字 -> 现在建宠 / 稍后建宠`，不得再出现无 Human 的
  新装 Pet-first 主路径，也不得预先请求通知、定位、相机或相册权限。
- 立即建宠路径必须在 Pet 保存后进入待办的 50 椰子领取事项；只有用户在奖励层
  明确领取成功后才显示 Oasis。Pet 保存或首次照护都不得自动发这 50 椰子。
- 稍后建宠路径立即进入包含 Human 卡片的首页；待办保留“建立第一只宠物”，
  取消创建后仍保留，建宠后再替换为领取事项。
- 领取启动赠礼后，待办顶部最多显示三项 D28 新手成长计划。六项总额 400，
  必须分别满足真实资格并明确领取到有效 Human 钱包；选择暂无、不适用、不清楚
  或不愿透露不能被当作低一等完成。
- 这组当前流程的本地编译、定向测试和 disposable-Simulator 证据仍由
  `TFU-20260715-002` 负责。关闭前不要生成新的签名 RC 结论。

## 完成打卡板

使用方法：

- 完成且通过：把 `- [ ]` 改成 `- [x]`。
- 失败或需要我修：不要勾，在这一行后面写 `失败：现象`，并把详情写到对应小节的“记录”。
- 需要复测：不要勾，在这一行后面写 `复测：原因`。
- CloudKit 如果首发继续关闭，勾选第 15 项表示“本轮确认不测”。
- Family 守护保持运行开关和 SKU 关闭时，第 17 项标记“Family 本轮不发布”；只有
  准备开放 Family 时才执行完整双真机矩阵。

### 第一轮：首发硬门和系统能力

- [x] 1. GAP-7 补记喂食
- [ ] 2. GAP-6 通知交付
- [ ] 3. GAP-9 离世退场
- [ ] 9. Medication / Notifications
- [ ] 11. Expenses / Insurance / Documents
- [ ] 12. Privacy / Security
- [ ] 13. Onboarding / CrewRoster / FunctionMenu
- [ ] 16. Today Widget / Live Activity / Dynamic Island

### 第二轮：模块视觉和手感

- [ ] 4. PhotoAlbum / FamilyReports
- [ ] 5. Memorial / Plants
- [ ] 6. PetCare / CatCare / Hygiene / Moments
- [ ] 7. Achievements / Milestones / GrowthUnlock / Wishlist
- [ ] 8. HumanHealth / HumanNotes / Workouts
- [ ] 10. Calendar / DashboardRecords / CareLedger

### 收尾 / 延后确认

- [ ] 14. Phase 9 dogfooding / RC
- [ ] 15. CloudKit live apply policy - 首发关闭 CloudKit 时勾选“本轮不测”
- [ ] 17. Family App 内亲友守护 - 本地版关闭时标记“本轮不发布”；开放前必须双真机通过

## Family 守护专项（对应打卡 17）

前置条件：生产 / Sandbox APNs、AWS `eu-central-1`、Cognito + Sign in with Apple、
真实 HTTPS Universal Link / Associated Domains、App Store Server Notifications V2、
Family Yearly Sandbox 商品和隐私标签均已配置。使用两台实体 iPhone 和两个 Apple
测试账号，不得用模拟器结果替代。

- 邀请：链接、二维码和 16 位邀请码均只能在安装 Ohana、登录并明确接受后建立关系；
  过期、复用、第四位守护人和撤销必须失败或正确停止。
- 权限与设备：允许 / 拒绝通知、同账号第二设备、退出当前设备、卸载 token 失效、
  全部守护人不可达警告均符合真实状态，不显示“已收到”。
- 漏签：第 1 个守护日无亲友推送；第 2 日恰好一次首次推送；第 3 日最多一次跟进；
  第 4 日以后同一事件安静。
- 结束：守护人“已联系到本人”不生成签到；本人恢复只发一次恢复推送；暂停、切换
  普通模式、更换 / 解绑本人、纪念、撤销、Family 到期和删除账号均停止后续调度。
- 离线与隐私：离线签到显示等待同步，恢复联网后不误报；锁屏不出现姓名、分数或
  照护资料；服务端日志无姓名、号码、邮箱、分数、健康、Pet、Plant 或费用。
- 订阅：Family 同时开放 Personal；Family→Personal / Free、退款、撤销和账单状态变化
  停止在线守护但不改变本机签到、档案或椰子。

记录：设备 A / iOS：_____；设备 B / iOS：_____；build：_____；AWS stage：_____；
APNs 环境：_____；StoreKit 测试账号：_____；问题：_____。

## 2026-07-09 Solo Release P0/P1 专项验收

这组是当前最短修复路径的真机 Release 签收。必须用已签名的 **Release**
包和真实 iPhone 执行；模拟器、Debug、静态审计或 Instruments 截图都只能当
预检，不能勾选下面任何一项。

- [ ] R0. 首发设备矩阵与签名包
- [ ] R1. 公开政策与支持入口
- [ ] R2. 首页十次快速照护
- [ ] R3. 两分钟 sheet 覆盖首页
- [ ] R4. 500 图长滚
- [ ] R5. 30–60 分钟锁屏遛狗
- [ ] R6. 自动备份与删除失败恢复
- [ ] R7. Today Widget 与 Dynamic Island

### R0. 首发设备矩阵与签名包

步骤：生成已签名 Release Archive；在 App Store Connect 核对设备与 storefront；
分别在 iPhone SE（第二代）或实际首发最小 iPhone，以及一台当前 iPhone 上安装
同一 build 并完成 Human 名字 → 立即建第一只宠物 → 待办明确领取 50 椰子 →
Oasis 解锁 → 第一笔真实照护的最短 smoke；再用 disposable 环境覆盖一次“稍后建宠”。

通过标准：

- Archive 的 `UIDeviceFamily` 仅包含 `1`，App Store Connect 不要求 iPad 截图，
  不包含 watchOS app 或 complication。
- 签名 App 内嵌且只内嵌当前 `OhanaWidgets` WidgetKit extension，不包含
  watchOS app 或 complication；App 与 extension 的 bundle identifier、版本和
  deployment target 一致可解释。
- 签名 App 与 target entitlement 一致，只保留当前需要的 HealthKit、
  CloudDocuments 与匹配环境的一个 App Group；Widget extension 只申领同一个
  App Group。不包含 Sign in with Apple、CloudKit、APNs 或 remote notification。
  Developer Portal 与 distribution profile 不保留未使用能力。
- 最低系统为 iOS 26.2；最小与当前 iPhone 都能完成核心 smoke，关键操作不截断、
  不被安全区遮挡、没有启动或持久化失败。
- 记录实际开放的 storefront。原生 iPad、原生 Watch 与更低 iOS 不得写入首发宣传。

记录（2026-07-11，部分完成）：Archive / build：开发签名 Release 1.0 (1)，
`/tmp/OhanaArchives-20260711/Ohana-R0-eece7d642-dirty.xcarchive`；
`xcodebuild archive`、Xcode store validation 和严格 `codesign` 校验通过。
归档产物为 arm64、`UIDeviceFamily = [1]`、`MinimumOSVersion = 26.2`，不含
app extension / watchOS 内容；签名 Entitlements 只有 HealthKit 与
`CloudDocuments` iCloud container，没有 CloudKit、APNs 或 App Group。
Provisioning profile 包含当前设备，当前 iPhone 17 Pro Max / iOS 26.5.2
(23F84) 已安装并启动，进程未立即退出。用户授权后已于 2026-07-11 卸载 App
以清除本地容器，再重新安装并启动同一 Archive；未删除 iCloud Drive 或用户
自行导出的备份。最小设备 / iOS：未执行；当前设备内“首启 → 建第一只宠物 →
第一笔照护 → Oasis” smoke 已走到 Oasis，但在只有 Pet、没有 Human、总额显示
59🥥 的样本上，点击右下角生命树注入只震动、不增加能量。根因已定位为旧 D17
50🥥 赠礼错误绑定 Pet，而注入命令硬依赖 current Human。当前工作区已把赠礼改为
`system:island` 岛屿储备，加入旧 v2 赠礼幂等重分类，并让生命树原子使用全部正式
岛屿总额；32 条 targeted Unit/Integration 与 1 条 Pet-first 五次注入 UI 路径通过。
随后增量 `-O` Release 设备包通过严格签名校验，并在不卸载、不清空容器的前提下
覆盖安装和启动。只读复制设备 SwiftData store 后确认迁移已提交：`system:island=50`、
Pet 奖励余额 `9`、`system:legacy=0`，同时存在 Pet `-50`、岛屿 `+50` 和幂等 marker，
总额仍为 59。还需用户在该设备点击一次注入，确认总额 59→49、树能量 +10，故当前
设备核心 smoke 尚未最终签收；Storefront：未验证。当前机器
只有 Apple Development identity，因此本次证明的是可安装的
开发签名 Release，不是 App Store distribution / App Store Connect 通过证据。
项目目录受 File Provider 管理时，`.build` 内归档会在签名前重新附加
`com.apple.FinderInfo`；将 DerivedData 与 Archive 移到 `/tmp` 后成功，归档内
未残留 FinderInfo / ResourceFork。R0 保持未勾选，直至最小设备、当前设备完整
smoke 与 App Store Connect / storefront 均有记录。该 Archive 的无 Sign in with
Apple、HealthKit + CloudDocuments 能力边界与当前产品决定一致，但它早于当前
HealthKit 和文档变更；仍须用当前 worktree 生成新签名包重测。

历史记录（2026-07-12，不得用于当前验收）：一份短期 Apple 身份原型 Archive
`/tmp/OhanaArchives/2026-07-12-105335/Ohana-c2aa2af859-dirty.xcarchive`
曾包含 Sign in with Apple，并完成覆盖安装、数据保留、取消和授权观察；后续
Create Human handoff 曾卡住。该原型及后续 Supabase 账号原型均未进入产品，现已连同
登录 UI、Auth 依赖、账号 entitlement/config/privacy 声明一起移除。此 Archive 不再
匹配当前 target，不能签收 R0 或任何账号能力；未来设计仅见
`docs/planning/account-backend-extension.md`。

记录（2026-07-12，当前 local-only 包已安装，用户观察待完成）：
`scripts/archive-release-local.sh` 成功生成并验证
`/tmp/OhanaArchives/2026-07-12-180306/Ohana-c2aa2af859-dirty.xcarchive`。
WMO Archive、Xcode store validation、strict `codesign`、designated requirement、
xattr 检查均通过；产物为 arm64、iPhone-only、iOS 26.2+，不含 extension/watchOS。
签名 App 只申领 HealthKit + CloudDocuments，不含 Sign in with Apple、CloudKit、APNs、
App Group 或 remote-notification mode；`PrivacyInfo.xcprivacy` 无 collected data、tracking
或 tracking domain，也无 Supabase/crypto 产物。该 App 已在不卸载、不清空数据的前提下
覆盖安装并通过 CLI 启动于 iPhone 17 Pro Max / iOS 26.5.2，进程保持存在。development
profile 仍允许比 App 更宽的 Apple 登录/APNs/iCloud/HealthKit 能力，因此 distribution
profile / Developer Portal 卫生仍是 R0；用户尚未确认原数据保留以及修复后的
Exercise/Stand/活动环/Recent Workouts，R0 与 HealthKit P1 均保持未勾选。

### R1. 公开政策与支持入口

步骤：在 Settings > 关于，点“隐私政策”和“获取支持”。

通过标准：

- 隐私政策打开公开 HTTPS 页面，内容与当前实现一致：无 Ohana 账号、登录、开发者
  后端、分析、追踪或照护数据远程同步；自动 iCloud Drive 包由用户自己的 iCloud
  持有，且不含人类健康/HealthKit/体重/运动/用药/健康报告。
- 支持入口打开邮件撰写，收件人正确，且不会自动附带任何记录、日志、截图或诊断数据。

记录（2026-07-11，外部 URL 预检）：公开隐私政策 HTTPS 页面可匿名访问，页面
内容声明 Solo 关闭 CloudKit sharing、APNs、远程同步，并声明自动 iCloud Drive
备份排除人类健康 / HealthKit 数据。真机 Settings 内点按、系统浏览器跳转、邮件
撰写页收件人与“不会自动附带诊断数据”尚未执行；R1 保持未勾选。

### R2. 首页十次快速照护

步骤：在一个有真实数据的宠物首页，以正常手速连续完成十次快捷照护；混合喂食、
饮水、如厕、清洁或播放等可用动作，并记录每次预期是否应被重复保护拦截。

通过标准：

- 每次触摸先出现即时视觉反馈，页面不冻结、不掉帧、不需要第二次点按。
- 每个允许的动作恰好写入一条事实、奖励和历史；预期被重复保护拦截的动作不多写。
- 返回首页后卡片、待办角标和余额只合并刷新一次，不出现持续重算或跳位。

记录：设备 / iOS：_____；动作与结果：_____；问题：_____.

### R3. 两分钟 sheet 覆盖首页

步骤：从首页打开一个会写入照护或设置的 sheet，保持覆盖首页至少两分钟；期间完成
一次有效操作，再 dismiss 回首页。

通过标准：

- 覆盖期间首页不在后台反复刷新、解码或播放环境动效；sheet 手感稳定。
- dismiss 后只做一次合并刷新，新事实可见且没有重复写入、闪烁或卡片位置跳变。

记录：设备 / iOS：_____；sheet：_____；问题：_____.

### R4. 500 图长滚

步骤：在 Release 真机导入或使用包含约 500 张真实图片的相册/记录列表，连续上下
滚动至少十轮，并在低电量模式下再完成一轮。

通过标准：

- 可见缩略图正确、无错误复用；离屏图片不持续占用内存。
- 无明显卡顿、黑屏、崩溃或系统内存警告；低电量模式仍可按需显示图片，只是预取和
  缓存工作集更小。
- 如使用 Instruments，记录 Memory / Energy 轨迹并附在本任务记录，不以截图代替结果。

记录：设备 / iOS：_____；图片数：_____；低电量轮次：_____；问题：_____.

### R5. 30–60 分钟锁屏遛狗

步骤：从真实 iPhone 开始一条狗狗遛狗，锁屏并维持 30–60 分钟；中途至少一次恢复
前台，再停止并检查路线、距离、便便点、历史和静态地图。

通过标准：

- 仅活跃遛狗持有后台定位；锁屏期间路线连续，恢复前台后不会创建第二条 session。
- 停止后只保存一套路线事实；共享目标如有，使用同一派生地图而非重复地图渲染。
- 低电量或高热时地图以降级质量延后生成，不影响走路事实持久化。

记录：设备 / iOS：_____；时长：_____；电量起止：_____；定位权限：_____；问题：_____.

### R6. 自动备份与删除失败恢复

仅使用测试数据执行。先完成一次自动备份，再临时让 iCloud Drive 不可用（例如断网或
退出测试账户）并执行 App Reset；随后恢复 iCloud Drive，进入 Settings > 数据备份并
点击重试删除。

通过标准：

- 自动包标记为受限范围；不包含人类健康、HealthKit、体重、运动、用药或健康报告。
- reset 即使远端删除失败也完成本机清除，但 Settings 持久显示“需要处理”状态与错误，
  不把失败伪装成已删除。
- 恢复 iCloud 后重试可删除旧 app-managed 自动包；若仍失败，错误仍保留且可解释。

记录：设备 / iOS：_____；iCloud 状态：_____；结果：_____；问题：_____.

### R7. Today Widget 与 Dynamic Island

步骤：用同一已签名 Release 在支持 Dynamic Island 的真实 iPhone 上添加 Today
Widget 的 small、medium 与 accessory rectangular；分别观察 Personal、Free、
降级、锁屏、过期快照和 App reset。随后为活跃狗狗开始遛狗，依次暂停、继续、
添加便便标记、锁屏、回前台、杀进程后重开，再从 Lock Screen / Dynamic Island
进入 App 并结束遛狗。

通过标准：

- Personal Widget 最多显示三项最相关照护事项；不显示自由输入任务标题、健康
  详情、已删除或已离世对象。Free / 降级态显示升级说明而不是旧 Personal 数据。
- small、medium、accessory rectangular、锁屏隐私与九语言关键长文案不截断；
  空、过期、App Group 不可用和 reset 状态安全降级，不显示陈旧私人内容。
- Widget 从冷启动和热启动都进入正确待办或设置路径，不接受外部 scheme / host；
  路由无效时留在安全页面而不是打开错误成员。
- 每次遛狗只有一个 Live Activity；Lock Screen 与 Dynamic Island expanded、
  compact、minimal 的时间、距离、暂停和便便数一致。恢复 App 不复制 session，
  停止后 Activity 正常结束，陈旧 Activity 会被清理。
- 前后台、Low Power、Reduce Motion 与锁屏期间不出现高频刷新或额外业务写入；
  定位和持久化仍由既有 Walk 领域边界负责。

记录：设备 / iOS：_____；build：_____；App Group / profile：_____；Widget
families：_____；Dynamic Island：_____；问题：_____.

## 快速总表

| 编号 | 模块 / Gate | 已测过 | 真机还要测 | 本轮状态 |
| --- | --- | --- | --- | --- |
| 1 | GAP-7 补记喂食 | 模拟器 UI 已覆盖 History “+” 手动补记、1 天 / 2 天历史日期保存和回读；2026-07-01 batch F 再次复测通过。 | 手动选择历史日期补记一次，确认历史行日期和操作日奖励口径正确。 | 待真机 |
| 2 | GAP-6 通知交付 | 调度策略、合并、夜间延后、关键用药豁免、通知 action 协调、Observability 面板已测；2026-07-03 已补测关联植物的普通 Calendar 事项会按用户选择时间通知，不被植物护理提醒窗口挪到早晨；普通植物关联 Reminder 完成 / 跳过不会误写植物护理事实。 | 真机权限弹窗、banner、锁屏、Focus/DND、前台展示、通知点击和完成 / 跳过 / 稍后提醒；真机创建一个关联植物的普通 Calendar 事项，确认按选定时间通知；如有配对 Apple Watch，再确认 iPhone 通知转发及三个 action 恰好处理一次，但不得据此宣称原生 Watch app 支持。 | 待真机 |
| 3 | GAP-9 离世退场 | 离世对象活跃入口过滤、冻结钱包、历史可读、未来计划清理、标记 / 撤销 UI 已测；2026-07-01 已复测 Human、Pet 和 Dog 纪念标记 / 撤销的取消 / 确认路径，并复测纪念宠物不再暴露 Home / Function Menu 活跃照护入口，旧 Calendar 宠物事项不会打开活跃照护页。 | 真机标记离世、撤销离世、通知取消 / 恢复、历史资料可读、无活跃照护入口。 | 待真机 |
| 4 | PhotoAlbum / FamilyReports | 周报非竞赛语义、照片隐私清洗、相册命令边界、密集照片 fixture 已测；2026-07-01 已复测 Settings Debug -> Family Weekly Report GUI，batch L 再次复测周报入口和非竞赛文案。 | PhotosPicker 权限和选择器、真实批量照片、大图 viewer、隐私和性能目检。 | 待真机 |
| 5 | Memorial / Plants | 植物门禁、历史植物数据、植物提醒 / 照护 / 账本边界、纪念历史可读已测；2026-07-01 已跑通植物解锁、创建、提醒、日历、护理和删除 GUI 长链路；最新复测确认新建植物生成的植物计划可在 Calendar 列表行中找到；2026-07-03 最新 executor 级单测确认添加植物命令会直接物化植物计划 Calendar Event 和 Reminder 行；植物提醒“全部延后一天”业务单测和 existing-plant Settings GUI 路径均已通过；batch K 又完整复跑植物解锁、创建、提醒、Calendar、详情护理、删除撤销和最终删除；batch L 再次复测 existing-plant Settings bulk defer 和 Plant Detail 编辑取消 / 保存；2026-07-03 已复测系统生成植物护理计划仍走植物提醒窗口，同时普通植物关联 Calendar / Reminder 完成或跳过都不污染植物护理日志、last-care 日期和植物护理账本；后续产品口径改为不再提供植物页 / Function Menu 的独立植物日历入口，植物事项只从统一待办的“植物”筛选查看；植物 wallet 卡片展开 / 收起已做根因复测，当前实现使用共享 scene 的本地 inactive freeze 锁住非选中卡片 frame / rotation，且不恢复植物页外部 frozen 状态，非选中卡片不应再跳位；8 株植物长列表已 GUI 复测为首屏只有 6 张可点卡片，后续卡片需要向下滚动并仍可展开 / 收起。 | 用真实纪念对象和历史植物样本遍历 Home、Task Center、Oasis、FunctionMenu；真机点击 Settings -> Plant care reminders -> Defer all by one day 并看反馈；新增植物品种库添加、植物 wallet 卡片展开 / 快捷操作、右侧房间 rail 手感验收；真机创建关联植物的普通 Calendar 事项并确认通知按时到达；从待办日历点“植物”聚合筛选确认可查看植物事项，同时确认植物详情和 Function Menu 植物分组不再出现独立日历入口。 | 待真机 |
| 6 | PetCare / CatCare / Hygiene / Moments | 宠物快捷照护、猫砂、护理、quick moment、奖励、账本和重复保护已有广泛模拟器覆盖；遛狗大卡片最小化 / 悬浮窗互斥 / 再点遛狗回当前卡片已复测；2026-07-01 已复测宠物功能中心、猫狗长链路、Feeding 补记、Home 快捷喂食、potty / hygiene / health / walk 记录、walk summary、litter scoop / full-change / plan、Bond Vault、永久删除安全保护和已故宠物入口过滤；首页展开卡内部快捷操作延迟、快捷操作加载前点击卡片无法缩小、底部 FAB 菜单遮挡卡内快捷操作的问题均已修复并复测；batch K 又复测 Pet Feature Hub 日常 / 健康入口和 Dog Home 遛狗快捷操作 -> summary -> feature hub 回读；batch L 再次复测 Water 奖励账本、水计划 Calendar 保存 / 删除、Bond Vault 余额不足 / 解锁支出、Coconut Shop 购买和 Basic Info 编辑取消 / 保存。 | 真机连续点击、历史跨页回读、低性能手感、已故对象只读 / no-op，以及首页展开卡快捷操作手感。 | 待真机 |
| 7 | Achievements / Milestones / GrowthUnlock / Wishlist | 成就领取、里程碑、成长解锁策略、心愿单兑换业务和 UI 已测；2026-07-01 已复测心愿创建 / 兑换和 Daily Streak sheet 打开 / 关闭，batch L 再次复测两者。 | 成就墙、里程碑、成长路线、心愿兑换的长文案、按钮遮挡和触感。 | 待真机 |
| 8 | HumanHealth / HumanNotes / Workouts | 添加 / 回读、删除后消失、首发本地查看者可见策略已由模拟器 UI 覆盖；2026-07-01 已复测 Human Feature Hub 多路由、Home 快捷 sheet、weight / expense / medication / note 持久化、note 保存后历史刷新、note 删除和扩展模块创建 / 删除；batch K 又复测 Human extended module 连续写入 body metric / workout / health report / wishlist / profile notes；batch L 再次复测 Human record persistence。 | 真机键盘、长文案、添加 / 删除、本地查看者文案和手感最终签收。 | 待真机 |
| 9 | Medication / Notifications | 宠物 / 人类用药命令、剂量记录、Human medication 添加 / 回读 UI 已测；2026-07-01 已复测 Reminder Observability 入口和 Human medication 持久化，batch L 再次复测 Observability 面板。 | 真实通知系统行为同编号 2；再确认用药入口、长语言通知和手感。 | 待真机 |
| 10 | Calendar / DashboardRecords / CareLedger | 日历命令、筛选、深链、水计划读回、密集快照、账本 backfill 已测；手动事项详情 / 编辑 / 删除、系统喂食事项跳 Quick Feed、Add Event 键盘保存、水计划日历保存 / 删除、宠物筛选，以及标题像 feed / water / potty / walk / play / weight / health / hygiene 的宠物关联用户事项打开可编辑详情已复测；最新 6 条策略单测还覆盖普通植物事项不会误跳系统页，生成的喂食 / 饮水 / 植物计划会进相关详情页 / 打卡页；batch E/F/G/H/I/J/K/L 复测系统计划、linked pet 用户事项、植物计划行、宠物筛选、Add Event 键盘保存和手动 Calendar CRUD；2026-07-03 已补测普通植物关联 Calendar 事项的通知时间不会被植物护理窗口改写，且普通植物关联事项 / 提醒完成或跳过不写植物护理账本；当前全局日历入口收敛为首页日历 tab，植物页不再提供独立植物日历路由。 | 真机长列表滚动、趋势图 / 账本筛选、已删除 / 已离世 / legacy 样本目检；创建普通植物关联 Calendar 事项并确认详情 / filter / 通知时间都正确；从首页日历 tab 进入，确认“植物”聚合筛选能显示植物事项，且没有从植物详情或 Function Menu 进入日历的替代入口。 | 待真机 |
| 11 | Expenses / Insurance / Documents | 费用、保单、文档、附件隐私清洗、删除级联、人类费用 UI 已测；2026-07-01 已复测 Human expense 添加 / 回读。2026-07-11 补充：普通费用在 user/shared/Human command、备份 preflight 和 rehydrate 边界拒绝 0、负数、NaN、正负无穷；失败后重试、重复失败、合法恢复和保险报销负向事实兼容测试通过。 | 真实相册 / 文件 picker、附件预览、删除后入口消失和手感。 | 待真机 |
| 12 | Privacy / Security | 未来 PIN / 隐私字段命令边界、备份排除和不可写保护已测；首发本地 UI 当前隐藏 Human 隐私 / PIN 控制并保持同设备成员资料可见；2026-07-01 已复测 account switcher 不暴露隐私 / PIN 控制、同设备成员资料仍可见，以及 Human 永久删除取消 / 错误名称保护；batch K 再次复测 account switcher 不暴露隐私 / PIN 控制。 | 真机确认当前首发 Settings / 成员切换不会露出误导性隐私 / PIN 入口，锁屏 / 键盘 / 系统权限相关页面不破版。 | 待真机 |
| 13 | Onboarding / CrewRoster / FunctionMenu | 旧 Pet-first 首启和既有一人一宠 Function Menu 路径有历史证据；CrewRoster 卡片缩回动画已有策略覆盖。当前 Human-first、稍后建宠、Task Center 显式领取与 D28 路径尚待 TFU-20260715-002 本地验收，旧 smoke 不算当前通过。 | 新签名包覆盖立即 / 稍后建宠、Oasis 领取门、D28 前三项、覆盖安装、reset、第二人 / 第二宠、CrewRoster 卡片手感、全功能菜单和危险区视觉。 | 本地前置未关；待真机 |
| 14 | Phase 9 dogfooding / RC | 当前处于 9A；自动和模拟器证据已大幅收敛。 | 真机完成本表后，再跑一次 RC 级全路径冒烟。 | 待 RC |
| 15 | CloudKit live apply policy | 已登记为 TFU-20260614-014 和 CloudKit 1.x 延后项。 | 首发如果 CloudKit 保持关闭，本轮不用测；启用 CloudKit 前另起专项真机 / iCloud 验证。 | 本轮不测 |
| 16 | Today Widget / Live Activity / Dynamic Island | Widget extension、bounded App Group snapshot、Personal gate、typed deep link、walk Activity lifecycle 与能耗节流已由 89 项聚焦测试和 unsigned Simulator app+extension 编译覆盖。 | 注册并签名两个环境对应的 App Group；真机检查 Widget families、锁屏隐私、Free/Personal/降级/过期/reset、冷启动链接，以及完整 walk 的 Lock Screen / Dynamic Island / relaunch / background / end。 | 待签名真机 |
| 17 | Family App 内亲友守护 | V96/outbox、客户端 fail-closed、Family catalog、AWS SAM、17 个后端规则/隐私/安全合同测试与 353 个 iOS 定向测试已通过；这不能证明 APNs 到达。 | 部署生产栈并按本节用两台真机、两个账号验证邀请、权限、第 2/3 日推送、恢复、确认、暂停、撤销、token 失效、权益到期、隐私和删除。 | Family 本轮不发布 / 开放前必测 |

## 第一轮：首发硬门

这一轮优先找会阻塞首发的真实设备问题。

### 1. GAP-7 补记喂食（对应打卡 1）

历史已测过：

- 模拟器 UI 已覆盖从 Feeding History “+”打开补记弹窗。
- 模拟器 UI 已覆盖选择 1 天前和 2 天前日期、保存、历史行回读。
- 单元测试已覆盖所选历史日期会写入照护历史和 CareLedger 发生时间。
- 2026-07-01 broad GUI 批次 F 再次覆盖 Feeding History “+” 手动补记、1 天 / 2 天历史日期保存和回读。

真机还要测：

- 进入宠物 Feeding / Food Log。
- 在 History 区域点 “+” 或补记入口。
- 手动选择一个历史日期，保存一条手动喂食记录。
- 再选择另一个历史日期，保存第二条记录。
- 回到历史列表确认两条记录分别显示在对应历史日期。
- 看奖励反馈：补记事实落在历史日期，但奖励 / 冷却按当前操作日口径处理。

通过标准：

- 系统日期控件能手动选择，不遮挡保存按钮。
- 两条历史记录都能回读，日期正确。
- 不出现卡死、重复写入、历史日期丢失或奖励口径明显错误。

记录：

- 设备 / iOS：
- 构建：
- 结果：待真机。
- 预检证据：2026-07-01 broad GUI 批次 F 合跑 9 条用例，`testFeedingManualHistoryAddOpensBackdateLogSheetAndRecords` 通过；整批 `Executed 9 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-f/Logs/Test/Test-Ohana-2026.07.01_03-21-43-+0200.xcresult`。
- 问题：

### 2. 启动、首启和 Settings（对应打卡 13）

已测过：

- Pet-first 首启 -> 创建首宠 -> 第一笔照护 -> starter gift -> Home Oasis -> Settings 曾有真机 smoke；该路线已被 D17 当前流程替代，只保留历史证据。
- 一人一宠进入 Function Menu 的模拟器预检已通过。
- 2026-06-30 模拟器 GUI 批次已覆盖 Home FAB -> More -> Function Menu -> Coconut Shop，Lime Glow 购买确认弹窗、确认后人类余额从 1000🥥 到 700🥥、购买反馈显示。
- 2026-07-01 broad GUI 批次已再次覆盖首启创建 Human / Pet、starter gift、Oasis Lv1、Home FAB -> More -> Function Menu，且未出现单人家庭缺员文案。
- 2026-07-01 已修复 CrewRoster 成员页钱包卡片放大 / 缩小动画层级：缩回过程中选中卡片保持前景，只在接近完全收回时交还原卡堆层级，避免缩小时被其他卡片遮住或跳层。

真机还要测：

- 覆盖安装或重新 build 后不卸载 App，确认不会白屏或卡在启动图。
- App reset 后重新首启，只输入 Human 名字；分别完成“立即建宠”和“稍后建宠”。
- 立即建宠只要求名字、物种和品种；Pet 保存后待办出现 50 椰子领取项，Oasis
  在明确领取成功前始终隐藏，失败可重试且重复点击不重复入账。
- 稍后建宠后首页立即显示 Human 卡片，待办保留建宠系统事项；取消建宠不丢事项，
  保存首宠后同一旅程切换为领取事项。
- 领取后检查 D28 新手成长计划最多显示三个未领取事项；资料明确选择与填写等价，
  默认计划不自动冒充完成，真实照护之外的体重/健康记录不冒充首次照护。
- 打开 Settings，页面应立即可用，不停在 opening shell。
- 确认没有 Ohana 账号、Apple/Google 登录或登录提示，也不会出现系统登录授权页；
  Human 只来自用户输入的姓名，性别和生日可保持未设置，App 不读取 Apple 账号资料。
- 启用 iCloud Drive 自动备份、退出并重开 App，确认备份状态恢复且从未要求 App 登录；
  断网/iCloud 不可用时本地照护继续可用，备份失败可见并可重试。
- App Reset 后确认本机数据删除，并按 R6 验证 app-managed iCloud Drive 备份清理的
  成功、失败、重试和重复操作；不存在远程 Ohana 账号删除步骤。
- 创建第二个人类和第二只宠物后回首页，卡片和账户选择应正常。
- CrewRoster 连续点击成员卡片，确认放大 / 缩小动画顺滑，缩小时不被其他卡片盖住、不跳层、不闪烁。
- CrewRoster 和 FunctionMenu 扫描一遍，确认只出现首发可达功能。

通过标准：

- 没有白屏、卡死、长时间不可点击、卡片消失或必须切 tab 才恢复。
- 联机、CloudKit、植物未解锁入口仍被门禁收起。
- 当前产品不存在登录门槛或账号同步声明；新装必须有一个本地 Human，但无需网络或
  App 账号即可建 Pet、照护、备份和恢复。legacy 无 Human 数据不应被强制重做首启；
  iCloud Drive 错误可见且可重试。
- 详情入口、删除入口、标记离世入口的视觉和文案一致。

记录：

- 设备 / iOS：
- 构建：
- 结果：旧 Pet-first 真机 smoke 与 2026-06-30/07-01 Function Menu 证据保留为历史；当前 Human-first/D28 本地前置和新签名真机路径均待完成。
- 预检证据：2026-06-30 5 条 GUI 用例合跑 `Executed 5 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-1782917200/Logs/Test/Test-Ohana-2026.06.30_23-51-17-+0200.xcresult`；2026-07-01 7 条 GUI 用例合跑 `Executed 7 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-a/Logs/Test/Test-Ohana-2026.07.01_00-39-04-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 K 合跑 `testFirstReleaseReachableHomeOasisAndSettingsSmoke` 和 `testSingleHumanPetHomeAndFunctionMenuFeelComplete`，覆盖首启 Human / Pet、starter gift、Oasis、Settings、Home 卡片快捷操作、Home FAB -> More -> Function Menu；整批 9 条 GUI 用例 `Executed 9 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-k/Logs/Test/Test-Ohana-2026.07.01_08-23-54-+0200.xcresult`。
- 预检证据：2026-07-01 CrewRoster 卡片动画层级根因修复：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-wallet-motion-policy-20260701 scripts/test-simulator.sh '-only-testing:OhanaTests/WalletHeroMotionPolicyTests'`，`iPhone 17` simulator，2 条策略单测通过，xcresult `/tmp/OhanaDerivedData-wallet-motion-policy-20260701/Logs/Test/Test-Ohana-2026.07.01_10-47-50-+0200.xcresult`。
- 问题：真机仍要确认 CrewRoster 卡片放大 / 缩小手感；如果缩小时仍被后排卡片遮挡、跳层或闪烁，按失败记录让我继续修。

### 3. 通知和纪念模式（对应打卡 2、3、9）

已测过：

- 通知调度、预算、夜间延后、合并、关键用药豁免和通知 action 业务边界已测。
- 2026-07-03 模拟器单测已覆盖：关联植物的普通 Calendar 事项设为 23:30 时，仍按 23:30 通知；只有系统生成的植物护理计划才走植物提醒偏好窗口。
- 2026-07-03 模拟器单测已覆盖：普通植物关联 Reminder 完成 / 跳过只改变提醒状态并写 reminder ledger，不会写 `PlantCareLog`、植物 last-care 日期或 plant-care ledger；系统生成植物计划的跳过仍会写计划反馈并重排下一次任务。
- 离世对象活跃入口过滤、冻结钱包、未来计划清理和纪念历史只读边界已测。
- 2026-07-01 broad GUI 批次已复测 Settings Debug -> Reminder Observability 面板可达和 ledger 卡片存在。
- 2026-07-01 broad GUI 批次 D 已复测 Human 纪念标记取消 / 确认、撤销取消 / 确认，取消不会写入离世状态，确认后可回读和撤销。
- 2026-07-01 broad GUI 批次 E 已复测宠物纪念后重启：Home 不显示喂食 / 喝水等活跃照护快捷入口，Home FAB -> Function Menu -> daily care 不把纪念宠物作为活跃目标；纪念宠物旧 Calendar 水提醒不会打开 Quick Water、Health、Walk 或 Bond Vault 等活跃页面。
- 2026-07-01 broad GUI 批次 F 已复测 Dog 纪念标记 / 撤销的取消 / 确认路径，并复测 Dog Basic Info、遛狗、永久删除安全保护和 Human 永久删除取消 / 错误名称保护。
- 2026-07-01 broad GUI 批次 I 再次复测 Human 和 Pet 纪念标记 / 撤销的取消 / 确认路径，整批 16 条真实用户 GUI 路径通过。
- 2026-07-01 broad GUI 批次 L 再次复测 Reminder Observability 面板可达。

真机还要测：

- 首次请求通知权限，确认文案和授权后状态。
- 创建普通提醒、宠物用药、人类用药、健康关键提醒。
- 创建一个关联植物的普通 Calendar 事项，时间设为当前时间后 3-5 分钟，确认通知按选择时间到达，不被植物护理提醒窗口延后到早晨。
- 在锁屏、前台、后台、Focus/DND 场景下观察通知是否合理出现。
- 点击通知正文进入正确 typed route。
- 点完成 / 跳过 / 稍后提醒，不应重复写账或跳到错误成员。
- 对普通植物关联提醒点完成 / 跳过后，确认它不会新增植物护理历史；对系统生成植物计划点跳过后，确认只生成“跳过 / 延后反馈”。
- 标记宠物或人类离世后，未来通知应取消或不再跳回活跃照护入口。
- 撤销离世后，确认应该恢复的提醒或入口恢复，且历史资料仍可读。

通过标准：

- 真机通知能到达，点击和 action 能回到正确对象。
- 健康关键提醒不被普通预算或夜间策略错误吞掉。
- 离世对象不再有活跃照护写入入口，不会收到会跳回活跃对象的旧通知。

记录：

- 设备 / iOS：
- 构建：
- 结果：原始真机结果失败；2026-06-30 已做模拟器 GUI 复测并修复，当前待真机二次确认。
- 问题：添加事件后，点击标题输入框，会弹出一个大页面把所有内容都盖住。凡事弹出键盘的时候，app画面都会被覆盖。我在九点27分创建了一个九点30分的事件，并没有通知我，在我九点31分打开日历看的时候，已经显示逾期。
- Codex 处理记录（2026-06-30）：
  - 键盘遮挡根因：根层 `OhanaApp` / `RootView` / `ContentView` 全局忽略 keyboard safe area，导致 Add Event 这种内联全屏编辑页在键盘出现时不让系统重新避让。
  - 通知未到达根因：Add Event 默认选择“前30分钟”；21:27 创建 21:30 事件时，实际提醒时间被算成 21:00，进入调度时已过期，因此不会注册系统通知。
  - 修复：移除根层全局 keyboard safe-area 忽略；Add Event 新增“准时 / At time”提醒选项并设为默认，同时保留前30分钟、前1小时等旧选项。
  - 模拟器复测：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-calendar-keyboard-1782910800 scripts/test-simulator.sh '-only-testing:OhanaTests/HomeCommandExecutorTests/calendarEventPlanServiceCreatesAtTimeReminderForNearFutureEvents()' '-only-testing:OhanaUITests/OhanaUITests/testCalendarAddEventKeyboardKeepsEditorControlsVisible'`，`iPhone 17` simulator，结果 `** TEST SUCCEEDED **`，xcresult `/tmp/OhanaDerivedData-calendar-keyboard-1782910800/Logs/Test/Test-Ohana-2026.06.30_21-39-00-+0200.xcresult`。
  - 2026-07-01 入口复测：Reminder Observability 随 broad GUI 批次通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-a/Logs/Test/Test-Ohana-2026.07.01_00-39-04-+0200.xcresult`。
  - 2026-07-01 键盘复测：Add Event 键盘保持保存按钮可见随 broad GUI 批次 B 复测通过；该批次初跑 10 条用例中 9 条通过，唯一失败是测试脚本误滑掉 Human Note 弹窗，修正脚本后单条复跑通过。初跑 xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-b/Logs/Test/Test-Ohana-2026.07.01_00-57-31-+0200.xcresult`；复跑 xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-b/Logs/Test/Test-Ohana-2026.07.01_01-25-41-+0200.xcresult`。
  - 2026-07-01 Human 纪念流程复测：`testHumanMemorialMarkCancelConfirmAndUndoFlow` 随 broad GUI 批次 D 通过；该批次 10 条 GUI 用例合跑 `Executed 10 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-d/Logs/Test/Test-Ohana-2026.07.01_02-46-35-+0200.xcresult`。
  - 2026-07-01 宠物纪念 / 删除 stale Calendar 复测：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-e scripts/test-simulator.sh ...`，`iPhone 17` simulator，12 条 GUI 用例合跑 `Executed 12 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-e/Logs/Test/Test-Ohana-2026.07.01_03-00-54-+0200.xcresult`。
  - 2026-07-01 broad GUI 批次 I 复测 Human / Pet 纪念取消、确认、撤销路径，整批 `Executed 16 tests, with 0 failures`；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-i/Logs/Test/Test-Ohana-2026.07.01_06-05-25-+0200.xcresult`。
  - 2026-07-01 Dog / Human 删除安全复测：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-f scripts/test-simulator.sh ...`，`iPhone 17` simulator，9 条 GUI 用例合跑 `Executed 9 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-f/Logs/Test/Test-Ohana-2026.07.01_03-21-43-+0200.xcresult`。
  - 2026-07-01 Observability 复测：`testReminderObservabilityPanelOpensFromDebugSettings` 随 broad GUI 批次 L 通过；整批 `Executed 12 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-l/Logs/Test/Test-Ohana-2026.07.01_08-44-15-+0200.xcresult`。
  - 仍需真机复测：打开添加事件页后点击标题输入框，确认键盘不会盖住保存按钮；创建当前时间 3-5 分钟后的普通事件并保持通知权限允许，确认系统通知能按时到达。

### 4. 隐私、安全和文件附件（对应打卡 11、12）

已测过：

- 未来 PIN / 隐私字段命令边界、失败锁定、备份排除和不可写保护已测。
- 当前首发本地 UI 策略已测：Human 隐私 / PIN 控制隐藏，同设备成员切换只改变打卡归属，不隐藏本机成员资料。
- 图片附件、相册图片和 quick moment 图片入库前隐私清洗已测。
- 费用、保单、文档附件创建、删除级联和账本边界已测。
- 2026-07-01 broad GUI 批次 F 已复测 Human 永久删除危险区：未输入精确名称不能删除，错误名称不会删除，取消后成员仍保留。

真机还要测：

- 打开 Settings 和成员相关页面，确认当前首发不会露出 Human 隐私 / PIN 设置入口。
- 切换同设备成员，确认这只是打卡 / 操作者归属切换，不出现“本机成员资料应该被锁住”的误导性文案。
- 在票据、保单或文档附件入口调用真实相册 / 文件 picker，确认系统权限和选择器可用。
- 添加票据、保单或文档附件，预览后删除，确认普通入口消失。
- 相册大图 viewer 和批量照片样本放到第二轮“照片、周报、纪念历史和植物历史”里测。
- 测试键盘、Face ID / Touch ID 或系统锁屏相关交互是否破版。

通过标准：

- 首发本地 UI 不出现误导性的 Human 隐私 / PIN 控制；同设备成员资料可见的策略和文案一致。
- 真实照片和文件 picker 可用，预览不卡死。
- 删除后没有恢复、回收站或 30 天中转态入口。

记录：

- 设备 / iOS：
- 构建：
- 结果：2026-07-01 broad GUI 批次 B 已复测 Settings account switcher 不暴露 Human 隐私 / PIN 控制、同设备成员切换后资料仍可见，并复测 Human expense 添加 / 回读；batch F 已复测 Human 永久删除取消 / 错误名称保护；真实相册 / 文件 picker、附件预览、锁屏 / 权限相关页面仍待真机。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-b scripts/test-simulator.sh ... '-only-testing:OhanaUITests/OhanaUITests/testHumanSettingsAccountSwitcherHidesLocalPrivacyControls' '-only-testing:OhanaUITests/OhanaUITests/testHumanProfileStaysVisibleWhenViewedByOtherLocalMember' '-only-testing:OhanaUITests/OhanaUITests/testHumanRecordOperationsPersistFromFeatureHub' ...`，`iPhone 17` simulator；初跑 10 条中 9 条通过，唯一失败为测试脚本误滑掉 Human Note 弹窗；修正脚本后 `testHumanRecordOperationsPersistFromFeatureHub` 单条复跑 `Executed 1 test, with 0 failures`。
- 预检证据：2026-07-01 broad GUI 批次 F 中 `testHumanPermanentDeleteCancelAndWrongNameAreSafe` 通过；整批 `Executed 9 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-f/Logs/Test/Test-Ohana-2026.07.01_03-21-43-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 K 再次复测 `testHumanSettingsAccountSwitcherHidesLocalPrivacyControls`，Settings Human account switcher 可打开 / 关闭，未暴露 Human 隐私 / PIN 控制；同批 `Executed 9 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-k/Logs/Test/Test-Ohana-2026.07.01_08-23-54-+0200.xcresult`。
- 问题：

## 第二轮：模块视觉和手感签收

这一轮主要确认真实使用体验：滚动、点击、长文案、真实数据、跨页回读和低性能手感。

### 5. 宠物照护、猫砂、护理和 Moments（对应打卡 6）

已测过：

- 快捷照护、Water、Feeding、Potty / litter、Hygiene、Health、Play、quick moment、奖励、账本、重复保护已有模拟器和业务层覆盖。
- 2026-06-30 模拟器 GUI 批次已覆盖 Feeding 手动方案保存、Home 快捷喂食、重复喂食确认、进入 Feeding 详情回读。
- 2026-06-30 模拟器 GUI 批次已覆盖开始遛狗、Home 大遛狗卡片右上角最小化、最小化后只显示全局圆形悬浮窗、大卡和悬浮窗不同时出现、再点 Home 遛狗快捷操作会翻回当前遛狗卡片而不是重新开始。
- 2026-07-01 broad GUI 批次已覆盖从展开宠物卡进入全部功能，并逐项打开 / 返回 potty、hygiene、walk、health 路由。
- 2026-07-01 broad GUI 批次 D 已覆盖 Pet Basic Info 空名称保存保护、Pet Health 记录取消 / 保存 / 回读、Pet Hygiene 记录保存 / 当天重复打卡拦截。
- 2026-07-01 broad GUI 批次 E 已覆盖 Potty 完美便便记录写入 / 回读，猫砂计划和铲屎计划保存后 Calendar 出现、删除后 Calendar 消失，Bond Vault 零余额解锁拦截、种子余额解锁支出、水打卡奖励进入 Bond Vault 最近账本，永久删除取消 / 错误名称保护和正确名称删除 smoke，删除宠物旧 Calendar 行清理，以及纪念宠物活跃入口过滤。
- 2026-07-01 broad GUI 批次 F 已覆盖 existing-pet 不重置 / 重启回读、Cat 长链路 feed / water / litter / hygiene / health / Calendar / Bond Vault、Dog 遛狗开始停止和 summary 回读、Dog Basic Info 编辑取消 / 保存、Dog 纪念标记 / 撤销取消确认、Dog 永久删除安全保护、Feeding 补记、litter scoop / full-change / plan 取消保存。
- 2026-07-01 已修复首页展开宠物卡内部快捷操作延迟首显：展开卡挂载时立即从已准备 snapshot 生成快捷操作，后续刷新仍延迟到下一帧；新增 `testPetExpandedCardShowsQuickActionsWithoutSecondTap` 防回归。
- 2026-07-01 已修复首页展开卡在快捷操作加载前无法点击卡片缩小：展开卡的收起命中层现在立即挂载，只有快捷操作真正可见后才保护底部快捷操作区；新增 `VerticalHomeTabMountPolicyTests` 策略断言防止收起能力再次被 quick-action thaw 阶段阻塞。
- 2026-07-01 broad GUI 批次 H 又修复并复测首页展开卡上的底部 FAB 菜单遮挡：展开卡时底部快捷菜单会恢复，且菜单列上移，不再挡住卡片内部快捷操作。
- 2026-07-01 broad GUI 批次 I 又复测 Feeding 手动计划 + Home 快捷喂食、Pet Feature Hub 日常 / 健康入口、Potty 写入、Hygiene 重复保护、Health 取消 / 保存、Basic Info 空名称保护、Walk 开始 / 停止 / summary 回读，以及 Pet 纪念取消 / 确认 / 撤销。
- 2026-07-01 broad GUI 批次 L 又复测 Water 奖励进入 Bond Vault ledger、水计划 Calendar 保存 / 删除、Bond Vault 余额不足拦截和解锁支出、Coconut Shop 购买、Pet Basic Info 编辑取消 / 保存。

真机还要测：

- 对同一只宠物连续执行喂食、喝水、猫砂或排泄、护理、玩耍、quick moment。
- 立即查看 Task Center、历史记录、账本和奖励反馈是否一致。
- 重复点击同一操作，确认不会重复奖励或卡死。
- 已故宠物路径只读或 no-op，不出现活跃照护写入。
- 首页卡片放大后的内部快捷操作要在真机上观察是否立即出现；在快捷操作出现前快速再次点击卡片应能缩小，连续点击应能来回放大 / 缩小；底部“全部功能”属于主按钮 FAB 菜单，预期会随展开状态恢复，但不应挡住卡内快捷操作。

通过标准：

- 反馈及时，历史和账本能解释刚才的操作。
- 没有重复奖励、按钮闪烁卡死、路由跳错或已故对象可写入。

记录：

- 设备 / iOS：
- 构建：
- 结果：2026-06-30 和 2026-07-01 模拟器 GUI 预检通过，真机待你手感签收。
- 预检证据：2026-06-30 5 条 GUI 用例合跑 `Executed 5 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-1782917200/Logs/Test/Test-Ohana-2026.06.30_23-51-17-+0200.xcresult`；2026-07-01 7 条 GUI 用例合跑 `Executed 7 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-a/Logs/Test/Test-Ohana-2026.07.01_00-39-04-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 D 合跑 `testPetBasicInfoEmptyNameSaveKeepsOriginalName`、`testPetHealthRecordCancelAndSavePersistsFromFeatureHub`、`testPetHygieneRecordPersistsAndRepeatTapIsBlocked` 等宠物路径，整批 10 条 GUI 用例 `Executed 10 tests, with 0 failures`；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-d/Logs/Test/Test-Ohana-2026.07.01_02-46-35-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 E 合跑 12 条宠物 / Calendar / Bond Vault / 删除 / 纪念路径，`Executed 12 tests, with 0 failures`；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-e/Logs/Test/Test-Ohana-2026.07.01_03-00-54-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 F 合跑 9 条 existing-pet / Cat-Dog 长链路 / Feeding backdate / litter / walk / Human 删除安全用例，`Executed 9 tests, with 0 failures`；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-f/Logs/Test/Test-Ohana-2026.07.01_03-21-43-+0200.xcresult`。
- 预检证据：2026-07-01 首页展开卡内部快捷操作延迟修复回归用例 `testPetExpandedCardShowsQuickActionsWithoutSecondTap` 通过，`Executed 1 test, with 0 failures`；xcresult `/tmp/OhanaDerivedData-home-quick-reveal-20260701/Logs/Test/Test-Ohana-2026.07.01_03-49-45-+0200.xcresult`。
- 预检证据：2026-07-01 首页展开卡立即收起根因修复：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-home-collapse-hit-20260701 scripts/test-simulator.sh '-only-testing:OhanaTests/VerticalHomeTabMountPolicyTests'`，`iPhone 17` simulator，32 条策略单测通过，xcresult `/tmp/OhanaDerivedData-home-collapse-hit-20260701/Logs/Test/Test-Ohana-2026.07.01_10-40-29-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 H 初跑 15 条中 12 条通过；修复底部 FAB 菜单遮挡后，`testHumanExtendedModuleDeletesDisappearFromFeatureHub` 单条复测 `Executed 1 test, with 0 failures`；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-h-rerun/Logs/Test/Test-Ohana-2026.07.01_05-14-00-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 I 合跑 16 条 Feeding / Pet Feature Hub / Potty / Hygiene / Health / Basic Info / Memorial / Walk / Calendar 路径，`Executed 16 tests, with 0 failures`；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-i/Logs/Test/Test-Ohana-2026.07.01_06-05-25-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 K 合跑 `testPetFeatureHubDailyAndHealthRoutesOpenAndCancel` 和 `testPetWalkQuickActionPersistsAndSummaryReadback`，覆盖 Pet Feature Hub potty / hygiene / walk / health 入口打开和关闭、Dog Home 遛狗快捷操作开始 / 停止、summary 距离值、Feature Hub walk 回读；整批 9 条 GUI 用例通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-k/Logs/Test/Test-Ohana-2026.07.01_08-23-54-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 L 合跑 `testPetWaterCareRewardAppearsInBondVaultLedger`、`testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail`、`testPetBondVaultInsufficientBalanceBlocksUnlockFromFeatureHub`、`testPetBondVaultUnlockSpendsPetBalanceFromFeatureHub`、`testPetCoconutShopEffectPurchaseSpendsHumanBalanceFromFunctionMenu` 和 `testPetBasicInfoEditCancelDoesNotPersistAndSaveDoes`；整批 12 条 GUI 用例通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-l/Logs/Test/Test-Ohana-2026.07.01_08-44-15-+0200.xcresult`。
- 问题：真机仍要确认展开动画、快捷操作出现时机、以及快速连续点击放大 / 缩小是否顺手；如果内部快捷操作仍需二次点卡片才出现，或快捷操作出现前点击卡片不能缩小，按失败记录让我修。

### 6. 人类健康、笔记、锻炼和用药（对应打卡 8、9）

已测过：

- HumanHealth / HumanNotes / Workouts 的添加、回读、删除后消失已测；当前首发本地查看者策略为同设备成员资料可见。
- HealthKit 页面已改为直接展示可读的活动摘要与 `HKWorkout`；不再要求二次导入，
  HealthKit / PetWalk 行只读，只有 Ohana 手动运动记录可删。每个活动环独立根据真实目标
  显示，并支持活动能量与 Apple Move Time 两种 Move 模式。相关 Unit / 源码契约测试
  通过 10/10，但真实 HealthKit 读取仍需下方真机签收。
- Human medication 添加和回读 UI 已测。
- 2026-07-01 broad GUI 批次已复测 Human Feature Hub 多个模块入口：weight、body metrics、workout、health report、medication、basic info、expense、wishlist、notes、profile，并复测 Home 人类快捷操作 weight / expense / medication sheet 打开和关闭。
- 2026-07-01 broad GUI 批次 B 已复测 Human weight / expense / medication / note 持久化、扩展模块 TSH / workout / health report / wishlist / profile 写入、health metric / workout / health report / human note 删除后消失、同设备成员资料可见策略。
- 2026-07-01 broad GUI 批次 H 修复并复测 Human note 保存后历史刷新和删除标识；同时复测 Human extended 删除路径，workout / health report / note 删除后都能消失。
- 2026-07-01 broad GUI 批次 L 再次复测 Human record persistence 和 Human wishlist redeem。

真机还要测：

- 添加健康指标、健康报告、笔记、锻炼和人类用药。
- 删除上述记录，确认普通入口不再显示。
- 在已签名新构建中授予步数、距离、活动能量、锻炼时间、站立时间、活动摘要和
  运动记录读取权限；确认真实 Exercise / Stand 值、活动能量或 Move Time 目标及每个
  可用圆环都正确。单个目标缺失时，其他圆环仍必须显示真实进度。
- 确认 Recent Workouts 直接显示 Apple Health 和 Ohana 遛狗来源，不出现导入或删除按钮；
  与遛狗重合的记录只显示一行，覆盖安装后不产生新的本地副本或重复行。
- 重启 App，然后分别拒绝一个类型与撤销 HealthKit 权限；确认页面不把“已发起授权”
  误报为“已确认可读”，不可读的单项如实显示为无数据，其他允许项继续显示。
- 切换同设备查看者 / 操作者，确认归属文案和可见策略一致，不出现“本机资料应被锁住”的误导。
- 用长文案、长备注和键盘输入检查是否遮挡或溢出。

通过标准：

- 添加、回读、删除都稳定。
- HealthKit 值和每个可用目标圆环与 Apple Health 一致；Recent Workouts 是只读直接展示，
  没有二次导入、不可删除外部事实，且重启、单项拒绝和撤权时状态诚实可恢复。
- 键盘不遮挡关键按钮，长文案不破版。
- 同设备查看者策略和当前首发说明一致，不出现过期的隐私锁提示或误导。

记录：

- 设备 / iOS：
- 构建：
- 结果：2026-07-01 Human Feature Hub / Home 人类快捷操作模拟器 GUI 预检通过。2026-07-11
  真机旧签名构建已确认 HealthKit 授权和大部分数值，但 Exercise、Stand 和活动环失败，且
  旧导入交互不清晰。本地已完成上述直读修复并通过 10/10 定向测试；新签名构建的
  HealthKit 实数据、重启、拒绝和撤权复测，以及真机键盘、长文案和手感仍待测。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-a scripts/test-simulator.sh ... '-only-testing:OhanaUITests/OhanaUITests/testHumanFeatureHubRoutesOpenFromHome' '-only-testing:OhanaUITests/OhanaUITests/testHumanHomeQuickActionsOpenExpectedSheets' ...`，`iPhone 17` simulator，7 条 GUI 用例合跑 `Executed 7 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-a/Logs/Test/Test-Ohana-2026.07.01_00-39-04-+0200.xcresult`。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-b scripts/test-simulator.sh ...`，`iPhone 17` simulator，初跑 10 条中 9 条通过；唯一失败定位为 UI 测试脚本 `dismissKeyboardIfPresent` 的全局 swipe 误关 Human Note 弹窗。修正后单独复跑 `testHumanRecordOperationsPersistFromFeatureHub`，结果 `Executed 1 test, with 0 failures`；初跑 xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-b/Logs/Test/Test-Ohana-2026.07.01_00-57-31-+0200.xcresult`，复跑 xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-b/Logs/Test/Test-Ohana-2026.07.01_01-25-41-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 H 初跑 15 条中 12 条通过；修复后 `testHumanRecordOperationsPersistFromFeatureHub` 在复跑中通过，`testHumanExtendedModuleDeletesDisappearFromFeatureHub` 单条复测通过；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-h-rerun/Logs/Test/Test-Ohana-2026.07.01_04-52-30-+0200.xcresult` 和 `/tmp/OhanaDerivedData-gui-broad-20260701-h-rerun/Logs/Test/Test-Ohana-2026.07.01_05-14-00-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 K 中 `testHumanExtendedModuleOperationsPersistFromFeatureHub` 通过，覆盖 Human Feature Hub 内 body metric / workout / health report / wishlist / basic info notes 写入保存和回到首页 / 再进功能中心回读；整批 9 条 GUI 用例通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-k/Logs/Test/Test-Ohana-2026.07.01_08-23-54-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 L 中 `testHumanRecordOperationsPersistFromFeatureHub` 和 `testHumanWishlistRedeemSpendsCoconutsFromFeatureHub` 通过；整批 12 条 GUI 用例通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-l/Logs/Test/Test-Ohana-2026.07.01_08-44-15-+0200.xcresult`。
- 问题：

### 7. 日历、Dashboard 和 CareLedger（对应打卡 10）

已测过：

- 日历创建 / 完成 / 删除、筛选、宠物深链、水计划读回、密集快照和 CareLedger backfill 已测。
- 2026-06-30 模拟器 GUI 批次已覆盖用户手动添加的日历事项：点击行打开详情、点编辑、修改标题保存、再次打开详情、删除并确认列表消失。
- 2026-06-30 模拟器 GUI 批次已覆盖系统生成的喂食计划日历事项：保存 Feeding 手动提醒计划后，Calendar 里点击“早餐 干粮 50g”一类系统事项会进入 Quick Feed，而不是打开普通事项编辑。
- 2026-07-01 模拟器 GUI 复测已覆盖：无关联用户事项详情 / 编辑 / 删除、宠物关联用户事项仍打开事项详情、标题含 water 的宠物关联用户事项不误跳水计划页、系统生成喂食事项点击后进入 Quick Feed。
- 2026-07-01 最新策略复核已覆盖：标题含 Feed 的直连宠物用户事项、普通直连植物事项不会误跳系统页；真正生成的手动喂食计划、饮水计划和带“植物计划”标记的植物计划才走相关详情页 / 打卡页。
- 2026-07-01 最新 GUI 复测再次覆盖：用户手动事项点击后能查看详情、编辑、保存、再打开并删除；标题含 water 的宠物关联用户事项仍打开可编辑详情；系统生成喂食计划点击后进入 Quick Feed。
- 2026-07-01 代码 / 单测复核已覆盖：Function Menu 内打开 Calendar 后，系统生成人类用药、运动、笔记事项也会映射到对应人类详情页，不再静默留在日历行。
- 2026-07-01 broad GUI 批次 B 已复测 Add Event 键盘保存按钮可见、宠物筛选只显示宠物关联事项、水计划 Calendar event 保存和删除后消失。
- 2026-07-01 broad GUI 批次 D 已复测宠物关联的用户手动事项，即使标题像 potty、walk、play、weight、health、hygiene，也打开事项详情 / 编辑入口，不误跳到对应打卡页。
- 2026-07-01 broad GUI 批次 E 已复测系统生成的猫砂计划和铲屎计划 Calendar 行：保存计划后 Calendar 能看到对应事项，删除计划后事项从 Calendar 消失；已删除宠物的旧 Calendar 事项会被清理，已离世宠物旧 Calendar 事项不会打开活跃照护 / 健康 / 遛狗 / 经济页面。
- 2026-07-01 broad GUI 批次 F 在 existing-pet / Cat 长链路中再次复测宠物关联用户事项创建、Calendar 宠物筛选和长会话回读。
- 2026-07-01 broad GUI 批次 H 再次复测 Add Event 键盘保存控件可见、宠物 Calendar 筛选、水计划 Calendar 保存 / 删除。
- 2026-07-01 broad GUI 批次 I 又复测宠物关联用户事项：普通标题以及 potty / walk / play / weight / health / hygiene 标题都打开事项详情 / 编辑入口，不误跳到打卡页；同批还复测系统 Feeding 手动计划 + Home 快捷喂食。
- 2026-07-01 broad GUI 批次 J 修正并复跑植物 Calendar 查找：打开 Calendar 后选择全部 / 列表，并按 `calendar-event-row-*` 滚动找到新建植物生成的植物计划行。
- 2026-07-01 broad GUI 批次 K 再次复测 Add Event 键盘保存、用户手动事项详情 / 编辑 / 删除，以及植物计划 Calendar 长链路。
- 2026-07-01 最新日历干净合跑再次复测：6 条策略单测通过，用户手动事项点击后能查看详情、编辑、保存、再打开并删除；系统生成喂食计划点击后进入 Quick Feed。
- 2026-07-03 最新通知策略单测已覆盖：普通植物关联 Calendar 事项保留用户选定通知时间；生成的植物护理计划仍走植物提醒窗口，避免把手动 Calendar 事项误当成植物护理提醒。
- 2026-07-03 最新植物联动单测已覆盖：普通植物关联 Calendar 事项 / Reminder 的完成或跳过不会误写植物护理日志、last-care 日期或 plant-care ledger；系统生成植物计划的 Calendar / Reminder 完成和跳过仍写正确护理事实或计划反馈。
- 2026-07-03 最新植物创建联动单测已覆盖：`PlantCreationCommandExecutor` 添加植物后会直接生成植物计划 Calendar Event 和 Reminder 行，避免“保存成功但日历 / 提醒未同步”的回归。
- 2026-07-03 后续产品口径已改为移除植物详情 -> 护理日历和 Function Menu -> Plant Calendar 入口；全局日历只保留首页日历 tab，植物事项通过“植物”聚合筛选查看。

真机还要测：

- 用长列表数据打开 Calendar，切换全部 / 宠物 / 人类筛选。
- 点日历行进入对应详情，再返回。
- 添加一个普通用户日历事项，确认点击后能查看详情、编辑并删除；再创建标题像“喂食 / 喝水 / walk / health”的普通事项，确认仍进入事项详情而不是打卡页。
- 添加一个关联植物的普通用户日历事项，确认植物 filter 能筛到它，点击仍进事项详情，通知按用户选的时间到达。
- 从首页日历 tab 进入 Calendar，确认“植物”聚合筛选能显示植物相关事项；确认植物详情页和 Function Menu 植物分组不再出现日历入口。
- 完成 / 跳过一个普通植物关联提醒，确认只改变提醒状态；完成 / 跳过系统生成植物计划，确认进入对应植物护理事实或跳过反馈。
- 从首页日历 tab 点系统生成的人类用药 / 运动 / 笔记事项，确认进入对应详情页或打卡页。
- 对真实系统生成事项，比如喂食、猫砂、铲屎、水计划或植物计划，确认点击后进入对应详情页 / 打卡页，删除相关计划后 Calendar 不再残留旧行。
- 打开 DashboardRecords 和 CareLedger，切换时间、类型和对象筛选。
- 检查已删除、已离世、legacy 样本不会以活跃对象混入。

通过标准：

- 首屏不空白，滚动稳定。
- 筛选和深链进入正确对象。
- 账本、趋势和照护事实能互相解释。

记录：

- 设备 / iOS：
- 构建：
- 结果：2026-07-01 日历事项点击行为模拟器 GUI 复测通过，真机长列表和手感待测。
- 预检证据：`iPhone 17` simulator 4 条日历 GUI 合跑通过：`testManualCalendarEventRowOpensDetailEditsAndDeletes`、`testPetLinkedManualCalendarEventRowOpensEventDetail`、`testPetLinkedManualWaterTitleCalendarEventRowOpensEventDetail`、`testSystemGeneratedPetCalendarFeedEventRowOpensQuickFeedDetail`；xcresult `/tmp/OhanaDerivedData-calendar-interaction-1782858424/Logs/Test/Test-Ohana-2026.07.01_00-32-19-+0200.xcresult`。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-calendar-policy-20260701 scripts/test-simulator.sh '-only-testing:OhanaTests/CalendarEventInteractionPolicyTests'`，`iPhone 17` simulator，5 条策略单测通过；xcresult `/tmp/OhanaDerivedData-calendar-policy-20260701/Logs/Test/Test-Ohana-2026.07.01_04-10-00-+0200.xcresult`。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-calendar-policy-20260701 scripts/test-simulator.sh '-only-testing:OhanaUITests/OhanaUITests/testManualCalendarEventRowOpensDetailEditsAndDeletes' '-only-testing:OhanaUITests/OhanaUITests/testPetLinkedManualWaterTitleCalendarEventRowOpensEventDetail' '-only-testing:OhanaUITests/OhanaUITests/testSystemGeneratedPetCalendarFeedEventRowOpensQuickFeedDetail'`，`iPhone 17` simulator，3 条 GUI 用例通过；xcresult `/tmp/OhanaDerivedData-calendar-policy-20260701/Logs/Test/Test-Ohana-2026.07.01_04-12-07-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 G 中 `testManualCalendarEventRowOpensDetailEditsAndDeletes` 再次通过；整批 11 条 GUI 用例 `Executed 11 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-g/Logs/Test/Test-Ohana-2026.07.01_03-53-06-+0200.xcresult`。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-calendar-fm-1782861586 scripts/test-simulator.sh '-only-testing:OhanaTests/CalendarEventInteractionPolicyTests'`，`iPhone 17` simulator，3 条策略单测通过并完成 Function Menu 路由补丁编译；xcresult `/tmp/OhanaDerivedData-calendar-fm-1782861586/Logs/Test/Test-Ohana-2026.07.01_02-44-53-+0200.xcresult`。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-b scripts/test-simulator.sh ... '-only-testing:OhanaUITests/OhanaUITests/testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail' '-only-testing:OhanaUITests/OhanaUITests/testPetCalendarFilterShowsOnlyPetLinkedEvents' '-only-testing:OhanaUITests/OhanaUITests/testCalendarAddEventKeyboardKeepsEditorControlsVisible' ...`，`iPhone 17` simulator；相关 Calendar 用例在 broad GUI 批次 B 初跑通过。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-d scripts/test-simulator.sh ...`，`iPhone 17` simulator，日历标题边界用例 `testPetLinkedManualPottyTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualWalkTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualPlayTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualWeightTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualHealthTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualHygieneTitleCalendarEventRowOpensEventDetail` 随 10 条 GUI 合跑通过；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-d/Logs/Test/Test-Ohana-2026.07.01_02-46-35-+0200.xcresult`。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-e scripts/test-simulator.sh ...`，`iPhone 17` simulator，`testPetLitterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail`、`testPetScoopPlanCalendarEventAppearsAndDeletesFromQuickCareDetail`、`testDeletedPetCalendarEventDoesNotOpenLiveCareRoute`、`testMemorialPetCalendarEventDoesNotOpenLiveCareRoute` 随 12 条 GUI 合跑通过；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-e/Logs/Test/Test-Ohana-2026.07.01_03-00-54-+0200.xcresult`。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-f scripts/test-simulator.sh ...`，`iPhone 17` simulator，`testExistingPetRealUserJourneyWithoutReset` 和 `testPetRealUserLongSessionCoversCareCalendarEconomyAndSafeguards` 覆盖 linked pet 用户事项和宠物筛选；整批 `Executed 9 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-f/Logs/Test/Test-Ohana-2026.07.01_03-21-43-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 H 中 `testCalendarAddEventKeyboardKeepsEditorControlsVisible`、`testPetCalendarFilterShowsOnlyPetLinkedEvents`、`testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail` 初跑通过；初跑 15 条中 12 条通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-h/Logs/Test/Test-Ohana-2026.07.01_04-19-18-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 I 中 `testPetLinkedManualCalendarEventRowOpensEventDetail`、`testPetLinkedManualPottyTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualWalkTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualPlayTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualWeightTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualHealthTitleCalendarEventRowOpensEventDetail`、`testPetLinkedManualHygieneTitleCalendarEventRowOpensEventDetail` 全部通过；整批 `Executed 16 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-i/Logs/Test/Test-Ohana-2026.07.01_06-05-25-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 J 初跑中植物 Calendar 查找失败后，修复 UITest 为全部筛选 / 列表视图 / 滚动匹配植物计划行，`PlantModuleUITests.testPlantModuleUnlockCreateCareReminderCalendarAndDelete` 单条复跑 `Executed 1 test, with 0 failures`；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-j/Logs/Test/Test-Ohana-2026.07.01_06-52-42-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 K 中 `testCalendarAddEventKeyboardKeepsEditorControlsVisible` 和 `testManualCalendarEventRowOpensDetailEditsAndDeletes` 通过，覆盖 Add Event 键盘弹出后保存按钮仍可见、用户手动事项点击详情、编辑标题保存、再次打开并删除；整批 9 条 GUI 用例通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-k/Logs/Test/Test-Ohana-2026.07.01_08-23-54-+0200.xcresult`。
- 预检证据：2026-07-01 日历点击干净合跑：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-calendar-event-tap-20260701 scripts/test-simulator.sh '-only-testing:OhanaTests/CalendarEventInteractionPolicyTests' '-only-testing:OhanaUITests/OhanaUITests/testManualCalendarEventRowOpensDetailEditsAndDeletes' '-only-testing:OhanaUITests/OhanaUITests/testSystemGeneratedPetCalendarFeedEventRowOpensQuickFeedDetail'`，`iPhone 17` simulator；6 条策略单测 + 2 条 GUI 用例全部通过，xcresult `/tmp/OhanaDerivedData-calendar-event-tap-20260701/Logs/Test/Test-Ohana-2026.07.01_09-09-36-+0200.xcresult`。
- 问题：

### 8. 成就、里程碑、成长解锁和心愿单（对应打卡 7）

已测过：

- 成就领取、里程碑奖励、成长解锁策略、心愿单创建 / 兑换 / 删除、余额不足 no-op 已测。
- 心愿单兑换 UI 已测。
- 2026-07-01 broad GUI 批次 B 已复测 Human Wishlist 创建 / 兑换 / redeemed state，并复测 Daily Streak sheet 打开 / 关闭。
- 2026-07-01 broad GUI 批次 L 再次复测 Human Wishlist 兑换和 Daily Streak sheet 打开 / 关闭。

真机还要测：

- 打开成就墙，领取一次可领取成就。
- 创建里程碑，确认奖励和历史显示。
- 打开成长路线，检查锁定 / 解锁说明。
- 创建心愿单并兑换，检查余额和账本。
- 用长语言或长标题检查按钮遮挡。

通过标准：

- 奖励和消费进入正确钱包 / 账本。
- 余额不足、冻结钱包和锁定状态反馈得体。
- 长文案不遮挡主要按钮。

记录：

- 设备 / iOS：
- 构建：
- 结果：2026-07-01 心愿单兑换和 Daily Streak sheet 模拟器 GUI 预检通过，真机长文案、按钮遮挡和触感仍待测。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-b scripts/test-simulator.sh ... '-only-testing:OhanaUITests/OhanaUITests/testHumanWishlistRedeemSpendsCoconutsFromFeatureHub' '-only-testing:OhanaUITests/OhanaUITests/testDailyStreakSheetOpensAndClosesFromHome' ...`，`iPhone 17` simulator；相关用例在 broad GUI 批次 B 初跑通过。
- 预检证据：2026-07-01 broad GUI 批次 L 中 `testDailyStreakSheetOpensAndClosesFromHome` 和 `testHumanWishlistRedeemSpendsCoconutsFromFeatureHub` 通过；整批 12 条 GUI 用例通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-l/Logs/Test/Test-Ohana-2026.07.01_08-44-15-+0200.xcresult`。
- 问题：

### 9. 照片、周报、纪念历史和植物历史（对应打卡 4、5）

已测过：

- 家庭周报非竞赛语义已测。
- 相册照片隐私清洗和批量命令边界已测。
- 植物功能门、历史植物数据和纪念历史只读边界已测。
- 2026-07-01 broad GUI 批次已复测 Settings Debug -> Family Weekly Report，成员贡献卡、最近活动卡和非竞赛文案仍可达。
- 2026-07-01 broad GUI 批次已跑通植物完整核心链路：Oasis Lv4 解锁、添加 Pothos、填写 room / location、植物卡片回读、Settings 植物提醒开关往返、重启后 Calendar / Plants 回读、Plant Detail 护理、删除撤销和最终删除。
- 2026-07-01 broad GUI 批次 J 初跑时植物长链路只有 Calendar 可见性断言失败；定位为 UITest 只看 Calendar 首屏，未切全部 / 列表并滚动查找未来日期的植物计划行。修复测试后，单条植物完整链路复跑通过。
- 2026-07-01 植物提醒“全部延后一天”业务单测通过：到期植物任务会被延后并保留提醒重建边界；后续 broad GUI 批次 H 也通过了 existing-plant Settings bulk defer 入口、Plant Detail 编辑取消和保存路径。
- 2026-07-01 broad GUI 批次 L 再次复测 Family Weekly Report、existing-plant Settings bulk defer、Plant Detail 编辑取消和保存路径。
- 2026-07-02 植物品种库和 Plants 视图升级已做代码预检：离线精选库解码 / 搜索 / attribution / 本地图断言通过；添加植物目录优先、植物 wallet 卡片、四个快捷操作、右侧房间 rail、切房间自动收起错误展开卡片均有源级和单元测试覆盖；Debug build 通过。
- 2026-07-03 添加植物目录优先主路径已做 GUI 复测：新账号解锁 Plants 后，点击 Add Plant -> 选择 Pothos 目录品种，名称自动采用品种名；选择房间 chip 和位置 chip 时，名称、房间、自定义位置输入框不会出现在主路径里，可选细节保持收起；保存后 Home 植物 wallet 卡片出现。
- 2026-07-03 植物品种库本地头像已做单元预检：当前 248 个目录品种全部有 `PlantAvatarAssets/plant_*.png` 本地头像；没有用户照片时，植物 wallet 卡会优先使用匹配的品种库本地头像；未知 / 手动非目录品种仍使用通用叶子图占位，真机只需确认不破版。
- 2026-07-03 植物 wallet 卡片展开 / 收起位置稳定性已做 GUI 复测并追加根因修复：6 张植物卡片同屏时，展开一张植物卡再收起后，6 张卡片都会回到原始 frame 附近；8 张植物长列表时，首屏只有 6 张卡片处于可点击区域，第 7 张以后需要向下滚动，滚动到的卡片仍可展开 / 收起且后续卡片仍可继续到达；植物 deck 已对齐 Home 植物卡片的 collapsed anchor，当前根因修复是在植物页启用共享 scene 的本地 inactive freeze，让非选中卡片在 hero 动画期间冻结 frame / rotation 并禁用隐式动画 / 缩放，同时仍不恢复植物页专用 frozen inactive 外部状态；最新复跑还确认 wallet 代码拆到 `PlantDashboardView+WalletDeck.swift` 后源码守卫覆盖该文件和 scene-local inactive freeze 开关。
- 2026-07-03 最新顺序 GUI 复跑再次确认植物 wallet：6 张卡片展开 / 收起后全部回到原始 frame 附近；8 张植物时首屏只有 6 张处于可点区域，第 7 张以后需要滚动，滚动后的卡片仍可展开 / 收起且后续卡片仍可继续到达。并发跑 UI 测试会抢同一个模拟器 app 进程，已丢弃不作为失败证据。
- 2026-07-03 植物照护类型文案已做显式语言预检：Dashboard、wallet 快捷操作、护理计划、位置详情、植物详情时间线、通知 intent 标题和成长日记导出都走 `displayName(l:)`，中文 / 英文 / 德文单测和源码守卫通过；真机只需按当前语言目检关键入口文案不串语言。
- 2026-07-03 右侧房间 rail 的旧交互曾做 GUI 复测：展开 Living room 植物后直接点击 Balcony rail 会收起卡片并完成筛选。当前显式策略已改为“卡片展开时隐藏 rail”；现行自动化会先收起卡片、等待 rail 恢复，再筛选并验证重排。旧结果只保留为历史证据，现行 GUI 复跑仍待完成。
- 2026-07-03 后续产品口径已移除植物详情 -> 护理日历入口；植物相关 Calendar 事项改为通过首页日历 tab 的“植物”聚合筛选验收。

真机还要测：

- 用真实照片打开相册大图，滑动多张照片。
- 打开家庭周报，确认只表达照护周报，不出现排行或竞赛暗示。
- 打开纪念对象历史资料，确认历史可读但不可活跃写入。
- 用带历史植物数据的样本遍历 Home、Task Center、Oasis、FunctionMenu。
- 在 Settings -> Plant care reminders 中点击 `Defer all by one day` / `全部延后一天`。
  记录：是否能立即看到“正在延后到期植物任务…”或最终状态文案；是否卡住；是否误触其它行。

植物新增能力真机打卡：

- [ ] 添加植物时先用“新手友好 / 宠物家庭 / 弱光 / 阳台 / 开花 / 多肉”筛选，再点一个目录品种建档；确认主路径默认不弹名称 / 房间 / 位置输入框，名称可按需点编辑手改，品种、浇水、施肥、光照、土壤和安全提示会自动带入。
- [ ] 在添加植物搜索框分别搜中文名、英文名、拉丁名和别名；确认结果能点选，且不知道品种时仍可跳过手动建档。
- [ ] Plants 视图中点击植物卡片能展开为 wallet 卡片；再次点击或上滑能收起；展开 / 收起过程中其他卡片不能跳位；6 张以内按宠物卡片位置铺开，7 张及以上从第 7 张开始需要向下滚动；展开后浇水、施肥、笔记 / 成长记录、详情四个快捷操作都能点到正确页面或记录页。
- [ ] 植物卡图片优先显示用户照片；没有用户照片时，Pothos / Monstera / 空气凤梨等目录品种显示品种库本地图；手动创建未知 / 非目录品种时使用通用叶子图且不破版。
- [ ] 展开植物卡片时确认屏幕右边缘房间 rail 隐藏；收起卡片后确认 rail 恢复，再切换“全部”和各房间；确认 44pt 命中不难点、不挡底部导航 / FAB，筛选后的卡片会重新排布，切回“全部”后恢复完整 deck。
- [ ] 从 Home FAB -> More -> Plants 打开 Function Menu 植物分组，依次点 Plant Overview / Plant List / Growth Photos；确认三者切换到对应植物页，并确认不再出现 Plant Calendar 分段。
- [ ] 从植物详情页打开功能中心；确认不再出现“护理日历”卡片；回到首页日历 tab 点“植物”聚合筛选，确认植物事项仍可查看。
- [ ] 多房间、多植物、空房间、长英文 / 德文 / 中文名称、动态字体放大时不重叠、不挡按钮。

通过标准：

- 图片 viewer 不泄漏隐私附件信息，不明显卡死。
- 周报语气不是排行榜。
- 纪念和历史植物入口不会污染当前活跃照护、奖励或任务。
- 植物提醒“全部延后一天”在真机上可点击，点击后马上出现状态反馈；有到期任务时延后一天，无到期任务时显示“当前没有已到期的植物任务”一类空状态。
- 植物目录添加、植物 wallet 卡片和右侧房间 rail 在真机上可顺手完成，不需要依赖外部 API 或网络。

记录：

- 设备 / iOS：
- 构建：
- 结果：2026-07-01 周报、植物核心长链路、植物 Settings bulk defer 入口和 Plant Detail 编辑取消 / 保存均已有模拟器 GUI 预检；2026-07-02 植物品种库 / wallet 卡片 / 右侧房间 rail 已有代码预检和 Debug build；2026-07-03 添加植物目录优先无键盘主路径、248 个目录品种本地头像接入、植物 wallet 展开 / 收起、8 张植物长列表滚动，以及“植物页不再提供独立植物日历入口，植物事项只从首页日历 tab 的植物聚合筛选查看”均已有模拟器 GUI 或单元预检。房间 rail 的旧 GUI 结果不再代表当前“展开时隐藏”的交互；当前策略已有单元预检，修订后的 GUI 用例仍待复跑。真实照片、纪念历史真实样本、历史植物样本和真机手感仍待测。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-a scripts/test-simulator.sh '-only-testing:OhanaUITests/PlantModuleUITests/testPlantModuleUnlockCreateCareReminderCalendarAndDelete' ... '-only-testing:OhanaUITests/OhanaUITests/testFamilyWeeklyReportOpensFromDebugSettingsWithoutCompetitionCopy' ...`，`iPhone 17` simulator，7 条 GUI 用例合跑 `Executed 7 tests, with 0 failures`，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-a/Logs/Test/Test-Ohana-2026.07.01_00-39-04-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 J 初跑 18 条中 17 条通过，唯一失败为植物 Calendar 首屏查找测试脚本问题；修复后 `PlantModuleUITests.testPlantModuleUnlockCreateCareReminderCalendarAndDelete` 单条复跑通过，覆盖植物解锁、创建、Settings 提醒、Calendar 植物计划行查找、详情护理、删除撤销和永久删除；初跑 xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-j/Logs/Test/Test-Ohana-2026.07.01_06-26-43-+0200.xcresult`，复跑 xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-j/Logs/Test/Test-Ohana-2026.07.01_06-52-42-+0200.xcresult`。
- 预检证据：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gui-broad-20260701-c scripts/test-simulator.sh '-only-testing:OhanaTests/PlantLaunchTests/plantBulkDeferAppliesToMutedVisibleCareTasksWithoutRecreatingReminders()'`，`iPhone 17` simulator，植物 bulk defer 业务单测通过；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-c/Logs/Test/Test-Ohana-2026.07.01_02-43-45-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 H 修复后，`PlantModuleUITests.testExistingPlantSettingsBulkDeferAndEditCancelSaveWithoutReset` 通过，覆盖 existing plant seed、Settings bulk defer 入口点击、Plant Detail 编辑取消不保存、保存后回读；xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-h-plant-rerun/Logs/Test/Test-Ohana-2026.07.01_05-55-24-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 K 中 `PlantModuleUITests.testPlantModuleUnlockCreateCareReminderCalendarAndDelete` 再次通过，覆盖植物解锁、创建 Pothos、Settings 植物提醒开关、Calendar 列表计划行、详情延后 / 浇水 / 施肥、删除撤销和最终删除；整批 9 条 GUI 用例通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-k/Logs/Test/Test-Ohana-2026.07.01_08-23-54-+0200.xcresult`。
- 预检证据：2026-07-01 broad GUI 批次 L 中 `testFamilyWeeklyReportOpensFromDebugSettingsWithoutCompetitionCopy` 和 `PlantModuleUITests.testExistingPlantSettingsBulkDeferAndEditCancelSaveWithoutReset` 通过；整批 12 条 GUI 用例通过，xcresult `/tmp/OhanaDerivedData-gui-broad-20260701-l/Logs/Test/Test-Ohana-2026.07.01_08-44-15-+0200.xcresult`。
- 预检证据：2026-07-02 `DERIVED_DATA_PATH=/tmp/OhanaDerivedData-plant-catalog-wallet-20260702 scripts/test-simulator.sh '-only-testing:OhanaTests/PlantLaunchTests'`，`iPhone 17` simulator，44 条植物启动 / 目录 / 搜索 / 默认值 / bulk defer 测试通过，xcresult `/tmp/OhanaDerivedData-plant-catalog-wallet-20260702/Logs/Test/Test-Ohana-2026.07.02_20-44-25-+0200.xcresult`。
- 预检证据：2026-07-03 `scripts/test-simulator.sh '-only-testing:OhanaTests/PlantLaunchTests'`，`iPhone 17` simulator，50 条植物启动 / 品种库 / 248 个本地头像 / wallet 卡片适配 / 提醒 / Calendar / 账本测试通过；xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_06-46-12-+0200.xcresult`。
- 预检证据：2026-07-02 `DERIVED_DATA_PATH=/tmp/OhanaDerivedData-plant-catalog-wallet-20260702 scripts/test-simulator.sh '-only-testing:OhanaTests/PlantDetailExperienceTests'`，`iPhone 17` simulator，11 条植物详情 / 添加页 / dashboard wallet / room rail 源级测试通过，xcresult `/tmp/OhanaDerivedData-plant-catalog-wallet-20260702/Logs/Test/Test-Ohana-2026.07.02_20-43-57-+0200.xcresult`。
- 预检证据：2026-07-02 `git diff --check`、`scripts/audit-ui-v4.sh --changed`、`scripts/audit-accessibility.sh --changed`、`scripts/dev-check-changed.sh`、`scripts/build-debug-fast.sh` 均通过；目录和新增 UI 不依赖运行时外部 API / API Key。
- 预检证据：2026-07-03 `scripts/test-simulator.sh '-only-testing:OhanaTests/PlantDetailExperienceTests/testAddPlantFlowUsesSimpleCatalogFirstSetup'`，`iPhone 17` simulator，1 条添加植物源码守卫通过，确认目录优先、层级品种分组、名称默认、chip 选择、自定义房间 / 位置显式展开和可选细节收起结构仍在；xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_06-14-49-+0200.xcresult`。
- 预检证据：2026-07-03 `scripts/test-simulator.sh '-only-testing:OhanaUITests/PlantModuleUITests/testAddPlantPrimaryPathUsesCatalogAndChoiceChipsWithoutTyping'`，`iPhone 17` simulator，1 条 GUI 用例通过；测试新账号解锁 Plants，打开添加植物，选择 Pothos 目录品种，断言 `add-plant-name-input`、`add-plant-room-input`、`add-plant-location-input` 和 `add-plant-optional-details-content` 在主路径中都不存在，选择房间 / 位置 chip 后保存并确认 `home-card-plant-pothos` 出现；xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_06-15-09-+0200.xcresult`。
- 预检证据：2026-07-03 `OhanaTests/VerticalHomeTabMountPolicyTests`，`iPhone 17` simulator，56 条 source / policy 测试通过，其中包含植物 deck 使用 Home 植物 collapsed bias、共享 inactive freeze policy、植物页稳定 collapsed 槽位守卫、以及旧 Plants toggle 走 hero 状态机的守卫；最新复跑 xcresult `/Users/guanchenli/Library/Developer/XcodeBuildMCP/workspaces/Ohana-b6cf423d5931/result-bundles/test_sim_2026-07-03T07-49-55-147Z_pid68180_1c4036cb.xcresult`。
- 预检证据：2026-07-03 `scripts/test-simulator.sh '-only-testing:OhanaTests/PlantDetailExperienceTests'`，`iPhone 17` simulator，12 条植物体验源码测试通过，确认植物 dashboard 源码守卫已包含 `PlantDashboardView+WalletDeck.swift`、8 张植物 seed 数量和长列表 GUI 断言；xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_07-45-54-+0200.xcresult`。
- 预检证据：2026-07-03 `scripts/test-simulator.sh '-only-testing:OhanaUITests/PlantModuleUITests/testExistingPlantWalletExpandCollapseReturnsToStableDeckWithoutReset()'`，`iPhone 17` simulator，1 条 GUI 用例通过；测试 seed 6 张植物卡片，展开第一张植物卡、等待 `home-expanded-detail-plant`、点击 `home-expanded-collapse-plant` 收起，并断言 6 张植物卡都恢复到稳定可点击 collapsed frame；最新复跑通过，xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_07-46-12-+0200.xcresult`。
- 预检证据：2026-07-03 `scripts/test-simulator.sh '-only-testing:OhanaUITests/PlantModuleUITests/testPlantWalletLongListScrollsPastSixCardsWithoutCrowdingTopViewport()'`，`iPhone 17` simulator，1 条 GUI 用例通过；测试 seed 8 张植物卡片，断言首屏顶部可点击区域正好 6 张卡片、至少 1 张卡片需要滚动才能到达，滚动到第 7 张以后仍能展开 / 收起，且另一张后续卡片仍可继续滚动到达；xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_07-42-52-+0200.xcresult`。
- 历史预检证据：2026-07-03 `testPlantRoomRailFiltersAndCollapsesExpandedCard` 在 `iPhone 17` simulator 通过，xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_05-00-34-+0200.xcresult`；该用例验证的是已被当前策略取代的“展开时 rail 仍可点击”交互，不作为现行 GUI 通过证据。现行用例名为 `testPlantRoomRailFiltersAfterCollapsingExpandedCard`，先验证展开时 rail 隐藏，再收起并筛选；GUI 复跑待完成。
- 当前策略证据：2026-07-10 `scripts/test-simulator.sh '-only-testing:OhanaTests/VerticalHomeTabMountPolicyTests/plantRoomRailShowsWhenPlantPageHasPlants()'`，`iPhone 17` simulator，通过；确认有植物且无展开卡片时显示 rail，卡片选中或 hero 动画期间隐藏。xcresult `.build/DerivedData/tests/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.10_23-58-26-+0200.xcresult`。
- 预检证据：2026-07-03 `scripts/test-simulator.sh '-only-testing:OhanaTests/PlantDetailExperienceTests' '-only-testing:OhanaTests/PlantLaunchTests' '-only-testing:OhanaTests/AppRouteCoordinatorTests' '-only-testing:OhanaTests/HomeRouteCoordinatorTests' '-only-testing:OhanaTests/VerticalHomeTabMountPolicyTests'`，`iPhone 17` simulator，176 条 selected 源码 / 路由 / 植物策略测试通过；其中 `PlantDetailExperienceTests/testPlantCalendarEntrypointsAreRemovedButGlobalFilterRemains` 确认植物详情 / Function Menu 植物日历入口已移除，首页日历的“植物”聚合筛选仍保留；xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_13-48-26-+0200.xcresult`。
- 预检证据：2026-07-03 `scripts/test-simulator.sh '-only-testing:OhanaUITests/PlantModuleUITests/testPlantDetailDoesNotExposeCareCalendarEntrypointWithoutReset'`，`iPhone 17` simulator，1 条 GUI 用例通过；测试 seed 植物后进入植物详情，确认 `plant-detail-action-tool-calendar` 不存在，打开功能中心后确认 `feature-hub-plan-calendar` 不存在；xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.07.03_13-48-48-+0200.xcresult`。
- 问题：

## RC 收尾

完成上面两轮后，再跑一遍最短 RC：

- 启动 App。
- 打开 Home。
- 进入 Settings。
- 创建或选择一个人类和宠物。
- 执行一次宠物快捷照护。
- 执行一次人类记录。
- 打开 Calendar。
- 打开 FunctionMenu。
- 确认当前首发 Settings 不暴露隐藏的 Human 隐私 / PIN 控制。
- 打开相册或文档附件。
- 退出并重开 App。

通过标准：

- App 可启动、可退出、可重进。
- 主要数据仍在。
- 没有首屏空白、闪退、卡死、不可点击或明显视觉错位。

## 发现问题时怎么记录

把下面模板复制到对应小节：

```text
日期：
设备 / iOS：
构建：
路径：
结果：通过 / 失败 / 需要复测
是否阻塞首发：是 / 否 / 不确定
现象：
截图或录屏：
下一步：
```

失败分级建议：

- 阻塞首发：闪退、卡死、数据丢失、隐私泄漏、通知跳错成员、删除后对象复活、首启不可达。
- 需要首发前修：按钮不可点、键盘遮挡关键操作、真实 picker 不可用、删除后入口仍可见、长列表严重卡顿。
- 可延期：纯文案微调、低频视觉瑕疵、CloudKit live apply、首发关闭功能的 1.x 行为。
