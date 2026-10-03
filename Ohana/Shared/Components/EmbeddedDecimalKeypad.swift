//
//  EmbeddedDecimalKeypad.swift
//  Ohana
//
//  Sheet-native decimal keypad for short numeric entry.
//

import SwiftUI

struct EmbeddedDecimalKeypad: View {
    @Binding var text: String
    let countryCode: String
    var maxFractionDigits: Int = 2
    var accent: Color = .goPrimary
    var isEnabled: Bool = true
    var isMini: Bool = false
    var showsSubmitButton: Bool = true
    var onSubmit: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "decimal", "0", "delete"]

    private var gridSpacing: CGFloat { isMini ? 5 : 7 }
    private var keyHeight: CGFloat { 44 }
    private var keyCornerRadius: CGFloat { isMini ? 10 : 14 }
    private var horizontalPadding: CGFloat { isMini ? 0 : 20 }

    private var decimalSeparator: String {
        CountryDecimalInput.decimalSeparator(for: countryCode)
    }

    var body: some View {
        VStack(spacing: gridSpacing) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3), spacing: gridSpacing) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        press(key)
                    } label: {
                        keyContent(key)
                            .frame(maxWidth: .infinity)
                            .frame(height: keyHeight)
                            .background(keyBackground(key), in: RoundedRectangle(cornerRadius: keyCornerRadius, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!isEnabled || (key == "decimal" && maxFractionDigits == 0))
                    .opacity((key == "decimal" && maxFractionDigits == 0) ? 0.28 : 1)
                    .accessibilityLabel(keyAccessibilityLabel(key))
                    .accessibilityHint(key == "delete" ? deleteAccessibilityHint : "")
                    .accessibilityIdentifier("embedded-decimal-keypad-key-\(key)")
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                            if key == "delete" {
                                clear()
                            }
                        }
                    )
                }
            }

            if showsSubmitButton {
                Button {
                    onSubmit?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard.chevron.compact.down").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                        Text("OK")
                            .font(OhanaFont.caption(.black))
                    }
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!isEnabled)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, isMini ? 2 : 6)
        .padding(.bottom, isMini ? 0 : 10)
        .background(isMini ? Color.clear : Color.ohanaCardSurface)
    }

    @ViewBuilder
    private func keyContent(_ key: String) -> some View {
        if key == "delete" {
            Image(systemName: "delete.left.fill").accessibilityHidden(true)
                .font(.system(size: isMini ? 13 : 17, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryText)
        } else {
            Text(key == "decimal" ? decimalSeparator : key)
                .font(isMini ? OhanaFont.subheadline(.black) : OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    private func keyBackground(_ key: String) -> Color {
        if key == "decimal" {
            return Color.ohanaCardSurfaceElevated
        }
        if key == "delete" {
            return Color.ohanaCardSurfaceElevated
        }
        return Color.ohanaCardSurfaceElevated
    }

    private func keyAccessibilityLabel(_ key: String) -> String {
        let l = L10n(appLanguage)
        return switch key {
        case "delete":
            l.tr(
                zh: "删除", en: "Delete", de: "Löschen",
                es: "Borrar", pt: "Apagar", fr: "Effacer",
                ja: "削除", ko: "삭제", it: "Elimina"
            )
        case "decimal":
            l.tr(
                zh: "小数点", en: "Decimal separator", de: "Dezimaltrennzeichen",
                es: "Separador decimal", pt: "Separador decimal", fr: "Séparateur décimal",
                ja: "小数点", ko: "소수점", it: "Separatore decimale"
            )
        default:
            key
        }
    }

    private var deleteAccessibilityHint: String {
        L10n(appLanguage).tr(
            zh: "长按清空", en: "Touch and hold to clear", de: "Zum Leeren gedrückt halten",
            es: "Mantén pulsado para borrar todo", pt: "Mantenha premido para limpar",
            fr: "Maintenez pour tout effacer", ja: "長押しですべて消去",
            ko: "길게 눌러 모두 지우기", it: "Tieni premuto per cancellare tutto"
        )
    }

    private func press(_ key: String) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        switch key {
        case "delete":
            if !text.isEmpty {
                text.removeLast()
            }
        case "decimal":
            guard maxFractionDigits > 0 else { return }
            if !text.contains("."), !text.contains(",") {
                text = text.isEmpty ? "0\(decimalSeparator)" : text + decimalSeparator
            }
        default:
            text.append(key)
        }

        text = CountryDecimalInput.sanitize(
            text,
            countryCode: countryCode,
            maxFractionDigits: maxFractionDigits
        )
    }

    private func clear() {
        guard isEnabled, !text.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        text = ""
    }
}
