//
//  EditPetExpenseSheet.swift
//  Ohana
//
//  Edits an existing pet expense through the expense command boundary.
//

import SwiftData
import SwiftUI
import UIKit

struct EditPetExpenseSheet: View {
    let pet: Pet
    let log: PetExpenseLog
    let humans: [Human]
    var onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var amountInput: String
    @State private var selectedCategory: ExpenseCategory
    @State private var noteInput: String
    @State private var date: Date
    @State private var selectedPayerIDs: [UUID]
    @State private var payerAmountInputs: [UUID: String]
    @State private var payerSelectionEdited = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    private var l: L10n { L10n(appLanguage) }
    private var isReimbursement: Bool { log.amount < 0 }
    private var activeHumans: [Human] { humans.filter { !$0.hasPassedAway } }
    private var hasHistoricalPayerShares: Bool {
        let activeIDs = Set(activeHumans.map(\.id))
        if !log.payerContributionsJSON.isEmpty {
            let contributions = log.payerContributions
            return contributions.isEmpty || contributions.contains { contribution in
                guard let humanID = contribution.humanID else { return true }
                return !activeIDs.contains(humanID)
            }
        }
        guard let executorID = log.executorId,
              let humanID = UUID(uuidString: executorID) else { return false }
        return !activeIDs.contains(humanID)
    }
    private var parsedAmount: Double? {
        CountryDecimalInput.parse(amountInput, countryCode: appCountry)
    }
    private var storedAmount: Double? {
        guard let parsedAmount, parsedAmount > 0, parsedAmount.isFinite else { return nil }
        return isReimbursement ? -parsedAmount : parsedAmount
    }
    private var storedNote: String {
        let clean = noteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isReimbursement else { return clean }
        return "\(ExpenseAmountPolicy.insuranceReimbursementNotePrefix)\(clean)"
    }
    private var payerContributionsForSave: [ExpensePayerContribution]? {
        guard !isReimbursement, selectedPayerIDs.count > 1 else { return [] }
        guard let total = parsedAmount else { return nil }
        let contributions = selectedPayerIDs.compactMap { humanID -> ExpensePayerContribution? in
            guard let input = payerAmountInputs[humanID],
                  let amount = CountryDecimalInput.parse(input, countryCode: appCountry) else {
                return nil
            }
            return try? ExpensePayerContributionPolicy.contribution(humanID: humanID, amount: amount)
        }
        guard contributions.count == selectedPayerIDs.count else { return nil }
        return try? ExpensePayerContributionPolicy.validated(contributions, total: total)
    }
    private var canSave: Bool {
        guard let storedAmount, !isSaving, !pet.hasPassedAway else { return false }
        if !payerSelectionEdited {
            return log.payerContributionsJSON.isEmpty || storedAmount == log.amount
        }
        return payerContributionsForSave != nil
    }

    init(
        pet: Pet,
        log: PetExpenseLog,
        humans: [Human],
        onSaved: (() -> Void)? = nil
    ) {
        self.pet = pet
        self.log = log
        self.humans = humans
        self.onSaved = onSaved

        let activeHumanIDs = Set(humans.filter { !$0.hasPassedAway }.map(\.id))
        let effectiveContributions = log.payerContributions
        let hasHistoricalPayerShares = !log.payerContributionsJSON.isEmpty
            && (effectiveContributions.isEmpty || effectiveContributions.contains { contribution in
                guard let humanID = contribution.humanID else { return true }
                return !activeHumanIDs.contains(humanID)
            })
        let initialPayerIDs: [UUID] = if hasHistoricalPayerShares {
            []
        } else {
            effectiveContributions
                .compactMap(\.humanID)
                .filter { activeHumanIDs.contains($0) }
        }
        let initialPayerAmounts: [UUID: String] = if log.amount > 0, initialPayerIDs.count > 1 {
            Dictionary(uniqueKeysWithValues: effectiveContributions.compactMap { contribution in
                guard let humanID = contribution.humanID,
                      activeHumanIDs.contains(humanID),
                      contribution.minorUnits > 0 else { return nil }
                return (
                    humanID,
                    CountryDecimalInput.format(
                        contribution.amount,
                        countryCode: AppCountry.code,
                        maxFractionDigits: 2
                    )
                )
            })
        } else {
            [:]
        }

        _amountInput = State(initialValue: CountryDecimalInput.format(
            abs(log.amount),
            countryCode: AppCountry.code,
            maxFractionDigits: 2
        ))
        _selectedCategory = State(initialValue: log.expenseCategory)
        _noteInput = State(initialValue: Self.editableNote(for: log))
        _date = State(initialValue: log.date)
        _selectedPayerIDs = State(initialValue: initialPayerIDs)
        _payerAmountInputs = State(initialValue: initialPayerAmounts)
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                detailsSection
                payerSection
            }
            .scrollContentBackground(.hidden)
            .background(OhanaAppBackground())
            .navigationTitle(l.tr(zh: "编辑花费", en: "Edit Expense", de: "Ausgabe bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern"), action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("pet-expense-edit-save-action")
                }
            }
        }
        .tint(Color.goPrimary)
        .environment(\.locale, AppLanguage.effectiveLocale)
        .interactiveDismissDisabled(isSaving)
        .onChange(of: amountInput) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(
                newValue,
                countryCode: appCountry,
                maxFractionDigits: 2
            )
            if sanitized != newValue {
                amountInput = sanitized
                return
            }
            if !payerInputsMatchCurrentAmount {
                resetPayerAmountsToEqual()
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
            isSaving = false
        }
        .alert(
            l.tr(zh: "无法保存花费", en: "Could not save expense", de: "Ausgabe konnte nicht gespeichert werden"),
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

    private var amountSection: some View {
        Section(isReimbursement
            ? l.tr(zh: "报销金额", en: "Reimbursement", de: "Erstattung")
            : l.tr(zh: "金额", en: "Amount", de: "Betrag")) {
            HStack {
                Text(AppCurrency.symbol)
                    .foregroundStyle(Color.goPrimary)
                TextField(CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: appCountry), text: $amountInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .disabled(isReimbursement)
                    .accessibilityIdentifier("pet-expense-edit-amount-input")
            }
        }
    }

    private var detailsSection: some View {
        Section(l.tr(zh: "详情", en: "Details", de: "Details")) {
            if isReimbursement {
                LabeledContent(
                    l.tr(zh: "类型", en: "Category", de: "Kategorie"),
                    value: l.tr(zh: "保险报销", en: "Insurance reimbursement", de: "Versicherungserstattung")
                )
            } else {
                Picker(l.tr(zh: "类型", en: "Category", de: "Kategorie"), selection: $selectedCategory) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Label(l.expenseCategoryTitle(category), systemImage: category.systemIconName)
                            .tag(category)
                    }
                }
            }
            DatePicker(
                l.tr(zh: "日期", en: "Date", de: "Datum"),
                selection: $date,
                in: ...Date(),
                displayedComponents: [.date]
            )
            TextField(
                l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"),
                text: $noteInput,
                axis: .vertical
            )
            .lineLimit(2 ... 5)
            .accessibilityIdentifier("pet-expense-edit-note-input")
        }
    }

    private var payerSection: some View {
        Section {
            payerButton(id: nil, name: l.tr(
                zh: "未指定",
                en: "Unassigned",
                de: "Nicht zugeordnet"
            ))
            ForEach(activeHumans) { human in
                payerButton(id: human.id, name: human.name)
            }
            if !isReimbursement, selectedPayerIDs.count > 1 {
                ForEach(selectedPayerIDs, id: \.self) { humanID in
                    if let human = activeHumans.first(where: { $0.id == humanID }) {
                        HStack {
                            Text(human.name)
                            Spacer()
                            Text(AppCurrency.symbol)
                                .foregroundStyle(Color.ohanaSecondaryText)
                            TextField(
                                CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: appCountry),
                                text: payerAmountBinding(for: humanID)
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                            .accessibilityIdentifier("pet-expense-edit-payer-amount-\(humanID.uuidString)")
                        }
                    }
                }
            }
        } header: {
            Text(isReimbursement
                ? l.tr(zh: "到账成员", en: "Recipient", de: "Empfänger")
                : l.tr(zh: "支付人", en: "Payer", de: "Zahlende Person"))
        } footer: {
            if hasHistoricalPayerShares, !payerSelectionEdited {
                Text(l.tr(
                    zh: "历史支付人及匿名份额会保留；重新选择支付人后才会替换。",
                    en: "Historical payers and anonymous shares stay intact unless you select new payers.",
                    de: "Frühere Zahlende und anonyme Anteile bleiben erhalten, bis du neue Zahlende auswählst."
                ))
            }
            if !payerSelectionEdited, !log.payerContributionsJSON.isEmpty,
               storedAmount != log.amount {
                Text(l.tr(
                    zh: "更改总金额前，请重新选择支付人并分配金额。",
                    en: "Select payers and allocate their shares before changing the total.",
                    de: "Wähle vor der Änderung des Gesamtbetrags die Zahlenden und ihre Anteile erneut aus."
                ))
                .foregroundStyle(Color.goRed)
            } else if payerSelectionEdited, !isReimbursement,
                      selectedPayerIDs.count > 1, payerContributionsForSave == nil {
                Text(l.tr(
                    zh: "逐人金额会自动汇总到总金额。",
                    en: "Payer amounts automatically update the total.",
                    de: "Die Zahlbeträge aktualisieren automatisch die Gesamtsumme."
                ))
                .foregroundStyle(Color.goRed)
            }
        }
    }

    private func payerButton(id: UUID?, name: String) -> some View {
        let isSelected = id.map { selectedPayerIDs.contains($0) }
            ?? (selectedPayerIDs.isEmpty && (payerSelectionEdited || !hasHistoricalPayerShares))
        return Button {
            payerSelectionEdited = true
            if let id {
                togglePayer(id)
            } else {
                selectedPayerIDs = []
                payerAmountInputs = [:]
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack {
                Text(name)
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                        .foregroundStyle(Color.goPrimary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(id.map { "pet-expense-edit-payer-\($0.uuidString)" } ?? "pet-expense-edit-payer-unassigned")
    }

    private func togglePayer(_ id: UUID) {
        if isReimbursement {
            selectedPayerIDs = selectedPayerIDs == [id] ? [] : [id]
            payerAmountInputs = [:]
            return
        }
        if selectedPayerIDs.contains(id) {
            selectedPayerIDs.removeAll { $0 == id }
        } else {
            selectedPayerIDs.append(id)
        }
        if selectedPayerIDs.count > 1 {
            resetPayerAmountsToEqual()
        } else {
            payerAmountInputs = [:]
        }
    }

    private func payerAmountBinding(for humanID: UUID) -> Binding<String> {
        Binding(
            get: { payerAmountInputs[humanID] ?? "" },
            set: { newValue in
                payerSelectionEdited = true
                payerAmountInputs[humanID] = CountryDecimalInput.sanitize(
                    newValue,
                    countryCode: appCountry,
                    maxFractionDigits: 2
                )
                syncAmountFromPayerInputs()
            }
        )
    }

    private var draftedPayerContributions: [ExpensePayerContribution]? {
        guard selectedPayerIDs.count > 1 else { return [] }
        let contributions = selectedPayerIDs.compactMap { humanID -> ExpensePayerContribution? in
            guard let input = payerAmountInputs[humanID],
                  let amount = CountryDecimalInput.parse(input, countryCode: appCountry) else {
                return nil
            }
            return try? ExpensePayerContributionPolicy.contribution(humanID: humanID, amount: amount)
        }
        return contributions.count == selectedPayerIDs.count ? contributions : nil
    }

    private var payerInputsMatchCurrentAmount: Bool {
        guard selectedPayerIDs.count > 1,
              let parsedAmount,
              let amountUnits = ExpensePayerContributionPolicy.minorUnits(parsedAmount),
              let contributions = draftedPayerContributions,
              let total = try? ExpensePayerContributionPolicy.totalAmount(of: contributions),
              let payerUnits = ExpensePayerContributionPolicy.minorUnits(total) else {
            return false
        }
        return amountUnits == payerUnits
    }

    private func syncAmountFromPayerInputs() {
        guard let contributions = draftedPayerContributions,
              let total = try? ExpensePayerContributionPolicy.totalAmount(of: contributions) else {
            return
        }
        amountInput = CountryDecimalInput.format(
            total,
            countryCode: appCountry,
            maxFractionDigits: 2
        )
    }

    private func resetPayerAmountsToEqual() {
        guard !isReimbursement,
              selectedPayerIDs.count > 1,
              let parsedAmount,
              let contributions = try? ExpensePayerContributionPolicy.equalSplit(
                  total: parsedAmount,
                  humanIDs: selectedPayerIDs
              ) else {
            return
        }
        payerAmountInputs = Dictionary(uniqueKeysWithValues: contributions.compactMap { contribution in
            guard let humanID = contribution.humanID else { return nil }
            return (
                humanID,
                CountryDecimalInput.format(
                    contribution.amount,
                    countryCode: appCountry,
                    maxFractionDigits: 2
                )
            )
        })
    }

    @MainActor
    private func save() {
        guard canSave,
              let amount = storedAmount else { return }
        let payerContributions = payerSelectionEdited ? payerContributionsForSave : nil
        guard !payerSelectionEdited || payerContributions != nil else { return }
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.expenseUpdate(
            entityID: pet.id,
            entityKind: EntityKind.pet.rawValue,
            recordID: log.id
        )) {
            do {
                _ = try DashboardRecordCommandExecutor(
                    context: modelContext,
                    services: appServices
                ).updatePetExpense(
                    log,
                    pet: pet,
                    input: PetExpenseUpdateInput(
                        amount: amount,
                        date: date,
                        category: isReimbursement ? .insurancePremium : selectedCategory,
                        note: storedNote,
                        payerID: payerSelectionEdited ? selectedPayerIDs.first : nil,
                        payerContributions: payerContributions
                    ),
                    note: "dashboard.expense.update"
                )
                isSaving = false
                onSaved?()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                isSaving = false
                saveErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? l.tr(
                        zh: "花费保存失败，请重试。",
                        en: "Could not save the expense. Try again.",
                        de: "Die Ausgabe konnte nicht gespeichert werden. Versuche es erneut."
                    )
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private static func editableNote(for log: PetExpenseLog) -> String {
        guard log.amount < 0,
              log.note.hasPrefix(ExpenseAmountPolicy.insuranceReimbursementNotePrefix) else {
            return SharedCareMetadata.visibleNote(log.note)
        }
        return String(log.note.dropFirst(ExpenseAmountPolicy.insuranceReimbursementNotePrefix.count))
    }
}
