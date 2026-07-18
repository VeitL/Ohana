//
//  QuickHumanExpenseSheet.swift
//  Ohana
//
//  V4 quick human expense popup.
//

import SwiftData
import SwiftUI

private struct QuickHumanExpenseContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct QuickHumanExpenseSheet: View {
    let human: Human
    var onSaved: (() -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var amountText = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var note = ""
    @State private var date = Date()
    @State private var selectedRecorderID: UUID?
    @State private var requiresRecorderSelection = false
    @State private var adaptiveSheetHeight: CGFloat = 610
    @State private var contentHeight: CGFloat = 0
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var isSaving = false
    @State private var popupDragOffset: CGFloat = 0
    @State private var saveErrorMessage: String? = nil
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var amount: Double? { CountryDecimalInput.parse(amountText, countryCode: appCountry) }
    private var isValid: Bool { (amount ?? 0) > 0 && !requiresRecorderSelection }
    private var quickAmounts: [Double] {
        ExpenseAmountPresets.defaults(for: selectedCategory)
    }

    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(human.name)
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    amountBlock
                    EmbeddedDecimalKeypad(
                        text: $amountText,
                        countryCode: appCountry,
                        maxFractionDigits: 2,
                        accent: Color.goPrimary,
                        isMini: true,
                        showsSubmitButton: false,
                        onSubmit: {
                            if isValid { save() }
                        }
                    )
                    .padding(.horizontal, 22)
                    quickAmountBlock
                    categoryBlock
                    noteBlock
                    dateBlock
                    QuickCareActionHumanPickerContainer(
                        selectedHumanID: $selectedRecorderID,
                        requiresSelection: $requiresRecorderSelection,
                        role: .recorder,
                        tint: .goPrimary
                    )
                    .padding(.horizontal, 22)
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("quick-human-expense-sheet")
            .navigationTitle(l.tr(zh: "快速记账", en: "Quick Expense", de: "Schnelle Ausgabe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { close() }
                        .accessibilityIdentifier("ohana-sheet-close-action")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) { save() }
                        .disabled(!isValid || isSaving)
                        .accessibilityIdentifier("quick-human-expense-save-action")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .onChange(of: amountText) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(newValue, countryCode: appCountry, maxFractionDigits: 2)
            if sanitized != newValue {
                amountText = sanitized
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
        .alert(
            l.tr(zh: "无法保存费用", en: "Could not save expense", de: "Ausgabe konnte nicht gespeichert werden"),
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button(l.tr(zh: "知道了", en: "OK", de: "OK"), role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private var popupBackdrop: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.06), // ui-v4: allow short popup scrimGradient token
                Color.black.opacity(0.30) // ui-v4: allow short popup scrimGradient token
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { close() }
    }

    private var popupDragHandle: some View {
        OhanaPopupDragHandle()
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        popupDragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height > 70 || value.predictedEndTranslation.height > 130 {
                            close()
                        } else {
                            withAnimation(popupAnimation) { popupDragOffset = 0 }
                        }
                    }
            )
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(Color.goPrimary.opacity(0.18))
                Image(systemName: AppCurrency.systemIconName)
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "快速记账", en: "Quick Expense", de: "Schnelle Ausgabe"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(human.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            OhanaPopupCloseButton { close() }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "金额", en: "Amount", de: "Betrag"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(AppCurrency.symbol)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goPrimary)
                Text(amountText.isEmpty ? "0" : amountText)
                    .font(OhanaFont.metric(size: 44))
                    .foregroundStyle(amountText.isEmpty ? Color.ohanaTertiaryText : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
        .padding(.horizontal, 22)
    }

    private var quickAmountBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.quickExpenseCommonAmounts)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(quickAmounts.enumerated()), id: \.element) { index, amount in
                        Button {
                            amountText = displayAmount(amount)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("\(AppCurrency.symbol)\(displayAmount(amount))")
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(isQuickAmountSelected(amount) ? Color.arkInk : Color.ohanaPrimaryText)
                                .padding(.horizontal, 13)
                                .frame(height: 34)
                                .background(
                                    isQuickAmountSelected(amount) ? Color.goPrimary : Color.ohanaControlFill,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("quick-human-expense-amount-\(index)")
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private var categoryBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.quickExpenseCategory)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            TextField(l.tr(zh: "例如：咖啡、药品、交通", en: "Coffee, meds, transit", de: "Kaffee, Medikamente, Fahrt"), text: $note) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
                .accessibilityIdentifier("quick-human-expense-note-input")
        }
        .padding(.horizontal, 22)
    }

    private var dateBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(l.tr(zh: "日期", en: "Date", de: "Datum"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .tint(Color.goPrimary)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .padding(.horizontal, 22)
    }

    private var saveBar: some View {
        Button { save() } label: {
            HStack(spacing: 8) {
                Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                Text(isSaving
                    ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                    : l.tr(zh: "保存花费", en: "Save Expense", de: "Ausgabe speichern")
                )
                .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isValid && !isSaving ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isValid || isSaving)
        .accessibilityIdentifier("quick-human-expense-save-action")
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private func categoryChip(_ category: ExpenseCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(GoMotion.feedback) {
                selectedCategory = category
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.systemIconName)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                Text(l.expenseCategoryTitle(category))
                    .font(OhanaFont.caption(.black))
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func displayAmount(_ amount: Double) -> String {
        let rounded = ExpenseAmountPresets.roundedCurrency(amount)
        let fractionDigits = abs(rounded - rounded.rounded()) < 0.01 ? 0 : 2
        return CountryDecimalInput.format(rounded, countryCode: appCountry, maxFractionDigits: fractionDigits)
    }

    private func isQuickAmountSelected(_ amount: Double) -> Bool {
        guard let parsed = self.amount else { return false }
        return abs(ExpenseAmountPresets.roundedCurrency(parsed) - ExpenseAmountPresets.roundedCurrency(amount)) < 0.01
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    @MainActor
    private func save() {
        guard !isSaving, !requiresRecorderSelection, let amount, amount > 0 else { return }
        isSaving = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let savedNote = note
        let savedDate = date
        let savedCategory = selectedCategory
        let savedRecorderID = selectedRecorderID?.uuidString
        let command = DomainCommand.quickHumanExpense(humanID: human.id)
        commandQueue.enqueue(command) {
            do {
                try DashboardRecordCommandExecutor(context: modelContext, services: appServices).recordHumanExpense(
                    human: human,
                    amount: amount,
                    date: savedDate,
                    note: savedNote,
                    recordedByHumanId: savedRecorderID,
                    category: savedCategory,
                    command: command,
                    revisionNote: "quick.human.expense"
                )
                onSaved?()
                close()
            } catch {
                saveErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? l.tr(
                        zh: "费用保存失败，请检查金额后重试。",
                        en: "Could not save the expense. Check the amount and try again.",
                        de: "Die Ausgabe konnte nicht gespeichert werden. Prüfe den Betrag und versuche es erneut."
                    )
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
