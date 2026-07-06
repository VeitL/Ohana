//
//  MemberCardCreationContentView+Controls.swift
//  Ohana
//

import AVFoundation
import Combine
import ImageIO
import os
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

extension MemberCardCreationContentView {
    func humanNameInput(width: CGFloat) -> some View {
        OhanaTextField(
            placeholder: l.tr(zh: "名字", en: "Name", de: "Name"),
            text: $draft.name,
            style: .compactCapsule
        )
        .frame(width: width, height: 44)
        .accessibilityIdentifier("member-name-input")
    }

    func compactNameInput(width: CGFloat) -> some View {
        MemberNameInputField(
            text: $draft.name,
            placeholder: kind == .pet
                ? l.tr(zh: "名字", en: "Name", de: "Name")
                : l.tr(zh: "名字", en: "Name", de: "Name"),
            foreground: cardForeground,
            placeholderForeground: cardSecondaryForeground
        )
        .padding(.horizontal, 12)
        .frame(width: width, height: 44)
        .background(cardControlFill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(cardControlStroke, lineWidth: 1)
        }
        .shadow(color: Color.goCardWhite.opacity(0.08), radius: 10, y: 4) // ui-v4: allow member creation glass input depth
    }

    func compactOptionRow(options: [String], selection: Binding<String>, label: @escaping (String) -> String) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    withAnimation(GoMotion.selection) {
                        selection.wrappedValue = option
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(label(option))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.54)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isSelected ? cardSelectedFill : cardControlFill, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(isSelected ? cardAccent.opacity(0.62) : cardControlStroke, lineWidth: 1)
                        }
                        .shadow(color: isSelected ? cardAccent.opacity(0.30) : Color.clear, radius: 12, y: 4) // ui-v4: allow selected glass control glow
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    func compactGenderIconRow(
        options: [String],
        selection: Binding<String>,
        label: @escaping (String) -> String,
        icon: @escaping (String) -> String
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    withAnimation(GoMotion.selection) {
                        selection.wrappedValue = option
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(icon(option))
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isSelected ? cardSelectedFill : cardControlFill, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(isSelected ? cardAccent.opacity(0.62) : cardControlStroke, lineWidth: 1)
                        }
                        .shadow(color: isSelected ? cardAccent.opacity(0.30) : Color.clear, radius: 12, y: 4) // ui-v4: allow selected glass control glow
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    func petGenderIcon(_ gender: String) -> String {
        switch gender {
        case "boy", "male", "男": "♂"
        case "girl", "female", "女": "♀"
        default: "?"
        }
    }

    func humanGenderIcon(_ gender: String) -> String {
        switch HumanProfileOptions.normalizedGender(gender) {
        case "男": "♂"
        case "女": "♀"
        default: "?"
        }
    }

    func compactHumanMetricInput(
        title: String,
        text: Binding<String>,
        placeholder: String,
        unit: String,
        maxFractionDigits: Int,
        inputAccessibilityIdentifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(cardSecondaryForeground)
            InlineNumericInput(
                text: text,
                placeholder: placeholder,
                unit: unit,
                countryCode: appCountry,
                maxFractionDigits: maxFractionDigits,
                accent: Color.goPrimary,
                valueFont: OhanaFont.callout(.black),
                unitFont: OhanaFont.caption2(.black),
                fill: cardControlFill,
                cornerRadius: OhanaRadius.input,
                horizontalPadding: 10,
                verticalPadding: 8,
                usesMiniKeypad: true,
                inputAccessibilityIdentifier: inputAccessibilityIdentifier
            )
        }
        .frame(maxWidth: .infinity)
    }

    var privacyPillGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 7)], spacing: 7) {
            privacyPill(title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"), icon: "scalemass", isOn: $draft.privateWeight)
            privacyPill(title: l.tr(zh: "运动", en: "Workout", de: "Training"), icon: "figure.run", isOn: $draft.privateWorkout)
            privacyPill(title: l.tr(zh: "用药", en: "Meds", de: "Medizin"), icon: "pills.fill", isOn: $draft.privateMedication)
            privacyPill(title: l.tr(zh: "愿望", en: "Wish", de: "Wunsch"), icon: "sparkle", isOn: $draft.privateWishlist)
            privacyPill(title: l.tr(zh: "消费", en: "Expense", de: "Kosten"), icon: "creditcard.fill", isOn: $draft.privateExpense)
        }
    }

    func privacyPill(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        compactTogglePill(title: title, icon: icon, isOn: isOn)
    }

    func humanMetricInput(
        title: String,
        text: Binding<String>,
        placeholder: String,
        unit: String,
        maxFractionDigits: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(cardSecondaryForeground)
            InlineNumericInput(
                text: text,
                placeholder: placeholder,
                unit: unit,
                countryCode: appCountry,
                maxFractionDigits: maxFractionDigits,
                accent: Color.goPrimary,
                valueFont: OhanaFont.title3(.black),
                unitFont: OhanaFont.caption(.black),
                fill: cardControlFill,
                cornerRadius: OhanaRadius.cardSoft,
                horizontalPadding: 12,
                verticalPadding: 8,
                usesMiniKeypad: true
            )
        }
    }

    func clampPetAppearance() {
        guard kind == .pet else { return }
        let coats = petCoatOptions
        if !coats.isEmpty, !coats.contains(draft.coatColor) {
            draft.coatColor = coats[0]
        }
        let eyes = petEyeOptions
        if !eyes.isEmpty, !eyes.contains(draft.eyeColor) {
            draft.eyeColor = eyes[0]
        }
    }

    func mediaButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(cardForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(cardControlFill, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(cardControlStroke, lineWidth: 1)
                }
                .shadow(color: Color.goCardWhite.opacity(0.07), radius: 9, y: 3) // ui-v4: allow member creation glass media control depth
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func compactTogglePill(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(GoMotion.selection) {
                isOn.wrappedValue.toggle()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(isOn.wrappedValue ? cardSelectedForeground : cardForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isOn.wrappedValue ? cardSelectedFill : cardControlFill, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isOn.wrappedValue ? cardAccent.opacity(0.58) : cardControlStroke, lineWidth: 1)
                }
                .shadow(color: isOn.wrappedValue ? cardAccent.opacity(0.26) : Color.clear, radius: 10, y: 4) // ui-v4: allow selected glass control glow
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func statusPill(text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(tint.mix(with: .white, by: 0.84), in: Capsule())
    }

    func flatTextField(_ title: String, text: Binding<String>) -> some View { // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            .textInputAutocapitalization(.words)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(cardForeground)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(cardControlFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(cardControlStroke, lineWidth: 1)
            }
    }

    func menuPicker(title: String, value: String, @ViewBuilder content: () -> some View) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(cardSecondaryForeground)
                Spacer()
                Text(value)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(cardForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Image(systemName: "chevron.up.chevron.down").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 10, weight: .black))
                    .foregroundStyle(cardSecondaryForeground)
            }
            .frame(height: 42)
            .padding(.horizontal, 12)
            .background(cardControlFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(cardControlStroke, lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func compactMenuPicker(title: String, value: String, @ViewBuilder content: () -> some View) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(cardSecondaryForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 4)
                Text(value)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(cardForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Image(systemName: "chevron.up.chevron.down").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 9, weight: .black))
                    .foregroundStyle(cardSecondaryForeground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .padding(.horizontal, 12)
            .background(cardControlFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(cardControlStroke, lineWidth: 1)
            }
            .shadow(color: Color.goCardWhite.opacity(0.07), radius: 9, y: 3) // ui-v4: allow member creation glass picker depth
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func chipRow(options: [String], selection: Binding<String>, label: @escaping (String) -> String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue == option || draft.personalityTagIds.contains(option)
                    Button {
                        withAnimation(GoMotion.selection) {
                            selection.wrappedValue = option
                        }
                    } label: {
                        Text(label(option))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
}
