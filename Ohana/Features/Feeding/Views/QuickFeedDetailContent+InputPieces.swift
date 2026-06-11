import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    // MARK: - Sheet Pieces

    func foodKindPicker(selection: Binding<FeedFoodKind>) -> some View {
        foodKindSegmentedControl(selection: selection.wrappedValue) { foodKind in
            guard selection.wrappedValue != foodKind else { return }
            withAnimation(GoMotion.page) {
                selection.wrappedValue = foodKind
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    var feedModeSelector: some View {
        QuickFeedModeSelector(
            localization: l,
            selectedMode: activeFeedingMode,
            onSelect: handleFeedModeChipTap
        )
    }

    func handleFeedModeChipTap(_ mode: FeedOperatingMode) {
        if activeFeedingMode == mode {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        collapseEmbeddedPanel()
        switch mode {
        case .manual:
            switchToManualFeedMode()
        case .manualReminder:
            if feedScheduleEvents.isEmpty {
                openPlanEditor(.manualReminder)
            } else {
                activateExistingFeedRuleMode(.manualReminder)
            }
        case .autoFeeder:
            if autoFeederEvents.isEmpty {
                openPlanEditor(.autoFeeder)
            } else {
                activateExistingFeedRuleMode(.autoFeeder)
            }
        }
    }

    var mainFoodKindSelector: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                mainFoodKindLabel
                Spacer(minLength: 0)
                mainFoodKindButtons
            }
            VStack(alignment: .leading, spacing: 8) {
                mainFoodKindLabel
                mainFoodKindButtons
            }
        }
        .padding(.vertical, 2)
    }

    var mainFoodKindLabel: some View {
        Text(l.tr(zh: "当前主粮", en: "Current food", de: "Aktuelles Futter"))
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    var mainFoodKindButtons: some View {
        HStack(spacing: 8) {
            ForEach(FeedFoodKind.allCases) { foodKind in
                Button {
                    withAnimation(GoMotion.feedback) {
                        setMainFoodKind(foodKind)
                    }
                } label: {
                    Text(foodKind.title(l))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(pet.mainFoodKind == foodKind ? Color.arkInk : foodKindTint(foodKind))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            pet.mainFoodKind == foodKind ? foodKindTint(foodKind) : Color.ohanaControlFill,
                            in: Capsule()
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .animation(GoMotion.feedback, value: pet.mainFoodKind)
    }

    var manualFoodKindSelector: some View {
        foodKindSegmentedControl(selection: draftStore.manualFoodKindDraft) { foodKind in
            guard draftStore.manualFoodKindDraft != foodKind else { return }
            withAnimation(GoMotion.page) {
                draftStore.manualFoodKindDraft = foodKind
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    func foodKindSegmentedControl(
        selection: FeedFoodKind,
        setSelection: @escaping (FeedFoodKind) -> Void
    ) -> some View {
        QuickFeedFoodKindSegmentedControl(
            selection: selection,
            title: { $0.title(l) },
            tintForKind: foodKindTint,
            setSelection: setSelection
        )
    }

    func treatKindPicker(selection: Binding<FeedTreatKind>) -> some View {
        QuickFeedTreatKindPicker(
            selection: selection.wrappedValue,
            title: { $0.title(l) },
            tint: treatTint
        ) { treatKind in
            withAnimation(GoMotion.feedback) {
                selection.wrappedValue = treatKind
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    var brandSuggestionChips: some View {
        let brands = PetFoodBrandCatalog.brands(foodKind: draftStore.selectedStockFoodKind)
        let filtered = draftStore.stockBrandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? brands
            : brands.filter { $0.localizedCaseInsensitiveContains(draftStore.stockBrandText) }
        return QuickFeedBrandSuggestionChips(
            brands: Array(filtered.prefix(18)),
            tint: stockTint
        ) { brand in
            draftStore.stockBrandText = brand
            dismissFeedKeyboard()
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    func plannedReminderBanner(_ reminder: Reminder) -> some View {
        let grams = reminder.event.map {
            FeedRuleMetadata.amountGrams(from: $0, fallback: pet.dailyPortionGrams)
        } ?? pet.dailyPortionGrams
        let kindTitle = reminder.event?.foodKind.title(l) ?? FeedFoodKind.dry.title(l)
        return compactNotice(
            icon: "bell.badge.fill",
            text: l.tr(
                zh: "计划餐 \(reminder.scheduledAt.formatted(date: .omitted, time: .shortened)) · \(kindTitle) \(formattedFoodWeight(grams))",
                en: "Planned \(reminder.scheduledAt.formatted(date: .omitted, time: .shortened)) · \(kindTitle) \(formattedFoodWeight(grams))",
                de: "Geplant \(reminder.scheduledAt.formatted(date: .omitted, time: .shortened)) · \(kindTitle) \(formattedFoodWeight(grams))"
            ),
            tint: reminder.event.map { foodKindTint($0.foodKind) } ?? mainFoodTint
        )
    }

    func gramInput(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color,
        quickValues: [Double]
    ) -> some View {
        quickGramInput(title: title, text: text, field: field, tint: tint, quickValues: quickValues)
    }

    func manualGramInput(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color,
        quickValues: [Double]
    ) -> some View {
        quickGramInput(title: title, text: text, field: field, tint: tint, quickValues: quickValues)
    }

    func quickGramInput(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color,
        quickValues: [Double]
    ) -> some View {
        QuickFeedGramInput(
            title: title,
            text: text,
            tint: tint,
            onDecrease: {
                dismissFeedKeyboard()
                adjustGramText(text, delta: -5)
                UISelectionFeedbackGenerator().selectionChanged()
            },
            onIncrease: {
                dismissFeedKeyboard()
                adjustGramText(text, delta: 5)
                UISelectionFeedbackGenerator().selectionChanged()
            },
            onOpenNumberPad: {
                openFeedNumberPad(field)
            },
            keypad: {
                feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
            },
            chips: {
                quickGramChips(values: quickValues, text: text, tint: tint)
            }
        )
    }

    func gramStepButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        QuickFeedGramStepButton(systemName: systemName, tint: tint) {
            dismissFeedKeyboard()
            action()
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    func planMealGramEditor(index: Int, tint: Color) -> some View {
        let field = FeedInputField.planMealGrams(index)
        let text = planMealGramsTextBinding(index: index)
        return QuickFeedPlanMealGramEditor(
            valueText: text.wrappedValue,
            tint: tint,
            onDecrease: {
                dismissFeedKeyboard()
                adjustPlanMealGrams(index: index, delta: -5)
                UISelectionFeedbackGenerator().selectionChanged()
            },
            onIncrease: {
                dismissFeedKeyboard()
                adjustPlanMealGrams(index: index, delta: 5)
                UISelectionFeedbackGenerator().selectionChanged()
            },
            onOpenNumberPad: {
                openFeedNumberPad(field)
            },
            keypad: {
                feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
            }
        )
    }

    func adjustGramText(_ text: Binding<String>, delta: Double) {
        let current = parsePositiveDouble(text.wrappedValue) ?? 0
        let next = max(0, current + delta)
        text.wrappedValue = next > 0 ? String(format: "%.0f", next) : ""
    }

    func adjustPlanMealGrams(index: Int, delta: Double) {
        guard draftStore.planMeals.indices.contains(index) else { return }
        draftStore.planMeals[index].grams = max(0, draftStore.planMeals[index].grams + delta)
    }

    var manualDefaultToggle: some View {
        Toggle(isOn: $draftStore.saveManualAsDefault) {
            Text(l.tr(zh: "保存为默认克数", en: "Save as default", de: "Als Standard speichern"))
                .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .tint(mainFoodTint)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
    }

    func gramInputCompact(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color
    ) -> some View {
        QuickFeedGramInputCompact(
            title: title,
            text: text,
            tint: tint,
            onOpenNumberPad: {
                openFeedNumberPad(field)
            },
            keypad: {
                feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
            }
        )
    }

    func openFeedNumberPad(_ field: FeedInputField) {
        dismissSystemFeedKeyboardIfNeeded()
        draftStore.stockExpenseAmountKeypadVisible = false
        withAnimation(GoMotion.feedback) {
            focusedField = focusedField == field ? nil : field
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @ViewBuilder
    func feedInlineNumberPad(
        field: FeedInputField,
        text: Binding<String>,
        tint: Color,
        maxFractionDigits: Int
    ) -> some View {
        if focusedField == field {
            EmbeddedDecimalKeypad(
                text: text,
                countryCode: AppCountry.code,
                maxFractionDigits: maxFractionDigits,
                accent: tint,
                isMini: true
            ) {
                withAnimation(GoMotion.feedback) {
                    focusedField = nil
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
    }

    func planMealGramsTextBinding(index: Int) -> Binding<String> {
        Binding(
            get: { draftStore.planMeals.indices.contains(index) ? String(format: "%.0f", draftStore.planMeals[index].grams) : "" },
            set: { value in
                guard draftStore.planMeals.indices.contains(index) else { return }
                draftStore.planMeals[index].grams = parsePositiveDouble(value) ?? 0
            }
        )
    }

    func quickGramChips(values: [Double], text: Binding<String>, tint: Color) -> some View {
        QuickFeedQuickGramChips(
            values: values,
            title: formattedFoodWeight,
            tint: tint
        ) { value in
            dismissFeedKeyboard()
            text.wrappedValue = String(format: "%.0f", value)
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    func planStepperCard(
        title: String,
        value: String,
        tint: Color,
        @ViewBuilder control: () -> some View
    ) -> some View {
        QuickFeedPlanStepperCard(
            title: title,
            value: value,
            tint: tint,
            control: control
        )
    }

    func compactNotice(icon: String, text: String, tint: Color) -> some View {
        QuickFeedCompactNotice(icon: icon, text: text, tint: tint)
    }

    func errorText(_ text: String) -> some View {
        QuickFeedErrorText(text: text)
    }
}
