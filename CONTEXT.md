# Ohana 项目 AI 导航文件
> 每次新对话开始时，将本文件内容贴入对话框，或在 Windsurf 中 @CONTEXT.md
> 最后更新：2026-04-19 | Schema: ArkSchemaV19 | Phase 1-76 完成

---

## ⭐ 主设计规范（权威来源）

> **所有 UI 工作必须以此为准，其他文档为补充参考。**

| 文件 | 内容 |
|------|------|
| `ohana-design-system/project/README.md` | 品牌概述、语气、色彩、字体、组件解剖、图标规范 |
| `ohana-design-system/project/tokens.json` | 全部设计 Token（颜色 / 间距 / 圆角 / 阴影 / 动效数值） |
| `ohana-design-system/project/ui_kits/ohana_ios/` | 四屏高保真 UI Kit：首页 / 宠物详情 / 椰子商店 / 生命树绿洲 |
| `UIRules.md` | Swift 实现层补充规则（当与设计系统冲突时，以设计系统为准） |

### 设计系统关键决策速查

| 决策 | 规范值 |
|------|--------|
| 主色（暗色） | `Color.goLime` = `#C8FF00` 荧光绿 |
| 主色（浅色） | `Color.goPrimary` = `#FF7600` 橙色 |
| 主色上的文字 | `#1A1A2E` = `Color.arkInk`（非纯黑） |
| 背景 | 深蓝渐变 `#2D4ECC→#1A2E8A→#0C1640` + lime/indigo/purple 浮动色球 |
| 卡片风格 | 玻璃卡片（UltimateGlassCard）/ 纯白实色卡片（用户明确要求时） |
| 圆角 | 主卡片 24pt · 小卡片 20pt · Bento 14pt · 按钮/胶囊 full |
| 字体 | `.system(design: .rounded)` 全局，Metric 数字最大 80pt Heavy |
| 图标 | SF Symbols（功能）/ Emoji（货币🥥 / 身份🐕🐈 / 奖励🎉🔥） |
| 底部 Dock | 玻璃胶囊，活跃 Tab = lime 背景 + 墨色文字 + label 展开 |
| 生命之树 | 首页核心英雄卡，`OasisTreeManager.shared` 提供实时数据 |
| 椰子余额 | 始终以 lime 胶囊展示，`QuestManager.shared` 管理 |

---

## 项目定位

- **App 名称**：Ohana（欧哈纳）
- **平台**：iOS 17+，Swift 6，SwiftUI + SwiftData + Swift Charts
- **定位**：家庭生命体综合管理（宠物 / 人类成员 / 植物统称 Critters）
- **App Group**：`group.com.guanchen.li.Ark`
- **设计语言**：Go UI — 青柠 `#C8FF00` 主色 + 深蓝渐变背景 + 浮动色球 + 毛玻璃卡片

---

## ⚠️ 改代码前必读的强制规则

### 1. Schema 变更
- 当前版本：**ArkSchemaV19**（V19 新增 `Pet.cardStyleRaw`）
- **任何 Model 字段变更** → 必须新建 `ArkSchemaV20`，在 `SharedModelContainer.swift` 的 `stages` 追加迁移
- 新增字段必须有默认值，尽量用 `lightweight` 迁移
- 绝对不能跳版本号

### 2. 椰子奖励
- **所有打卡** → 必须且只能通过 `QuestManager.shared.awardAction(type:pet:context:)` 发放椰子
- 禁止直接修改 `pet.coconutBalance` 或 `human.coconutBalance`
- 打卡有冷却机制（feed/water: 4h，potty: 2h，care: 24h，general: 2h）
- 双倍券逻辑在 `addCoconuts` 内自动处理，不需要外部干预

### 3. SwiftUI 数据响应
- 需要实时刷新的打卡数据 → 必须用 `@Query` 而非 `pet.walkLogs`（relationship 不实时响应）
- 参考 `PetHUDVitalSection` 的独立 struct + `@Query` 模式

### 4. 颜色规范
- `foregroundStyle` 中必须写 `Color.goLime`，不能写 `.goLime`
- 颜色定义在 `Utilities/ColorExtensions.swift`

### 5. 人类主题色
- 读取：`human.themeColor`（走 `HumanExtensions.swift` 计算属性）
- 写入：`human.themeColorHex = "XXXXXX"`（V15 起不再写 `notes`）

---

## 文件结构速查

```
Models/          # 33 个文件（SwiftData 模型 + 管理器）
Views/
  ├── Details/   # 35 个详情/子页面
  ├── Components/# 25 个可复用组件
  ├── Forms/     # 7 个表单/向导
  └── Home/      # 6 个首页子组件（含 CritterDeckCarousel / OasisRewardView）
Utilities/       # ColorExtensions / ImageCutoutService / ModelContextExtensions
ViewModels/      # IslandUnifiedStatsViewModel / IslandWealthViewModel2
```

---

## 核心管理器一览（改功能前先看这里）

| 管理器 | 文件 | 职责 |
|--------|------|------|
| **QuestManager** | `Models/QuestManager.swift` | 椰子奖励唯一入口，含冷却/暴击/双倍券/双边分润 |
| **OasisTreeManager** | `Models/OasisTreeManager.swift` | 生命树10级，能量计算，被动收益，升级奖励 |
| **StreakManager** | `Models/StreakManager.swift` | 连胜天数，保护盾检测 |
| **StreakRewardManager** | `Models/StreakRewardManager.swift` | Streak 里程碑奖励（7/30/100/365天） |
| **PetWalkingManager** | `Models/PetWalkingManager.swift` | 遛狗全流程，GPS 追踪，<20m 不奖励 |
| **LocationManager** | `Models/LocationManager.swift` | 定位权限，后台追踪（CLBackgroundActivitySession） |
| **NotificationManager** | `Models/NotificationManager.swift` | 通知调度，滑动窗口补充 |
| **PetHealthAlertEngine** | `Models/PetHealthAlertEngine.swift` | 健康预警扫描（疫苗/体重/遛狗/便便/证件） |
| **DataBackupManager** | `Models/DataBackupManager.swift` | 21 模型 JSON 全量导出/导入 |
| **ImageCutoutService** | `Utilities/ImageCutoutService.swift` | iOS 17 Vision 前景抠像 |

---

## 关键全局调用流程

### 打卡奖励流程（任何打卡入口均适用）
```
用户操作
→ QuestManager.shared.awardAction(type: OhanaActionType, pet: Pet?, context: ModelContext)
  → 冷却检测（isOnCooldown）→ 冷却中直接 return (0, 0)
  → 暴击 roll → 双倍券检测 → 双边分润
  → pet.coconutBalance += finalPet
  → human.coconutBalance += finalHuman（读 UserDefaults["currentActiveHumanId"]）
  → 写入 CoconutLogEntry
  → StreakRewardManager.checkAndAward(pet:)
→ UI：震动 + 椰子浮字特效（CoconutRewardModifier）
```

### 遛狗流程
```
PetWalkingManager.start(pet:) → LocationManager.startTracking()
→ GlobalWalkBanner 展开（可拖动气泡）
→ stop() → 距离<20m 跳过椰子 → 生成地图快照 → PetWalkLog 写入
→ awardAction(.walk) + poopCount × awardAction(.potty)
→ WalkSummarySheet 弹出
```

### 提醒流程
```
AddEventView → Event + Reminder(s)（循环事件：180天内批量生成，365天 hardCap）
→ NotificationManager.schedule(reminder) → UNCalendarNotificationTrigger
→ 完成/跳过/明天再说 → .snoozed 时创建次日新 Reminder
```

---

## 全局状态（UserDefaults）关键 Key

| Key | 用途 |
|-----|------|
| `currentActiveHumanId` | 当前设备绑定 Human UUID，QuestManager 自动读取 |
| `coconutCount` | 全局椰子总数 |
| `overview_activeCritterId` | 首页顶牌宠物 UUID |
| `quest_cooldownLogs` | 打卡冷却时间戳记录（petId_actionKey → Unix timestamp） |
| `shop_boostDoubleActive` | 双倍券激活标记 |
| `shop_streakShieldExpiry` | 连胜保护盾到期时间 |
| `oasis_injectedEnergy` | 生命树已注入能量 |
| `purchasedShopItems` | 已购商店道具 ID 列表 |
| `celebratedMilestoneDays` | 已触发庆典里程碑（防重复） |
| `ohana_has_onboarded` | 是否完成引导 |

---

## 数据模型速查

### Pet 模型关键字段
- `species`：dog / cat / rabbit / hamster / bird（影响 Quick Access 可用卡片）
- `coconutBalance`：由 QuestManager 管理，勿直接改
- `currentStreak` / `lastCheckInDate`：连胜相关
- `foodTrackingModeRaw`：casual（佛系）/ precise（精准）
- `passedAwayDate`：非 nil 表示已离世（Rainbow Bridge）
- `cardStyleRaw`：V19 新增，classic / minimal

### Quick Access 物种分配
- 狗：walk / feed / water / potty / care / play / health / expense / weight
- 猫：litter / feed / water / potty / play / care / health / expense / weight
- 鱼：feed / waterChange / filterClean / health / expense / weight
- 鸟：feed / water / cageCleaning / freeFlight / play / care / health / expense / weight
- 兔鼠：feed / water / litter / play / cageCleaning / care / health / expense
- 爬宠：feed / water / misting / substrateChange / play / health / expense / weight
- **黑名单机制**：存储 `qaExcluded_<petId>`，非激活列表

---

## 主要页面与文件对应

| 页面 | 文件 | 关键注意点 |
|------|------|-----------|
| 首页 | `Views/OverviewView.swift` | Apple Wallet 堆叠卡 + 首页模块排序 |
| 宠物详情 | `Views/Details/PetDetailView.swift` | HUD 用 `@Query` 实时查询，L1.5=PetHUDVitalSection |
| 卡片轮播 | `Views/Home/CritterDeckCarousel.swift` | 透明PNG→破框悬浮，普通图→高斯模糊背景 |
| 日历 | `Views/CalendarView.swift` | SwipeableEventRow 滑动操作 |
| 绿洲 | `Views/Home/OasisRewardView.swift` | 生命树 + 打卡日历 + 补签 + 被动收益 |
| 椰子商店 | `Views/Details/CoconutShopView.swift` | 消耗品可重复购买，不标记 purchasedSet |
| 扭蛋机 | `Views/Details/GachaView.swift` | 30🥥/次，含补打卡券奖品 |
| 家庭悬赏榜 | `Views/Details/BountyBoardView.swift` | JSON 存 AppStorage，椰子转移 |
| 粮食管理 | `Views/Details/PetFoodManagementView.swift` | 双轨制：佛系/精准 |
| 添加宠物向导 | `Views/Forms/AddPetWizardView.swift` | 头像粘贴抠图是主推 CTA，自动调 Vision 抠像 |
| 健康详情 | `Views/Details/PetHealthDetailView.swift` | 必须有关闭按钮（已修复 sheet 死锁） |

---

## 已知 Bug 与限制（改代码时注意）

| ID | 问题 | 状态 |
|----|------|------|
| BUG-2 | `UIScreen.main` deprecated（iOS 16+），多处存在 | 低优，待修 |
| LIMIT-1 | Sign in with Apple 未实现 | 待做 |
| LIMIT-2 | CloudKit 同步未实现（需付费开发者账号） | 待做 |
| **LIMIT-3** | **Widget Target 不存在（P0 优先）** | **待做** |
| LIMIT-4 | 多语言 Localizable.strings 未建立，中文硬编码 | 待做 |
| CHARTS | BarMark 的 `unit` 参数只支持静态值（.day/.hour/.month），不能动态传 `Calendar.Component`，否则 fatal error | 已知陷阱 |

---

## 常见问题的文件定位提示

**椰子没增加** → 先查 `QuestManager.awardAction` 是否被调用，再查冷却是否触发

**打卡数字不实时刷新** → 检查是否用了 `pet.walkLogs`（不响应），改为独立 struct + `@Query`

**Quick Access 卡片不显示** → 查 `QAConfig.load(for:species:)`，确认 species 参数传入，检查黑名单 key `qaExcluded_<petId>`

**Sheet 无法关闭** → 检查是否有 `@Environment(\.dismiss)` + toolbar 关闭按钮

**改了 Model 编译报错** → 必须新建 ArkSchemaV20 并在 `SharedModelContainer.swift` 追加迁移 stage

**体重/花费图表崩溃** → BarMark unit 参数必须是静态值，不能动态传

---

## Backlog 优先级提醒

- **P0（最高）**：Widget（App Group 基础设施已就绪，缺 Widget Target）
- **P1**：CloudKit 同步 / HealthKit 写入 / NFC 魔法贴
- **P2**：Siri 快捷指令 / Live Activity / PDF 导出 / 分享海报 / 多语言