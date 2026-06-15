//
//  PetHealthDetailContentView+Overview.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension PetHealthDetailContentView {
    @ViewBuilder
    func healthOverviewSheet(_ sheet: ActiveHealthSheet) -> some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch sheet {
                        case .preventiveOverview:
                            preventiveOverviewContent
                        case .medicationOverview:
                            medicationOverviewContent
                        case .symptomVisitOverview:
                            symptomVisitOverviewContent
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        closeHealthOverview()
                    } label: {
                        Image(systemName: "xmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 14, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                }
            }
        }
    }

    var preventiveOverviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            overviewTitle(
                icon: "shield.checkered",
                title: l.tr(zh: "预防护理", en: "Preventive care", de: "Vorsorge"),
                subtitle: preventiveDashboardDetail,
                tint: preventionTint
            )

            VStack(spacing: 10) {
                ForEach(preventionItems) { item in
                    preventiveStatusRow(item)
                }
            }

            HStack(spacing: 10) {
                overviewActionButton(l.tr(zh: "添加预防", en: "Add preventive", de: "Vorsorge hinzufügen"), icon: "plus") {
                    activeHealthSheet = nil
                    openHealthRecord(.guided(.preventive), feedback: false)
                }
                overviewActionButton(l.tr(zh: "疫苗本", en: "Passport", de: "Impfpass"), icon: "syringe.fill") {
                    activeHealthSheet = nil
                    showingPassport = true
                }
            }

            overviewSectionTitle(l.tr(zh: "最近记录", en: "Recent", de: "Zuletzt"))
            let preventiveLogs = pet.activeHealthLogs
                .filter { preventiveTypes.contains($0.healthLogType) }
                .sorted { $0.date > $1.date }
                .prefix(6)
            if preventiveLogs.isEmpty {
                emptyOverviewRow(l.tr(zh: "还没有预防护理记录", en: "No preventive records yet", de: "Noch keine Vorsorgeeinträge"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(preventiveLogs)) { log in
                        overviewHistoryRow(
                            icon: healthIcon(for: log.healthLogType),
                            title: log.note.isEmpty ? healthTypeTitle(log.healthLogType) : log.note,
                            detail: log.date.formatted(.dateTime.year().month().day()),
                            tint: colorForType(log.healthLogType)
                        )
                    }
                }
            }
        }
    }

    var medicationOverviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            overviewTitle(
                icon: "pill.fill",
                title: l.tr(zh: "用药", en: "Medication", de: "Medikamente"),
                subtitle: nextMedicationDoseText,
                tint: medicationTint
            )

            HStack(spacing: 12) {
                overviewMetric(
                    title: l.tr(zh: "今日", en: "Today", de: "Heute"),
                    value: medicationStatusText,
                    tint: medicationTint
                )
                overviewMetric(
                    title: l.tr(zh: "进行中", en: "Active", de: "Aktiv"),
                    value: "\(activeMedications.count)",
                    tint: Color.goPurple
                )
            }

            overviewSectionTitle(l.tr(zh: "未来 48 小时", en: "Next 48 hours", de: "Nächste 48 Stunden"))
            let futureItems = next48HourMedicationDoseItems.prefix(8)
            if futureItems.isEmpty {
                emptyOverviewRow(l.tr(zh: "没有固定剂量", en: "No scheduled doses", de: "Keine geplanten Dosen"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(futureItems)) { item in
                        medicationDoseRow(item)
                    }
                }
            }

            overviewSectionTitle(l.tr(zh: "最近服药", en: "Recent doses", de: "Letzte Dosen"))
            let medicationIds = Set((activeMedications + pet.medications).map(\.id))
            let recentEvents = medicationDoseEvents
                .filter { event in
                    PetMedicationDoseLogging.doseMedicationId(for: event)
                        .map { medicationIds.contains($0) } == true
                }
                .sorted { $0.startDate > $1.startDate }
                .prefix(8)
            if recentEvents.isEmpty {
                emptyOverviewRow(l.tr(zh: "还没有服药记录", en: "No dose history yet", de: "Noch keine Einnahmen"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(recentEvents)) { event in
                        overviewHistoryRow(
                            icon: "pill.fill",
                            title: medicationName(for: event),
                            detail: event.startDate.formatted(.dateTime.month().day().hour().minute()),
                            tint: medicationTint
                        )
                    }
                }
            }

            overviewActionButton(l.tr(zh: "管理用药", en: "Manage medication", de: "Medikamente verwalten"), icon: "slider.horizontal.3") {
                activeHealthSheet = nil
                withAnimation(GoMotion.sheet) {
                    healthPlusDestination = .medications
                }
            }
        }
    }

    var symptomVisitOverviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            overviewTitle(
                icon: "waveform.path.ecg",
                title: l.tr(zh: "异常/就诊", en: "Symptoms & visits", de: "Auffälligkeiten & Besuche"),
                subtitle: symptomVisitDashboardDetail,
                tint: symptomVisitTint
            )

            if !pet.activeSymptomLogs.isEmpty {
                overviewSectionTitle(l.tr(zh: "严重程度", en: "Severity", de: "Schweregrad"))
                symptomSeverityDistribution
            }

            HStack(spacing: 10) {
                overviewActionButton(l.tr(zh: "记录症状", en: "Log symptom", de: "Symptom eintragen"), icon: "exclamationmark.triangle.fill") {
                    activeHealthSheet = nil
                    openHealthRecord(.symptom, feedback: false)
                }
                overviewActionButton(l.tr(zh: "记录就诊", en: "Log visit", de: "Besuch eintragen"), icon: "cross.case.fill") {
                    activeHealthSheet = nil
                    openHealthRecord(.guided(.visit), feedback: false)
                }
            }

            overviewSectionTitle(l.tr(zh: "症状", en: "Symptoms", de: "Symptome"))
            let symptoms = pet.activeSymptomLogs.sorted { $0.date > $1.date }.prefix(6)
            if symptoms.isEmpty {
                emptyOverviewRow(l.tr(zh: "没有异常症状", en: "No symptoms", de: "Keine Symptome"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(symptoms)) { log in
                        overviewHistoryRow(
                            icon: symptomCategoryIcon(log.category),
                            title: log.symptomName.isEmpty ? l.tr(zh: "异常症状", en: "Symptom", de: "Symptom") : log.symptomName,
                            detail: "\(localizedSeverityLabel(log.severity)) · \(log.date.formatted(.dateTime.month().day()))",
                            tint: log.severity == .severe || log.severity == .critical ? Color.goRed : Color.goOrange
                        )
                    }
                }
            }

            overviewSectionTitle(l.tr(zh: "就诊/检查", en: "Visits & procedures", de: "Besuche & Eingriffe"))
            let visits = pet.activeHealthLogs
                .filter { visitTypes.contains($0.healthLogType) }
                .sorted { $0.date > $1.date }
                .prefix(6)
            if visits.isEmpty {
                emptyOverviewRow(l.tr(zh: "没有就诊记录", en: "No visit records", de: "Keine Besuchseinträge"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(visits)) { log in
                        overviewHistoryRow(
                            icon: healthIcon(for: log.healthLogType),
                            title: log.note.isEmpty ? healthTypeTitle(log.healthLogType) : log.note,
                            detail: log.date.formatted(.dateTime.year().month().day()),
                            tint: colorForType(log.healthLogType)
                        )
                    }
                }
            }
        }
    }

    func overviewTitle(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 22, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(isDark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
    }

    func overviewSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.top, 4)
    }

    func overviewMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    func overviewActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(chromeAccent, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func preventiveStatusRow(_ item: PetHealthPreventionItem) -> some View {
        let tint: Color = {
            guard let days = item.daysRemaining else { return Color.goOrange }
            if days < 0 { return Color.goRed }
            if days <= 30 { return Color.goYellow }
            return chromeAccent
        }()
        let status: String = {
            guard let days = item.daysRemaining else {
                return l.tr(zh: "待补录", en: "Missing", de: "Fehlt")
            }
            if days < 0 {
                return l.tr(zh: "逾期 \(abs(days)) 天", en: "\(abs(days)) days overdue", de: "\(abs(days)) Tage überfällig")
            }
            if days == 0 {
                return l.tr(zh: "今天到期", en: "Due today", de: "Heute fällig")
            }
            return l.tr(zh: "\(days) 天后", en: "In \(days) days", de: "In \(days) Tagen")
        }()

        return HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(item.latestLog?.date.formatted(.dateTime.year().month().day()) ?? l.tr(zh: "未记录", en: "Not logged", de: "Nicht erfasst"))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(status)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    func medicationDoseRow(_ item: PetHealthMedicationDoseItem) -> some View {
        let isPast = item.scheduledAt <= Date()
        return HStack(spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : (isPast ? "clock.badge.exclamationmark.fill" : "clock.fill"))
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(item.isCompleted ? Color.goTeal : (isPast ? Color.goOrange : medicationTint))
                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            VStack(alignment: .leading, spacing: 3) {
                Text(item.medication.name.isEmpty ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament") : item.medication.name)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(relativeDoseTime(item.scheduledAt))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if item.isCompleted {
                Text(l.tr(zh: "已服", en: "Taken", de: "Genommen"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
            } else if Calendar.current.isDateInToday(item.scheduledAt) {
                Button {
                    recordMedicationDose(item)
                } label: {
                    Text(isPast ? l.tr(zh: "补记", en: "Catch up", de: "Nachtragen") : l.tr(zh: "提前", en: "Early", de: "Früh"))
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(medicationTint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Text(l.tr(zh: "待服", en: "Planned", de: "Geplant"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    func overviewHistoryRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint.opacity(isDark ? 0.16 : 0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(detail)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    func emptyOverviewRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tray").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 16, weight: .bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    var symptomSeverityDistribution: some View {
        let severities = SymptomSeverity.allCases
        let total = max(1, pet.activeSymptomLogs.count)
        return VStack(spacing: 9) {
            ForEach(severities, id: \.rawValue) { severity in
                let count = pet.activeSymptomLogs.count(where: { $0.severity == severity })
                HStack(spacing: 10) {
                    Text(severity.label)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 44, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(severityColor(severity).opacity(0.18))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(severityColor(severity))
                                    .frame(width: max(6, proxy.size.width * CGFloat(count) / CGFloat(total)))
                            }
                    }
                    .frame(height: 9)
                    Text("\(count)")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    func severityColor(_ severity: SymptomSeverity) -> Color {
        switch severity {
        case .mild: Color.goTeal
        case .moderate: Color.goYellow
        case .severe: Color.goOrange
        case .critical: Color.goRed
        }
    }

    func medicationName(for event: Event) -> String {
        guard let medicationId = PetMedicationDoseLogging.doseMedicationId(for: event) else {
            return l.tr(zh: "服药记录", en: "Medication dose", de: "Medikamenteneinnahme")
        }
        return (activeMedications + pet.medications).first { $0.id == medicationId }?.name
            ?? l.tr(zh: "服药记录", en: "Medication dose", de: "Medikamenteneinnahme")
    }
}
