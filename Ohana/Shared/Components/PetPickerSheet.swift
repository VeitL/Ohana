//
//  PetPickerSheet.swift
//  Ohana
//
//  T3: Quick Access 先选宠物再执行动作
//

import SwiftData
import SwiftUI

struct PetPickerSheet: View {
    let pets: [Pet]
    let actionId: String
    let onSelect: (Pet) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    private var actionTitle: String {
        switch actionId {
        case "walk": l.tr(zh: "选择要遛的狗", en: "Choose a dog to walk", de: "Hund fuer Spaziergang waehlen")
        case "health": l.tr(zh: "选择宠物查看健康", en: "Choose a pet for health", de: "Haustier fuer Gesundheit waehlen")
        case "groom": l.tr(zh: "选择要护理的宠物", en: "Choose a pet to groom", de: "Haustier fuer Pflege waehlen")
        case "potty": l.tr(zh: "选择宠物记录排泄", en: "Choose a pet for potty", de: "Haustier fuer Kot-Eintrag waehlen")
        default: l.tr(zh: "选择宠物", en: "Choose a pet", de: "Haustier waehlen")
        }
    }

    private var actionEmoji: String {
        switch actionId {
        case "walk": "🦮"
        case "health": "❤️"
        case "groom": "✂️"
        case "potty": "💩"
        default: "🐾"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 40, height: 4) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .padding(.top, 12)
                .padding(.bottom, 20)

            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Text(actionEmoji)
                        .font(OhanaFont.adaptive(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle)
                            .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "选择一只宠物继续", en: "Choose one pet to continue", de: "Waehle ein Haustier zum Fortfahren"))
                            .font(OhanaFont.adaptive(size: 14, weight: .medium))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    ForEach(pets) { pet in
                        Button {
                            onSelect(pet)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                // 头像
                                PetAvatarPortraitView(
                                    pet: pet,
                                    fallbackText: pet.species == "狗" ? "🐶" : pet.species == "猫" ? "🐱" : "🐾",
                                    themeColor: Color(hex: pet.safeThemeColorHex),
                                    size: 52,
                                    backgroundOpacity: 0.2
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pet.name)
                                        .font(OhanaFont.adaptive(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                    Text(pet.localizedSpeciesBreedSummary(l: l))
                                        .font(OhanaFont.adaptive(size: 13, weight: .medium))
                                        .foregroundStyle(Color.ohanaSecondaryText)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right").accessibilityHidden(true)
                                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: OhanaRadius.control))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 40)
        }
        .background(OhanaAppBackground())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}
