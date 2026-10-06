# 当前候选：DRAFT / UNVERIFIED

负责人：产品负责人；源码核对：2026-09-25 Europe/Berlin。本文件是当前源码状态快照，**不是** 1.0-rc1。尚无冻结后的 RC build 身份、Distribution Archive 或与当前 SHA 绑定的验证收据；不得据此上传或提交。确定候选后，复制[轮次模板](_template.md)建立正式、不可回填的记录。

## 可核实的身份

| 字段 | 事实 | 类别 |
| --- | --- | --- |
| 当前 HEAD | 116ea499f1d005c55d49332db63ded7bc428dafc；提交于 2026-09-25 09:30:04 +02:00，标题 fix: address RC1 validation failures | SOURCE VERIFIED：git log -1 |
| 父提交 | fd39a2035ac38e062aed18486d788d7fd550a318；标题 Await complete storefront entitlement refresh in test | SOURCE VERIFIED：git show -s --format=%P HEAD |
| 分支 / 本轮开始时工作树 | agent/fix-water-refill-care-fact；起始状态只有 docs/release/ 草稿未跟踪，tracked source 无改动 | SOURCE VERIFIED：本轮开始的 git status --short --untracked-files=all |
| 提交变更 | 新提交改动 22 个源码/测试文件，包含 OhanaUITests/OhanaUITests.swift、PlantModuleUITests.swift 及两个 Unit 测试文件 | SOURCE VERIFIED：git show --stat HEAD；提交标题不能替代验证结果 |
| 源码版本 | MARKETING_VERSION=1.0、CURRENT_PROJECT_VERSION=1、iPhone-only、iOS 26.2+ | SOURCE VERIFIED：[project.pbxproj](../../../Ohana.xcodeproj/project.pbxproj)；不代表 ASC build |
| schema / 语言 | V99；zh,en,de,es,pt,fr,ja,ko,it | SOURCE VERIFIED：[schema](../../../Ohana/Models/SharedModelContainer.swift)、[语言注册](../../../Ohana/Shared/LocalizationSettings.swift) |
| UI 清单 / Test Plan | 132 selectors / 9 shards；OhanaUnitTests.xctestplan 存在且由主 scheme 引用 | SOURCE VERIFIED：[manifest](../../../scripts/ui-test-shards.tsv)、[plan](../../../OhanaTests/OhanaUnitTests.xctestplan)；不代表执行 |
| Xcode/SDK、Distribution Archive、Archive checksum、Privacy Report、CI run、TestFlight/ASC build | UNKNOWN | 没有找到与当前 HEAD 绑定的可核实记录 |

## 当前轮次门禁

下表是当前候选状态的唯一所有者。此快照有 **0/12 个门禁具备当前 SHA 的已关闭执行证据（0%）**；这只是证据计数，不是功能完成度或发布质量评分。BLOCKED 表示缺少所需账号、签名、硬件或先决产物；NOT RUN 表示尚未执行。没有任何一项被记为当前 PASS。

| ID | 状态 | 负责人 | 证据或缺口 | 下一步 | 阻塞 | 退出条件 | 最后核对 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RC-IDENTITY | NOT RUN | 负责人/Codex | 当前只有源码 commit，未冻结 RC，也没有对应 build/Archive | 选定 RC 号，冻结工作树并记录版本、build、SHA、时间与产物身份 | 负责人需决定是否以当前源码作为候选；发行签名另需授权 | 同一冻结 commit 对应一个明确 version/build 与最终 Archive | 2026-09-25 |
| RC-STATIC | NOT RUN | Codex | 当前 HEAD 没有本轮静态发布门收据 | 跑 scripts/release-hardening-check.sh --static-only 并保存完整摘要 | 无 | 当前 SHA 所需静态检查全通过且收据可定位 | 2026-09-25 |
| RC-UNIT | NOT RUN | Codex | 附件报告的 2,577/2,577 指向父提交 fd39a203；当前提交另改了 Unit 测试文件，无同 SHA 收据 | 对冻结 SHA 跑 scripts/xcode-test.sh --unit | 无；本次仅完成文档，不跑 App 测试 | 完整结果绑定 SHA，首次失败均解释，保留结果包 | 2026-09-25 |
| RC-UI | NOT RUN | Codex | 132 selectors 是清单规模，不是结果；当前提交修改两个 UI 测试文件，没有同 SHA 完整 campaign receipt | 对冻结 SHA 跑 scripts/test-ui-nightly.sh，逐 shard 留结果 | 无；本次仅完成文档，不跑 App 测试 | 9 个 shard 的首轮结果完整；失败按政策处理，不能由重试抹除 | 2026-09-25 |
| RC-DOGFOOD | NOT RUN | Codex | 当前提交改了现有 UI/route surface；没有同 SHA 的既有用户读回记录 | 冻结后按持久化/既有用户影响判断是否适用；适用时走一次受保护正常 UI | 需冻结可验证产物；仅遵守受保护身份规则 | 记录适用性与结果；若适用则同一 Release build 读回通过 | 2026-09-25 |
| RC-DISTRIBUTION | BLOCKED | 负责人 | 没有当前 SHA 的 Distribution Archive；旧 development-signed Archive 不匹配 | 核对 Portal 的 App/Widget IDs、生产 App Group 与 profile，并生成 Distribution Archive/checksum | Developer Portal、有效证书/profile 与负责人签名授权 | App 和 Widget 的签名、entitlement、嵌入关系一致且安装验证通过 | 2026-09-25 |
| RC-PRIVACY | BLOCKED | 负责人 | 没有当前最终 Archive 的 Xcode Privacy Report | 从最终 Distribution Archive 生成报告，再逐项核对 manifest、依赖、数据流与 ASC App Privacy | 依赖 RC-DISTRIBUTION 和 ASC 访问 | 报告及隐私答案绑定同一最终产物且可复核 | 2026-09-25 |
| RC-STOREKIT | BLOCKED | 负责人/测试者 | 本地 Ohana.storekit 配置存在；真实商品、Sandbox 账号及交易生命周期未知 | 核对 ASC SKU，再用专用 Sandbox/TestFlight 账号测购买、取消、pending、恢复、到期、退款/撤销 | ASC 商品、测试账号与签名 build | 各交易状态和 entitlement 有同 build 脱敏记录，Free 数据保留 | 2026-09-25 |
| RC-DEVICE | BLOCKED | 负责人 | 没有当前签名 build 的真机权限、通知、后台、Widget、HealthKit、辅助功能和能耗观察 | 对当前 build 执行[真机 R0–R7](../../release-true-device-test-plan.md) | Distribution/TestFlight build 与实体 iPhone | 适用 Test ID 都有设备/OS/步骤/观察记录，无未解释 P0/P1 | 2026-09-25 |
| RC-R6B | BLOCKED | 负责人 | 未查到第二台可擦除设备上的加密系统备份/恢复排除证据 | 在独立测试机按真机计划 R6b 检查排除边界 | 第二台可擦除 iPhone 与安全合成备份 | 同一 build 下确认允许/排除内容及失败不伤原数据 | 2026-09-25 |
| RC-METADATA | BLOCKED | 负责人 | ASC App 记录、协议、地区、截图、年龄、出口合规与 Review Notes 未核实 | 对照[文案包](../../app-store-connect-submission-package.md)和上架手册逐项检查 | App Store Connect 账号及最终 build | 所有必填项准确、匹配产品范围和选定 build | 2026-09-25 |
| RC-PERF | NOT RUN | 负责人/Codex | 当前 SHA 无密集数据、冷启动、内存/能耗对比收据 | 固定合成数据与实体设备，在 Release-like build 记录起止指标 | 真机能耗/后台部分需要物理设备与最终产物 | 按性能政策留可重复数据，无未解释关键回归 | 2026-09-25 |

当前提交决定：**NO-GO**。主要未关闭硬门为 Distribution 签名、最终隐私报告、StoreKit Sandbox、真机、第二设备 R6b 和 App Store Connect 元数据；仓库静态、Unit、UI 与性能也没有当前 SHA 的执行收据。这不表示当前源码测试失败，只表示缺少能证明它已通过的记录。

## 历史证据与文档漂移

1. 用户提供的审计摘要报告父提交 fd39a203 上 2,577/2,577 Unit 通过；仓库中未找到可定位的同 SHA 完整收据。即使该摘要准确，HEAD 116ea499 又改了 22 个源码/测试文件，因此旧结果不能证明当前候选。提交标题说修复 RC1 验证问题，也不能作为修复通过的证据。
2. [活动状态页](../../testing-progress.md)仍以 2026-08-03 的 2,310 Unit / 132 UI campaign 与 3ee93cf718 的 2026-08-04 development-signed Archive 为“当前”。它们只证明各自历史记录；不能拼接为当前 RC。
3. [首发真机计划](../../release-true-device-test-plan.md)部分导语仍以 2026-07-29 的未签名流程为“本轮”，[上架准备清单](../../app-store-launch-readiness-checklist.md)以 2026-08-04 Archive 为当前。两份既有权威文件未在本任务改动；实际候选按本轮冻结 SHA 和新证据记录。
4. [状态总账地图](../../status-ledger-map.md)指定现有测试进展与开放工作文档维护仓库状态总账。本次只更新 docs/release/，发现的漂移记于此处，没有暗改既有权威文档。
5. [项目 Info.plist](../../../Ohana/Info.plist)未见显式 ITSAppUsesNonExemptEncryption 键；是否需要、应填何值须根据最终加密实现及 ASC 问卷核实，不能由源码检查推定。

没有复制旧 Archive 的 checksum、隐私报告或开发签名结果到当前候选。没有检查 Developer Portal/App Store Connect 账号或真实设备，也没有在本轮执行 Xcode/CI 测试。
