//
//  QuickPottyDetailSheet+ActionHuman.swift
//  Ohana
//
//  Draft-scoped Human attribution for potty and litter actions.
//

import SwiftUI

extension QuickPottyDetailSheet {
    func prepareActionHumanDraft(for sheet: ActiveSheet) {
        switch sheet {
        case .pottyType, .scoopCheckIn, .litterChangeCheckIn:
            selectedActionHumanID = nil
            requiresActionHumanSelection = false
        default:
            break
        }
    }

    func validateActionHumanDraft() -> Bool {
        guard !requiresActionHumanSelection else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showSaveConfirmation(
                l.tr(
                    zh: "请先选择这次操作的执行人",
                    en: "Choose who completed this action",
                    de: "Wähle aus, wer diese Aktion erledigt hat"
                )
            )
            return false
        }
        return true
    }

    @ViewBuilder
    var pottyTypeActionSheet: some View {
        VStack(spacing: 0) {
            actionHumanPicker(tint: pottyTint)
            PottyTypeSheet(
                tint: pottyTint,
                unknownGroupTitle: sameSpeciesPottyPets.count > 1
                    ? l.tr(
                        zh: "猫砂盆未知噗噗",
                        en: "Mystery litter-box poop",
                        de: "Unbekanntes Klo-Häufchen"
                    )
                    : nil,
                onUnknownGroup: sameSpeciesPottyPets.count > 1 ? {
                    guard logUnknownGroupPotty() else { return }
                    dismissInlinePoopSheet()
                } : nil
            ) { type in
                guard logPotty(type: type) else { return }
                dismissInlinePoopSheet()
            }
        }
        .ohanaAdaptiveSheetContentHeight(
            $adaptiveSheetHeight,
            minHeight: 350,
            maxHeight: 680,
            chromePadding: 70
        )
    }

    @ViewBuilder
    var scoopCheckInActionSheet: some View {
        VStack(spacing: 12) {
            actionHumanPicker(tint: scoopTint)
            if sameSpeciesPottyPets.count > 1 {
                SharedCareTargetPicker(
                    title: l.tr(zh: "共同铲砂", en: "Scoop together", de: "Gemeinsam reinigen"),
                    subtitle: petCountText(selectedPottyTargets.count, species: pet.species),
                    pets: sameSpeciesPottyPets,
                    selectedPetIds: $selectedSharedPottyPetIds,
                    tint: scoopTint,
                    fixedPetId: pet.id
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            PoopCheckInSheet(
                tint: scoopTint,
                icon: "trash.fill",
                title: l.tr(zh: "铲砂打卡", en: "Scoop check-in", de: "Klo-Check-in"),
                value: dueText(daysUntil: daysUntilScoop),
                subtitle: scoopSubtitle,
                primaryTitle: scoopNeedsCatchUp
                    ? l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen")
                    : (todayLitterLogs.isEmpty
                        ? l.tr(zh: "完成铲砂", en: "Scoop done", de: "Klo sauber")
                        : l.tr(zh: "今天已完成", en: "Done today", de: "Heute erledigt")),
                secondaryTitle: l.tr(zh: "编辑计划", en: "Edit plan", de: "Plan ändern"),
                isPrimaryDisabled: !todayLitterLogs.isEmpty && daysUntilScoop >= 0,
                primaryAccessibilityIdentifier: "quick-potty-scoop-confirm-action",
                secondaryAccessibilityIdentifier: "quick-potty-scoop-edit-plan-action",
                primaryAction: {
                    guard recordScoop() else { return }
                    dismissInlinePoopSheet()
                },
                secondaryAction: {
                    openPottySheet(.scoopSettings)
                }
            )
        }
        .ohanaAdaptiveSheetContentHeight(
            $adaptiveSheetHeight,
            minHeight: sameSpeciesPottyPets.count > 1 ? 430 : 330,
            maxHeight: 680,
            chromePadding: 70
        )
    }

    @ViewBuilder
    var litterChangeActionSheet: some View {
        VStack(spacing: 12) {
            actionHumanPicker(tint: litterTint)
            if sameSpeciesPottyPets.count > 1 {
                SharedCareTargetPicker(
                    title: l.tr(zh: "共同换砂", en: "Change together", de: "Gemeinsam wechseln"),
                    subtitle: petCountText(selectedPottyTargets.count, species: pet.species),
                    pets: sameSpeciesPottyPets,
                    selectedPetIds: $selectedSharedPottyPetIds,
                    tint: litterTint,
                    fixedPetId: pet.id
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            PoopCheckInSheet(
                tint: litterTint,
                icon: "tray.full.fill",
                title: l.tr(zh: "换猫砂", en: "Change litter", de: "Streu wechseln"),
                value: dueText(daysUntil: daysUntilLitterChange),
                subtitle: litterChangeSubtitle,
                primaryTitle: l.tr(zh: "记录换砂", en: "Log change", de: "Wechsel loggen"),
                secondaryTitle: l.tr(zh: "编辑计划", en: "Edit plan", de: "Plan ändern"),
                isPrimaryDisabled: false,
                primaryAccessibilityIdentifier: "quick-potty-litter-confirm-action",
                secondaryAccessibilityIdentifier: "quick-potty-litter-edit-plan-action",
                primaryAction: {
                    guard doFullChange() else { return }
                    dismissInlinePoopSheet()
                },
                secondaryAction: {
                    openPottySheet(.litterSettings)
                }
            )
        }
        .ohanaAdaptiveSheetContentHeight(
            $adaptiveSheetHeight,
            minHeight: sameSpeciesPottyPets.count > 1 ? 430 : 330,
            maxHeight: 680,
            chromePadding: 70
        )
    }

    @ViewBuilder
    private func actionHumanPicker(tint: Color) -> some View {
        QuickCareActionHumanPickerContainer(
            selectedHumanID: $selectedActionHumanID,
            requiresSelection: $requiresActionHumanSelection,
            role: .executor,
            tint: tint
        )
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
