# GO Club iOS App — UI Design Reference Document

> 基于 2025年11月 iOS截图（共106张）整理，用于完整复现该应用的视觉设计与交互规范。

---

## 一、设计语言总览

### 核心风格
- **风格关键词**：现代、活力、游戏化、健康科技
- **视觉基调**：深蓝渐变主背景 + 白色/彩色信息卡片，强调数据可视化
- **语气**：积极鼓励，简洁有力（"Every Step Counts!"）

---

## 二、色彩系统

### 主色
| 名称 | 用途 | 色值 |
|------|------|------|
| Primary Blue | 主背景、主按钮 | `#3B5BDB` → 渐变至 `#1E3A8A` |
| Accent Yellow | 高亮徽章、促销标签 | `#FFE500` |
| Accent Cyan | 次强调、图表高亮 | `#22D3EE` |
| Accent Pink | 分类色、装饰 | `#F472B6` |
| Accent Green | 成功状态、完成 | `#4ADE80` |
| Accent Orange | 警告、高能量活动 | `#FB923C` |

### 中性色
| 名称 | 色值 | 用途 |
|------|------|------|
| White | `#FFFFFF` | 主文字、卡片背景 |
| Gray 100 | `#F3F4F6` | 页面背景（浅色模式） |
| Gray 300 | `#D1D5DB` | 分隔线、禁用态 |
| Gray 600 | `#4B5563` | 次级文字 |
| Dark BG | `#111827` | 深色模式背景 |

### 渐变
```
主背景渐变: linear-gradient(180deg, #3B5BDB 0%, #1E2D6B 100%)
卡片渐变 (Focus Mode 主题):
  - Orange-Pink: linear-gradient(135deg, #FB923C, #EC4899, #9333EA)
  - Blue-Teal: linear-gradient(135deg, #3B82F6, #06B6D4)
```

---

## 三、字体系统

### 字体族
- **主字体**：SF Pro（iOS系统字体）
- **数字/强调**：SF Pro Rounded（圆润感）

### 字阶规范
| 级别 | 字号 | 字重 | 行高 | 用途 |
|------|------|------|------|------|
| Display | 48px | Bold (700) | 1.1 | 步数大数字展示 |
| H1 | 34px | Bold (700) | 1.2 | 页面主标题 |
| H2 | 26px | Semibold (600) | 1.3 | 区块标题 |
| H3 | 20px | Semibold (600) | 1.4 | 卡片标题 |
| Body | 16px | Regular (400) | 1.5 | 正文内容 |
| Caption | 14px | Regular (400) | 1.4 | 辅助说明 |
| Label | 12px | Medium (500) | 1.3 | 标签、徽章 |
| Micro | 10px | Regular (400) | 1.2 | 极小标注 |

---

## 四、间距与圆角

### 间距基准（8px grid）
| Token | 值 | 使用场景 |
|-------|----|---------|
| xs | 4px | 图标与文字间距 |
| sm | 8px | 元素内部间距 |
| md | 12px | 小元素间距 |
| lg | 16px | 页面水平边距、卡片内边距 |
| xl | 20px | 区块间距 |
| 2xl | 24px | 大卡片间距 |
| 3xl | 32px | 主要区块分隔 |

### 圆角
| Token | 值 | 用途 |
|-------|----|------|
| sm | 8px | 小标签、徽章 |
| md | 12px | 按钮、输入框 |
| lg | 16px | 小卡片 |
| xl | 20px | 主卡片、弹窗 |
| 2xl | 24px | 大模态框 |
| full | 9999px | 胶囊按钮、头像 |

---

## 五、组件规范

### 5.1 底部导航栏（Tab Bar）

**结构**：4个Tab，图标+文字标签
- **Steps**：足迹图标，当前步骤统计主页
- **Plan**：扬声器/日历图标，活动计划页
- **Profile**：人物/齿轮图标，个人资料页
- 第4个Tab（根据截图可能为 Water 或 Discover）

**视觉规范**：
- 背景：白色/深色系统背景，轻度毛玻璃效果
- 激活状态：图标+文字变为 Primary Blue，带轻量下划线或背景色块
- 非激活：Gray 300 色
- 高度：83px（含Home Indicator区域）
- 图标尺寸：24×24px

---

### 5.2 顶部区域（Header）

**主页Header**：
- 左上：用户头像（40px圆形，蓝色背景+笑脸图标）+ 欢迎语
- 右上：通知铃铛图标
- 背景：延伸至状态栏的蓝色渐变（沉浸式效果）

---

### 5.3 步数展示卡（核心组件）

**大步数展示区**：
```
布局：居中对齐
  - 大数字（Display 48px, Bold, 白色）：当前步数，如 "1,068"
  - 副标题（Caption, 白色70%透明）："steps today"
  - 进度环或进度条：显示目标完成百分比
  - 目标文字：如 "11,000 daily goal"
```

**每日快速统计行**（水平排列4个指标）：
| 指标 | 图标 | 示例值 |
|------|------|--------|
| Steps | 足迹 | 1,068 |
| Distance | 地图pin | 0.41 mi |
| Calories | 火焰 | 48 kcal |
| Speed | 闪电 | 2.4 mph |

每项：图标（16px）+ 数值（H3 Semibold）+ 单位（Caption Gray）

---

### 5.4 周活动柱状图

**规范**：
- 7根柱子，对应周一到周日（Mon-Sun）
- 柱子颜色：蓝色渐变（底部深，顶部亮）；当日高亮为亮蓝/青
- 横轴：日期缩写标签，Caption 12px
- 纵轴：隐藏，通过相对高度表达
- 容器：圆角卡片，白色背景，16px 内边距
- 顶部标题："Your weekly progress" + H3
- 副标题：Caption Gray，"Don't forget to log your activity."

---

### 5.5 天气组件

**圆形仪表盘式设计**：
- 圆形背景：蓝色渐变
- 中心：温度数字（H1 Bold 白色），如 "78.8°F"
- 中心副标题：天气状况，如 "Cloudy"
- 外圈弧形标注：湿度 "82%"
- 右侧信息列：图标+数值（Wind, UV等）

---

### 5.6 活动卡片（Activity Card）

```
┌─────────────────────────────────┐
│ [图标] Steady Running           │
│        3,000 steps · 45min      │
│                   [进度条] 62%  │
└─────────────────────────────────┘
```
- 背景：白色或浅蓝色
- 图标：30×30px，彩色背景圆形
- 标题：Body Semibold
- 副标题：Caption Gray
- 进度条：圆角，Primary Blue填充
- 圆角：16px

---

### 5.7 计划详情（Plan Breakdown）

**周计划卡片**：
- 标题："Week 1 · Intermediate Daily Activity Plan"
- 每日活动行（7行）：
  ```
  [日期] [活动名称]     [距离] [时长]  [步数]
  Mon    Morning Walk    0mi   60min   5,000
  ```
- 分隔线：1px Gray 100

**Diet Tips 区域**：
- 卡路里图标 + "Caloric Intake: Approx. 1600-1800kcal/day"
- 水滴图标 + 饮水建议
- 食物图标 + 食物建议

---

### 5.8 水分摄入组件

**主展示**：
- 中心：3D风格蓝色水瓶插图（约150×200px）
- 大数字："55 oz" （H1 Bold）
- 进度描述："Goal: 50 oz · Completed ✓"

**控制区**：
```
  [−]    [当前数值]    [+]
```
- 减号/加号：白色圆形按钮，48×48px
- 中间：数值文字

**提醒区**：
- Toggle 开关："Reminders · Stay on track with regular sips"
- 时间列表：07:00 AM、10:00 AM（可编辑）
- 间隔设置："1 hour"
- Set as Alarm Toggle

---

### 5.9 个人资料页

**头部区域**：
```
[头像 64px] Alex Smith
            [Edit Profile 按钮]
```

**My Goals 区域**：
- 11,000 Daily Steps
- 55 oz Water Intake
- 每项：左图标 + 标题 + 数值（右对齐）+ 箭头

**促销Banner**：
- 黄色背景（`#FFE500`）
- 插图：人物慢跑
- 文字："exclusive GD widgets"
- 圆角：16px

**设置菜单列表**：
每行规范：
```
[左图标 24px]  [标题 Body]      [右值/箭头 Caption Gray]
```
条目：
- Focus Mode（Toggle）
- My Shoes（当前：New Balance）
- My Bottle（当前：Memobottle）
- Sync Apple Watch
- Subscription
- Settings
- Rate Us
- Contact Us

---

### 5.10 Focus Mode 主题选择器

**布局**：横向滚动卡片列表
每张主题卡片：
- 尺寸：约 160×200px
- 渐变背景（橙粉紫渐变 或 蓝青渐变）
- 顶部：圆形步数环
- 中部：大数字步数
- 底部：小号统计数据
- 选中态：白色边框 2px + 白色勾选徽章

---

### 5.11 鞋子选择器（My Shoes Modal）

**弹窗设计**：
- 顶部：大号鞋子插图（居中，约100px高）
- 标题："GO" + "New Balance"
- 4×5 图标网格（共20种鞋型可选）
- 图标尺寸：约 48×48px
- 选中态：Primary Blue 背景 + 白色勾选

---

### 5.12 订阅/Premium 页面

**定价卡片组**（3个选项，垂直排列）：

```
┌─────────────────────────────────┐
│ ⭐ Most Popular          [徽章] │
│ Yearly    $11.99/year           │
│           Save 40%    ← 推荐   │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ Monthly    $3.99/month          │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ Lifetime   $54.99 one-time      │
└─────────────────────────────────┘
```
- 推荐卡片：Primary Blue 描边 2px + "Most Popular" 徽章（Yellow）
- 普通卡片：Gray 100 背景
- CTA 按钮：全宽，白色背景+蓝色文字 或 蓝色背景+白色文字
- 底部文字：Caption Gray，"Recurring Billing: Cancel anytime"

**Feature Highlights**（横向轮播）：
- 水分追踪功能展示
- Apple Watch 集成
- AI 个性化计划
- 轮播点指示器（3-4个点）

---

### 5.13 按钮系统

| 类型 | 背景 | 文字色 | 高度 | 圆角 | 用途 |
|------|------|--------|------|------|------|
| Primary | White | Primary Blue | 52px | full | 主CTA（蓝色背景页面） |
| Primary Alt | Primary Blue | White | 52px | full | 主CTA（白色背景页面） |
| Secondary | Gray 100 | Gray 600 | 44px | full | 次要操作 |
| Destructive | Red | White | 44px | full | 删除/退出 |
| Ghost | Transparent | White/Blue | 44px | full | 取消/次级 |
| Icon | Circle 40px | — | 40px | full | 图标按钮 |

---

### 5.14 Toggle 开关

- 启用：绿色（`#4ADE80`）滑块
- 禁用：Gray 300 滑块
- 尺寸：51×31px（iOS标准）

---

### 5.15 弹窗（Modal / Sheet）

**底部抽屉式（Bottom Sheet）**：
- 圆角：顶部 24px
- 背景：白色 或 深色（深色模式）
- 顶部拖动条：40×4px，Gray 300，居中
- 遮罩：黑色 40% 透明

**确认对话框（Alert）**：
- 居中小弹窗
- 标题 H3 + 描述 Body
- 底部两个按钮（左取消 Ghost，右确认 Destructive 或 Primary）
- 圆角：20px

---

### 5.16 图表组件

**弧形/仪表盘（Gauge）**：
- 弧形从左下到右下（约270°）
- 渐变：金色 → 蓝色 → 青色
- 中心显示主数值 + 副文字
- 背景弧：Gray 100

**折线图（Line Chart）**：
- 渐变填充区域（蓝色到透明）
- 数据点：白色圆点，Primary Blue 描边
- 坐标轴：Caption Gray，浅色网格线

**数据对比徽章**：
- 绿色上箭头 + 百分比（如 "+587% higher"）
- Caption 12px，绿色文字

---

## 六、页面结构目录

```
App
├── 启动/引导
│   ├── 欢迎页（"Every Step Counts!"）
│   ├── 权限申请（Location Enable）
│   └── 登录（Apple ID / Google）
│
├── 主页 (Steps Tab)
│   ├── 步数大屏展示
│   ├── 4项快速统计
│   ├── 周活动柱状图
│   ├── 天气组件
│   └── 当前活动卡片
│
├── 趋势 (Trending)
│   ├── 时间段选择器（This Week / Last Week / 月份 / 年份）
│   ├── 汇总统计列表（Steps/Distance/Floors/Energy/Speed/Standing）
│   └── 折线/柱状图
│
├── 计划 (Plan Tab)
│   ├── AI 生成加载页（"Hold on while we build..."）
│   ├── 周计划详情（7天活动列表）
│   ├── Diet Tips 区块
│   ├── Upcoming Activity 区块
│   └── Activity History（可折叠）
│
├── 水分 (Water Tab)
│   ├── 水瓶主展示
│   ├── ±控制
│   └── 提醒设置
│
├── 个人资料 (Profile Tab)
│   ├── 头像 + 姓名
│   ├── My Goals
│   ├── Plan with AI 入口
│   ├── 小组件促销 Banner
│   ├── 偏好设置列表
│   └── More Apps / Logout
│
├── 设置
│   ├── 主题选择（System/Dark/Light）
│   ├── 单位系统（Imperial/Metric）
│   ├── 显示名称编辑
│   ├── App 图标选择
│   └── 账号管理（Delete Account）
│
├── Focus Mode
│   ├── Toggle 开关
│   └── 主题卡片横向列表
│
├── My Shoes
│   └── 20种鞋型网格选择
│
└── 订阅/Premium
    ├── Feature 轮播
    ├── 定价卡片（月/年/终身）
    ├── Family 分享选项
    └── 管理订阅
```

---

## 七、交互与动效规范

| 场景 | 动效类型 | 参数 |
|------|---------|------|
| 页面切换（Tab） | 淡入淡出 | 200ms ease |
| 底部抽屉弹出 | Spring 弹出 | damping: 0.8, stiffness: 300 |
| 按钮点击 | Scale 0.96 | 100ms |
| 加载步数 | 数字滚动动画 | 600ms ease-out |
| 进度条填充 | 宽度动画 | 800ms ease-in-out |
| 图表绘制 | 从左到右逐渐显示 | 1000ms ease |
| 成功状态 | 粒子/星光散开动画（蓝色点） | 500ms burst |
| Onboarding 轮播 | 水平滑动 + 点指示器 | spring |

---

## 八、深色模式规范

| 元素 | 浅色 | 深色 |
|------|------|------|
| 主背景 | `#F3F4F6` | `#111827` |
| 卡片背景 | `#FFFFFF` | `#1F2937` |
| 主文字 | `#111827` | `#F9FAFB` |
| 次级文字 | `#6B7280` | `#9CA3AF` |
| 分隔线 | `#E5E7EB` | `#374151` |
| 蓝色主背景页 | 不变（始终深蓝） | 不变 |

---

## 九、空状态与加载态

**AI 计划生成中**：
- 全屏蓝色背景
- 居中动画图标（波浪/脉冲）
- 文字："Hold on while we build your custom plan for this week with GO AI."
- 进度条：从左到右填充

**无数据**：
- 柱状图显示空柱子（Gray 100 填充）
- 提示文字：Caption Gray，居中

---

## 十、关键品牌文案

```
主Slogan:    "Every Step Counts!"
副Slogan:    "Let's move smarter, faster, and together toward your goals"
AI计划:      "Hold on while we build your custom plan with GO AI."
步数激励:    "You're taking fewer steps than you usually do by now."
周进度:      "Your weekly progress. Don't forget to log your activity."
饮水激励:    "Easily track your daily water intake..."
品牌署名:    "Built for all, Made in India"
订阅说明:    "Recurring Billing: Cancel anytime"
健康声明:    "Apple Health" integration disclaimer
```

---

## 十一、图标规范

- 风格：SF Symbols（iOS原生）+ 少量自定义图标
- 尺寸：20px（列表）、24px（Tab Bar）、28-30px（卡片）
- 颜色：配合内容语境，彩色或单色

**常用图标列表**：
- 足迹（步数）
- 地图pin（距离）
- 火焰（卡路里）
- 闪电（速度）
- 楼梯（楼层）
- 水滴（饮水）
- 鞋子（My Shoes）
- 水瓶（My Bottle）
- 苹果手表（Watch Sync）
- 人物（Profile）
- 齿轮（Settings）
- 星形（Premium/Rating）
- 火箭（Premium Upgrade）

---

*本文档基于GO Club iOS App 2025年11月截图集（106张）整理，覆盖全部核心页面和组件。*
