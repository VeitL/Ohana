import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    // MARK: - Sheets

    var manualFeedSheet: some View {
        let isSettingsOnly = draftStore.manualFeedSheetMode == .settingsOnly
        let nextReminder = overviewSnapshot.nextPendingManualReminder
        let latestManualLogDate = Date()
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !isSettingsOnly, let reminder = nextReminder {
                    plannedReminderBanner(reminder)
                }
                Text(pet.name).font(.headline)
                if isSettingsOnly || nextReminder == nil {
                    manualFoodKindSelector
                }
                manualGramInput(
                    title: l.tr(zh: "克数", en: "Grams", de: "Gramm"),
                    text: $draftStore.manualGramsText,
                    field: .manualGrams,
                    tint: mainFoodTint,
                    quickValues: quickMainGramOptions
                )
                if !isSettingsOnly, nextReminder == nil {
                    manualDefaultToggle
                }
                if !isSettingsOnly {
                    DisclosureGroup(PetCareExperienceCopy(l: l).moreOptions, isExpanded: $draftStore.manualMoreOptionsExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            actionHumanPicker
                            if nextReminder == nil {
                                manualFeedDatePicker(latestDate: latestManualLogDate)
                                TextField(PetCareExperienceCopy(l: l).note, text: $draftStore.manualNote, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                if sameSpeciesFeedPets.count > 1 {
                                    SharedCareTargetPicker(
                                        title: PetCareExperienceCopy(l: l).sharedCare,
                                        subtitle: "\(selectedFeedTargets.count) · \(pet.name)",
                                        pets: sameSpeciesFeedPets,
                                        selectedPetIds: $draftStore.selectedSharedFeedPetIds,
                                        tint: mainFoodTint,
                                        fixedPetId: pet.id
                                    )
                                }
                            }
                        }.padding(.top, 12)
                    }
                }

                if let inputError = draftStore.inputError {
                    errorText(inputError)
                }


            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
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
            .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .default))
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
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .default))
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
                actionHumanPicker
                    .frame(maxWidth: .infinity, alignment: .leading)
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

            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
