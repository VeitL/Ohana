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

    private var themeColor: Color { Color(hex: pet.themeColorHex.isEmpty ? "C8FF00" : pet.themeColorHex) }

    var body: some View {
        VStack(spacing: 0) {
                // ── 顶栏
                HStack {
                    // 宠物头像 + 名字
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(themeColor.opacity(0.22))
                                .frame(width: 40, height: 40)
                            if let data = pet.avatarImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                                    .font(.system(size: 20))
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pet.name)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("记录体重")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
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
                .padding(.bottom, 24)

                // ── 体重大数字输入卡
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0.0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.4)
                        .focused($focused)
                        .multilineTextAlignment(.center)
                    Text("kg")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(themeColor)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 20)

                // ── 上次体重提示
                if let last = pet.weightLogs.sorted(by: { $0.date > $1.date }).first {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("上次记录：\(last.weight, specifier: "%.1f") kg")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.top, 10)
                }

                Spacer(minLength: 20)

                // ── 日期选择
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.4))
                    Text("记录日期")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                    Spacer()
                    DatePicker("", selection: $recordDate, in: ...Date(), displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(themeColor)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)

                // ── 保存按钮
                Button { saveWeight() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: didSave ? "checkmark.circle.fill" : "scalemass.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(didSave ? "已保存 ✓" : "保存记录")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        didSave ? Color.goTeal : (isValid ? themeColor : themeColor.opacity(0.35)),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                }
                .disabled(!isValid || didSave)
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
        .background(.ultraThinMaterial)
        .presentationBackground(.clear)
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
