# 发布与测试外部依据

核对日期：2026-09-24。以下均为 Apple 官方或项目自身仓库/wiki 的**一手**资料；未采用二手博客。Apple 规则随时间变化，每个 RC 在实际提交前复核链接与当时 App Store Connect UI。本目录的本地事实仍以当前 Ohana 源码、脚本和执行收据为准。链接只概括实践，不转录原文。

| 资料与组织 | 类型 / 规范性 | 学到的做法 → 在 Ohana 的应用 | 刻意不采用 |
| --- | --- | --- | --- |
| [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) · Apple | 官方审核规则 / 规范性 | 审核资料、隐私、后台能力必须与运行中的 1.0 一致；发布手册要求同一包核对 | 不把尚未启用的 Family 能力写进审核说明 |
| [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)、[Choose a build to submit](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit)、[Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app) · Apple | ASC 帮助 / 规范性 | 上传后等处理、按 version/build 选择唯一待审包、再提交；记录平台回执 | 不把 Archive 成功当上传成功 |
| [TestFlight Overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) · Apple | 官方流程 / 规范性 | 同一 beta build 的内部/外部测试与反馈独立记录 | Solo 项目不建立大型测试组织 |
| [StoreKit Xcode testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)、[sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)、[all stages](https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox) · Apple | 官方技术文档 / 规范性 | 本地 `.storekit`、真实 Sandbox 商品和 TestFlight 三层分开；购买、待处理、撤销和恢复逐层记录 | 不把本地虚拟价格/交易当 ASC 证据；不进行真实购买 |
| [Xcode test plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback)、[Adding tests](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)、[XCTest](https://developer.apple.com/documentation/xctest)、[Swift Testing](https://developer.apple.com/documentation/testing) · Apple | 官方技术文档 / 建议性 | Unit/Integration 与 UI 分层；确认 Ohana 现有 Unit plan 和 script shard，再决定是否将来加细分 plan | 不虚构已存在的 RC/performance Test Plan |
| [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility-inspector)、[system settings testing](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app) · Apple | 官方技术文档 / 建议性 | 静态审计之外，用真机检查焦点、标签、最大字体和系统设置 | 不以脚本 PASS 代替 VoiceOver 人工观察 |
| [Privacy manifests and Xcode Privacy Report](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)、[Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy) · Apple | 官方技术/ASC 流程 / 规范性 | 最终 Archive 报告与 App/Widget 声明、实际收集行为、ASC 答案相互核对 | 不从空 manifest 直接推导“Data Not Collected”已获批准 |
| [Archive/distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)、[Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)、[Encryption declarations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations) · Apple | 官方技术/ASC 流程 / 规范性 | 分开源码 entitlement、profile、签名 Archive 和出口问卷；准确决定 `ITSAppUsesNonExemptEncryption` | 不预填尚未核实的加密豁免结论 |
| [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)、[Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating) · Apple | ASC 帮助 / 规范性 | 截图按提交时 ASC 接受尺寸与实际 iPhone UI 核对；年龄问卷如实回答健康/内容项 | 不沿用旧尺寸表，也不先猜评级 |
| [Release option](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option)、[Phased release for updates](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases) · Apple | ASC 帮助 / 规范性 | 首发明确手动/自动发布时间；phased release 仅在未来更新且符合条件时考虑 | 不把首发 1.0 写成可用 phased release |
| [Improving app performance](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance) · Apple | 官方技术文档 / 建议性 | 聚焦一条路径测启动、卡顿、内存/能耗，必要时 Instruments/MetricKit；与 Ohana 密集数据基线比较 | 不建立缺少设备/样本的抽象分数 |

## 成熟开源 iOS 项目：借方法，不复制规模

| 资料与项目 | 类型 / 性质 | 学到的做法 → Ohana 调整 | 刻意不采用 |
| --- | --- | --- | --- |
| [Automated UI Tests](https://github.com/mozilla-mobile/firefox-ios/wiki/Automated-UI-Tests)、[Firefox iOS Test Types](https://github.com/mozilla-mobile/firefox-ios/wiki/Firefox-iOS-Test-Types)、[Page Object guide](https://github.com/mozilla-mobile/firefox-ios/wiki/Test-Automation-Efficiency-UI-Testing-Guide-for-Firefox-iOS) · Mozilla Firefox iOS | 项目 wiki / 建议性 | Unit 在日常门、长 UI 在定时/RC；一条测试一个主要用户任务，稳定选择器集中管理。Ohana 保留现有 9 shard 与相关单条 UI，而非每次代码改动跑全量 | 不复制 Firefox 的 Bitrise/Jenkins、测试人员分工或大规模 POM 重构 |
| [Wikipedia iOS README](https://github.com/wikimedia/wikipedia-ios/blob/main/README.md)、[localization guide](https://github.com/wikimedia/wikipedia-ios/blob/main/docs/localization.md) · Wikimedia | 项目仓库文档 / 建议性 | Release-like 性能前置，RTL/长文案单独检查；Ohana 将德语、9 语言、RTL、Dynamic Type 与密集 Home/Task Center 作为有风险的样本 | 不引入其多服务器 scheme、旧 OS 矩阵或照抄其语言配置 |
| [WordPress iOS AGENTS.md](https://github.com/wordpress-mobile/WordPress-iOS/blob/trunk/AGENTS.md) · WordPress Mobile | 项目仓库规则 / 建议性 | 明确 test plan 与测试 target 范围；Ohana 检查现有 `OhanaUnitTests.xctestplan` 和实际 scheme，不以名称猜测试覆盖 | 不引入 WordPress 的 workspace/依赖/发布自动化规模 |

每项均在上表日期查看。开源项目的流程只提供可借鉴的调度、证据和组织办法；Ohana 的首发范围、受保护 Dogfood、1.0 本地数据安全及签名门仍由本仓库权威规则决定。

## 采用这些实践的直接价值

| 来源组 | 为什么对 Ohana 有用 |
| --- | --- |
| Apple App Review | 防止审核文案与当前 Solo 可达路径冲突，减少退件与隐私风险。 |
| Apple 上传、选包、提交 | 让单人开发者能确认最终被审的 build 正是验收的二进制。 |
| Apple TestFlight | 将真实分发反馈与本地 Simulator 结果分开，便于定位渠道特有故障。 |
| Apple StoreKit 三种环境 | 让本地模拟覆盖失败分支，同时保留真实商品和交易生命周期的独立门。 |
| Apple 测试框架与 Test Plan | 避免把 Unit 测试误当 UI/硬件证明，也能在现有 scheme 中选最窄目标。 |
| Apple Accessibility Inspector | 发现静态审计看不到的焦点、顺序和设备设置问题。 |
| Apple Privacy Report 与 App Privacy | 让本地 manifest、最终包和对用户公开的隐私答案可以逐项对账。 |
| Apple Archive/签名与出口合规 | 防止 Development 包或未经核实的加密声明进入提交。 |
| Apple 截图与年龄评级 | 避免素材尺寸、可达功能及健康内容声明在最后一步不符。 |
| Apple 发布选项 | 让负责人可控地决定审批后的公开时间；首发不误用分阶段更新功能。 |
| Apple 性能工具 | 为密集本地数据和后台遛狗提供可复测的设备证据。 |
| Mozilla Firefox iOS | 现有 Ohana 分片可留在 nightly/RC，日常反馈仍快；一条 UI 测试围绕一个真实任务更容易排错。 |
| Wikimedia Wikipedia iOS | 长德语、RTL 与 Release-like 性能在 Ohana 九语言本地 UI 中都可能暴露首发问题。 |
| WordPress iOS | 核实 Test Plan 与 target 的真实关系，避免从“计划名称”猜全量覆盖。 |
