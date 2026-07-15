# Accessibility Governance

Ohana must be usable with VoiceOver, Dynamic Type, and the system accessibility
settings. Accessibility is a release gate, not a nice-to-have. Reduce Motion is
already covered by `AppWorkloadPolicy`; this document covers the rest.

`scripts/audit-accessibility.sh` runs heuristic checks. Passing it does not prove
quality — it only catches common omissions. Treat it as a floor.

## Non-Negotiable Rules

1. **Every interactive control is labeled.** Icon-only buttons, image buttons,
   and custom tappable views must have a localized `accessibilityLabel` (via
   `L10n`), and a `accessibilityHint` when the action is not obvious. Decorative
   images use `.accessibilityHidden(true)`.
2. **Dynamic Type works.** Use `OhanaFont.*` / relative text styles, not
   `.system(size:)` fixed points. Layouts must not clip or truncate at the
   largest standard content size (AX1 minimum). Avoid fixed-height text rows.
3. **Minimum hit target 44x44pt.** Interactive controls must have at least a
   44x44pt tappable area (`.frame(minWidth:44,minHeight:44)` or
   `.contentShape` + padding). Glyph visuals may be smaller; the target may not.
4. **Color is never the only signal.** State, validation, success/failure, and
   categories must also use a shape, SF Symbol, or text (Differentiate Without
   Color / color-blind safety).
5. **Contrast meets WCAG AA.** Body text ≥ 4.5:1, large text/icons ≥ 3:1 against
   their background, in both light and dark mode. Token choices live in
   `ui规范.selection.json`; do not introduce low-contrast one-offs.
6. **Grouping and order.** Composite cells/cards expose one combined element
   (`.accessibilityElement(children: .combine)`) with a sensible reading order;
   avoid VoiceOver reading 8 fragments per pet card.
7. **Traits are correct.** Buttons use button traits, headers use
   `.accessibilityAddTraits(.isHeader)`, toggles report on/off, selected states
   report `.isSelected`.
8. **Respect system settings.** Reduce Motion (via `AppWorkloadPolicy`), Bold
   Text, Reduce Transparency, and Increase Contrast must not break layout or
   hide critical affordances.
9. **Localized accessibility copy.** Author Chinese and English labels/hints via
   `L10n` / `AppLocalizedText`; every other registered language must resolve
   through the shared fallback chain. Never hardcode Chinese in a view.

## Shared Component Requirement

Per `docs/design-system-governance.md`, a new shared component must declare its
hit target, accessibility label strategy, Dynamic Type behavior, and color-blind
safety before it ships.

## Validation

- Run `scripts/audit-accessibility.sh --changed` (or pass files) before reporting
  focused UI work complete; CI and release hardening run
  `scripts/audit-accessibility.sh --all` as a whole-repo strict gate.
- For high-traffic flows (Home cards, Task Center, quick actions, sheets, and
  Oasis), use path-scoped accessibility checks by default. When an explicit
  visual/flow or release request needs Simulator interaction, use the disposable
  `iPhone 17 Tests` environment for clean/destructive journeys and the pinned
  Dogfood phone through `scripts/run-dogfood-simulator.sh` for non-destructive
  existing-data journeys. Physical-device acceptance still owns final VoiceOver,
  Voice Control, Switch Control, touch, and largest-Dynamic-Type evidence.
- Use `// a11y: allow <reason>` only for genuinely decorative or non-interactive
  exceptions.

## Out of Scope (for now, but tracked)

Full Switch Control / Voice Control tuning and audio descriptions are not yet
required, but new flows must not actively block them (keep controls reachable
and labeled).
