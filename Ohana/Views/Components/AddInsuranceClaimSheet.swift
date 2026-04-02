//
//  AddInsuranceClaimSheet.swift
//  Ohana
//
//  报销申请表单 Sheet — 支持关联现有医疗花费记录，审批到账时写负值 PetExpenseLog
//

import SwiftUI
import SwiftData

struct AddInsuranceClaimSheet: View {
    let insurance: PetInsurance
    let pet: Pet

    // 可选：从 AddExpenseSheet 打开时直接预填花费记录
    var prelinkedExpenseId: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var incidentDate = Date()
    @State private var totalExpenseInput = ""
    @State private var claimedAmountInput = ""
    @State private var noteInput = ""
    @State private var initialStatus: ClaimStatus = .submitted
    @State private var selectedExpenseLogId: String? = nil
    @State private var showExpensePicker = false

    // 该宠物的医疗 + 保险类花费（供关联选择）
    @Query private var allExpenses: [PetExpenseLog]

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
        Double(totalExpenseInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var claimedDouble: Double {
        Double(claimedAmountInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var canSave: Bool {
        totalExpenseDouble > 0 && claimedDouble > 0 && claimedDouble <= totalExpenseDouble
    }

    init(insurance: PetInsurance, pet: Pet, prelinkedExpenseId: String? = nil) {
        self.insurance = insurance
        self.pet = pet
        self.prelinkedExpenseId = prelinkedExpenseId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView {
                    VStack(spacing: 14) {
                        // 保险公司提示
                        if !insurance.companyName.isEmpty || !insurance.productName.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.goPrimary)
                                Text("\(insurance.productName) · \(insurance.companyName)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("保额 \(insurance.coverageAmount > 0 ? String(format: "¥%.0f", insurance.coverageAmount) : "—")")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color.goPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }

                        // 就诊 / 事故日期
                        DatePicker("就诊 / 事故日期", selection: $incidentDate, in: ...Date(), displayedComponents: .date)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .tint(Color.goPrimary)
                            .padding(14)
                            .goTranslucentCard(cornerRadius: 14)

                        // 金额区
                        VStack(spacing: 10) {
                            amountRow(label: "本次总花费 *", placeholder: "0.00", text: $totalExpenseInput)
                            amountRow(label: "申请报销金额 *", placeholder: "0.00", text: $claimedAmountInput)
                            if claimedDouble > totalExpenseDouble && totalExpenseDouble > 0 {
                                Text("报销金额不能超过总花费")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "FF6B6B"))
                                    .padding(.horizontal, 4)
                            }
                        }

                        // 关联花费记录
                        VStack(alignment: .leading, spacing: 8) {
                            Text("关联花费记录（可选）")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.45))
                            Button { showExpensePicker = true } label: {
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(selectedExpense == nil ? .secondary : Color.goPrimary)
                                    if let exp = selectedExpense {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(exp.note.isEmpty ? exp.expenseCategory.rawValue : exp.note)
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.primary)
                                            Text("\(exp.date.formatted(.dateTime.month().day())) · ¥\(String(format: "%.0f", exp.amount))")
                                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("从医疗花费中关联")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedExpense != nil {
                                        Button {
                                            selectedExpenseLogId = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(14)
                                .goTranslucentCard(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                        }

                        // 初始状态
                        VStack(alignment: .leading, spacing: 8) {
                            Text("申请状态")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.45))
                            HStack(spacing: 8) {
                                ForEach(ClaimStatus.allCases, id: \.rawValue) { status in
                                    Button { initialStatus = status } label: {
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(Color(hex: status.colorHex))
                                                .frame(width: 7, height: 7)
                                            Text(status.rawValue)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(initialStatus == status ? Color.arkInk : .primary)
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(
                                            initialStatus == status ? Color.goPrimary : Color.primary.opacity(0.08),
                                            in: Capsule()
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(14)
                        .goTranslucentCard(cornerRadius: 14)

                        // 备注
                        TextField("备注（诊断、病因等，可选）", text: $noteInput, axis: .vertical)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .lineLimit(3)
                            .padding(14)
                            .goTranslucentCard(cornerRadius: 14)

                        // 保存
                        Button { save() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("提交报销申请")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(
                                canSave ? Color.goPrimary : Color.primary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                        }
                        .buttonStyle(.plain).disabled(!canSave)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }
            }
            .navigationTitle("新增报销申请").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(.secondary)
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

    private func amountRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 14)
    }

    // MARK: - Logic

    private func save() {
        let claim = InsuranceClaim(
            claimDate: Date(),
            incidentDate: incidentDate,
            totalExpense: totalExpenseDouble,
            claimedAmount: claimedDouble,
            approvedAmount: initialStatus == .approved ? claimedDouble : 0,
            status: initialStatus,
            note: noteInput,
            relatedExpenseLogId: selectedExpenseLogId,
            insurance: insurance
        )
        modelContext.insert(claim)

        // 若直接标记为已报销，写负值 ExpenseLog
        if initialStatus == .approved && claimedDouble > 0 {
            let productName = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
            let expense = PetExpenseLog(
                date: Date(),
                amount: -claimedDouble,
                category: .insurancePremium,
                note: "保险报销到账：\(productName)",
                pet: pet
            )
            modelContext.insert(expense)
        }

        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - 关联花费选择器

private struct ExpenseLinkPickerSheet: View {
    let expenses: [PetExpenseLog]
    @Binding var selectedId: String?
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                Group {
                    if expenses.isEmpty {
                        VStack(spacing: 12) {
                            Text("暂无医疗花费记录")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
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
                                            Text(exp.note.isEmpty ? exp.expenseCategory.rawValue : exp.note)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.primary)
                                            Text(exp.date.formatted(.dateTime.year().month().day()))
                                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(String(format: "¥%.0f", exp.amount))
                                            .font(.system(size: 14, weight: .black, design: .rounded))
                                        if selectedId == exp.id.uuidString {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.goPrimary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("选择关联花费").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
    }
}
