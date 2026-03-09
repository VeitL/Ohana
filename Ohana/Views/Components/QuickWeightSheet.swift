//
//  QuickWeightSheet.swift
//  Ohana
//
//  Quick Access 快速添加体重弹窗（presentationDetents .height(280)）
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
            // 玻璃风格背景
            Color.goDarkBlue.ignoresSafeArea()
            LinearGradient(
                colors: [Color.goPrimary.opacity(0.25), Color.goDarkBlue],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 标题行
                HStack {
                    HStack(spacing: 10) {
                        if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 38, height: 38)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                        } else {
                            Text(pet.speciesEmoji)
                                .font(.system(size: 26))
                                .frame(width: 38, height: 38)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("记录体重")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text(pet.name)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                // 玻璃风格输入大卡片
                VStack(spacing: 20) {
                    // 巨大数字 + kg
                    VStack(spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            TextField("0.0", text: $weightText)
                                .font(.system(size: 72, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .focused($focused)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity)
                            Text("kg")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goLime)
                                .padding(.bottom, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // 细分割线
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }

                    // 日期选择器
                    HStack {
                        Label("日期", systemImage: "calendar")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        DatePicker("", selection: $recordDate, in: ...Date(), displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.goLime)
                            .colorScheme(.dark)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                Spacer(minLength: 20)

                // 保存按钮
                Button {
                    guard let v = Double(safeWeightText), v > 0 else { return }
                    let log = PetWeightLog(date: recordDate, weight: v, pet: pet)
                    modelContext.insert(log)
                    modelContext.safeSave()
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    didSave = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
                } label: {
                    HStack(spacing: 8) {
                        if didSave {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                        }
                        Text(didSave ? "已保存 ✓" : "保存记录")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        didSave ? Color.goTeal : (isValid ? Color.goLime : Color.goLime.opacity(0.25)),
                        in: Capsule()
                    )
                }
                .disabled(!isValid || didSave)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onAppear { focused = true }
    }
}
