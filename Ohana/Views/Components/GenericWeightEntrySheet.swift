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
    @State private var weightUnit: String = "kg"   // "kg" | "g"

    private var accentColor: Color {
        switch target {
        case .pet(let p): return Color(hex: p.themeColorHex.isEmpty ? "C8FF00" : p.themeColorHex)
        case .human: return Color.goPrimary
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

    private var weightInKgForBcs: Double? {
        guard let w = parsedWeight, w > 0 else { return nil }
        return weightUnit == "g" ? w / 1000.0 : w
    }

    private var autoBcsForPet: Int? {
        guard case .pet(let p) = target, let kg = weightInKgForBcs else { return nil }
        return PetBodyConditionEstimator.suggestedBCS(for: p, weightKg: kg)
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()
            VStack(spacing: 20) {
                // 标题栏
                HStack {
                    Text("记录体重")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20)

                // 体重大数字输入 + 单位切换
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField(weightUnit == "g" ? "0" : "0.0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .focused($inputFocused)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.5)
                    // 单位切换胶囊
                    HStack(spacing: 0) {
                        ForEach(["kg", "g"], id: \.self) { unit in
                            Button {
                                weightUnit = unit
                            } label: {
                                Text(unit)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(weightUnit == unit ? .black : .primary.opacity(0.4))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(weightUnit == unit ? accentColor : Color.clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(.primary.opacity(0.08), in: Capsule())
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 20)

                // 日期行
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.4))
                    Text("日期")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
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
                        .foregroundStyle(.primary.opacity(0.4))
                    Text(entityName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    avatarView
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                // BCS：按物种/品种/年龄与本次体重自动估算（非诊断）
                if case .pet = target {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.4))
                            Text("体型评分 BCS")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        if let b = autoBcsForPet {
                            HStack(spacing: 10) {
                                Text("\(b)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(bcsColor(b))
                                    .frame(width: 44, height: 44)
                                    .background(bcsColor(b).opacity(0.2), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bcsLabel(b))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text("根据品种、年龄与本次体重自动估算")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.45))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20)
                        } else {
                            Text("输入有效体重后显示估算分")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.35))
                                .padding(.horizontal, 20)
                        }
                    }
                }

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
        .onAppear { inputFocused = true }
    }

    // BCS 1-3 偏瘦(蓝), 4-5 理想(绿), 6-7 偏胖(橙), 8-9 肥胖(红)
    private func bcsColor(_ score: Int) -> Color {
        switch score {
        case 1...3: return Color(hex: "4ECDC4")
        case 4...5: return Color.goPrimary
        case 6...7: return Color(hex: "FFD93D")
        default:    return Color(hex: "FF6B6B")
        }
    }

    private func bcsLabel(_ score: Int) -> String {
        switch score {
        case 1: return "极度消瘦"
        case 2: return "消瘦"
        case 3: return "偏瘦"
        case 4: return "理想偏瘦"
        case 5: return "理想体型"
        case 6: return "理想偏胖"
        case 7: return "偏胖"
        case 8: return "肥胖"
        case 9: return "极度肥胖"
        default: return ""
        }
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
            let bcs = autoBcsForPet ?? 0
            let log = PetWeightLog(date: selectedDate, weight: w, weightUnit: weightUnit, bcsScore: bcs, pet: p)
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
