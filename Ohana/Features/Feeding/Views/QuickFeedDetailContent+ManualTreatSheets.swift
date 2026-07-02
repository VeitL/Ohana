import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    // MARK: - Sheets

    var manualFeedSheet: some View {
        let isSettingsOnly = draftStore.manualFeedSheetMode == .settingsOnly
        let nextReminder = overviewSnapshot.nextPendingManualReminder
        let isPlannedCompletion = !isSettingsOnly && nextReminder != nil
        let latestManualLogDate = Date()
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sheetHero(icon: "fork.knife.circle.fill", title: manualFeedSheetTitle, tint: mainFoodTint)
                if !isSettingsOnly, let reminder = nextReminder {
                    plannedReminderBanner(reminder)
                }
                if isSettingsOnly || nextReminder == nil {
                    manualFoodKindSelector
                }
                if !isSettingsOnly, nextReminder == nil, sameSpeciesFeedPets.count > 1 {
                    SharedCareTargetPicker(
                        title: l.tr(zh: "共同照护", en: "Shared care", de: "Gemeinsam"),
                        subtitle: "\(selectedFeedTargets.count)只\(pet.species)",
                        pets: sameSpeciesFeedPets,
                        selectedPetIds: $draftStore.selectedSharedFeedPetIds,
                        tint: mainFoodTint,
                        fixedPetId: pet.id
                    )
                }
                manualGramInput(
                    title: l.tr(zh: "克数", en: "Grams", de: "Gramm"),
                    text: $draftStore.manualGramsText,
                    field: .manualGrams,
                    tint: mainFoodTint,
                    quickValues: quickMainGramOptions
                )
                if !isSettingsOnly, nextReminder == nil {
                    manualFeedDatePicker(latestDate: latestManualLogDate)
                }
                if !isSettingsOnly {
                    manualDefaultToggle
                }

                if let inputError = draftStore.inputError {
                    errorText(inputError)
                }

                FoodPrimaryButton(
                    title: isSettingsOnly
                        ? l.tr(zh: "确认", en: "Confirm", de: "Bestätigen")
                        : (isPlannedCompletion ? l.tr(zh: "完成计划餐", en: "Complete planned meal", de: "Planmahlzeit erledigen") : l.tr(zh: "完成打卡", en: "Log feeding", de: "Eintragen")),
                    icon: isSettingsOnly ? "checkmark" : "checkmark.circle.fill",
                    tint: mainFoodTint
                ) {
                    if isSettingsOnly {
                        saveManualFeedSettings()
                    } else if nextReminder == nil {
                        commitManualFeed()
                    } else {
                        completeNextPlannedFeed()
                    }
                }
                .accessibilityIdentifier(isSettingsOnly
                    ? "quick-feed-manual-settings-save"
                    : (isPlannedCompletion ? "quick-feed-planned-complete" : "quick-feed-manual-log-save"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .ohanaAdaptiveSheetContentHeight(
                adaptiveSheetHeightBinding,
                minHeight: 310,
                maxHeight: 560,
                chromePadding: 66
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
    }

    var manualFeedSheetTitle: String {
        draftStore.manualFeedSheetMode == .settingsOnly
            ? l.tr(zh: "喂食设置", en: "Feeding settings", de: "Fütterung einstellen")
            : l.tr(zh: "记录喂食", en: "Log feeding", de: "Fütterung eintragen")
    }

    func manualFeedDatePicker(latestDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker(
                l.tr(zh: "时间", en: "Time", de: "Zeit"),
                selection: $draftStore.manualFeedDate,
                in: ...latestDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .tint(mainFoodTint)
            .accessibilityIdentifier("quick-feed-manual-log-date")

            #if DEBUG
                manualFeedUITestDateShortcuts(latestDate: latestDate)
            #endif
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
        .accessibilityElement(children: .contain)
    }

    #if DEBUG
        @ViewBuilder
        func manualFeedUITestDateShortcuts(latestDate: Date) -> some View {
            if isRunningQuickFeedUITests {
                HStack(spacing: 8) {
                    manualFeedUITestDateShortcut(title: "Yesterday", daysAgo: 1, latestDate: latestDate)
                    manualFeedUITestDateShortcut(title: "Two days ago", daysAgo: 2, latestDate: latestDate)
                }
            }
        }

        var isRunningQuickFeedUITests: Bool {
            let processInfo = ProcessInfo.processInfo
            let environment = processInfo.environment
            return processInfo.arguments.contains("-OHANA_UI_TESTS")
                || environment["XCTestConfigurationFilePath"] != nil
                || environment["XCTestBundlePath"] != nil
                || environment["XCTestSessionIdentifier"] != nil
        }

        func manualFeedUITestDateShortcut(title: String, daysAgo: Int, latestDate: Date) -> some View {
            Button {
                let targetDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: latestDate) ?? latestDate
                draftStore.manualFeedDate = min(targetDate, latestDate)
            } label: {
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(mainFoodTint, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("quick-feed-manual-log-date-minus-\(daysAgo)-day")
        }
    #endif

    var treatFeedSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sheetHero(icon: "birthday.cake.fill", title: l.tr(zh: "记录零食", en: "Log treats", de: "Snack eintragen"), tint: treatTint)
                treatKindPicker(selection: $draftStore.selectedTreatKind)
                gramInput(
                    title: l.tr(zh: "克数（可选）", en: "Grams (optional)", de: "Gramm (optional)"),
                    text: $draftStore.treatGramsText,
                    field: .treatGrams,
                    tint: treatTint,
                    quickValues: [5, 10, 15, 20]
                )
                if let inputError = draftStore.inputError {
                    errorText(inputError)
                }
                FoodPrimaryButton(title: l.tr(zh: "保存零食", en: "Save treat", de: "Snack speichern"), icon: "checkmark", tint: treatTint) {
                    commitTreatFeed()
                }
            }
            .padding(20)
            .ohanaAdaptiveSheetContentHeight(
                adaptiveSheetHeightBinding,
                minHeight: 330,
                maxHeight: 560,
                chromePadding: 66
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(l.tr(zh: "零食", en: "Treats", de: "Snacks"))
    }
}
