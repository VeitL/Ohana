# Ohana App QA 已完成任务归档

---

## 归档时间：2026-03-05（Sprint 4 开始前归档）

### 模块 A：高危 Bug 修复与交互纠错
- [x] 1. 首页 Island Stats 图表点击死区修复
  - 📂 涉及文件：`OverviewView.swift`, `IslandStatComponents.swift`, `IslandUnifiedDashboardView.swift`
  - 📝 详细要求：为首页的 Island Stats 图表卡片添加点击事件。点击后必须全屏弹出 `IslandUnifiedDashboardView`（全岛数据聚合面板）。解决目前点按无反应的死区问题。
  - 💬 用户的测试反馈：Bug 仍存：Island Stats 模块中的"粮仓"图表卡应该和其他三个一样，弹出一个展示所有宠物的粮仓管理的详情页。✅ 已修复：新建 AllPetsFoodOverviewSheet，列出所有宠物余粮状态，点击进入 PetFoodManagementView。

- [x] 2. 卡片背面打卡"数字双倍增加"严重 Bug 修复
  - 📂 涉及文件：`ArkCrewIDCardView.swift`
  - 📝 详细要求：排查并修复宠物卡片背面点击"喂食/喂水/便便"时数字加倍的渲染逻辑错误（目前按1次变2次，再按变4次），确保每次点击严格只 +1。
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 3. 遛狗操作触发重构与 UI 极简化
  - 📂 涉及文件：`ArkCrewIDCardView.swift`
  - 📝 详细要求：在卡片背面点击"开始遛狗"时，仅需在后台启动计时并呼出全局可见的遛狗悬浮窗（GlobalWalkBanner）。**必须彻底删除**卡片背面自带的那一套冗余的遛狗历史记录 UI 展示。
  - 💬 用户的测试反馈：✅ 已修复：cardBackView 移除 isActiveWalk 分支，始终显示 Bento 背面。

- [x] 4. 彻底删除原"日常照料"详情页及入口重定向
  - 📂 涉及文件：`PetFoodManagementView.swift`, `PetDetailView.swift`, `PetHygieneCard.swift`
  - 📝 详细要求：删除旧版的"日常照料详情页"。将主页卡片上的"日常照料"入口直接重定向到原来的 `PetFoodManagementView`。并将该页面正式改名为"饮食与排泄管理"。
  - 💬 用户的测试反馈：噗噗电台移到护理打卡详情页中，详情页增加铲屎和便便记录（狗狗不需要铲屎，猫需要铲屎和便便）。猫咪护理打卡有铲屎和便便两个选项，狗只有一个便便选项。✅ 已修复：PottySection 从 PetFoodManagementView 移除，在 HygieneDetailSheet 末尾新增噗噗电台区块（今日统计+打卡+记录列表，猫显示铲屎+便便，狗只显示便便）。

- [x] 5. 零散打卡功能合并与归类
  - 📂 涉及文件：`PetDetailView.swift`, `PetHygieneCard.swift`
  - 📝 详细要求：把所有"噗噗打卡"和"便便图表"统一挪进刚刚改名的"饮食与排泄管理"页；把原来混在外面的"铲屎打卡"专属入口，精准挪入"护理打卡 (Hygiene)"卡片中。
  - 💬 用户的测试反馈：功能遗漏：「铲屎打卡」功能未能成功迁移，当前在「护理打卡 (Hygiene)」界面中完全看不到铲屎的选项。✅ 已修复：PetHygieneCard 底部新增铲屎/便便快捷打卡行（按 species 区分猫/狗）。

- [x] 6. 核心图表新增快捷打卡按钮
  - 📂 涉及文件：`PetDetailView.swift`
  - 📝 详细要求：在宠物详情页的"噗噗图表"和"花费图表"的右上角，分别加上一个醒目的 `+` 号按钮，方便用户不进详情页就能一键记账或打卡。
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 7. 清理花费详情列表里的多余按钮
  - 📂 涉及文件：`ExpenseHistoryView.swift`
  - 📝 详细要求：进入"花费详情列表页"后，把里面图表上的快捷添加按钮删掉，避免和底部或列表原本的添加按钮冲突，保持视觉清爽。
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 8. 危险操作区安全分级拆分
  - 📂 涉及文件：`PetDetailView.swift` 或 `EditPetSheet.swift`
  - 📝 详细要求：在宠物编辑页最底部明确放置两个按钮。黄色/次警告色按钮："仅清空所有记录"（删记录留基本档案）；红色/最高警告色按钮："彻底删除该家人"（连档案带数据从数据库彻底抹除）。
  - 💬 用户的测试反馈：✅ 测试通过


### 模块 C：饮食与排泄管理深度优化 (原粮水管理)
- [x] 9. 粮食库存增加国际主流品牌选择器
  - 📂 涉及文件：`PetFoodManagementView.swift`
  - 📝 详细要求：将添加粮食的"品牌"输入框改成下拉选择器 (Picker)。必须内置中德主流品牌供选（如：皇家, 渴望, 爱肯拿, 巅峰, Josera, Wolfsblut, MAC's, 麦富迪, 严选等，附带"其他"选项）。
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 10. 喂食：默认容量设置 + 自动扣库存 + 达标拦截
  - 📂 涉及文件：`PetFoodManagementView.swift`
  - 📝 详细要求：允许勾选输入量为"默认每次喂食量"。每次打卡喂食，必须实时从 SwiftData 的"余粮总库存"中扣除克数。今日喂食累计达到设定目标克数时，打卡需弹出 Toast 提示"今日份量已达标"。
  - 💬 用户的测试反馈：✅ 已修复：FoodReminderSheet 重构，新增可选开始时间/结束时间 DatePicker、全天开关、重复频率选择器，保存时生成 Event+Reminder 并写入 SwiftData。

- [x] 11. 喂水：默认容量设置支持
  - 📂 涉及文件：`PetFoodManagementView.swift`
  - 📝 详细要求：与喂食逻辑保持一致，输入自定义 ml（毫升）后，可勾选将其保存为快捷打卡的默认容量值。
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 12. 粮/水打卡长按呼出待办系统
  - 📂 涉及文件：`PetFoodManagementView.swift`
  - 📝 详细要求：对喂食/喂水卡片上的「+ 打卡」按钮添加长按手势（Long Press）。长按后直接弹出"添加日历待办"弹窗 (AddReminderSheet)，并自动帮用户填好标题（如"喂食 50g"），方便快速建定闹钟。
  - 💬 用户的测试反馈：✅ 测试通过


### 模块 E：首页宠物卡片背面重构 (ArkCrewIDCardView)
- [x] 13. 废弃等大 8 宫格，引入 Bento Box 便当盒网格
  - 涉及文件：`ArkCrewIDCardView.swift`
  - 用户的测试反馈：✅ 测试通过

- [x] 14. 赋予短按与长按双重交互逻辑
  - 涉及文件：`ArkCrewIDCardView.swift`
  - 用户的测试反馈：路由逻辑错误：长按「喂食」或「喂水」时应跳转至「饮食与排泄」详情页；长按「铲屎」时应跳转至「护理打卡」详情页。✅ 已修复：BackBentoDashboard 长按喂食/喂水→onShowFood，长按铲屎→onShowCare。

- [x] 15. 顶部数据指标转化为快捷入口
  - 涉及文件：`ArkCrewIDCardView.swift`
  - 用户的测试反馈：路由修正：点击顶部的「上次便便/铲屎」数据卡片时，应路由至「护理打卡」页面，并请确保护理页面中包含铲屎选项。✅ 已修复：护理页已包含铲屎入口。

- [x] 16. 原地生成椰子掉落特效，拒绝弹窗打断
  - 📂 涉及文件：`ArkCrewIDCardView.swift`
  - 💬 用户的测试反馈：✅ 测试通过


### 模块 F：日历页面彻底翻新 (CalendarView)
- [x] 18. 终结全屏"📋"图标，引入动态视觉映射
  - 📂 涉及文件：`SwipeableEventRow.swift`
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 19. 优化发光时间轴与点击详情面板
  - 📂 涉及文件：`CalendarView.swift`
  - 💬 用户的测试反馈：✅ 测试通过


### 模块 G：绿洲圣地与生命之树联动 (OasisRewardView)
- [x] 20. 修复 UI 穿透错位与冗余计数器
  - 📂 涉及文件：`OasisRewardView.swift`
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 21. 让生命之树随打卡数据真实成长
  - 📂 涉及文件：`OasisRewardView.swift`
  - 💬 用户的测试反馈：✅ 已修复：energyParticles 提升到最外层 ZStack zIndex(99)。

- [x] 22. 新增"注入能量"的椰子消耗玩法
  - 📂 涉及文件：`OasisRewardView.swift`, `QuestManager.swift`
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 23. 底部功能区 Bento 化及进度直显
  - 📂 涉及文件：`OasisRewardView.swift`
  - 💬 用户的测试反馈：✅ 测试通过


### 模块 H：多巴胺循环与经济系统闭环 (Rewards & Economy)
- [x] 26. 特殊纪念日/生日投喂触发多巴胺爆裂
  - 📂 涉及文件：`SmartTodayCard.swift`
  - 💬 用户的测试反馈：✅ 已修复：GoldenRewardRow 新增"奖励宠物零食 🍖 庆祝这个特别时刻～"文案。

- [x] 28. 卡片正面增加翻转提示
  - 📂 涉及文件：`ArkCrewIDCardView.swift`
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 29. 卡片背面顶部指标栏重组与详情入口
  - 📂 涉及文件：`ArkCrewIDCardView.swift`
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 30. 空白处点击返回正面
  - 📂 涉及文件：`ArkCrewIDCardView.swift`
  - 💬 用户的测试反馈：✅ 测试通过


### 模块 J：Quick Access 与 SmartTodayCard (首页动态卡)
- [x] 31. Quick Access 快捷入口状态联动与手势区分
  - 📂 涉及文件：`OverviewView.swift`, `QuickAccess` 相关组件
  - 💬 用户的测试反馈：✅ 已实现：GoQuickActionCard 新增 pendingReminder 参数——有待办时卡片高亮边框+红点+显示待办标题；长按调用 handleLongPressAction；Context Menu 支持一键完成待办。

- [x] 32. SmartTodayCard (每日多巴胺卡) 空数据隐藏
  - 📂 涉及文件：`OverviewView.swift`, `SmartTodayCard.swift`
  - 💬 用户的测试反馈：✅ 已修复：SmartTaskEngine 移除 HygieneType 遍历逻辑，只读取真实 Reminder 对象。


### 模块 K：详情页 (Detail Pages) UI 降噪与沉浸式升级
- [x] 33. PetDetailView 降噪：移除冗余打卡按钮
  - 📂 涉及文件：`PetDetailView.swift`, `PetChartDashboard.swift`
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 34. 各模块详情页的"沉浸式深色图表"重构
  - 📂 涉及文件：`WeightHistoryView`, `ExpenseHistoryView`, `PottyOverviewView`, `PetFoodManagementView` 等
  - 💬 用户的测试反馈：✅ 已实现：PottyOverviewView 重构为沉浸式布局——顶部 ArkBackgroundView 深色区显示今日次数大字+7日柱状图+快速打卡按钮行，底部 F2F0F5 白色圆角前置卡片显示历史记录列表（含删除），与 WeightHistoryView/ExpenseHistoryView 风格完全一致。

- [x] 35. 移除噗噗历史记录的冗余计时
  - 📂 涉及文件：`PottyOverviewView.swift`
  - 💬 用户的测试反馈：✅ 测试通过


### 模块 L：底层数据 Bug 与多巴胺逻辑闭环
- [x] 36. 修复噗噗打卡"数据串户 (Cross-Pet Data)"严重 Bug
  - 📂 涉及文件：`ArkCrewIDCardView.swift`（BackBentoDashboard）, `PetFoodManagementView.swift`
  - 💬 用户的测试反馈：✅ 已修复：pottySection.todayCount 改为只读 pet.pottyLogs，不混入 careLogs。

- [x] 37. 修复背面打卡椰子未真实入账 Bug
  - 📂 涉及文件：`ArkCrewIDCardView.swift`, `QuestManager.swift`, `CoconutLogView.swift`
  - 💬 用户的测试反馈：✅ 已修复：CoconutLogView 改用 @Bindable 持有 QuestManager.shared。

- [x] 38. 行为打卡与日历事件的智能闭环防重复
  - 📂 涉及文件：`QuestManager.swift`, `SwipeableEventRow.swift`, `ArkCrewIDCardView.swift`, `PetFoodManagementView.swift`
  - 💬 用户的测试反馈：✅ 已修复：移除所有 autoCompleteReminders 调用，日历保持纯净。


### 模块 M：绿洲与椰子系统深度修复 (Oasis & Economy Bugs)
- [x] 39. 修复椰子记录 (CoconutLogView) 缺失消耗明细的 Bug
  - 📂 涉及文件：`CoconutLogView.swift`, `QuestManager.swift`
  - 💬 用户的测试反馈：✅ 测试通过

- [x] 40. 修复生命之树升级判定失效 Bug (越界不升级)
  - 📂 涉及文件：`OasisTreeManager.swift` 或 `QuestManager.swift`
  - 💬 用户的测试反馈：✅ 测试通过

  - [x] 42. 彻底修复删除宠物后的"数据幽灵" Bug (幽灵日历与快捷卡片)
  - 📂 涉及文件：`Pet.swift` (Model), `OverviewView.swift`, `CalendarView.swift`
  - 📝 详细要求：
    1. **排查 SwiftData 级联**：检查 `Pet` 模型中与 Log、Reminder、Event 等关联的属性，是否正确设置了 `@Relationship(deleteRule: .cascade)`。若没有，请在删除宠物时，手动遍历并 `modelContext.delete` 掉该宠物的所有底层关联数据。
    2. **UI 状态刷新**：确保删除宠物后，主页的 Quick Access 模块和日历页中关于该宠物的卡片/日程瞬间消失，不再残留幽灵数据。
  - 💬 用户的测试反馈：[留空，等我填写]


### 模块 N：待办 (Backlog / 待测试)
- [ ] 17. 彻底修复假删除 Bug + 左滑产出椰子
  - 📂 涉及文件：`SwipeableEventRow.swift`, `CalendarView.swift`
  - 📝 详细要求：修复右滑删除只是删了 UI 而没删数据的致命 Bug，强制执行 `modelContext.delete()` 彻底清库；左滑标记任务完成时，不仅要播放粒子特效，还要发放 5 个椰子奖励并显示 `+5🥥` 飘字动效。
  - 💬 用户的测试反馈：待测试

- [ ] 24. 椰子数据全站实时同步 (Single Source of Truth)
  - 📂 涉及文件：`QuestManager.swift` 及所有带有椰子余额的 View
  - 📝 详细要求：梳理全站代码，强制要求首页、绿洲、任务栏等所有展示 🥥 数量的视图全部监听唯一的全局状态。确保任何地方花掉或赚取椰子，全站数字无需刷新即可瞬间同步联动。
  - 💬 用户的测试反馈：待测试

- [ ] 25. 剥离并封装“全屏大爆金币”通用组件
  - 📂 涉及文件：`OhanaDesignSystem.swift`（`CoconutRewardModifier` 已存在并复用）
  - 📝 详细要求：原本只有添加宠物向导页有"+50🥥 巨型弹跳爆发"动画。请将这段动画代码提取封装为支持任意参数化（传入不同数量）的全局 Modifier 组件，让全 App 任何任务完成时都能随调随用。
  - 💬 用户的测试反馈：待测试

- [ ] 27. 新手村岛屿任务统一爽快反馈
  - 📂 涉及文件：`WelcomeQuestBentoView.swift`
  - 📝 详细要求：用户在主页上方点击领取“首次打卡”或“设置主题”的新手横向任务奖励时，同样必须调用封装好的“全屏大爆金币”组件，确保 App 核心奖励机制在视觉和情绪上的高度统一。
  - 💬 用户的测试反馈：待测试