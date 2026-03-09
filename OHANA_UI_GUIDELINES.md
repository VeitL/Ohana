# Ohana UI Guidelines

This document tracks the permanent UI guidelines for the Ohana app. **ALL new UI development and refactoring MUST follow these guidelines.**

## Core Principles
1. **Adaptive & Modern:** The app must look excellent in both Light and Dark modes.
2. **Dynamic Layouts:** Avoid endless lists of identical horizontal cards. Use Bento Box styling to break up monotony and create visual hierarchy.
3. **Consistent Vocabulary:** All components should be named with the `Ohana` prefix in `OhanaDesignSystem.swift` to distinguish them from standard or deprecated elements.

---

## 1. Card Styles (The "Standard Card")
The foundation of the app is the unified container for content. 
There is only **one** standard card style for each mode.

- **Dark Mode:** `goTranslucentCard` (Deep blue/navy gradient with frosted glass border and subtle drop shadow).
- **Light Mode:** `neoWhiteCard` (Pure white background with soft, broad drop-shadow).

**Implementation:**
Use the `.ohanaStandardCard(dark: Bool)` modifier or `OhanaStandardCard` wrapper.

---

## 2. Layouts: Bento Box
To organize content (especially on Overview or Dashboard pages), avoid stacking horizontal rows. Instead, use a mix of large and small square/rectangular cards.
- **Hero elements:** Take up full width or 2/3 width.
- **Secondary metrics:** Use square tiles in a grid or stack layout next to the hero element.
- **Floating Groups (Settings):** For list-heavy pages like Settings, group items into a single `.ohanaStandardCard` and use single-pixel dashed or ultra-light solid dividers (`GoDashedDivider` / `OhanaDashedDivider`) between items, instead of wrapping every row in its own card.

---

## 3. Buttons
### Icon Buttons
We use **Style B (Subtle Gradient)** for small, standalone icon buttons (like Quick Actions or floating menu buttons).
- **Style B:** Subtle gradient background (e.g., color at 20% to 5% opacity) + colored icon. NO border.

### Primary Buttons
- **Gradient Capsule:** `LinearGradient` (goLime to #A8E44A), rounded corners, dark ink text, bold, with a drop shadow matching the tint color.

---

## 4. Alert Banners (Toast Style)
Use **Style D (Solid Capsule)** for non-intrusive feedback, warnings, and system notices.
- **Style D:** Solid color background capsule (e.g., solid `goLime` for success, `goRed` for errors), with contrasting icon and text. Highly compact, toast-like appearance.
- **Implementation:** Use `OhanaAlertBanner(style: .success, message: "...")`.

---

## 5. Tags and Chips
Use **Style C (Dot + Weighted Background)** for categorizing items, status indicators, or filters.
- **Style C:** A small solid circle (dot) on the left, followed by bold text.
- **Selected State:** Solid background slightly tinted with the theme color or white/black.
- **Implementation:** Use `OhanaChip(label: color: selected:)`.

---

## 6. Quick Access (QA) Cards
Use the **Glass / Modern Metric** style for top-level metrics or quick access shortcuts.
- **Properties:** Large icon at the top left, followed by a bold value/metric, and a small title below it.
- **Size:** Smaller and tighter than standard cards to allow scrolling or grid arrangement.

---

## 7. Typography (OhanaFont)
Always use the `OhanaFont` struct (SF Pro Rounded). Never use raw `.font(.system(...))` unless building a specific one-off layout.
- `largeTitle` (34pt Black)
- `title`, `title2`, `title3`
- `headline`, `body`, `callout`
- `footnote`, `caption`, `caption2`
- `metric` (Variable size, Black weight, typically used for QA values or big stats).

---

## 8. Colors
Refer to `ColorExtensions.swift`.
- **Primary / Theme:** `goLime`, `goYellow`, `goOrange`, `goRed`, `goTeal`, `goMint`, `goPrimary`.
- **Backgrounds:** `ArkBackgroundView` for root views. `F4F5F9` for light mode standard background.
- **Text:** 
  - `textPrimary`: White (Dark) / ArkInk (Light)
  - `textSecondary`: White 50% / ArkInk 50%
  - `textTertiary`: White 30% / ArkInk 30%

## Process for Refactoring Existing Views
1. Remove nested `NavigationStack`s if they exist inside subviews.
2. Replace scattered `.background` and `.shadow` logic with `.ohanaStandardCard()`.
3. Consolidate list rows into a single card (Floating Group) or reorganize into a Bento Box.
4. Replace ad-hoc buttons with `OhanaIconButton`.
