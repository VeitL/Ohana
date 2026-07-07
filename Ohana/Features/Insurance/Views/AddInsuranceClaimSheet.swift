//
//  AddInsuranceClaimSheet.swift
//  Ohana
//
//  报销申请表单 Sheet — 支持关联现有医疗花费记录，审批到账时写负值 PetExpenseLog
//

import SwiftData
import SwiftUI

struct AddInsuranceClaimSheet: View {
    let insurance: PetInsurance
    let pet: Pet
    let allExpenses: [PetExpenseLog]

    // 可选：从 AddExpenseSheet 打开时直接预填花费记录
    var prelinkedExpenseId: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var incidentDate = Date()
    @State private var totalExpenseInput = ""
    @State private var claimedAmountInput = ""
    @State private var noteInput = ""
    @State private var initialStatus: ClaimStatus = .submitted
    @State private var selectedExpenseLogId: String? = nil
    @State private var showExpensePicker = false
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var medicalExpenses: [PetExpenseLog] {
        allExpenses
            .filter { $0.pet?.id == pet.id }
            .filter { $0.expenseCategory == .medical || $0.expenseCategory == .insurancePremium }
            .sorted { $0.date > $1.date }
    }

    private var selectedExpense: PetExpenseLog? {
        guard let id = selectedExpenseLogId else { return nil }
        return allExpenses.first { $0.id.uuidString == id }
    }

    private var totalExpenseDouble: Double {
        CountryDecimalInput.parse(totalExpenseInput, countryCode: AppCountry.code) ?? 0
    }

    private var claimedDouble: Double {
        CountryDecimalInput.parse(claimedAmountInput, countryCode: AppCountry.code) ?? 0
    }

    private var canSave: Bool {
        totalExpenseDouble > 0 && claimedDouble > 0 && claimedDouble <= totalExpenseDouble
    }

    private var l: L10n { L10n(appLanguage) }

    init(
        insurance: PetInsurance,
        pet: Pet,
        allExpenses: [PetExpenseLog],
        prelinkedExpenseId: String? = nil
    ) {
        self.insurance = insurance
        self.pet = pet
        self.allExpenses = allExpenses
        self.prelinkedExpenseId = prelinkedExpenseId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        // 保险公司提示
                        if !insurance.companyName.isEmpty || !insurance.productName.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.checkered") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.goPrimary)
                                Text("\(insurance.productName) · \(insurance.companyName)")
                                    .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                Spacer()
                                Text(coverageSummary)
                                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            .padding(12)
                            .background(Color.goPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.chip))
                        }

                        // 就诊 / 事故日期
                        DatePicker(l.tr(zh: "就诊 / 事故日期", en: "Visit / incident date", de: "Behandlungs- / Vorfalldatum"), selection: $incidentDate, in: ...Date(), displayedComponents: .date)
                            .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .tint(Color.goPrimary)
                            .padding(14)
                            .goTranslucentCard(cornerRadius: OhanaRadius.row)

                        // 金额区
                        VStack(spacing: 10) {
                            amountRow(label: l.tr(zh: "本次总花费 *", en: "Total expense *", de: "Gesamtkosten *"), placeholder: "0.00", text: $totalExpenseInput)
                            amountRow(label: l.tr(zh: "申请报销金额 *", en: "Claim amount *", de: "Erstattungsbetrag *"), placeholder: "0.00", text: $claimedAmountInput)
                            if claimedDouble > totalExpenseDouble, totalExpenseDouble > 0 {
                                Text(l.tr(zh: "报销金额不能超过总花费", en: "Claim amount cannot exceed total expense", de: "Der Erstattungsbetrag darf die Gesamtkosten nicht überschreiten"))
                                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color(hex: "FF6B6B"))
                                    .padding(.horizontal, 4)
                            }
                        }

                        // 关联花费记录
                        VStack(alignment: .leading, spacing: 8) {
                            Text(l.tr(zh: "关联花费记录（可选）", en: "Linked expense (optional)", de: "Verknüpfte Ausgabe (optional)"))
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                            Button { showExpensePicker = true } label: {
                                HStack {
                                    Image(systemName: "link.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(selectedExpense == nil ? .secondary : Color.goPrimary)
                                    if let exp = selectedExpense {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(exp.note.isEmpty ? l.expenseCategoryTitle(exp.expenseCategory) : exp.note)
                                                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.ohanaPrimaryText)
                                            Text("\(exp.date.formatted(.dateTime.month().day())) · \(AppCurrency.format(exp.amount, fractionDigits: 0))")
                                                .font(OhanaFont.adaptive(size: 11, weight: .regular, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.ohanaSecondaryText)
                                        }
                                    } else {
                                        Text(l.tr(zh: "从医疗花费中关联", en: "Link a medical expense", de: "Medizinische Ausgabe verknüpfen"))
                                            .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(Color.ohanaSecondaryText)
                                    }
                                    Spacer()
                                    if selectedExpense != nil {
                                        Button {
                                            selectedExpenseLogId = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                .font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.ohanaSecondaryText)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    } else {
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 12, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(14)
                                .goTranslucentCard(cornerRadius: OhanaRadius.row)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // 初始状态
                        VStack(alignment: .leading, spacing: 8) {
                            Text(l.tr(zh: "申请状态", en: "Claim status", de: "Status"))
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                            HStack(spacing: 8) {
                                ForEach(ClaimStatus.allCases, id: \.rawValue) { status in
                                    Button { initialStatus = status } label: {
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(Color(hex: status.colorHex))
                                                .frame(width: 7, height: 7) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                            Text(status.localizedLabel(l))
                                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(initialStatus == status ? Color.arkInk : .primary)
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(
                                            initialStatus == status ? Color.goPrimary : Color.primary.opacity(0.08),
                                            in: Capsule()
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                        .padding(14)
                        .goTranslucentCard(cornerRadius: OhanaRadius.row)

                        // 备注
                        TextField(l.tr(zh: "备注（诊断、病因等，可选）", en: "Notes (diagnosis, cause, optional)", de: "Notizen (Diagnose, Ursache, optional)"), text: $noteInput, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .lineLimit(3)
                            .padding(14)
                            .goTranslucentCard(cornerRadius: OhanaRadius.row)

                        // 保存
                        Button { save() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                Text(isSaving ? l.tr(zh: "提交中", en: "Submitting", de: "Wird gesendet") : l.tr(zh: "提交报销申请", en: "Submit claim", de: "Erstattung einreichen"))
                                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            }
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(
                                canSave && !isSaving ? Color.goPrimary : Color.primary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: OhanaRadius.control)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle()).disabled(!canSave || isSaving)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }
            }
            .navigationTitle(l.tr(zh: "新增报销申请", en: "New claim", de: "Neue Erstattung"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) { dismiss() }.foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .sheet(isPresented: $showExpensePicker) {
                ExpenseLinkPickerSheet(
                    expenses: medicalExpenses,
                    selectedId: $selectedExpenseLogId,
                    onSelect: { id in
                        selectedExpenseLogId = id
                        // 自动填入金额
                        if let exp = allExpenses.first(where: { $0.id.uuidString == id }) {
                            totalExpenseInput = String(format: "%.2f", exp.amount)
                            if claimedAmountInput.isEmpty {
                                claimedAmountInput = String(format: "%.2f", exp.amount)
                            }
                        }
                    }
                )
            }
            .onAppear {
                if let pid = prelinkedExpenseId {
                    selectedExpenseLogId = pid
                    if let exp = allExpenses.first(where: { $0.id.uuidString == pid }) {
                        totalExpenseInput = String(format: "%.2f", exp.amount)
                        claimedAmountInput = String(format: "%.2f", exp.amount)
                        incidentDate = exp.date
                    }
                }
            }
        }
    }

    // MARK: - Sub-views

    private var coverageSummary: String {
        let amount = insurance.coverageAmount > 0 ? AppCurrency.format(insurance.coverageAmount, fractionDigits: 0) : "—"
        return l.tr(zh: "保额 \(amount)", en: "Coverage \(amount)", de: "Deckung \(amount)")
    }

    private func amountRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(AppCurrency.symbol)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                InlineNumericInput(
                    text: text,
                    placeholder: placeholder,
                    maxFractionDigits: 2,
                    accent: Color.goPrimary,
                    step: 10,
                    valueFont: .system(size: 17, weight: .black, design: .rounded),
                    valueAlignment: .trailing,
                    fill: Color.clear,
                    cornerRadius: OhanaRadius.chip,
                    horizontalPadding: 4,
                    verticalPadding: 0
                )
                .frame(maxWidth: 128)
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: OhanaRadius.row)
    }

    // MARK: - Logic

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        let now = Date()
        let executorId = appServices.activeHumanSelection.currentHumanId
        let input = InsuranceClaimCommandInput(
            claimDate: now,
            incidentDate: incidentDate,
            totalExpense: totalExpenseDouble,
            claimedAmount: claimedDouble,
            status: initialStatus,
            note: noteInput,
            executorId: executorId,
            relatedExpenseLogId: selectedExpenseLogId,
            approvedAt: initialStatus == .approved ? now : nil
        )
        let command = DomainCommand.insuranceClaim(
            petID: pet.id,
            policyID: insurance.id,
            claimID: nil,
            action: "create"
        )

        commandQueue.enqueue(command) {
            do {
                try InsuranceCommandExecutor(context: modelContext, services: appServices).createClaim(
                    insurance: insurance,
                    pet: pet,
                    input: input,
                    note: "insurance.claim.create"
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }
}

// MARK: - 关联花费选择器

private struct ExpenseLinkPickerSheet: View {
    let expenses: [PetExpenseLog]
    @Binding var selectedId: String?
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                Group {
                    if expenses.isEmpty {
                        VStack(spacing: 12) {
                            Text(l.tr(zh: "暂无医疗花费记录", en: "No medical expense records", de: "Keine medizinischen Ausgaben"))
                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(expenses) { exp in
                                Button {
                                    onSelect(exp.id.uuidString)
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exp.note.isEmpty ? l.expenseCategoryTitle(exp.expenseCategory) : exp.note)
                                                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.ohanaPrimaryText)
                                            Text(exp.date.formatted(.dateTime.year().month().day()))
                                                .font(OhanaFont.adaptive(size: 12, weight: .regular, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.ohanaSecondaryText)
                                        }
                                        Spacer()
                                        Text(AppCurrency.format(exp.amount, fractionDigits: 0))
                                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        if selectedId == exp.id.uuidString {
                                            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                .foregroundStyle(Color.goPrimary)
                                        }
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle(l.tr(zh: "选择关联花费", en: "Choose expense", de: "Ausgabe auswählen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) { dismiss() }.foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
    }
}
