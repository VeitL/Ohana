//
//  PetMedicationDetailSheet.swift
//  Ohana
//
//  单条用药疗程详情：进度、今日打卡、历史（基于 Event）
//

import SwiftUI
import SwiftData

struct PetMedicationDetailSheet: View {
    let pet: Pet
    let medication: PetMedication

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @Query(sort: \Event.startDate, order: .reverse) private var allEvents: [Event]

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingEdit = false

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var chromeAccent: Color { colorScheme == .dark ? Color.goPrimary : Color.goBlue }
    private var l: L10n { L10n(appLanguage) }

    private var medEvents: [Event] {
        let idStr = medication.id.uuidString
        return allEvents.filter {
            $0.eventType == EventType.petMedicationDose.rawValue
                && $0.relatedEntityType == PetMedicationDoseLogging.relatedEntityTypeMedication
                && $0.relatedEntityId == idStr
        }
    }

    private var remainingAmount: Double {
        UserDefaults.standard.double(forKey: "medication_remaining_\(medication.id.uuidString)")
    }

    private var todayRequired: Int {
        PetMedicationDoseLogging.requiredDoses(on: Date(), for: medication)
    }

    private var todayDone: Int {
        PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: medication.id)
    }

    private var administrationDisplay: String {
        let (tag, _) = splitAdministration(from: medication.notes)
        if let tag { return tag }
        return "—"
    }

    private var noteBody: String {
        let (_, rest) = splitAdministration(from: medication.notes)
        return rest
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        detailChrome
                        headerBlock

                        if todayRequired > 0 && todayDone < todayRequired {
                            recordDoseButton
                        }

                        courseProgressCard

                        HStack(alignment: .top, spacing: 12) {
                            bentoTodayStatus
                            bentoAdministration
                        }

                        if remainingAmount > 0 {
                            remainingCard
                        }

                        historySection

                        if !noteBody.isEmpty {
                            Text("备注：\(noteBody)")
                                .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .padding(.top, 4)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEdit) {
                AddPetMedicationSheet(pet: pet, existing: medication)
            }
        }
    }

    private var detailChrome: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageData: pet.avatarImageData,
                emoji: pet.avatarEmoji,
                fallback: "🐾",
                tint: themeColor
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "用药详情", en: "Medication detail", de: "Medikationsdetail"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(pet.name)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                showingEdit = true
            } label: {
                Image(systemName: "pencil").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.ohanaControlFill, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Menu {
                Button(role: .destructive) {
                    deleteMedication()
                } label: {
                    Label(l.tr(zh: "删除此用药", en: "Delete medication", de: "Medikation löschen"), systemImage: "trash")
                }
                Button {
                    setMedicationActive(!medication.isActive)
                } label: {
                    Label(
                        medication.isActive ? l.tr(zh: "标记为停用", en: "Pause medication", de: "Medikation pausieren") : l.tr(zh: "恢复用药", en: "Resume medication", de: "Medikation fortsetzen"),
                        systemImage: medication.isActive ? "pause.circle" : "play.circle"
                    )
                }
            } label: {
                Image(systemName: "ellipsis").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: medication.colorHex))
                    .frame(width: 14, height: 14) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Text(medication.name.isEmpty ? "未命名药品" : medication.name)
                    .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
            }
            Text("\(medication.frequency.rawValue) · 每次 \(medication.dosage.isEmpty ? "—" : medication.dosage)")
                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private var recordDoseButton: some View {
        Button {
            PetMedicationDoseLogging.recordDose(
                medication: medication,
                pet: pet,
                modelContext: modelContext,
                awardCoconut: true
            )
            MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                Text("记录今次喂药")
                Spacer()
                Text("+1 🥥")
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(14)
            .background(chromeAccent, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func deleteMedication() {
        let command = DomainCommand.petMedicationPlanDelete(petID: pet.id, medicationID: medication.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            PetMedicationCommandExecutor(context: modelContext).deletePlan(
                pet: pet,
                medication: medication,
                note: "pet.medication.detail.delete"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    private func setMedicationActive(_ isActive: Bool) {
        let command = DomainCommand.petMedicationPlanActivation(
            petID: pet.id,
            medicationID: medication.id,
            isActive: isActive
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            PetMedicationCommandExecutor(context: modelContext).setPlanActive(
                pet: pet,
                medication: medication,
                isActive: isActive,
                note: "pet.medication.detail.activation"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private var courseProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("疗程进度")
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            if let end = medication.endDate {
                let cal = Calendar.current
                let start = cal.startOfDay(for: medication.startDate)
                let endDay = cal.startOfDay(for: end)
                let today = cal.startOfDay(for: Date())
                let total = max(1, cal.dateComponents([.day], from: start, to: endDay).day ?? 7)
                let passed = max(0, cal.dateComponents([.day], from: start, to: today).day ?? 0)
                let dayIndex = min(total, passed + 1)
                let p = min(1, Double(passed) / Double(total))

                Text("第 \(dayIndex) / \(total) 天")
                    .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                ProgressView(value: p)
                    .tint(themeColor)
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)
                Text("\(medication.startDate, format: .dateTime.year().month().day()) → \(end, format: .dateTime.year().month().day())")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                Text("长期用药")
                    .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                Text("未设置结束日期")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var bentoTodayStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日状态")
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            if todayRequired == 0 {
                Text("无需记录")
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
            } else if todayDone >= todayRequired {
                Label("已喂完", systemImage: "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
            } else {
                Text("还需 \(todayRequired - todayDone) 次")
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goYellow)
            }
            if let last = medEvents.filter({ Calendar.current.isDateInToday($0.startDate) }).first {
                Text(last.startDate, format: .dateTime.hour().minute())
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bentoAdministration: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("喂药方式")
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 6) {
                Image(systemName: "fork.knife").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(themeColor)
                Text(administrationDisplay)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var remainingCard: some View {
        let perDay = max(1, PetMedicationDoseLogging.requiredDoses(on: Date(), for: medication))
        let estDays = Int(remainingAmount / Double(perDay))

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube.box.fill").accessibilityHidden(true)
                    .foregroundStyle(themeColor)
                Text("剩余药量")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text("约 \(Int(remainingAmount)) 单位")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
            }
            ProgressView(value: min(1, remainingAmount / max(remainingAmount, 1)))
                .tint(themeColor)
            Text("按当前频次，预计还够约 \(max(estDays, 0)) 天")
                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("打卡历史")
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(themeColor)

            ForEach(historyDayRows, id: \.dayStart) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.title)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    HStack(spacing: 10) {
                        ForEach(row.events) { ev in
                            Label(ev.startDate.formatted(.dateTime.hour().minute()), systemImage: "checkmark.circle.fill")
                                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                        if row.missedCount > 0 {
                            ForEach(0..<row.missedCount, id: \.self) { _ in
                                Label("漏喂", systemImage: "xmark.circle.fill")
                                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.goRed.opacity(0.85))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private struct HistoryDayRow: Identifiable {
        var id: Date { dayStart }
        let dayStart: Date
        let title: String
        let events: [Event]
        let missedCount: Int
    }

    private var historyDayRows: [HistoryDayRow] {
        let cal = Calendar.current
        var rows: [HistoryDayRow] = []
        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let start = cal.startOfDay(for: day)
            let req = PetMedicationDoseLogging.requiredDoses(on: day, for: medication)
            let dayEvents = medEvents.filter { cal.isDate($0.startDate, inSameDayAs: day) }
                .sorted { $0.startDate < $1.startDate }
            let missed: Int
            if req == 0 {
                missed = 0
            } else if cal.isDateInToday(day) {
                missed = 0
            } else {
                missed = max(0, req - dayEvents.count)
            }
            let title: String
            if cal.isDateInToday(day) { title = "今天" }
            else if cal.isDateInYesterday(day) { title = "昨天" }
            else { title = day.formatted(.dateTime.month().day()) }

            if !dayEvents.isEmpty || missed > 0 {
                rows.append(HistoryDayRow(dayStart: start, title: title, events: dayEvents, missedCount: missed))
            }
        }
        return rows
    }

    private func splitAdministration(from full: String) -> (String?, String) {
        let prefix = "【喂法:"
        guard full.hasPrefix(prefix), let range = full.range(of: "】") else {
            return (nil, full)
        }
        let innerStart = full.index(full.startIndex, offsetBy: prefix.count)
        let tag = String(full[innerStart..<range.lowerBound])
        var rest = String(full[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if rest.hasPrefix("\n") { rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) }
        return (tag.isEmpty ? nil : tag, rest)
    }
}
