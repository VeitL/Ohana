# QA Testing Tracker — Ohana

> 最后更新：2026-03-05（Phase 49 重建）
> 规则：已完成 [x] 和「待办 Backlog」跳过，只处理未完成条目。

---

## 模块 1：ArkSchemaV11 模型升级

| # | 测试项 | 状态 |
|---|--------|------|
| 1.1 | App 冷启动后无崩溃（V10→V11 迁移成功） | [ ] |
| 1.2 | 旧数据（V10）迁移后 Pet/Human.coconutBalance 默认为 0 | [ ] |
| 1.3 | 旧数据（V10）迁移后所有 Log.executorId 默认为 nil | [ ] |
| 1.4 | 新建 PetPottyLog 时 executorId 字段可正确保存 | [ ] |
| 1.5 | 新建 PetWalkLog 时 executorId 字段可正确保存 | [ ] |
| 1.6 | 新建 PetCareLog 时 executorId 字段可正确保存 | [ ] |
| 1.7 | 新建 PetExpenseLog 时 executorId 字段可正确保存 | [ ] |
| 1.8 | Pet.coconutBalance 可读写，数值正确持久化 | [ ] |
| 1.9 | Human.coconutBalance 可读写，数值正确持久化 | [ ] |

---

## 模块 2：设备身份绑定

| # | 测试项 | 状态 |
|---|--------|------|
| 2.1 | SettingsView 有 Human 时显示「设备身份」区域 | [ ] |
| 2.2 | SettingsView 无 Human 时「设备身份」区域隐藏（安全降级） | [ ] |
| 2.3 | 选中某 Human 后，头像呈 goLime 圆环高亮，下方显示确认文案 | [ ] |
| 2.4 | 选中「未绑定」后，currentActiveHumanId 被清空（""） | [ ] |
| 2.5 | 重启 App 后身份绑定状态持久化（@AppStorage） | [ ] |
| 2.6 | 绑定身份后执行便便打卡 → PetPottyLog.executorId == 选中人 UUID | [ ] |
| 2.7 | 绑定身份后喂食打卡 → PetCareLog.executorId == 选中人 UUID | [ ] |
| 2.8 | 绑定身份后喂水打卡 → PetCareLog.executorId == 选中人 UUID | [ ] |
| 2.9 | 绑定身份后遛狗结束 → PetWalkLog.executorId == 选中人 UUID | [ ] |
| 2.10 | 未绑定（""）时所有打卡的 executorId 为 nil，不崩溃 | [ ] |
| 2.11 | QuickPottySheet 打卡注入 executorId 正确 | [ ] |
| 2.12 | PetCareTrackingCard 铲屎打卡注入 executorId 正确 | [ ] |
| 2.13 | ArkCrewIDCardView 背面 feed/water/potty 打卡注入 executorId 正确 | [ ] |
| 2.14 | PetFoodManagementView quickFeed/quickWater 注入 executorId 正确 | [ ] |

---

## 模块 3：QuestManager 分润引擎

| # | 测试项 | 状态 |
|---|--------|------|
| 3.1 | awardAction(.walk) → pet.coconutBalance +amount, human.coconutBalance +amount, coconutCount +amount | [ ] |
| 3.2 | awardAction(.feed) → pet.coconutBalance +amount, human.coconutBalance +amount, coconutCount +amount | [ ] |
| 3.3 | awardAction(.water) → pet.coconutBalance +amount, human.coconutBalance +amount, coconutCount +amount | [ ] |
| 3.4 | awardAction(.litter) → 仅 human.coconutBalance +amount, coconutCount +amount，pet 不变 | [ ] |
| 3.5 | awardAction(.potty) → 仅 coconutCount +amount，pet/human 均不变 | [ ] |
| 3.6 | humanId 为 nil 时不崩溃，仅更新全岛总库 | [ ] |
| 3.7 | humanId 在 allHumans 中找不到时不崩溃，安全降级 | [ ] |
| 3.8 | 全岛 coconutCount 实时反映在 OverviewView 椰子胶囊 | [ ] |

---

## 模块 4：SynergyFlashCard UI

| # | 测试项 | 状态 |
|---|--------|------|
| 4.1 | islandStatsBento ScrollView 中 SynergyFlashCard 正常显示 | [ ] |
| 4.2 | 无 human/pet 打卡数据时显示「欢迎来到欧哈纳」默认卡（安全降级） | [ ] |
| 4.3 | 6秒自动轮播到下一张（分页点更新） | [ ] |
| 4.4 | 点击卡片手动切换到下一张，带 Spring 动画 | [ ] |
| 4.5 | 有2个以上 Human 且有铲屎记录时显示「铲屎战况」简报 | [ ] |
| 4.6 | 有遛狗记录+executorId 时显示「散步搭子」简报 | [ ] |
| 4.7 | 有支出记录+executorId 时显示「首席提款机」简报 | [ ] |
| 4.8 | 有 coconutBalance > 0 的成员时显示「椰子富翁」简报 | [ ] |
| 4.9 | 卡片宽度 280，不超出 ScrollView 可视范围 | [ ] |
| 4.10 | View 消失时 Timer 正确 invalidate（无内存泄漏） | [ ] |

---

## 模块 5：CoconutWealthRankingCard UI

| # | 测试项 | 状态 |
|---|--------|------|
| 5.1 | islandStatsBento ScrollView 中 CoconutWealthRankingCard 正常显示 | [ ] |
| 5.2 | 全岛总资产数字正确反映 QuestManager.shared.coconutCount | [ ] |
| 5.3 | 所有成员 coconutBalance == 0 时显示「完成打卡即可解锁财富榜」提示 | [ ] |
| 5.4 | 有余额成员时显示排行榜（最多4名，降序） | [ ] |
| 5.5 | 第1名胶囊显示 goLime 高亮色 | [ ] |
| 5.6 | Pet 和 Human 混排在同一榜单中 | [ ] |
| 5.7 | 卡片宽度 260，布局不错位 | [ ] |

---

---

## 模块 6：多巴胺暴击引擎（QuestManager）

| # | 测试项 | 状态 |
|---|--------|------|
| 6.1 | amount < 0（消耗）时直接扣除，不触发暴击，日志记录正确 | [ ] |
| 6.2 | 多次调用 addCoconuts(1)，约 11% 概率触发小暴击（实际 +7🥥） | [ ] |
| 6.3 | 小暴击时日志标题为 "🎉 触发幸运暴击！"，金额为 amount×2+5 | [ ] |
| 6.4 | 大暴击时日志 emoji 为 "🎁"，标题为 "👑 奇迹发生！主子赏的大红包！"，金额为 amount×5+20 | [ ] |
| 6.5 | 大暴击触发双次 .heavy 触觉，小暴击触发 .medium 触觉，普通无额外触觉 | [ ] |
| 6.6 | 暴击后 coconutCount 正确累加（含暴击倍率后的数量） | [ ] |
| 6.7 | CoconutLogView 明细显示暴击后的实际数量和标题 | [ ] |
| 6.8 | 现有 `.coconutRewardOverlay` 动画逻辑不受影响（仍能正常播放） | [ ] |

---

## 模块 7：生命之树被动收益

| # | 测试项 | 状态 |
|---|--------|------|
| 7.1 | 树等级 < .thriving 时，OasisRewardView 树形图标附近无气泡按钮 | [ ] |
| 7.2 | 树等级 >= .thriving 且今日未领取时，显示 goYellow 气泡「领取今日掉落 🥥」 | [ ] |
| 7.3 | 气泡有呼吸跳动动画（scaleEffect 1.0 ↔ 1.08 循环） | [ ] |
| 7.4 | 点击气泡后 coconutCount +3，日志标题「生命之树的馈赠」 | [ ] |
| 7.5 | 领取后气泡消失（justHarvested = true），带 Spring 动画 | [ ] |
| 7.6 | 点击领取触发粒子特效（spawnEnergyParticles） | [ ] |
| 7.7 | 重启 App 后今日已领取状态持久化（UserDefaults["lastTreeHarvestDate"]） | [ ] |
| 7.8 | 次日（跨越午夜）重新可领取，气泡重新出现 | [ ] |
| 7.9 | 椰子不足时 harvestDailyPassiveIncome 不受影响（被动收益不消耗椰子） | [ ] |

---

---

## 模块 8：Phase 51 — Bug Fix Sprint（11 bugs）

| # | 测试项 | 状态 |
|---|--------|------|
| 8.1 | 每日首次打开 App，CoconutLogView 出现「每日登录奖励」记录 +1🥥 | [ ] |
| 8.2 | 添加循环喂食提醒（每天），日历视图连续 7 天均出现该提醒 | [ ] |
| 8.3 | 添加每天提醒后，CalendarView 中 180 天内的每一天均有 Reminder 条目 | [ ] |
| 8.4 | Quick Access：创建「喂食」和「喂水」两张卡，喂食待办仅点亮喂食卡，不串线到喂水卡 | [ ] |
| 8.5 | Quick Access：首页 3D 转盘切到宠物 B，Quick Access 中该宠物的待办红点正确显示 | [ ] |
| 8.6 | 点击 Quick Access「便便」打卡，当前宠物 `coconutBalance` +1，全岛总库 +1 | [ ] |
| 8.7 | 点击 Quick Access「喂食」打卡，宠物 `coconutBalance` +1，当前 Human `coconutBalance` +1 | [ ] |
| 8.8 | 点击 Quick Access「喂水」打卡，宠物 `coconutBalance` +1，当前 Human `coconutBalance` +1 | [ ] |
| 8.9 | 添加健康记录（疫苗），设置有效期距今 3 天，BackBentoDashboard 显示红色紧急提醒行 | [ ] |
| 8.10 | 有效期超过 7 天时，BackBentoDashboard 不显示紧急提醒行 | [ ] |
| 8.11 | PetImmunityCard 中，有设置 expirationDate 的记录显示实际到期日，而非计算推算日 | [ ] |
| 8.12 | AddHealthRecordSheet 选择疫苗类型打开后，名称栏自动填入「<宠物名>接种疫苗」 | [ ] |
| 8.13 | AddHealthRecordSheet 疫苗默认名可手动覆盖编辑 | [ ] |
| 8.14 | AddHealthRecordSheet 类型选择器包含「体内驱虫」和「体外驱虫」两个新选项 | [ ] |
| 8.15 | 旧数据中 `.medication` 类型记录在 PetImmunityCard「体内驱虫」行中仍能显示 | [ ] |
| 8.16 | 点击「+ 添加快捷入口」，若转盘顶牌为宠物，AddQuickActionSheet 直接跳过选宠步骤（Step 2） | [ ] |
| 8.17 | 进入宠物详情页后返回首页，Quick Access 仍过滤当前宠物的 actions（activeCritterId 不丢失） | [ ] |
| 8.18 | 财富榜「全岛总资产」数字 = 所有 Pet.coconutBalance 之和 + 所有 Human.coconutBalance 之和 | [ ] |
| 8.19 | 财富榜卡片无背景色和边框（透明卡片） | [ ] |
| 8.20 | 财富榜中宠物和人类均出现在排行榜列表（即使 balance = 0） | [ ] |

---

---

## 模块 9：Phase 52 — Bug Fix + Feature Sprint N1~N10

| # | 测试项 | 状态 |
|---|--------|------|
| 9.1 | Quick Access 排泄卡单击：触觉震动仅发生1次（不重复），椰子+1（不+2） | [ ] |
| 9.2 | Quick Access 铲猫砂打卡：全岛总库+1，Human coconutBalance+1，宠物 coconutBalance+1 | [ ] |
| 9.3 | 遛狗结束后：全岛总库增加，Human coconutBalance 增加，宠物 coconutBalance 增加 | [ ] |
| 9.4 | 铲猫砂/遛狗后：OasisRewardView 生命树 EXP 增加（绿洲页刷新后树形等级变化） | [ ] |
| 9.5 | 首次安装（重置 ohana_has_onboarded=false）：App 启动显示引导流程，不进入主页 | [ ] |
| 9.6 | 引导第2步：输入名字后可进入下一步；名字为空时「继续」按钮置灰不可点 | [ ] |
| 9.7 | 引导完成后：Human 被创建并在图鉴中可见，currentActiveHumanId 已写入 | [ ] |
| 9.8 | 引导完成后再次重启 App：直接进入主页，不再显示引导 | [ ] |
| 9.9 | 宠物B详情页返回首页：转盘顶牌为B，Quick Access 显示B的动作 | [ ] |
| 9.10 | 转盘手动滑动切换后返回首页：顶牌保持最后滑到的宠物 | [ ] |
| 9.11 | Today's Tasks 完成一项待办：coconutCount +1，日志中出现「✅ 完成待办」记录 | [ ] |
| 9.12 | CalendarView 左滑完成一个 Event：今日对应 Reminder 的 status 变为 "completed" | [ ] |
| 9.13 | CalendarView 左滑反选（取消完成）：Reminder 的 status 恢复为 "pending" | [ ] |
| 9.14 | 首页右上角：用户头像圆形按钮（左）+ 椰子数胶囊按钮（右）各自独立 | [ ] |
| 9.15 | 点击椰子数按钮：弹出 CoconutLogView sheet | [ ] |
| 9.16 | 点击用户头像：弹出菜单含「添加成员/管理主页/设置」三项 | [ ] |
| 9.17 | CalendarView 右上角 toolbar：视图切换 + 添加 + 椰子数按钮，点击椰子数进入 CoconutLogView | [ ] |
| 9.18 | 图鉴页右上角 toolbar：添加成员 + 椰子数按钮，点击椰子数进入 CoconutLogView | [ ] |
| 9.19 | 绿洲页椰子数按钮（原有位置）点击进入 CoconutLogView | [ ] |
| 9.20 | CoconutLogView 首次打开（有打卡记录后）：出现成员筛选胶囊（「全部」+各执行者） | [ ] |
| 9.21 | 点击某成员胶囊：列表仅显示该成员的记录，其他成员记录隐藏 | [ ] |
| 9.22 | 每条有执行者的记录：显示执行者 tag 徽章（goLime 底色小胶囊） | [ ] |
| 9.23 | AddHealthRecordSheet 选择疫苗：名称栏出现且自动填入「<宠物名>接种疫苗」 | [ ] |
| 9.24 | AddHealthRecordSheet 选择体外驱虫：名称栏出现，有效期默认开启 | [ ] |
| 9.25 | AddHealthRecordSheet 选择体内驱虫：名称栏出现，有效期默认开启 | [ ] |

---

## 模块 N：待办 (Backlog / 待测试)

- task31: Quick Access 卡片实时待办状态联动
- task10: 喂食余粮扣除 + 时间选择器
- task34: 各详情页沉浸式深色图表重构
- Widget 实现
- CloudKit 同步
