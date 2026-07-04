# Ohana V4 New Page Template

Use this when creating or heavily refactoring an app view. The machine source of truth is always `ui规范.selection.json`; this template is only a practical starting point.

Before using the code shape below, read `docs/design/ohana-ui-spec.md` and declare the local UI contract you are following. If a mature sibling surface exists, copy its information architecture and interaction pattern before adjusting visuals.

## Before Creating Local UI

Before adding a page-local button, card, row, popup, metric, chart, avatar treatment, close control, or motion helper, check whether an existing shared component or V4 pattern already exists.

Create local UI only when:

- The behavior is truly feature-specific.
- No shared component matches the role.
- The local variant does not weaken accessibility, hit testing, density, motion, or token semantics.
- The code is unlikely to be copied elsewhere.

Promote local UI to a shared component when it appears in two features, encodes a V4 rule, or affects navigation chrome, sheet chrome, privacy placeholders, forms, charts, accessibility, or motion.

## Template Scope

This template is a construction starter, not a route-ownership rule. Do not copy the sample `NavigationStack` into leaf views already hosted by an app route host. Route hosts own navigation containers; pages own content, local chrome, local interaction state, and typed intents.

Default to MV, not MVVM. Use local `@State` for view-owned state,
`@Environment` for shared services, scoped `@Query` only in route/data
containers, and services/models for business rules. Do not add a view model just
to mirror local state, wrap environment dependencies, or hide a long `body`;
split the view into dedicated subview types first.

## Default Page Shape

Use `ZStack` as the visual root. For static content it is simply the background/content layering tool. For key motion interactions, use a stable motion scene: keep layers mounted, freeze the UI snapshot before animation, and drive transforms/masks from one progress value.

```swift
import SwiftUI

struct ExampleV4Page: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        header
                        primarySection
                        stateSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 38, height: 34)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 42, height: 42)
                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Page Title")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("Short status, not instructions")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var primarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Section")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)

            Button {
                withAnimation(GoMotion.feedback) {
                    // update visible state
                }
            } label: {
                Label("Primary Action", systemImage: "checkmark")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .goSolidCardSurface(cornerRadius: 22)
    }

    private var stateSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.goYellow)
            Text("Private values stay hidden")
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 14)
        .goSolidCardSurface(cornerRadius: 18)
    }
}
```

## Default Sheet Shape

Short record, confirm, restock, and lightweight management popups should be implemented as an in-page overlay inside the current `ZStack` so the glass samples the real screen behind it. Reserve system `.sheet` for overview pages, history, long lists, and complex editors.

Inline overlays are not free-form full-screen views. If an overlay or custom sheet ignores the container safe area, the host must pass explicit top and bottom safe-area insets into the presented content. Header chrome, close buttons, and drag affordances must start below the status bar/Dynamic Island region; bottom actions and floating controls must clear the home indicator. Entry and exit should be driven by a lightweight shell or frozen snapshot first, with heavy content mounted after the visual handoff and route clearing delayed until the exit animation has started.

Before marking an inline overlay or custom sheet complete, verify the actual route for entry motion, exit motion, close-button hit testing, top safe-area clearance, and bottom safe-area clearance. Use a simulator screenshot or manual-device run when the route is reachable; if onboarding or missing seed data blocks the route, report that explicitly.

Use the authoritative `sheet*` tokens from `ui规范.selection.json`. The example below mirrors the current token values; if the JSON changes, update the example from the JSON instead of treating this file as a second source of truth.

```swift
@State private var activePopup: PopupKind?
@State private var popupHeight: CGFloat = 360
@State private var popupVisible = false

ZStack(alignment: .bottom) {
    pageContent

    if let activePopup {
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 6
            let cornerRadius: CGFloat = 52
            let bottomInset: CGFloat = 8
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            ZStack(alignment: .bottom) {
                Color.black.opacity(popupVisible ? 0.16 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { dismissPopupOrKeyboard() }

                popupContent(activePopup)
                    .frame(width: proxy.size.width - horizontalInset * 2)
                    .frame(height: popupHeight)
                    .background {
                        shape
                            .fill(.clear)
                            .glassEffect(.regular.interactive(false), in: shape)
                    }
                    .clipShape(shape)
                    .shadow(color: Color.black.opacity(popupVisible ? 0.56 : 0), radius: 48, y: -18) // ui-v4: allow liftedAlert popup shadow
                    .shadow(color: Color.black.opacity(popupVisible ? 0.46 : 0), radius: 28, y: 12) // ui-v4: allow grounding popup shadow
                    .offset(y: popupVisible ? 0 : popupHeight + 72)
                    .scaleEffect(popupVisible ? 1 : 0.982, anchor: .bottom)
                    .animation(GoMotion.page, value: popupVisible)
                    .padding(.bottom, bottomInset)
            }
        }
    }
}
```

## Stable ZStack Motion Scene

Use this pattern for hero cards, FAB/menu reveals, reward reveals, gacha/Oasis rewards, role creation cards, and chart range switches. Do not use it to over-engineer ordinary static lists.

```swift
OhanaMotionScene(role: .hero, isActive: selectedID != nil, reduceMotion: reduceMotion) {
    backgroundLayer
        .ohanaSceneLayer(zIndex: 0, hitTesting: false)

    supportingLayer
        .offset(y: supportingOffset(progress))
        .opacity(supportingOpacity(progress))
        .ohanaSceneLayer(zIndex: 10, hitTesting: progress > 0.98)

    activeLayer
        .frame(width: activeFrame.width, height: activeFrame.height)
        .position(x: activeFrame.midX, y: activeFrame.midY)
        .ohanaSceneLayer(zIndex: 20)
}
```

Rules:

- One user action owns one progress value.
- Do not insert/remove the active visual layers mid-transition.
- Prefer reveal masks and transforms over delayed fade-ins.
- No image decoding, SwiftData scans, reward writes, or heavy state aggregation on the tap-to-first-frame path.
- Visible first-screen content must be seeded from route data or value snapshots before the first body pass; do not initialize primary modules from empty `@State` and rely on `onAppear` to backfill them.
- Reduce Motion should keep the same final states but use short fade/scale.

## Required Checklist

- Read `ui规范.selection.json` before designing or editing.
- Reserve fixed chrome before laying out content: status bar/Dynamic Island, fixed headers, bottom navigation, sheet chrome, and host insets. Main content must not start under fixed UI.
- Verify hero cards, avatars, charts, CTAs, close buttons, and quick actions are fully visible on the smallest supported iPhone viewport and in embedded containers.
- Do not create accidental double backgrounds or double borders. Use one primary card surface unless the design is an intentional physical stack of multiple real cards.
- Give decorative ZStack layers `.allowsHitTesting(false)` and keep close buttons, top buttons, CTAs, and quick actions on explicit foreground zIndex layers.
- Check long localized text, large numbers, missing images, 2.5D full-body avatars, and real dense data before considering the page done.
- Check dark and light mode together. Glass must remain visibly refractive while preserving text and icon contrast.
- Use `OhanaAppBackground()` for full-screen pages.
- Use `Color.ohanaPrimaryText`, `Color.ohanaSecondaryText`, and `Color.ohanaTertiaryText`; avoid system `.primary` / `.secondary` in custom surfaces.
- Use `goSolidCardSurface`, `goIslandModuleCard`, `goGlassBackground`, or a local token-based surface; avoid ad hoc card stacks. `goTranslucentCard` is a legacy alias for a solid V4 card surface.
- Do not wrap pure information summaries in card chrome; reserve card surfaces for tappable, navigable, expandable, or editable grouped surfaces.
- Use `Color.foodDry` for dry food and `Color.foodWet` for wet food; stock, remaining food, and treats follow the current JSON token policy, with warning/error colors only for local low-stock or abnormal states.
- Keep compact density, but preserve a 44pt hit target for buttons, toggles, rows, chips, and icon actions.
- Use `ScaleButtonStyle()` for tappable controls unless there is a specific reason not to.
- Use `GoMotion.page`, `GoMotion.feedback`, `GoMotion.fab`, `GoMotion.quick`, or `GoMotion.reduced`; do not invent one-off spring values.
- Apply Ohana premium micro-motion by default: visible numbers use `.ohanaNumericMotion(value)` or `contentTransition(.numericText())`; member/filter/segmented/calendar-owner switches use selected-state-first snapshot handoff with `GoMotion.selection` or `GoMotion.stateChange`; related visible changes begin in the same interaction frame.
- Keep micro scale restrained: roughly 1.01-1.05 for selection/context feedback and up to about 1.08-1.12 only for reward or success pulses. Avoid hard content replacement, delayed two-step transitions, large bounce, repeated wobble, and fake delta animations during context switches.
- For key animated interactions, use `OhanaMotionScene` or an equivalent stable `ZStack + single progress` scene; avoid independent delayed animations for the same action.
- Prefer dedicated subview `View` types over large computed `some View` helpers
  when a section has state, async work, branching, or deserves its own preview.
- Keep `.task(id:)` identifiers cheap and stable: ids, revision tokens, small
  visibility flags, or user input after debounce. Do not use full content
  signatures, localized labels, image data, relationship scans, or `Date()`
  buckets as task ids on high-frequency surfaces.
- Use `sheet(item:)` or typed sheet/popup routes when presentation state carries
  a selected model. Avoid parallel booleans for mutually exclusive sheets and
  avoid `if let` inside a sheet body when the route already carries the data.
- If an action can enter from App Intents, widgets, notifications, deep links, or
  Shortcuts, model it as a typed route or typed command first; do not add a
  system-surface-specific side channel.
- Liquid Glass migrations must use native `glassEffect` / `GlassEffectContainer`
  with availability fallback, consistent shapes, and `.interactive()` only on
  interactive elements. Ordinary business cards still follow V4 solid surfaces
  unless the task explicitly asks for Liquid Glass migration.
- Settings rows must follow `settingIcon`; non-sheet pages must follow `pageBackButton` and `pageCloseButton`; sheet close controls must follow `sheetChrome`.
- New sheets must follow independent sheet tokens from `ui规范.selection.json`: compact layout, nativeRegular background, flat card/input, pill button, iconOnly chrome, and an adaptive content-height detent for short record/confirm sheets.
- Charts use area trends and quiet axes.
- Private/locked states show a lock placeholder and never leak values.
- Run `scripts/audit-ui-v4.sh --changed` before reporting UI work complete.

## Common Allowlist Cases

Use an inline comment only when the exception is intentional:

```swift
Color.black.opacity(0.22) // ui-v4: allow scrim behind modal overlay
```

Do not use allowlist comments to bypass ordinary card, text, button, or page styling.
