//
//  InlineNumericInput.swift
//  Ohana
//
//  Reusable in-page numeric input. Keeps simple number entry out of the system keyboard.
//

import SwiftUI

struct InlineNumericInput: View {
    @Binding var text: String
    let placeholder: String
    var unit: String?
    var countryCode: String = AppCountry.code
    var maxFractionDigits: Int = 0
    var accent: Color = .goPrimary
    var step: Double?
    var minValue: Double = 0
    var valueFont: Font = OhanaFont.title3(.black)
    var unitFont: Font = OhanaFont.callout(.black)
    var valueAlignment: Alignment = .center
    var fill: Color = .ohanaCardSurface
    var cornerRadius: CGFloat = 18
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 10
    var usesMiniKeypad = true

    @State private var showsKeypad = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if step != nil {
                    stepButton(systemName: "minus", deltaMultiplier: -1)
                }

                Button {
                    GoKeyboard.dismiss()
                    withAnimation(GoMotion.feedback) {
                        showsKeypad.toggle()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(text.isEmpty ? placeholder : text)
                            .font(valueFont)
                            .foregroundStyle(text.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        if let unit {
                            Text(unit)
                                .font(unitFont)
                                .foregroundStyle(accent)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: valueAlignment)
                }
                .buttonStyle(ScaleButtonStyle())

                if step != nil {
                    stepButton(systemName: "plus", deltaMultiplier: 1)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            if showsKeypad {
                EmbeddedDecimalKeypad(
                    text: $text,
                    countryCode: countryCode,
                    maxFractionDigits: maxFractionDigits,
                    accent: accent,
                    isMini: usesMiniKeypad
                ) {
                    withAnimation(GoMotion.feedback) {
                        showsKeypad = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    private func stepButton(systemName: String, deltaMultiplier: Double) -> some View {
        Button {
            guard let step else { return }
            let current = CountryDecimalInput.parse(text, countryCode: countryCode) ?? 0
            let next = max(minValue, current + step * deltaMultiplier)
            text = next > minValue
                ? CountryDecimalInput.format(next, countryCode: countryCode, maxFractionDigits: maxFractionDigits)
                : ""
            showsKeypad = false
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Image(systemName: systemName)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(accent, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
