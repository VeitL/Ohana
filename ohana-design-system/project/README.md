# Ohana Design System

> iOS family life-tracker for pets (🐕), humans (🧑), and plants (🌱) — collectively called **Critters**. Gamified with a coconut 🥥 reward economy, streak bonds, and a "Life Tree" that grows with the family's activity.

Ohana (欧哈纳, "family" in Hawaiian) is a **SwiftUI + SwiftData** iOS app. The design language is called **Go UI** — a dark, glassy, gamey layout built on iOS 26 Liquid Glass (`.glassEffect`), with a single punchy accent color (`#FF7600` orange in light mode, `#C8FF00` lime in dark mode) set against a deep navy gradient background with floating blurred blobs.

This design system is a **portable extract** of Ohana's visual identity — tokens, type, components, and UI-kit screens — so any designer or agent can produce on-brand artifacts (slides, landing pages, mock screens, prototypes) without booting the Xcode project.

---

## Sources

Everything in this system was extracted from the `Ohana/` codebase mounted locally.

| Source | Path |
|---|---|
| Root reference doc | `Ohana/OHANA_COMPLETE_REFERENCE.md` (1776 lines, v8.0.0) |
| AI navigation file | `Ohana/CONTEXT.md` (ArkSchemaV19, Phase 1–76) |
| UI rules (authoritative) | `Ohana/UIRules.md` (415 lines, iOS 26 Liquid Glass) |
| GO Club visual reference | `Ohana/GO_Club_UI_Design_Reference.md` (the "Go UI" style guide — blue + lime + glass cards) |
| Design system source | `Ohana/Ohana/Views/OhanaDesignSystem.swift` (fonts, modifiers, components) |
| Color tokens | `Ohana/Ohana/Utilities/ColorExtensions.swift` |
| Background engine | `Ohana/Ohana/Views/ArkBackgroundView.swift` (9 variants) |
| Home / dashboard | `Ohana/Ohana/Views/GoDashboardView.swift` (1638 lines) |
| iOS app target | `Ohana/Ohana/` (Swift 6, iOS 17+, SwiftData, Swift Charts) |

No Figma was provided. No marketing website exists. The **only** product is the iOS app.

---

## The product

**Platform:** iOS 17+, Swift 6, SwiftUI + SwiftData + Swift Charts
**Primary market:** Chinese-speaking pet owners (most copy is Simplified Chinese; app has an `en.lproj` too)
**Original name:** Ark → rebranded to Ohana. Some code identifiers still carry `Ark` prefix (`ArkSchemaV19`, `ArkBackgroundView`, `arkInk`).

### Core concepts

- **Critters** — a unified term for the three entities Ohana tracks: **Pet** (dog/cat/rabbit/hamster/bird/fish/reptile), **Human** (family members), and **Plant**.
- **Household / Island (岛屿)** — the family unit. Has a `totalProsperity` EXP score.
- **Coconut 🥥 economy** — every check-in, walk, feed, or care action awards coconuts via `QuestManager.awardAction(...)`. Coconuts are the single in-app currency. Used in the **Shop**, **Gacha**, and to **inject energy into the Life Tree**.
- **Life Tree / Oasis (生命之树)** — a 10-level tree that grows with household activity. Level 5+ yields daily passive coconut income. Visual metaphor: a coconut palm on an island.
- **Streak (羁绊值)** — consecutive-day check-ins per pet. 7/30/100/365-day milestones trigger rewards via `StreakRewardManager`.
- **Quick Access** — per-species configurable check-in buttons on the pet detail screen (walk, feed, water, potty, care, play, health, expense, weight…).
- **Wallet cards** — a stack of Apple-Wallet-style cards on the home screen, one per critter, that flip to reveal stats (`CritterDeckCarousel`).

### Key managers (single source of truth for business logic)

| Manager | Role |
|---|---|
| `QuestManager` | Coconut rewards, cooldowns, crits, double-token |
| `OasisTreeManager` | Life Tree level, energy, passive income |
| `StreakManager` / `StreakRewardManager` | Daily streak + milestone rewards |
| `PetWalkingManager` | Full walking flow, GPS, map snapshots |
| `AchievementManager` | 10+ achievement unlocks |
| `PetHealthAlertEngine` | Vaccine / weight / document expiry scans |

---

## CONTENT FUNDAMENTALS

### Voice & tone

Ohana's voice is **warm, caring, slightly playful, and gamified**. It treats caretaking as a loving ritual, not a chore, and leans into the "island" / "family" fantasy. Copy is bilingual (zh-CN primary, en as reference).

- **Person:** Second-person imperative or first-person-plural ("你家宝贝 / 我们的岛"). Rarely third-person.
- **Casing (English):** Title Case for buttons and nav labels ("Add Pet", "My Shoes"). Sentence case for body.
- **Casing (Chinese):** No case concept — but headers are kept short (2–6 characters) and punchy: "首页", "日历", "椰子商店", "扭蛋机", "家庭悬赏榜".
- **Action verbs:** Short, vivid, verb-first: "打卡", "遛狗", "喂食", "铲屎", "补签", "注入能量", "升级", "合成".
- **Numbers:** Always prominent. Big rounded metric fonts for coconut counts, streak days, steps.

### Gamified vocabulary

The app freely borrows from games/RPGs. **Do not sanitize this** — it's the voice.

- 🥥 **Coconut** (椰子) — currency
- 🥥🥥 **Double token** (双倍券) — coconut multiplier
- 🛡️ **Streak shield** (连胜保护盾) — freeze shield
- 🌴 **Life Tree** (生命之树) — progression system
- 🏝️ **Island / Oasis** (岛屿 / 绿洲) — household
- 💥 **Crit** (暴击) — 2× or 5× coconut roll (1–89: ×1, 90–98: ×2, 99–100: ×5)
- 🎰 **Gacha** (扭蛋机) — 30🥥 per pull
- 🏆 **Bounty board** (悬赏榜) — family chore assignments
- 🌈 **Rainbow Bridge** (彩虹桥) — deceased pet memorial
- 🥇 **Bond value** (羁绊值) — streak count

### Emoji usage — **yes, heavily**

Unlike most design systems that avoid emoji, Ohana uses them **as first-class UI**:

- **Pet species indicators:** 🐕 🐈 🐇 🐹 🐦 🐠 🦎
- **Action identifiers:** 🍽️ feeding, 💧 water, 🧹 litter, 🔄 water change, 🥥 reward, 🎉 crit, 👑 mega-crit
- **Avatars:** `Pet.avatarEmoji` and `Human.avatarEmoji` are explicit model fields — users pick an emoji if they haven't uploaded a photo.
- **Mood/Weather (Island Mood):** 😊 🌤️ ⛈️ indicate the household's collective health state.

**But:** inside functional UI (tab bar icons, list icons, chart markers), the rule is **SF Symbols only**. Emoji is reserved for:
1. Currency/reward animations
2. Species/avatar placeholders
3. Milestone celebrations
4. Quick-action button icons on the pet card

### Copy samples

From the codebase:

| Context | Copy |
|---|---|
| Slogan (GO Club ref) | "Every Step Counts!" / "Let's move smarter, faster, together." |
| Home header greeting | "早上好, [Human Name]" / "Good morning" |
| Coconut gain toast | "+5 🥥" / "暴击! +10 🥥 🎉" |
| Empty state | "还没有记录" + SF Symbol in tinted circle |
| Confirm-CTA button | "确认" / "保存" / "继续" |
| Streak celebration | "连续打卡 X 天! 🔥" |
| Walk end | "今日已走 X 米 · +Y🥥" |
| Tree level-up | "生命之树升到 Lv.X!" |

---

## VISUAL FOUNDATIONS

### Color vibe

- **Deep navy + lime** is the signature. Backgrounds are **dark navy gradients with floating blurred blobs** (indigo, blue, purple). Accents are **punchy lime or orange** — never pastel.
- Cards are **mostly translucent** (`.glassEffect(.regular, in: RoundedRectangle(24))`) with a white-ish tint floating over the dark blob-gradient background.
- In **light mode**, the accent flips to warm orange (`#FF7600`), backgrounds become soft off-white/lavender.
- Light + dark are **both first-class** — no "light is the default" assumption.

### Typography

- **System font, rounded design** (`.system(design: .rounded)`) — every text style in the app uses SF Pro Rounded. This is the single most important type decision. Nothing is serif. Nothing is monospace except numeric metrics (and even those stay rounded).
- **Hierarchy is driven by weight + size, not family.** Metric numbers go up to 80px Heavy; body stays 15px Medium; captions 11–12px.
- **`OhanaFont` enum is the canonical API** — `OhanaFont.largeTitle()`, `.title2(.bold)`, `.metric(size: 60, .heavy)`, etc.

### Spacing & layout

- **8pt grid.** Tokens: `xs 4 / sm 8 / md 12 / lg 16 / xl 20 / 2xl 24 / 3xl 32`.
- **Page horizontal padding: 24pt**. Cards internal: 16pt. Bento cells: 14pt. Between-card: 20pt.
- Layout is **vertical scroll stack**, often with a **hero** block at top (wallet card / big metric / weather dial), a **bento grid** of stats below, then sectioned modules (activity, plan, health alerts).

### Backgrounds

**9 background variants** are shipped (`ArkBackgroundView`). All share a common recipe:
1. Solid base color
2. 2–4 large `Circle()`s filled with accent colors, each with `.blur(radius: 60–120)` and slow infinite `.easeInOut.repeatForever` offset animations — "floating blobs"
3. A very-faint `NoiseTextureView` Canvas layer at ~0.02 opacity, `.blendMode(.overlay)` — adds film grain

Named variants: `goDefault`, `goIsland` (deep blue gradient), `deepAmbient`, `aurora`, `midnight`, `sunsetGlow`, `sakuraMist`, `forestGlade`, `paperCream`, `neonGrid`. **Default is `goDefault` (dark navy blob).**

### Borders & strokes

- Almost no hard borders. Glass cards have a **1px inner stroke of `.white.opacity(0.15–0.55)`** to catch light.
- Divider lines are **`.white.opacity(0.1)` × 1px**, or a **dashed divider** (`[4, 4]` or `[6, 4]` dash) at white 20–25% for decorative breaks.

### Shadows

- Glass cards: `shadow(color: .black.opacity(0.05), radius: 12, y: 4)`
- White cards: `shadow(color: .black.opacity(0.08), radius: 16, y: 4)`
- Dark cards: `shadow(color: .black.opacity(0.15), radius: 12, y: 4)`
- Neon CTA: `shadow(color: Color(hex: "E0FF00").opacity(0.3), radius: 12, y: 4)` — a **colored glow** under the primary lime button.
- **No heavy/dramatic drop shadows.** The glow-under-neon pattern is the only shadow that's decorative.

### Corner radii

| Element | Radius |
|---|---|
| Main cards / modals | **24pt** |
| Dock / floating bars | **22pt** |
| Small cards | 20pt |
| Bento cells | 14pt |
| Buttons / inputs | 12pt |
| Small pills / badges | Capsule (full) |
| Big CTAs | Capsule |

### Animation

- **Springs everywhere.** `spring(response: 0.3–0.4, dampingFraction: 0.82)` for taps. `spring(response: 0.45, dampingFraction: 0.55)` for reward bounces.
- **Infinite `easeInOut.repeatForever(autoreverses: true)`** on background blobs (8–18s cycles).
- **Coconut reward overlay** bounces from 20% scale to 100%, holds ~1.4s, flies up and out over 0.4s.
- **Numeric transitions** use `.contentTransition(.numericText())` for coconut balance updates.
- **Stagger entries** with `.delay(index * 0.05)` for list items.

### Hover / press states

- **Press:** `scaleEffect(0.96)` with `100ms` linear, backed by `UIImpactFeedbackGenerator(.soft)` haptic.
- **Buttons style:** `.buttonStyle(.plain)` is default; CTAs wrap in explicit scale/opacity animation.
- **Tap glow on primary:** colored shadow stays; no hover (touch OS).

### Transparency & blur

- **Heavy use of blur.** `.glassEffect(.regular, in: <shape>)` is the default card style. `.ultraThinMaterial` for sheets.
- **Accessibility:** code explicitly checks `@Environment(\.accessibilityReduceTransparency)` and falls back to `.systemBackground @ 95% opacity`.
- Pet background images (when the wallet card has a photo) are **gaussian-blurred** and tinted behind the transparent card content — the photo becomes wallpaper.

### Imagery

- Two built-in breed photo placeholders ship in the asset catalog: **Golden Retriever** (dog) and **Devon Rex** (cat) — warm, natural, shallow-depth-of-field, golden-hour. These define the **photography vibe: warm, low-contrast, blurred background, affectionate close-up portraits**. Never cold, never clinical.
- Photos are **nearly always treated** — either masked into a card, gaussian-blurred as wallpaper, or passed through Vision's cutout service (`ImageCutoutService`) to remove the background for a "broken-frame" floating-pet effect.

### Layout rules

- **Page scroll direction: vertical.** Horizontal scroll only for chip rows (species, date-range), theme-pickers, and moment carousels.
- **Bottom Dock (Tab Bar):** floating glass capsule, 4 tabs, label-on-active pattern. Lives on top of scroll content, not pinned outside.
- **Global floating elements:** Coconut balance capsule (top-right toolbar), Walk-in-progress pill (snaps to edges, draggable), reward overlay (center).

### Cards — the anatomy

A standard Ohana card is:
1. **Glass fill** — `.ultraThinMaterial` layer
2. **Subtle white-gradient tint** on top (20% → 4% → 10% diagonal)
3. **1px `.white.opacity(0.55)` inner stroke**
4. **24pt corner radius**
5. **Soft black-5% shadow at y=4**
6. **16pt internal padding**

This is the single most reused visual primitive — `UltimateGlassCard` in code.

---

## Fonts

**No custom webfonts ship.** Ohana uses **SF Pro Rounded**, which is the iOS system font with `.design: .rounded` applied. For web/cross-platform output we substitute **Nunito** (Google Fonts, closest rounded-sans match) for headings/metrics and **Inter** for body at smaller sizes.

⚠️ **Font substitution flagged to user:** This design system uses Nunito + Inter as stand-ins for SF Pro Rounded. If you need the real type on a non-Apple surface, either embed a fallback stack or ship the design exclusively on iOS. See `fonts/` for the Google-Fonts-hosted mirrors.

---

## Iconography

Described in full in the **ICONOGRAPHY** section below — in short: **SF Symbols for functional icons, emoji for rewards/identity, no custom icon font.**

See `ICONOGRAPHY.md` section within this file (below) for specifics.

---

## ICONOGRAPHY

### The rule

**Functional icons → SF Symbols. Identity/reward → emoji. Decorative → neither (use typography or photography).**

### SF Symbols (primary)

The entire app uses Apple's SF Symbols library via `Image(systemName: "...")`. No custom icon font, no custom SVG sprite, no icon package.

Common symbols observed in the codebase:

| Category | Symbols |
|---|---|
| Nav / Tab | `house.fill`, `calendar`, `person.crop.circle`, `heart.fill`, `gearshape.fill` |
| Actions | `plus`, `xmark`, `checkmark`, `chevron.right`, `arrow.up`, `trash` |
| Status | `checkmark.circle.fill`, `exclamationmark.triangle.fill`, `xmark.circle.fill`, `info.circle.fill` |
| Pet care | `pawprint.fill`, `figure.walk`, `drop.fill`, `fork.knife`, `heart.text.square` |
| Health | `cross.case.fill`, `pills.fill`, `stethoscope`, `thermometer`, `bandage.fill` |
| Finance | `creditcard.fill`, `wallet.pass.fill`, `dollarsign.circle.fill` |
| Growth | `leaf.fill`, `flame.fill` (streak), `star.fill`, `bolt.fill` |

**Usage for web:** Since SF Symbols aren't licensed for non-Apple platforms, this design system substitutes **Lucide Icons** (CDN: `https://unpkg.com/lucide@latest`) — closest stroke weight and visual style match. Used in the `ui_kits/` previews. Lucide ≠ SF Symbols 1:1 but maps cleanly for most icons.

⚠️ **Flagged substitution:** Lucide stands in for SF Symbols on non-iOS surfaces. Stroke-weight match is close but ligatures and filled variants differ. Document any substitution in slide/mock captions.

### Emoji (identity + rewards)

Emoji appear in **three strict contexts only**:

1. **Avatars** — `Pet.avatarEmoji`, `Human.avatarEmoji` (🐕 🐈 🧑 🌿 etc.)
2. **Currency & rewards** — 🥥 (always), 🎉 (crit), 👑 (mega-crit), 🔥 (streak), 🎁 (gift)
3. **Action identity on Quick Access buttons** — 🍽️ feed, 💧 water, 🧹 litter, 🔄 water change, 🛁 bath, 🧠 training, 🩺 health

### Unicode symbols

Occasionally used for dense metrics: `♂` `♀` `⚧` (gender), `·` middle dot separator, `✓`/`✗` in list checkmarks when SF Symbols feels heavy.

### Logo / brand mark

No wordmark file was provided. The app icon is referenced in `Assets.xcassets/AppIcon.appiconset/` but its actual PNG source wasn't accessible. This design system ships **a reconstructed wordmark** (`assets/ohana_wordmark.svg`) using the brand's type/color rules — rounded sans, lime-on-navy. Flagged for user review.

---

## Index / Manifest

Root of the design system:

| File | Purpose |
|---|---|
| `README.md` | This file — brand overview, content, visuals, iconography |
| `SKILL.md` | Cross-compatible Agent Skill descriptor |
| `colors_and_type.css` | CSS variables: color palette + semantic tokens + type scale + utility classes |
| `tokens.json` | Same tokens as JSON (for design tooling) |

Folders:

| Folder | Contents |
|---|---|
| `assets/` | Logos, wordmarks, brand imagery, breed photo placeholders |
| `fonts/` | Google-fonts mirrors for Nunito + Inter (SF Pro Rounded substitution) |
| `preview/` | Small HTML cards registered to the Design System tab |
| `ui_kits/ohana_ios/` | Hi-fi React recreation of the iOS app's core screens |

Available UI kits:

- **`ui_kits/ohana_ios/`** — iOS pet/family tracker. Home dashboard, pet detail with quick-access, coconut shop, life tree / oasis, onboarding.

No slide template was provided → no `slides/` folder is shipped.

---

## Caveats

- **No Figma** was attached — all tokens are extracted from the Swift codebase only.
- **No logo PNG source** was accessible — a reconstructed wordmark is provided and flagged for review.
- **SF Pro Rounded** is not available outside Apple platforms → Nunito + Inter are used as a fallback on web.
- **SF Symbols** are Apple-licensed → Lucide is used as a fallback on web.
- **GO Club** screenshots (a separate reference app, 106 images) exist in the source folder but our tooling couldn't access them through their filename-with-spaces path. The visual guidance in `GO_Club_UI_Design_Reference.md` (which we could read) drives the color/layout/type decisions.
- The app is **primarily Chinese-language**. English copy in this system is translated/paraphrased for Western designers; keep original Chinese when producing Chinese-audience artifacts.
