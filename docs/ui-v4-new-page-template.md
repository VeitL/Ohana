# Ohana V4 New Page Template

Use this when creating or heavily refactoring an app view. The machine source of truth is always `ui规范.selection.json`; this template is only a practical starting point.

## Default Page Shape

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
        .goTranslucentCard(cornerRadius: 22)
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
        .goTranslucentCard(cornerRadius: 18)
    }
}
```

## Default Sheet Shape

Short record, confirm, restock, and lightweight management popups should be implemented as an in-page overlay inside the current `ZStack` so the glass samples the real screen behind it. Reserve system `.sheet` for overview pages, history, long lists, and complex editors.

Use the authoritative short-popup parameters from `ui规范.selection.json`:

- `sheetImplementation=inlineOverlay`
- `sheetHorizontalInset=6pt`
- `sheetPosition=bottomNearSafeEdge`
- `sheetCornerRadius=52pt`
- `sheetMaxHeight=contentAdaptive`
- `sheetGlass=nativeRegular`
- `sheetShadow=liftedAlert`
- `sheetBackdrop=scrimGradient`
- `sheetAnimation=bottomSpringScaleFade`

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

## Required Checklist

- Read `ui规范.selection.json` before designing or editing.
- Use `OhanaAppBackground()` for full-screen pages.
- Use `Color.ohanaPrimaryText`, `Color.ohanaSecondaryText`, and `Color.ohanaTertiaryText`; avoid system `.primary` / `.secondary` in custom surfaces.
- Use `goTranslucentCard`, `goIslandModuleCard`, `goGlassBackground`, or a local token-based surface; avoid ad hoc card stacks.
- Do not wrap pure information summaries in card chrome; reserve card surfaces for tappable, navigable, expandable, or editable grouped surfaces.
- Use `Color.foodDry` for dry food and `Color.foodWet` for wet food; keep stock/remaining-food status on its own inventory status colors.
- Keep compact density, but preserve a 44pt hit target for buttons, toggles, rows, chips, and icon actions.
- Use `ScaleButtonStyle()` for tappable controls unless there is a specific reason not to.
- Use `GoMotion.page`, `GoMotion.feedback`, `GoMotion.fab`, `GoMotion.quick`, or `GoMotion.reduced`; do not invent one-off spring values.
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
