//
//  AddPlantView+ConfirmationStep.swift
//  Ohana
//
//  Step 4: review and add.
//

import SwiftUI

extension AddPlantView {
    var plantConfirmationStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            plantMiniHeader

            PlantCreationSection(
                title: l.tr(zh: "确认信息", en: "Review", de: "Prüfen"),
                icon: "checkmark.seal.fill"
            ) {
                VStack(spacing: 8) {
                    plantConfirmationRow(
                        icon: "leaf.fill",
                        title: l.tr(zh: "植物", en: "Plant", de: "Pflanze"),
                        value: "\(resolvedPlantName) · \(profilePreviewSpecies)",
                        targetStep: .plant
                    )
                    plantConfirmationRow(
                        icon: "house.fill",
                        title: l.tr(zh: "房间", en: "Room", de: "Raum"),
                        value: plantPlacementSummary,
                        targetStep: .plant
                    )
                    plantConfirmationRow(
                        icon: selectedAvatarSource == .customImage ? "photo.fill" : "leaf.circle.fill",
                        title: l.tr(zh: "头像", en: "Avatar", de: "Avatar"),
                        value: plantAvatarStatusText,
                        targetStep: .avatar
                    )
                    plantConfirmationRow(
                        icon: "drop.fill",
                        title: l.tr(zh: "Water", en: "Water", de: "Wasser"),
                        value: l.tr(zh: "每 \(wateringInterval) 天", en: "Every \(wateringInterval) days", de: "Alle \(wateringInterval) Tage"),
                        targetStep: .care
                    )
                    plantConfirmationRow(
                        icon: "sun.max.fill",
                        title: l.tr(zh: "Light / humidity", en: "Light / humidity", de: "Licht / Feuchte"),
                        value: "\(lightLevel.displayName) · \(humidityPreference.displayName)",
                        targetStep: .care
                    )
                    plantConfirmationRow(
                        icon: "leaf.fill",
                        title: l.tr(zh: "Fertilizing", en: "Fertilizing", de: "Düngen"),
                        value: l.tr(zh: "每 \(fertilizingInterval) 天", en: "Every \(fertilizingInterval) days", de: "Alle \(fertilizingInterval) Tage"),
                        targetStep: .care
                    )
                    plantConfirmationRow(
                        icon: "exclamationmark.triangle.fill",
                        title: l.tr(zh: "Toxicity", en: "Toxicity", de: "Giftigkeit"),
                        value: toxicitySummary,
                        targetStep: .care
                    )
                }
            }

            duplicateWarningSection

            PlantCreationInfoRow(
                icon: "bell.badge.fill",
                title: l.tr(zh: "植物提醒", en: "Plant reminders", de: "Pflanzenerinnerungen"),
                subtitle: l.tr(zh: "添加后会根据这些信息生成本地护理计划。", en: "After adding, Ohana generates local care plans from this info.", de: "Nach dem Hinzufügen erzeugt Ohana lokale Pflegepläne aus diesen Infos.")
            ) {
                Toggle(l.tr(zh: "开启提醒", en: "Enable reminders", de: "Erinnerungen aktivieren"), isOn: $remindersEnabled)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .tint(Color.goPrimary)
            }
        }
        .overlay(alignment: .topLeading) {
            PlantCreationAccessibilityMarker(identifier: "add-plant-step-confirm")
        }
    }

    var plantPlacementSummary: String {
        let room = trimmedRoomName.isEmpty ? l.tr(zh: "未设置房间", en: "No room", de: "Kein Raum") : trimmedRoomName
        guard !trimmedLocation.isEmpty else { return room }
        return "\(room) · \(trimmedLocation)"
    }

    var toxicitySummary: String {
        var risks: [String] = []
        if isToxicToCats { risks.append(l.tr(zh: "猫", en: "cats", de: "Katzen")) }
        if isToxicToDogs { risks.append(l.tr(zh: "狗", en: "dogs", de: "Hunde")) }
        if isToxicToChildren { risks.append(l.tr(zh: "儿童", en: "children", de: "Kinder")) }
        if risks.isEmpty {
            return l.tr(zh: "低风险", en: "Low risk", de: "Geringes Risiko")
        }
        return l.tr(
            zh: "注意 \(risks.joined(separator: "、"))",
            en: "Watch \(risks.joined(separator: ", "))",
            de: "Achtung: \(risks.joined(separator: ", "))"
        )
    }

    func plantConfirmationRow(
        icon: String,
        title: String,
        value: String,
        targetStep: AddPlantCreationStep
    ) -> some View {
        Button {
            withAnimation(GoMotion.selection) {
                currentStep = targetStep
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 28, height: 28) // a11y: allow decorative row glyph; the full review row button owns the 44pt hit target.
                    .background(Color.goTeal.opacity(0.13), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                    Text(value)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 8)
                Image(systemName: "pencil") // a11y: allow decorative edit affordance; row text labels the edit target.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ohanaControlFill.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(title), \(value)")
    }
}
