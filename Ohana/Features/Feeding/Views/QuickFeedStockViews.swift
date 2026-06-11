//
//  QuickFeedStockViews.swift
//  Ohana
//
//  Stock management presentation pieces for the quick feeding detail flow.
//

import SwiftUI

struct QuickFeedStockCalculationModePicker: View {
    let title: String
    let modes: [FeedStockCalculationMode]
    let selectedMode: FeedStockCalculationMode
    let titleForMode: (FeedStockCalculationMode) -> String
    let subtitleForMode: (FeedStockCalculationMode) -> String
    let iconForMode: (FeedStockCalculationMode) -> String
    let tintForMode: (FeedStockCalculationMode) -> Color
    let onSelect: (FeedStockCalculationMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ForEach(modes) { mode in
                        button(for: mode)
                    }
                }
                VStack(spacing: 10) {
                    ForEach(modes) { mode in
                        button(for: mode)
                    }
                }
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }

    private func button(for mode: FeedStockCalculationMode) -> some View {
        QuickFeedStockCalculationModeButton(
            title: titleForMode(mode),
            subtitle: subtitleForMode(mode),
            icon: iconForMode(mode),
            tint: tintForMode(mode),
            isSelected: selectedMode == mode
        ) {
            onSelect(mode)
        }
    }
}

struct QuickFeedStockCalculationModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : tint)
                    .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(isSelected ? Color.arkInk.opacity(0.14) : tint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(subtitle)
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk.opacity(0.74) : Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? tint : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
    }
}

struct QuickFeedOptionalStockDateRow: View {
    let title: String
    @Binding var isOn: Bool
    @Binding var date: Date
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isOn.animation(GoMotion.feedback)) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(tint)

            if isOn {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(tint)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
    }
}

struct QuickFeedStockExpenseAmountInput: View {
    let amountTitle: String
    let optionalTitle: String
    let currencySymbol: String
    let placeholder: String
    let countryCode: String
    let tint: Color
    @Binding var amountText: String
    @Binding var isKeypadVisible: Bool
    let onToggleKeypad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(amountTitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(optionalTitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(amountText.isEmpty ? Color.ohanaTertiaryText : tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.ohanaCardSurfaceElevated, in: Capsule())
            }

            Button(action: onToggleKeypad) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(currencySymbol)
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                    Text(amountText.isEmpty ? placeholder : amountText)
                        .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(amountText.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 8)
                    Image(systemName: isKeypadVisible ? "keyboard.chevron.compact.down" : "number")
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(tint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            if isKeypadVisible {
                EmbeddedDecimalKeypad(
                    text: $amountText,
                    countryCode: countryCode,
                    maxFractionDigits: 2,
                    accent: tint,
                    isMini: true
                ) {
                    withAnimation(GoMotion.feedback) {
                        isKeypadVisible = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }
}

struct QuickFeedStockDeleteCurrentRecordCard: View {
    let title: String
    let message: String
    let isDisabled: Bool
    let onDelete: () -> Void

    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: 12) {
                Image(systemName: "trash").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                    Text(message)
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }
            .padding(14)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.input)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
    }
}

struct QuickFeedStockManagementCurrentCard: View {
    let title: String
    let subtitle: String
    let remainingDaysText: String
    let statusTint: Color
    let purchaseTitle: String
    let purchaseDate: Date
    let openTitle: String
    let openDate: Date
    let correctionText: String?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(statusTint)
                }
                Spacer()
                Text(remainingDaysText)
                    .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(statusTint)
            }

            QuickFeedStockDateLine(title: purchaseTitle, date: purchaseDate)
            QuickFeedStockDateLine(title: openTitle, date: openDate)

            if let correctionText {
                Text(correctionText)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.input)
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityAddTraits(.isButton)
    }
}

struct QuickFeedStockDateLine: View {
    let title: String
    let date: Date

    var body: some View {
        HStack {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
            Text(date.formatted(date: .numeric, time: .omitted))
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }
}

struct QuickFeedStockCorrectionCard<Keypad: View>: View {
    let title: String
    let placeholder: String
    let valueText: String
    let unitText: String
    let tint: Color
    let saveTitle: String
    let onOpenNumberPad: () -> Void
    let onSave: () -> Void
    @ViewBuilder let keypad: () -> Keypad

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onOpenNumberPad) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(valueText.isEmpty ? placeholder : valueText)
                            .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(valueText.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text(unitText)
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                        Spacer()
                        Image(systemName: "number").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(tint)
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                keypad()
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)

            FoodPrimaryButton(title: saveTitle, icon: "checkmark", tint: tint, action: onSave)
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.input)
    }
}

struct QuickFeedStockReminderManageCard: View {
    let title: String
    let pickerTitle: String
    let saveTitle: String
    let dayTitle: (Int) -> String
    let advanceOptions: [Int]
    let tint: Color
    @Binding var isEnabled: Bool
    @Binding var advanceDays: Int
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isEnabled) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(tint)

            if isEnabled {
                Picker(pickerTitle, selection: $advanceDays) {
                    ForEach(advanceOptions, id: \.self) { days in
                        Text(dayTitle(days)).tag(days)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                onSave()
            } label: {
                Label(saveTitle, systemImage: "bell.badge.fill")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.input)
    }
}
