# GAP-3 自动备份验收跟踪清单

状态：通过；Codex 自动/源码验收已通过，真实 iCloud Drive / 真机体验项已记录为非阻塞追踪
负责人：Codex 先验收可自动验证项；用户验收真实设备 / 真实 iCloud Drive / Files App 体验项
准备日期：2026-06-12

## 验收范围

本清单用于验收 GAP-3 Phase 6.5：首发版本保留手动导出 / 恢复，同时新增默认开启、可关闭的定期自动备份；自动备份写入用户 iCloud Drive 文件，不启用 CloudKit 同步、CKShare 或多设备合并；失败状态必须在设置页可见，必要时温和提醒。

## Codex 已验收

- [x] 已写入规则书。
  - 证据：`docs/specs/AutomaticBackup-logic.md` 已创建。
  - 结论：规则书覆盖默认开启、每日 due 语义、生命周期机会触发、iCloud Drive 文件目标、失败可见、重置清理、备份→擦除→恢复验收合同，以及不启用 CloudKit 同步边界。

- [x] 自动备份服务不变量已测试。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/AutomaticBackupServiceTests`
  - 输出摘要：`AutomaticBackupServiceTests` 6 个 Swift Testing 测试通过。
  - 覆盖点：默认开启且首次 due；关闭后不导出不写文件；成功写入后记录 last attempt / last success / 文件名；iCloud 不可用时失败可见且提醒限频；并发触发只启动一次导出；自动备份复用手动备份投影并完成备份→擦除→恢复。

- [x] 生命周期触发点已测试。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/AppLifecycleCoordinatorTests`
  - 输出摘要：`AppLifecycleCoordinatorTests` 5 个 Swift Testing 测试通过。
  - 结论：自动备份只挂在首帧后的 `rootAppeared` 和 `didEnterBackground` due check；重复 scene phase 不重复触发；未新增 BGTask。

- [x] App reset 行为已测试。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/AppResetServiceTests`
  - 输出摘要：`AppResetServiceTests` 2 个 XCTest 通过。
  - 结论：现有重置语义未回归；自动备份 status defaults 进入 reset 清理范围，真实文件删除失败不会阻断 reset。

- [x] 设置页自动备份 UI 通过静态门禁。
  - 命令：`scripts/dev-check-changed.sh`
  - 输出摘要：SwiftFormat 0 文件再格式化；UI V4 audit、Accessibility audit、Smoothness risk audit、Runtime guardrails、Shared-care note metadata audit 均通过。
  - 结论：设置页新增“自动备份”开关、状态、立即备份按钮与失败提示；手动导出 / 恢复保留。

- [x] plist / entitlements 语法通过。
  - 命令：`plutil -lint Ohana/Info.plist Ohana/Ohana.entitlements`
  - 输出摘要：`Ohana/Info.plist: OK`；`Ohana/Ohana.entitlements: OK`。
  - 结论：`Info.plist` 声明 iCloud Documents 容器；主 entitlements 加入 `CloudDocuments` 和 ubiquity container。

- [x] 未新增 CloudKit 同步、CKShare、OnlineFeatureGate 或 BGTask 入口。
  - 命令：`rg -n "AutomaticBackup|automaticBackups|automaticBackup" Ohana | rg "CloudSync|CKShare|CloudKit|CloudSyncEngine|CloudSyncHouseholdShareService|OnlineFeatureGate|BGTask|BGTaskScheduler"`
  - 输出摘要：无命中。
  - 命令：`rg -n "BGTaskSchedulerPermittedIdentifiers|automaticBackup|AutomaticBackup" Ohana/Info.plist Ohana/App/BackgroundTaskCoordinator.swift`
  - 输出摘要：仅命中 `Ohana/Info.plist` 中既有 `BGTaskSchedulerPermittedIdentifiers`；未出现自动备份 BGTask identifier。
  - 结论：自动备份边界是 iCloud Drive 文件，不是 CloudKit 同步。

- [x] Debug 构建通过。
  - 命令：`scripts/build-debug-fast.sh`
  - 输出摘要：`** BUILD SUCCEEDED **`；目标为 iPhone 17 simulator / `iphonesimulator`；存在一个既有 `SettingsView.swift` trailing-closure warning，非本轮引入。
  - 结论：Info.plist / entitlement 改动不破坏 Debug simulator 打包。

- [x] 模块退出门通过。
  - 命令：`scripts/module-exit-gate.sh`
  - 输出摘要：changed-file checks、runtime guardrails、localization coverage 均通过；全量单元测试 706 个测试 / 56 个 suite 通过；UI 测试 3 个测试通过；最终输出 `RESULT: PASS — module may be committed`。
  - 结论：模块退出门通过。

## 已记录的人工追踪项

以下项目需要真实设备、真实 iCloud 账号、真实 iCloud Drive quota 或人眼遍历才能确认。根据 2026-06-12 验收决定，这些项目已记录在本 track list 中，不阻塞 GAP-3 标记通过。

- [ ] 真机登录 iCloud 后，自动备份能写入 Files / iCloud Drive。
  - Codex 已验证：文件写入路径通过 `FileManager.url(forUbiquityContainerIdentifier:)` 封装；模拟测试用 fake file store 覆盖成功写入。
  - 仍需人工原因：模拟器 / 单元测试无法代表真实 iCloud Drive 容器、Apple ID 登录状态和 Files App 可见性。
  - 入口 → 操作 → 预期：设置 → 数据备份 → 自动备份开启 → 点“立即备份”；Files App / iCloud Drive 中可见 `Ohana/Ohana Backups/Ohana Automatic Backup.json`，设置页显示“上次成功”。
  - 实际结果：

- [ ] 关闭自动备份后不会自动写入。
  - Codex 已验证：关闭后 `runIfDue` 返回 `.skipped(.disabled)`，fake exporter/write 均未调用。
  - 仍需人工原因：需要确认真实设置页 toggle、文案状态和重进 App 后持久化。
  - 入口 → 操作 → 预期：设置 → 数据备份 → 关闭“自动备份” → 杀进程重进 / 进后台；设置页保持“已关闭”，不会更新时间或写新文件。
  - 实际结果：

- [ ] iCloud 不可用时失败可见。
  - Codex 已验证：file store 返回 `iCloudUnavailable` 时，状态记录失败类型、失败消息和连续失败次数；设置页会显示失败提示。
  - 仍需人工原因：需要真实设备退出 iCloud、关闭 iCloud Drive 或限制 iCloud 权限确认系统表现。
  - 入口 → 操作 → 预期：退出 iCloud 或关闭 iCloud Drive → 设置 → 数据备份 → 点“立即备份”；设置页显示失败，不崩溃、不假成功，本机数据不变。
  - 实际结果：

- [ ] iCloud 空间不足 / 写入失败时降级得体。
  - Codex 已验证：写入异常会归类为 `writeFailed` 并在设置页可见。
  - 仍需人工原因：需要真实 iCloud quota 或系统级写入失败环境，单元测试只能模拟错误。
  - 入口 → 操作 → 预期：构造 iCloud Drive 空间不足或写入失败 → 点“立即备份”；设置页显示失败原因，后续可重试，不阻断普通使用。
  - 实际结果：

- [ ] 自动备份文件可用于真实 UI 恢复。
  - Codex 已验证：`AutomaticBackupServiceTests.automaticBackupUsesManualProjectionAndRestoresAfterWipe` 覆盖备份→App reset→导入→数据完整。
  - 仍需人工原因：需要真实 Files picker、真实设置页导入 UI、真实页面刷新和人眼确认。
  - 入口 → 操作 → 预期：生成自动备份 → 重置 App → 设置 → 数据备份 → 从 iCloud Drive 选择 `Ohana Automatic Backup.json` 恢复；成员、宠物和记录恢复，PIN hash/salt 不出现在文件内容中。
  - 实际结果：

- [ ] 手动导出 / 加密导出仍可用。
  - Codex 已验证：本轮未移除手动导出 / 恢复代码；既有备份测试仍编译通过。
  - 仍需人工原因：需要系统 Share Sheet、Files picker 和密码输入真实交互。
  - 入口 → 操作 → 预期：设置 → 数据备份 → 密码加密开启 → 生成备份 → 分享；恢复加密备份要求密码，密码错误有提示。
  - 实际结果：

- [ ] App reset 后自动备份关闭，Ohana 管理的自动备份文件被尝试清理。
  - Codex 已验证：`AppResetService` 会重置 `automaticBackup.*` defaults 并调用 managed file cleanup；失败不阻断 reset。
  - 仍需人工原因：真实 iCloud Drive 删除需要设备 / Files App 观察。
  - 入口 → 操作 → 预期：先生成自动备份 → 设置 → 重置 App；重置后自动备份为关闭状态，Ohana 管理的自动备份文件被删除或系统稍后同步删除，手动导出的其他文件不受影响。
  - 实际结果：

- [ ] 真实 UI 目检设置页备份区块。
  - Codex 已验证：UI V4、a11y、smoothness 静态审计通过。
  - 仍需人工原因：需要人眼确认不同数据量、动态字号、深浅色、德语长文本和 Reduce Motion 下的排版。
  - 入口 → 操作 → 预期：设置 → 数据备份；自动备份、手动导出、密码加密、从备份恢复各行不重叠、不遮挡，按钮可点，失败提示得体。
  - 实际结果：

- [x] 最终签署。
  - 结论：2026-06-12 按用户授权，Codex 已完成自动验收并将剩余真实设备 / 真实 iCloud 项转入本 track list；GAP-3 可标记通过。
  - 实际结果：通过。

## 余留项记录

- [x] 本轮没有发现需要写入 `docs/task-follow-ups.md` 的真实 blocker、跨范围修复或验证缺口。
- [ ] 如人工验收发现真实余留项，写入 `docs/task-follow-ups.md`。
