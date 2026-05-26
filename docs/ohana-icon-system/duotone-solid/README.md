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
--ohana-icon-primary: #1f8a8a;
--ohana-icon-accent: #ff755f;
```

在网页或设计稿里使用 inline SVG 时，可以在父容器或 svg 根节点覆盖这两个变量。直接作为 iOS Asset 使用时，Xcode 会把 SVG 当作静态矢量资源；如果要在 SwiftUI 运行时动态换色，建议下一步把选定图标转换成 SwiftUI Shape 或模板化矢量组件。

## 文件

- `icons/*.svg`: 单个透明 SVG 图标，使用静态颜色，适合直接预览和导入设计工具/Xcode。
- `icons-variable/*.svg`: 使用 CSS 变量的版本，适合 inline SVG 调色。
- `preview.svg`: 默认配色总览图。
- `preview.html`: 可交互调色预览。
- `generate-icons.mjs`: 生成脚本，便于后续批量增删图标或调整几何。
