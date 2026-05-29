import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    var guidedInlineTaskPanel: AnyView? {
        if case .modeSettings = activeEmbeddedPanel {
            return AnyView(embeddedModeSettingsPanel)
        }
        return nil
    }

    var guidedInlineTreatPanel: AnyView? {
        activeEmbeddedPanel == .treat ? AnyView(embeddedTreatPanel) : nil
    }

    @ViewBuilder
    var embeddedModeSettingsPanel: some View {
        if case .modeSettings = activeEmbeddedPanel {
            embeddedModeSettingsCard
        }
    }

    @ViewBuilder
    var embeddedTreatPanel: some View {
        if activeEmbeddedPanel == .treat {
            embeddedTreatAddCard
        }
    }

    @ViewBuilder
    var embeddedModeSettingsCard: some View {
        switch activeFeedingMode {
        case .manual:
            embeddedManualSettingsCard
        case .manualReminder:
            embeddedPlanSettingsCard(.manualReminder)
        case .autoFeeder:
            embeddedPlanSettingsCard(.autoFeeder)
        }
    }

    func toggleEmbeddedModeSettings() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.feedingOverview)
            return
        }
        dismissFeedKeyboard()
        let panel = ActiveFeedEmbeddedPanel.modeSettings(activeFeedingMode)
        if activeEmbeddedPanel == panel {
            collapseEmbeddedPanel()
            return
        }
        switch activeFeedingMode {
        case .manual:
            prepareManualSheet(settingsOnly: true)
        case .manualReminder:
            preparePlanEditorDraft(.manualReminder)
        case .autoFeeder:
            preparePlanEditorDraft(.autoFeeder)
        }
        withAnimation(GoMotion.page) {
            activeEmbeddedPanel = panel
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func toggleEmbeddedTreatAdd() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.treatOverview)
            return
        }
        dismissFeedKeyboard()
        if activeEmbeddedPanel == .treat {
            collapseEmbeddedPanel()
            return
        }
        prepareTreatSheet()
        withAnimation(GoMotion.page) {
            activeEmbeddedPanel = .treat
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func collapseEmbeddedPanel() {
        guard activeEmbeddedPanel != nil else { return }
        dismissFeedKeyboard()
        withAnimation(GoMotion.page) {
            activeEmbeddedPanel = nil
        }
    }

    var embeddedManualSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            embeddedPanelHeader(
                icon: "gearshape.fill",
                title: l.tr(zh: "手动设置", en: "Manual settings", de: "Manuelle Einstellungen"),
                tint: mainFoodTint
            )
            compactNotice(
                icon: "hand.tap.fill",
                text: l.tr(
                    zh: "设置默认粮种和克数；关闭默认后，手动模式会回到需要先设置克数的状态。",
                    en: "Set the default food and grams. Turning the default off makes manual mode ask for an amount first.",
                    de: "Standardfutter und Gramm festlegen. Ohne Standard fragt der manuelle Modus zuerst nach der Menge."
                ),
                tint: mainFoodTint
            )
            manualFoodKindSelector
            manualDefaultEnabledToggle
            if draftStore.manualDefaultEnabled {
                manualGramInput(
                    title: l.tr(zh: "默认克数", en: "Default grams", de: "Standardgramm"),
                    text: $draftStore.manualGramsText,
                    field: .manualGrams,
                    tint: mainFoodTint,
                    quickValues: quickMainGramOptions
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let inputError = draftStore.inputError {
                errorText(inputError)
            }
            FoodPrimaryButton(
                title: l.tr(zh: "保存设置", en: "Save settings", de: "Einstellungen speichern"),
                icon: "checkmark",
                tint: mainFoodTint
            ) {
                saveManualFeedSettings()
            }
        }
        .padding(16)
        .feedFlatBlockSurface(cornerRadius: 24)
    }

    func embeddedPlanSettingsCard(_ kind: FeedRuleKind) -> some View {
        let tint = kind == .manualReminder ? Color.goPurple : Color.goTeal
        let hasExistingPlan = !FeedingPlanWriter.planEvents(pet: pet, kind: kind, allEvents: allEvents).isEmpty

        return VStack(alignment: .leading, spacing: 14) {
            embeddedPanelHeader(
                icon: kind.iconName,
                title: kind == .manualReminder
                    ? l.tr(zh: "喂食计划设置", en: "Feeding plan settings", de: "Fütterungsplan einstellen")
                    : l.tr(zh: "自动猫粮机设置", en: "Auto feeder settings", de: "Futterautomat einstellen"),
                tint: tint
            )
            compactNotice(
                icon: kind.iconName,
                text: kind == .manualReminder
                    ? l.tr(zh: "每餐可独立设置时间、粮种和克数；到点后提醒你确认打卡。", en: "Each meal has its own time, food type, and grams. You will be reminded to confirm it.", de: "Jede Mahlzeit hat Zeit, Sorte und Gramm. Du wirst ans Bestätigen erinnert.")
                    : l.tr(zh: "每餐可独立设置时间、粮种和克数；到点后自动补记并扣余粮。", en: "Each meal has its own time, food type, and grams. Due meals are logged automatically.", de: "Jede Mahlzeit hat Zeit, Sorte und Gramm. Fällige Mahlzeiten werden automatisch erfasst."),
                tint: tint
            )
            if sameSpeciesFeedPets.count > 1 {
                SharedCareTargetPicker(
                    title: l.tr(zh: "目标宠物", en: "Pets", de: "Tiere"),
                    subtitle: "\(selectedPlanTargets.count)只\(pet.species)",
                    pets: sameSpeciesFeedPets,
                    selectedPetIds: $draftStore.selectedSharedPlanPetIds,
                    tint: tint
                )
            }
            planStepperCard(
                title: l.tr(zh: "每天次数", en: "Meals per day", de: "Mahlzeiten pro Tag"),
                value: "\(draftStore.planCount)",
                tint: tint
            ) {
                Stepper("", value: $draftStore.planCount, in: 1 ... 6)
                    .labelsHidden()
                    .onChange(of: draftStore.planCount) { _, newValue in
                        syncPlanTimesCount(newValue)
                    }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(l.tr(zh: "餐次", en: "Meals", de: "Mahlzeiten"))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                ForEach(Array(draftStore.planMeals.indices), id: \.self) { index in
                    embeddedPlanMealEditor(index: index, tint: tint)
                }
            }
            if let inputError = draftStore.inputError {
                errorText(inputError)
            }
            FoodPrimaryButton(
                title: draftStore.isSavingFeedPlan
                    ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                    : (kind == .manualReminder
                        ? l.tr(zh: "保存计划", en: "Save plan", de: "Plan speichern")
                        : l.tr(zh: "保存自动记录", en: "Save auto feeder", de: "Automat speichern")),
                icon: draftStore.isSavingFeedPlan ? "hourglass" : "checkmark",
                tint: tint
            ) {
                savePlan(kind)
            }
            .disabled(draftStore.isSavingFeedPlan)
            .opacity(draftStore.isSavingFeedPlan ? 0.72 : 1)
            if hasExistingPlan {
                Button(role: .destructive) {
                    deletePlan(kind)
                } label: {
                    Label(l.tr(zh: "删除当前计划", en: "Delete current plan", de: "Aktuellen Plan löschen"), systemImage: "trash")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .feedFlatBlockSurface(cornerRadius: 16)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(draftStore.isSavingFeedPlan)
                .opacity(draftStore.isSavingFeedPlan ? 0.72 : 1)
            }
        }
        .padding(16)
        .feedFlatBlockSurface(cornerRadius: 24)
    }

    func embeddedPlanMealEditor(index: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(FeedRuleMetadata.mealName(for: draftStore.planMeals[index].time), systemImage: "clock.fill")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            DatePicker(
                "",
                selection: Binding(
                    get: { draftStore.planMeals[index].time },
                    set: { draftStore.planMeals[index].time = $0 }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()

            foodKindSegmentedControl(selection: draftStore.planMeals[index].foodKind) { foodKind in
                withAnimation(GoMotion.feedback) {
                    draftStore.planMeals[index].foodKind = foodKind
                }
                UISelectionFeedbackGenerator().selectionChanged()
            }

            planMealGramEditor(index: index, tint: tint)
        }
        .padding(10)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    var embeddedTreatAddCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            embeddedPanelHeader(
                icon: "plus",
                title: l.tr(zh: "快速添加零食", en: "Quick add treat", de: "Snack schnell hinzufügen"),
                tint: treatTint
            )
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
            FoodPrimaryButton(
                title: l.tr(zh: "保存零食", en: "Save treat", de: "Snack speichern"),
                icon: "checkmark",
                tint: treatTint
            ) {
                commitTreatFeed()
            }
        }
        .padding(16)
        .feedFlatBlockSurface(cornerRadius: 24)
    }

    var manualDefaultEnabledToggle: some View {
        Toggle(isOn: $draftStore.manualDefaultEnabled.animation(GoMotion.feedback)) {
            Text(l.tr(zh: "开启默认克数", en: "Enable default grams", de: "Standardgramm aktivieren"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .tint(mainFoodTint)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    func embeddedPanelHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 40, height: 40)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 8)
            Button {
                collapseEmbeddedPanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }
}
