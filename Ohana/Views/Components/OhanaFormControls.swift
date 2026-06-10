//
//  OhanaFormControls.swift
//  Ohana
//
//  Construction-level UI consistency: the V4 tokens in ui规范.selection.json
//  get ONE Swift home for radii, sheet detents, and text inputs. New code
//  reaches for these instead of re-deriving literals; scripts/audit-ui-v4.sh
//  flags raw TextField, hardcoded detent heights, and radius literals.
//

import SwiftUI

// MARK: - Radius Scale
// Anchored on verified V4 values already shipping in the app. Do not invent
// new steps here without updating ui规范.selection.json and docs/design/ui规范.md.

enum OhanaRadius {
    /// Boxed form input surface (canonical quick-sheet input).
    static let input: CGFloat = 20
    /// Standard business/module card (matches goIslandModuleCard default).
    static let card: CGFloat = 20
    /// Large hero/summary card surface.
    static let cardLarge: CGFloat = 24
    /// Compact system sheet chrome (ohanaCompactSheetPresentation).
    static let sheetCompact: CGFloat = 32
    /// Long sheet page chrome (ohanaSheetPagePresentation).
    static let sheetPage: CGFloat = 36
    /// Inline short popup container (V4 short popup: continuous 52pt).
    static let inlinePopup: CGFloat = 52
}

// MARK: - Sheet Detent Presets
// System sheets pick a semantic preset instead of per-sheet height literals.
// Computed adaptive heights remain allowed; raw numeric .height(...) is audited.

enum OhanaSheetDetents {
    /// Overview/history sheets that start half-height and can grow.
    static let overview: Set<PresentationDetent> = [.medium, .large]
    /// Full-page sheet flows.
    static let full: Set<PresentationDetent> = [.large]
    /// Single-purpose compact pickers.
    static let compactMedium: Set<PresentationDetent> = [.medium]
}

// MARK: - Ohana Text Field (V4 `input = flat` with clear state emphasis)

/// The canonical V4 text input. Mirrors the established boxed quick-sheet
/// pattern (OhanaFont label, solid token surface, hairline stroke) and the
/// compact capsule control-row pattern, adding a restrained focus emphasis.
/// Standard text-input modifiers (.keyboardType, .textInputAutocapitalization,
/// .submitLabel, .focused) chain onto this view and propagate to the field.
struct OhanaTextField: View {
    enum Style {
        /// 52pt boxed input on a card surface (forms, quick sheets).
        case boxed
        /// 42pt capsule input on control fill (dense control rows).
        case compactCapsule
    }

    let placeholder: String
    @Binding var text: String
    var style: Style = .boxed

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text) // ui-v4: allow canonical shared input wrapper
            .textFieldStyle(.plain) // ui-v4: allow flat input per V4 input token
            .font(style == .boxed ? OhanaFont.callout(.bold) : OhanaFont.caption(.bold))
            .foregroundStyle(Color.ohanaPrimaryText)
            .focused($isFocused)
            .padding(.horizontal, style == .boxed ? 16 : 12)
            .frame(height: style == .boxed ? 52 : 42)
            .background(surface)
            .overlay(focusBorder)
            .animation(GoMotion.stateChange, value: isFocused)
    }

    @ViewBuilder private var surface: some View {
        switch style {
        case .boxed:
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .fill(Color.ohanaCardSurface)
        case .compactCapsule:
            Capsule().fill(Color.ohanaControlFill)
        }
    }

    @ViewBuilder private var focusBorder: some View {
        let stroke = isFocused ? Color.goPrimary.opacity(0.55) : Color.ohanaCardStroke
        let width: CGFloat = isFocused ? 1.5 : 1
        switch style {
        case .boxed:
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(stroke, lineWidth: width)
        case .compactCapsule:
            Capsule().strokeBorder(stroke, lineWidth: width)
        }
    }
}
