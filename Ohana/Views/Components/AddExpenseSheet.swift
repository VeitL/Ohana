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

    var body: some View {
        ZStack {
            ArkBackgroundView()
            VStack(spacing: 20) {
                // 标题栏
                HStack {
                    Text("快速记账")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20)

                // 金额输入
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("¥")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                    TextField("0.00", text: $amountInput)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, 20)

                // 支付人选择器
                if !humans.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("谁付的款")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // 无指定选项
                                Button { selectedPayerId = nil } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedPayerId == nil ? Color.goYellow : .white.opacity(0.1))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "questionmark")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(selectedPayerId == nil ? Color.arkInk : .white.opacity(0.5))
                                        }
                                        Text("未指定")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(selectedPayerId == nil ? .white : .white.opacity(0.4))
                                    }
                                }
                                .buttonStyle(.plain)

                                ForEach(humans) { human in
                                    let hid = human.id.uuidString
                                    let isSelected = selectedPayerId == hid
                                    let themeColor = humanThemeColor(human)
                                    Button { selectedPayerId = hid } label: {
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Circle()
                                                    .fill(isSelected ? themeColor : themeColor.opacity(0.2))
                                                    .frame(width: 40, height: 40)
                                                if let data = human.avatarImageData, let img = UIImage(data: data) {
                                                    Image(uiImage: img)
                                                        .resizable().scaledToFill()
                                                        .frame(width: 40, height: 40).clipShape(Circle())
                                                } else {
                                                    Text(human.avatarEmoji)
                                                        .font(.system(size: 20))
                                                }
                                                if isSelected {
                                                    Circle()
                                                        .strokeBorder(.white, lineWidth: 2)
                                                        .frame(width: 40, height: 40)
                                                }
                                            }
                                            Text(human.name)
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // 分类选择
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ExpenseCategory.allCases, id: \.rawValue) { cat in
                            Button { selectedCategory = cat } label: {
                                HStack(spacing: 5) {
                                    Text(cat.emoji).font(.system(size: 14))
                                    Text(cat.rawValue)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(selectedCategory == cat ? Color.arkInk : .white.opacity(0.6))
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(selectedCategory == cat ? Color.goYellow : .white.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // 备注
                HStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    TextField("备注（可选）", text: $noteInput)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                // 记录按钮
                Button { saveExpense() } label: {
                    Text("记录花费")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(
                            amountInput.isEmpty ? Color.goYellow.opacity(0.4) : Color.goYellow,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
                .disabled(amountInput.isEmpty)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear {
            // 默认选中当前活跃用户
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
