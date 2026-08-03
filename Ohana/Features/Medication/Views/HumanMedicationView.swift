//
//  HumanMedicationView.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

private enum HumanMedicationToastKind: Equatable {
    case success
    case failure

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: .goTeal
        case .failure: .goRed
        }
    }
}

// MARK: - Main View

struct HumanMedicationContentView: View {
    let human: Human
    let allMeds: [HumanMedication]
    let allLogs: [HumanMedicationLog]
    let readCompleteness: HumanMedicationRouteReadCompleteness
    var showsDoneButton: Bool = true
    var onDoseTaken: (() -> Void)?
    let referenceNow: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var showAddSheet = false
    @State private var editingMed: HumanMedication? = nil
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastKind = HumanMedicationToastKind.success
    @State private var toastSequence = 0
    @State private var medicationPresentationState = HumanMedicationPresentationState()
    @State private var timelineNow: Date
    @State private var planPendingDeactivation: HumanMedication?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(
        human: Human,
        allMeds: [HumanMedication],
        allLogs: [HumanMedicationLog],
        readCompleteness: HumanMedicationRouteReadCompleteness = .complete,
        showsDoneButton: Bool = true,
        onDoseTaken: (() -> Void)? = nil,
        referenceNow: Date = Date()
    ) {
        self.human = human
        self.allMeds = allMeds
        self.allLogs = allLogs
        self.readCompleteness = readCompleteness
        self.showsDoneButton = showsDoneButton
        self.onDoseTaken = onDoseTaken
        self.referenceNow = referenceNow
        _timelineNow = State(initialValue: referenceNow)
        _planPendingDeactivation = State(initialValue: nil)
    }

    private var myMeds: [HumanMedication] {
        allMeds
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
    private var didReachReadLimit: Bool {
        !readCompleteness.all
    }

    private var todayLogs: [HumanMedicationLog] {
        allLogs.filter { log in
            Calendar.current.isDate(log.scheduledTime, inSameDayAs: timelineNow)
                && HumanMedicationLogStore.canonicalID(log.humanId) == human.id.uuidString
        }
    }

    private var adherenceSnapshot: HumanMedicationAdherenceSnapshot {
        HumanMedicationAdherenceAnalysis.snapshot(
            medications: myMeds,
            logs: allLogs,
            now: timelineNow
        )
    }

    private var sevenDayCompletionLabel: String {
        guard readCompleteness.sevenDayAnalysis else {
            return l.tr(zh: "七日趋势为部分数据", en: "Partial 7-day trend", de: "Teilweiser 7-Tage-Verlauf")
        }
        guard let completionRate = adherenceSnapshot.completionRate else {
            return l.tr(zh: "暂无到期剂量", en: "No doses due", de: "Keine Dosis fällig")
        }
        return l.tr(
            zh: "\(completionRate)% 七日估算",
            en: "\(completionRate)% 7-day estimate",
            de: "\(completionRate)% 7-Tage-Schätzung"
        )
    }

    private var todayScheduleItems: [DailyDoseItem] {
        HumanMedicationSchedulePlan
            .doses(on: timelineNow, medications: myMeds)
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
        pendingScheduleItems.filter { $0.scheduledTime < timelineNow }
    }

    private var nextPendingItem: DailyDoseItem? {
        pendingScheduleItems.first { $0.scheduledTime >= timelineNow } ?? overdueItems.first
    }

    private var nextPresentationDeadline: Date? {
        HumanMedicationTimelineRefreshPolicy.nextDosePresentationDeadline(
            after: timelineNow,
            medications: myMeds
        )
    }

    private func meds(in group: HumanMedicationDisplayGroup) -> [HumanMedication] {
        myMeds.filter { displayGroup(for: $0) == group }
    }

    var body: some View {
        Group {
            if isPrivacyLocked {
                HumanMedicationPrivacyLockedPage(
                    human: human,
                    showsDoneButton: showsDoneButton,
                    l: l,
                    onClose: { dismiss() }
                )
            } else {
                medicationContent
            }
        }
        .toolbar(showsDoneButton ? .hidden : .visible, for: .navigationBar)
        .sheet(isPresented: $showAddSheet) {
            AddMedicationSheet(human: human)
                .ohanaSheetPagePresentation() // ui-v4: allow complex medication editor uses full-height system sheet
        }
        .sheet(item: $editingMed) { med in
            AddMedicationSheet(human: human, editing: med)
                .ohanaSheetPagePresentation() // ui-v4: allow complex medication editor uses full-height system sheet
        }
        .onChange(of: referenceNow) { _, newValue in
            timelineNow = newValue
        }
        .task(id: nextPresentationDeadline) {
            await refreshAtNextDoseDeadline(nextPresentationDeadline)
        }
        .confirmationDialog(
            l.tr(zh: "停用用药计划？", en: "Stop medication plan?", de: "Medikamentenplan stoppen?"),
            isPresented: Binding(
                get: { planPendingDeactivation != nil },
                set: { if !$0 { planPendingDeactivation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let medication = planPendingDeactivation {
                Button(
                    l.tr(zh: "停用 \(spokenMedicationName(medication)) 的计划", en: "Stop \(spokenMedicationName(medication)) plan", de: "Plan für \(spokenMedicationName(medication)) stoppen"),
                    role: .destructive
                ) {
                    planPendingDeactivation = nil
                    setMedicationActive(medication, isActive: false)
                }
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                planPendingDeactivation = nil
            }
        } message: {
            Text(l.tr(
                zh: "这会停止未来日程和提醒，并影响后续依从率统计；既有服药记录会保留，也可随时恢复计划。",
                en: "This stops future schedules and reminders and affects future adherence totals. Existing dose logs stay saved, and the plan can be resumed anytime.",
                de: "Dadurch werden künftige Zeitpläne und Erinnerungen gestoppt und künftige Adhärenzwerte beeinflusst. Vorhandene Einnahmen bleiben gespeichert; der Plan kann jederzeit fortgesetzt werden."
            ))
        }
        .onDisappear {
            commandQueue.cancelAll()
            medicationPresentationState.cancelAll()
            planPendingDeactivation = nil
        }
    }
}

private extension HumanMedicationContentView {
    private func refreshAtNextDoseDeadline(_ deadline: Date?) async {
        guard AppWorkloadPolicy.shared.shouldRunEssentialDeadlineTimer(),
              let deadline else { return }
        let delaySeconds = max(0.25, deadline.timeIntervalSince(Date()) + 0.1)
        do {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        } catch {
            return
        }
        guard !Task.isCancelled,
              AppWorkloadPolicy.shared.shouldRunEssentialDeadlineTimer() else { return }
        timelineNow = Date()
    }

    private var medicationContent: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── 人物标识栏
                    HumanMedicationIdentityHeader(
                        human: human,
                        showsDoneButton: showsDoneButton,
                        todayTotal: todayPlannedCount,
                        todayDone: todayTakenCount,
                        isTodayReadComplete: readCompleteness.today,
                        showsPrivacyToggle: isViewingOwnProfile,
                        l: l,
                        onClose: { dismiss() }
                    )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    HumanPrivateDataNotice(human: human, field: .medication)
                        .padding(.horizontal, 16)

                    if didReachReadLimit {
                        HumanMedicationBoundedReadNotice(l: l)
                            .padding(.horizontal, 16)
                    }

                    HumanMedicationTodayFocusCard(
                        hasOverdueDose: !overdueItems.isEmpty,
                        todayCompletion: todayCompletion,
                        isTodayReadComplete: readCompleteness.today,
                        todayPlannedCount: todayPlannedCount,
                        currentMedicationCount: currentMeds.count,
                        isActivePlansReadComplete: readCompleteness.activePlans,
                        sevenDayCompletionLabel: sevenDayCompletionLabel,
                        title: todayOverviewTitle,
                        subtitle: todayOverviewSubtitle,
                        l: l
                    )
                        .padding(.horizontal, 16)

                    HumanMedicationOverviewMetricGrid(
                        isTodayReadComplete: readCompleteness.today,
                        todayTakenCount: todayTakenCount,
                        todaySkippedCount: todaySkippedCount,
                        todayPlannedCount: todayPlannedCount,
                        pendingCount: pendingScheduleItems.count,
                        overdueCount: overdueItems.count,
                        l: l
                    )
                        .padding(.horizontal, 16)

                    if !todayScheduleItems.isEmpty {
                        sectionLabel(l.tr(zh: "今日时间表", en: "Today", de: "Heute"))
                        HumanMedicationSurface {
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
                        HumanMedicationAdherenceCard(
                            snapshot: adherenceSnapshot,
                            isSevenDayReadComplete: readCompleteness.sevenDayAnalysis,
                            l: l
                        )
                            .padding(.horizontal, 16)
                    }

                    if myMeds.isEmpty {
                        HumanMedicationEmptyState(l: l)
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
                        Image(systemName: toastKind.icon)
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(toastKind.tint)
                            .accessibilityHidden(true)
                        Text(toastMessage)
                            .font(OhanaFont.subheadline(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(toastKind.tint.opacity(0.7), lineWidth: 1))
                    .padding(.horizontal, 16).padding(.bottom, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(toastMessage)
                    .accessibilityIdentifier(toastKind == .failure
                        ? "human-medication-error-toast"
                        : "human-medication-success-toast")
                }

                Button { showAddSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(l.tr(zh: "添加药物", en: "Add medication", de: "Medikament hinzufügen"))
                            .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("human-medication-add-action")
                .padding(.bottom, 28)
            }
        }
    }

    private var todayPlannedCount: Int { todayScheduleItems.count }
    private var todayTakenCount: Int { todayScheduleItems.count(where: { $0.log?.status == .taken }) }
    private var todaySkippedCount: Int { todayScheduleItems.count(where: { $0.log?.status == .skipped }) }
    private var todayResolvedCount: Int { todayTakenCount + todaySkippedCount }
    private var todayCompletion: Double {
        guard todayPlannedCount > 0 else { return 0 }
        return min(1, Double(todayTakenCount) / Double(todayPlannedCount))
    }

    private var todayOverviewTitle: String {
        guard readCompleteness.today else {
            return l.tr(zh: "今日记录仅显示部分", en: "Only part of today is shown", de: "Heute nur teilweise angezeigt")
        }
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
        guard readCompleteness.today else {
            return l.tr(
                zh: "已达到本地显示上限，请勿据此判断所有剂量已完成。",
                en: "The local display limit was reached; do not use this view to infer that every dose is complete.",
                de: "Das lokale Anzeigelimit ist erreicht; daraus lässt sich nicht ableiten, dass alle Dosen erledigt sind."
            )
        }
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
        activeMeds.count(where: {
            if let days = $0.daysRemaining { return days <= 7 }
            return false
        })
    }

    private var longTermCount: Int {
        activeMeds.count(where: { $0.endDate == nil })
    }

    // MARK: - Schedule Timeline

    private func scheduleRow(_ item: DailyDoseItem) -> some View {
        let status = effectiveDoseStatus(for: item)
        let isTaken = status == .taken
        let isSkipped = status == .skipped
        let isResolved = isTaken || isSkipped
        let isOverdue = !isResolved && item.scheduledTime < timelineNow
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
                    .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(doseTakenActionAccessibilityLabel(item, isTaken: isTaken))

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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(doseSkippedActionAccessibilityLabel(item, isSkipped: isSkipped))
            }
            .disabled(medicationPresentationState.pendingStatus(for: item.id) != nil)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private func doseTakenActionAccessibilityLabel(
        _ item: DailyDoseItem,
        isTaken: Bool
    ) -> String {
        let name = spokenMedicationName(item.medication)
        let time = item.scheduledTime.formatted(date: .omitted, time: .shortened)
        if isTaken {
            return l.tr(
                zh: "撤回 \(name) \(time) 的已服记录",
                en: "Undo taken record for \(name) at \(time)",
                de: "Einnahme von \(name) um \(time) rückgängig machen"
            )
        }
        return l.tr(
            zh: "记录 \(name) \(time) 已服",
            en: "Mark \(name) at \(time) as taken",
            de: "\(name) um \(time) als eingenommen markieren"
        )
    }

    private func doseSkippedActionAccessibilityLabel(
        _ item: DailyDoseItem,
        isSkipped: Bool
    ) -> String {
        let name = spokenMedicationName(item.medication)
        let time = item.scheduledTime.formatted(date: .omitted, time: .shortened)
        if isSkipped {
            return l.tr(
                zh: "撤回 \(name) \(time) 的跳过记录",
                en: "Undo skipped record for \(name) at \(time)",
                de: "Überspringen von \(name) um \(time) rückgängig machen"
            )
        }
        return l.tr(
            zh: "跳过 \(name) \(time) 的剂量",
            en: "Skip \(name) dose at \(time)",
            de: "Dosis von \(name) um \(time) überspringen"
        )
    }

    private func doseStatusText(_ item: DailyDoseItem) -> String {
        doseStatusText(item, status: effectiveDoseStatus(for: item))
    }

    private func doseStatusText(_ item: DailyDoseItem, status: HumanMedicationStatus?) -> String {
        switch status {
        case .taken:
            l.tr(zh: "已服", en: "Taken", de: "Genommen")
        case .skipped:
            l.tr(zh: "已跳过", en: "Skipped", de: "Überspr.")
        default:
            item.scheduledTime < timelineNow
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
            "checkmark"
        case .skipped:
            "minus"
        default:
            item.scheduledTime < timelineNow ? "exclamationmark" : "clock"
        }
    }

    private func effectiveDoseStatus(for item: DailyDoseItem) -> HumanMedicationStatus? {
        medicationPresentationState.effectiveStatus(
            for: item.id,
            persistedStatus: item.log?.status
        )
    }

    private func setDoseStatus(_ status: HumanMedicationStatus, for item: DailyDoseItem) {
        guard medicationPresentationState.pendingStatus(for: item.id) == nil else { return }
        withAnimation(GoMotion.feedback) {
            medicationPresentationState.begin(itemID: item.id, status: status)
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
            let result = HumanCareCommandExecutor(context: modelContext, services: appServices).setMedicationDoseStatus(
                human: human,
                medicationID: medicationID,
                scheduledTime: scheduledTime,
                status: status
            )
            let completion = medicationPresentationState.complete(itemID: item.id, result: result)
            switch completion {
            case let .persisted(shouldNotifyDoseTaken):
                presentMedicationToast(
                    doseToastMessage(status, medicationName: item.medication.name),
                    kind: .success
                )
                if shouldNotifyDoseTaken {
                    onDoseTaken?()
                }
            case .failed:
                let message = doseFailureMessage(medicationName: item.medication.name)
                presentMedicationFailure(message)
            }
        }
    }

    private func doseStatusColor(_ status: HumanMedicationStatus?) -> Color {
        switch status {
        case .taken: Color.goTeal
        case .skipped: Color.goOrange
        default: dividerColor.opacity(0.9)
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

    private func doseFailureMessage(medicationName: String) -> String {
        let name = medicationName.isEmpty
            ? l.tr(zh: "药物", en: "Medication", de: "Medikament")
            : medicationName
        if human.hasPassedAway {
            return l.tr(
                zh: "纪念模式为只读，未记录 \(name) 的用药状态。",
                en: "Memorial mode is read-only. \(name)'s medication status was not logged.",
                de: "Der Gedenkmodus ist schreibgeschützt. Der Medikamentenstatus für \(name) wurde nicht erfasst."
            )
        }
        return l.tr(
            zh: "未能保存 \(name) 的用药状态，请重试。",
            en: "Could not save \(name)'s medication status. Try again.",
            de: "Der Medikamentenstatus für \(name) konnte nicht gespeichert werden. Versuche es erneut."
        )
    }

    private func presentMedicationToast(
        _ message: String,
        kind: HumanMedicationToastKind,
        duration: TimeInterval = 2.0
    ) {
        toastSequence &+= 1
        let sequence = toastSequence
        withAnimation(GoMotion.feedback) {
            toastMessage = message
            toastKind = kind
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard toastSequence == sequence else { return }
            withAnimation(GoMotion.quick) { showToast = false }
        }
    }

    private func presentMedicationFailure(_ message: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        presentMedicationToast(message, kind: .failure, duration: 3.5)
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    // MARK: - Medication Row

    private func manualMedicationRow(_ med: HumanMedication) -> some View {
        HumanMedicationSurface {
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(l.tr(
                    zh: "记录一次 \(spokenMedicationName(med))",
                    en: "Log one dose of \(spokenMedicationName(med))",
                    de: "Eine Dosis \(spokenMedicationName(med)) eintragen"
                ))

                Button {
                    editingMed = med
                } label: {
                    Image(systemName: "slider.horizontal.3") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(secondaryText)
                        .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(controlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(l.tr(
                    zh: "编辑 \(spokenMedicationName(med))",
                    en: "Edit \(spokenMedicationName(med))",
                    de: "\(spokenMedicationName(med)) bearbeiten"
                ))
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
        let isActivationPending = medicationPresentationState.isPlanActivationPending(medicationID: med.id)
        return HumanMedicationSurface {
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
                        Image(systemName: "clock") // a11y: allow decorative icon covered by surrounding text or control
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
                        } else if med.endDate == nil, displayGroup(for: med) == .current {
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
                    Image(systemName: "slider.horizontal.3") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(secondaryText)
                        .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(controlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(l.tr(
                    zh: "编辑 \(spokenMedicationName(med))",
                    en: "Edit \(spokenMedicationName(med))",
                    de: "\(spokenMedicationName(med)) bearbeiten"
                ))

                Button {
                    if isMedicationActive {
                        planPendingDeactivation = med
                    } else {
                        setMedicationActive(med, isActive: true)
                    }
                } label: {
                    Image(systemName: isMedicationActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(isMedicationActive ? Color.goOrange : Color.goTeal)
                        .opacity(isActivationPending ? 0.55 : 1)
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(isMedicationActive
                    ? l.tr(
                        zh: "停用 \(spokenMedicationName(med)) 的用药计划",
                        en: "Stop medication plan for \(spokenMedicationName(med))",
                        de: "Medikamentenplan für \(spokenMedicationName(med)) stoppen"
                    )
                    : l.tr(
                        zh: "恢复 \(spokenMedicationName(med)) 的用药计划",
                        en: "Resume medication plan for \(spokenMedicationName(med))",
                        de: "Medikamentenplan für \(spokenMedicationName(med)) fortsetzen"
                    ))
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
            Image(systemName: "pills.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color(hex: med.colorHex))
        }
    }

    private func spokenMedicationName(_ med: HumanMedication) -> String {
        let name = med.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty
            ? l.tr(zh: "未命名药物", en: "Unnamed medication", de: "Unbenanntes Medikament")
            : name
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
        medicationPresentationState.effectivePlanActive(
            medicationID: med.id,
            persistedIsActive: med.isActive
        )
    }

    private func displayGroup(for med: HumanMedication) -> HumanMedicationDisplayGroup {
        guard effectiveMedicationActive(med) else { return .stopped }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: timelineNow)
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
            HumanMedicationSchedulePlan.date(on: timelineNow, minuteOfDay: $0)?.formatted(date: .omitted, time: .shortened)
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

    private func setMedicationActive(_ med: HumanMedication, isActive: Bool) {
        guard !medicationPresentationState.isPlanActivationPending(medicationID: med.id) else { return }
        guard effectiveMedicationActive(med) != isActive else { return }
        withAnimation(GoMotion.feedback) {
            medicationPresentationState.beginPlanActivation(
                medicationID: med.id,
                isActive: isActive
            )
        }

        let command = DomainCommand.humanMedicationPlanActivation(
            humanID: human.id,
            medicationID: med.id,
            isActive: isActive
        )
        commandQueue.enqueue(command) {
            let result = HumanCareCommandExecutor(context: modelContext, services: appServices).setMedicationPlanActive(
                human: human,
                medication: med,
                isActive: isActive,
                appLanguage: appLanguage
            )
            let completion = medicationPresentationState.completePlanActivation(
                medicationID: med.id,
                result: result
            )
            switch completion {
            case let .persisted(isActive):
                presentMedicationToast(
                    isActive
                        ? l.tr(zh: "\(med.name) 已恢复", en: "\(med.name) resumed", de: "\(med.name) fortgesetzt")
                        : l.tr(zh: "\(med.name) 已停药", en: "\(med.name) stopped", de: "\(med.name) pausiert"),
                    kind: .success,
                    duration: 2.5
                )
            case .failed:
                presentMedicationFailure(planActivationFailureMessage(medicationName: med.name))
            }
        }
    }

    private func planActivationFailureMessage(medicationName: String) -> String {
        let name = medicationName.isEmpty
            ? l.tr(zh: "药物", en: "Medication", de: "Medikament")
            : medicationName
        if human.hasPassedAway {
            return l.tr(
                zh: "纪念模式为只读，未更改 \(name) 的用药计划。",
                en: "Memorial mode is read-only. \(name)'s medication plan was not changed.",
                de: "Der Gedenkmodus ist schreibgeschützt. Der Medikamentenplan für \(name) wurde nicht geändert."
            )
        }
        return l.tr(
            zh: "未能更改 \(name) 的用药计划，请重试。",
            en: "Could not change \(name)'s medication plan. Try again.",
            de: "Der Medikamentenplan für \(name) konnte nicht geändert werden. Versuche es erneut."
        )
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
}
