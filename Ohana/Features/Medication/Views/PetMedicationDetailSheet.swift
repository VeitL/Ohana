//
//  PetMedicationDetailSheet.swift
//  Ohana
//
//  单条用药疗程详情：进度、今日打卡、历史（基于 Event）
//

import SwiftData
import SwiftUI

struct PetMedicationDetailContentSheet: View {
    let pet: Pet
    let medication: PetMedication
    let doseEvents: [Event]
    var onDataChanged: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingEdit = false

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var chromeAccent: Color { colorScheme == .dark ? Color.goPrimary : Color.goBlue }
    private var l: L10n { L10n(appLanguage) }

    private var medEvents: [Event] {
        doseEvents.filter {
            PetMedicationDoseLogging.isDoseEvent($0, medicationId: medication.id)
        }
    }

    private var remainingAmount: Double {
        PetMedicationPlanStorageKeys.remainingAmountValue(medication: medication)
    }

    private var todayRequired: Int {
        PetMedicationDoseLogging.requiredDoses(on: Date(), for: medication)
    }

    private var todayDone: Int {
        PetMedicationDoseLogging.todayDoseCount(events: doseEvents, medicationId: medication.id)
    }

    private var administrationDisplay: String {
        let (tag, _) = PetMedicationAdministrationMetadata.split(from: medication.notes)
        if let tag {
            return PetMedicationAdministrationOption.displayTitle(for: tag, l: l)
        }
        return "—"
    }

    private var noteBody: String {
        let (_, rest) = PetMedicationAdministrationMetadata.split(from: medication.notes)
        return rest
    }

    private var localizedDose: String {
        let formatted = PetMedicationDoseUnitOption.formatDosage(medication.dosage, l: l)
        return formatted.isEmpty ? "—" : formatted
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        detailChrome
                        headerBlock

                        if todayRequired > 0, todayDone < todayRequired {
                            recordDoseButton
                        }

                        courseProgressCard

                        medicationDetailStatusStack

                        if remainingAmount > 0 {
                            remainingCard
                        }

                        historySection

                        if !noteBody.isEmpty {
                            Text(l.tr(zh: "备注：\(noteBody)", en: "Note: \(noteBody)", de: "Notiz: \(noteBody)"))
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
                AddPetMedicationSheet(
                    pet: pet,
                    existing: medication,
                    onSaved: {
                        onDataChanged?()
                    }
                )
            }
        }
    }

    private var detailChrome: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageCacheID: "pet-medication-detail-\(pet.id.uuidString)",
                imageSignature: pet.avatarThumbnailSignature,
                petModelID: pet.persistentModelID,
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(Color(hex: medication.colorHex))
                    .frame(width: 14, height: 14) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .padding(.top, 8)
                Text(medication.name.isEmpty ? l.tr(zh: "未命名药品", en: "Unnamed medication", de: "Unbenanntes Medikament") : medication.name)
                    .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(l.tr(
                zh: "\(localizedFrequency(medication.frequency)) · 每次 \(localizedDose)",
                en: "\(localizedFrequency(medication.frequency)) · per dose \(localizedDose)",
                de: "\(localizedFrequency(medication.frequency)) · pro Dosis \(localizedDose)"
            ))
                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recordDoseButton: some View {
        Button {
            let result = PetMedicationCommandExecutor(context: modelContext, services: appServices).recordDose(
                medication: medication,
                pet: pet,
                awardCoconut: true,
                note: "pet.medication.detail.dose"
            )
            guard result.didRecord, result.allowsDerivedEffects else { return }
            appServices.medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onDataChanged?()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                Text(l.tr(zh: "记录今次喂药", en: "Log this dose", de: "Diese Dosis eintragen"))
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
            PetMedicationCommandExecutor(context: modelContext, services: appServices).deletePlan(
                pet: pet,
                medication: medication,
                note: "pet.medication.detail.delete"
            )
            onDataChanged?()
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
            PetMedicationCommandExecutor(context: modelContext, services: appServices).setPlanActive(
                pet: pet,
                medication: medication,
                isActive: isActive,
                note: "pet.medication.detail.activation"
            )
            onDataChanged?()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private var courseProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "疗程进度", en: "Course progress", de: "Verlauf"))
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

                Text(l.tr(zh: "第 \(dayIndex) / \(total) 天", en: "Day \(dayIndex) / \(total)", de: "Tag \(dayIndex) / \(total)"))
                    .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                ProgressView(value: p)
                    .tint(themeColor)
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)
                Text("\(medication.startDate, format: .dateTime.year().month().day()) → \(end, format: .dateTime.year().month().day())")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(l.tr(zh: "长期用药", en: "Long-term medication", de: "Langzeitmedikation"))
                    .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                Text(l.tr(zh: "未设置结束日期", en: "No end date set", de: "Kein Enddatum festgelegt"))
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var medicationDetailStatusStack: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                bentoTodayStatus
                bentoAdministration
            }

            VStack(alignment: .leading, spacing: 12) {
                bentoTodayStatus
                bentoAdministration
            }
        }
    }

    private var bentoTodayStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "今日状态", en: "Today", de: "Heute"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            if todayRequired == 0 {
                Text(l.tr(zh: "无需记录", en: "No dose needed", de: "Keine Dosis nötig"))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if todayDone >= todayRequired {
                Label(l.tr(zh: "已喂完", en: "Done", de: "Erledigt"), systemImage: "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
                    .lineLimit(2)
            } else {
                Text(l.tr(zh: "还需 \(todayRequired - todayDone) 次", en: "\(todayRequired - todayDone) left", de: "Noch \(todayRequired - todayDone)"))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goYellow)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let last = medEvents.filter({ Calendar.current.isDateInToday($0.startDate) }).first {
                Text(last.startDate, format: .dateTime.hour().minute())
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private var bentoAdministration: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "喂药方式", en: "How to give", de: "Gabe"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "fork.knife").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14))
                    .foregroundStyle(themeColor)
                    .padding(.top, 2)
                Text(administrationDisplay)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private var remainingCard: some View {
        let perDay = max(1, PetMedicationDoseLogging.requiredDoses(on: Date(), for: medication))
        let estDays = Int(remainingAmount / Double(perDay))

        return VStack(alignment: .leading, spacing: 8) {
            medicationRemainingHeader(remainingAmount: remainingAmount)
            ProgressView(value: min(1, remainingAmount / max(remainingAmount, 1)))
                .tint(themeColor)
            Text(l.tr(
                zh: "按当前频次，预计还够约 \(max(estDays, 0)) 天",
                en: "At this schedule, about \(max(estDays, 0)) days left",
                de: "Bei diesem Plan reichen sie noch ca. \(max(estDays, 0)) Tage"
            ))
                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func medicationRemainingHeader(remainingAmount: Double) -> some View {
        let title = l.tr(zh: "剩余药量", en: "Remaining", de: "Vorrat")
        let value = l.tr(
            zh: "约 \(Int(remainingAmount)) 单位",
            en: "About \(Int(remainingAmount)) units",
            de: "Etwa \(Int(remainingAmount)) Einheiten"
        )

        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                medicationRemainingTitle(title)
                Spacer(minLength: 8)
                medicationRemainingValue(value)
            }

            VStack(alignment: .leading, spacing: 6) {
                medicationRemainingTitle(title)
                medicationRemainingValue(value)
            }
        }
    }

    private func medicationRemainingTitle(_ title: String) -> some View {
        Label {
            Text(title)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "cube.box.fill").accessibilityHidden(true)
                .foregroundStyle(themeColor)
        }
        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
    }

    private func medicationRemainingValue(_ value: String) -> some View {
        Text(value)
            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "打卡历史", en: "Dose history", de: "Verlauf"))
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(themeColor)

            ForEach(historyDayRows, id: \.dayStart) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.title)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    medicationHistoryChips(row: row)
                }
            }
        }
    }

    private func medicationHistoryChips(row: HistoryDayRow) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(row.events) { ev in
                Label(ev.startDate.formatted(.dateTime.hour().minute()), systemImage: "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            if row.missedCount > 0 {
                ForEach(0 ..< row.missedCount, id: \.self) { _ in
                    Label(l.tr(zh: "漏喂", en: "Missed", de: "Verpasst"), systemImage: "xmark.circle.fill")
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.goRed.opacity(0.85))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.goRed.opacity(0.10), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        for offset in 0 ..< 14 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let start = cal.startOfDay(for: day)
            let req = PetMedicationDoseLogging.requiredDoses(on: day, for: medication)
            let dayEvents = medEvents.filter { cal.isDate($0.startDate, inSameDayAs: day) }
                .sorted { $0.startDate < $1.startDate }
            let missed: Int = if req == 0 {
                0
            } else if cal.isDateInToday(day) {
                0
            } else {
                max(0, req - dayEvents.count)
            }
            let title: String = if cal.isDateInToday(day) { l.tr(zh: "今天", en: "Today", de: "Heute") }
            else if cal.isDateInYesterday(day) { l.tr(zh: "昨天", en: "Yesterday", de: "Gestern") }
            else { day.formatted(.dateTime.month().day()) }

            if !dayEvents.isEmpty || missed > 0 {
                rows.append(HistoryDayRow(dayStart: start, title: title, events: dayEvents, missedCount: missed))
            }
        }
        return rows
    }

    private func localizedFrequency(_ frequency: PetMedicationFrequency) -> String {
        switch frequency {
        case .daily:
            l.tr(zh: "每天", en: "Daily", de: "Täglich")
        case .twiceDaily:
            l.tr(zh: "每天两次", en: "Twice daily", de: "Zweimal täglich")
        case .threeTimesDaily:
            l.tr(zh: "每天三次", en: "Three times daily", de: "Dreimal täglich")
        case .everyOtherDay:
            l.tr(zh: "隔天", en: "Every other day", de: "Alle zwei Tage")
        case .weekly:
            l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich")
        case .asNeeded:
            l.tr(zh: "按需", en: "As needed", de: "Nach Bedarf")
        case .custom:
            l.tr(zh: "自定义", en: "Custom", de: "Benutzerdefiniert")
        }
    }
}
