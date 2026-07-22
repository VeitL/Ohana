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
    var petSpeciesGridColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 7), count: count)
    }

    @ViewBuilder
    func petSpeciesButton(_ species: String) -> some View {
        let key = Pet.canonicalSpeciesKey(species)
        let isSelected = !draft.species.isEmpty &&
            Pet.canonicalSpeciesKey(draft.species) == key
        let button = Button {
            selectPetSpecies(species)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: Pet.speciesSilhouetteSymbol(forSpecies: species))
                    .font(OhanaFont.adaptive(size: 17, weight: .bold))
                    .accessibilityHidden(true)
                Text(speciesLabel(species))
                    .font(OhanaFont.caption2(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonBorderShape(.roundedRectangle(radius: OhanaRadius.control))
        .accessibilityIdentifier("member-pet-species-option-\(key)")
        .accessibilityLabel(speciesLabel(species))
        .accessibilityValue(
            isSelected
                ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt")
                : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])

        if isSelected {
            button
                .buttonStyle(.borderedProminent)
                .tint(cardAccent)
        } else {
            button
                .buttonStyle(.bordered)
                .tint(cardForeground)
        }
    }

    func selectPetSpecies(_ species: String) {
        let nextKey = Pet.canonicalSpeciesKey(species)
        let currentKey = draft.species.isEmpty ? "" : Pet.canonicalSpeciesKey(draft.species)
        guard currentKey != nextKey else { return }

        withAnimation(GoMotion.selection) {
            draft.species = species
            draft.isCustomSpecies = nextKey == "other"
            draft.customSpecies = ""
            draft.breed = ""
            draft.customBreed = ""
            draft.isCustomBreed = false
            draft.coatColor = ""
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func humanNameInput(width: CGFloat? = nil) -> some View {
        OhanaTextField(
            placeholder: l.tr(zh: "名字", en: "Name", de: "Name"),
            text: $draft.name,
            style: .compactCapsule
        )
        .frame(width: width, height: 44)
        .accessibilityIdentifier("member-name-input")
    }

    func compactHumanGenderGrid(
        options: [String],
        selection: Binding<String>,
        label: @escaping (String) -> String
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 150 : 92), spacing: 7)],
            spacing: 7
        ) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    withAnimation(GoMotion.selection) {
                        selection.wrappedValue = option
                    }
                    OhanaFeedback.selection()
                } label: {
                    HStack(spacing: 5) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative selected-state icon; the button exposes label, value, and selected trait
                                .accessibilityHidden(true)
                        }
                        Text(label(option))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 6)
                    .background(isSelected ? cardSelectedFill : cardControlFill, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(isSelected ? cardAccent.opacity(0.62) : cardControlStroke, lineWidth: 1)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("member-gender-\(option)")
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    func petNameInput() -> some View {
        MemberNameInputField(
            text: $draft.name,
            placeholder: l.tr(zh: "宠物名字", en: "Pet name", de: "Tiername"),
            foreground: cardForeground,
            placeholderForeground: cardSecondaryForeground
        )
        .padding(.horizontal, 10)
        .frame(maxWidth: 270)
        .frame(height: 44)
        .background(cardControlFill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(cardControlStroke, lineWidth: 1)
        }
        .shadow(color: Color.goCardWhite.opacity(0.08), radius: 10, y: 4) // ui-v4: allow member creation glass input depth
        .accessibilityIdentifier("member-name-input")
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
                .accessibilityIdentifier("member-gender-\(option)")
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
        default: ""
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
        if !draft.coatColor.isEmpty, !coats.contains(draft.coatColor) {
            draft.coatColor = ""
        }
    }

    func mediaButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(cardForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
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
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .tint(Color.goPrimary)
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
            .frame(height: 44)
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
            .frame(height: 44)
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
            .frame(height: 44)
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
