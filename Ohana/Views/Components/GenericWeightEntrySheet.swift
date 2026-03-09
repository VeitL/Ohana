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
    @Query(sort: \Human.createdAt) private var humans: [Human]

    @FocusState private var inputFocused: Bool

    @State private var weightText = ""
    @State private var selectedDate = Date()
    @State private var selectedRecorderId: String? = nil

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
                        .foregroundStyle(accentColor)
                }
                .padding(.horizontal, 20)

                // 记录人选择器
                if !humans.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("谁记录的")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // 无指定选项
                                Button { selectedRecorderId = nil } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedRecorderId == nil ? accentColor : .white.opacity(0.1))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "questionmark")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(selectedRecorderId == nil ? Color.arkInk : .white.opacity(0.5))
                                        }
                                        Text("未指定")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(selectedRecorderId == nil ? .white : .white.opacity(0.4))
                                    }
                                }
                                .buttonStyle(.plain)

                                ForEach(humans) { human in
                                    let hid = human.id.uuidString
                                    let isSelected = selectedRecorderId == hid
                                    let themeColor = humanThemeColor(human)
                                    Button { selectedRecorderId = hid } label: {
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
                        .tint(accentColor)
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
                            isValid ? accentColor : accentColor.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear { 
            inputFocused = true 
            let stored = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
            if !stored.isEmpty { selectedRecorderId = stored }
        }
    }

    private func humanThemeColor(_ human: Human) -> Color {
        let hex = human.themeColor
        if hex.count == 6 { return Color(hex: hex) }
        return Color.goLime
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
            QuestManager.shared.awardAction(type: .weight, pet: p, context: modelContext) // Also reward user
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
