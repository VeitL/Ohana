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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var doseAmount = ""
    @State private var doseUnit = "片"
    private let doseUnits = ["片", "ml", "g", "粒"]

    @State private var frequency: PetMedicationFrequency = .daily
    private let frequencyOptions: [(PetMedicationFrequency, String)] = [
        (.daily, "每天1次"),
        (.twiceDaily, "每天2次"),
        (.everyOtherDay, "隔天"),
        (.weekly, "每周"),
        (.asNeeded, "按需"),
    ]

    @State private var hasCourseEnd = true
    @State private var startDate = Date()
    @State private var coursePresetDays: Int? = 7
    @State private var customCourseDays = ""

    @State private var administrationTag: String? = nil
    private let administrationOptions = ["拌饭", "直接喂", "溶水", "零食包裹"]

    @State private var remainingText = ""
    @State private var notes = ""

    @State private var colorHex = "FF6B6B"
    private let colorPresets = ["FF6B6B", "FF9500", "FFDD44", "4ECDC4", "5B9FFF", "A78BFA"]

    private var themeColor: Color { Color(hex: pet.themeColorHex) }

    private var composedDosage: String {
        let amt = doseAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if amt.isEmpty { return doseUnit }
        return "\(amt) \(doseUnit)"
    }

    private var parsedEndDate: Date? {
        guard hasCourseEnd else { return nil }
        let days: Int = {
            if let p = coursePresetDays { return p }
            if let c = Int(customCourseDays.trimmingCharacters(in: .whitespaces)), c > 0 { return c }
            return 7
        }()
        return Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: startDate))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        labeledField("药品名称 *") {
                            TextField("例：阿莫西林、肠胃宝…", text: $name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }

                        labeledField("每次剂量 *") {
                            HStack(spacing: 10) {
                                TextField("1", text: $doseAmount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: 120)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(doseUnits, id: \.self) { u in
                                            unitChip(u)
                                        }
                                    }
                                }
                            }
                        }

                        labeledField("喂药频次 *") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(frequencyOptions, id: \.0) { freq, label in
                                        Button {
                                            frequency = freq
                                        } label: {
                                            Text(label)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(frequency == freq ? Color.arkInk : .primary)
                                                .padding(.horizontal, 12).padding(.vertical, 8)
                                                .background(frequency == freq ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        labeledField("疗程设置") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("有疗程期限", isOn: $hasCourseEnd)
                                    .tint(themeColor)
                                if hasCourseEnd {
                                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                                        .tint(themeColor)
                                    Text("疗程天数")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach([7, 14, 30], id: \.self) { d in
                                                Button {
                                                    coursePresetDays = d
                                                    customCourseDays = ""
                                                } label: {
                                                    Text("\(d)天")
                                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                                        .foregroundStyle(coursePresetDays == d && customCourseDays.isEmpty ? Color.arkInk : .primary)
                                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                                        .background(coursePresetDays == d && customCourseDays.isEmpty ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            TextField("自定义", text: $customCourseDays)
                                                .keyboardType(.numberPad)
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .frame(width: 72)
                                                .padding(.horizontal, 10).padding(.vertical, 8)
                                                .background(Color.primary.opacity(0.06), in: Capsule())
                                                .onChange(of: customCourseDays) { _, new in
                                                    if !new.isEmpty { coursePresetDays = nil }
                                                }
                                        }
                                    }
                                } else {
                                    Text("长期用药：不设置结束日期")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        labeledField("喂药方式（可选）") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(administrationOptions, id: \.self) { opt in
                                        Button {
                                            administrationTag = administrationTag == opt ? nil : opt
                                        } label: {
                                            Text(opt)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(administrationTag == opt ? Color.arkInk : .primary)
                                                .padding(.horizontal, 12).padding(.vertical, 8)
                                                .background(administrationTag == opt ? themeColor.opacity(0.35) : Color.primary.opacity(0.08), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        labeledField("剩余药量（可选）") {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    TextField("数量", text: $remainingText)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .padding(12)
                                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                    Text(doseUnit)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Text("填写后可在详情页查看余量与预估天数")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        labeledField("颜色标签") {
                            HStack(spacing: 14) {
                                ForEach(colorPresets, id: \.self) { hex in
                                    Button {
                                        colorHex = hex
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: colorHex == hex ? 2 : 0)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        labeledField("备注（可选）") {
                            TextField("兽医叮嘱、注意事项…", text: $notes, axis: .vertical)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .lineLimit(3...6)
                        }

                        Button {
                            save()
                        } label: {
                            Text(existing == nil ? "开始记录这个疗程 💊" : "保存修改 💊")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(Color.arkInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canSave ? Color.goPrimary : Color.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle(existing == nil ? "添加用药记录" : "编辑用药")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                        .foregroundStyle(canSave ? Color(hex: "FF5A00") : .secondary)
                }
            }
            .onAppear {
                if let e = existing {
                    name = e.name
                    parseDosage(e.dosage)
                    frequency = e.frequency
                    startDate = e.startDate
                    if let end = e.endDate {
                        hasCourseEnd = true
                        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: e.startDate), to: end).day ?? 7
                        if [7, 14, 30].contains(days) {
                            coursePresetDays = days
                            customCourseDays = ""
                        } else {
                            coursePresetDays = nil
                            customCourseDays = "\(days)"
                        }
                    } else {
                        hasCourseEnd = false
                    }
                    (administrationTag, notes) = splitAdministration(from: e.notes)
                    colorHex = e.colorHex
                    let rk = "medication_remaining_\(e.id.uuidString)"
                    let v = UserDefaults.standard.double(forKey: rk)
                    if v > 0 {
                        remainingText = String(format: "%.0f", v)
                    }
                }
            }
        }
    }

    private func labeledField(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func unitChip(_ u: String) -> some View {
        Button {
            doseUnit = u
        } label: {
            Text(u)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(doseUnit == u ? Color.arkInk : .primary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(doseUnit == u ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
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

    private func save() {
        let end = parsedEndDate
        let dosageFinal = composedDosage

        if let e = existing {
            e.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            e.dosage = dosageFinal
            e.frequency = frequency
            e.startDate = startDate
            e.endDate = end
            e.colorHex = colorHex
            e.notes = mergedNotes()
            modelContext.safeSave()
            let rk = "medication_remaining_\(e.id.uuidString)"
            if remainingText.trimmingCharacters(in: .whitespaces).isEmpty {
                UserDefaults.standard.removeObject(forKey: rk)
            } else if let v = Double(remainingText.replacingOccurrences(of: ",", with: ".")), v >= 0 {
                UserDefaults.standard.set(v, forKey: rk)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
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
        modelContext.insert(med)
        modelContext.safeSave()
        if let v = Double(remainingText.replacingOccurrences(of: ",", with: ".")), v > 0 {
            UserDefaults.standard.set(v, forKey: "medication_remaining_\(med.id.uuidString)")
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
