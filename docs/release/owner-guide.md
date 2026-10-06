# 一个人也能执行的发布测试指南

负责人：产品负责人；源码核对：2026-09-25。先读[控制中心](README.md)和[入门与进度](getting-started.md)，再按[测试策略](test-strategy.md)和[手工手册](manual-device-test-runbook.md)操作。Ohana 1.0 是本机 Solo Free / Personal；本机 Human 档案不是远程账号，Family 守护仍在发布门外。

## 从一行代码到 App Store

```text
改动 → 小范围测试/审计 → 修复并复测 → 冻结 commit
     → 候选版本 RC → 完整 Unit + UI 分片 → 同一 RC 的 Release/Distribution Archive
     → 真机 + 第二设备 + StoreKit Sandbox → TestFlight 反馈
     → 隐私/元数据/审核资料核对 → GO 决定 → App Store Connect 提交
     → 上线后观察；若修复代码，重新冻结 RC
```

**Release Candidate（RC，发布候选）**是准备提交的一个具体版本：固定 commit、版本/build、签名 Archive 与测试结果。冻结 commit 是为了回答“测试的究竟是不是将要提交的代码”。在 RC 后改一行代码，先前能受影响的结果就要重新核对，通常另起 RC。版本号 `1.0` 给用户理解功能版本；build number `1` 给 Apple 区分同版本的不同二进制。当前项目源码显示 `1.0 (1)`，不是 App Store Connect 已有此 build 的证明。

`Debug` 是开发配置，方便诊断；`Release` 是优化后配置。Simulator 是 Mac 上的虚拟 iPhone，能做稳定 UI 流，却不能证明真实通知交付、后台定位、HealthKit、相机、能耗、锁屏或 App Group 签名。**development-signed** 包用于开发设备；**Distribution-signed** 包用发布证书和配置描述文件（provisioning profile，列出 App ID 与允许能力的签名材料）面向分发。**Archive** 是 Xcode 生成的带构建内容与元数据的归档，不等于已装到手机，也不等于已上传 App Store Connect（Apple 的应用管理后台）。

## 测试词汇与 Ohana 的实际用法

| 术语 | 简明解释与实例 |
| --- | --- |
| Unit test 单元测试 | 直接检验一条规则：椰子余额是否与账本一致、Free 配额是否正确。最快；不证明按钮可用。 |
| Integration test 集成测试 | 检验命令、SwiftData 和派生状态一起工作：完成默认“补充饮水”计划会产生一条 250 ml watering 事实，重放不重复写；喂食后 Event、库存、任务、奖励和 revision 也要一致。使用隔离数据容器。 |
| Migration test 迁移测试 | 用旧版本磁盘 store 打开新 schema，核对旧照护/附件仍能读；当前源码到 V99。不能拿全新安装代替。 |
| UI test 界面自动化 | XCUITest 启动 App，点首启、Task Center、喂食等并看最终界面；仓库按 9 shard 分组。XCTest 是 Apple 测试框架，XCUITest 是其中操控 UI 的方式；Swift Testing 主要用于 Unit/Integration。 |
| Smoke test 冒烟测试 | 少量核心路径先判断“能不能继续测”：首启到首页、创建对象、保存一次事实、打开 Settings。 |
| Regression test 回归测试 | 修复后重跑受影响路径，并在 RC 跑完整范围，防止旧功能退化。 |
| Performance test 性能测试 | 固定设备、数据和起止点测启动、卡顿、内存或能耗；密集历史和缺失图片是 Ohana 的关键样本。Instruments 是 Xcode 的性能分析工具；MetricKit 可提供设备上的聚合诊断，不能自动替代一次可复测的现场。 |
| Manual exploratory test 人工探索 | 人按目标操作并观察异常，不预设每个点击；记录设备/build/步骤/预期/实际。 |

> 新手理解：按钮被点到只证明入口可触达。一次喂食必须再核对可见历史、持久 Event、库存、任务、提醒、椰子账本，以及重启后读回。哪些副作用适用，以[产品事实流](../specs/product-foundation.md)为准。

## 商店、隐私与发布术语

- **StoreKit configuration testing**：Xcode 使用仓库的 [`Ohana.storekit`](../../Ohana/Configuration/Ohana.storekit) 模拟本地商品/交易，适合早期及失败分支；它不查询真实 App Store Connect 商品。
- **StoreKit sandbox**：Apple 的测试交易环境，使用 Sandbox Apple Account（沙盒账号）和 App Store Connect 的真实测试商品资料，不收真实费用。**TestFlight** 是 Apple 分发 beta build 和收集反馈的服务；TestFlight 购买也走 sandbox，但仍须核对产品、账号和恢复状态。见 [Apple 的环境说明](https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox)。
- **TestFlight build / App Store build**：TestFlight build 是 App Store Connect 处理后供 beta 测试的上传二进制；负责人可将同一个 build 选为 App Store 审核版本。记录 build number 和 ASC build ID，确保测试、Archive、TestFlight 与待审 build 指向同一包；换了二进制就不能沿用受影响的 PASS。
- **privacy manifest**：App/扩展的 `PrivacyInfo.xcprivacy` 声明必需原因 API、追踪和收集情况；**Xcode Privacy Report** 从最终 Archive 汇总清单与依赖，是填写 App Store **App Privacy**（隐私标签）时的一项证据。报告不能代替实际数据流审计。Ohana 两个 manifest 在 [App](../../Ohana/PrivacyInfo.xcprivacy)与 [Widget](../../OhanaWidgets/PrivacyInfo.xcprivacy)。
- **entitlement**：签入二进制的系统能力声明，如 HealthKit、CloudDocuments、App Group；源码文件中的值还须与 Developer Portal、profile 和最终签名包一致。`Ohana/Ohana.entitlements` 与 Widget entitlement 共享生产 App Group；配置存在不等于 Portal 已批准。
- **GO / CONDITIONAL GO / NO-GO**：本轮能提交、在明确非关键条件下可提交、不能提交。不是百分比。缺真机隐私/数据安全、Distribution 签名、真实购买恢复或审核必需资料时是 NO-GO。
- **证据与追溯**：每条 `PASS` 指向 Test ID、RC 身份、环境、步骤、结果和可找回的脱敏记录。日志或截图需能让另一个人复核，却不含私人健康、精确位置、收据或账号 ID。

## 谁能做什么

| 工作 | Codex | 负责人/设备 |
| --- | --- | --- |
| 阅读源码、找现有测试、选择窄命令、运行仓库审计与获准的本机测试、整理脱敏结果 | 可完成并报告实际命令 | 复核关键判断 |
| Dogfood 既有用户检查 | 仅按[保护规则](../dogfood-testing.md)运行正常 UI、守住 store 身份 | 无需交出真实数据 |
| Distribution 签名、Developer Portal/App Group/profile、Archive 和上传 | 可准备审查清单；执行签名/上传需负责人明确授权 | 账号持有人控制证书、profile、上传与提交 |
| 真机权限、通知、HealthKit、相机、锁屏定位、Energy、VoiceOver | 可逐组指引与记录 | 在真实设备上观察；不得用 Simulator 代签 |
| 第二设备恢复及 R6b 加密设备备份 | 可给安全步骤与比较表 | 仅在可擦除的测试 iPhone 上执行，不动个人主力机数据 |
| App Store Connect 元数据、产品、Sandbox 测试者、TestFlight、审核提交 | 可核对准备稿与报告缺口 | 账号持有人/受邀测试者操作并提供脱敏结果 |

受保护的 `iPhone 17 Dogfood` 只用于已建立的合成用户的正常、非破坏性升级读回。**永远不要**在它上面做 XCTest、首启清空、重置、卸载、恢复、直接写 store/defaults、测试 seed、Debug 经济工具或成员删除。首启/删除/失败恢复在一次性 `iPhone 17 Tests`；真机第二设备恢复用独立测试数据。详见[环境矩阵](test-strategy.md)。

## 和 Codex 一起测试

1. 告诉 Codex 本次 RC 身份或“还没冻结”，以及要测的 Test ID；Codex 先确认前置条件和设备。
2. Codex 一次只发[手工手册](manual-device-test-runbook.md)中的一小组步骤，明确何时停止。你按真实界面操作，回复“看到什么”，不需要猜是否通过。
3. 若失败，描述最后成功一步、错误文案、重试是否变化；Codex 记录缺陷，先保留现场。别在同一手工测试会话里边测边修，否则 RC 身份会混乱。
4. 若成功，Codex 只对本次执行层写 `PASS`，再列下一组；发布判断在[轮次记录](runs/current-candidate.md)汇总。

常见“vibe coding”发布失误：把源码有测试当测试已跑、把重试通过当首轮无故障、用新装覆盖旧用户升级、把本地 `.storekit` 当真实商品、用 development Archive 当 Distribution、对不同 commit 的绿色结果拼接、把截图里的私人资料直接发给 AI、一次修很多无关文件后丢失根因。遇到任一情况，停在当前 Test ID，把证据/缺口写清，再决定下一步。

## 速查词表

`RC` = 固定源码和产物的发布候选；`SHA` = Git 提交或文件内容的哈希身份；`xcresult` = Xcode 测试结果包；`shard` = UI 测试分片；`Archive checksum` = 归档内容指纹；`App Group` = App 与 Widget 共享容器能力；`Storefront` = App Store 销售地区/商品页面；`provisioning profile` = 签名授权材料；`rollback` = 撤回发布或回到已知安全状态，不能自动恢复已迁移的用户数据库；`hotfix` = 另起 RC 的聚焦紧急修复。
