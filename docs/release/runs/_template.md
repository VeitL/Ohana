# 发布轮次记录模板

复制为 `runs/<version>-<rc>.md`；只有冻结 commit 与具体 build/Archive 已核实后才称 RC。负责人：产品负责人。状态值见[控制中心](../README.md)。**没有证据字段的 PASS 无效；空白不表示通过。** 每个证据写日期、build、环境、执行者、结果和可定位路径/账号截图引用（脱敏）。发布后该文件作为历史记录保留，不用未来版本的结果回填。

## 身份

| 字段 | 值 / 证据 |
| --- | --- |
| App version / build number / RC 号 | UNKNOWN |
| commit SHA / branch / 冻结时工作树状态 | UNKNOWN |
| 冻结时间与时区 / 执行时间与时区 | UNKNOWN |
| Xcode version / SDK / Release configuration | UNKNOWN |
| Simulator matrix（型号、OS、UDID、用途） | UNKNOWN |
| 真机 matrix（型号、OS、用途；不记序列号） | UNKNOWN |
| TestFlight build / App Store Connect build | UNKNOWN |
| Distribution Archive 路径、签名身份、App/Widget bundle IDs | UNKNOWN |
| Archive checksum（算法、值、命令）/ Privacy Report（路径、checksum） | UNKNOWN |
| CI run URL / commit 与成功状态 | UNKNOWN |
| StoreKit 环境与 Sandbox 测试账号代号 | UNKNOWN |

## 门禁结果

| ID | 事项 | 状态 | 证据类别与引用 | 执行者 | 下一步 / 阻塞 | 退出条件 | 最后核对 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RC-IDENTITY | 冻结的 commit、App version/build 和最终产物身份 | NOT RUN | UNKNOWN | 负责人/Codex | 确定候选并核验一致性 | 同一冻结 SHA 唯一对应 version/build 与 Archive | — |
| RC-STATIC | 仓库静态发布门 | NOT RUN | UNKNOWN | Codex | 执行当前 commit 的门禁 | 当前 SHA 所需严格静态检查全通过，收据可定位 | — |
| RC-UNIT | 完整 Unit/Integration | NOT RUN | UNKNOWN | Codex | 保留完整收据 | 完整结果绑定 SHA，首次失败均解释 | — |
| RC-UI | 9 分片 UI 回归，逐分片结果 | NOT RUN | UNKNOWN | Codex | 附 manifest 与 receipt | 9 个 shard 首轮结果完整，失败有处置记录 | — |
| RC-DOGFOOD | 适用时既有用户正常 UI 读回 | NOT RUN | UNKNOWN | Codex | 先遵守 Dogfood 规则；注明适用性 | 适用时同一 Release build 读回通过；不适用时记录理由 | — |
| RC-DISTRIBUTION | Distribution Archive、签名、entitlement、Widget | NOT RUN | UNKNOWN | 负责人/Codex | 核对签名及校验和 | App 与 Widget 签名/能力一致且安装验证通过 | — |
| RC-PRIVACY | 最终 Archive Privacy Report 与隐私答案 | NOT RUN | UNKNOWN | 负责人 | 生成并比对 | 报告和答案对应同一最终产物 | — |
| RC-STOREKIT | StoreKit Sandbox 与 TestFlight 购买生命周期 | NOT RUN | UNKNOWN | 负责人/测试者 | 保存脱敏交易状态 | 适用交易状态有同 build 记录，Free 数据保留 | — |
| RC-DEVICE | 主真机权限、通知、后台、Widget、辅助功能与能耗 | NOT RUN | UNKNOWN | 负责人 | 逐 Test ID 记录 | 适用 Test ID 有设备/OS/观察证据 | — |
| RC-R6B | 第二设备与加密系统备份排除 | NOT RUN | UNKNOWN | 负责人 | 在可擦除设备按 R6b 验证 | 允许/排除边界已验证且失败不伤原数据 | — |
| RC-METADATA | App Store Connect 元数据、处理、选包与提交 | NOT RUN | UNKNOWN | 负责人 | 核对账号记录 | 必填资料准确并匹配选定 build | — |
| RC-PERF | 密集数据、启动、内存/能耗性能 | NOT RUN | UNKNOWN | 负责人/Codex | 固定设备与合成 fixture，保存可比测量 | 数据可复测且无未解释关键回归 | — |

## 结果与决定

- 功能 Test ID 结果汇总（引用[能力矩阵](../feature-test-matrix.md)；禁止把一层 PASS 写成全功能 PASS）：UNKNOWN。
- UI shard 逐项：UNKNOWN。
- 失败 Test IDs、缺陷 ID、复现状态、修复 commit、复测证据：UNKNOWN。
- 手工观察（脱敏，设备/build/步骤/期望/实际）：UNKNOWN。
- 已知问题与发布阻塞（ID、负责人、下一步、退出条件、最后核对）：UNKNOWN。
- 发布决定：`NO-GO` / `CONDITIONAL GO` / `GO`，理由与未关闭的 P0/P1：UNKNOWN。
- 负责人签收（日期、时区、明确同一 build）：UNKNOWN。
- 发布后 48 小时检查、反馈与热修复行动：UNKNOWN。

`CONDITIONAL GO` 只能用于不影响核心照护、数据安全、隐私、购买恢复和审核合规的已知 P2/P3，须写清条件、观察窗口和负责人；缺少硬门证据时是 `NO-GO`。
