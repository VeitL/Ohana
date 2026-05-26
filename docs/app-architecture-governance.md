# Ohana App 架构治理守则

> 目标：让 Ohana 像长期维护的主流 iOS app 一样，合规、低功耗、性能稳定、可扩展。本文是工程治理边界；UI 视觉仍以根目录 `ui规范.selection.json` 为准。

## 分层边界

- `Views/` 只负责界面组合、局部交互状态和路由，不直接承担跨页面业务规则。
- `Models/` 放 SwiftData 模型、领域服务和持久化相关业务，例如 `CareEventService`、`FamilyTaskService`、`CoconutEconomyService`。
- `Utilities/` 放跨模块基础设施，例如运行时能耗策略、定位封装、颜色、输入格式、日历同步。
- `ViewModels/` 只在单个页面需要复杂只读聚合时使用；不要把 SwiftData 写入逻辑藏在 ViewModel 里。
- 新功能优先复用已有服务；只有当同一规则被两个以上入口使用时，才抽成新 service。

## 依赖方向

Ohana dependencies flow inward and downward:

```text
App Shell / Route Host
        ↓
Feature Modules
        ↓
Domain Services / Repositories / Snapshot Builders
        ↓
SwiftData Models / Persistence
        ↓
Foundation Utilities
```

Shared UI / Design System is consumed by App Shell and Features. Runtime Policy is consumed by App Shell, Features, and Motion components. Features must not depend on each other's internal Views or ViewModels.

Allowed dependency examples:

- View -> shared UI component.
- View -> feature-local coordinator.
- View -> render state.
- Feature coordinator -> route value.
- Snapshot builder -> domain service / SwiftData read.
- Domain service -> SwiftData write.
- Runtime-aware component -> `AppWorkloadPolicy`.

Forbidden dependency examples:

- Domain service -> SwiftUI View.
- SwiftData model -> ViewModel.
- Reusable component -> `ModelContext`.
- Feature A View -> Feature B internal View.
- View body -> broad repository query.
- Startup path -> feature-specific heavy service.

## 后台与定位

Apple 的审核和能耗边界很清楚：后台能力必须服务于用户明确理解的核心功能。Ohana 的规则是：

- 只有 `running` 遛狗可以持续定位。
- `paused`、`finished`、没有遛狗进程、普通浏览、首页、记录、喂食、协作、商店都不能持续定位。
- 后台/锁屏 running 遛狗继续记录路线，但 UI timer、地图重绘、装饰动画必须停止或降频。
- 所有 Core Location 入口集中在 `LocationManager` / `PetWalkingManager`；其他文件不得直接创建 `CLLocationManager` 或打开后台定位。

参考：
- Apple App Review Guideline 2.5.4: background services must be used only for intended purposes.
- Apple “Accessing the device’s location efficiently”: only register background location when the feature cannot work without it.

## 能耗与动画

- 全局能耗判断统一走 `AppWorkloadPolicy`，不要在单个页面里随手写一套低功耗判断。
- 动效/能耗分成三类预算：核心交互走 `interactionMotionBudget`，装饰循环走 `ambientMotionBudget`，计时/地图/UI 刷新走 `refreshBudget`。
- 正常前台、当前可见页面的点击、FAB、弹窗、卡片展开、奖励反馈保持完整动效。
- App 内省电模式默认关闭；开启后也不能牺牲当前可见核心交互的顺滑度，只能静态化装饰动效、降低刷新频率、停止离屏工作。
- 后台、锁屏、低电量、Reduce Motion、省电模式、离屏页面，只允许保留必要业务；常驻动画、`repeatForever`、粒子、Canvas、TimelineView、Timer 应暂停或降频。
- 时长、倒计时、计划状态优先用“当前时间 - 开始时间”计算，不依赖后台每秒 timer。
- Map UI 使用降采样路线点；数据记录不能被降采样影响。
- 关键空间动效统一使用稳定 `ZStack` motion scene：动画开始前冻结 UI snapshot，动画期间保持视觉层挂载，只用单一 progress 驱动 transform、mask、opacity、zIndex 和 hit-testing；动画完成后再解冻真实业务状态。
- 首页卡片、FAB/菜单、inline popup、奖励 reveal、扭蛋/Oasis 奖励、添加人类/宠物角色卡和图表范围切换应复用 `OhanaMotionScene` / Wallet-style timeline，不要在交互中途插入/移除复杂 View 或启动业务重算。

### Device Stress and Graceful Degradation

Resource-heavy work must degrade before the UI degrades.

When the app is under Low Power Mode, background, hidden route, active scrolling, active spatial transition, memory pressure, or expensive visible animation:

- Stop decorative loops first.
- Stop prefetch next.
- Defer non-critical aggregation.
- Reduce map/UI refresh.
- Use cached snapshots.
- Show placeholders for non-critical media.
- Keep tap feedback, route shell, form input, and critical confirmation responsive.

Never protect prefetch, decoration, or dashboard freshness at the cost of current visible interaction responsiveness.

### 常驻动画接入模式

- 装饰性循环必须有可见性 gate：`@State isVisible` + `@StateObject AppWorkloadPolicy.shared` + `workloadPolicy.shouldAnimate(isVisible:)`。
- `onAppear` 只在 gate 允许时启动循环，`onDisappear` 必须把循环状态复位。
- `onChange` 监听 gate 变化；后台、低电量、Reduce Motion、省电模式时停止，恢复前台可见时按原动画参数重启。
- 条件动画写成 `shouldAnimate ? originalRepeatAnimation : nil`，不要改原 duration、offset、scale 或节奏。
- 2026-05 本轮已覆盖：水管理 hero、便便管理 hero、家庭协作成员浮动、Oasis 发光/呼吸/收获气泡、成员页删除抖动。
- 剩余历史清单由 `scripts/audit-runtime-guardrails.sh --soft` 暴露；新改动必须通过 path-specific guardrail。

## 数据与任务一致性

- 用户动作只写一次业务事实，再由服务同步相关状态。例：快捷打卡写照护记录后，由 `FamilyTaskService` 同步协作任务/reminder 状态。
- 家庭任务、悬赏、Today Focus 和提醒都要围绕统一 task/reminder 状态，不允许同一事项在不同入口显示不同状态。
- SwiftData schema 增长必须追加版本，迁移保持 lightweight；新增模型同步考虑备份/恢复。
- 删除/离世/隐私这类边界状态必须从服务层过滤，不能只在 UI 隐藏。

## 用户流所有权

每个高频用户流必须有一个 owner service 或 owner feature。不要让一个用户流分散在多个 View、多个 ViewModel、多个 service extension 里。

高频用户流至少包括：

- 快捷照护记录。
- 今日重点查看与完成。
- 喂食与库存变化。
- 遛狗开始、暂停、恢复、结束。
- 家庭任务创建、接受、完成、确认、奖励。
- 提醒创建、触发、完成、跳转。
- 宠物/人类资料查看与隐私状态。
- 删除、离世、纪念模式。
- 奖励购买、装备、余额变化。
- 健康/报告/历史查看。

每个用户流要声明：

- 入口。
- 成功结果。
- 失败结果。
- 是否可撤销。
- 是否需要恢复。
- 写入哪个业务事实。
- 同步哪些派生状态。
- 影响哪些 read models。
- 影响哪些 widget/notification/App Intent。
- 需要哪些测试。
- 需要哪些指标或 signposts。

## 隐私与账户

- 人类隐私统一走 `PrivacyService`；非本人不能通过快捷操作、全部功能、统计页、协作页或 Today Focus 绕过。
- PIN 是本地家庭成员软隐私，不能作为强安全保险箱宣传。
- 备份不得包含 PIN hash/salt 或可用于恢复 PIN 的字段。
- 人类/宠物离世后进入只读纪念模式；未来提醒和日常任务不应继续出现。

## UI 与本地化

- UI token 唯一来源是 `ui规范.selection.json`。
- 新页面从 `docs/ui-v4-new-page-template.md` 开始。
- 短记录/确认/管理弹窗使用 inline overlay，不用系统 sheet 冒充小弹窗。
- 所有用户文案同时提供中文、英文、德文；动态字符串走 `L10n` / `AppLocalizedText`。

## 构建与验证

常规小改：

```bash
scripts/build-debug-fast.sh
```

UI 改动：

```bash
scripts/audit-ui-v4.sh --changed
```

后台、定位、timer、常驻动画相关改动：

```bash
scripts/audit-runtime-guardrails.sh
```

资源或 Git 体积异常：

```bash
scripts/audit-git-size.sh
```

发布前至少验证：

- App Store 隐私权限说明与实际行为一致。
- 无遛狗时不持续定位。
- running 遛狗锁屏/后台继续记录路线。
- 低电量模式下常驻动画降级，关键交互仍顺滑。
- `scripts/build-debug-fast.sh` 通过；必要时跑相关 SwiftData in-memory 测试。
