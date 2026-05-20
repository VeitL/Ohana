//
//  AddPetMedicationSheet.swift
//  Ohana
//
//  新开 / 编辑用药疗程（不改 PetMedication 字段定义）
//

import SwiftUI
import SwiftData

struct AddPetMedicationSheet: View {
    let pet: Pet
    /// 传入则进入编辑模式
    var existing: PetMedication? = nil
    var isInlinePopup: Bool = false
    var onClose: (() -> Void)? = nil
    var onSaved: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var name = ""
    @State private var doseAmount = ""
    @State private var doseUnit = "片"
    private let doseUnits = ["片", "粒", "ml", "g", "次"]

    @State private var frequency: PetMedicationFrequency = .daily
    @State private var doseMinutes: [Int] = PetMedicationSchedulePlan.defaultDoseMinutes(for: .daily)

    @State private var hasCourseEnd = true
    @State private var startDate = Date()
    @State private var coursePresetDays: Int? = 7
    @State private var customCourseDays = "7"
    @State private var showsCourseDaysKeypad = false

    @State private var administrationTag: String? = nil
    private let administrationOptions = ["拌饭", "直接喂", "溶水", "零食包裹"]

    @State private var remainingText = ""
    @State private var notes = ""

    @State private var colorHex = "FF6B6B"
    private let colorPresets = ["FF6B6B", "FF9500", "FFDD44", "4ECDC4", "5B9FFF", "A78BFA"]

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var chromeAccent: Color { colorScheme == .dark ? Color.goPrimary : Color.goBlue }
    private var l: L10n { L10n(appLanguage) }
    private var commonMedicationNames: [String] {
        PetMedicationQuickCatalog.names(for: appCountry)
    }
    private var frequencyOptions: [(PetMedicationFrequency, String)] {
        [
            (.daily, l.tr(zh: "每天1次", en: "Once daily", de: "1x täglich")),
            (.twiceDaily, l.tr(zh: "每天2次", en: "Twice daily", de: "2x täglich")),
            (.threeTimesDaily, l.tr(zh: "每天3次", en: "3 times daily", de: "3x täglich")),
            (.everyOtherDay, l.tr(zh: "隔天", en: "Every other day", de: "Alle 2 Tage")),
            (.weekly, l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich")),
            (.asNeeded, l.tr(zh: "按需", en: "As needed", de: "Nach Bedarf"))
        ]
    }

    private var composedDosage: String {
        let amt = doseAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if amt.isEmpty { return doseUnit }
        return "\(amt) \(doseUnit)"
    }

    private var parsedEndDate: Date? {
        guard hasCourseEnd else { return nil }
        return Calendar.current.date(byAdding: .day, value: resolvedCourseDays, to: Calendar.current.startOfDay(for: startDate))
    }

    private var resolvedCourseDays: Int {
        let raw = customCourseDays.trimmingCharacters(in: .whitespacesAndNewlines)
        if let days = Int(raw), days > 0 {
            return min(days, 365)
        }
        return max(1, coursePresetDays ?? 7)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var scheduledDoseCount: Int {
        PetMedicationSchedulePlan.dosesPerDay(for: frequency)
    }

    var body: some View {
        Group {
            if isInlinePopup {
                inlinePopupBody
            } else {
                navigationBody
            }
        }
        .onAppear(perform: loadExistingMedication)
        .onChange(of: frequency) { _, newValue in
            withAnimation(GoMotion.selection) {
                doseMinutes = PetMedicationSchedulePlan.normalizedDoseMinutes(
                    doseMinutes,
                    count: PetMedicationSchedulePlan.dosesPerDay(for: newValue),
                    frequency: newValue
                )
            }
        }
    }

    private var navigationBody: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        medicationFields
                        saveButton
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(existing == nil ? "添加用药记录" : "编辑用药")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "返回", en: "Back", de: "Zurück")) { close() }
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) { saveAfterKeyboardDismiss() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                        .foregroundStyle(canSave ? chromeAccent : Color.ohanaSecondaryText)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                        GoKeyboard.dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(chromeAccent)
                }
            }
        }
    }

    private var inlinePopupBody: some View {
        VStack(spacing: 0) {
            OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                .padding(.top, 8)

            HStack(spacing: 12) {
                Image(systemName: "pill.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(chromeAccent)
                    .frame(width: 42, height: 42)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? l.tr(zh: "添加药物", en: "Add medication", de: "Medikament hinzufügen") : l.tr(zh: "编辑药物", en: "Edit medication", de: "Medikament bearbeiten"))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "名称、剂量、频次", en: "Name, dose, schedule", de: "Name, Dosis, Rhythmus"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer()

                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText, action: close)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    medicationFields
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 520)
            .scrollDismissesKeyboard(.interactively)

            saveButton
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .background { OhanaPopupGlassSurface(cornerRadius: 52) }
        .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
    }

    @ViewBuilder
    private var medicationFields: some View {
        labeledField(l.tr(zh: "药品名称 *", en: "Medication name *", de: "Medikament *")) {
            VStack(alignment: .leading, spacing: 12) {
                GoDraftTextField(
                    "例：阿莫西林、肠胃宝…",
                    text: $name,
                    capitalization: .words,
                    autoFocusDelay: isInlinePopup ? nil : 0.25
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(commonMedicationNames, id: \.self) { option in
                            Button {
                                withAnimation(GoMotion.selection) {
                                    name = option
                                }
                            } label: {
                                Text(option)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(name == option ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(name == option ? chromeAccent : Color.ohanaControlFill, in: Capsule())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
        }

        labeledField(l.tr(zh: "每次剂量 *", en: "Dose each time *", de: "Dosis je Einnahme *")) {
            VStack(alignment: .leading, spacing: 10) {
                InlineNumericInput(
                    text: $doseAmount,
                    placeholder: "1",
                    countryCode: AppCountry.code,
                    maxFractionDigits: 2,
                    accent: chromeAccent,
                    step: 0.5,
                    valueFont: .system(size: 18, weight: .black, design: .rounded),
                    valueAlignment: .center,
                    fill: Color.ohanaControlFill,
                    cornerRadius: 16,
                    horizontalPadding: 10,
                    verticalPadding: 8,
                    usesMiniKeypad: true
                )
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(doseUnits, id: \.self) { u in
                            unitChip(u)
                        }
                    }
                }
            }
        }

        labeledField(l.tr(zh: "喂药频次 *", en: "Frequency *", de: "Häufigkeit *")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(frequencyOptions, id: \.0) { freq, label in
                        Button {
                            withAnimation(GoMotion.selection) {
                                frequency = freq
                            }
                        } label: {
                            Text(label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(frequency == freq ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(frequency == freq ? chromeAccent : Color.ohanaControlFill, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }

        if scheduledDoseCount > 0 {
            labeledField(scheduledDoseCount > 1 ? l.tr(zh: "每次服药时间", en: "Dose times", de: "Einnahmezeiten") : l.tr(zh: "服药时间", en: "Dose time", de: "Einnahmezeit")) {
                VStack(spacing: 10) {
                    ForEach(0..<doseMinutes.count, id: \.self) { index in
                        doseTimeRow(index: index)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }

        labeledField(l.tr(zh: "疗程设置", en: "Course", de: "Kur")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("有疗程期限", isOn: $hasCourseEnd)
                    .tint(chromeAccent)
                if hasCourseEnd {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        .tint(chromeAccent)
                    Text("疗程天数")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    HStack(alignment: .top, spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach([7, 14, 30], id: \.self) { d in
                                coursePresetButton(days: d)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        courseDaysControl
                            .frame(width: 148)
                    }
                    .onChange(of: customCourseDays) { _, new in
                        syncCoursePreset(from: new)
                    }
                } else {
                    Text("长期用药：不设置结束日期")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }

        labeledField(l.tr(zh: "喂药方式（可选）", en: "How to give it (optional)", de: "Gabeart (optional)")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(administrationOptions, id: \.self) { opt in
                        Button {
                            administrationTag = administrationTag == opt ? nil : opt
                        } label: {
                            Text(opt)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(administrationTag == opt ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(administrationTag == opt ? chromeAccent : Color.ohanaControlFill, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }

        labeledField(l.tr(zh: "剩余药量（可选）", en: "Remaining amount (optional)", de: "Restmenge (optional)")) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    InlineNumericInput(
                        text: $remainingText,
                        placeholder: "数量",
                        unit: doseUnit,
                        countryCode: AppCountry.code,
                        maxFractionDigits: 2,
                        accent: chromeAccent,
                        step: 1,
                        valueFont: .system(size: 15, weight: .black, design: .rounded),
                        unitFont: .system(size: 12, weight: .black, design: .rounded),
                        valueAlignment: .leading,
                        fill: Color.ohanaControlFill,
                        cornerRadius: 12,
                        horizontalPadding: 10,
                        verticalPadding: 8,
                        usesMiniKeypad: true
                    )
                }
                Text("填写后可在详情页查看余量与预估天数")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }

        labeledField(l.tr(zh: "颜色标签", en: "Color tag", de: "Farbmarke")) {
            HStack(spacing: 14) {
                ForEach(colorPresets, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Circle().strokeBorder(Color.ohanaPrimaryText.opacity(0.9), lineWidth: colorHex == hex ? 2 : 0)
                            }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }

        labeledField(l.tr(zh: "备注（可选）", en: "Notes (optional)", de: "Notizen (optional)")) {
            GoDraftTextField(
                "兽医叮嘱、注意事项…",
                text: $notes,
                axis: .vertical
            )
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .lineLimit(3...6)
        }
    }

    private var saveButton: some View {
        Button {
            saveAfterKeyboardDismiss()
        } label: {
            Text(existing == nil ? "开始记录这个疗程" : "保存修改")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? chromeAccent : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave)
    }

    private func labeledField(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func unitChip(_ u: String) -> some View {
        Button {
            doseUnit = u
        } label: {
            Text(u)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(doseUnit == u ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(doseUnit == u ? chromeAccent : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func coursePresetButton(days: Int) -> some View {
        let selected = resolvedCourseDays == days && coursePresetDays == days
        return Button {
            setCourseDays(days, preset: days)
        } label: {
            Text("\(days)\(l.tr(zh: "天", en: "d", de: "T"))")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selected ? chromeAccent : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var courseDaysControl: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                courseStepButton(systemName: "minus", delta: -1)

                Button {
                    GoKeyboard.dismiss()
                    withAnimation(GoMotion.feedback) {
                        showsCourseDaysKeypad.toggle()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(resolvedCourseDays)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(l.tr(zh: "天", en: "d", de: "T"))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(chromeAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                courseStepButton(systemName: "plus", delta: 1)
            }
            .padding(.horizontal, 5)
            .frame(height: 44)
            .background(Color.ohanaControlFill, in: Capsule())

            if showsCourseDaysKeypad {
                EmbeddedDecimalKeypad(
                    text: $customCourseDays,
                    countryCode: AppCountry.code,
                    maxFractionDigits: 0,
                    accent: chromeAccent,
                    isMini: true
                ) {
                    withAnimation(GoMotion.feedback) {
                        showsCourseDaysKeypad = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    private func courseStepButton(systemName: String, delta: Int) -> some View {
        Button {
            setCourseDays(resolvedCourseDays + delta, preset: nil)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 34, height: 34)
                .background(chromeAccent, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(systemName == "minus" && resolvedCourseDays <= 1)
        .opacity(systemName == "minus" && resolvedCourseDays <= 1 ? 0.36 : 1)
    }

    private func setCourseDays(_ days: Int, preset: Int?) {
        let clamped = min(max(days, 1), 365)
        withAnimation(GoMotion.selection) {
            coursePresetDays = preset
            customCourseDays = "\(clamped)"
            showsCourseDaysKeypad = false
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func syncCoursePreset(from raw: String) {
        let digits = raw.filter(\.isNumber)
        if digits != raw {
            customCourseDays = digits
            return
        }
        guard let days = Int(digits), days > 0 else {
            coursePresetDays = nil
            return
        }
        coursePresetDays = [7, 14, 30].contains(days) ? days : nil
    }

    private func doseTimeRow(index: Int) -> some View {
        let timeBinding = Binding<Date>(
            get: {
                let minute = doseMinutes.indices.contains(index) ? doseMinutes[index] : 8 * 60
                return Calendar.current.date(
                    bySettingHour: minute / 60,
                    minute: minute % 60,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let minute = (comps.hour ?? 8) * 60 + (comps.minute ?? 0)
                if doseMinutes.indices.contains(index) {
                    doseMinutes[index] = minute
                }
            }
        )

        return HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 28, height: 28)
                .background(chromeAccent, in: Circle())
            Text(index == 0 ? "第一次" : "第\(index + 1)次")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(chromeAccent)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func parseDosage(_ raw: String) {
        let parts = raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count >= 2 {
            doseAmount = String(parts[0])
            let u = String(parts[1])
            if doseUnits.contains(u) { doseUnit = u }
        } else if !raw.isEmpty {
            doseAmount = raw
        }
    }

    private func splitAdministration(from full: String) -> (String?, String) {
        let prefix = "【喂法:"
        guard full.hasPrefix(prefix), let range = full.range(of: "】") else {
            return (nil, full)
        }
        let innerStart = full.index(full.startIndex, offsetBy: prefix.count)
        let tag = String(full[innerStart..<range.lowerBound])
        let rest = String(full[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let note = rest.hasPrefix("\n") ? String(rest.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) : rest
        return (tag.isEmpty ? nil : tag, note)
    }

    private func mergedNotes() -> String {
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let tag = administrationTag {
            return "【喂法:\(tag)】" + (n.isEmpty ? "" : "\n\(n)")
        }
        return n
    }

    private func saveAfterKeyboardDismiss() {
        GoKeyboard.dismiss()
        DispatchQueue.main.async {
            save()
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func finishSaved() {
        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }

    private func loadExistingMedication() {
        guard let e = existing else {
            if customCourseDays.isEmpty {
                customCourseDays = "\(coursePresetDays ?? 7)"
            }
            return
        }
        name = e.name
        parseDosage(e.dosage)
        frequency = e.frequency
        doseMinutes = PetMedicationSchedulePlan.doseMinutes(for: e)
        startDate = e.startDate
        if let end = e.endDate {
            hasCourseEnd = true
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: e.startDate), to: end).day ?? 7
            if [7, 14, 30].contains(days) {
                coursePresetDays = days
                customCourseDays = "\(days)"
            } else {
                coursePresetDays = nil
                customCourseDays = "\(days)"
            }
        } else {
            hasCourseEnd = false
        }
        (administrationTag, notes) = splitAdministration(from: e.notes)
        colorHex = e.colorHex
        let remainingKey = "medication_remaining_\(e.id.uuidString)"
        let remainingValue = UserDefaults.standard.double(forKey: remainingKey)
        if remainingValue > 0 {
            remainingText = String(format: "%.0f", remainingValue)
        }
    }

    private func save() {
        let end = parsedEndDate
        let dosageFinal = composedDosage

        if let e = existing {
            e.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            e.dosage = dosageFinal
            e.frequency = frequency
            e.customFrequencyNote = PetMedicationSchedulePlan.encodeDoseMinutes(doseMinutes)
            e.startDate = startDate
            e.endDate = end
            e.colorHex = colorHex
            e.notes = mergedNotes()
            modelContext.safeSave()
            MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
            let rk = "medication_remaining_\(e.id.uuidString)"
            if remainingText.trimmingCharacters(in: .whitespaces).isEmpty {
                UserDefaults.standard.removeObject(forKey: rk)
            } else if let v = Double(remainingText.replacingOccurrences(of: ",", with: ".")), v >= 0 {
                UserDefaults.standard.set(v, forKey: rk)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            finishSaved()
            return
        }

        let med = PetMedication(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosageFinal,
            frequency: frequency,
            startDate: startDate,
            endDate: end,
            colorHex: colorHex,
            notes: mergedNotes(),
            pet: pet
        )
        med.customFrequencyNote = PetMedicationSchedulePlan.encodeDoseMinutes(doseMinutes)
        modelContext.insert(med)
        modelContext.safeSave()
        MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
        if let v = Double(remainingText.replacingOccurrences(of: ",", with: ".")), v > 0 {
            UserDefaults.standard.set(v, forKey: "medication_remaining_\(med.id.uuidString)")
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        finishSaved()
    }
}

private enum PetMedicationQuickCatalog {
    static func names(for countryCode: String) -> [String] {
        switch AppCountry.normalize(countryCode) {
        case "US", "GB":
            return ["Amoxicillin", "Metronidazole", "Gabapentin", "Apoquel", "Simparica", "Revolution"]
        case "DE":
            return ["Amoxicillin", "Metronidazol", "Gabapentin", "Apoquel", "Milbemax", "Advocate"]
        case "JP":
            return ["アモキシシリン", "メトロニダゾール", "ガバペンチン", "ネクスガード", "レボリューション", "ミルベマックス"]
        case "HK", "TW":
            return ["阿莫西林", "甲硝唑", "加巴喷丁", "益生菌", "全能貓", "寵愛"]
        default:
            return ["阿莫西林", "甲硝唑", "加巴喷丁", "益生菌", "拜有利", "大宠爱"]
        }
    }
}
