//
//  GenericWeightEntrySheet.swift
//  Ohana
//
//  统一体重输入弹窗 — 玻璃风格，巨大数字，支持宠物和人类
//

import SwiftUI
import SwiftData

struct GenericWeightEntrySheet: View {
    enum Target {
        case pet(Pet)
        case human(Human)
    }

    let target: Target
    var onSaved: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    @State private var weightText = ""
    @State private var selectedDate = Date()

    private var accentColor: Color {
        switch target {
        case .pet(let p): return Color(hex: p.themeColorHex.isEmpty ? "C8FF00" : p.themeColorHex)
        case .human: return Color.goLime
        }
    }

    private var entityName: String {
        switch target {
        case .pet(let p): return p.name
        case .human(let h): return h.name
        }
    }

    private var parsedWeight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool { (parsedWeight ?? 0) > 0 }

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

                // 体重大数字输入
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0.0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .focused($inputFocused)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                    Text("kg")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                }
                .padding(.horizontal, 20)

                // 日期行
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("日期")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goLime)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                // 记录对象行
                HStack(spacing: 10) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(entityName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    avatarView
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                // 保存按钮
                Button { save() } label: {
                    Text("保存体重记录")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(
                            isValid ? Color.goLime : Color.goLime.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        switch target {
        case .pet(let p):
            Group {
                if let data = p.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Text(p.avatarEmoji.isEmpty ? p.speciesEmoji : p.avatarEmoji)
                        .font(.system(size: 30))
                }
            }
        case .human(let h):
            Group {
                if let data = h.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Text(h.avatarEmoji)
                        .font(.system(size: 30))
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard let w = parsedWeight, w > 0 else { return }
        switch target {
        case .pet(let p):
            let log = PetWeightLog(date: selectedDate, weight: w, pet: p)
            modelContext.insert(log)
        case .human(let h):
            let log = HumanWeightLog(date: selectedDate, weight: w, human: h)
            modelContext.insert(log)
            h.weightLogs.append(log)
        }
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSaved?()
        dismiss()
    }
}
