//
//  InlineNumericInput.swift
//  Ohana
//
//  Reusable native numeric entry and optional step controls.
//

import SwiftUI

struct InlineNumericInput: View {
    @Binding var text: String
    let placeholder: String
    var unit: String?
    var countryCode: String = AppCountry.code
    var maxFractionDigits: Int = 0
    var accent: Color = .goPrimary
    var accentForeground: Color = .ohanaPrimaryActionText
    var step: Double?
    var minValue: Double = 0
    var valueFont: Font = OhanaFont.title3(.semibold)
    var unitFont: Font = OhanaFont.callout(.semibold)
    var valueAlignment: Alignment = .center
    var fill: Color = .ohanaCardSurface
    var cornerRadius: CGFloat = 18
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 10
    var usesMiniKeypad = true
    var inputAccessibilityIdentifier: String?
    var decrementAccessibilityIdentifier: String?
    var incrementAccessibilityIdentifier: String?

    var body: some View {
        HStack(spacing: 10) {
            if step != nil {
                stepButton(systemName: "minus", deltaMultiplier: -1, accessibilityIdentifier: decrementAccessibilityIdentifier)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField(placeholder, text: $text)
                    .keyboardType(maxFractionDigits == 0 ? .numberPad : .decimalPad)
                    .font(valueFont)
                    .monospacedDigit()
                    .multilineTextAlignment(valueAlignment == .leading ? .leading : .center)
                    .ohanaRoundedTextFieldStyle()
                    .accessibilityLabel(unit.map { "\(placeholder) \($0)" } ?? placeholder)
                    .accessibilityIdentifier(inputAccessibilityIdentifier ?? "ohana-decimal-input")
                if let unit {
                    Text(unit).font(unitFont).foregroundStyle(accent)
                }
            }
            if step != nil {
                stepButton(systemName: "plus", deltaMultiplier: 1, accessibilityIdentifier: incrementAccessibilityIdentifier)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .tint(accent)
        .onChange(of: text) { _, value in
            let sanitized = CountryDecimalInput.sanitize(value, countryCode: countryCode, maxFractionDigits: maxFractionDigits)
            if sanitized != value { text = sanitized }
        }
    }

    private func stepButton(systemName: String, deltaMultiplier: Double, accessibilityIdentifier: String?) -> some View {
        Button {
            guard let step else { return }
            let current = CountryDecimalInput.parse(text, countryCode: countryCode) ?? 0
            let next = max(minValue, current + step * deltaMultiplier)
            text = next > minValue
                ? CountryDecimalInput.format(next, countryCode: countryCode, maxFractionDigits: maxFractionDigits)
                : ""
        } label: {
            Image(systemName: systemName)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityIdentifier(accessibilityIdentifier ?? "ohana-number-\(systemName)")
    }
}
