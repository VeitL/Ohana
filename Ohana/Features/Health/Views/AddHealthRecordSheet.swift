//
//  AddHealthRecordSheet.swift
//  Ohana
//
//  T10: 健康记录添加页，含有效期输入
//

import SwiftData
import SwiftUI

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
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var selectedType: HealthLogType

    @State private var date: Date = .init()
    @State private var name: String = "" // N9: 疫苗/驱虫専用名称字段
    @State private var note: String = ""
    @State private var vetName: String = ""
    @State private var cost: String = ""
    @State private var hasExpiration: Bool = false
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var hasNextCheckup: Bool = false
    @State private var nextCheckupDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(pet: Pet, type: HealthLogType, entryMode: HealthRecordEntryMode? = nil) {
        self.pet = pet
        self.entryMode = entryMode
        _selectedType = State(initialValue: type)
    }

    // 根据类型推算标准有效期
    private func defaultExpirationDate(from base: Date) -> Date {
        let cal = Calendar.current
        switch selectedType {
        case .vaccine: return cal.date(byAdding: .year, value: 1, to: base) ?? base
        case .dewormingInternal: return cal.date(byAdding: .month, value: 3, to: base) ?? base
        case .dewormingExternal: return cal.date(byAdding: .month, value: 1, to: base) ?? base
        case .medication: return cal.date(byAdding: .month, value: 1, to: base) ?? base
        default: return cal.date(byAdding: .year, value: 1, to: base) ?? base
        }
    }

    private var expirationHint: String {
        switch selectedType {
        case .vaccine: "推荐：1 年"
        case .dewormingInternal: "推荐：3 个月"
        case .dewormingExternal: "推荐：1 个月"
        case .medication: "推荐：1 个月"
        default: ""
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
        case .vaccine: "疫苗接种"
        case .medication: "驱虫用药"
        case .dewormingInternal: "体内驱虫"
        case .dewormingExternal: "体外驱虫"
        case .checkup: "体检记录"
        case .surgery: "就诊记录"
        default: selectedType.rawValue
        }
    }

    private var activeExecutorID: String? {
        activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // 宠物信息行
                        HStack(spacing: 12) {
                            PetAvatarPortraitView(
                                imageData: pet.avatarImageData,
                                fallbackText: pet.avatarEmoji,
                                themeColor: Color(hex: pet.safeThemeColorHex),
                                size: 48,
                                backgroundOpacity: 0.25
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name)
                                    .font(OhanaFont.body(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(typeLabel)
                                    .font(OhanaFont.caption(.medium))
                                    .foregroundStyle(Color.goTeal)
                            }
                            Spacer()
                            Text(selectedType.emoji).font(OhanaFont.adaptive(size: 32)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        }
                        .padding(16)
                        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))

                        if let mode = entryMode {
                            healthSubtypeCapsules(mode: mode)
                        }

                        // N9: 疫苗/驱虫名称字段（面板最顶部）
                        if showsNameField {
                            fieldCard {
                                HStack {
                                    Image(systemName: "pencil.line") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.goPrimary)
                                        .frame(width: 22)
                                    TextField("名称（如：狂犬疫苗三联苗）", text: $name) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                }
                            }
                        }

                        // 日期
                        fieldCard {
                            DatePicker("记录日期", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(Color.goPrimary)
                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }

                        // 有效期（疫苗/驱虫才显示）
                        if showsExpiration {
                            fieldCard {
                                VStack(spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("设置有效期")
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.ohanaPrimaryText)
                                            if !expirationHint.isEmpty {
                                                Text(expirationHint)
                                                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                    .foregroundStyle(Color.ohanaSecondaryText)
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
                                            .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
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
                                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(Color.ohanaPrimaryText)
                                        Spacer()
                                        Toggle("", isOn: $hasNextCheckup)
                                            .tint(Color.goTeal)
                                            .labelsHidden()
                                    }
                                    if hasNextCheckup {
                                        DatePicker("提醒日期", selection: $nextCheckupDate, in: date..., displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .tint(Color.goTeal)
                                            .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                                    }
                                }
                            }
                        }

                        // 医生 / 诊所
                        fieldCard {
                            HStack {
                                Image(systemName: "stethoscope") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.goTeal)
                                    .frame(width: 22)
                                TextField("医生 / 诊所（可选）", text: $vetName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                    .font(OhanaFont.adaptive(size: 15, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText)
                            }
                        }

                        // 费用
                        fieldCard {
                            HStack {
                                Image(systemName: AppCurrency.systemIconName)
                                    .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.goYellow)
                                    .frame(width: 22)
                                InlineNumericInput(
                                    text: $cost,
                                    placeholder: "0",
                                    maxFractionDigits: 2,
                                    accent: Color.goYellow,
                                    step: 10,
                                    valueFont: .system(size: 15, weight: .medium, design: .rounded),
                                    valueAlignment: .leading,
                                    fill: Color.clear,
                                    cornerRadius: OhanaRadius.chip,
                                    horizontalPadding: 4,
                                    verticalPadding: 0
                                )
                            }
                        }

                        // 备注
                        fieldCard {
                            HStack(alignment: .top) {
                                Image(systemName: "note.text") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                    .frame(width: 22)
                                    .padding(.top, 2)
                                TextField("备注 / 笔记（可选）", text: $note, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                    .font(OhanaFont.adaptive(size: 15, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(3 ... 6)
                            }
                        }

                        // 保存按钮
                        Button(action: save) {
                            HStack(spacing: 8) {
                                Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                                    .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                Text(isSaving ? "保存中" : "保存记录")
                                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            }
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                isSaving ? Color.ohanaControlFill : Color.goPrimary,
                                in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isSaving)

                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(typeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ohanaCardSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
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
            .onDisappear {
                commandQueue.cancelAll()
            }
        }
    }

    @ViewBuilder
    private func healthSubtypeCapsules(mode: HealthRecordEntryMode) -> some View {
        let options: [(HealthLogType, String)] = switch mode {
        case .preventive:
            [
                (.vaccine, "💉 疫苗"),
                (.dewormingInternal, "🐛 体内驱虫"),
                (.dewormingExternal, "🛡️ 体外驱虫"),
                (.checkup, "🩺 体检")
            ]
        case .visit:
            [
                (.surgery, "🏥 就诊"),
                (.general, "📋 常规记录")
            ]
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("记录类型")
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.0) { t, label in
                        Button {
                            selectedType = t
                        } label: {
                            Text(label)
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(selectedType == t ? Color.arkInk : .primary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(selectedType == t ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
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

    private func fieldCard(@ViewBuilder content: @escaping () -> some View) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let input = PetHealthRecordCommandInput(
            type: selectedType,
            date: date,
            name: name,
            note: note,
            vetName: vetName,
            cost: CountryDecimalInput.parse(cost, countryCode: AppCountry.code) ?? 0,
            expirationDate: (showsExpiration && hasExpiration) ? expirationDate : nil,
            nextCheckupDate: (showsNextCheckup && hasNextCheckup) ? nextCheckupDate : nil,
            executorId: activeExecutorID,
            source: .detail,
            includesNameInNote: showsNameField
        )
        let command = DomainCommand.petHealthRecord(petID: pet.id, type: selectedType.rawValue)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            PetHealthCommandExecutor(context: modelContext, services: appServices).recordHealth(
                pet: pet,
                input: input,
                note: "pet.health.record"
            )
            dismiss()
        }
    }
}
