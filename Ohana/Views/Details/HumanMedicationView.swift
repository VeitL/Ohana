//
//  HumanMedicationView.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct DailyDoseItem: Identifiable, Hashable {
    let medication: HumanMedication
    let scheduledTime: Date
    let doseIndex: Int
    var log: HumanMedicationLog?

    var id: String {
        let minuteKey = Int(scheduledTime.timeIntervalSince1970 / 60)
        return "\(medication.id.uuidString)-\(minuteKey)-\(doseIndex)"
    }
}

private struct MedicationAdherenceDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayLabel: String
    let planned: Int
    let taken: Int

    var completion: Double {
        guard planned > 0 else { return 0 }
        return min(1, Double(taken) / Double(planned))
    }
}

// MARK: - Main View

struct HumanMedicationView: View {
    let human: Human
    var showsDoneButton: Bool = true
    var onDoseTaken: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @Query private var allMeds: [HumanMedication]
    @Query private var allLogs: [HumanMedicationLog]

    @State private var showAddSheet = false
    @State private var editingMed: HumanMedication? = nil
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var pendingDoseStatusByID: [String: HumanMedicationStatus] = [:]
    @State private var pendingMedicationActiveByID: [UUID: Bool] = [:]
    @State private var pendingMedicationActivationIDs: Set<UUID> = []
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var myMeds: [HumanMedication] {
        allMeds.filter { $0.humanId == human.id.uuidString }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var currentMeds: [HumanMedication] { meds(in: .current) }
    private var manualMeds: [HumanMedication] { meds(in: .manual) }
    private var notStartedMeds: [HumanMedication] { meds(in: .notStarted) }
    private var endedMeds: [HumanMedication] { meds(in: .ended) }
    private var stoppedMeds: [HumanMedication] { meds(in: .stopped) }
    private var activeMeds: [HumanMedication] { myMeds.filter { effectiveMedicationActive($0) } }
    private var inactiveMeds: [HumanMedication] { stoppedMeds }

    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var dividerColor: Color { Color.ohanaDivider }
    private var controlFill: Color { Color.ohanaControlFill }
    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.medication, viewedBy: activeHumanId) }

    private var todayLogs: [HumanMedicationLog] {
        allLogs.filter { log in
            Calendar.current.isDateInToday(log.scheduledTime) && log.humanId == human.id.uuidString
        }
    }

    private var adherenceDays: [MedicationAdherenceDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = AppLanguage.effectiveLocale
        weekdayFormatter.dateFormat = "E"

        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let planned = plannedDoseCount(on: day)
            let taken = allLogs.filter {
                $0.humanId == human.id.uuidString &&
                $0.status == .taken &&
                calendar.isDate($0.scheduledTime, inSameDayAs: day)
            }.count

            return MedicationAdherenceDay(
                date: day,
                dayLabel: weekdayFormatter.string(from: day),
                planned: planned,
                taken: min(taken, max(planned, taken))
            )
        }
    }

    private var sevenDayCompletionRate: Int {
        let planned = adherenceDays.reduce(0) { $0 + $1.planned }
        guard planned > 0 else { return 0 }
        let taken = adherenceDays.reduce(0) { $0 + $1.taken }
        return Int((Double(taken) / Double(planned) * 100).rounded())
    }
    
    private var todayScheduleItems: [DailyDoseItem] {
        HumanMedicationSchedulePlan
            .doses(on: Date(), medications: myMeds)
            .map { dose in
                let existingLog = HumanMedicationLogStore.matchingLog(
                    in: todayLogs,
                    humanId: human.id.uuidString,
                    medicationId: dose.medication.id.uuidString,
                    scheduledTime: dose.scheduledTime
                )
                return DailyDoseItem(
                    medication: dose.medication,
                    scheduledTime: dose.scheduledTime,
                    doseIndex: dose.doseIndex,
                    log: existingLog
                )
            }
    }

    private var pendingScheduleItems: [DailyDoseItem] {
        todayScheduleItems.filter { $0.log?.status != .taken && $0.log?.status != .skipped }
    }

    private var overdueItems: [DailyDoseItem] {
        let now = Date()
        return pendingScheduleItems.filter { $0.scheduledTime < now }
    }

    private var nextPendingItem: DailyDoseItem? {
        let now = Date()
        return pendingScheduleItems.first { $0.scheduledTime >= now } ?? overdueItems.first
    }

    private func meds(in group: HumanMedicationDisplayGroup) -> [HumanMedication] {
        myMeds.filter { displayGroup(for: $0) == group }
    }

    var body: some View {
        Group {
            if isPrivacyLocked {
                privacyLockedView
            } else {
                medicationContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddSheet) {
            AddMedicationSheet(human: human)
                .ohanaSheetPagePresentation() // ui-v4: allow complex medication editor uses full-height system sheet
        }
        .sheet(item: $editingMed) { med in
            AddMedicationSheet(human: human, editing: med)
                .ohanaSheetPagePresentation() // ui-v4: allow complex medication editor uses full-height system sheet
        }
        .onDisappear {
            commandQueue.cancelAll()
            pendingMedicationActiveByID.removeAll()
            pendingMedicationActivationIDs.removeAll()
        }
    }

    private var medicationContent: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── 人物标识栏
                    humanIdentityHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    HumanPrivateDataNotice(human: human, field: .medication)
                        .padding(.horizontal, 16)

                    todayFocusCard
                        .padding(.horizontal, 16)

                    overviewMetricGrid
                        .padding(.horizontal, 16)

                    if !todayScheduleItems.isEmpty {
                        sectionLabel(l.tr(zh: "今日时间表", en: "Today", de: "Heute"))
                        medicationSurface {
                            VStack(spacing: 0) {
                                ForEach(Array(todayScheduleItems.enumerated()), id: \.element.id) { index, item in
                                    scheduleRow(item)
                                    if index < todayScheduleItems.count - 1 {
                                        GoDashedDivider().padding(.leading, 64)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal, 16)
                    }

                    if !manualMeds.isEmpty {
                        sectionLabel(l.tr(zh: "按需与自定义", en: "Manual medication", de: "Manuelle Medikamente"))
                        ForEach(manualMeds) { med in
                            manualMedicationRow(med)
                                .padding(.horizontal, 16)
                        }
                    }

                    if !currentMeds.isEmpty {
                        sectionLabel(l.tr(zh: "当前用药", en: "Current", de: "Aktuell"))
                        ForEach(currentMeds) { med in
                            medicationRow(med)
                                .padding(.horizontal, 16)
                        }
                    }

                    if !notStartedMeds.isEmpty {
                        sectionLabel(l.tr(zh: "尚未开始", en: "Not started", de: "Noch nicht gestartet"))
                        ForEach(notStartedMeds) { med in
                            medicationRow(med)
                                .padding(.horizontal, 16)
                        }
                    }

                    if !endedMeds.isEmpty {
                        sectionLabel(l.tr(zh: "已结束", en: "Ended", de: "Beendet"))
                        ForEach(endedMeds) { med in
                            medicationRow(med)
                                .padding(.horizontal, 16)
                        }
                    }

                    if !stoppedMeds.isEmpty {
                        sectionLabel(l.tr(zh: "已停药", en: "Stopped", de: "Pausiert"))
                        ForEach(stoppedMeds) { med in
                            medicationRow(med)
                                .padding(.horizontal, 16)
                        }
                    }

                    if !myMeds.isEmpty {
                        adherenceChartCard
                            .padding(.horizontal, 16)
                    }

                    if myMeds.isEmpty {
                        emptyState
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }

                    Spacer(minLength: 120)
                }
            }

            // ── Toast + FAB
            VStack(spacing: 0) {
                if showToast {
                    HStack(spacing: 8) {
                        Text(toastMessage)
                            .font(OhanaFont.subheadline(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.ohanaCardStroke, lineWidth: 1))
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }

                Button { showAddSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .black))
                        Text(l.tr(zh: "添加药物", en: "Add medication", de: "Medikament hinzufügen"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Human Identity Header
    private var humanIdentityHeader: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "用药管理", en: "Medication", de: "Medikamente"),
            subtitle: human.name,
            showsCloseButton: showsDoneButton,
            onClose: { dismiss() }
        ) {
            let todayTotal = todayScheduleItems.count
            let todayDone  = todayScheduleItems.filter { $0.log?.status == .taken }.count
            if todayTotal > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(todayDone)/\(todayTotal)")
                        .font(OhanaFont.metric(size: 20))
                        .foregroundStyle(todayDone == todayTotal ? Color.goTeal : Color.goPrimary)
                    Text(l.tr(zh: "今日服药", en: "Today", de: "Heute"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            if isViewingOwnProfile {
                HumanPrivacyToggleButton(human: human, field: .medication)
            }
        }
    }

    private var privacyLockedView: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()
            VStack(spacing: 20) {
                HumanModulePageHeader(
                    human: human,
                    title: l.tr(zh: "用药管理", en: "Medication", de: "Medikamente"),
                    subtitle: human.name,
                    showsCloseButton: showsDoneButton,
                    onClose: { dismiss() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer(minLength: 16)
                HumanModulePrivacyLockedView(
                    title: l.tr(zh: "吃药提醒仅本人可见", en: "Medication is private", de: "Medikamente sind privat"),
                    message: l.tr(zh: "当前家庭成员无权查看用药计划、剂量和服药记录。", en: "This household member cannot view medication plans, doses, or logs.", de: "Dieses Haushaltsmitglied kann Medikamentenpläne, Dosen oder Protokolle nicht sehen.")
                )
                Spacer()
            }
        }
    }

    // MARK: - Summary Bento

    private var todayFocusCard: some View {
        medicationSurface {
            HStack(spacing: 18) {
                medicationProgressRing

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: overdueItems.isEmpty ? "pills.fill" : "exclamationmark.triangle.fill")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(overdueItems.isEmpty ? Color.goPrimary : Color.goRed)
                        Text(l.tr(zh: "TODAY FOCUS", en: "TODAY FOCUS", de: "HEUTE"))
                            .font(OhanaFont.caption(.black))
                            .tracking(1.2)
                            .foregroundStyle(tertiaryText)
                    }

                    Text(todayOverviewTitle)
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(primaryText)
                        .lineLimit(2)

                    Text(todayOverviewSubtitle)
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        overviewPill(l.tr(zh: "\(currentMeds.count) 个固定用药", en: "\(currentMeds.count) scheduled", de: "\(currentMeds.count) geplant"), color: Color.goRed)
                        overviewPill(l.tr(zh: "\(sevenDayCompletionRate)% 七日完成", en: "\(sevenDayCompletionRate)% 7-day", de: "\(sevenDayCompletionRate)% 7 Tage"), color: Color.goPrimary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
    }

    private var overviewMetricGrid: some View {
        HStack(spacing: 10) {
            overviewMetricCard(
                icon: "checkmark.seal.fill",
                label: l.tr(zh: "今日已服", en: "Taken", de: "Genommen"),
                value: "\(todayTakenCount)",
                suffix: todayPlannedCount > 0 ? "/\(todayPlannedCount)" : "",
                color: Color.goTeal
            )
            overviewMetricCard(
                icon: "forward.fill",
                label: l.tr(zh: "已跳过", en: "Skipped", de: "Übersprungen"),
                value: "\(todaySkippedCount)",
                suffix: l.tr(zh: "次", en: "", de: ""),
                color: Color.goOrange
            )
            overviewMetricCard(
                icon: overdueItems.isEmpty ? "clock.badge.checkmark" : "exclamationmark.triangle.fill",
                label: overdueItems.isEmpty ? l.tr(zh: "待记录", en: "Pending", de: "Offen") : l.tr(zh: "已超时", en: "Overdue", de: "Überfällig"),
                value: "\(overdueItems.isEmpty ? pendingScheduleItems.count : overdueItems.count)",
                suffix: l.tr(zh: "次", en: "", de: ""),
                color: overdueItems.isEmpty ? Color.goYellow : Color.goRed
            )
        }
    }

    private var medicationProgressRing: some View {
        ZStack {
            Circle()
                .stroke(controlFill, lineWidth: 12)
                .frame(width: 108, height: 108)
            Circle()
                .trim(from: 0, to: todayCompletion)
                .stroke(
                    LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 108, height: 108)
            VStack(spacing: 0) {
                Text(todayPlannedCount == 0 ? "--" : "\(Int((todayCompletion * 100).rounded()))%")
                    .font(OhanaFont.metric(size: 26))
                    .foregroundStyle(primaryText)
                Text(l.tr(zh: "今日", en: "Today", de: "Heute"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(tertiaryText)
            }
        }
    }

    private var todayPlannedCount: Int { todayScheduleItems.count }
    private var todayTakenCount: Int { todayScheduleItems.filter { $0.log?.status == .taken }.count }
    private var todaySkippedCount: Int { todayScheduleItems.filter { $0.log?.status == .skipped }.count }
    private var todayResolvedCount: Int { todayTakenCount + todaySkippedCount }
    private var todayCompletion: Double {
        guard todayPlannedCount > 0 else { return 0 }
        return min(1, Double(todayTakenCount) / Double(todayPlannedCount))
    }

    private var todayOverviewTitle: String {
        if todayPlannedCount == 0 {
            return myMeds.isEmpty
                ? l.tr(zh: "还没有服药计划", en: "No medication plan yet", de: "Noch kein Medikamentenplan")
                : l.tr(zh: "今日没有固定剂量", en: "No scheduled doses today", de: "Heute keine geplanten Dosen")
        }
        if !overdueItems.isEmpty {
            return l.tr(zh: "\(overdueItems.count) 次用药已超时", en: "\(overdueItems.count) dose(s) overdue", de: "\(overdueItems.count) Dosis überfällig")
        }
        if todayTakenCount == todayPlannedCount {
            return l.tr(zh: "今日服药已完成", en: "Medication done today", de: "Heute abgeschlossen")
        }
        if todayResolvedCount == todayPlannedCount {
            return l.tr(zh: "今日记录已处理", en: "All doses handled", de: "Alle Dosen erledigt")
        }
        if let nextPendingItem {
            return l.tr(
                zh: "下一次 \(nextPendingItem.scheduledTime.formatted(date: .omitted, time: .shortened))",
                en: "Next at \(nextPendingItem.scheduledTime.formatted(date: .omitted, time: .shortened))",
                de: "Nächste um \(nextPendingItem.scheduledTime.formatted(date: .omitted, time: .shortened))"
            )
        }
        return l.tr(zh: "还剩 \(max(0, todayPlannedCount - todayResolvedCount)) 次待记录", en: "\(max(0, todayPlannedCount - todayResolvedCount)) left today", de: "\(max(0, todayPlannedCount - todayResolvedCount)) heute offen")
    }

    private var todayOverviewSubtitle: String {
        if todayPlannedCount == 0 {
            if !manualMeds.isEmpty {
                return l.tr(zh: "按需药物可在下方手动记录一次。", en: "As-needed medication can be logged below.", de: "Bedarfsmedikamente kannst du unten manuell protokollieren.")
            }
            return l.tr(zh: "添加药物后，这里会展示今日进度和待处理剂量。", en: "Add medication to see today's progress and pending doses.", de: "Füge Medikamente hinzu, um Fortschritt und offene Dosen zu sehen.")
        }
        let skipped = todaySkippedCount > 0 ? l.tr(zh: " · 跳过 \(todaySkippedCount)", en: " · skipped \(todaySkippedCount)", de: " · übersprungen \(todaySkippedCount)") : ""
        return l.tr(zh: "已服 \(todayTakenCount)/\(todayPlannedCount)\(skipped)", en: "Taken \(todayTakenCount)/\(todayPlannedCount)\(skipped)", de: "Genommen \(todayTakenCount)/\(todayPlannedCount)\(skipped)")
    }

    private var endingSoonCount: Int {
        activeMeds.filter {
            if let days = $0.daysRemaining { return days <= 7 }
            return false
        }.count
    }

    private var longTermCount: Int {
        activeMeds.filter { $0.endDate == nil }.count
    }

    private func plannedDoseCount(on day: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)

        return HumanMedicationSchedulePlan.plannedDoseCount(on: startOfDay, medications: myMeds, calendar: calendar)
    }

    private var adherenceChartCard: some View {
        medicationSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.tr(zh: "近 7 天服药趋势", en: "7-day medication trend", de: "7-Tage-Verlauf"))
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(primaryText)
                        Text(l.tr(zh: "计划剂量与已完成剂量对比", en: "Planned doses vs completed doses", de: "Geplante und erledigte Dosen"))
                            .font(OhanaFont.caption())
                            .foregroundStyle(secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(sevenDayCompletionRate)%")
                            .font(OhanaFont.metric(size: 24))
                            .foregroundStyle(Color.goPrimary)
                        Text(l.tr(zh: "完成率", en: "Done", de: "Erledigt"))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(secondaryText)
                    }
                }

                OhanaMinimalBarChart(
                    points: adherenceDays.map { item in
                        OhanaMinimalChartPoint(
                            date: item.date,
                            value: Double(item.taken),
                            label: item.dayLabel,
                            id: item.id.uuidString
                        )
                    },
                    tint: Color.goPrimary,
                    showsLabels: true,
                    maxBarHeight: 104
                )
                .frame(height: 150)

                HStack(spacing: 14) {
                    chartLegendDot(color: secondaryText.opacity(0.55), label: l.tr(zh: "计划", en: "Planned", de: "Geplant"))
                    chartLegendDot(color: .goPrimary, label: l.tr(zh: "已服", en: "Taken", de: "Genommen"))
                    Spacer()
                    Text(l.tr(zh: "按药物排程计算计划剂量", en: "Planned doses follow the medication schedule", de: "Geplante Dosen folgen dem Zeitplan"))
                        .font(OhanaFont.caption2())
                        .foregroundStyle(tertiaryText)
                }
            }
            .padding(16)
        }
    }

    private func chartLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(secondaryText)
        }
    }

    private func overviewMetricCard(icon: String, label: String, value: String, suffix: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(color)
                Text(label)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(tertiaryText)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(OhanaFont.metric(size: 24))
                    .foregroundStyle(primaryText)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func overviewPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Schedule Timeline

    private func scheduleRow(_ item: DailyDoseItem) -> some View {
        let status = effectiveDoseStatus(for: item)
        let isTaken = status == .taken
        let isSkipped = status == .skipped
        let isResolved = isTaken || isSkipped
        let isOverdue = !isResolved && item.scheduledTime < Date()
        let tint = isTaken ? Color.goTeal : (isSkipped ? Color.goOrange : (isOverdue ? Color.goRed : Color.goPrimary))
        
        return HStack(spacing: 16) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.scheduledTime, style: .time)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(isResolved ? tertiaryText : primaryText)
                Text(doseStatusText(item, status: status))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(tint)
            }
            .frame(width: 62, alignment: .trailing)
            
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: doseStatusIcon(item, status: status))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(tint)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.medication.name)
                    .font(OhanaFont.headline(.semibold))
                    .foregroundStyle(isResolved ? secondaryText : primaryText)
                    .strikethrough(isResolved, color: secondaryText)
                if !item.medication.dosage.isEmpty {
                    Text(item.medication.dosage)
                        .font(OhanaFont.caption())
                        .foregroundStyle(tertiaryText)
                }
            }
            
            Spacer()

            HStack(spacing: 8) {
                Button {
                    setDoseStatus(isTaken ? .pending : .taken, for: item)
                } label: {
                    Text(isTaken ? l.tr(zh: "撤回", en: "Undo", de: "Zurück") : l.tr(zh: "已服", en: "Taken", de: "Genommen"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(isTaken ? secondaryText : Color.arkInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(isTaken ? controlFill : Color.goTeal, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    setDoseStatus(isSkipped ? .pending : .skipped, for: item)
                } label: {
                    Text(isSkipped ? l.tr(zh: "撤回", en: "Undo", de: "Zurück") : l.tr(zh: "跳过", en: "Skip", de: "Überspr."))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(isSkipped ? Color.goOrange : secondaryText)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background((isSkipped ? Color.goOrange : controlFill).opacity(isSkipped ? 0.16 : 1), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private func doseStatusText(_ item: DailyDoseItem) -> String {
        doseStatusText(item, status: effectiveDoseStatus(for: item))
    }

    private func doseStatusText(_ item: DailyDoseItem, status: HumanMedicationStatus?) -> String {
        switch status {
        case .taken:
            return l.tr(zh: "已服", en: "Taken", de: "Genommen")
        case .skipped:
            return l.tr(zh: "已跳过", en: "Skipped", de: "Überspr.")
        default:
            return item.scheduledTime < Date()
                ? l.tr(zh: "已超时", en: "Overdue", de: "Überfällig")
                : l.tr(zh: "待记录", en: "Pending", de: "Offen")
        }
    }

    private func doseStatusIcon(_ item: DailyDoseItem) -> String {
        doseStatusIcon(item, status: effectiveDoseStatus(for: item))
    }

    private func doseStatusIcon(_ item: DailyDoseItem, status: HumanMedicationStatus?) -> String {
        switch status {
        case .taken:
            return "checkmark"
        case .skipped:
            return "minus"
        default:
            return item.scheduledTime < Date() ? "exclamationmark" : "clock"
        }
    }

    private func effectiveDoseStatus(for item: DailyDoseItem) -> HumanMedicationStatus? {
        pendingDoseStatusByID[item.id] ?? item.log?.status
    }

    private func setDoseStatus(_ status: HumanMedicationStatus, for item: DailyDoseItem) {
        withAnimation(GoMotion.feedback) {
            pendingDoseStatusByID[item.id] = status
            toastMessage = doseToastMessage(status, medicationName: item.medication.name)
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showToast = false }
            }
        }

        let medicationID = item.medication.id
        let scheduledTime = item.scheduledTime
        let scheduledMinute = Int(scheduledTime.timeIntervalSince1970 / 60)
        let command = DomainCommand.humanMedicationDose(
            humanID: human.id,
            medicationID: medicationID,
            scheduledMinute: scheduledMinute,
            status: status.rawValue
        )

        commandQueue.enqueue(command) {
            let result = HumanCareCommandExecutor(context: modelContext).setMedicationDoseStatus(
                human: human,
                medicationID: medicationID,
                scheduledTime: scheduledTime,
                status: status
            )
            if result.status == .taken, result.didChange {
                onDoseTaken?()
            }
        }
    }

    private func doseStatusColor(_ status: HumanMedicationStatus?) -> Color {
        switch status {
        case .taken: return Color.goTeal
        case .skipped: return Color.goOrange
        default: return dividerColor.opacity(0.9)
        }
    }

    private func doseToastMessage(_ status: HumanMedicationStatus, medicationName: String) -> String {
        let name = medicationName.isEmpty ? l.tr(zh: "药物", en: "Medication", de: "Medikament") : medicationName
        switch status {
        case .taken: return l.tr(zh: "已记录 \(name)", en: "Logged \(name)", de: "\(name) protokolliert")
        case .skipped: return l.tr(zh: "已跳过 \(name)", en: "Skipped \(name)", de: "\(name) übersprungen")
        case .pending: return l.tr(zh: "已恢复待记录", en: "Back to pending", de: "Wieder offen")
        }
    }

    // MARK: - Medication Row

    private func manualMedicationRow(_ med: HumanMedication) -> some View {
        medicationSurface {
            HStack(spacing: 14) {
                medicationIcon(for: med)

                VStack(alignment: .leading, spacing: 5) {
                    Text(med.name.isEmpty ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament") : med.name)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(primaryText)
                    Text(manualMedicationSubtitle(med))
                        .font(OhanaFont.caption())
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    recordManualDose(for: med)
                } label: {
                    Text(l.tr(zh: "记录一次", en: "Log", de: "Eintragen"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    editingMed = med
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(secondaryText)
                        .frame(width: 34, height: 34)
                        .background(controlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(14)
        }
    }

    private func recordManualDose(for med: HumanMedication) {
        let item = DailyDoseItem(medication: med, scheduledTime: Date(), doseIndex: 0, log: nil)
        setDoseStatus(.taken, for: item)
    }

    private func manualMedicationSubtitle(_ med: HumanMedication) -> String {
        let frequencyTitle = med.frequency.displayTitle(l: l)
        let dose = med.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        if dose.isEmpty { return frequencyTitle }
        return "\(frequencyTitle) · \(dose)"
    }

    private func medicationRow(_ med: HumanMedication) -> some View {
        let isMedicationActive = effectiveMedicationActive(med)
        let isActivationPending = pendingMedicationActivationIDs.contains(med.id)
        return medicationSurface {
            HStack(spacing: 14) {
                medicationIcon(for: med)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(med.name.isEmpty ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament") : med.name)
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(primaryText)
                        medicationStateBadge(for: med)
                    }
                    HStack(spacing: 6) {
                        Text(med.frequency.displayTitle(l: l))
                            .font(OhanaFont.caption())
                            .foregroundStyle(secondaryText)
                        if !med.dosage.isEmpty {
                            Text("·")
                                .foregroundStyle(tertiaryText)
                            Text(med.dosage)
                                .font(OhanaFont.caption())
                                .foregroundStyle(secondaryText)
                        }
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(OhanaFont.caption2())
                            .foregroundStyle(tertiaryText)
                        Text(scheduleSummary(for: med))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color(hex: med.colorHex))
                            .lineLimit(1)
                        if let days = med.daysRemaining, displayGroup(for: med) == .current {
                            Text(l.tr(zh: "· 剩 \(max(0, days)) 天", en: "· \(max(0, days)) d left", de: "· \(max(0, days)) T übrig"))
                                .font(OhanaFont.caption())
                                .foregroundStyle(days <= 3 ? Color.goRed : tertiaryText)
                        } else if med.endDate == nil && displayGroup(for: med) == .current {
                            Text(l.tr(zh: "· 长期", en: "· long-term", de: "· langfristig"))
                                .font(OhanaFont.caption())
                                .foregroundStyle(tertiaryText)
                        }
                    }
                }

                Spacer()

                Button {
                    editingMed = med
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(secondaryText)
                        .frame(width: 34, height: 34)
                        .background(controlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    toggleMedicationActive(med)
                } label: {
                    Image(systemName: isMedicationActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(isMedicationActive ? Color.goOrange : Color.goTeal)
                        .opacity(isActivationPending ? 0.55 : 1)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isActivationPending)
            }
            .padding(14)
        }
    }

    private func medicationIcon(for med: HumanMedication) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: med.colorHex).opacity(0.2))
                .frame(width: 48, height: 48)
            Image(systemName: "pills.fill")
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color(hex: med.colorHex))
        }
    }

    private func medicationStateBadge(for med: HumanMedication) -> some View {
        let group = displayGroup(for: med)
        let text: String
        let color: Color
        switch group {
        case .current:
            text = l.tr(zh: "当前", en: "Current", de: "Aktuell")
            color = .goTeal
        case .manual:
            text = l.tr(zh: "手动", en: "Manual", de: "Manuell")
            color = .goPrimary
        case .notStarted:
            text = l.tr(zh: "未开始", en: "Not started", de: "Geplant")
            color = .goYellow
        case .ended:
            text = l.tr(zh: "已结束", en: "Ended", de: "Beendet")
            color = .goOrange
        case .stopped:
            text = l.tr(zh: "已停", en: "Stopped", de: "Pausiert")
            color = .goOrange
        }
        return Text(text)
            .font(OhanaFont.caption2(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func effectiveMedicationActive(_ med: HumanMedication) -> Bool {
        pendingMedicationActiveByID[med.id] ?? med.isActive
    }

    private func displayGroup(for med: HumanMedication) -> HumanMedicationDisplayGroup {
        guard effectiveMedicationActive(med) else { return .stopped }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if today < calendar.startOfDay(for: med.startDate) { return .notStarted }
        if let endDate = med.endDate, today > calendar.startOfDay(for: endDate) { return .ended }
        if med.frequency.isManualEntry { return .manual }
        return .current
    }

    private func scheduleSummary(for med: HumanMedication) -> String {
        if med.frequency.isManualEntry {
            return l.tr(zh: "手动记录", en: "Manual log", de: "Manuell")
        }
        let minutes = HumanMedicationSchedulePlan.doseMinutes(for: med)
        let timeText = minutes.compactMap {
            HumanMedicationSchedulePlan.date(on: Date(), minuteOfDay: $0)?.formatted(date: .omitted, time: .shortened)
        }.joined(separator: " / ")
        if med.frequency == .weekly {
            let weekday = HumanMedicationScheduleMetadata.parse(from: med.notes)?.weeklyWeekday
                ?? Calendar.current.component(.weekday, from: med.startDate)
            return "\(weekdayLabel(weekday)) · \(timeText)"
        }
        return timeText
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return symbols[max(0, min(6, weekday - 1))]
    }

    private func toggleMedicationActive(_ med: HumanMedication) {
        guard !pendingMedicationActivationIDs.contains(med.id) else { return }
        let nextIsActive = !effectiveMedicationActive(med)
        withAnimation(GoMotion.feedback) {
            pendingMedicationActiveByID[med.id] = nextIsActive
            pendingMedicationActivationIDs.insert(med.id)
            toastMessage = nextIsActive
                ? l.tr(zh: "\(med.name) 已恢复", en: "\(med.name) resumed", de: "\(med.name) fortgesetzt")
                : l.tr(zh: "\(med.name) 已停药", en: "\(med.name) stopped", de: "\(med.name) pausiert")
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(GoMotion.quick) { showToast = false }
            }
        }

        let command = DomainCommand.humanMedicationPlanActivation(
            humanID: human.id,
            medicationID: med.id,
            isActive: nextIsActive
        )
        commandQueue.enqueue(command) {
            HumanCareCommandExecutor(context: modelContext).setMedicationPlanActive(
                human: human,
                medication: med,
                isActive: nextIsActive,
                appLanguage: appLanguage
            )
            pendingMedicationActivationIDs.remove(med.id)
            pendingMedicationActiveByID[med.id] = nil
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        medicationSurface {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.goRed.opacity(0.12)).frame(width: 72, height: 72)
                    Image(systemName: "pills").font(.system(size: 32)).foregroundStyle(Color.goRed)
                }
                Text(l.tr(zh: "还没有添加药物", en: "No medication yet", de: "Noch keine Medikamente"))
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(primaryText)
                Text(l.tr(zh: "添加第一个服药提醒，今天的待处理剂量会显示在这里。", en: "Add the first medication reminder to see today's doses here.", de: "Füge die erste Erinnerung hinzu, um heutige Dosen hier zu sehen."))
                    .font(OhanaFont.callout())
                    .foregroundStyle(secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(tertiaryText)
            .textCase(.uppercase)
            .tracking(1.0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    private func medicationSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}

// MARK: - Add / Edit Sheet

struct AddMedicationSheet: View {
    let human: Human
    var editing: HumanMedication? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var name = ""
    @State private var doseForm: HumanMedicationDoseForm = .tablet
    @State private var doseAmount = ""
    @State private var doseUnit = "片"
    @State private var frequency: MedicationFrequency = .daily
    @State private var customNote = ""
    @State private var doseMinutes = HumanMedicationSchedulePlan.defaultDoseMinutes(for: .daily)
    @State private var weeklyWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var colorHex = "FF4757"
    @State private var notes = ""
    @State private var isActive = true
    @State private var showMore = false
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case name, dosage, customNote, notes
    }

    private enum HumanMedicationDoseForm: String, CaseIterable, Identifiable {
        case tablet
        case liquid
        case powder
        case injection
        case other

        var id: String { rawValue }

        func title(l: L10n) -> String {
            switch self {
            case .tablet:
                return l.tr(zh: "片剂", en: "Tablet", de: "Tablette")
            case .liquid:
                return l.tr(zh: "液体", en: "Liquid", de: "Flüssig")
            case .powder:
                return l.tr(zh: "粉剂", en: "Powder", de: "Pulver")
            case .injection:
                return l.tr(zh: "注射", en: "Injection", de: "Injektion")
            case .other:
                return l.tr(zh: "其他", en: "Other", de: "Andere")
            }
        }

        var unitOptions: [String] {
            switch self {
            case .tablet:
                return ["片", "粒", "mg"]
            case .liquid:
                return ["ml", "滴"]
            case .powder:
                return ["mg", "g", "勺"]
            case .injection:
                return ["ml", "IU"]
            case .other:
                return ["单位", "mg", "ml"]
            }
        }
    }

    private let colorOptions = ["FF4757", "FF8C42", "FFF44F", "00D4AA", "14B8A6", "9B5DE5", "64748B"]

    private var l: L10n { L10n(appLanguage) }
    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var controlFill: Color { Color.ohanaControlFill }
    private var controlStroke: Color { Color.ohanaCardStroke }
    private var canSave: Bool { !isSaving && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isEditing: Bool { editing != nil }
    private var composedDosage: String {
        let amount = doseAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !amount.isEmpty else { return "" }
        return "\(amount) \(doseUnit)"
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    basicInfoCard
                    frequencyCard
                    dateCard

                    if frequency.isManualEntry {
                        manualModeCard
                    } else {
                        scheduleCard
                        previewCard
                    }

                    if isEditing {
                        editingStateCard
                    }

                    moreToggle
                    if showMore {
                        moreCard
                    }

                    Spacer(minLength: 110)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { footerBar }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                    focusedField = nil
                    GoKeyboard.dismiss()
                }
                if canSave {
                    Button(l.tr(zh: "保存", en: "Save", de: "Sichern")) {
                        GoKeyboard.dismiss()
                        DispatchQueue.main.async {
                            save()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .alert(l.tr(zh: "删除药物计划？", en: "Delete medication plan?", de: "Medikamentenplan löschen?"), isPresented: $showDeleteConfirmation) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) { }
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                deleteMedication()
            }
        } message: {
            Text(l.tr(zh: "只会删除这个药物计划，历史服药记录会保留。", en: "Only this medication plan will be deleted. Past dose logs stay saved.", de: "Nur dieser Plan wird gelöscht. Frühere Einnahmen bleiben gespeichert."))
        }
        .onAppear {
            loadEditing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focusedField = .name
            }
        }
        .onChange(of: frequency) { _, newValue in
            applyDefaults(for: newValue)
        }
        .onChange(of: startDate) { _, newValue in
            if frequency == .weekly {
                weeklyWeekday = Calendar.current.component(.weekday, from: newValue)
            }
            if endDate < newValue {
                endDate = newValue
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? l.tr(zh: "编辑药物", en: "Edit medication", de: "Medikament bearbeiten") : l.tr(zh: "添加药物", en: "Add medication", de: "Medikament hinzufügen"))
                    .font(OhanaFont.title2(.bold))
                    .foregroundStyle(primaryText)
                Text(l.tr(zh: "先设好药名、频率和时间。", en: "Set the name, frequency, and time first.", de: "Lege zuerst Name, Häufigkeit und Zeit fest."))
                    .font(OhanaFont.caption())
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Button {
                guard !isSaving else { return }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isSaving)
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var basicInfoCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "pills.fill", color: Color(hex: colorHex), title: l.tr(zh: "药物信息", en: "Medication", de: "Medikament"))
                fieldRow(icon: "textformat", label: l.tr(zh: "药品名称", en: "Name", de: "Name")) {
                    GoDraftTextField(
                        l.tr(zh: "如：维生素 D", en: "e.g. Vitamin D", de: "z. B. Vitamin D"),
                        text: $name,
                        capitalization: .words,
                        autoFocusDelay: 0.25
                    )
                        .font(OhanaFont.body())
                        .foregroundStyle(primaryText)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label(l.tr(zh: "剂型", en: "Form", de: "Form"), systemImage: "pills")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(HumanMedicationDoseForm.allCases) { form in
                                let selected = doseForm == form
                                Button {
                                    endEditing()
                                    withAnimation(GoMotion.feedback) {
                                        doseForm = form
                                        if !form.unitOptions.contains(doseUnit) {
                                            doseUnit = form.unitOptions[0]
                                        }
                                    }
                                } label: {
                                    Text(form.title(l: l))
                                        .font(OhanaFont.caption(.bold))
                                        .foregroundStyle(selected ? Color.arkInk : primaryText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .goSelectableSurface(isSelected: selected, tint: Color.goPrimary, in: Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }
                fieldRow(icon: "scalemass", label: l.tr(zh: "每次剂量", en: "Dose per time", de: "Dosis pro Einnahme")) {
                    GoDraftTextField(
                        l.tr(zh: "数值", en: "Amount", de: "Menge"),
                        text: $doseAmount,
                        keyboardType: .decimalPad
                    )
                    .font(OhanaFont.body())
                    .foregroundStyle(primaryText)

                    Spacer(minLength: 8)

                    Menu {
                        ForEach(doseForm.unitOptions, id: \.self) { unit in
                            Button(unit) {
                                endEditing()
                                doseUnit = unit
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(doseUnit)
                                .font(OhanaFont.callout(.bold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(OhanaFont.caption(.bold))
                        }
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                    }
                }
            }
        }
    }

    private var frequencyCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(icon: "repeat", color: Color.goTeal, title: l.tr(zh: "频率", en: "Frequency", de: "Häufigkeit"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MedicationFrequency.allCases) { freq in
                            frequencyChip(freq)
                        }
                    }
                }
                if frequency == .custom {
                    fieldRow(icon: "text.bubble", label: l.tr(zh: "自定义说明", en: "Custom note", de: "Eigene Notiz")) {
                        GoDraftTextField(
                            l.tr(zh: "说明服药规则", en: "Describe the rule", de: "Regel beschreiben"),
                            text: $customNote
                        )
                            .font(OhanaFont.body())
                            .foregroundStyle(primaryText)
                    }
                }
            }
        }
    }

    private var dateCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "calendar", color: Color.goBlue, title: l.tr(zh: "日期", en: "Dates", de: "Daten"))
                HStack {
                    Label(l.tr(zh: "开始日期", en: "Start date", de: "Startdatum"), systemImage: "calendar")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .simultaneousGesture(TapGesture().onEnded { endEditing() })
                }
                .padding(12)
                .background(controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Toggle(isOn: $hasEndDate) {
                    Label(l.tr(zh: "设置结束日期", en: "Set end date", de: "Enddatum setzen"), systemImage: "calendar.badge.checkmark")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(primaryText)
                }
                .tint(Color.goTeal)
                .onChange(of: hasEndDate) { _, _ in endEditing() }

                if hasEndDate {
                    HStack {
                        Label(l.tr(zh: "结束日期", en: "End date", de: "Enddatum"), systemImage: "calendar.badge.minus")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(secondaryText)
                        Spacer()
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .labelsHidden()
                            .simultaneousGesture(TapGesture().onEnded { endEditing() })
                    }
                    .padding(12)
                    .background(controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var scheduleCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "clock.fill", color: Color.goPrimary, title: l.tr(zh: "服药时间", en: "Dose times", de: "Einnahmezeiten"))

                ForEach(Array(doseMinutes.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        Label(doseTimeLabel(index), systemImage: "clock")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(secondaryText)
                        Spacer()
                        DatePicker("", selection: doseTimeBinding(index), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .simultaneousGesture(TapGesture().onEnded { endEditing() })
                    }
                    .padding(12)
                    .background(controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if frequency == .weekly {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l.tr(zh: "每周哪一天", en: "Day of week", de: "Wochentag"))
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(secondaryText)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(weekdayOptions, id: \.0) { weekday, label in
                                    Button {
                                        endEditing()
                                        withAnimation(GoMotion.feedback) { weeklyWeekday = weekday }
                                    } label: {
                                        Text(label)
                                            .font(OhanaFont.caption(.bold))
                                            .foregroundStyle(weeklyWeekday == weekday ? Color.arkInk : primaryText)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(weeklyWeekday == weekday ? Color.goPrimary : controlFill, in: Capsule())
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var previewCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.goYellow)
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "接下来提醒", en: "Next reminders", de: "Nächste Erinnerungen"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(primaryText)
                Text(previewText)
                    .font(OhanaFont.caption())
                    .foregroundStyle(secondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.goYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.goYellow.opacity(0.28), lineWidth: 1))
    }

    private var manualModeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.goPrimary)
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "手动记录", en: "Manual logging", de: "Manuell eintragen"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(primaryText)
                Text(l.tr(zh: "按需和自定义药物不会自动生成固定提醒，可在管理页记录一次。", en: "As-needed and custom medications do not create fixed reminders. Log them from the management page.", de: "Bedarfs- und eigene Medikamente erzeugen keine festen Erinnerungen. Trage sie auf der Verwaltungsseite ein."))
                    .font(OhanaFont.caption())
                    .foregroundStyle(secondaryText)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.goPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.goPrimary.opacity(0.24), lineWidth: 1))
    }

    private var editingStateCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(icon: isActive ? "pause.circle.fill" : "play.circle.fill", color: isActive ? Color.goOrange : Color.goTeal, title: l.tr(zh: "药物状态", en: "Medication status", de: "Status"))
                Button {
                    withAnimation(GoMotion.feedback) { isActive.toggle() }
                } label: {
                    Label(
                        isActive ? l.tr(zh: "标记为停药", en: "Mark as stopped", de: "Als pausiert markieren") : l.tr(zh: "恢复用药", en: "Resume medication", de: "Fortsetzen"),
                        systemImage: isActive ? "pause.circle" : "play.circle"
                    )
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(isActive ? Color.goOrange : Color.goTeal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background((isActive ? Color.goOrange : Color.goTeal).opacity(0.12), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Label(l.tr(zh: "删除药物计划", en: "Delete plan", de: "Plan löschen"), systemImage: "trash")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.goRed.opacity(0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSaving)
            }
        }
    }

    private var moreToggle: some View {
        Button {
            withAnimation(GoMotion.feedback) { showMore.toggle() }
        } label: {
            HStack {
                Label(l.tr(zh: "更多", en: "More", de: "Mehr"), systemImage: "ellipsis.circle")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                Image(systemName: showMore ? "chevron.up" : "chevron.down")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(secondaryText)
            }
            .padding(14)
            .background(controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var moreCard: some View {
        sheetCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "slider.horizontal.3", color: Color.goBlue, title: l.tr(zh: "更多", en: "More", de: "Mehr"))

                VStack(alignment: .leading, spacing: 8) {
                    Text(l.tr(zh: "标签颜色", en: "Color", de: "Farbe"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                    HStack(spacing: 10) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                withAnimation(GoMotion.feedback) { colorHex = hex }
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(primaryText, lineWidth: colorHex == hex ? 2.5 : 0))
                                    .scaleEffect(colorHex == hex ? 1.12 : 1.0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(l.tr(zh: "备注", en: "Notes", de: "Notizen"), systemImage: "note.text")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(secondaryText)
                    GoDraftTextEditor(
                        l.tr(zh: "备注", en: "Notes", de: "Notizen"),
                        text: $notes,
                        minHeight: 74
                    )
                        .font(OhanaFont.body())
                        .foregroundStyle(primaryText)
                        .frame(height: 74)
                        .padding(10)
                        .background(controlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(controlStroke, lineWidth: 1))
                }
            }
        }
    }

    private var footerBar: some View {
        VStack(spacing: 0) {
            Button {
                GoKeyboard.dismiss()
                DispatchQueue.main.async {
                    save()
                }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        Image(systemName: "hourglass")
                            .font(OhanaFont.callout(.bold))
                    }
                    Text(isSaving ? l.tr(zh: "保存中", en: "Saving", de: "Speichert") : (isEditing ? l.tr(zh: "保存修改", en: "Save changes", de: "Änderungen sichern") : l.tr(zh: "保存药物", en: "Save medication", de: "Medikament sichern")))
                        .font(OhanaFont.headline(.bold))
                }
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color.goPrimary : Color.goPrimary.opacity(0.35), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSave)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(Color.ohanaCardSurface)
    }

    private func sheetCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }

    private func cardHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 36, height: 36)
                Image(systemName: icon).font(OhanaFont.callout(.bold)).foregroundStyle(color)
            }
            Text(title).font(OhanaFont.headline(.bold)).foregroundStyle(primaryText)
            Spacer()
        }
    }

    private func fieldRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(secondaryText)
            HStack { content() }
                .padding(12)
                .background(controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(controlStroke, lineWidth: 1))
        }
    }

    private func frequencyChip(_ freq: MedicationFrequency) -> some View {
        let selected = frequency == freq
        return Button {
            endEditing()
            withAnimation(GoMotion.feedback) { frequency = freq }
        } label: {
            Text(freq.displayTitle(l: l))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(selected ? Color.arkInk : primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .goSelectableSurface(isSelected: selected, tint: Color.goTeal, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func doseTimeLabel(_ index: Int) -> String {
        if doseMinutes.count == 1 {
            return l.tr(zh: "服药时间", en: "Dose time", de: "Einnahmezeit")
        }
        return l.tr(zh: "第 \(index + 1) 次", en: "Dose \(index + 1)", de: "Dosis \(index + 1)")
    }

    private func doseTimeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minute = doseMinutes.indices.contains(index) ? doseMinutes[index] : 8 * 60
                return dateFromMinute(minute)
            },
            set: { newDate in
                guard doseMinutes.indices.contains(index) else { return }
                doseMinutes[index] = HumanMedicationSchedulePlan.minuteOfDay(from: newDate)
                doseMinutes = HumanMedicationScheduleMetadata.normalizedDoseMinutes(doseMinutes)
            }
        )
    }

    private var weekdayOptions: [(Int, String)] {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (1...7).map { ($0, symbols[$0 - 1]) }
    }

    private var previewText: String {
        let dates = previewDates().prefix(3)
        guard !dates.isEmpty else {
            return l.tr(zh: "当前设置不会生成未来提醒。", en: "This setup will not create future reminders.", de: "Diese Einstellung erzeugt keine zukünftigen Erinnerungen.")
        }
        return dates
            .map { $0.formatted(date: .abbreviated, time: .shortened) }
            .joined(separator: " · ")
    }

    private func previewDates() -> [Date] {
        guard !frequency.isManualEntry else { return [] }
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        return (0..<14).flatMap { offset -> [Date] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return [] }
            guard calendar.startOfDay(for: day) >= calendar.startOfDay(for: startDate) else { return [] }
            if hasEndDate, calendar.startOfDay(for: day) > calendar.startOfDay(for: endDate) { return [] }
            if frequency == .weekly, calendar.component(.weekday, from: day) != weeklyWeekday { return [] }
            return doseMinutes.compactMap { HumanMedicationSchedulePlan.date(on: day, minuteOfDay: $0) }
        }
        .filter { $0 > now }
        .sorted()
    }

    private func dateFromMinute(_ minute: Int) -> Date {
        HumanMedicationSchedulePlan.date(on: Date(), minuteOfDay: minute) ?? Date()
    }

    private func applyDefaults(for frequency: MedicationFrequency) {
        if frequency.isManualEntry {
            doseMinutes = []
        } else {
            doseMinutes = HumanMedicationSchedulePlan.defaultDoseMinutes(for: frequency)
        }
        if frequency == .weekly {
            weeklyWeekday = Calendar.current.component(.weekday, from: startDate)
        }
    }

    private func endEditing() {
        focusedField = nil
        GoKeyboard.dismiss()
    }

    private func loadEditing() {
        guard let med = editing else { return }
        name = med.name
        loadDosage(med.dosage)
        frequency = med.frequency
        customNote = med.customFrequencyNote
        let loadedMinutes = HumanMedicationSchedulePlan.doseMinutes(for: med)
        doseMinutes = loadedMinutes.isEmpty ? HumanMedicationSchedulePlan.defaultDoseMinutes(for: med.frequency) : loadedMinutes
        weeklyWeekday = HumanMedicationScheduleMetadata.parse(from: med.notes)?.weeklyWeekday
            ?? Calendar.current.component(.weekday, from: med.startDate)
        startDate = med.startDate
        hasEndDate = med.endDate != nil
        endDate = med.endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        colorHex = med.colorHex
        notes = HumanMedicationScheduleMetadata.visibleNotes(from: med.notes)
        isActive = med.isActive
    }

    private func loadDosage(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            doseForm = .tablet
            doseAmount = ""
            doseUnit = "片"
            return
        }

        let allUnits = Array(Set(HumanMedicationDoseForm.allCases.flatMap(\.unitOptions)))
            .sorted { $0.count > $1.count }
        if let unit = allUnits.first(where: { trimmed.hasSuffix($0) }) {
            doseUnit = unit
            doseForm = inferredDoseForm(for: unit)
            doseAmount = trimmed
                .dropLast(unit.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return
        }

        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2, allUnits.contains(parts[1]) {
            doseAmount = parts[0]
            doseUnit = parts[1]
            doseForm = inferredDoseForm(for: parts[1])
        } else {
            doseForm = .other
            doseAmount = trimmed
            doseUnit = "单位"
        }
    }

    private func inferredDoseForm(for unit: String) -> HumanMedicationDoseForm {
        switch unit {
        case "片", "粒":
            return .tablet
        case "ml", "滴":
            return .liquid
        case "mg", "g", "勺":
            return .powder
        case "IU":
            return .injection
        default:
            return .other
        }
    }

    private var commandInput: HumanMedicationPlanCommandInput {
        HumanMedicationPlanCommandInput(
            name: name,
            dosage: composedDosage,
            frequency: frequency,
            customFrequencyNote: customNote,
            doseMinutes: doseMinutes,
            weeklyWeekday: weeklyWeekday,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            colorHex: colorHex,
            visibleNotes: notes,
            isActive: isActive,
            appLanguage: appLanguage
        )
    }

    private func save() {
        let input = commandInput
        guard !input.cleanName.isEmpty, !isSaving else { return }
        isSaving = true

        let command = DomainCommand.humanMedicationPlan(humanID: human.id, medicationID: editing?.id)
        commandQueue.enqueue(command) {
            guard HumanCareCommandExecutor(context: modelContext).saveMedicationPlan(
                human: human,
                editing: editing,
                input: input
            ) != nil else {
                isSaving = false
                return
            }

            isSaving = false
            dismiss()
        }
    }

    private func deleteMedication() {
        guard let med = editing, !isSaving else { return }
        isSaving = true

        let command = DomainCommand.humanMedicationPlanDelete(humanID: human.id, medicationID: med.id)
        commandQueue.enqueue(command) {
            HumanCareCommandExecutor(context: modelContext).deleteMedicationPlan(
                human: human,
                medication: med,
                note: "human.medication.plan.deleted"
            )
            isSaving = false
            dismiss()
        }
    }
}
