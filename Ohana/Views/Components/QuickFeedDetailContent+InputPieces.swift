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
            .font(.system(size: 12, weight: .black, design: .rounded))
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
                        .font(.system(size: 12, weight: .black, design: .rounded))
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
        GeometryReader { proxy in
            let spacing = CGFloat(10)
            let options = FeedFoodKind.allCases
            let selectedIndex = options.firstIndex(of: selection) ?? 0
            let segmentWidth = max(0, (proxy.size.width - spacing) / 2)
            let selectedTint = foodKindTint(selection)

            ZStack(alignment: .leading) {
                HStack(spacing: spacing) {
                    ForEach(options) { _ in
                        Capsule()
                            .fill(Color.ohanaControlFill.opacity(0.82))
                            .frame(width: segmentWidth, height: 46)
                    }
                }

                Capsule()
                    .fill(selectedTint)
                    .frame(width: segmentWidth, height: 46)
                    .offset(x: CGFloat(selectedIndex) * (segmentWidth + spacing))
                    .shadow(color: selectedTint.opacity(0.20), radius: 10, y: 5) // ui-v4: allow stable local segmented-control lift
                    .animation(GoMotion.page, value: selection)

                HStack(spacing: spacing) {
                    ForEach(options) { foodKind in
                        Button {
                            setSelection(foodKind)
                        } label: {
                            Text(foodKind.title(l))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(selection == foodKind ? Color.arkInk : foodKindTint(foodKind))
                                .contentTransition(.opacity)
                                .frame(width: segmentWidth, height: 46)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .frame(height: 46)
    }

    func treatKindPicker(selection: Binding<FeedTreatKind>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(FeedTreatKind.allCases) { treatKind in
                Button {
                    withAnimation(GoMotion.feedback) {
                        selection.wrappedValue = treatKind
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(treatKind.title(l), systemImage: treatKind.systemIconName)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(selection.wrappedValue == treatKind ? Color.arkInk : treatTint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection.wrappedValue == treatKind ? treatTint : treatTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    var brandSuggestionChips: some View {
        let brands = PetFoodBrandCatalog.brands(foodKind: draftStore.selectedStockFoodKind)
        let filtered = draftStore.stockBrandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? brands
            : brands.filter { $0.localizedCaseInsensitiveContains(draftStore.stockBrandText) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(filtered.prefix(18)), id: \.self) { brand in
                    Button {
                        draftStore.stockBrandText = brand
                        dismissFeedKeyboard()
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(brand)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(stockTint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(stockTint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
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
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 10) {
                gramStepButton(systemName: "minus", tint: tint) {
                    adjustGramText(text, delta: -5)
                }
                Button {
                    openFeedNumberPad(field)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(text.wrappedValue.isEmpty ? "50" : text.wrappedValue)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(text.wrappedValue.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text("g")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
                gramStepButton(systemName: "plus", tint: tint) {
                    adjustGramText(text, delta: 5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .feedFlatBlockSurface(cornerRadius: 18)

            feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
            quickGramChips(values: quickValues, text: text, tint: tint)
        }
    }

    func gramStepButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            dismissFeedKeyboard()
            action()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(tint, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(.isButton)
    }

    func planMealGramEditor(index: Int, tint: Color) -> some View {
        let field = FeedInputField.planMealGrams(index)
        let text = planMealGramsTextBinding(index: index)
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                gramStepButton(systemName: "minus", tint: tint) {
                    adjustPlanMealGrams(index: index, delta: -5)
                }
                Button {
                    openFeedNumberPad(field)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(text.wrappedValue.isEmpty ? "50" : text.wrappedValue)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(text.wrappedValue.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text("g")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
                gramStepButton(systemName: "plus", tint: tint) {
                    adjustPlanMealGrams(index: index, delta: 5)
                }
            }
            feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
        }
        .padding(10)
        .feedFlatBlockSurface(cornerRadius: 14)
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
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .tint(mainFoodTint)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    func gramInputCompact(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 5) {
                Button {
                    openFeedNumberPad(field)
                } label: {
                    Text(text.wrappedValue.isEmpty ? "50" : text.wrappedValue)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(text.wrappedValue.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ScaleButtonStyle())
                Text("g")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 16)
            feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button {
                        dismissFeedKeyboard()
                        text.wrappedValue = String(format: "%.0f", value)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(formattedFoodWeight(value))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    func planStepperCard<Control: View>(
        title: String,
        value: String,
        tint: Color,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack {
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                control()
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func compactNotice(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    func errorText(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.goRed)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 14)
    }
}
