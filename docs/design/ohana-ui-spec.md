# Ohana UI Specification

Updated: 2026-10-05

This document is Ohana's UI pattern contract. It explains how screens,
components, motion, and validation should be composed from the existing Ohana
V4 system. It does not replace `ui规范.selection.json`; that JSON remains the
machine-readable token source of truth. This document prevents style drift when
new pages are generated or refactored.

## 1. Authority

UI decisions follow the repository rule stack:

1. Current user request.
2. Product behavior and acceptance truth in `docs/specs/product-foundation.md`.
3. Engineering workflow and smoothness laws in `AGENTS.md`.
4. Tokens and component choices in `ui规范.selection.json`.
5. This UI specification and other governance docs in `docs/`.
6. Current source code, especially mature sibling modules.
7. Historical plans, exports, external design skills, and inspiration.

## 2. Product Feel

Ohana should feel compact, calm, tactile, and fast. It is a daily care app, not
a marketing site. A good Ohana screen lets the user recognize the care target,
act quickly, review history, and leave without reading a manual.

Core qualities:

- **Compact**: dense but breathable. Avoid oversized hero copy, deep card
  stacks, or ornamental sections on operational screens.
- **Solid**: high-frequency custom content surfaces use opaque token fills.
  Semantic system surfaces own their material; custom content must not redraw it.
- **Low noise**: one primary action, quiet secondary actions, sparse shadows,
  no decorative text shadows, no background clutter.
- **Finger-first**: tap, drag, expand, or present feedback must happen on the
  first frame before business work starts.
- **First-render data**: visible modules render from route-scoped value
  snapshots initialized before the first body pass; `onAppear` may reconcile or
  defer non-visible work, but it must not be required for primary content to
  appear correct.
- **Mature sibling first**: when a new page resembles an existing mature page,
  the mature page is the default contract.

## 3. Before New Or Substantial UI Work

New pages and substantial UI refactors should begin with a contract declaration.
Small local edits should directly reuse the existing component or mature sibling
without loading this full specification or producing a new contract:

```text
UI contract: <canonical existing surface/path>
Reason: <same user job, same component family, same interaction class>
Allowed divergence: <only what the product requires>
```

If there is no mature sibling, use `docs/ui-v4-new-page-template.md` and the
tokens in `ui规范.selection.json`. Do not start from an external mockup or a
fresh visual style while a local pattern exists.

Before visual polish, compare the skeleton:

- Page chrome: fixed header, close/back affordance, safe-area behavior.
- Primary action location and timing.
- Sheet, popup, or route presentation style.
- Card density, list rhythm, and section hierarchy.
- Data loading, empty, error, private, and disabled states.
- Motion class and whether the surface needs a frozen snapshot handoff.

## 4. Canonical Surface Map

Use these as the first references when generating or reviewing similar UI:

| Need | Canonical Surface |
| --- | --- |
| High-frequency care detail with quick record, history, settings | `Ohana/Features/Feeding/Views/QuickFeedDetailSheet.swift` |
| Guided care home card and discovery dock | `Ohana/Features/Feeding/Views/GuidedFeedHomeView.swift` |
| Short record popup / lightweight logging | `Ohana/Features/Feeding/Views/QuickFeedDetailContent+ManualTreatSheets.swift` |
| Quick action second-level menu | Feeding quick-action menu pattern in `FocusHomeRouteSheetModifier.swift` |
| Long overview/history sheet page | `QuickFeedDetailSheet` and Settings sheet pages |
| Settings rows and debug tools | `Ohana/Features/Settings/Views/SettingsView+Debug.swift` |
| UI token console / developer previews | `Ohana/Features/Settings/DesignLab/UIGuidelinesView.swift` |
| Home card spatial motion | `VerticalSolidHomeView`, `FocusHomeVerticalSolidScene`, `OhanaMotionScene` |
| Zen check-in card stack and full-card score gesture | `ZenHomeView`, reusing `FocusHomeVerticalSolidCardSurface` geometry |
| Human, Pet, and Plant read-first profile | `ProfileDetailScaffold`, `ProfileCompletionCard`, and the three basic-info views |
| Oasis surface in either app mode | Shared `OasisHomeTabHost` and `VerticalSolidHomeOasisFrozenTreeStage`; Zen may only overlay its one-time starter gift |
| Plant care detail | Follow the QuickFeed guided care structure before adding plant-specific modules |
| Performance diagnostics | `Ohana/Features/Settings/Views/SettingsPerformanceDiagnosticsView.swift` |

When two surfaces seem relevant, choose the one with the same user job first,
then the one with the same presentation style.

## 5. Foundations

### Color

- Use semantic Ohana colors only: `goPrimary`, `goTeal`, `goYellow`, `goRed`,
  member theme colors, domain colors, and text/surface tokens.
- `goPrimary` is reserved for the global primary action, selection, focus,
  confirmation, and functional icons.
- Product defaults are Go Blue (`#2563EB`) in light appearance and Go Lime
  (`#C8F34A`) in dark appearance. A device-local Debug lab may compare
  candidate accents; Release builds always ignore those developer selections.
- Pet/human theme colors must not reuse primary aliases.
- Domain colors carry meaning: feeding, reminders, danger, success, rewards,
  charts, and plant care should not borrow each other's semantics.
- Never hardcode white/black for app UI; use text, surface, stroke, and action
  tokens so dark and light modes stay aligned.
- Solid `goPrimary` surfaces pair with `ohanaPrimaryActionText`. Member themes,
  custom hex colors, and other dynamic solid tints derive their foreground from
  `OhanaResolvedPrimaryAccent.actionTextColor`; bright teal/orange surfaces must
  not inherit a fixed white foreground.

### Typography

- Use rounded `OhanaFont` system semantic helpers throughout the app. Titles
  and headings use bold; body, callout, subheadline, footnote, and caption default
  to medium, with semibold for emphasis. Keep Dynamic Type and native controls.
- `brandTitle` and `brandMetric` preserve member/Oasis/reward expression; measured
  values retain monospaced digits. Heavy/black is reserved for intentional heroes.

### Iconography

- Use SF Symbols or template-rendered vector glyphs for functional UI.
- Functional icons are monochrome token colors, usually `goPrimary`.
- Icon-only controls require localized accessibility labels and 44pt hit areas.
- Do not use emoji, multicolor illustration icons, or decorative glyphs for
  navigation, settings rows, quick actions, status rows, or primary commands.

### Spacing And Density

- Custom pages use `OhanaSpacing`: pageMargin 16pt, section 24pt, row 12pt,
  related 8pt. Native List/Form keep system spacing.
- Reflow adjacent labels and actions vertically when the available width or
  accessibility text size cannot fit them. Long names wrap instead of shrinking
  into unreadable text.
- Use stable dimensions for repeated controls, grids, tiles, boards, quick
  actions, counters, and charts.
- Avoid card-in-card layouts. Use spacing, headers, hairlines, and row rhythm
  before adding another framed surface.
- Content must respect safe areas, bottom navigation, keyboard, dynamic island,
  and sheet chrome.

### Surfaces

- Default business surfaces use solid token fills:
  `ohanaCardSurface`, `ohanaCardSurfaceElevated`, `ohanaControlFill`.
- Use cards for tappable, navigable, or interactive grouped surfaces. Pure
  information summaries should usually be inline metrics or rows.
- Shadows are budgeted. Ordinary text, cards, chips, buttons, and list rows do
  not receive decorative shadows.
- Material/glass is not a default business-card style. Use real Liquid Glass
  for system navigation chrome, toolbars, back/close/floating controls, sheet
  control regions, popups, native system-control interaction surfaces, or an
  explicitly documented exception.
- Zen status selection is a documented interaction exception: one noninteractive
  full-card Liquid Glass layer may cover the touched card while the underlying
  gesture owns input. It must match the card bounds and corner radius, use
  high-contrast text, and become an opaque contrast surface under Reduce
  Transparency.
- Pet, Human, and Plant identity hero cards are the only standing content-layer
  exception: one noninteractive regular-glass surface beneath a translucent
  member-theme atmosphere. Reduce Transparency and reduced-effects modes use
  the opaque five-stop fallback.

## 6. Core Components

### Buttons

- One primary CTA per screen or popup.
- Primary content button: pill, solid `goPrimary`, `ohanaPrimaryActionText`, min
  44pt. Floating chrome actions use the system `glassProminent` style instead.
- Secondary button: token control fill or quiet text treatment.
- Destructive button: semantic danger color and explicit confirmation.
- Icon-only content button: SF Symbol, 44pt hit target, accessibility label.
  Back, close, and toolbar controls use the system glass button style.
- Native controls keep system press and selection feedback. `ScaleButtonStyle()`
  and `GoMotion` are for custom brand content, never layered over native
  Picker, Menu, toolbar or glass button interactions.

### Settings Rows

- Use `settingsRow` and `settingsSection` when inside Settings.
- Leading icon: plain SF Symbol, no colored tile unless an existing Settings
  pattern explicitly uses one.
- Row height: at least 44pt.
- Subtitle is for operational context, not paragraphs.

### Cards

- Standard care cards use token surfaces, a hairline stroke, and restrained
  radius (`OhanaRadius.cardSoft` or a mature sibling's existing radius).
- Avoid nested card chrome. If a module needs subgroups, use rows, chips,
  dividers, or compact metric blocks.
- Interactive cards must keep hit testing stable during expand/collapse. Users
  should not wait for animation completion before the next valid tap.
- Starter-task cards complete short profile fields in place. A successful save
  keeps the editor open with a persistent saved status; only structured,
  safety-sensitive, or real-action workflows navigate to a dedicated surface.

### Chips And Segmented Controls

- Use `ohanaContentTabsPickerStyle` for native list/calendar content switching
  and `ohanaRoundedTextFieldStyle` for native inputs. Both adopt iOS 27 behavior
  while retaining iOS 26.2 fallbacks.
- Use quiet labels for passive status; avoid adding repeated decorative pills.
- Toggle, Slider, segmented Picker, and DatePicker stay native so the system
  owns rest, press, drag, selection, disabled state, refraction, and Reduce
  Motion behavior. Do not rebuild their glass with opacity-only capsules.
- Selected state uses solid `goPrimary` or the domain semantic color.
- Unselected state uses solid elevated surface, not a barely visible tint.
- State must not be color-only; include label, icon, position, or value.

### Feedback And Statistics

- `OhanaFeedbackState` defaults to a page state. Use `layout: .compact` inside
  an existing section; it adds no nested card or fixed large minimum height.
- Loading, no records, an actual zero, and a failed read have different meanings.
  Never show 0.0 kg or “new data” as a substitute for absent weight records.
- One weight observation remains a point at its actual time and value. It must
  not create a flat trend from fabricated endpoints.
- Object and time range each have one menu. Keep all six household insight
  categories and their locks discoverable. Preserve entitlement checks.
- Shared charts own one line reveal (`GoMotion.chartLine`, 0.72s ease-out),
  without a second parent animation or a y-axis rise from zero. An unchanged
  chart does not replay when scrolling back. AppWorkloadPolicy owns the motion
  budget and Reduce Motion behavior.

### Inputs

- Use `OhanaTextField` or existing project input helpers.
- Flat input surfaces with clear focus/error/success states.
- Keep keyboards and popup dismissal scoped to the active input surface.
- Text fields use `OhanaTextField(placeholder:text:style:)`; do not assemble a
  one-off `TextField` background, border, and focus state inside a page.

### Control Rows

Use this row grammar for toggles, dates, bounded numbers, and low-frequency
choices. The same examples are rendered in
`Ohana/Features/Settings/DesignLab/OhanaUISpecShowcaseView.swift`.

- Row wrapper: `.padding(12)` then
  `.feedFlatBlockSurface(cornerRadius: OhanaRadius.control)`.
- Label: title on the left, current value on the right, one short footnote
  below. The value must be visible before the user opens the control.
- Toggle row: `Toggle(isOn:) { specControlLabel(...) }` with domain tint.
- Date row: `DatePicker(selection:displayedComponents:) { specControlLabel(...) }`.
- Stepper row: `Stepper(value:in:) { specControlLabel(...) }` for bounded
  numeric settings such as intervals, thresholds, or quantities.
- Menu picker: `.pickerStyle(.menu)` for long or low-frequency choices.
- Segmented picker: `.pickerStyle(.segmented)` for 2-4 frequent mutually
  exclusive choices.
- Every control row keeps at least a 44pt target and must survive long German
  text without clipping.

### Charts

- Charts must answer a care question. If they do not change user behavior, use
  simpler metric rows.
- Use quiet axes, token colors, and small annotations.
- Mini care charts use `OhanaMinimalBarChart` or the mature sibling's existing
  compact chart component before introducing a custom `Chart {}` block.
- Keep chart data as value snapshots. Do not fetch or aggregate in `body`.
- Dense data must not cause scroll hitching; precompute bins off the main actor
  when needed.

## 7. Page Archetypes

### Care Detail Sheet

Use for watering, feeding, medication, grooming, and similar detail flows.

Required structure:

1. Native `NavigationStack` sheet chrome with one system cancel/back affordance.
2. Care target identity and current status.
3. Primary quick record card high on the page.
4. Recent history or chart.
5. Optional habit/recommendation details.
6. Reminder/schedule management.
7. Secondary settings/details.
8. Empty, disabled, failed-write, and private states.

Interaction rule: quick record must give local visual feedback immediately, then
defer writes, reward sync, reminder sync, and read-model refresh.

### Root Navigation And Contextual Actions

- Standard mode has one bottom row, reserved by `safeAreaInset`: a native Picker
  followed by a native Button for one action or Menu for several actions.
- Keep Home / Tasks / Oasis / Plants order and existing unlock rules. Use
  `ohanaContentTabsPickerStyle` (`.tabs` on iOS 27, `.segmented` on 26.2).
- Prefer localized text. At accessibility sizes or when text cannot fit, use
  SF Symbols while retaining full accessible names, selected state and task
  count. Each segment and context action has at least a 44pt target.
- Home and Plants open quick logging, Tasks adds an event, Oasis injects energy.
  Reuse the existing subject/action catalog. Skip subject selection for one
  eligible subject, retaining action choices and business confirmations.
- Do not draw a second glass layer, animate menu items flying in, delay taps
  until an animation finishes, or manually reserve the same bottom inset twice.
- Zen retains its native three-page TabView and shares modal/navigation rules.

### Modal And Editor Ownership

- Each modal host provides one title and `OhanaModalToolbar`. Browsing uses a
  trailing `.close` on the title row; editing uses leading `.cancel` and trailing Save. Pushed
  children inherit system Back and edge-swipe, without an extra close action.
- `ohanaEditorChrome` / `OhanaEditorSheet` own dirty-draft confirmation and
  submission UI. Dirty editors cannot swipe away. Cancel asks with a system
  confirmationDialog; failure keeps inputs, attachments and route context.
- Save disables duplicate submission and dismissal. Only a committed domain
  result permits success feedback or closing. Loading shells expose title and
  close immediately, and route tasks cancel on dismissal.
- Member creation keeps its branded step card and progressive bottom CTA; its
  standard modal uses native Cancel and the same draft guard. Required first-run
  steps keep their product-defined back/defer semantics. Photos, avatar crops,
  Oasis and member-card motion remain documented brand content exceptions;
  they do not authorize custom modal transitions or duplicate exit controls.

### Short Record Popup

Use for quick logging, confirmation, restock, or lightweight management.

Required structure:

- Use `Alert` or `confirmationDialog` for decisions, `Menu` for compact commands,
  and native `sheet(item:)` for record, restock, or management content.
- Let SwiftUI own the sheet surface, safe areas, keyboard avoidance, drag gesture,
  transition, and dismissal.
- Use `NavigationStack`, `Form`/`List`, medium/large detents and shared native
  toolbar actions. Editors have one Save action in the confirmation position.
- Do not add an in-page scrim, replacement handle, fixed popup frame, or custom
  close capsule.

### Long Overview Sheet

Use for history, settings, management, and diagnostics.

Required structure:

- Native `sheet(item:)` presentation with `NavigationStack` when hierarchy is
  needed.
- A real navigation title and native toolbar actions.
- `List` or `Form` with quiet `Section` headers where row semantics fit.
- No duplicate or hand-drawn close controls. Push details in the current stack;
  present independent editing as a separate native sheet.

### Household Insights Sheet

- Keep one horizontally scrolling tab row in this fixed order: Weight,
  Expenses, Weekly, Care Analysis, Reminder Health, Long-term Review.
- Never remove a locked tab from the row. Show a lock plus the exact required
  tree level, and mount only the currently selected tab's content.
- Weight and Expenses are separate Lv.1 surfaces. Health and medication family
  aggregates remain in their separate Lv.2 group.
- A locked Reminder Health tab still renders the compact permission, overdue,
  and failed-reminder safety summary. Detailed scheduling history stays locked.
- Free range controls expose 7 and 30 days with one selected subject. Personal
  adds 90 days, one year, all time, comparison, and analytical export.
- Locks, status, and selection always use text or symbols in addition to color;
  the tab row must remain usable at large Dynamic Type sizes and in RTL.

### Home Spatial Card

Use stable ZStack motion scenes for expand/collapse and hero transitions.

Required structure:

- Freeze visual snapshot at animation start.
- Motion scene owns frame, zIndex, transform, hit testing, and thaw timing.
- Business work stays outside the animation loop.
- Tap targets remain responsive during and after transition.

## 8. Motion And Smoothness

Ohana motion is useful, restrained, and governed.

Motion rules:

- Finger-first frame mutates only local visual state, route value, frozen
  snapshot, animation progress, focus, pressed/selected state, or hit testing.
- Heavy work is deferred, cancellable, cacheable, or batched.
- Visible motion consumes `GoMotion` and respects Reduce Motion and
  `AppWorkloadPolicy`.
- Hidden surfaces are unmounted, inert, or snapshot-only. They must not keep
  broad queries, timers, image decoding, or dashboard aggregation alive.
- Repeating/ambient motion must be visible, intentional, and budgeted.
- Expanded/collapsed surfaces should accept valid taps as soon as the target is
  visually available, not only after animation completion.
- Custom buttons use one shallow press: 0.985 scale, no default vertical
  displacement or shadow, and a brief opacity response. Native controls keep
  their system feedback. Reduce Motion removes custom spatial transforms.
- List reveals keep content readable and tappable on the first frame, use
  cancellable view tasks, and never scale the list. The existing 35 ms stagger
  remains bounded at 240 ms. Floating menus use a lighter 25 ms entrance stagger
  capped at 100 ms; all rows leave together in 160 ms before a submenu handoff.
- Routine value feedback uses a numeric transition or one symbol pulse. Do not
  combine symbol bounce and pulse. Reward pops remain reserved for meaningful
  completion and use a small lift; ambient glow changes opacity without scaling
  the content and stops under the workload policy.
- Module selection updates local route state immediately. Animate the selected
  pill and a light content handoff without applying a spring transaction to the
  entire outgoing and incoming data-backed module.

Smoothness compliance before calling a strict task complete:

| Gate | Required Evidence |
| --- | --- |
| Finger-first frame | Local state changes before persistence/business work |
| Frozen render or snapshot handoff | Animation reads value snapshots only |
| Heavy work deferred and cancellable | Task, actor, or delayed handoff exists |
| Visual/business separation | View emits intent; service/command writes fact |
| Runtime budget and visibility gating | Timers/ambient motion gated by policy |
| Thaw timing | Live data resumes only after visual handoff |
| Safe area and hit testing | Controls remain tappable and unobscured |
| Validation performed | UI audit, accessibility audit, build/test as scoped |

## 9. Data, State, And Privacy

- Render components receive small value snapshots.
- SwiftData is not a render-time aggregation engine.
- Reusable rows, cards, popups, dashboards, and motion scenes must not own broad
  `@Query` reads.
- Domain services own persistence writes, rewards, reminders, tasks, ledger,
  and side effects.
- Private/locked states show icon + text placeholder and never leak values.
- Failed writes keep the UI recoverable with explicit status and retry.

## 10. Accessibility And Localization

- Chinese and English copy are mandatory at authoring time through `L10n`,
  `AppLocalizedText`, or localized resources.
- Other registered languages may fall back through the existing chain.
- Dynamic Type must be considered for all user-facing text.
- Icon-only controls need labels.
- Interactive targets need 44pt hit areas.
- State cannot rely on color only.
- Check dark and light modes together.
- Avoid hiding meaningful content behind scroll, safe area, keyboard, or chrome.

## 11. Performance Budgets

Treat UI richness as a budget, not a default.

- Shadows: reserve for popups, sheets, toasts, critical floating controls, and
  major hero visuals.
- Glass/material: reserve for system-aligned surfaces and explicit showcases.
- Blend modes/noise/text shadows: avoid on high-frequency pages.
- Lists and dashboards: use bounded fetches, snapshots, and cached derived
  state.
- Images: downsample, cache by signature, and decode off the main actor.
- Charts/calendars: precompute visible windows.
- Release + real device decides smoothness; simulator can rank CPU work but
  cannot prove final frame delivery.

## 12. Validation

Choose the smallest trustworthy gate, then escalate by risk.

For UI-only changes:

```bash
scripts/audit-ui-v4.sh --changed
scripts/audit-accessibility.sh --changed
```

For docs-only changes:

```bash
git diff --check
```

For Swift UI changes that touch routes, sheets, shared components, localization,
or compile-sensitive code:

```bash
scripts/dev-check-changed.sh
```

For smoothness-sensitive work:

- State the affected flow.
- State whether launch, first render, tap response, route transition, scrolling,
  memory, SwiftData reads, image decoding, timers, or background work changed.
- Use Instruments/MetricKit on Release + real device when deciding final frame
  delivery.

## 13. Anti-Patterns

Do not ship these:

- New page generated from a web landing-page style while a local app pattern
  exists.
- Card-in-card layouts for simple information.
- Big text blocks explaining how to use the UI.
- Decorative shadows on every card.
- Material/glass as the default business-card fill.
- Emoji or multicolor glyphs for functional controls.
- Broad SwiftData reads in reusable cards or popups.
- Animation that blocks the next valid tap until completion.
- Route presentation that builds every destination eagerly.
- Popup presentation that shows a large background card and then a foreground
  modal for the same action.

## 14. Definition Of Done

A new or refactored Ohana UI is done when:

- It declares and follows a local UI contract.
- It uses `ui规范.selection.json` tokens and shared Swift helpers.
- It has the expected empty, loading, error, private, dense, and long-text
  states for its risk level.
- It keeps visual work separate from business work.
- It passes the relevant UI and accessibility audits.
- It names any remaining manual or real-device validation gap instead of hiding
  it in chat context.

## 15. October 2026 Core-Page Alignment

UI contract: existing QuickFeed detail, native Settings forms, FeatureHub shared
components, and the member wallet-card motion scene. The accepted change keeps
all business commands, data models, shop IDs, mode navigation, and unlock rules.
Care screens prioritize member/status, record action, recent records, then
plans and management. Modal hosts own one navigation title and one close action.
The nine-item shop retains its three groups and legacy inventory support.

References inform specific choices, not a new visual identity: [iOS 27](https://www.apple.com/os/ios/)
for system material/readability, [Things](https://culturedcode.com/things/features/)
for quiet grouping, [Gentler Streak](https://docs.gentler.app/release-notes-and-announcements/a-more-intuitive-streak)
for concise status, and [Planta](https://getplanta.com/) for photo/status/action hierarchy.
