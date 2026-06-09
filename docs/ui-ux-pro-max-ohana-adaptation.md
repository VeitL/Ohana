# UI UX Pro Max for Ohana

Source: `nextlevelbuilder/ui-ux-pro-max-skill`.

This skill is installed locally in the repo at `.codex/skills/ui-ux-pro-max/` and is also installed in the Codex user skill folder. Restart Codex for automatic skill activation.

## Role

`ui-ux-pro-max` is an advisory design intelligence layer for Ohana. It can help with:

- UI/UX review checklists
- Information architecture options
- Accessibility and touch target checks
- SwiftUI interaction guidance
- Forms, sheets, charts, and feedback quality checks
- Product-category inspiration for pet care, health, collaboration, and dashboards

It is not a source of truth for Ohana tokens.

## Priority

When UI advice conflicts, follow this order:

1. `ui规范.selection.json`
2. `docs/design/ui规范.md`
3. `AGENTS.md`
4. `docs/ui-v4-new-page-template.md`
5. This adaptation document
6. Raw `ui-ux-pro-max` recommendations

The generated `ui-ux-pro-max` palette, typography, landing-page pattern, and web-specific rules must not override Ohana V4.

## Useful Ohana Mappings

| UI UX Pro Max Advice | Ohana Implementation Rule |
| --- | --- |
| Touch targets at least 44pt | Keep all tappable controls at or above 44pt hit area, even if the visual icon is smaller. |
| Reduced Motion | Use `AppWorkloadPolicy`, `GoMotion`, and existing Reduce Motion handling. Do not create a parallel policy. |
| State changes should animate smoothly | Use `GoMotion.feedback`, `GoMotion.page`, `GoMotion.quick`, `contentTransition(.numericText())`, and shared motion helpers. |
| Avoid excessive motion | Animate only meaningful elements. Decoration loops must stop when invisible or in low power. |
| Forms need visible labels and feedback | V4 popups and forms must show persistent labels, validation near the field, and a clear save/result state. |
| Mobile keyboards should fit input type | Prefer embedded mini keypads for weight, money, grams, and other frequent numeric input. |
| Accessibility labels for icon buttons | All icon-only close, back, lock, settings, and action buttons need `accessibilityLabel`. |
| Consistent card/elevation style | Ohana uses flat cards only for interactive grouped surfaces; pure summaries are unframed. |
| Charts need legends and accessible colors | Charts use semantic colors, quiet axes, labels/legends, and must not rely on color alone. |

## Product Guidance That Fits Ohana

`ui-ux-pro-max` matches Ohana to several product categories:

- Pet tech: playful, warm, micro-interactions, flat design
- Veterinary/health: accessible, ethical, calm, clear status
- Collaboration/productivity: simple task hierarchy, visible ownership, clear completion state
- Dashboard/data: scannable metrics, quiet chart axes, drill-down only when needed

Ohana should translate these into the existing V4 direction:

- Deep/dark mode with `goLime` primary and light mode with `goBlue` primary
- Warm member/pet personality through avatars, 2.5D bodies, badges, and small domain colors
- High-frequency care pages as three-card dashboards
- Short actions as inline overlay popups
- Large history/overview pages as normal sheets/pages with solid backgrounds

## What To Ignore

Do not import these raw recommendations into Ohana:

- Web landing-page CTAs, QR code patterns, App Store marketing sections
- Google Fonts recommendations
- Orange primary palette or any generated palette that conflicts with V4
- Cursor/hover-only web checks
- Raw `.spring()` / `.easeInOut` if a `GoMotion` token exists
- Generic “use Form for settings” when Ohana has a custom V4 setting row pattern

## How To Use During Implementation

For a UI task:

1. Read `ui规范.selection.json`.
2. If the task is broad or ambiguous, query `.codex/skills/ui-ux-pro-max/scripts/search.py` for UX, SwiftUI, product, or chart guidance.
3. Translate only compatible advice into Ohana V4 components.
4. Run `scripts/audit-ui-v4.sh` on changed files.
5. Run `scripts/build-debug-fast.sh`.

Example:

```bash
python3 .codex/skills/ui-ux-pro-max/scripts/search.py \
  "SwiftUI medication tracking forms chart accessibility" \
  --stack swiftui \
  --max-results 10
```

## Human Module Update Order

Remaining human pages should be updated in this order:

1. High-frequency quick record pages: weight, expense, note
2. Medication and health report pages
3. Workout and activity pages
4. Human all-features dashboard and destination chrome
5. Wishlist, privacy, PIN, and account management
6. Long-tail archive/report surfaces

Each page should keep privacy as a hard boundary: owner sees private data with “only visible to you”; non-owner sees locked placeholders without values.
