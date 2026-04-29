//
//  HumanMedicationView.swift
//  Ohana
//

import SwiftUI
import SwiftData
import Charts

struct DailyDoseItem: Identifiable, Hashable {
    let id = UUID()
    let medication: HumanMedication
    let scheduledTime: Date
    let doseIndex: Int
    var log: HumanMedicationLog?
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
    @Query private var allMeds: [HumanMedication]
    @Query private var allLogs: [HumanMedicationLog]

    @State private var showAddSheet = false
    @State private var editingMed: HumanMedication? = nil
    @State private var showToast = false
    @State private var toastMessage = ""

    private var myMeds: [HumanMedication] {
        allMeds.filter { $0.humanId == human.id.uuidString }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var activeMeds: [HumanMedication] { myMeds.filter { $0.isActive } }
    private var inactiveMeds: [HumanMedication] { myMeds.filter { !$0.isActive } }

    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var dividerColor: Color { Color.ohanaDivider }
    private var controlFill: Color { Color.ohanaControlFill }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
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
        var items: [DailyDoseItem] = []
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        for med in activeMeds {
            let dosesPerDay = med.frequency.dosesPerDay
            guard dosesPerDay > 0 else { continue } // 按需不参与静态排表

            if med.frequency == .weekly {
                let daysSinceStart = calendar.dateComponents([.day], from: med.startDate, to: startOfToday).day ?? 0
                if daysSinceStart % 7 != 0 { continue }
            }
            
            let intervalHours = 24.0 / Double(dosesPerDay)
            var baseComponents = calendar.dateComponents([.year, .month, .day], from: now)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: med.firstDoseTime)
            baseComponents.hour = timeComponents.hour ?? 8
            baseComponents.minute = timeComponents.minute ?? 0
            baseComponents.second = 0
            guard let baseTime = calendar.date(from: baseComponents) else { continue }
            
            for doseIdx in 0..<dosesPerDay {
                let fireDate = baseTime.addingTimeInterval(Double(doseIdx) * intervalHours * 3600)
                let existingLog = todayLogs.first(where: { 
                    $0.medicationId == med.id.uuidString && 
                    calendar.isDate($0.scheduledTime, equalTo: fireDate, toGranularity: .minute)
                })
                items.append(DailyDoseItem(medication: med, scheduledTime: fireDate, doseIndex: doseIdx, log: existingLog))
            }
        }
        return items.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    var body: some View {
        Group {
            if isPrivacyLocked {
                privacyLockedView
            } else {
                medicationContent
            }
        }
        .navigationTitle("吃药提醒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 隐私开关（leading）
            ToolbarItem(placement: .topBarLeading) {
                HumanPrivacyToggleButton(human: human, field: .medication)
            }
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMedicationSheet(human: human)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingMed) { med in
            AddMedicationSheet(human: human, editing: med)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var medicationContent: some View {
        ZStack(alignment: .bottom) {
            ArkBackgroundView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── 人物标识栏
                    humanIdentityHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // ── 汇总 Bento
                    summaryBento
                        .padding(.horizontal, 16)

                    overviewMetricGrid
                        .padding(.horizontal, 16)

                    if !myMeds.isEmpty {
                        adherenceChartCard
                            .padding(.horizontal, 16)
                    }

                    // ── 今日时间表
                    if !todayScheduleItems.isEmpty {
                        sectionLabel("今日时间表")
                        UltimateGlassCard {
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

                    // ── 当前用药
                    if !activeMeds.isEmpty {
                        sectionLabel("当前用药")
                        ForEach(activeMeds) { med in
                            medicationRow(med)
                                .padding(.horizontal, 16)
                        }
                    }

                    // ── 已停药
                    if !inactiveMeds.isEmpty {
                        sectionLabel("已停药")
                        ForEach(inactiveMeds) { med in
                            medicationRow(med)
                                .padding(.horizontal, 16)
                        }
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
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.black.opacity(0.85), in: Capsule())
                    .padding(.horizontal, 16).padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button { showAddSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .black))
                        Text("添加药物")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.goPrimary, in: Capsule())
                    .shadow(color: Color.goPrimary.opacity(0.4), radius: 14, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Human Identity Header
    private var humanIdentityHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: human.themeColorHex).opacity(0.18))
                    .frame(width: 48, height: 48)
                if let data = human.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text(human.avatarEmoji).font(.system(size: 24))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(human.name)
                    .font(OhanaFont.headline(.bold))
                    .foregroundStyle(.primary)
                Text("用药管理")
                    .font(OhanaFont.caption())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // 今日完成进度
            let todayTotal = todayScheduleItems.count
            let todayDone  = todayScheduleItems.filter { $0.log?.status == .taken }.count
            if todayTotal > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(todayDone)/\(todayTotal)")
                        .font(OhanaFont.metric(size: 20))
                        .foregroundStyle(todayDone == todayTotal ? Color.goTeal : Color.goPrimary)
                    Text("今日服药")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .goGlassBackground(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var privacyLockedView: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.goYellow)
                Text("吃药提醒仅本人可见")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(primaryText)
                Text("当前家庭成员无权查看用药计划、剂量和服药记录。")
                    .font(OhanaFont.callout())
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .ohanaStandardCard(cornerRadius: 24)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Summary Bento

    private var summaryBento: some View {
        UltimateGlassCard {
            HStack(spacing: 18) {
                medicationProgressRing

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.goPrimary)
                        Text("OVERVIEW")
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
                        overviewPill("\(activeMeds.count) 个当前用药", color: Color.goRed)
                        overviewPill("\(sevenDayCompletionRate)% 七日完成", color: Color.goPrimary)
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
                label: "今日已服",
                value: "\(todayTakenCount)",
                suffix: todayPlannedCount > 0 ? "/\(todayPlannedCount)" : "",
                color: Color.goTeal
            )
            overviewMetricCard(
                icon: "forward.fill",
                label: "已跳过",
                value: "\(todaySkippedCount)",
                suffix: "次",
                color: Color.goOrange
            )
            overviewMetricCard(
                icon: "calendar.badge.clock",
                label: "即将结束",
                value: "\(endingSoonCount)",
                suffix: "个",
                color: Color.goYellow
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
                Text("今日")
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
        if todayPlannedCount == 0 { return activeMeds.isEmpty ? "还没有服药计划" : "今日没有固定剂量" }
        if todayTakenCount == todayPlannedCount { return "今日服药已完成" }
        if todayResolvedCount == todayPlannedCount { return "今日记录已处理" }
        return "还剩 \(max(0, todayPlannedCount - todayResolvedCount)) 次待记录"
    }

    private var todayOverviewSubtitle: String {
        if todayPlannedCount == 0 { return "添加药物后，这里会展示今日进度、七日趋势和待处理剂量。" }
        let skipped = todaySkippedCount > 0 ? " · 跳过 \(todaySkippedCount)" : ""
        return "已服 \(todayTakenCount)/\(todayPlannedCount)\(skipped) · 长按快捷操作可直接回到这里。"
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

        return myMeds.reduce(0) { total, med in
            let medStart = calendar.startOfDay(for: med.startDate)
            guard startOfDay >= medStart else { return total }
            if let endDate = med.endDate,
               startOfDay > calendar.startOfDay(for: endDate) {
                return total
            }

            let dosesPerDay = med.frequency.dosesPerDay
            guard dosesPerDay > 0 else { return total }

            if med.frequency == .weekly {
                let daysSinceStart = calendar.dateComponents([.day], from: medStart, to: startOfDay).day ?? 0
                return daysSinceStart % 7 == 0 ? total + dosesPerDay : total
            }

            return total + dosesPerDay
        }
    }

    private var adherenceChartCard: some View {
        UltimateGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("近 7 天服药趋势")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(primaryText)
                        Text("计划剂量与已完成剂量对比")
                            .font(OhanaFont.caption())
                            .foregroundStyle(secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(sevenDayCompletionRate)%")
                            .font(OhanaFont.metric(size: 24))
                            .foregroundStyle(Color.goPrimary)
                        Text("完成率")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(secondaryText)
                    }
                }

                Chart {
                    ForEach(adherenceDays) { item in
                        BarMark(
                            x: .value("日期", item.dayLabel),
                            y: .value("剂量", item.planned)
                        )
                        .foregroundStyle(controlFill)
                        .position(by: .value("类型", "计划"))
                        .cornerRadius(5)

                        BarMark(
                            x: .value("日期", item.dayLabel),
                            y: .value("剂量", item.taken)
                        )
                        .foregroundStyle(Color.goPrimary.gradient)
                        .position(by: .value("类型", "已服"))
                        .cornerRadius(5)
                    }
                }
                .frame(height: 150)
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(dividerColor)
                        AxisValueLabel().foregroundStyle(secondaryText)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(secondaryText)
                    }
                }

                HStack(spacing: 14) {
                    chartLegendDot(color: secondaryText.opacity(0.55), label: "计划")
                    chartLegendDot(color: .goPrimary, label: "已服")
                    Spacer()
                    Text("按每日频率自动估算计划剂量")
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
        .goGlassBackground(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        let isTaken = item.log?.status == .taken
        let isSkipped = item.log?.status == .skipped
        
        return HStack(spacing: 16) {
            // Time
            VStack(alignment: .trailing) {
                Text(item.scheduledTime, style: .time)
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle((isTaken || isSkipped) ? tertiaryText : primaryText)
            }
            .frame(width: 52, alignment: .trailing)
            
            // Interaction Checkmark
            Button {
                toggleDoseStatus(item)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(doseStatusColor(item.log?.status), lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill((isTaken || isSkipped) ? doseStatusColor(item.log?.status) : Color.clear)
                        )
                    if isTaken {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                    } else if isSkipped {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.medication.name)
                    .font(OhanaFont.headline(.semibold))
                    .foregroundStyle((isTaken || isSkipped) ? secondaryText : primaryText)
                    .strikethrough(isTaken || isSkipped, color: secondaryText)
                if !item.medication.dosage.isEmpty {
                    Text(item.medication.dosage)
                        .font(OhanaFont.caption())
                        .foregroundStyle(tertiaryText)
                }
            }
            
            Spacer()

            Button {
                setDoseStatus(isSkipped ? .pending : .skipped, for: item)
            } label: {
                Text(isSkipped ? "已跳过" : "跳过")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(isSkipped ? Color.goOrange : secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isSkipped ? Color.goOrange : controlFill).opacity(isSkipped ? 0.16 : 1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private func toggleDoseStatus(_ item: DailyDoseItem) {
        setDoseStatus(item.log?.status == .taken ? .pending : .taken, for: item)
    }

    private func setDoseStatus(_ status: HumanMedicationStatus, for item: DailyDoseItem) {
        withAnimation(.spring(response: 0.3)) {
            let log = item.log ?? HumanMedicationLog(
                humanId: human.id.uuidString,
                medicationId: item.medication.id.uuidString,
                scheduledTime: item.scheduledTime
            )
            if item.log == nil { modelContext.insert(log) }

            log.status = status
            log.recordedTime = status == .pending ? nil : Date()

            if status != .pending {
                CareLedgerService.record(
                    occurredAt: log.recordedTime ?? Date(),
                    actorKind: .human,
                    actorId: human.id.uuidString,
                    subjectKind: .human,
                    subjectId: human.id.uuidString,
                    eventKind: .medication,
                    actionType: status == .taken ? "humanMedicationTaken" : "humanMedicationSkipped",
                    source: .detail,
                    legacyModelName: "HumanMedicationLog",
                    legacyModelId: log.id.uuidString,
                    metadataJSON: "{\"medicationId\":\"\(item.medication.id.uuidString)\"}",
                    context: modelContext,
                    save: false
                )
                if status == .taken { onDoseTaken?() }
            }

            modelContext.safeSave()
            toastMessage = doseToastMessage(status, medicationName: item.medication.name)
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showToast = false }
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
        let name = medicationName.isEmpty ? "药物" : medicationName
        switch status {
        case .taken: return "✅ 已记录 \(name)"
        case .skipped: return "⏭ 已跳过 \(name)"
        case .pending: return "↩️ 已恢复待记录"
        }
    }

    private func scheduleHumanMedicationReminders(overrideMeds: [HumanMedication]?) {
        let meds = overrideMeds ?? myMeds
        MedicationReminderService.shared.scheduleHumanMedicationReminders(for: human, meds: meds, context: modelContext)
    }

    // MARK: - Medication Row

    private func medicationRow(_ med: HumanMedication) -> some View {
        Button { editingMed = med } label: {
            UltimateGlassCard {
                HStack(spacing: 14) {
                    // Color dot + icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: med.colorHex).opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: "pills.fill")
                            .font(OhanaFont.title3(.bold))
                            .foregroundStyle(Color(hex: med.colorHex))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(med.name.isEmpty ? "未命名药物" : med.name)
                                .font(OhanaFont.callout(.bold))
                                .foregroundStyle(primaryText)
                            if !med.isActive {
                                Text("已停")
                                    .font(OhanaFont.caption2(.bold))
                                    .foregroundStyle(Color.goOrange)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.goOrange.opacity(0.15), in: Capsule())
                            }
                        }
                        HStack(spacing: 6) {
                            Text(med.frequency.emoji + " " + med.frequency.rawValue)
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
                        // 服药时间
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(OhanaFont.caption2())
                                .foregroundStyle(tertiaryText)
                            Text(med.firstDoseTime, style: .time)
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color(hex: med.colorHex))
                            if let days = med.daysRemaining {
                                Text("· 剩 \(days) 天")
                                    .font(OhanaFont.caption())
                                    .foregroundStyle(days <= 3 ? Color.goRed : tertiaryText)
                            } else {
                                Text("· 长期")
                                    .font(OhanaFont.caption())
                                    .foregroundStyle(tertiaryText)
                            }
                        }
                    }

                    Spacer()

                    // Toggle active
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            med.isActive.toggle()
                            modelContext.safeSave()
                            scheduleHumanMedicationReminders(overrideMeds: nil)
                            toastMessage = med.isActive ? "✅ \(med.name) 已恢复" : "⏸ \(med.name) 已停药"
                            showToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation { showToast = false }
                            }
                        }
                    } label: {
                        Image(systemName: med.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                            .font(OhanaFont.title3(.bold))
                            .foregroundStyle(med.isActive ? Color.goTeal : Color.goOrange)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
            }
        }
        .goGlassBackground(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        UltimateGlassCard {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.goRed.opacity(0.12)).frame(width: 72, height: 72)
                    Image(systemName: "pills").font(.system(size: 32)).foregroundStyle(Color.goRed)
                }
                Text("还没有添加药物").font(OhanaFont.title3(.bold)).foregroundStyle(primaryText)
                Text("点击下方按钮添加第一个服药提醒").font(OhanaFont.callout()).foregroundStyle(secondaryText)
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
}

// MARK: - Add / Edit Sheet

struct AddMedicationSheet: View {
    let human: Human
    var editing: HumanMedication? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allMeds: [HumanMedication]

    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency: MedicationFrequency = .daily
    @State private var customNote = ""
    @State private var firstDoseTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var colorHex = "FF4757"
    @State private var notes = ""

    private let colorOptions: [(String, String)] = [
        ("goRed", "FF4757"),
        ("goOrange", "FF8C42"),
        ("goYellow", "FFF44F"),
        ("goLime", "C8FF00"),
        ("goTeal", "00D4AA"),
        ("goBlue", "4895EF"),
        ("goPurple", "9B5DE5"),
        ("goPrimary", "4338FF"),
    ]

    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var controlFill: Color { Color.ohanaControlFill }
    private var controlStroke: Color { Color.ohanaCardStroke }

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Title
                    HStack {
                        Text(editing == nil ? "添加药物提醒" : "编辑药物")
                            .font(OhanaFont.title2(.bold))
                            .foregroundStyle(primaryText)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(OhanaFont.title2())
                                .foregroundStyle(tertiaryText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // Card 1: Basic Info
                    UltimateGlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "pills.fill", color: Color(hex: colorHex), title: "药物信息")
                            fieldRow(icon: "textformat", label: "药品名称") {
                                TextField("如：阿莫西林、维生素C", text: $name)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(primaryText)
                            }
                            fieldRow(icon: "scalemass", label: "剂量") {
                                TextField("如：1片、500mg", text: $dosage)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(primaryText)
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Card 2: Schedule
                    UltimateGlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "clock.fill", color: Color.goTeal, title: "服药时间")

                            // Frequency Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Label("频率", systemImage: "repeat")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(secondaryText)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(MedicationFrequency.allCases) { freq in
                                            Button {
                                                withAnimation(.spring(response: 0.25)) { frequency = freq }
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Text(freq.emoji)
                                                    Text(freq.rawValue)
                                                        .font(OhanaFont.caption(.bold))
                                                }
                                                .foregroundStyle(frequency == freq ? Color.arkInk : primaryText)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(frequency == freq ? Color.goTeal : controlFill, in: Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            if frequency == .custom {
                                fieldRow(icon: "text.bubble", label: "自定义说明") {
                                    TextField("说明服药频率", text: $customNote)
                                        .font(OhanaFont.body())
                                        .foregroundStyle(primaryText)
                                }
                            }

                            // First dose time
                            HStack {
                                Label("第一次服药时间", systemImage: "clock")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(secondaryText)
                                Spacer()
                                DatePicker("", selection: $firstDoseTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }

                            // Date range
                            HStack {
                                Label("开始日期", systemImage: "calendar")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(secondaryText)
                                Spacer()
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()
                            }

                            Toggle(isOn: $hasEndDate) {
                                Label("设置结束日期", systemImage: "calendar.badge.checkmark")
                                    .font(OhanaFont.callout(.bold))
                                    .foregroundStyle(primaryText)
                            }
                            .tint(Color.goTeal)

                            if hasEndDate {
                                HStack {
                                    Label("结束日期", systemImage: "calendar.badge.minus")
                                        .font(OhanaFont.caption(.bold))
                                        .foregroundStyle(secondaryText)
                                    Spacer()
                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .labelsHidden()
                                }
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Card 3: Color & Notes
                    UltimateGlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            cardHeader(icon: "paintpalette.fill", color: Color(hex: colorHex), title: "颜色 & 备注")

                            // Color picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("标签颜色")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(secondaryText)
                                HStack(spacing: 10) {
                                    ForEach(colorOptions, id: \.1) { option in
                                        Button {
                                            withAnimation(.spring(response: 0.25)) { colorHex = option.1 }
                                        } label: {
                                            Circle()
                                                .fill(Color(hex: option.1))
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Circle().strokeBorder(primaryText, lineWidth: colorHex == option.1 ? 2.5 : 0)
                                                )
                                                .scaleEffect(colorHex == option.1 ? 1.15 : 1.0)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer()
                                }
                            }

                            // Notes
                            VStack(alignment: .leading, spacing: 6) {
                                Label("备注", systemImage: "note.text")
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(secondaryText)
                                TextEditor(text: $notes)
                                    .font(OhanaFont.body())
                                    .foregroundStyle(primaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 60)
                                    .padding(10)
                                    .background(controlFill, in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(controlStroke, lineWidth: 1))
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Delete button if editing
                    if let med = editing {
                        Button {
                            modelContext.delete(med)
                            modelContext.safeSave()
                            scheduleHumanMedicationReminders(overrideMeds: allMeds.filter {
                                $0.humanId == human.id.uuidString && $0.id != med.id
                            })
                            dismiss()
                        } label: {
                            Label("删除这条药物记录", systemImage: "trash")
                                .font(OhanaFont.callout(.semibold))
                                .foregroundStyle(Color.goRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.goRed.opacity(0.1), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }

                    // Save button
                    Button { save() } label: {
                        Text(editing == nil ? "保存药物提醒" : "更新")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(name.isEmpty ? Color.goPrimary.opacity(0.4) : Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(name.isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { loadEditing() }
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
            HStack {
                content()
            }
            .padding(12)
            .background(controlFill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(controlStroke, lineWidth: 1))
        }
    }

    private func loadEditing() {
        guard let med = editing else { return }
        name = med.name
        dosage = med.dosage
        frequency = med.frequency
        customNote = med.customFrequencyNote
        firstDoseTime = med.firstDoseTime
        startDate = med.startDate
        hasEndDate = med.endDate != nil
        endDate = med.endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        colorHex = med.colorHex
        notes = med.notes
    }

    private func save() {
        let savedMed: HumanMedication
        if let med = editing {
            med.name = name
            med.dosage = dosage
            med.frequency = frequency
            med.customFrequencyNote = customNote
            med.firstDoseTime = firstDoseTime
            med.startDate = startDate
            med.endDate = hasEndDate ? endDate : nil
            med.colorHex = colorHex
            med.notes = notes
            savedMed = med
        } else {
            let med = HumanMedication(
                humanId: human.id.uuidString,
                name: name,
                dosage: dosage,
                frequency: frequency,
                firstDoseTime: firstDoseTime,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                colorHex: colorHex,
                notes: notes
            )
            med.customFrequencyNote = customNote
            modelContext.insert(med)
            savedMed = med
        }
        modelContext.safeSave()
        scheduleHumanMedicationReminders(overrideMeds: mergedMeds(including: savedMed))
        dismiss()
    }

    private func mergedMeds(including savedMed: HumanMedication) -> [HumanMedication] {
        var meds = allMeds.filter { $0.humanId == human.id.uuidString && $0.id != savedMed.id }
        meds.append(savedMed)
        return meds
    }

    private func scheduleHumanMedicationReminders(overrideMeds: [HumanMedication]) {
        MedicationReminderService.shared.scheduleHumanMedicationReminders(for: human, meds: overrideMeds, context: modelContext)
    }
}
