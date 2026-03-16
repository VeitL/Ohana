//
//  AddHealthRecordSheet.swift
//  Ohana
//
//  T10: 健康记录添加页，含有效期输入
//

import SwiftUI
import SwiftData

struct AddHealthRecordSheet: View {
    let pet: Pet
    let type: HealthLogType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date = Date()
    @State private var name: String = ""   // N9: 疫苗/驱虫専用名称字段
    @State private var note: String = ""
    @State private var vetName: String = ""
    @State private var cost: String = ""
    @State private var hasExpiration: Bool = false
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var hasNextCheckup: Bool = false
    @State private var nextCheckupDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    // N9: 疫苗/驱虫显示专用名称字段
    private var showsNameField: Bool {
        type == .vaccine || type == .dewormingInternal || type == .dewormingExternal || type == .medication
    }

    // Bug8: 使用 needsExpiration 属性
    private var showsExpiration: Bool { type.needsExpiration }
    
    // 体检记录显示下次提醒日期
    private var showsNextCheckup: Bool { type == .checkup }

    private var typeLabel: String {
        switch type {
        case .vaccine:           return "疫苗接种"
        case .medication:        return "驱虫用药"
        case .dewormingInternal: return "体内驱虫"
        case .dewormingExternal: return "体外驱虫"
        case .checkup:           return "体检记录"
        case .surgery:           return "就诊记录"
        default:                 return type.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()

                ScrollView {
                    VStack(spacing: 20) {
                        // 宠物信息行
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color(hex: pet.themeColorHex).opacity(0.25))
                                    .frame(width: 48, height: 48)
                                if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                                    Image(uiImage: ui).resizable().scaledToFill()
                                        .frame(width: 48, height: 48).clipShape(Circle())
                                } else {
                                    Text(pet.avatarEmoji).font(.system(size: 26))
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name)
                                    .font(OhanaFont.body(.black))
                                    .foregroundStyle(.primary)
                                Text(typeLabel)
                                    .font(OhanaFont.caption(.medium))
                                    .foregroundStyle(Color.goTeal)
                            }
                            Spacer()
                            Text(type.emoji).font(.system(size: 32))
                        }
                        .padding(16)
                        .ohanaStandardCard(cornerRadius: 16)

                        // N9: 疫苗/驱虫名称字段（面板最顶部）
                        if showsNameField {
                            fieldCard {
                                HStack {
                                    Image(systemName: "pencil.line")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.goLime)
                                        .frame(width: 22)
                                    TextField("名称（如：狂犬疫苗三联苗）", text: $name)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }

                        // 日期
                        fieldCard {
                            DatePicker("记录日期", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(Color.goLime)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        // 有效期（疫苗/驱虫才显示）
                        if showsExpiration {
                            fieldCard {
                                VStack(spacing: 10) {
                                    HStack {
                                        Text("设置有效期")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Toggle("", isOn: $hasExpiration)
                                            .tint(Color.goLime)
                                            .labelsHidden()
                                    }
                                    if hasExpiration {
                                        DatePicker("有效期至", selection: $expirationDate, in: date..., displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .tint(Color.goYellow)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary.opacity(0.8))
                                    }
                                }
                            }
                        }
                        
                        // 下次体检提醒（体检记录才显示）
                        if showsNextCheckup {
                            fieldCard {
                                VStack(spacing: 10) {
                                    HStack {
                                        Text("下次体检提醒")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Toggle("", isOn: $hasNextCheckup)
                                            .tint(Color.goTeal)
                                            .labelsHidden()
                                    }
                                    if hasNextCheckup {
                                        DatePicker("提醒日期", selection: $nextCheckupDate, in: date..., displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .tint(Color.goTeal)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary.opacity(0.8))
                                    }
                                }
                            }
                        }

                        // 医生 / 诊所
                        fieldCard {
                            HStack {
                                Image(systemName: "stethoscope")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.goTeal)
                                    .frame(width: 22)
                                TextField("医生 / 诊所（可选）", text: $vetName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // 费用
                        fieldCard {
                            HStack {
                                Image(systemName: "yensign.circle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.goYellow)
                                    .frame(width: 22)
                                TextField("费用（可选）", text: $cost)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // 备注
                        fieldCard {
                            HStack(alignment: .top) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.4))
                                    .frame(width: 22)
                                    .padding(.top, 2)
                                TextField("备注 / 笔记（可选）", text: $note, axis: .vertical)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(3...6)
                            }
                        }

                        // 保存按钮
                        Button(action: save) {
                            Text("保存记录")
                                .font(OhanaFont.headline(.black))
                                .foregroundStyle(Color.arkInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.goLime, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(typeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }
            .onAppear {
                // N9: 疫苗/驱虫默认名称 + 默认开启有效期
                if type == .vaccine {
                    if name.isEmpty { name = "\(pet.name)接种疫苗" }
                    hasExpiration = true
                } else if type == .dewormingInternal || type == .dewormingExternal || type == .medication {
                    if name.isEmpty { name = "\(pet.name)\(typeLabel)" }
                    hasExpiration = true
                }
            }
        }
    }

    private func fieldCard<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        UltimateGlassCard {
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func save() {
        // N9: 名称字段内容写入 note（如果填了名称则用它，否则用备注）
        let finalNote = showsNameField ? (name.isEmpty ? note : name + (note.isEmpty ? "" : " - " + note)) : note
        let log = PetHealthLog(date: date, type: type, note: finalNote, pet: pet)
        log.vetName = vetName
        log.cost = Double(cost) ?? 0
        log.expirationDate = (showsExpiration && hasExpiration) ? expirationDate : nil
        log.nextCheckupDate = (showsNextCheckup && hasNextCheckup) ? nextCheckupDate : nil
        modelContext.insert(log)

        // 同步费用记录
        if let amount = Double(cost), amount > 0 {
            let expense = PetExpenseLog(date: date, amount: amount, category: .medical, note: typeLabel, pet: pet)
            modelContext.insert(expense)
        }

        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
