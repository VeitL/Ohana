# Ohana Release Control Center

负责人：产品负责人（单人开发者）；维护者：执行发布工作的 Codex 与负责人。源码核对日期：2026-09-25；源码基线：`116ea499f1d005c55d49332db63ded7bc428dafc`。本目录把测试、人工观察、缺陷和提交决定连成可追溯的操作记录；它不替代 [产品基石](../specs/product-foundation.md)、[仓库规则](../../AGENTS.md)或现有[发布质量门](../release-quality-gates.md)。

## 从这里开始

1. 初次使用先读[入门与进度](getting-started.md)，了解当前阶段和下一步；术语不熟时再读[负责人入门](owner-guide.md)。
2. 按[测试策略](test-strategy.md)选择证明层级与安全环境；在[能力矩阵](feature-test-matrix.md)选稳定 Test ID，按[手工测试手册](manual-device-test-runbook.md)一次执行一组。
3. 复制[发布轮次模板](runs/_template.md)记录**同一**版本、build、commit 和 Archive；当前仅有[候选草稿](runs/current-candidate.md)。失败按[缺陷与 RC 政策](defect-and-rc-policy.md)闭环。
4. 上架时依次执行[App Store 发布手册](app-store-release-runbook.md)和原有[上架准备清单](../app-store-launch-readiness-checklist.md)；外部方法的出处在[参考来源](reference-sources.md)。

## 当前已核实的发布读数

| 项目 | 判断 | 证据边界 |
| --- | --- | --- |
| 源码 | HEAD 为 `116ea499f1d005c55d49332db63ded7bc428dafc`，分支 `agent/fix-water-refill-care-fact`；本轮开始时只有 `docs/release/` 草稿未跟踪 | 2026-09-25 的 Git 状态与提交信息；该提交是 `fd39a2035ac38e062aed18486d788d7fd550a318` 的子提交，改了 22 个源码/测试文件；这不是发行产物身份 |
| 项目配置 | 源码配置 `1.0 (1)`、iPhone-only、iOS 26.2+；SwiftData 最新 V99；注册 9 种语言；UI manifest 为 132 selectors / 9 shards | [项目配置](../../Ohana.xcodeproj/project.pbxproj)、[schema](../../Ohana/Models/SharedModelContainer.swift)、[语言注册](../../Ohana/Shared/LocalizationSettings.swift)、[UI 清单](../../scripts/ui-test-shards.tsv)；均为 SOURCE VERIFIED |
| 当前完整测试结果 | **NOT RUN / UNKNOWN**：本次未执行 app 测试，也没有当前 HEAD 的完整结果收据 | [旧状态页](../testing-progress.md)的 2,310 是 2026-08-03 结果；附件的 2,577/2,577 指向父提交 `fd39a203`，不能证明当前 HEAD；源码中的测试声明数也不是执行数 |
| 当前 RC / Distribution Archive | **DRAFT / UNVERIFIED**；尚未核实当前 HEAD 对应的 distribution 签名 Archive、checksum、Privacy Report、TestFlight 或 App Store build | [当前候选](runs/current-candidate.md)；2026-08-04 的 development-signed Archive 对应旧 commit `3ee93cf718` |
| 提交决定 | **NO-GO**，直到当前候选的发布硬门有证据；不是给源码质量打分 | [发布轮次](runs/current-candidate.md)是此判断的细目所有者 |

当前候选记录的 12 个发布门中，**0/12 有当前提交的已关闭执行证据（0%）**。这是证据进度计数，不是功能完成度或发布就绪评分；详细缺口以[当前候选](runs/current-candidate.md)为准。

最高风险的现有缺口：Distribution 签名与 App/Widget App Group、真实 StoreKit/Sandbox、同一 build 的真机权限和后台行为、第二台设备恢复及 R6b 系统备份排除、最终 Archive Privacy Report、完整 UI/密集数据性能和 App Store Connect 资料。详见[发布轮次](runs/current-candidate.md)与[开放工作](../task-follow-ups.md)。

## 状态与证据语言

测试状态**只能**使用 `NOT RUN`、`IN PROGRESS`、`PASS`、`FAIL`、`BLOCKED`、`NOT APPLICABLE`。未知事实写 `UNKNOWN`，它是证据类别或字段值，**不是**第七种测试状态。候选身份可写 `DRAFT / UNVERIFIED`，发布决定只写 `GO`、`CONDITIONAL GO`、`NO-GO`。

| 证据类别 | 能说明什么 |
| --- | --- |
| `EXECUTED` | 指定 commit/build、环境、步骤、结果和可定位收据的真实执行 |
| `SOURCE VERIFIED` | 当前源码、脚本或配置确实含有该行为/规则；不证明运行成功 |
| `EXTERNAL ACCOUNT VERIFIED` | 对应 App Store Connect、Developer Portal、Sandbox 等账号的可核对记录 |
| `HUMAN OBSERVATION` | 人在指定设备、build、步骤下实际看到的结果 |
| `INFERRED` | 根据材料推断，尚待执行；绝不等于 `PASS` |
| `UNKNOWN` | 尚无足够材料判断；写清获取证据的下一步 |

`PASS` 必须指向真实证据（收据、报告、经过隐私处理的观察记录）。源码检查本身不能证明执行；重试成功不能抹去未解释的首次失败；旧 build 不能证明新 RC；Unit 不能证明 UI；Simulator 不能证明真机权限、后台、交付或能耗。单个层次的通过不能把整个功能标为 `PASS`。

## 文件所有权与更新触发

| 文档 | 所有者与何时更新 |
| --- | --- |
| 本 README | Codex 在范围、导航、总体证据边界改变时更新摘要；不复制测试明细 |
| [入门与进度](getting-started.md)、[测试策略](test-strategy.md)、[手工手册](manual-device-test-runbook.md)、[上架手册](app-store-release-runbook.md)、[缺陷政策](defect-and-rc-policy.md)、[负责人入门](owner-guide.md) | 进度变化、流程/脚本、Apple 规则或环境变化时更新 |
| [能力矩阵](feature-test-matrix.md) | 功能入口、自动覆盖、风险或验收合同变化时更新；它拥有覆盖状态 |
| [当前轮次](runs/current-candidate.md)或正式 RC 文件 | 每次冻结、执行、失败、复测和决策后更新；它拥有该 build 的执行结果 |
| [轮次模板](runs/_template.md)、[参考来源](reference-sources.md) | 字段/证据要求或外部规则更新时更新 |

现有[状态总账地图](../status-ledger-map.md)仍把[测试进展](../testing-progress.md)和[开放工作](../task-follow-ups.md)列为仓库整体状态所有者。本次仅获准写本目录；发现的漂移记在[当前轮次](runs/current-candidate.md)，不能暗改那些权威文件。未来 Codex 更新时，先核对 HEAD、工作树、脚本和产物；选 Test ID；只记录本轮真正执行的证据；发现与权威文档冲突时指出来源并交给负责人处理；更新后做相对链接、`git diff --check` 和文档审计。已发布的轮次记录是历史，不为下一版改写。

## 现有权威入口

[产品基石](../specs/product-foundation.md) · [发布质量门](../release-quality-gates.md) · [架构](../app-architecture-governance.md) · [隐私](../privacy-compliance.md) · [无障碍](../accessibility-governance.md) · [并发与错误策略](../concurrency-and-error-policy.md) · [缓存/同步策略](../data-cache-sync-policy.md) · [性能](../performance-and-observability.md) · [设备范围](../os-support-matrix.md) · [Dogfood 规则](../dogfood-testing.md) · [真机清单](../release-true-device-test-plan.md) · [App Store 文案包](../app-store-connect-submission-package.md)。
