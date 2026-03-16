//
//  AddExpenseSheet.swift
//  Ohana
//
//  B67: 花费快捷添加半屏 Sheet
//

import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Human.createdAt) private var humans: [Human]

    @State private var amountInput = ""
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var noteInput = ""
    @State private var date = Date()
    @State private var selectedPayerId: String? = nil

    private var petThemeColor: Color {
        Color(hex: pet.themeColorHex.isEmpty ? "FFF44F" : pet.themeColorHex)
    }
    private var isAmountValid: Bool {
        guard let v = Double(amountInput.replacingOccurrences(of: ",", with: ".")), v > 0 else { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {

                // ── 顶栏：宠物 header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(petThemeColor.opacity(0.22))
                            .frame(width: 44, height: 44)
                        if let data = pet.avatarImageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                                .font(.system(size: 22))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.name)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("快速记账")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.4))
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
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {

                        // ── 金额输入大卡
                        VStack(spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("¥")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundStyle(petThemeColor)
                                TextField("0.00", text: $amountInput)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 52, weight: .black, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .minimumScaleFactor(0.4)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 16)

                            GoDashedDivider()
                                .padding(.horizontal, 20)
                                .padding(.bottom, 4)

                            // 分类 chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(ExpenseCategory.allCases, id: \.rawValue) { cat in
                                        Button { selectedCategory = cat } label: {
                                            HStack(spacing: 5) {
                                                Text(cat.emoji).font(.system(size: 13))
                                                Text(cat.rawValue)
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    .foregroundStyle(selectedCategory == cat ? Color.arkInk : .primary.opacity(0.6))
                                            }
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(
                                                selectedCategory == cat ? petThemeColor : Color.primary.opacity(0.08),
                                                in: Capsule()
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                        }
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 16)

                        // ── 支付人
                        if !humans.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.primary.opacity(0.4))
                                    Text("谁付的款")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.4))
                                }
                                .padding(.horizontal, 20)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        // 未指定
                                        Button { selectedPayerId = nil } label: {
                                            VStack(spacing: 5) {
                                                ZStack {
                                                    Circle()
                                                        .fill(selectedPayerId == nil ? petThemeColor : Color.primary.opacity(0.08))
                                                        .frame(width: 44, height: 44)
                                                    Image(systemName: "questionmark")
                                                        .font(.system(size: 18, weight: .bold))
                                                        .foregroundStyle(selectedPayerId == nil ? Color.arkInk : .primary.opacity(0.4))
                                                }
                                                Text("未指定")
                                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(selectedPayerId == nil ? Color.primary : Color.primary.opacity(0.4))
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        ForEach(humans) { human in
                                            let hid = human.id.uuidString
                                            let isSelected = selectedPayerId == hid
                                            let hColor = humanThemeColor(human)
                                            Button { selectedPayerId = hid } label: {
                                                VStack(spacing: 5) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(isSelected ? hColor : hColor.opacity(0.18))
                                                            .frame(width: 44, height: 44)
                                                        if let data = human.avatarImageData, let img = UIImage(data: data) {
                                                            Image(uiImage: img)
                                                                .resizable().scaledToFill()
                                                                .frame(width: 44, height: 44)
                                                                .clipShape(Circle())
                                                        } else {
                                                            Text(human.avatarEmoji)
                                                                .font(.system(size: 22))
                                                        }
                                                        if isSelected {
                                                            Circle()
                                                                .strokeBorder(.white, lineWidth: 2.5)
                                                                .frame(width: 44, height: 44)
                                                        }
                                                    }
                                                    Text(human.name)
                                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                        .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.4))
                                                        .lineLimit(1)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(.horizontal, 16)
                        }

                        // ── 日期 + 备注
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.4))
                                Text("日期")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.4))
                                Spacer()
                                DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(petThemeColor)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)

                            GoDashedDivider()
                                .padding(.horizontal, 16)

                            HStack(spacing: 10) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.4))
                                TextField("备注（可选）", text: $noteInput)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 16)

                        // ── 记录按钮
                        Button { saveExpense() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "yensign.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("记录花费")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                isAmountValid ? petThemeColor : petThemeColor.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                        }
                        .disabled(!isAmountValid)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
        }
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            let stored = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
            if !stored.isEmpty { selectedPayerId = stored }
        }
    }

    private func humanThemeColor(_ human: Human) -> Color {
        let hex = human.themeColor
        if hex.count == 6 { return Color(hex: hex) }
        return Color.goLime
    }

    private func saveExpense() {
        guard let amount = Double(amountInput.replacingOccurrences(of: ",", with: ".")) else { return }
        let log = PetExpenseLog(date: date, amount: amount, category: selectedCategory, note: noteInput, pet: pet, executorId: selectedPayerId)
        modelContext.insert(log)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        QuestManager.shared.awardAction(type: .expense, pet: pet, context: modelContext)
        dismiss()
    }
}
