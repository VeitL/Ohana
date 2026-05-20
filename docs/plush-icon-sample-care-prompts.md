# Ohana Plush Icon Sample Prompts

本文件定义 Ohana 照护快捷三件套毛绒 icon 样张：Feed / Water / Walk。生成目标是透明背景、3D 毛绒玩具质感、可用于 SwiftUI 快捷操作卡片与功能入口。

## Unified Style Prompt

Use this style prefix for every icon:

```text
A premium 3D plush toy app icon, soft fuzzy fabric, rounded cute proportions, subtle stitched seams, gentle studio lighting, toy photography, high quality product render, centered object, transparent background, soft contact shadow, warm family pet-care feeling, tactile textile details, slightly oversized cute shape, no text, no letters, no watermark, no hard plastic, no metal sharpness, no realistic animal body, no human character, no UI mockup, isolated icon asset, 1024x1024
```

## Unified Negative Prompt

```text
text, letters, numbers, watermark, logo, flat vector, emoji, low resolution, blurry, realistic animal, human figure, scary, dirty, medical gore, sharp needle, hard metal, glossy chrome, cluttered background, full scene, screenshot, phone UI, app screen, photorealistic food mess, poop realism, extra objects, cropped object, off-center, harsh shadow
```

## 1. Feed / 喂食

### Prompt

```text
A premium 3D plush toy app icon, soft fuzzy fabric, rounded cute proportions, subtle stitched seams, gentle studio lighting, toy photography, high quality product render, centered object, transparent background, soft contact shadow, warm family pet-care feeling, tactile textile details, slightly oversized cute shape, no text, no letters, no watermark, no hard plastic, no metal sharpness, no realistic animal body, no human character, no UI mockup, isolated icon asset, 1024x1024.

Main subject: a soft plush pet food bowl with tiny rounded animal ears on the rim, filled with several cute fuzzy kibble pellets. The bowl is warm cream fabric with a soft coral-orange inner lining, a small stitched paw patch on the front, rounded puffy edges, visible short fur fibers, gentle seams. Make it immediately readable as pet feeding, friendly and clean, not messy. Three-quarter front view, icon-safe silhouette, strong single-object readability.
```

### Notes

- 主体：毛绒饭碗。
- 辅助元素：软粒粮、碗前小爪印。
- 主色建议：cream / coral orange / warm tan。
- 文件名：`plush_icon_feed_sample.png`。

## 2. Water / 喂水

### Prompt

```text
A premium 3D plush toy app icon, soft fuzzy fabric, rounded cute proportions, subtle stitched seams, gentle studio lighting, toy photography, high quality product render, centered object, transparent background, soft contact shadow, warm family pet-care feeling, tactile textile details, slightly oversized cute shape, no text, no letters, no watermark, no hard plastic, no metal sharpness, no realistic animal body, no human character, no UI mockup, isolated icon asset, 1024x1024.

Main subject: a soft plush pet water bowl with rounded puffy rim, a large translucent soft-gel water droplet floating above it, and a small stitched paw patch on the bowl. The bowl is pale sky-blue plush fabric with cream highlights, the water droplet is soft semi-transparent aqua gel with cute rounded highlights, no hard glass. Clean, refreshing, gentle, immediately readable as pet water. Three-quarter front view, centered, icon-safe silhouette, minimal object count.
```

### Notes

- 主体：毛绒水碗 + 透明软胶水滴。
- 辅助元素：碗前小爪印。
- 主色建议：pale blue / aqua / cream。
- 文件名：`plush_icon_water_sample.png`。

## 3. Walk / 遛狗

### Prompt

```text
A premium 3D plush toy app icon, soft fuzzy fabric, rounded cute proportions, subtle stitched seams, gentle studio lighting, toy photography, high quality product render, centered object, transparent background, soft contact shadow, warm family pet-care feeling, tactile textile details, slightly oversized cute shape, no text, no letters, no watermark, no hard plastic, no metal sharpness, no realistic animal body, no human character, no UI mockup, isolated icon asset, 1024x1024.

Main subject: a soft plush dog leash loop shaped like a gentle heart or rounded loop, with a small puffy handle and two cute plush paw prints beside it. The leash is warm lime-green and cream fabric rope with visible fuzzy fibers and stitched details, the clasp is a soft rounded fabric buckle instead of metal. Energetic outdoor companionship feeling, playful but clean, immediately readable as dog walking. Three-quarter front view, centered, icon-safe silhouette, no full dog character.
```

### Notes

- 主体：毛绒牵引绳。
- 辅助元素：两个软绒爪印。
- 主色建议：soft lime / cream / warm tan。
- 文件名：`plush_icon_walk_sample.png`。

## Preview Layout Prompt

If generating one comparison sheet:

```text
Create a clean comparison sheet with three separate premium 3D plush toy app icons on transparent or very light neutral background: Feed, Water, Walk. Keep all three icons same scale, same camera angle, same lighting, same soft fuzzy fabric material, centered in three equal columns, no labels, no text, no watermark. Feed is plush food bowl with fuzzy kibble, Water is plush water bowl with soft aqua droplet, Walk is plush dog leash loop with paw prints. 3D toy photography, rounded cute proportions, icon asset style, high quality render.
```

## Import Guidelines

- 生成后优先保留透明背景 PNG。
- 建议先导出 `1024x1024`，再由 Xcode asset catalog 或设计工具生成 `1x/2x/3x`。
- 统一资产命名：
  - `plush_icon_feed_sample`
  - `plush_icon_water_sample`
  - `plush_icon_walk_sample`
- 若用于正式资源，建议放入 `Ohana/Assets.xcassets/PlushIcons/` 下对应 imageset。
