# Ohana Duotone Solid Icon Set

这套图标延续选中的第三行方向：双色实心几何 glyph。每个图标都是透明背景 SVG，由一个主形体加少量强调色几何元素组成，适合 24pt、28pt、32pt 的应用内入口、快捷操作和卡片状态。

## 内容

- `feed`: 喂食 / Feeding
- `calendar`: 日历 / Calendar
- `walk`: 遛狗 / Dog walking
- `water`: 饮水 / Water
- `potty`: 如厕 / Potty cleanup
- `medicine`: 用药 / Medicine
- `groom`: 洗护 / Grooming
- `health`: 健康记录 / Health record
- `sleep`: 休息 / Sleep
- `vet`: 疫苗/就诊 / Vaccination and vet visit
- `weight`: 体重 / Weight
- `reminder`: 提醒 / Reminder
- `plant-water`: 植物浇水 / Plant watering
- `play`: 玩耍 / Play
- `bath`: 洗澡 / Bath
- `task`: 任务 / Task
- `food-stock`: 食物库存 / Food stock
- `dry-food`: 干粮 / Dry food
- `wet-food`: 湿粮 / Wet food
- `treat`: 零食 / Treat
- `food-bag`: 粮袋 / Food bag
- `feeder`: 自动喂食器 / Auto feeder
- `water-change`: 换水 / Water change
- `filter-change`: 换滤芯 / Filter change
- `litter`: 猫砂 / Litter
- `cleanup`: 清洁 / Cleanup
- `walk-map`: 散步地图 / Walk map
- `distance`: 距离 / Distance
- `training`: 训练 / Training
- `mood`: 心情 / Mood
- `check-in`: 打卡 / Check-in
- `family`: 家庭 / Family
- `profile`: 档案 / Profile
- `privacy`: 隐私 / Privacy
- `expense`: 花费 / Expense
- `insurance`: 保险 / Insurance
- `document`: 文档 / Document
- `photo`: 照片 / Photo
- `birthday`: 生日 / Birthday
- `reward`: 奖励 / Reward
- `temperature`: 温湿度 / Temperature
- `plant-fertilize`: 植物施肥 / Plant fertilize
- `notification-health`: 提醒健康 / Notification health
- `settings`: 设置 / Settings

## 调色

每个 SVG 都使用两个 CSS 变量：

```css
--ohana-icon-primary: #ffffff;
--ohana-icon-accent: var(--member-theme-color);
```

在网页或设计稿里使用 inline SVG 时，可以在父容器或 svg 根节点覆盖这两个变量。App 不导入静态 SVG，而是使用同源 SwiftUI 矢量几何，因此宠物、人类和植物卡片都能在运行时注入各自主题色。

## 文件

- `v2-review.html`: 简化版备选评审页，支持 24/28/32pt、浅色/深色和未打卡/进行中/已完成状态预览；不作为当前 App 图标基准。
- `icons/*.svg`: 单个透明 SVG 图标，使用静态颜色，适合直接预览和导入设计工具/Xcode。
- `icons-variable/*.svg`: 使用 CSS 变量的版本，适合 inline SVG 调色。
- `preview.svg`: 默认配色总览图。
- `preview.html`: 当前 App 快捷操作图标基准；主体固定白色，强调色使用宠物/人类成员主题色，44 枚图标均可点击播放一次语义动效。
- `generate-icons.mjs`: 生成脚本，便于后续批量增删图标或调整几何。

## App 接入

- `OhanaQuickActionIcon` 负责未打卡、打卡中、已打卡和 Reduce Motion 行为。
- `OverviewQuickActionIconGeometry.swift` 持有网页基线 44 枚及 11 枚生产扩展的 32pt SwiftUI 矢量几何，并把主体层与强调层分开渲染。
- 生产扩展覆盖 App 中实际存在但不属于网页基线的操作：全部功能、自由飞行、喷雾、换垫材、运动、植物修剪、查虫、转盆、换盆、新叶和植物异常。
- 主体层保持静止；点击或打卡状态改变时只播放强调层的一次性语义动效。未打卡强调层透明度为 16%，打卡中和已打卡为完整主题色；已打卡同时显示对勾，不依赖颜色单独表达状态。
- Reduce Motion 或 `AppWorkloadPolicy` 降低交互动效预算时，组件停止位移动画，只保留状态颜色和文字/对勾反馈。
