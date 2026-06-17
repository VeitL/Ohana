# Design System Governance

`ui规范.selection.json` remains the machine-readable token source of truth. This document governs component lifecycle, not token values.

## Design System Layers

Ohana UI changes must map to one of these layers:

1. Token: color, typography, motion, spacing, sheet, card, icon, chart rule.
2. Primitive: text, button, chip, input, icon, surface, divider.
3. Component: popup close button, drag handle, metric row, setting row, avatar, chart card.
4. Pattern: short record popup, fixed sheet page, hero card motion scene, three-card dashboard.
5. Template: new page template, report page template, dashboard template.
6. Product surface: actual feature screen.

Do not solve a token problem inside a product surface. Do not solve a product-specific problem by changing a global token.

## Discipline Rules

- Global action color discipline lives at the Token and Primitive layers: `goPrimary` / adaptive primary is the only global primary action, confirmation, focus, functional icon, and selected-system color. Domain colors explain domain meaning; they do not become alternate primary CTA systems.
- Surface rhythm comes before extra chrome. Prefer token surface contrast, spacing, grouping headers, and light hairlines before introducing borders, glass, nested cards, or shadows.
- Shadow is budgeted. Ordinary cards, buttons, text, chips, and rows stay flat; shadows require a clear overlay, toast, floating-control, role/avatar, reward, or preview reason.
- Button grammar must be stable across products: one primary pill per screen, quieter secondary actions, semantic destructive actions, and icon-only controls with 44pt hit areas plus labels.
- Press feedback belongs in the primitive. New product surfaces should use the shared light press feedback first, then hand off business writes, persistence, routing, or reward sync after the visual response.
- Converge one component or variant at a time. When a local visual treatment appears useful across surfaces, promote it to the shared primitive/component layer before copying it again.

## Component Promotion Rule

A local UI helper should be promoted to a shared component when:

- It appears in two or more features.
- It encodes a V4 rule.
- It affects accessibility, hit testing, sheet chrome, navigation chrome, privacy placeholders, or motion.
- It is likely to be copied by future pages.

## New Component Requirements

A new shared component must include:

- Role and allowed use cases.
- Disallowed use cases.
- Token dependencies.
- Light/dark behavior.
- Reduce Motion behavior if animated.
- Hit target and accessibility labels.
- Dynamic text behavior.
- Empty/loading/error/private states when applicable.
- Smallest iPhone fit check.
- Example preview with dense data and long localized text.

## Deprecation Rule

Do not leave two visually similar components with different behavior. When replacing a component:

- Mark the old one deprecated in comments.
- Name the replacement.
- Migrate high-traffic usages first.
- Add audit warnings if the old component should not be used in new code.
