# Ohana 功能完成清单

> 最后更新: 2026-04-02 | Build: ✅ | Schema: ArkSchemaV31
>
> **规则**：仅在完成新的功能模块或重大 UI 重构时更新本文档，小 bug 修复不记录。

---

## 当前完成功能模块

### 核心架构
- [x] SwiftData 多版本 Schema 迁移链（V23→V31），轻量迁移策略
- [x] `SharedModelContainer` 单例 + 磁盘备份库（`ohana_disk_fallback`），避免数据丢失
- [x] `QuestManager`（椰子奖励）+ `OasisTreeManager`（生命之树等级系统）
- [x] `EntityKind` 枚举统一 `relatedEntityType` 字符串（向下兼容旧数据）
- [x] 数据备份/恢复（`DataBackupManager`）

### 首页（OverviewView / MaterialDashboardView）
- [x] 全局固定顶栏（`globalFixedHeader`），右侧统一 32pt 行高，无 Tab 切换跳动
- [x] 宠物钱包卡转盘（`PetWalletStack`）：正面 MeshGradient（随主题色动态）+ 背面翻转动画
  - 背面重设计为 **2×4 功能枢纽**（8 格，SF Symbols 纯色剪影）：编辑信息 / 日历 / 健康档案 / 证件保障 / 重要时刻 / 成就 / 饮食管理 / 用药管理（鱼类隐藏）
  - 设置齿轮 → `PetCardBackSettingsSheet`（基本信息/寄养卡/彩虹桥/清空/删除）
  - 所有功能入口均以 sheet 形式从 `OverviewView` 弹出，无需进入 `PetDetailView`
- [x] `HomeHighlightDeck`：宠物卡下方 130pt 横滑甲板
  - 卡片：宠物今日状态 / 打卡连击 / 岛屿委托 / 岛屿等级
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

---

## 待办 / 未来规划

- [ ] 多设备 iCloud 同步
- [ ] Apple Watch 伴侣 App
- [ ] 宠物 AI 健康助手
- [ ] 家庭邀请 / 多成员实时协作
