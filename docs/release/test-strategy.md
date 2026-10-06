# 测试策略：按风险选证明

负责人：产品负责人；源码核对：2026-09-25。规则取自[发布质量门](../release-quality-gates.md)、[仓库规则](../../AGENTS.md)和当前脚本。目标是证明“用户动作之后的持久事实、派生状态与最终界面一致”，并在最少的反馈时间内发现问题。照护、备份、迁移、购买、隐私、权限和后台比装饰性 UI 风险高。

## 目前实际存在的测试设施

- [`scripts/xcode-test.sh`](../../scripts/xcode-test.sh) 是本机唯一 Xcode 测试入口：默认 `OhanaTests/AppWorkloadPolicyTests`；例如 `scripts/xcode-test.sh --only-testing OhanaTests/QuickWaterCommandTests`，另有 `--unit`、`--ui`、`--full`。它解析 `OhanaUnitTests` / `OhanaUITests` scheme，在一次性 `iPhone 17 Tests` 上运行，并保护 Dogfood UDID。不要直接执行 `xcodebuild test`。
- 现有 [`OhanaUnitTests.xctestplan`](../../OhanaTests/OhanaUnitTests.xctestplan) 被主 `Ohana` scheme 引用；Unit 专用 scheme 本身列 `OhanaTests`。不存在另一个已核实的 RC/本地化/性能 Test Plan；按标签细分计划是**未来可选改进**，不得写成已有功能。
- [`ui-test-shards.tsv`](../../scripts/ui-test-shards.tsv) 当前有 **132 selectors / 9 shards**：`launch-onboarding` 26、`human` 43、`pet-care-core` 14、`pet-care-hygiene` 8、`pet-lifecycle-economy` 11、`calendar` 12、`plants` 14、`pet-long-session` 3、`performance-launch` 1。[`audit-ui-test-shards.sh`](../../scripts/audit-ui-test-shards.sh)查漏/重复；[`test-ui-shard.sh`](../../scripts/test-ui-shard.sh)逐组，[`test-ui-nightly.sh`](../../scripts/test-ui-nightly.sh)顺序运行并生成 receipt。132 是清单规模，不是当前 PASS 数。
- [CI workflow](../../.github/workflows/ci.yml) 的 `audits`、`lint`、`backend-guardian`、`build-test` 用于 push/PR；`ui-regression` 只在 schedule 或 `workflow_dispatch` 运行。配置是 SOURCE VERIFIED，当前远程 CI 是否成功 UNKNOWN。CI 注释提到 branch protection，但设置须在 GitHub 外部核实。
- `OhanaTests` 有隔离 SwiftData、备份原子恢复、V90 旧 store fixture、密集数据、StoreKit entitlement 等测试；`OhanaUITests` 用 XCTest 走真实 UI。测试声明的静态计数不等于实际执行/通过数。

## 测试金字塔与证据界限

| 层 | Ohana 例子 | 能证明 | 不能证明 |
| --- | --- | --- | --- |
| Unit（多、快） | 钱包余额/账本规则、Free 配额 | 输入输出与纯规则 | SwiftData 持久化、按钮或系统通知 |
| Integration（中） | `TaskActionCommandExecutorTests.localizedDefaultWaterRefillCompletionWritesOneWateringFact`、`DataBackupAtomicRestoreTests`、`QuickWaterCommandTests`、schema 旧 store | 命令事务、单条 watering 事实、幂等重放、失败回滚、读模型、迁移 | 用户真的找得到入口、真机权限 |
| 自动 UI（少、关键） | Human-first 首启、喂食、Task Center、删除防护 | 用户路径和可见持久读回 | 所有边界、真实硬件、Sandbox 交易 |
| 手工 Simulator/Dogfood | 新用户、破坏性流程 / 既有合成用户正常 UI | 路由、视觉、升级读回 | 通知交付、真实能耗、相机/HealthKit/后台 |
| 真机/TestFlight/外部账户 | 锁屏遛狗、Widget、StoreKit 恢复、第二设备备份 | 系统与分发边界 | 未测的设备/地区/账号 |

迁移使用旧 store fixture 与真实既有用户读回；备份要验证导出受限范围、加密文件、恢复失败原状态不变。性能先按[性能政策](../performance-and-observability.md)查高频路径，再用固定样本在 Release-like build 测冷启动、首页卡片、Task Center、长列表、内存和能耗。无障碍静态脚本只是下限；真机 VoiceOver、Dynamic Type、Reduce Motion、明暗色与长德语仍需观察。隐私与安全要比对 App/Widget manifest、最终 Archive 报告、实际数据流和 App Store 答案。App Store 门禁详见[发布手册](app-store-release-runbook.md)。

## 何时跑什么

`FAST` 约数秒到数分钟；`MEDIUM` 需要 Xcode/Simulator；`LONG` 包含全量分片、真机或平台等待。时间类别用于排期，不保证分钟数。命令只按当前脚本写；执行结果必须另记在轮次文件。

| 节奏 | 执行与环境 | 耗时 / 阻断 | 证据与失败处理 |
| --- | --- | --- | --- |
| 开发一个功能 | `scripts/dev-check-changed.sh`；若改水命令，用 `scripts/xcode-test.sh --only-testing OhanaTests/QuickWaterCommandTests`；其他功能从真实测试声明选 selector | FAST/MEDIUM；受影响行为阻断合并 | 命令、SHA、suite 结果；失败先复现该路径 |
| 提交前 | changed-file preflight；水命令高风险变更示例：`scripts/module-exit-gate.sh --test OhanaTests/QuickWaterCommandTests` | FAST/MEDIUM；失败阻断 | 范围、输出摘要、未解决 warning；不要无故跑全 UI |
| PR | CI `audits`、`lint`、`build-test`；`backend-guardian` 验证关闭的可选后端源码，不证明 1.0 在线能力 | MEDIUM；必需检查失败阻断 | CI URL 与 SHA；runner/SDK 不可用记环境阻塞，不算产品 PASS |
| Nightly | CI `ui-regression` 或获准本地 `scripts/test-ui-nightly.sh`，清单 9 shard 顺序执行 | LONG；发布候选前需修复失败 | JSON receipt、每 shard 结果；首次失败即调查，重试不抹除 |
| RC 冻结 | `scripts/release-hardening-check.sh --static-only`、`scripts/xcode-test.sh --unit`、`scripts/test-ui-nightly.sh`；适用时受保护 Dogfood；`scripts/archive-release-local.sh` 需明确签名授权 | LONG；核心硬门阻断 | 同 SHA 与产物 checksum，失败依[缺陷政策](defect-and-rc-policy.md)换 RC |
| TestFlight beta | 内部/外部测试者安装**同一** build，Sandbox 购买/恢复、现有用户升级、系统表面与反馈 | LONG；发布关键路径阻断 | build ID、脱敏观察、反馈 ID；失败归类产品/环境/测试 |
| 最终提交 | Distribution Archive、Privacy Report、ASC 元数据和 build 选择、真机/第二设备结果、GO 决定 | LONG；任何缺失硬门 NO-GO | [正式轮次模板](runs/_template.md)签收；新二进制重新核对 |
| 上线后 | App Store 状态、崩溃/反馈、StoreKit 购买恢复、后台/Widget 问题 | 持续；异常触发 hotfix | 时间与版本、脱敏问题 ID；不改写已发布记录 |

本机常用现有命令：`scripts/test-ui-shard.sh --list` 查看真实分片；`scripts/test-ui-shard.sh pet-care-core` 跑相关组；`scripts/test-ui-release-smoke.sh smoke` 跑首发入口；`scripts/release-hardening-check.sh --with-ui` 是获准的完整静态+Unit+UI RC 入口。`scripts/build-release-fast.sh` 是优化编译预检，既不签名也不证明运行。文档改动只做 `git diff --check` 与文档审计，不跑这些 app 命令。

## 环境边界

| 环境 | 安全操作 | 禁止/不能据此声称 |
| --- | --- | --- |
| `iPhone 17 Tests` 可抛弃 Simulator | Unit/Integration、UI、首启、删除、恢复、拒绝权限；需要清空时只通过 `scripts/reset-test-simulator.sh` | 不证明真机交付；不可把测试 UDID 指向 Dogfood |
| `iPhone 17 Dogfood` 受保护 Simulator | 按[Dogfood 规则](../dogfood-testing.md)封存身份后，用 `scripts/run-dogfood-simulator.sh` 做一次稳定批次正常 UI 既有数据读回 | 不跑 XCTest、reset/seed、卸载、直接 store/defaults 写、删除/恢复等破坏流程 |
| 主真机 | 已授权的同 build 覆盖升级、权限、锁屏遛狗、通知、HealthKit、Widget/Live Activity、能耗、辅助功能 | 不做需要抹掉个人数据的恢复/系统备份测试；不能替代最小支持设备 |
| 第二台可擦除真机 | 合成数据的 iCloud Drive 恢复和 R6b 加密系统备份/恢复排除 | 不把私人健康/照片/位置放入分享证据 |
| TestFlight | 同一 beta build 的真实分发、反馈、Sandbox 商品 | 不把 TestFlight 安装当 App Store 已发布；不把 sandbox 当真实付款 |
| StoreKit Sandbox / ASC | 真实测试商品/账号生命周期与产品元数据 | 不用生产 Apple Account 做付费测试；外部状态无截图/记录为 UNKNOWN |
| Release configuration / Distribution Archive | 优化运行与签名、entitlement、嵌入资源/扩展检查 | Release Simulator build 不证明 Distribution；Archive 不证明安装或后台行为 |

最小测试组合按风险升级：仅文字/排版不触发 App build；命令和持久事实用目标 Unit/Integration；多入口或用户可见集成补一个相关 UI shard；影响旧用户的稳定批次补 Dogfood；系统能力和发行硬门再进入真机、第二设备、TestFlight。并行 UI runner 会共享 App 与 store，现有 full campaign 设计为串行。
