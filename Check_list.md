# Ohana 功能完成清单

> 最后更新: 2026-04-26（GO UI 宠物/人类卡展开态快捷操作与粮仓管理更新）| Build: ✅ | Schema: ArkSchemaV36
>
> **规则**：仅在完成新的功能模块或重大 UI 重构时更新本文档，小 bug 修复不记录。

---

## 当前完成功能模块

### 核心架构
- [x] **英文界面**（2026-04-16）：`en.lproj/Localizable.strings`（约 3250 条机翻 + 可续跑脚本 `scripts/generate_en_localizable.py`）、`en.lproj/InfoPlist.strings`，`CFBundleLocalizations` + `knownRegions` 含 `zh-Hans`；界面语言随系统「首选语言」切换
- [x] SwiftData 多版本 Schema 迁移链（V23→V31），轻量迁移策略
- [x] `SharedModelContainer` 单例 + 磁盘备份库（`ohana_disk_fallback`），避免数据丢失
- [x] `QuestManager`（椰子奖励）+ `OasisTreeManager`（生命之树等级系统）
- [x] `EntityKind` 枚举统一 `relatedEntityType` 字符串（向下兼容旧数据）
- [x] 数据备份/恢复（`DataBackupManager`）

### 首页（GO UI / OverviewView）
- [x] **GO UI 展开态快捷模块**（2026-04-26）：`FocusStackHomeTestView` 的宠物卡展开后复用经典 UI `GoQuickActionCard` 网格样式，读取同一份 `quickActionItems_v2`，短按/长按/Popover 行为与经典快捷操作保持一致
- [x] **GO UI 展开态快捷编辑**（2026-04-26）：宠物卡展开后的快捷操作支持铅笔编辑、删除、拖拽排序和添加入口，编辑态保持最多 4 个，保存回 `quickActionItems_v2`
- [x] **GO UI 人类卡快捷操作同步**（2026-04-26）：人类卡展开后使用同款 `GoQuickActionCard` 网格，支持体重 / 运动 / 用药 / 备注和编辑保存
- [x] **椰子增长动画**（2026-04-26）：`CoconutBalanceCapsule` 在椰子数增加时 pulse + `+N` 浮标，减少时不触发奖励动效
- [x] **GO UI 细节可读性**（2026-04-26）：顶部打卡/椰子胶囊左移，展开宠物卡高度降低，卡片堆左下角重复名字移除，快捷操作卡在深色模式使用高对比文字与 SF Symbol
- [x] 全局固定顶栏（`globalFixedHeader`），右侧统一 32pt 行高，无 Tab 切换跳动
- [x] 宠物钱包卡转盘（`PetWalletStack`）：正面 MeshGradient（随主题色动态）+ 背面翻转动画
  - 背面重设计为 **2×4 功能枢纽**（8 格，SF Symbols 纯色剪影）：编辑信息 / 日历 / 健康档案 / 证件保障 / 重要时刻 / 成就 / 饮食管理 / 用药管理（鱼类隐藏）
  - 设置齿轮 → `PetCardBackSettingsSheet`（基本信息/寄养卡/彩虹桥/清空/删除）
  - 所有功能入口均以 sheet 形式从 `OverviewView` 弹出，无需进入 `PetDetailView`
- [x] **首页简化 · 岛屿三层重构**（2026-04-16）
  - 顶部新增 `IslandMoodHeaderStrip`（60pt）：天气 emoji/情绪/负反馈汇总，点击弹 `IslandSummarySheet`
  - 宠物卡下方 `FamilyActivityStripView.compact` 胶囊（30pt）：家人头像堆叠 + 总次数，点击展开完整 Sheet
  - 新增 `TodayFocusCard`（130pt 单卡）按优先级展示 1 件该做的事，替换原 `HomeHighlightDeck` 水平滑组
  - 记忆碎片 / 岛屿统计收进 `HomeMoreSection` 折叠区（`AppStorage("home_more_expanded")`）
  - 宠物卡顶卡 `idleBreath` 呼吸漂浮 ±3pt / 6s；连击 ≥ 7 添加 `StreakFlameParticles` 火苗粒子
  - 首屏可见模块：7+ → 3，纵向滚动 2 屏 → 1 屏
- [x] `HomeHighlightDeck`（已废弃，保留为死代码，首页改用 `TodayFocusCard`）
- [x] 快捷操作网格（iOS 桌面风格编辑模式，长按/短按分流）
  - 喂食、喂水/换水、铲屎/换砂、便便、体重、花费、遛狗、逗玩、护理、健康、记录时刻
  - 护理 Popover / 健康 Popover（5选项）/ 便便 Popover
- [x] 首页 Menu 合并「添加成员」和「设置」为二级菜单
- [x] 今日任务（岛屿委托轮播 `IslandQuestCarousel`）
- [x] 岛屿每日报告（`IslandDailyReportSheet`，每日首次打开触发）
- [x] `IslandToastManager` 全局连击 Toast
- [x] 记忆碎片滑走发椰子
- [x] 防重复打卡（`AntiRepeatCareManager`，家庭协作防误操作）

### 宠物管理
- [x] 添加宠物向导（`AddPetWizardView`）：**横向 6 步卡片向导**（`TabView` paged），顶卡固定 + 下方左右滑动信息卡
  - Step 1: 名字 / 物种（选「其他」可手动输入）/ 品种下拉
  - Step 2: 头像设置（PhotosPicker + 相机 + 剪贴板透明PNG提示）
  - Step 3: 生物特征（性别主题色高亮 / 生日→等效人类年龄 / 到家日→已陪伴天数）
  - Step 4: 外貌 & 主题色（毛色/瞳色固定宽度防布局偏移）
  - Step 5: 性格标签（39 个内置 SF Symbols 标签 + 自定义标签内联输入框）
  - Step 6: 确认页（主题色色块展示 + 保存按钮含重名校验）
- [x] `PetSilhouetteView`：极简高级剪影（低频眨眼动画，`isAnimationEnabled` 可静态）
- [x] 16种高对比度宠物主题色（非绿色系），传播到所有图表/卡片
- [x] 宠物彩虹桥模式：星空渐变纪念 UI（`RainbowBridgeService`）

### 健康与医疗
- [x] `PetHealthDetailView`：右上角 Menu（预防护理 / 就诊记录 / 用药记录）
- [x] `AddHealthRecordSheet`：有效期自动推算（疫苗+1年/体内驱虫+3月/体外+1月）
- [x] BCS 体型评分（1-9，`PetBodyConditionEstimator` 自动估算）
- [x] 宠物用药管理（`PetMedicationDetailSheet`）：打卡写 `EventType.petMedicationDose`，生成岛屿委托
- [x] 异常症状追踪（`SymptomLog`）+ 生理期记录（`HeatCycleLog`，仅未绝育）
- [x] 趋势交叉预警（`PetHealthAlertEngine`）：饮水体重交叉/步数低/重度症状/发情孕期

### 保险管理
- [x] `PetInsuranceView`：保单列表，卡片 Menu（编辑/详情/删除）
- [x] `AddPetInsuranceSheet`：保单号/保额 Toggle；付款频次等高格；首期日期选择；自动生成全期 PetExpenseLog + 日历事件
- [x] `InsurancePolicyDetailSheet`：进度条 + Bento + 报销记录
- [x] `InsuranceClaim` 报销闭环：申请 → 审批 → 写负值 PetExpenseLog
- [x] `ExpenseCategory.insurancePremium`（保险费分类，饼图青色）

### 花费与统计
- [x] `AddExpenseSheet`：4列分类网格，支付人选择（`executorId`），Sheet 背景 `.bar`
- [x] `IslandExpenseDashboard`：多宠物支出饼图/折线，含保险费 + 报销净节省
- [x] `IslandWeightDashboard`：按 UUID `seriesID` 分线（防同名合并），宠物用 `weightInKg`
- [x] `HumanWeightHistoryView`：人类体重历史

### 护理计划与日历
- [x] `CarePlanCalendarSync`：换水/换砂/铲屎间隔计划 ↔ 日历 Event，支持 `cycleAnchor`
- [x] `QuickWaterDetailSheet`：双态胶囊切换喂水/换水，「保存并同步日历」
- [x] `QuickLitterDetailSheet`：铲屎/换砂间隔、提醒、截止日期
- [x] 计划喂食过期标 `ReminderStatus.failed`，首页补偿刷新

### 照片与记录
- [x] `PetPhotoAlbumView`：按年月分组，`@Attribute(.externalStorage)` 防膨胀
- [x] `QuickMomentSheet`：仪式感设计（心情标签/定位/虚线照片区/荧光绿保存键）
- [x] `PetMomentsHubView`：「时光 | 相册」分段统一入口

### 植物模块
- [x] `PlantDashboardView`：植物卡片网格 + 紧急浇水区
- [x] `PlantCareLog`：浇水/施肥历史，写 Event 计能量，生成岛屿委托
- [x] 日历植物着色（`themeColorHex`）

### 日历
- [x] 双模式顶栏（经典嵌入首页 / 独立）
- [x] 宠物筛选条（`CalendarPetChipFilterBar`，`@AppStorage` 持久化，纯色剪影图标）
- [x] `SwipeableEventRow`：浅/深色可读，宠物主题色着色，SF Symbols 纯色剪影图标
- [x] `EventType.foodChange` 不在日历列表展示
- [x] 重复日程逾期逻辑修复：逾期状态按**单次**计算，不污染整个系列
- [x] 添加事件页非全天时间输入：Google 日历风格，开始/结束各一行（左日期右时间）

### 设置与背景
- [x] `ArkBackgroundView`：9种背景风格，`SettingsView` 横向卡预览切换
- [x] iOS 26 UI 测试页（`iOS26UITestView`）：Liquid Glass 规范展示

### 家庭协作
- [x] 共享「执行人」胶囊 `ExecutorPickerBar`：所有打卡 Sheet 顶部展示当前家庭成员 + 一键切换
  - 读写 `@AppStorage("currentActiveHumanId")`，与 AddExpenseSheet 支付人默认值打通
  - 接入 7 个核心 Sheet：喂食 / 喂水 / 换水滤材 / 便便 / 铲屎 / 逗玩 / 快捷喂食喂水 Popover
- [x] 宠物卡下方「今日 · 谁在照顾 TA」活动条 `FamilyActivityStripView`
  - 聚合当日 Care / Potty / Walk / Expense 记录，按 (humanId, 动作类别) 去重
  - 头像圆 + SF Symbol 动作徽章 + 11pt 姓名，最多 8 条
  - 空态自动隐藏，仅顶牌为宠物时渲染
- [x] **多人打卡温馨卡**（`MemoryEngine.detectMultiPersonDay`）
  - 当日 ≥ 2 位家人护理同宠物 → 记忆碎片「全家都在爱 TA」，优先级最高
- [x] **任务指派 @ 家庭成员**（`BountyBoardView` / `AddBountyTaskSheet`）
  - `BountyTask` 新增 `assignedToId/Name/Emoji` 三字段（向前兼容）
  - 完成权限：无指派 → 任何家人可接；有指派 → 仅被指派者；创建者可撤销
  - `OasisRewardView` 首页「家庭悬赏榜」红点：显示 `@我 X 个待完成`
- [x] **家庭周报 Tab**（`BountyBoardView` 第 3 个 Tab）
  - 本周柱图 + 「本周最勤快」徽章
  - 统计 🍖 喂食 / 🦮 遛 / 💩 厕所 / 💰 花费
  - 周日 20:00 本地推送（`FamilyWeeklyReportService`）
- [x] **悬赏榜 / 扭蛋机 UI**（`BountyBoardView` / `AddBountyTaskSheet` / `GachaView`，2026-04-16）
  - 与 `CoconutShopView` 对齐：`ArkBackgroundView`、导航栏毛玻璃、`OhanaFont`、语义文字色、主按钮 `arkInk on goPrimary`

### 增长 / 留存机制
- [x] **椰子奖励按质量加成**（`QuestManager.QualityBonus`）
  - 精准克数 +20% / 写备注 +20% / 照片 +50% / 交叉叠加
  - 椰子日志标题自动附带加成徽章
  - 已接入 `QuickFeedDetailSheet` + `PetFoodManagementView.quickFeed`
- [x] **岛屿负反馈系统**（适度焦虑）
  - `IslandMood.cloudy` 新增阴天态 + 4 种气象粒子
  - `IslandNegativeFeedback.signals`：连击断裂 / 用药晚遗漏 / 喂食 >72h / 植物 >7 天未浇水
  - 首页 `IslandNegativeFeedbackBanner`：胶囊横幅 + 多信号翻页 + 当日可关闭
  - 严重度 `.critical`/`.warning` 双色排序
- [x] **椰子余额可预期化**
  - `CoconutBalanceCapsule` 长按 → 椰子明细 / 椰子商店
  - 胶囊下方「距 🍖 再 18🥥」预测提示（`CoconutPredictionHelper`）
- [x] **首日承诺（D0 留存钩子）**（`Day0PromiseSheet`）
  - 保存宠物后弹 Sheet：按物种差异化承诺（拍照/陪玩/记录/称重 + 狗散步/猫梳毛）
  - 勾选项 → 自动写入 `BountyTask`，所有家人可接
- [x] **AHA 破壳动画**（`AhaHatchOverlay`）
  - 保存后 3 秒分阶段动画：光晕 → 蛋壳震动 → 宠物 emoji 跳出 → 标题「{name} 加入 Ohana」
  - 之后自动推出 Day0 承诺 Sheet

---

## 待办 / 未来规划

- [ ] 多设备 iCloud 同步
- [ ] Apple Watch 伴侣 App
- [ ] 宠物 AI 健康助手
- [ ] 家庭邀请 / 多成员实时协作
