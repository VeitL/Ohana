# Ohana 1.0 App Store 发布执行手册

负责人：产品负责人；源码核对：2026-09-25；Apple 流程来源复核：2026-09-24。先读[控制中心](README.md)与[当前候选](runs/current-candidate.md)。本文件按 Apple 当前[上传/选包/提交说明](reference-sources.md)编排操作；产品范围以[产品基石](../specs/product-foundation.md)为准；仓库现有[上架准备清单](../app-store-launch-readiness-checklist.md)拥有 G0–G5 细目，[App Store 文案包](../app-store-connect-submission-package.md)拥有各语言元数据草稿，[真机计划](../release-true-device-test-plan.md)拥有 R0–R7。不要复制旧草稿为实际 ASC 状态。

当前源码可核实：`1.0 (1)`、主 Bundle ID `com.guanchen.li.Ohana`、Widget `com.guanchen.li.Ohana.Widgets`、iPhone-only / iOS 26.2+、App/Widget 共享 `group.com.guanchen.li.Ohana`、HealthKit、CloudDocuments、`fetch/location` 后台模式、App 与 Widget privacy manifest、三个 Personal SKU 与旧 Supporter 恢复路径。来源：[project](../../Ohana.xcodeproj/project.pbxproj)、[App entitlement](../../Ohana/Ohana.entitlements)、[Widget entitlement](../../OhanaWidgets/OhanaWidgets.entitlements)、[Info.plist](../../Ohana/Info.plist)、[商品目录](../../Ohana/Features/SupporterPack/SupporterPackCatalog.swift)。这些是 `SOURCE VERIFIED`；Developer Portal、Distribution profile、ASC 产品、签名 Archive、商店地区与价格均 `UNKNOWN`，不能声称已完成。Family 商品/守护仍在 1.0 门外。

下列每行的结果填入[正式轮次模板](runs/_template.md)。`阻断=是` 表示缺失或 FAIL 时本次 `NO-GO`；“条件”须由负责人说明为何不影响核心与合规。每步记录 actor、前置、动作、PASS、证据及失败下一步。

## A. 冻结源码与本地门

| ID / 责任 | 前置与具体动作 | PASS 与证据 | 失败处理 / 阻断 |
| --- | --- | --- | --- |
| AS-01 范围；负责人+Codex | 读产品 D4/D25/D31 和当前 OnlineFeatureGate；列出 Free/Personal 可达 UI 与 Family 关闭边界，冻结 1.0 规模、地区、计划商品 | 1.0 不出现 Ohana 登录、远程协作或 Family 购买；范围表和源码引用入轮次 | 发现可达 Family/能力漂移先修并换 RC；是 |
| AS-02 commit；Codex | `git status --short`、`git rev-parse HEAD`、`git branch --show-current`；确定 RC 号，记录干净树、SHA、时区；提交/分支等须负责人批准 | 冻结 SHA 与后续构建一致；Git 输出 | 脏树或不明文件先分清来源；是 |
| AS-03 版本；负责人+Codex | 从 project/bundle 核对 `MARKETING_VERSION` 与 build number；同一 App Store version 的新二进制给新 build；核对 App/Widget 匹配 | 版本/build 与轮次、Archive、ASC 完全相同；配置及包 `Info.plist` | 不一致先修配置并换 RC；是 |
| AS-04 静态/Unit；Codex | 用当前脚本 `scripts/release-hardening-check.sh --static-only` 与 `scripts/xcode-test.sh --unit`；保留范围/结果 | 同一 SHA 全部必需审计与 Unit/Integration 0 未解释失败；命令摘要、xcresult/CI URL | 首次失败保留，按[缺陷政策](defect-and-rc-policy.md)定位；是 |
| AS-05 UI；Codex | 审 `scripts/ui-test-shards.tsv` 并执行 `scripts/test-ui-nightly.sh`；逐 9 shard；适用的既有用户稳定代码批次再走 Dogfood | 132 selector 清单无漏、完整 campaign receipt 逐 shard 通过；Dogfood 仅正常 UI 且封存身份 | 重试不抹首次失败；新源码换 RC；是（Dogfood 按适用性） |
| AS-06 Release 警告/性能；Codex+负责人 | 对冻结源码跑优化 Release 预检，审当前编译警告、密集数据与启动/内存；使用[性能政策](../performance-and-observability.md)固定场景 | 无未解释发行警告或关键性能回归；记录 Xcode/SDK、测量文件和阈值 | 产品警告/回归精确修复；是（非关键 advisory 可有条件处理） |

## B. 签名与最终 Archive

| ID / 责任 | 前置与具体动作 | PASS 与证据 | 失败处理 / 阻断 |
| --- | --- | --- | --- |
| AS-07 App ID/capability；负责人 | 在 Developer Portal 核对主 App 与 Widget 标识符、生产 App Group、CloudDocuments/HealthKit；与源码 entitlement、Info.plist 对照；不顺手打开未批准能力 | 两个 App ID/profile 授权范围与 Solo 1.0 一致，Family/APNs/Sign in with Apple/CloudKit sharing 不在发行包；脱敏 Portal 记录 | 不匹配时只修相关能力/配置，重新生成 profile；是 |
| AS-08 签名；负责人+Xcode | 有明确授权和有效 Distribution certificate/profile 后用 `scripts/archive-release-local.sh` 或 Xcode Organizer 生成面向 iPhone 的 Release WMO Archive；脚本会按机器可用身份自动签名，**不会保证签出 Distribution**，须检查真实签名/profile | App+Widget 严格签名、嵌入关系和配置正确；Archive 路径、签名身份、创建时间、version/build | 若仍是 Development 身份或 xattr/嵌入失败，保留日志并停止上传；是 |
| AS-09 产物身份；Codex+负责人 | 对同一 Archive 记录 canonical checksum/sha256、Bundle ID、device family、最低 OS、entitlements、`UIBackgroundModes`、资源、PrivacyInfo、测试开关/本地 StoreKit 文件是否误嵌入 | 包身份可复核，主/扩展 App Group 完全相同，Family/test 面不可达；校验输出入轮次 | 有变更须新 Archive/新 RC，所有受影响证据重做；是 |
| AS-10 Privacy Report；Xcode+负责人 | 从**最终 Distribution Archive** 在 Organizer 生成 Xcode Privacy Report；比对两个 manifest、依赖/required-reason API、实际收集与[隐私规则](../privacy-compliance.md) | 报告、checksum、Xcode/SDK、依赖审查与 ASC App Privacy 答案一致；不凭空断言“Data Not Collected” | 报告缺失或不一致先审数据流/manifest 再换包；是 |
| AS-11 加密出口；负责人 | 按[Apple export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)核对实际 CryptoKit/备份加密、第三方库与销售地区；正确回答 ASC 问卷并决定 `ITSAppUsesNonExemptEncryption`；当前 Info.plist 未见显式键 | 决策、问卷状态、必要文档/审批与最终包一致 | 不猜“豁免”；需要文档则先提交并等待审批；是 |

## C. 同一 build 的设备和购买验收

| ID / 责任 | 前置与具体动作 | PASS 与证据 | 失败处理 / 阻断 |
| --- | --- | --- | --- |
| AS-12 现有用户；负责人 | 同签名身份覆盖安装，不卸载，做旧用户冷启动/前后台恢复/媒体与照护读回；按[会话 2](manual-device-test-runbook.md) | 旧事实、计划、附件、钱包无丢失/重复；同 build 真机记录 | 迁移/恢复失败即 P0/P1，保护现场换 RC；是 |
| AS-13 真机矩阵；负责人 | 在最低支持 iPhone 或实际选定最小机型、当前 iPhone 跑 R0–R7：通知、HealthKit、相机/照片、锁屏遛狗、Low Power、Widget/Live Activity、VoiceOver；记 OS | 每项 Test ID 有真机观察且无隐私/业务缺陷；脱敏证据 | 缺设备为 `BLOCKED`，Simulator 不补签；是 |
| AS-14 第二设备；负责人 | 仅可擦除测试机，用合成数据验证 iCloud Drive 文件恢复、失败 rollback 及 R6b 加密**系统**备份/恢复排除 | 第二机上批准范围完整、排除范围不存在、失败不破坏旧数据；两设备/build 记录 | 无第二机或备份不安全即 `BLOCKED`；是 |
| AS-15 Widget/扩展；负责人 | 已验证生产 App Group 签名，同 build 装置主屏/锁屏 Widget、走深链、锁定/过期/删除状态；walk Live Activity/Dynamic Island | 投影新鲜且不泄漏私人内容，活动结束清理；截图脱敏 | App/Widget entitlement 或运行不符即修包；是 |
| AS-16 商品配置；负责人 | 在 ASC核对 Paid Apps Agreement、税务/银行、Personal Monthly/Yearly 同订阅组、Lifetime 非消耗型、九语言、地区/价格、trial 资格；旧 Supporter 仅确认有生产历史才保留恢复叙述 | 真实商品状态与代码 product IDs/本地化相符；脱敏 ASC 状态记录 | 任一缺失先配商品/协议；Family SKU 不可售；是 |
| AS-17 Sandbox；负责人+测试者 | 用专用 Sandbox Apple Account 在 development/TestFlight 同一 build 测成功、取消、pending、未验证、失败/离线、`AppStore.sync()` 恢复、试用转换/到期、Lifetime、退款/撤销、换机恢复 | 每种状态都有预期 entitlement，Free 基础数据保留，椰子/Shop 所有权独立；只记状态不记 receipt | 未验证交易不能授予权益；缺账号/商品 `BLOCKED`；是 |
| AS-18 TestFlight；负责人+ASC+测试者 | 上传获授权 build 后等处理，填写 beta 说明/反馈联系方式，先内部、需要时外部测试；收集反馈、崩溃/设备矩阵 | TestFlight build ID、安装设备与 RC identity 一致；必要反馈已归档/关闭 | 处理警告或 beta review 问题先解决；是（外部测试范围按实际决定） |

## D. App Store Connect 元数据与提交

| ID / 责任 | 前置与具体动作 | PASS 与证据 | 失败处理 / 阻断 |
| --- | --- | --- | --- |
| AS-19 App 记录；负责人 | 在 ASC核对 App ID/名称、定价/地区、Support URL、Privacy Policy URL、联系信息；按[文案包](../app-store-connect-submission-package.md)审版本真实范围 | URL 公共可达、Bundle/开发者/地区匹配；ASC 脱敏记录 | 无记录或 URL 错先修；是 |
| AS-20 产品页；负责人 | 逐语言核对 description、subtitle、keywords、What’s New 与真实 1.0；截图用**最终 build**的公开可达 UI，包含适用尺寸；IAP 审核图和 Review Notes/演示步骤也实走一次 | 九语言/截图/审核备注无 Family、测试数据、虚价或未实现 Shortcuts 声明；清单与截图索引 | 文案或截图不一致先修，必要时换包；是 |
| AS-21 法务问卷；负责人 | 根据最终 Archive/隐私报告核对 App Privacy、年龄评级、出口合规、EU DSA/内容权利等适用项；不把 HealthKit 本地处理说成开发者已收集 | 每项 ASC 答案与实际数据流/地区/政策一致，保存答题摘要 | UNKNOWN/误答不得提交；是 |
| AS-22 上传；负责人+Xcode/ASC | 明确授权后从最终 Distribution Archive 上传；保存传输/处理回执、警告、version/build 与 checksum；等待 ASC processing 完成 | 同一 build 可见且无未解决错误，身份对上 AS-09 | 上传失败/处理拒绝先定位签名/资源；是 |
| AS-23 选择待审包；负责人 | 在 ASC 1.0 页面 Build 区选择已处理的**同一** build，核对版本/build/上传时间；同版只能关联一个待审 build | 与轮次及 TestFlight/Archive 一致；ASC 页面记录 | 不同 build 需重做受影响验收；是 |
| AS-24 发布方式；负责人 | 首发 1.0 选择手动或自动发布并记录时间；Apple 的 phased release 适用于**版本更新**，本次首发不选。未来更新再判断监测/暂停安排 | 发布控制方式、地区、负责人、监测计划已记录 | 无操作能力时偏向手动；是（选择须明确） |
| AS-25 GO 决定；负责人 | 对照下方门禁、[当前轮次](runs/current-candidate.md)和缺陷；明确签收同一包。然后在 ASC `Add for Review → Submit for Review`，处理审核反馈 | 签收为 GO；ASC 状态/提交时间/审查消息入轮次 | 缺硬门维持 NO-GO；提交被退回先记录，再按改动决定新 RC；是 |
| AS-26 上线与回退；负责人+Codex | Apple 审核通过后按选定方式发布；核对商店页面、购买/恢复、崩溃与反馈，至少前 48 小时记录版本与时区；严重问题停止推广、联系 Apple/准备聚焦 hotfix | 发布状态与页面真实，关键路径无新 P0/P1；监测记录 | 不能靠覆盖旧二进制“回滚”迁移后的用户库；修复须新 commit/build/RC/验收；是（上线后行动） |

## 决策门

- **GO**：AS-01–25 的所有适用硬门 `PASS` 且附真实证据；无未关闭 P0/P1；提交的 Archive、TestFlight、真机、Sandbox、隐私报告与 ASC build 是同一 RC。
- **CONDITIONAL GO**：仅剩已知、可绕过、不触碰数据安全/隐私/核心照护/购买恢复/审核合规的 P2/P3；负责人在轮次写明条件、受影响 Test ID、观察期限与责任人。不能用它豁免没执行的硬门。
- **NO-GO**：任一硬门 `FAIL`/`BLOCKED`/`NOT RUN`，或首次失败未解释、证据属于旧 build。当前[候选](runs/current-candidate.md)就是 NO-GO。

> 新手理解：`scripts/archive-release-local.sh` 的“本地 Archive 成功”只关了一道构建/签名门；Apple 后续处理、TestFlight、真实商品、第二设备和审核资料各有独立收据。提交和签名是负责人明确授权的外部/发行操作，本手册并未替负责人执行它们。
