# Ohana 1.0 上架准备与 Go/No-Go 清单

> 文档性质：Release owner 的执行清单；不替代状态总账。
>
> 核对日期：2026-08-04。
>
> 当前结论：**NO-GO，暂不可提交 App Review。**
>
> 首发范围：iPhone-only、iOS 26.2+、Ohana Free + Personal；Family、Care+、
> CloudKit 协作、原生 iPad/watchOS、Shortcuts/Siri/Spotlight 不进入 1.0。
>
> 状态权威：[`testing-progress.md`](testing-progress.md)、
> [`task-follow-ups.md`](task-follow-ups.md)；产品权威：
> [`product-foundation.md`](specs/product-foundation.md)。

## 一页结论

上架前不只是“再跑一次测试”。当前至少有六组硬门：

| Gate | 当前判断 | 关闭条件 |
| --- | --- | --- |
| G0：冻结 RC 与重建状态基线 | 本地源码冻结；替代 development-signed Archive 待生成 | 当前完整 Unit 2,310/2,310 和发行静态门通过；132-selector UI campaign 的 2 个失败已精确复验 2/2，受保护 Dogfood 通过；commit `64e3d6ba0` 的本地 Release Archive 已用于预检，但 Widget manifest 精度修复后须从新的干净 commit 生成替代 Archive |
| G1：首发裁剪与隐私清单 | Required Reason 扫描完成；替代 Archive/Privacy Report 待生成 | Guardian UI/runtime/deep link、源码 entitlement/Info.plist 与隐私清单已按 Solo 收敛；development-signed 预检发现并移除 Widget 多报的 File Timestamp 类别，仍须从修复后的 Archive 重复核验，并继续关闭 Developer Portal、distribution profile 与最终 distribution-signed Archive 门禁 |
| G2：Free / Personal 真实商店闭环 | 阻塞 | App Store Connect 商品、协议、税务、银行、九语言元数据、Sandbox、退款/撤销、第二设备恢复全部通过 |
| G3：Widget / Live Activity 签名能力 | 阻塞 | 注册 App Group；App 与 Widget distribution profile 匹配；当前签名包在真机完成 Widget、锁屏和 Dynamic Island 验收 |
| G4：商店资料与合规 | 仓库草案完成，外部状态未知 | 九语言元数据与审核填写包已准备；截图、年龄分级、DSA、隐私、出口合规、账户字段仍须在 App Store Connect 完成 |
| G5：当前签名包 RC 验收 | 旧 development-signed 包已完成预检；替代包待生成 | 当前 Unit/静态、失败已清零的 UI campaign、受保护 Dogfood 和 commit `64e3d6ba0` 的本地 Release Archive 已记录；Widget manifest 精度修复使该包成为历史证据，仍须生成替代 development-signed Archive、最终 distribution-signed artifact，并完成 TestFlight/Sandbox 和真机 R0–R7 |

活动总账已于 2026-08-03 区分 7 月 29 日历史证据与当前本地证据。当前结构审计记录 13 个 open follow-up：
P0 = 0、P1 = 8、P2 = 4、P3 = 1；“首发可达实现/证明缺口的 P1 = 2”是
2026-07-22 的旧分类，不是当前 RC 结论。
这些数字**不能直接证明当前工作树已经达到上架标准**：

- 本清单所在 commit 冻结跨模块发布改动；此前 dirty worktree 的历史路径计数不作为
  signed artifact 身份。
- 产品合同在 7 月 23–25 日继续变化，当前 D17/D28 已改成 Standard/Zen 共用的
  Human-first 两项新手任务；7 月 18 日旧流程的绿色证据不能证明当前实现。
- 本轮已把真机清单和 follow-up 从旧的“Pet 保存后才出现 +50”、Family
  第 2/3 个漏签日推送，校正为 Human 建立即可领取、Family 第 1/2 个有效漏签日；
  旧日期结果只保留为历史证据。

当前 D34/V97/V98 与化验单扫描已经完成本地实现，完整 Unit 执行 2,310 tests / 0
failures，发行静态门通过。当前 132-selector / 9-shard UI campaign 记录 130 pass、
2 fail；修复后两个原失败 selector 精确复验 2/2。按产品负责人要求，没有为合并数字而
重跑未变化的完整 campaign，因此不得写成单次 132/132。受保护 Dogfood WMO Release
overlay 与正常 UI Human detail/gender menu open-cancel 通过，sealed store 保持完整。
commit `64e3d6ba0` 冻结当前本地 RC 源码身份。Xcode 26.6 已从该 commit 生成
`Ohana 1.0 (1)` arm64 Release Archive；`codesign`、主 App/Widget test-surface
artifact scan 与 Archive 元数据检查通过。该包使用 Apple Development profile 且
`get-task-allow=true`，因此只关闭本地 development-signed 预检，不替代最终
App Store distribution artifact。Xcode Organizer 从该 Archive 生成的 Privacy Report
是有效的一页空白 PDF：归档内主 App 与 Widget 都声明不跟踪且
`NSPrivacyCollectedDataTypes` 为空，因此没有 Nutrition Label 条目；required-reason
API 仍由两份 `PrivacyInfo.xcprivacy` 单独核对。报告 SHA-256 为
`bc5523c13c40ed0811d4794d722050c150d3985d2f689afb23830b8f9d74b5b0`。随后按 Apple
当前五类 API 清单复核源码与归档可执行文件，确认主 App 使用且完整声明
User Defaults、File Timestamp、System Boot Time，没有 Disk Space 或 Active Keyboards；
项目没有第三方 package/framework。Widget 不使用任何列出的 required-reason API，
因此其原 `FileTimestamp/C617.1` 属于多报，源码 manifest 已改为空类别，并新增契约测试
与资源审计。该修复使 `64e3d6ba0` Archive 成为历史预检证据，须由修复后的干净
commit 重建替代 Archive 与 Privacy Report。

## G0：先冻结一个真正的 RC

### 0.1 固定范围与版本身份

- [ ] 确认 1.0 只包含 Free + Personal；Family SKU、入口、账号、APNs 守护和后端
  均不发布。
- [ ] 确认 iPhone-only、最低 iOS 26.2、版本 `1.0` 是最终产品选择。
- [x] 确认 V97/V98 的 Human 健康状况、观察、手动指标与 Personal 本机化验单
  扫描进入 1.0；原始图片/OCR 不持久化，结构化结果须经用户复核后原子保存。
- [x] 本清单所在 commit 是可追溯的本地 RC 源码身份；不得从后续 dirty worktree
  归档或提交。
- [ ] 固定 `MARKETING_VERSION = 1.0` 和唯一递增的 build number。当前工程是
  `1.0 (1)`；如果 build 1 已上传过，必须递增。
- [ ] 记录 RC 所用 Xcode、SDK、commit、build、Archive SHA-256 和构建时间。

本机已有 Xcode 26.6 / iOS 26.5 SDK，满足 Apple 自 2026-04-28 起要求使用
Xcode 26+ 与 iOS 26+ SDK 上传的门槛。最低部署版本 iOS 26.2 是 Ohana 自己的产品
决定，不是 Apple 的上传要求。

### 0.2 让状态文档重新对齐当前产品

- [x] 更新 [`testing-progress.md`](testing-progress.md)：旧 D17/D28 证据降级为历史，
  登记当前 Standard/Zen 证据。
- [x] 更新 [`task-follow-ups.md`](task-follow-ups.md)：重新确认当前 P0/P1 数量；
  Family 日序列改为第 1/2 个有效漏签日。
- [x] 更新 [`release-true-device-test-plan.md`](release-true-device-test-plan.md)：
  移除 Pet 决定礼包资格的旧步骤，统一打卡板和快速总表状态。
- [ ] 以 [`Onboarding-logic.md`](specs/Onboarding-logic.md) 当前 Required Proof 为准，
  至少重新证明：

  - [x] Standard：选择模式 → Human → 稍后建 Pet → 领取 +50 → Oasis → 关闭零奖励
    Pet 建议 → Human 资料 75% → 领取 +100 → Standard/Zen 往返无重复。
  - [x] Standard：选择模式 → Human → 现在建 Pet → 回 Home，不自动切 Tasks，
    不自动发礼包。
  - [x] Zen：选择模式 → Human → 领取 +50 → Oasis → Human 资料 75% →
    领取 +100。
  - [x] Standard/Zen 来回切换不重置、不重复展示已领取项、不双发奖励。
  - [x] 已有 receipt、奖励投影丢失恢复、重启幂等和当前既有 SwiftData 数据兼容。
  - [ ] 从更早 schema 的完整升级矩阵和中断恢复仍须纳入冻结 RC 全门。

### 0.3 2026-08-03 当前本地证据

| 证据 | 结果 | 限制 |
| --- | --- | --- |
| 完整 Unit | 2,310/2,310 通过，0 failure | repository/Simulator 本地证据；不替代 signed Archive 或真机 |
| 完整发行静态门 | 通过 | 当前完整严格静态审计通过；不替代 runtime、签名或外部平台证据 |
| 完整 UI campaign + 精确失败复验 | 132 selectors / 9 shards 首次 campaign 为 130 pass、2 fail、0 infra；修复后两个原失败 selector 精确复验 2/2 | 按负责人要求不完整重跑；所有记录失败已清零，但不得表述为单次 132/132 |
| 受保护既有用户 Dogfood | guarded WMO Release overlay 与正常 UI Human detail/gender menu open-cancel 通过；2 Humans / 1 Pet / 16 care / 8 plans / 52 ledger / 0 test artifacts | sealed identity/store 保持；仅证明积累数据和本次非破坏路径，不替代真机、reset/seed 或破坏性流程 |

以上足以让 V97/V98 Human 健康与 Personal 化验单扫描进入冻结的本地 1.0 candidate，
但不能替代 signed Archive、Camera/Photos 真机、StoreKit、TestFlight 或专业语言审校。

### 0.4 2026-07-29 历史未签名证据（D34 之前）

| 证据 | 结果 | 产物 / 限制 |
| --- | --- | --- |
| Standard + Zen 当前首装 UI | 2/2 通过 | `.build/TestResults/2026-07-29/app-store-standard-zen-ui-final.xcresult` |
| 自定义物种/品种返回持久化 UI | 1/1 通过 | `.build/TestResults/2026-07-29/app-store-custom-species-ui-final.xcresult` |
| Guardian 裁剪、隐私、路由、奖励恢复、Standard/Zen、本地 Family 任务 | 20 suites、270/270 通过 | `.build/TestResults/2026-07-29/app-store-release-cut-unit-final.xcresult` |
| 授权后能力清理回归与 Release 产物 | 2 suites、114/114；优化版 Release 构建通过 | 锁定首发 entitlement、Info.plist、Guardian/CloudKit fail-closed 边界；合并后 `UIBackgroundModes` 仅含 `fetch`/`location`，无 Guardian keys，Widget 已嵌入；`.build/TestResults/2026-07-29/app-store-capability-cleanup-unit.xcresult` |
| Solo APNs callback 编译门 | 12/12 通过 | runtime `responds(to:)` 契约确认 AppDelegate 对 3 个 APNs/远程通知 selector 均不响应；优化版 unsigned Release 的 `OhanaCloudSharingAppDelegate` class-specific method metadata 不实现这 3 项 callback；`.build/TestResults/2026-07-29/app-store-solo-apns-callback-gate.xcresult` |
| 当时源码完整 Unit | 2,182/2,182 通过 | 无 `remote-notification` 启动警告；`.build/TestResults/2026-07-29/app-store-full-unit-post-apns-callback-gate.xcresult`；不覆盖 2026-08-02 D34 |
| 当时源码完整 UI 执行 | 首轮 127/128；同构建复验 1/1 通过 | build 与 8/9 shards PASS；Plants 唯一失败为动态 `XCUIElementQuery.count` 与 `element(boundBy:)` 之间的 AX 集合竞态，失败现场仍保有 6 个 room、每组 4 张卡与 Collapse；同一 App/UI provenance 精确复验通过，0 failure/skip。首轮 root：`.build/TestResults/2026-07-29/app-store-full-ui-post-apns/20260729-141139-740`；复验：`.build/TestResults/2026-07-29/app-store-full-ui-post-apns/plant-room-stack-same-build-rerun.xcresult`。不得表述为单次 128/128，也不覆盖 2026-08-02 D34 |
| 完整发行静态门 | 通过 | 本轮观察 `scripts/release-hardening-check.sh --static-only` exit 0；128 selectors / 9 shards 仅为 manifest 完整性，Privacy manifest 声明 3 类 required-reason API；未保留独立静态日志，冻结 RC 须重跑并留档 |
| 受保护既有用户 WMO Release overlay | 通过 | 正常 Home 已目检；sealed identity 和 ready 快照保持 2 Humans / 1 Pet / 15 care / 8 plans / 47 ledger / 0 test artifacts；Day 7 ready、Day 30 incomplete |
| 全脏树 changed-file dispatcher | 未全绿 | `diff` 与 UI 分片通过；3 个本轮未修改的既有脏文件仍有 SwiftFormat lint，未擅自重写 |

本轮环境为 Xcode 26.6（17F113）、iOS Simulator SDK 26.5，自动化设备为
`iPhone 17 Tests`（`DFCF3E93-1A6F-4430-9312-8BFD08FC9FE0`）。优化版 unsigned
Release 为 `x86_64 arm64`，主二进制 SHA-256 为
`eec0892e0da28cf63054852b6a418c537c503425f917f18482e7f089fc2f8193`。
完整 UI 共用构建的 `source_tree_sha256` 为
`d1f2081e27e27f6489bf491ddbe9170f789442ff9bd5f370a3f69bbc718826e3`，
`contract_sha256` 为
`f585f1b6f5bbc8332758be5e73131ed680444cd336c8986522782f99abca9ffd`；
provenance 已随该次 run root 保存。

`scripts/dev-check-changed.sh` 唯一未关闭的是 3 个既有脏文件的机械格式债：
`PresenceCheckInCommandService.swift` 1 项 `blankLinesAtEndOfScope`、
`ZenStreakView.swift` 20 项 `redundantReturn`、`HomeCommandExecutorTests.swift`
7 项 `numberFormatting`。本轮没有借上架清理授权改写这些用户既有变更。

这些是 D34 之前源码的 unsigned Simulator / repository 历史证据，不是当前源码、
signed Archive、Storefront、TestFlight 或真机验收。

## G1：首发裁剪、能力和隐私必须说同一件事

### 1.1 把 Family 真正排除在 1.0 用户路径外

2026-07-29 的仓库内裁剪已经完成以下部分：

- 产品合同明确 Family 和 Care+ 不进入 1.0。
- Solo 编译能力与 runtime gate 双重关闭 Guardian；即使误填运行配置也不能开启。
- 设置入口、sheet、目标容器、crafted deep link、通知路由、APNs 注册/处理及默认
  outbox 均在 gate 关闭时不可达或 fail-closed。
- Solo AppDelegate 不编译 APNs 注册成功、注册失败或远程通知接收 callback；runtime
  `responds(to:)` selector 契约已通过，优化版 unsigned Release 的
  `OhanaCloudSharingAppDelegate` class-specific method metadata 也不实现这 3 项
  callback。
- 旧版本机 `SafetyContact` 仍可在不启动 Guardian 服务时清理。
- App privacy manifest 已移除 Family-only collected-data 声明。

产品负责人已授权且源码清理已完成：主 App source entitlement 不再包含
Sign in with Apple 或 APNs，源码 `Info.plist` 不再包含 `OHANAGuardian*` 键或
`remote-notification`。该结论只关闭仓库源码阻塞，不替代 Developer Portal、
distribution profile、最终 signed Archive 或 Privacy Report 证据。

上架 1.0 前：

- [x] Family section、route、SKU 和任何激活路径在 Solo runtime 中不可达；本机 Zen
  提醒可以保留。
- [x] 仓库内九语言商店草案和审核备注不宣传 Family。
- [x] 主 App 源码 entitlement 只保留实际需要的能力：

  - 主 App：HealthKit、CloudDocuments、生产 App Group。
  - Widget extension：与主 App 完全相同的生产 App Group。
  - 不包含 CloudKit、Associated Domains、Sign in with Apple 或 APNs。

- [x] 源码 `Info.plist` 只保留 `fetch/location`，没有 Guardian keys 或
  `remote-notification`。
- [ ] 检查 Developer Portal 与 Solo 1.0 App Store distribution profiles 只授予上述
  发行能力。
- [ ] 检查最终 Archive 内生成的 `Info.plist` 和签名 entitlement；不得重新引入
  Sign in with Apple、APNs、`remote-notification`、Guardian keys、CloudKit 或
  Associated Domains。
- [x] 审核备注草案明确写 Family 不属于本次提交；这不能替代真正的发行裁剪。

这样也能降低 Apple 审核指南 2.3.1 对 hidden/dormant/undocumented features 的风险。

### 1.2 修复当前隐私清单漏报

当前 `ZenHomeView` 使用 `ProcessInfo.processInfo.systemUptime` 测量手势内事件耗时。
源码 privacy manifest 已补齐对应 required reason。

- [x] App privacy manifest 已增加
  `NSPrivacyAccessedAPICategorySystemBootTime` / `35F9.1`。
- [x] 优化版 unsigned Release 已分别嵌入主 App 与 Widget privacy manifest；
  两者都声明不跟踪、无 collected-data 条目，Widget 保留
  `FileTimestamp` / `C617.1`。
- [x] 依据 Xcode 26.6 / iOS 26.5 SDK 与 Apple 2026-08-04 当前清单，重新扫描源码、
  主 App/Widget Archive 可执行文件及依赖：主 App 只使用已声明的 User Defaults、
  File Timestamp、System Boot Time；未发现 Disk Space、Active Keyboards 或第三方
  package/framework。
- [x] 从 commit `64e3d6ba0` 的本地 development-signed Release Archive 生成并人工
  核对 Xcode Privacy Report；报告是有效的一页空白 PDF，与主 App/Widget 的
  `NSPrivacyTracking=false`、空 `NSPrivacyCollectedDataTypes` 一致。
- [ ] 从最终 App Store distribution-signed Archive 再生成一次 Privacy Report，确认
  内容与上述 RC 预检一致；不能以 development profile 代替最终分发证据。
- [x] Widget 自己的 `PrivacyInfo.xcprivacy` 已移除未使用的
  `FileTimestamp/C617.1`，当前声明无 tracking、无 collection、无 required-reason API；
  `OnlineFeatureGateTests` 13/13 与资源完整性审计通过。

Apple 自 2024-05-01 起要求上传包为 required-reason API 提供获批理由；漏报会阻止
App Store Connect 接受提交。

### 1.3 统一隐私标签、manifest 和公开政策

- [ ] 先确定最终二进制是否真的只有 local Free / Personal。
- [ ] 如果 1.0 完整裁掉 Family 且没有数据传给开发者，再依据最终 Privacy Report
  判断 App Privacy 是否可回答 “Data Not Collected”；本机处理、StoreKit 由 Apple
  处理和用户主动分享不自动等于开发者收集。
- [ ] 如果最终包仍包含/启用 Family 数据流，则 App Privacy 必须披露 linked、
  non-tracking 的 User ID、Device ID、Purchase History、Product Interaction，
  不能回答 “Data Not Collected”。
- [x] 仓库内隐私政策草案、`NSPrivacyCollectedDataTypes` 和审核备注已统一为
  Free / Personal 无开发者数据收集。
- [ ] App Store Connect 隐私问卷与已发布公开政策
  使用同一最终口径。
- [ ] 选定唯一公开政策文本。当前仓库内政策和公开 GitHub 页面不是同一版本；提交前
  发布最终文本并匿名打开验证。
- [ ] 真机确认 Settings 内“隐私政策”能打开；“获取支持”只打开邮件撰写，不自动附带
  日志、截图或用户资料。

当前公开页面可用作候选：

- 隐私政策：<https://github.com/VeitL/Ohana/blob/main/docs/privacy-policy.md>
- 支持页面：<https://github.com/VeitL/Ohana/blob/main/docs/support.md>

App Store Connect 的 Support URL 必须是公开 HTTPS 页面；App 内保留 `mailto:` 支持
入口没有问题，但不能把 `mailto:` 当作商店的 Support URL。

### 1.4 权限、后台和出口合规

- [ ] 逐项证明 Camera、Photos、Location、Background Location、Notifications、
  Face ID、HealthKit、iCloud Drive 都有可达功能和准确 purpose string。
- [x] 西/葡/法/日/韩/意六种语言的系统权限文案已补齐；冻结 RC 仍须在真机核对
  实际系统弹窗，并完成专业语言审校。
- [ ] 后台定位只在活跃遛狗期间持有；本地提醒不依赖 remote notification。
- [ ] 对 AES-GCM、PBKDF2、CryptoKit/CommonCrypto 以及所有依赖完成一次正式出口
  合规判断。当前 `Info.plist` 没有 `ITSAppUsesNonExemptEncryption`。
- [ ] 如果 Apple 问卷确认无需文稿，再设置
  `ITSAppUsesNonExemptEncryption = NO`；不要未经判断直接填 `NO`。

## G2：关闭 Free / Personal 真实 Storefront

本地 `.storekit`、模拟价格和 Unit test 不能替代 App Store Connect。

### 2.1 商务与商品配置

- [ ] Apple Developer Program membership 有效。
- [ ] Paid Apps Agreement 为 Active。
- [ ] 税务表、银行资料和付款信息全部有效。
- [ ] 在同一 Personal subscription group 创建并核对：

  - `com.guanchen.li.Ohana.personal.monthly`
  - `com.guanchen.li.Ohana.personal.yearly`
  - `com.guanchen.li.Ohana.personal.lifetime`

- [ ] 先由账号持有人确认 legacy `com.guanchen.li.Ohana.supporterPack` 是否有真实
  生产购买历史；若有，停止新售但保持 `currentEntitlements` 与 Restore 可恢复；
  若无，不重建 SKU，并删除审核材料中的历史恢复承诺。
- [ ] Family Yearly 不进入本轮 submission，也不可售。
- [ ] Monthly / Yearly / Lifetime 的类型、价格、地区、税务类别和 Family Sharing
  与 [`Entitlement-logic.md`](specs/Entitlement-logic.md) 一致。
- [ ] Yearly 的 14 天 introductory offer 只面向 StoreKit 判定符合资格的人；
  App 不硬编码资格或假价格。
- [ ] 九种语言完成商品名称、说明、订阅组显示名和 IAP Review Notes。
- [ ] 为订阅和 non-consumable 准备审核截图，并写清 App 内购买入口与 Restore 入口。
- [ ] 首个 auto-renewable subscription、首个 non-consumable 和 App 1.0
  放进同一审核 submission。

### 2.2 Sandbox / TestFlight 验收矩阵

- [ ] 真实商品加载、Storefront 货币/价格、商品不可用和重试。
- [ ] Monthly、Yearly trial、Yearly 付费、Lifetime。
- [ ] verified、unverified、pending、取消、失败、重复点击。
- [ ] `Transaction.updates`、冷启动、前后台、离线和重新联网。
- [ ] `AppStore.sync()` 与自动 `currentEntitlements` 恢复。
- [ ] 同一 Sandbox 账号在第二台 iPhone 自动恢复和手动 Restore。
- [ ] trial 结束、订阅过期、账单状态、退款和 revocation。
- [ ] 若确认 legacy Supporter 有真实生产购买历史，在第二设备恢复为 Personal
  Lifetime；若无，记录“不重建 SKU / 不提交恢复声明”的处置。
- [ ] 所有失败/降级路径都保留本机数据、已有超额对象、手动导出、关键提醒、
  纪念档案和椰子商店所有权。
- [ ] Personal 页面在九语言、Dynamic Type、VoiceOver、Voice Control、Switch
  Control、深浅色、RTL 下可完成购买和恢复。

付费页已经实现 StoreKit 动态价格、Restore、管理订阅、隐私政策和标准 EULA 入口；
最终仍要用真实 Storefront 逐项验收。对外只列当前 build 已实际交付的 Personal 能力。

## G3：签名 App、Widget 和 Live Activity

### 3.1 Developer Portal 与 distribution profile

- [ ] 注册并核对 App ID：`com.guanchen.li.Ohana`。
- [ ] 注册并核对 Widget ID：`com.guanchen.li.Ohana.Widgets`。
- [ ] 注册生产 App Group：`group.com.guanchen.li.Ohana`。
- [ ] 将同一生产 App Group 同时关联主 App 与 Widget extension。
- [ ] 核对 `iCloud.com.guanchen.li.Ohana` 仅使用 CloudDocuments，不启用 CloudKit。
- [ ] 核对 HealthKit、iCloud、App Group 和所有 provisioning profile 精确匹配。
- [ ] 为 App Store distribution 重新生成 profile；不能沿用旧 development Archive。

`group.com.guanchen.li.Ohana.LocalDevice` 只属于本地设备开发 target，不是 App Store
1.0 的 distribution App Group。

### 3.2 最终 Archive 检查

- [ ] 用冻结的 RC 源码生成 WMO signed Archive。
- [ ] App 与 Widget 的版本/build、deployment target、bundle ID 和 App Group 一致。
- [ ] `UIDeviceFamily = [1]`；不包含 iPad app、watchOS app 或 complication。
- [ ] 主 App 只内嵌预期的 `OhanaWidgets.appex`。
- [ ] 对主 App 和 extension 分别执行 strict codesign / entitlement 检查。
- [ ] Archive 不含 FinderInfo、ResourceFork、quarantine、测试 fixture、Debug
  菜单、seed/reset 参数入口或测试 StoreKit 配置。
- [ ] 检查最终 `Assets.car`、IPA 下载/安装体积和启动时间。当前图标已是
  1024×1024、无 alpha；xcassets 源体积接近仓库 review threshold，仍需看最终产物。

### 3.3 真机系统表面

- [ ] Personal Widget 的 small、medium、accessory rectangular。
- [ ] Free、Personal、降级、过期、空、stale、锁屏、reset、App Group 不可用。
- [ ] Widget 最多三项，且不泄漏自由文本任务、健康、用药、已删除或已离世对象。
- [ ] 冷/热启动 typed deep link 到正确页面，非法 URL 安全失败。
- [ ] Dynamic Island 支持机完成 walk 开始、暂停、继续、距离/便便更新、锁屏、
  后台、杀进程重开、deep link 和结束。
- [ ] 始终只有一条 walk session 和一个 Live Activity；结束后无残留。
- [ ] Low Power、Reduce Motion、长语言、Dynamic Type 和锁屏隐私通过。

## G4：App Store Connect 资料包

仓库内已新增 [`app-store-connect-submission-package.md`](app-store-connect-submission-package.md)，
包含九语言 App/IAP 元数据、审核备注、截图采集计划及合规填写边界。它是可复制草案，
不能证明 App Store Connect 外部状态已经完成。

### 4.1 App 记录与产品页

- [x] App name（2–30 字符）、subtitle（最多 30 字符）九语言草案。
- [ ] Primary language、Bundle ID、不可变 SKU、Apple ID。
- [ ] Primary/secondary category。Ohana 不是诊断产品；若选择 Health & Fitness
  或 Medical，完成 Apple 要求的 regulated medical device declaration。
- [x] Description、keywords（最多 100 bytes）、promotional text 决策九语言草案。
- [x] Support URL、Privacy Policy URL、Marketing URL 决策草案。
- [x] Routing App Coverage 记为 Not Applicable；Solo 1.0 的 App Store Server
  Notifications URL 保持留空。
- [x] 1.0 不提供 App Preview，不启用 Promoted In-App Purchases 或 win-back offers；
  仍须为三个 Personal 商品分别上传 App Review Screenshot。
- [ ] 2026 copyright owner。
- [ ] 内容权利声明：头像、插图、图标、字体、品牌和任何第三方素材都有分发权。
- [ ] 销售地区、可用日期、发布方式、Primary Language、Privacy Choices URL、
  Accessibility URL，以及是否允许 iPhone App 在 Apple silicon Mac / Apple Vision Pro
  上分发。
- [ ] 创建 App 记录后核对正式 Apple ID；决定是在 1.0 中启用 Rate App，
  还是明确保持隐藏。

首个版本没有 “What’s New”；以后更新才需要。

### 4.2 年龄、隐私和地区合规

- [ ] 完成新版年龄分级问卷；Unrated 不能发布。
- [ ] 回答 2026 年新版问题以及当前已出现的 social media capability 问题。
- [ ] 不要误选 Made for Kids；一旦经审核批准为 Kids Category，后续不能撤销。
- [ ] 如实回答健康/医疗信息、位置、购买和用户生成内容相关项。
- [ ] 完成 App Privacy 问卷并 Publish。
- [ ] 完成 DSA trader/non-trader 自我评估；如在 EU 以 trader 身份分发，验证公开
  地址、电话、邮箱及付款资料。
- [ ] 完成出口合规问卷和任何要求的文稿。
- [ ] 对每个首发 storefront 处理当地许可；不准备的地区先不开放。

### 4.3 截图与审核素材

- [ ] 按提交填写包的六场景计划，为每个必需 iPhone 类别上传 1–10 张真实 App UI
  截图；无 alpha、无真实用户资料。
- [ ] 优先准备 6.9-inch 规格。Apple 当前接受的竖屏尺寸包括
  1260×2736、1290×2796、1320×2868。
- [ ] 因产品是 iPhone-only，不上传也不宣传 iPad / watchOS。
- [ ] 按提交填写包 §6 的六场景执行公开截图；三个 Personal 商品另行提供各自必需的
  IAP Review Screenshot。
- [ ] Widget / Live Activity 只有在最终 signed-device 证明完成后，才由负责人决定
  是否加入公开截图；只展示当前 build 可达内容。
- [ ] 九语言产品页或首发目标市场的本地化元数据经过母语/专业校对。
- [ ] App Review 联系人姓名、邮箱、电话真实有效。

## App Review Notes 单一来源

唯一可复制版本位于
[`app-store-connect-submission-package.md` §5.1](app-store-connect-submission-package.md#51-app-review-notes英文原样粘贴)。
提交前按最终 UI 路径和能力重新核对，控制在 4,000 字符内，并同时记录 UTF-8 bytes。

源码 G1 清理已经完成。只有最终 signed Archive 与 Portal/profile 也确认不含
Family 入口、Sign in with Apple、APNs、`remote-notification` 或 Guardian keys
后，才可复制该备注；若这些能力在最终包中重新出现，应修正发行包，而不是用审核文字
掩盖差异。

## G5：最终验证顺序

只对冻结后的同一 RC 执行，失败后修复会生成新 RC，并重跑受影响门。

### 5.1 仓库与 Simulator

```bash
git diff --check
scripts/dev-check-changed.sh

# 当前发行裁剪、D17/D28、隐私、路由与本地 Family 回归。
# --keep-success-result 只保留一个 success/latest.xcresult。
scripts/xcode-test.sh --keep-success-result \
  --only-testing OhanaTests/OnlineFeatureGateTests \
  --only-testing OhanaTests/AppRouteCoordinatorTests \
  --only-testing OhanaTests/SafetyContactCommandServiceTests \
  --only-testing OhanaTests/GuardianSafetyPolicyTests \
  --only-testing OhanaTests/GuardianSafetyPersistenceTests \
  --only-testing OhanaTests/TaskCenterSnapshotBuilderTests \
  --only-testing OhanaTests/HouseholdStarterJourneyServiceTests \
  --only-testing OhanaTests/OnboardingJourneyCoordinatorTests \
  --only-testing OhanaTests/StarterGiftServiceTests \
  --only-testing OhanaTests/MemberProfileCompletenessPolicyTests \
  --only-testing OhanaTests/MemberCreationServiceTests \
  --only-testing OhanaTests/TaskCenterSystemJourneyGuideTests \
  --only-testing OhanaTests/AppExperienceControllerTests \
  --only-testing OhanaTests/ZenPresentationTests \
  --only-testing OhanaTests/FamilyTaskCollaborationTests \
  --only-testing OhanaTests/FamilyTaskPlanMaterializationTests \
  --only-testing OhanaTests/FamilyTaskPlanSeriesTests \
  --only-testing OhanaTests/FamilyTaskRecurrenceRuleTests \
  --only-testing OhanaTests/FamilyTaskV95CompatibilityTests \
  --only-testing OhanaTests/CalendarFamilyTaskProjectionTests

# RC：全仓静态、完整 Unit、顺序完整 UI
scripts/release-hardening-check.sh --with-ui

# 优化 Release 编译；不替代签名或真机
scripts/build-release-fast.sh

# 当前既有数据只运行一次最终 Release overlay
scripts/run-dogfood-simulator.sh --require-ready
scripts/run-dogfood-simulator.sh
scripts/run-dogfood-simulator.sh --require-ready

# 签名 WMO Archive；该命令不上传
scripts/archive-release-local.sh
```

记录每条实际命令、结果、xcresult、源 SHA 和失败处置。不要把历史不同源码的测试数合并成
“当前全通过”。

本次 2026-08-03 campaign 已按产品负责人要求在 9 个 shard 完成后只精确复验两个
失败 selector；不要为了把 `130/132 + 2/2` 改写成一次性 `132/132` 而重跑完整
campaign。只有 App、UI-test 或 build 输入再次发生相关变化，才重新执行受影响的证明。

### 5.2 同一签名 build 的真机验收

以 [`release-true-device-test-plan.md`](release-true-device-test-plan.md) 更新后的
清单为执行源，至少关闭：

- [ ] 最小支持实体 iPhone + 当前 Dynamic Island iPhone 的同 build 核心 smoke。
- [ ] clean install 的 Standard 和 Zen；已有数据覆盖安装与升级回读。
- [ ] 通知权限、前台/banner/锁屏、Focus/DND、点击与三个 action。
- [ ] Memorial 标记/撤销、未来通知取消/恢复和历史只读。
- [ ] HealthKit Exercise/Stand/活动环/Recent Workouts、拒绝、撤销、重启。
- [ ] 30–60 分钟锁屏遛狗、后台定位、能耗、热状态和最终路线。
- [ ] Widget / Live Activity / Dynamic Island 全矩阵。
- [ ] PhotosPicker、Camera、Files、真实附件、500 图长滚和内存。
- [ ] 受限自动备份、iCloud 不可用、reset 删除失败、重试恢复。
- [ ] R6b 独立硬门：同一签名 Release 的加密设备备份 / 恢复证明
  Application Support、Human Note attachment 与 App Group Personal Widget
  投影均未恢复；未通过即 NO-GO。
- [ ] VoiceOver、Voice Control、Switch Control、最大 Dynamic Type、Reduce Motion、
  深浅色、RTL、德语长文案和触感。
- [ ] 最后一次 RC 级正常 UI 全路径冒烟。

破坏性 clean install/reset/restore 流程只用 disposable 测试设备或数据；不要在
`iPhone 17 Dogfood` 上执行。

### 5.3 上传与提交

- [ ] 先把同一 RC 上传 TestFlight，完成内部真机和 Sandbox 最终确认。
- [ ] 在 App Store Connect 选择正确 build，核对 processing 后的 entitlement、
  privacy、设备族和 build size 警告。
- [ ] 将 App 1.0、Personal subscription group、Monthly、Yearly、Lifetime 以及首个
  non-consumable 放入正确 submission。
- [ ] 核对所有状态为 Ready for Review，没有 Missing Metadata、协议或合规阻塞。
- [ ] 按提交填写包 §2.3 中负责人确认的 Version Release Settings 配置；Manual
  仅是保留审核后控制点的建议，不是已批准决定。
- [ ] 点击 Submit for Review 前，由另一人完成一次“四眼复核”：
  build、商品、价格、截图、隐私、年龄、地区、审核备注和联系信息。

## Go / No-Go 签字页

只有下列全部为“是”才能提交：

| 问题 | 是/否 | 证据 |
| --- | --- | --- |
| 当前 commit 的 P0/P1 已重新盘点且所有首发可达项关闭/明确处置？ |  |  |
| Standard/Zen 当前 D17/D28 在 Unit、UI、Dogfood/upgrade 中通过？ |  |  |
| Family 在 1.0 入口、SKU、capability、privacy 和宣传上都不可达？ |  |  |
| Required Reason API、Privacy Report、App Privacy 和公开政策一致？ |  |  |
| Personal 三商品、九语言、Sandbox、第二设备和退款/撤销通过？ |  |  |
| App Group、Widget、签名 entitlement 与 Developer Portal 完全匹配？ |  |  |
| 同一 distribution build 完成最小设备、当前设备、R0–R7，并独立通过 R6b 加密系统备份 / 恢复硬门？ |  |  |
| 元数据、截图、年龄、DSA、出口合规、支持 URL 与审核备注完整？ |  |  |
| Archive、TestFlight 和待提交 build 是同一 RC 身份？ |  |  |
| 已记录已知限制、回滚/下架方案和首发监控负责人？ |  |  |

Release owner：____________

复核人：____________

Commit / build：____________

Archive SHA-256：____________

签字日期：____________

## 上线后 48 小时

- [ ] 验证每个首发 storefront 的产品页、价格、IAP 和支持/隐私链接。
- [ ] 监控 App Store Connect crashes、hangs、launch、energy 和退款信号。
- [ ] 用生产 Apple 账号验证购买/恢复，但不为测试制造真实用户数据。
- [ ] 检查支持邮箱和 App Review 消息；高风险问题保留复现 build 与设备信息。
- [ ] 如发现数据安全、隐私、购买交付、启动或持久化问题，停止扩大投放并准备 hotfix；
  不以删除用户数据作为普通恢复手段。

## Apple 官方依据（核对日 2026-07-29）

- [Upcoming Requirements：Xcode 26 / iOS 26 SDK](https://developer.apple.com/news/upcoming-requirements/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App information fields](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Required Reason API values](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)
- [Paid Apps Agreement](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)
- [EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
