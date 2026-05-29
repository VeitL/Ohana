import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    var stockSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sheetHero(
                    icon: "shippingbox.fill",
                    title: draftStore.editingFoodRecord == nil
                        ? l.tr(zh: "补粮", en: "Restock", de: "Nachfüllen")
                        : l.tr(zh: "修改余粮", en: "Edit stock", de: "Vorrat bearbeiten"),
                    tint: stockTint
                )
                foodKindPicker(selection: $draftStore.selectedStockFoodKind)
                stockCalculationModePicker
                VStack(spacing: 12) {
                    TextField(l.tr(zh: "品牌，可选", en: "Brand, optional", de: "Marke, optional"), text: $draftStore.stockBrandText)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .stockBrand)
                        .feedingTextFieldStyle(tint: stockTint)
                    brandSuggestionChips
                    gramInput(
                        title: l.tr(zh: "总重量", en: "Total weight", de: "Gesamtgewicht"),
                        text: $draftStore.stockWeightText,
                        field: .stockWeight,
                        tint: stockTint,
                        quickValues: [1000, 1500, 2000, 4000]
                    )
                    optionalStockDateRow(
                        title: l.tr(zh: "购买日期", en: "Purchase date", de: "Kaufdatum"),
                        isOn: $draftStore.stockHasPurchaseDate,
                        date: $draftStore.stockPurchaseDate
                    )
                    stockExpenseOptions
                    optionalStockDateRow(
                        title: l.tr(zh: "开袋日期", en: "Open date", de: "Öffnungsdatum"),
                        isOn: $draftStore.stockHasOpenDate,
                        date: $draftStore.stockOpenDate
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $draftStore.stockReminderEnabled) {
                        Text(l.tr(zh: "低余粮提醒", en: "Low stock reminder", de: "Vorrats-Erinnerung"))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .tint(stockTint)

                    if draftStore.stockReminderEnabled {
                        Picker(l.tr(zh: "提前", en: "Advance", de: "Vorher"), selection: $draftStore.stockReminderAdvanceDays) {
                            ForEach(stockReminderAdvanceOptions, id: \.self) { days in
                                Text("\(days) \(l.tr(zh: "天", en: "days", de: "Tage"))").tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(14)
                .feedFlatBlockSurface(cornerRadius: 18)

                if let inputError = draftStore.inputError {
                    errorText(inputError)
                }
            }
            .padding(18)
            .padding(.bottom, 88)
            .ohanaAdaptiveSheetContentHeight(
                adaptiveSheetHeightBinding,
                minHeight: 620,
                maxHeight: 820,
                chromePadding: 112
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stockSheetFooter
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: draftStore.selectedStockFoodKind) { _, _ in
            guard draftStore.editingFoodRecord == nil else { return }
            draftStore.stockBrandText = ""
            draftStore.stockWeightText = ""
            draftStore.stockHasPurchaseDate = false
            draftStore.stockPurchaseDate = Date()
            draftStore.stockHasOpenDate = false
            draftStore.stockOpenDate = Date()
            configureStockExpenseFields(for: nil)
            draftStore.stockExpenseAmountKeypadVisible = false
        }
        .navigationTitle(l.tr(zh: "余粮", en: "Stock", de: "Vorrat"))
    }

    var stockCalculationModePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "粮仓计算", en: "Stock calculation", de: "Vorratsberechnung"))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ForEach(FeedStockCalculationMode.allCases) { mode in
                        stockCalculationModeButton(mode)
                    }
                }
                VStack(spacing: 10) {
                    ForEach(FeedStockCalculationMode.allCases) { mode in
                        stockCalculationModeButton(mode)
                    }
                }
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    func stockCalculationModeButton(_ mode: FeedStockCalculationMode) -> some View {
        let isSelected = draftStore.stockCalculationMode == mode
        let tint = stockCalculationModeTint(mode)
        return Button {
            guard draftStore.stockCalculationMode != mode else {
                UISelectionFeedbackGenerator().selectionChanged()
                return
            }
            withAnimation(GoMotion.feedback) {
                draftStore.stockCalculationMode = mode
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: stockCalculationModeIcon(mode))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : tint)
                    .frame(width: 28, height: 28)
                    .background(isSelected ? Color.arkInk.opacity(0.14) : tint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(stockCalculationModeTitle(mode))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(stockCalculationModeSubtitle(mode))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk.opacity(0.74) : Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? tint : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(stockCalculationModeTitle(mode))
    }

    func stockCalculationModeTitle(_ mode: FeedStockCalculationMode) -> String {
        switch mode {
        case .manualOrPlan:
            return l.tr(zh: "手动/计划", en: "Manual/Plan", de: "Manuell/Plan")
        case .autoFeeder:
            return l.tr(zh: "自动模式", en: "Auto mode", de: "Automatik")
        }
    }

    func stockCalculationModeSubtitle(_ mode: FeedStockCalculationMode) -> String {
        switch mode {
        case .manualOrPlan:
            return l.tr(zh: "按打卡扣粮", en: "Logged meals", de: "Einträge")
        case .autoFeeder:
            return l.tr(zh: "按自动扣粮", en: "Auto deduct", de: "Auto-Abzug")
        }
    }

    func stockCalculationModeIcon(_ mode: FeedStockCalculationMode) -> String {
        switch mode {
        case .manualOrPlan: return "hand.tap.fill"
        case .autoFeeder: return "dot.radiowaves.left.and.right"
        }
    }

    func stockCalculationModeTint(_ mode: FeedStockCalculationMode) -> Color {
        switch mode {
        case .manualOrPlan: return Color.goPurple
        case .autoFeeder: return Color.goTeal
        }
    }

    var stockSheetFooter: some View {
        VStack(spacing: 0) {
            FoodPrimaryButton(
                title: draftStore.editingFoodRecord == nil
                    ? l.tr(zh: "保存补粮", en: "Save restock", de: "Speichern")
                    : l.tr(zh: "保存修改", en: "Save changes", de: "Änderungen speichern"),
                icon: "checkmark",
                tint: stockTint
            ) {
                saveStock()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background {
            LinearGradient(
                colors: [
                    Color.ohanaCardSurface.opacity(0.02),
                    Color.ohanaCardSurface.opacity(0.62),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }

    func optionalStockDateRow(title: String, isOn: Binding<Bool>, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: isOn.animation(GoMotion.feedback)) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(stockTint)

            if isOn.wrappedValue {
                DatePicker("", selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(stockTint)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    var stockExpenseOptions: some View {
        VStack(spacing: 10) {
            HStack {
                Text(l.tr(zh: "支付人", en: "Payer", de: "Zahlende Person"))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Menu {
                    Button(l.tr(zh: "未指定", en: "Unspecified", de: "Nicht angegeben")) {
                        draftStore.stockExpensePayerId = nil
                    }
                    ForEach(allHumans) { human in
                        Button(human.name) {
                            draftStore.stockExpensePayerId = human.id.uuidString
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(stockExpensePayerName)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundStyle(stockTint)
                }
            }

            stockExpenseAmountInput
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    var stockExpenseAmountInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(l.tr(zh: "金额", en: "Amount", de: "Betrag"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(l.tr(zh: "可选", en: "Optional", de: "Optional"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(draftStore.stockExpenseAmountText.isEmpty ? Color.ohanaTertiaryText : stockTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.ohanaCardSurfaceElevated, in: Capsule())
            }

            Button {
                dismissSystemFeedKeyboardIfNeeded()
                focusedField = nil
                withAnimation(GoMotion.feedback) {
                    draftStore.stockExpenseAmountKeypadVisible.toggle()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(AppCurrency.symbol)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(stockTint)
                    Text(draftStore.stockExpenseAmountText.isEmpty ? CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code) : draftStore.stockExpenseAmountText)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(draftStore.stockExpenseAmountText.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 8)
                    Image(systemName: draftStore.stockExpenseAmountKeypadVisible ? "keyboard.chevron.compact.down" : "number")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(stockTint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            if draftStore.stockExpenseAmountKeypadVisible {
                EmbeddedDecimalKeypad(
                    text: $draftStore.stockExpenseAmountText,
                    countryCode: AppCountry.code,
                    maxFractionDigits: 2,
                    accent: stockTint,
                    isMini: true
                ) {
                    withAnimation(GoMotion.feedback) {
                        draftStore.stockExpenseAmountKeypadVisible = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    var stockExpensePayerName: String {
        guard let stockExpensePayerId = draftStore.stockExpensePayerId,
              let human = allHumans.first(where: { $0.id.uuidString == stockExpensePayerId })
        else {
            return l.tr(zh: "未指定", en: "Unspecified", de: "Nicht angegeben")
        }
        return human.name
    }

    var stockManageSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sheetHero(icon: "shippingbox.fill", title: l.tr(zh: "余粮管理", en: "Stock manage", de: "Vorrat verwalten"), tint: stockTint)
                foodKindSegmentedControl(selection: draftStore.selectedStockFoodKind) { foodKind in
                    withAnimation(GoMotion.page) {
                        draftStore.selectedStockFoodKind = foodKind
                        prepareStockCorrectionText()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                }

                let activeRecord = managedActiveStockRecord
                if let activeRecord {
                    stockManagementCurrentCard(record: activeRecord)
                    stockCorrectionCard(record: activeRecord)
                } else {
                    emptyInlineState(icon: "shippingbox", text: l.tr(zh: "当前类型还没有已开袋余粮", en: "No opened stock for this type", de: "Kein geöffneter Vorrat für diesen Typ"))
                }

                stockReminderManageCard
                stockPendingRecordsCard
                stockRecentRecordsCard

                FoodPrimaryButton(title: l.tr(zh: "新增补粮", en: "Add restock", de: "Nachfüllung hinzufügen"), icon: "plus", tint: stockTint) {
                    prepareStockSheet(foodKind: draftStore.selectedStockFoodKind)
                    openFeedSheet(.stock)
                }

                if let activeRecord {
                    stockDeleteCurrentRecordCard(record: activeRecord)
                }
            }
            .padding(20)
            .ohanaAdaptiveSheetContentHeight(
                adaptiveSheetHeightBinding,
                minHeight: 520,
                maxHeight: 760,
                chromePadding: 70
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(l.tr(zh: "余粮管理", en: "Stock manage", de: "Vorrat verwalten"))
    }

    func stockDeleteCurrentRecordCard(record: PetFoodRecord) -> some View {
        Button {
            activeAlert = .deleteFoodRecord(record)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 34, height: 34)
                    .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "删除这袋粮", en: "Delete this bag", de: "Diesen Vorrat löschen"))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                    Text(l.tr(
                        zh: "只删除当前补粮/开袋记录，不删除喂食历史。",
                        en: "Removes only this stock record, not feeding history.",
                        de: "Entfernt nur diesen Vorratseintrag, nicht die Fütterungshistorie."
                    ))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }
            .padding(14)
            .feedFlatBlockSurface(cornerRadius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(pet.hasPassedAway)
    }

    var managedStockRecords: [PetFoodRecord] {
        stockSnapshot.records(for: draftStore.selectedStockFoodKind)
    }

    var managedActiveStockRecord: PetFoodRecord? {
        stockSnapshot.activeRecord(for: draftStore.selectedStockFoodKind)
    }

    var managedPendingStockRecords: [PetFoodRecord] {
        stockSnapshot.pendingRecords(for: draftStore.selectedStockFoodKind)
    }

    var managedOpenedHistoryStockRecords: [PetFoodRecord] {
        stockSnapshot.openedHistoryRecords(for: draftStore.selectedStockFoodKind)
    }

    func stockManagementCurrentCard(record: PetFoodRecord) -> some View {
        let snapshot = stockSnapshot.stock(for: draftStore.selectedStockFoodKind)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.brand.isEmpty ? l.tr(zh: "当前余粮", en: "Current stock", de: "Aktueller Vorrat") : record.brand)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("\(draftStore.selectedStockFoodKind.title(l)) · \(formattedStockWeight(snapshot.remainingGrams))")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(stockStatusTint(snapshot))
                }
                Spacer()
                Text(snapshot.remainingDays > 0 ? "\(snapshot.remainingDays)d" : "--")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(stockStatusTint(snapshot))
            }

            stockDateLine(
                title: l.tr(zh: "购买", en: "Bought", de: "Gekauft"),
                date: record.purchaseDate ?? record.startDate
            )
            stockDateLine(
                title: l.tr(zh: "开袋", en: "Opened", de: "Geöffnet"),
                date: record.startDate
            )
            if let grams = record.remainingCorrectionGrams, let date = record.remainingCorrectionDate {
                Text(l.tr(
                    zh: "已手动修正为 \(formattedStockWeight(grams)) · \(date.formatted(date: .numeric, time: .shortened))",
                    en: "Manually corrected to \(formattedStockWeight(grams)) · \(date.formatted(date: .numeric, time: .shortened))",
                    de: "Manuell korrigiert auf \(formattedStockWeight(grams)) · \(date.formatted(date: .numeric, time: .shortened))"
                ))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            prepareStockSheet(record: record)
            openFeedSheet(.stock)
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .accessibilityAddTraits(.isButton)
    }

    func stockDateLine(title: String, date: Date) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
            Text(date.formatted(date: .numeric, time: .omitted))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    func stockCorrectionCard(record: PetFoodRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "手动修正余量", en: "Correct remaining stock", de: "Restbestand korrigieren"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    openFeedNumberPad(.stockCorrection)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(draftStore.stockCorrectionText.isEmpty ? "800" : draftStore.stockCorrectionText)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(draftStore.stockCorrectionText.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text("g")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(stockTint)
                        Spacer()
                        Image(systemName: "number")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(stockTint)
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                feedInlineNumberPad(field: .stockCorrection, text: $draftStore.stockCorrectionText, tint: stockTint, maxFractionDigits: 0)
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 16)
            FoodPrimaryButton(title: l.tr(zh: "保存修正", en: "Save correction", de: "Korrektur speichern"), icon: "checkmark", tint: stockTint) {
                correctStock(record)
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 20)
    }

    var stockReminderManageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $draftStore.stockReminderEnabled) {
                Text(l.tr(zh: "低余粮提醒", en: "Low stock reminder", de: "Vorrats-Erinnerung"))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(stockTint)

            if draftStore.stockReminderEnabled {
                Picker(l.tr(zh: "提前", en: "Advance", de: "Vorher"), selection: $draftStore.stockReminderAdvanceDays) {
                    ForEach(stockReminderAdvanceOptions, id: \.self) { days in
                        Text("\(days) \(l.tr(zh: "天", en: "days", de: "Tage"))").tag(days)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                saveStockReminderSettings()
            } label: {
                Label(l.tr(zh: "保存提醒", en: "Save reminder", de: "Erinnerung speichern"), systemImage: "bell.badge.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(stockTint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .feedFlatBlockSurface(cornerRadius: 16)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 20)
    }

    var stockPendingRecordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            overviewSectionHeader(l.tr(zh: "待开袋", en: "Pending open", de: "Wartet auf Öffnung"))
            if managedPendingStockRecords.isEmpty {
                emptyInlineState(icon: "clock", text: l.tr(zh: "没有未来开袋的粮", en: "No future stock", de: "Kein künftiger Vorrat"))
            } else {
                ForEach(managedPendingStockRecords.prefix(3)) { record in
                    foodRecordRow(record)
                }
            }
        }
    }

    @ViewBuilder
    var stockRecentRecordsCard: some View {
        if !managedOpenedHistoryStockRecords.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                overviewSectionHeader(l.tr(zh: "最近补粮", en: "Recent restocks", de: "Letzte Nachfüllungen"))
                ForEach(managedOpenedHistoryStockRecords.prefix(4)) { record in
                    foodRecordRow(record)
                }
            }
        }
    }

    var stockOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                stockOverviewStatusStrip
                stockSnapshotCard(foodKind: .dry, tint: dryFoodTint)
                stockSnapshotCard(foodKind: .wet, tint: wetFoodTint)
                HStack(spacing: 10) {
                    FoodPrimaryButton(title: l.tr(zh: "补粮", en: "Restock", de: "Nachfüllen"), icon: "plus", tint: stockTint) {
                        prepareStockSheet()
                        openFeedSheet(.stock)
                    }
                    Button {
                        prepareStockManageSheet()
                        openFeedSheet(.stockManage)
                    } label: {
                        Label(l.tr(zh: "管理", en: "Manage", de: "Verwalten"), systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(stockTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .feedFlatBlockSurface(cornerRadius: 18)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                stockOverviewRestockSection
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
    }
}
