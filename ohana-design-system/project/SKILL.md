# Ohana Design System — Agent Skill

Reference the Ohana design system when producing design artifacts (slides, mock screens, landing pages, prototypes) for the **Ohana** iOS pet/family tracker app.

## Quick start

1. Always include `colors_and_type.css` — it provides all color/type/spacing/radius tokens plus utility classes.
2. Use SF Pro Rounded when available. On non-Apple surfaces, `colors_and_type.css` imports **Nunito** (rounded-sans, stand-in for SF Pro Rounded) + **Inter** (body).
3. Use **SF Symbols** on iOS; **Lucide** on web (closest stroke match).
4. Default background is `oh-bg-island` (navy gradient) — the app is a dark-mode-first experience with lime accent.

## Brand-critical decisions

- **Primary flips:** `#C8FF00` lime in dark mode, `#FF7600` orange in light mode. Never show both at once in one artifact.
- **Ink color on primary:** `#1A1A2E` (not black, not white).
- **Glass cards are the default surface** — `.oh-glass` utility or inline `linear-gradient(135deg, rgba(255,255,255,0.22), ...0.04, ...0.12)` with 24px radius + 1px white stroke + 24px backdrop-blur.
- **Rounded everything.** SF Pro Rounded (system), Nunito (web). Never pair with a serif or geometric-sans.
- **Emoji is first-class.** Use 🥥 for coconut currency, 🐕 🐈 for pets, 🔥 for streaks, 🌴 for Life Tree — not as decoration, as UI.
- **Photography style:** warm, golden-hour, shallow-DOF close-ups. Sample images in `assets/backgrounds/`.
- **Copy is bilingual** (zh-CN primary). Preserve Chinese strings when designing for Chinese audiences.

## What to load

- `README.md` — full brand overview, voice, visuals, iconography, caveats.
- `colors_and_type.css` — tokens + utility classes. Always link.
- `tokens.json` — same tokens as JSON.
- `assets/ohana_wordmark.svg` + `assets/ohana_icon.svg` — reconstructed marks (flagged — verify with user).
- `assets/backgrounds/` — sample pet photos (Golden Retriever, Devon Rex).
- `ui_kits/ohana_ios/index.html` — four ready-made screen mocks + live components.

## UI kit available

**`ui_kits/ohana_ios/`** — iOS app recreation. Home, Pet Detail, Coconut Shop, Oasis (Life Tree). React + Babel, loaded through `index.html`. To add a new screen, drop a `screen-xxx.jsx` alongside the others and import it. Share components via `window.X = X` at the end of each JSX file (global scope across Babel scripts).

## Caveats to flag to users

- **No Figma, no original logo PNG** — the wordmark/icon in `assets/` are reconstructions.
- **SF Pro Rounded** isn't licensable off-Apple → Nunito substitute.
- **SF Symbols** are Apple-only → Lucide substitute.
- **GO Club** screenshots in source couldn't be accessed due to spaces in filenames; the design direction came from `GO_Club_UI_Design_Reference.md` + `UIRules.md`.
- Ohana is **primarily Chinese-language** — keep zh-CN strings when designing for Chinese-speaking audiences.
