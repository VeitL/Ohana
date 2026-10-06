import SwiftUI

/// Native numeric entry with the existing locale-aware parsing contract.
struct OhanaDecimalInput: View {
    @Binding var text: String
    let countryCode: String
    var maxFractionDigits: Int = 2
    var accent: Color = .goPrimary
    var isEnabled = true
    var isMini = false
    var showsSubmitButton = true
    var onSubmit: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @FocusState private var isFocused: Bool
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(spacing: 12) {
            TextField(
                l.tr(zh: "数值", en: "Value", de: "Wert", es: "Valor", pt: "Valor", fr: "Valeur", ja: "数値", ko: "값", it: "Valore"),
                text: $text,
                prompt: Text(CountryDecimalInput.placeholder(fractionDigits: maxFractionDigits, countryCode: countryCode))
            )
            .keyboardType(maxFractionDigits == 0 ? .numberPad : .decimalPad)
            .focused($isFocused)
            .ohanaRoundedTextFieldStyle()
            .monospacedDigit()
            .accessibilityIdentifier("ohana-decimal-input")
            .onSubmit { onSubmit?() }
            if showsSubmitButton {
                Button(l.done) {
                    isFocused = false
                    onSubmit?()
                }
                .buttonStyle(.bordered)
            }
        }
        .tint(accent)
        .disabled(!isEnabled)
        .padding(.horizontal, isMini ? 0 : OhanaSpacing.pageMargin)
        .onChange(of: text) { _, value in
            let sanitized = CountryDecimalInput.sanitize(value, countryCode: countryCode, maxFractionDigits: maxFractionDigits)
            if sanitized != value { text = sanitized }
        }
    }
}
