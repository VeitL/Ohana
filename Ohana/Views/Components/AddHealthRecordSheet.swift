//
//  AddHealthRecordSheet.swift
//  Ohana
//
//  T10: 健康记录添加页，含有效期输入
//

import SwiftUI
import SwiftData

/// 健康记录添加入口：菜单「预防护理 / 就诊记录」进入后在表单内再选细分类型
enum HealthRecordEntryMode: Hashable {
    case preventive
    case visit
}

struct AddHealthRecordSheet: View {
    let pet: Pet
    /// `nil`：固定类型（如免疫总览点按、宠物详情）；非 `nil`：显示类型胶囊
    let entryMode: HealthRecordEntryMode?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedType: HealthLogType

    @State private var date: Date = Date()
    @State private var name: String = ""   // N9: 疫苗/驱虫専用名称字段
    @State private var note: String = ""
    @State private var vetName: String = ""
    @State private var cost: String = ""
    @State private var hasExpiration: Bool = false
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var hasNextCheckup: Bool = false
    @State private var nextCheckupDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    init(pet: Pet, type: HealthLogType, entryMode: HealthRecordEntryMode? = nil) {
        self.pet = pet
        self.entryMode = entryMode
        _selectedType = State(initialValue: type)
    }

    // 根据类型推算标准有效期
    private func defaultExpirationDate(from base: Date) -> Date {
        let cal = Calendar.current
        switch selectedType {
        case .vaccine:           return cal.date(byAdding: .year,  value: 1, to: base) ?? base
        case .dewormingInternal: return cal.date(byAdding: .month, value: 3, to: base) ?? base
        case .dewormingExternal: return cal.date(byAdding: .month, value: 1, to: base) ?? base
        case .medication:        return cal.date(byAdding: .month, value: 1, to: base) ?? base
        default:                 return cal.date(byAdding: .year,  value: 1, to: base) ?? base
        }
    }

    private var expirationHint: String {
        switch selectedType {
        case .vaccine:           return "推荐：1 年"
        case .dewormingInternal: return "推荐：3 个月"
        case .dewormingExternal: return "推荐：1 个月"
        case .medication:        return "推荐：1 个月"
        default:                 return ""
        }
    }

    // N9: 疫苗/驱虫显示专用名称字段
    private var showsNameField: Bool {
        selectedType == .vaccine || selectedType == .dewormingInternal || selectedType == .dewormingExternal || selectedType == .medication
    }

    // Bug8: 使用 needsExpiration 属性
    private var showsExpiration: Bool { selectedType.needsExpiration }
    
    // 体检记录显示下次提醒日期
    private var showsNextCheckup: Bool { selectedType == .checkup }

    private var typeLabel: String {
        switch selectedType {
        case .vaccine:           return "疫苗接种"
        case .medication:        return "驱虫用药"
        case .dewormingInternal: return "体内驱虫"
        case .dewormingExternal: return "体外驱虫"
        case .checkup:           return "体检记录"
        case .surgery:           return "就诊记录"
        default:                 return selectedType.rawValue
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
                            Text(selectedType.emoji).font(.system(size: 32))
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        if let mode = entryMode {
                            healthSubtypeCapsules(mode: mode)
                        }

                        // N9: 疫苗/驱虫名称字段（面板最顶部）
                        if showsNameField {
                            fieldCard {
                                HStack {
                                    Image(systemName: "pencil.line")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.goPrimary)
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
                                .tint(Color.goPrimary)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        // 有效期（疫苗/驱虫才显示）
                        if showsExpiration {
                            fieldCard {
                                VStack(spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("设置有效期")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.primary)
                                            if !expirationHint.isEmpty {
                                                Text(expirationHint)
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Toggle("", isOn: $hasExpiration)
                                            .tint(Color.goPrimary)
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
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(Color.arkInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(typeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }
            .onAppear {
                applyDefaultsForSelectedType()
            }
            .onChange(of: selectedType) { _, _ in
                applyDefaultsForSelectedType()
            }
            .onChange(of: date) { _, newDate in
                // 当用户修改记录日期时，同步更新有效期（如果尚未手动改过）
                if hasExpiration {
                    expirationDate = defaultExpirationDate(from: newDate)
                }
            }
        }
    }

    @ViewBuilder
    private func healthSubtypeCapsules(mode: HealthRecordEntryMode) -> some View {
        let options: [(HealthLogType, String)] = {
            switch mode {
            case .preventive:
                return [
                    (.vaccine, "💉 疫苗"),
                    (.dewormingInternal, "🐛 体内驱虫"),
                    (.dewormingExternal, "🛡️ 体外驱虫"),
                    (.checkup, "🩺 体检"),
                ]
            case .visit:
                return [
                    (.surgery, "🏥 就诊"),
                    (.general, "📋 常规记录"),
                ]
            }
        }()

        VStack(alignment: .leading, spacing: 10) {
            Text("记录类型")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.0) { t, label in
                        Button {
                            selectedType = t
                        } label: {
                            Text(label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(selectedType == t ? Color.arkInk : .primary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(selectedType == t ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func applyDefaultsForSelectedType() {
        switch selectedType {
        case .vaccine:
            if name.isEmpty { name = "\(pet.name)接种疫苗" }
            hasExpiration = true
            expirationDate = defaultExpirationDate(from: date)
        case .dewormingInternal, .dewormingExternal, .medication:
            if name.isEmpty { name = "\(pet.name)\(typeLabel)" }
            hasExpiration = true
            expirationDate = defaultExpirationDate(from: date)
        default:
            break
        }
    }

    private func fieldCard<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func save() {
        // N9: 名称字段内容写入 note（如果填了名称则用它，否则用备注）
        let finalNote = showsNameField ? (name.isEmpty ? note : name + (note.isEmpty ? "" : " - " + note)) : note
        let log = PetHealthLog(date: date, type: selectedType, note: finalNote, pet: pet)
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

        // 自动在日历创建到期提醒事件（疫苗 / 体内驱虫 / 体外驱虫）
        if showsExpiration && hasExpiration {
            autoCreateReminderEvent(on: expirationDate)
        }

        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func autoCreateReminderEvent(on dueDate: Date) {
        let eventType: EventType
        let emoji: String
        switch selectedType {
        case .vaccine:
            eventType = .vaccine
            emoji = "💉"
        case .dewormingInternal:
            eventType = .internalDeworming
            emoji = "🪱"
        case .dewormingExternal:
            eventType = .externalDeworming
            emoji = "🛡️"
        default:
            return  // 其他类型不自动创建
        }
        let recordName = name.isEmpty ? typeLabel : name
        let event = Event(
            title: "\(emoji) \(pet.name) · \(recordName)到期提醒",
            startDate: dueDate,
            isAllDay: true,
            eventType: eventType.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        modelContext.insert(event)
    }
}
