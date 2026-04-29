//
//  AddExpenseSheet.swift
//  Ohana
//
//  花费快捷添加 Sheet — 参考 GenericWeightEntrySheet 风格
//  （ArkBackgroundView 背景 + 手动 Header + SF Symbol 分类图标）
//

import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let pet: Pet
    var preselectedPayerId: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @FocusState private var inputFocused: Bool

    @State private var amountInput = ""
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var noteInput = ""
    @State private var date = Date()
    @State private var selectedPayerId: String? = nil

    // 报销申请快捷入口
    @State private var savedExpenseId: String? = nil
    @State private var showClaimToast = false
    @State private var showClaimSheet = false

    private var petThemeColor: Color {
        Color(hex: pet.themeColorHex.isEmpty ? "C8FF00" : pet.themeColorHex)
    }
    private var isAmountValid: Bool {
        guard let v = Double(amountInput.replacingOccurrences(of: ",", with: ".")), v > 0 else { return false }
        return true
    }
    // 该宠物的活跃保单（用于报销快捷入口）
    private var activeInsurances: [PetInsurance] {
        (pet.insurances).filter { $0.isActive }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ArkBackgroundView()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    // 宠物头像 + 标题
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(petThemeColor.opacity(0.25))
                                .frame(width: 36, height: 36)
                            if let data = pet.avatarImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            } else {
                                Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                                    .font(.system(size: 18))
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("记录花费")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(pet.name)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 大金额输入
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("¥")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(petThemeColor)
                            TextField("0.00", text: $amountInput)
                                .keyboardType(.decimalPad)
                                .focused($inputFocused)
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                                .minimumScaleFactor(0.45)
                        }
                        .padding(.horizontal, 20)

                        GoDashedDivider().padding(.horizontal, 16)

                        // 分类选择（SF Symbol 图标）
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel(icon: "tag.fill", title: "分类")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(ExpenseCategory.allCases, id: \.rawValue) { cat in
                                    Button { selectedCategory = cat } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: cat.systemIconName)
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(selectedCategory == cat ? Color.arkInk : .primary.opacity(0.6))
                                                .frame(width: 36, height: 36)
                                                .background(
                                                    selectedCategory == cat ? petThemeColor : Color.primary.opacity(0.08),
                                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                )
                                            Text(cat.rawValue)
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(selectedCategory == cat ? .primary : .secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        GoDashedDivider().padding(.horizontal, 16)

                        // 支付者
                        if !humans.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionLabel(icon: "person.fill", title: "支付者")
                                    .padding(.horizontal, 20)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        // 未指定
                                        payerAvatar(id: nil, color: petThemeColor, label: "未指定") {
                                            Image(systemName: "questionmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(selectedPayerId == nil ? Color.arkInk : .primary.opacity(0.4))
                                        }
                                        // 家庭成员
                                        ForEach(humans) { human in
                                            let hid = human.id.uuidString
                                            let hColor = humanThemeColor(human)
                                            payerAvatar(id: hid, color: hColor, label: human.name) {
                                                if let data = human.avatarImageData, let img = UIImage(data: data) {
                                                    Image(uiImage: img)
                                                        .resizable().scaledToFill()
                                                        .frame(width: 38, height: 38)
                                                        .clipShape(Circle())
                                                } else {
                                                    Text(human.avatarEmoji).font(.system(size: 18))
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            GoDashedDivider().padding(.horizontal, 16)
                        }

                        if let payerName = selectedPayerName {
                            infoRow(icon: "creditcard.fill", label: "这笔钱由") {
                                Text(payerName)
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(petThemeColor)
                            }
                        }

                        // 日期行
                        infoRow(icon: "calendar", label: "日期") {
                            DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(petThemeColor)
                        }

                        // 备注行
                        infoRow(icon: "note.text", label: "备注") {
                            TextField("可选", text: $noteInput)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.trailing)
                        }

                        // 保存按钮
                        Button { saveExpense() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("保存花费")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isAmountValid ? petThemeColor : petThemeColor.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                        .disabled(!isAmountValid)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .presentationBackground(.clear)
        .presentationDetents([.fraction(0.70), .large])
        .presentationDragIndicator(.visible)
        .overlay(alignment: .bottom) {
            if showClaimToast {
                claimToastBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showClaimSheet) {
            if let firstInsurance = activeInsurances.first {
                AddInsuranceClaimSheet(
                    insurance: firstInsurance,
                    pet: pet,
                    prelinkedExpenseId: savedExpenseId
                )
            }
        }
        .onAppear {
            guard !humans.isEmpty else { selectedPayerId = nil; return }
            if let pid = preselectedPayerId, humans.contains(where: { $0.id.uuidString == pid }) {
                selectedPayerId = pid
            } else {
                let stored = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
                selectedPayerId = (!stored.isEmpty && humans.contains(where: { $0.id.uuidString == stored }))
                    ? stored : humans.first?.id.uuidString
            }
        }
    }

    // MARK: - Claim Toast Banner

    private var claimToastBanner: some View {
        Button {
            showClaimToast = false
            showClaimSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.arkInk)
                VStack(alignment: .leading, spacing: 2) {
                    Text("申请保险报销")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                    Text("向 \(activeInsurances.first?.productName ?? "保险公司") 提交报销申请")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.arkInk.opacity(0.7))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sub-views

    private func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.4))
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
        }
    }

    private func infoRow<Trailing: View>(icon: String, label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.4))
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func payerAvatar<Content: View>(id: String?, color: Color, label: String, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = selectedPayerId == id
        Button { selectedPayerId = id } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.18))
                        .frame(width: 38, height: 38)
                    content()
                    if isSelected {
                        Circle().strokeBorder(.white, lineWidth: 2).frame(width: 38, height: 38)
                    }
                }
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 56)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func humanThemeColor(_ human: Human) -> Color {
        let hex = human.themeColor
        return hex.count == 6 ? Color(hex: hex) : Color.goPrimary
    }

    private var selectedPayerName: String? {
        guard let selectedPayerId else { return nil }
        return humans.first(where: { $0.id.uuidString == selectedPayerId })?.name
    }

    private func saveExpense() {
        guard let amount = Double(amountInput.replacingOccurrences(of: ",", with: ".")) else { return }
        let payerId = selectedPayerId.flatMap { id in
            humans.contains(where: { $0.id.uuidString == id }) ? id : nil
        }
        let log = PetExpenseLog(date: date, amount: amount, category: selectedCategory, note: noteInput, pet: pet, executorId: payerId)
        modelContext.insert(log)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let reward = QuestManager.shared.awardAction(type: .expense, pet: pet, context: modelContext)
        CareLedgerService.record(
            occurredAt: log.date,
            actorKind: payerId == nil ? .unknown : .human,
            actorId: payerId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: selectedCategory.rawValue,
            amountValue: amount,
            amountUnit: "currency",
            note: noteInput,
            source: .detail,
            legacyModelName: "PetExpenseLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            context: modelContext
        )

        // 若是医疗类且宠物有活跃保险，显示报销快捷入口 Toast（3 秒后自动隐藏）
        if selectedCategory == .medical && !activeInsurances.isEmpty {
            savedExpenseId = log.id.uuidString
            withAnimation(.easeInOut(duration: 0.3)) { showClaimToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut(duration: 0.3)) { showClaimToast = false }
            }
        } else {
            dismiss()
        }
    }
}
