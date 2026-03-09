//
//  QuickWeightSheet.swift
//  Ohana
//
//  Quick Access 快速添加体重弹窗
//

import SwiftUI
import SwiftData

struct QuickWeightSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var weightText: String = ""
    @State private var recordDate: Date = Date()
    @State private var didSave = false
    @FocusState private var focused: Bool

    private var safeWeightText: String { weightText.replacingOccurrences(of: ",", with: ".") }
    private var isValid: Bool {
        guard let v = Double(safeWeightText), v > 0, v < 200 else { return false }
        return true
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()

            VStack(spacing: 20) {
                // 标题栏
                HStack {
                    Text("记录体重")
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

                // 体重输入
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0.0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .focused($focused)
                    Text("kg")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                }
                .padding(.horizontal, 20)

                // 日期选择 row
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("记录日期")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    DatePicker("", selection: $recordDate, in: ...Date(), displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(Color.goLime)
                        .colorScheme(.dark)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                // 保存按钮
                Button { saveWeight() } label: {
                    HStack(spacing: 8) {
                        if didSave {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                        }
                        Text(didSave ? "已保存" : "保存记录")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(
                        didSave ? Color.goTeal : (isValid ? Color.goLime : Color.goLime.opacity(0.4)),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .disabled(!isValid || didSave)
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear { focused = true }
    }

    private func saveWeight() {
        guard let v = Double(safeWeightText), v > 0 else { return }
        let log = PetWeightLog(date: recordDate, weight: v, pet: pet)
        modelContext.insert(log)
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        didSave = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }
}
