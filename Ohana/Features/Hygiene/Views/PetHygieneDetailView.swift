//
//  PetHygieneDetailView.swift
//  Ohana
//
//  护理详情页 — 参考饮食管理页风格
//  深色背景 + ScrollView 卡片 + 极简月频条
//

import SwiftData
import SwiftUI

// MARK: - Chart Data Point for Hygiene
private struct HygieneChartPoint: Identifiable {
    var id: Date { day }
    let day: Date
    let count: Int
    let label: String
}

struct PetHygieneDetailContentView: View {
    let pet: Pet
    let allReminders: [Reminder]
    let hygieneEntries: [PetHygieneLedgerEntry]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var groomingPlanTarget: HygieneType? = nil
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    /// 用于匹配 `HygieneTodoSheet` 写入的 Event 标题前缀：`\(pet.name) — \(type.rawValue)`

    private var themeColor: Color {
        Color(hex: pet.safeThemeColorHex)
    }

    private var isDark: Bool { colorScheme == .dark }
    private var chromeAccent: Color { isDark ? Color.goPrimary : Color.goBlue }
    private var l: L10n { L10n(appLanguage) }

    private func latestHygieneDate(_ type: HygieneType) -> Date? {
        hygieneEntries.first(where: { $0.type == type })?.date
    }

    private func cycleStatus(_ type: HygieneType, now: Date = Date()) -> CareCycleStatus? {
        type.cycleStatus(
            lastDate: latestHygieneDate(type),
            petId: pet.id,
            now: now,
            calendar: .current
        )
    }

    private func statusColor(_ status: CareCycleStatus?) -> Color {
        guard let status else { return themeColor.opacity(0.42) }
        switch status.duePhase {
        case .upcoming:
            return themeColor
        case .dueToday:
            return Color.goOrange
        case .overdue:
            return Color.goRed
        }
    }

    /// 与 `HygieneTodoSheet.save()` 写入的标题前缀一致（含备注时仍以此前缀开头）
    private func titlePrefix(for type: HygieneType) -> String {
        "\(pet.name) — \(type.rawValue)"
    }

    private func pendingHygienePlans(for type: HygieneType) -> [Reminder] {
        let pid = pet.id.uuidString
        let prefix = titlePrefix(for: type)
        return allReminders.filter { r in
            guard r.statusEnum == .pending,
                  let ev = r.event,
                  ev.eventType == EventType.grooming.rawValue,
                  MemberLifecycleActiveScheduleResolver.eventBelongsToPet(ev, petId: pid) else { return false }
            return ev.title.hasPrefix(prefix)
        }
        .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private func recurrenceLabel(_ days: Int) -> String {
        switch days {
        case 0:
            l.tr(zh: "不重复", en: "No repeat", de: "Keine Wiederholung")
        case 1:
            l.tr(zh: "每天", en: "Daily", de: "Täglich")
        case 2:
            l.tr(zh: "每 2 天", en: "Every 2 days", de: "Alle 2 Tage")
        case 3:
            l.tr(zh: "每 3 天", en: "Every 3 days", de: "Alle 3 Tage")
        case 7:
            l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich")
        case 14:
            l.tr(zh: "每两周", en: "Every 2 weeks", de: "Alle 2 Wochen")
        case 30:
            l.tr(zh: "每月", en: "Monthly", de: "Monatlich")
        default:
            l.tr(zh: "每 \(days) 天", en: "Every \(days) days", de: "Alle \(days) Tage")
        }
    }

    /// 近 28 天极简条（左旧右新），仅看打卡频率
    private func monthStripPoints(_ type: HygieneType) -> [HygieneChartPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0 ..< 28).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = hygieneEntries.count(where: {
                $0.type == type && cal.isDate($0.date, inSameDayAs: d)
            })
            return HygieneChartPoint(day: d, count: count, label: "")
        }
    }

    @ViewBuilder
    private func monthFrequencyStrip(_ type: HygieneType) -> some View {
        let pts = monthStripPoints(type)
        let maxH: CGFloat = 22
        VStack(alignment: .leading, spacing: 6) {
            Text(l.tr(zh: "近 28 天", en: "Last 28 days", de: "Letzte 28 Tage"))
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 2) {
                ForEach(pts) { pt in
                    let h = min(maxH, 4 + CGFloat(min(pt.count, 4)) * 4)
                    RoundedRectangle(cornerRadius: OhanaRadius.hairline, style: .continuous)
                        .fill(themeColor.opacity(pt.count > 0 ? 0.72 : 0.12))
                        .frame(width: 5, height: h)
                }
            }
            .frame(height: maxH, alignment: .bottom)
        }
    }

    private var monthlyTotalCount: Int {
        let cal = Calendar.current
        let now = Date()
        return hygieneEntries.count(where: { cal.isDate($0.date, equalTo: now, toGranularity: .month) })
    }

    private var currentStrike: Int {
        let cal = Calendar.current
        var strike = 0
        var lastDateByType: [String: Date] = [:]

        for entry in hygieneEntries.sorted(by: { $0.date < $1.date }) {
            let type = entry.type
            if let lastDate = lastDateByType[type.rawValue] {
                let days = cal.dateComponents(
                    [.day],
                    from: cal.startOfDay(for: lastDate),
                    to: cal.startOfDay(for: entry.date)
                ).day ?? 0
                strike = days <= type.effectiveCycleDays(for: pet.id) ? strike + 1 : 1
            } else {
                strike += 1
            }
            lastDateByType[type.rawValue] = entry.date
        }
        return strike
    }

    private var attentionTypes: [HygieneType] {
        HygieneType.allCases.filter { type in
            cycleStatus(type)?.requiresAttention == true
        }
    }

    private var hasOverdueType: Bool {
        HygieneType.allCases.contains { type in
            cycleStatus(type)?.isOverdue == true
        }
    }

    private var completedTodayCount: Int {
        HygieneType.allCases.count(where: { isDoneToday($0) })
    }

    @State private var hygieneCycleRefresh = 0
    @State private var showSingleUseNotice = false
    @State private var singleUseNoticeMessage = ""

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    hygieneHeader
                    // ── 本月概览（无卡片背景）
                    monthlySummaryCard
                    // ── 5 项护理卡片（打卡 + 计划；顶部状态条已移除，与首页快捷护理重复）
                    ForEach(HygieneType.allCases, id: \.rawValue) { type in
                        hygieneTypeCard(type)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeColor)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("pet-hygiene-detail-screen")
        // 护理卡片「计划」按钮 → 待办 sheet
        .sheet(item: $groomingPlanTarget) { hygieneType in
            HygieneTodoSheet(pet: pet, type: hygieneType, accent: themeColor) {
                hygieneCycleRefresh += 1
            }
            .presentationDetents([.medium, .large])
        }
        .alert(l.tr(zh: "今天已经完成了", en: "Already done today", de: "Heute schon erledigt"), isPresented: $showSingleUseNotice) {
            Button(l.tr(zh: "知道了", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(singleUseNoticeMessage)
        }
    }

    private var hygieneHeader: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                pet: pet,
                fallbackText: pet.avatarEmoji,
                themeColor: chromeAccent,
                size: 46,
                backgroundOpacity: isDark ? 0.18 : 0.12
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "护理", en: "Care", de: "Pflege"))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 40, height: 40) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 4)
    }

    // MARK: - 本月概览
    private var monthlySummaryCard: some View {
        let totalTypes = max(HygieneType.allCases.count, 1)
        let progress = CGFloat(completedTodayCount) / CGFloat(totalTypes)
        let attentionTint = hasOverdueType ? Color.goRed : Color.goOrange
        let headline = attentionTypes.isEmpty
            ? l.tr(zh: "今天的护理节奏很好", en: "Care rhythm looks good today", de: "Der Pflegerhythmus passt heute")
            : l.tr(zh: "\(attentionTypes.count) 项护理需要关注", en: "\(attentionTypes.count) care items need attention", de: "\(attentionTypes.count) Pflegepunkte brauchen Aufmerksamkeit")

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(themeColor.opacity(0.16), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(themeColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(completedTodayCount)/\(totalTypes)")
                            .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "今日", en: "Today", de: "Heute"))
                            .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 5) {
                    Text(headline)
                        .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(attentionTypes.isEmpty ? l.tr(zh: "继续保持，下一次护理会自动提醒。", en: "Keep going. The next care item will remind you.", de: "Weiter so. Die nächste Pflege erinnert dich.") : attentionTypes.map { $0.localizedLabel(l) }.joined(separator: l.tr(zh: "、", en: ", ", de: ", ")))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(attentionTypes.isEmpty ? .secondary : attentionTint.opacity(0.9))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                overviewMetric(icon: "sparkle", value: "\(monthlyTotalCount)", label: l.tr(zh: "本月护理", en: "This month", de: "Dieser Monat"), tint: themeColor)
                overviewMetric(icon: "bolt.fill", value: "\(currentStrike)", label: l.tr(zh: "连续打卡", en: "Streak", de: "Serie"), tint: Color.goOrange)
                overviewMetric(icon: "clock", value: "\(attentionTypes.count)", label: l.tr(zh: "待护理", en: "Due", de: "Fällig"), tint: attentionTypes.isEmpty ? themeColor : attentionTint)
            }
        }
        .padding(.vertical, 6)
    }

    private func overviewMetric(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(label)
                    .font(OhanaFont.adaptive(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    // MARK: - 是否今天已完成
    private func isDoneToday(_ type: HygieneType) -> Bool {
        hygieneEntries.contains {
            $0.type == type && Calendar.current.isDateInToday($0.date)
        }
    }

    // MARK: - 护理类型卡片（重构）
    private func hygieneTypeCard(_ type: HygieneType) -> some View {
        _ = hygieneCycleRefresh
        let logs = hygieneEntries.filter { $0.type == type }.sorted { $0.date > $1.date }
        let status = cycleStatus(type)
        let color = statusColor(status)
        let stripHasData = monthStripPoints(type).contains { $0.count > 0 }
        let doneToday = isDoneToday(type)
        let plans = pendingHygienePlans(for: type)
        let accessibilityPrefix = "pet-hygiene-\(type.accessibilityIdentifierFragment)"

        return VStack(alignment: .leading, spacing: 10) {
            // 标题行：名称 + 状态 + 计划 + 打卡（主题色仅用于图标/按钮）
            HStack(spacing: 6) {
                Image(systemName: type.systemIconName)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text(type.localizedLabel(l))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 4)
                if let status {
                    Text(status.requiresAttention ? status.compactDueText(l: l) : status.compactLastRecordedText(l: l))
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(status.elapsedDays == 0 ? themeColor : color)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((status.elapsedDays == 0 ? themeColor : color).opacity(0.14), in: Capsule())
                } else {
                    Text(l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag"))
                        .font(OhanaFont.adaptive(size: 10, weight: .medium))
                        .foregroundStyle(themeColor.opacity(0.55))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(themeColor.opacity(0.1), in: Capsule())
                }
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    groomingPlanTarget = type
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.badge.plus").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 10, weight: .bold))
                        Text(l.tr(zh: "计划", en: "Plan", de: "Plan"))
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(themeColor.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(themeColor.opacity(0.35), lineWidth: 0.5))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("\(accessibilityPrefix)-plan-action")
                Button {
                    recordHygiene(type, doneToday: doneToday)
                } label: {
                    if doneToday {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 11, weight: .bold))
                            .foregroundStyle(themeColor.opacity(0.55))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(themeColor.opacity(0.1), in: Capsule())
                    } else {
                        Text(l.tr(zh: "打卡", en: "Log", de: "Erfassen"))
                            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goCardWhite)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(themeColor, in: Capsule())
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("\(accessibilityPrefix)-record-action")
            }

            // 已添加的护理计划（HygieneTodoSheet → Event + Reminder）
            if !plans.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 10, weight: .bold))
                        Text(l.tr(zh: "已设计划", en: "Plans set", de: "Geplante Pflege"))
                            .font(OhanaFont.adaptive(size: 10, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))

                    ForEach(plans, id: \.id) { rem in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "calendar").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                                .foregroundStyle(themeColor)
                                .frame(width: 16, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rem.scheduledAt, format: .dateTime.month().day())
                                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                if let ev = rem.event, ev.recurrenceDays > 0 {
                                    Text(l.tr(zh: "重复 · \(recurrenceLabel(ev.recurrenceDays))", en: "Repeats · \(recurrenceLabel(ev.recurrenceDays))", de: "Wiederholt · \(recurrenceLabel(ev.recurrenceDays))"))
                                        .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ohanaSecondaryText)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeColor.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.22), lineWidth: 0.5)
                )
            }

            if stripHasData {
                monthFrequencyStrip(type)
            }

            // 周期标签 + 自定义按钮
            HStack(spacing: 6) {
                let effectiveDays = type.effectiveCycleDays(for: pet.id)
                let isCustom = HygieneType.customCycleDays(for: type, petId: pet.id) != nil
                Image(systemName: "repeat").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 9, weight: .semibold))
                    .foregroundStyle(themeColor.opacity(0.6))
                Text(cycleSummary(days: effectiveDays, isCustom: isCustom))
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.7))
                Spacer()
            }

            // 最近记录（无分割线）
            if !logs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(logs.prefix(3)) { log in
                        HStack {
                            Text(log.date, format: .dateTime.month().day().hour().minute())
                                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText.opacity(0.7))
                            Spacer()
                            Button { deleteHygieneEntry(log) } label: {
                                Image(systemName: "trash").accessibilityHidden(true).font(OhanaFont.adaptive(size: 10))
                                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.4))
                            }
                            .accessibilityIdentifier("\(accessibilityPrefix)-delete-\(log.id.uuidString)")
                        }
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("\(accessibilityPrefix)-recent-row-\(log.id.uuidString)")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
    }

    private func recordHygiene(_ type: HygieneType, doneToday: Bool) {
        guard !doneToday else {
            singleUseNoticeMessage = l.tr(
                zh: "\(pet.name) 今天已经记录过\(type.localizedLabel(l))了，这类护理一天记录一次就够了。",
                en: "\(pet.name) already has \(type.localizedLabel(l)) logged today. Once per day is enough for this care type.",
                de: "\(type.localizedLabel(l)) wurde für \(pet.name) heute schon erfasst. Einmal pro Tag reicht."
            )
            showSingleUseNotice = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        let executorId = appServices.activeHumanSelection.currentHumanId
        let command = DomainCommand.petHygieneRecord(petID: pet.id, type: type.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            PetHygieneCommandExecutor(context: modelContext, services: appServices).record(
                pet: pet,
                type: type,
                executorId: executorId,
                note: "pet.hygiene.detail.record"
            )
        }
    }

    private func deleteHygieneEntry(_ entry: PetHygieneLedgerEntry) {
        guard let logId = entry.legacyLogId else {
            OhanaLog.warning(
                "PetHygieneDetailView could not resolve hygiene log for ledger entry \(entry.id.uuidString)",
                category: "Care"
            )
            return
        }
        let command = DomainCommand.petHygieneDelete(petID: pet.id, recordID: logId)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            let executor = PetHygieneCommandExecutor(context: modelContext, services: appServices)
            guard let log = executor.hygieneLog(id: logId) else {
                OhanaLog.warning(
                    "PetHygieneDetailView could not resolve hygiene log \(logId.uuidString)",
                    category: "Care"
                )
                return
            }
            // recordDeletion: PetHygieneCommandService.delete marks CloudSync tombstones.
            executor.delete(
                log,
                pet: pet,
                note: "pet.hygiene.detail.delete"
            )
        }
    }

    private func cycleSummary(days: Int, isCustom: Bool) -> String {
        let base = l.tr(zh: "每\(days)天", en: "Every \(days) days", de: "Alle \(days) Tage")
        guard isCustom else { return base }
        return l.tr(zh: "\(base) · 已自定义", en: "\(base) · Custom", de: "\(base) · Eigene Einstellung")
    }
}

private extension HygieneType {
    var accessibilityIdentifierFragment: String {
        switch self {
        case .teeth: "teeth"
        case .nails: "nails"
        case .ears: "ears"
        case .brushing: "brushing"
        case .bath: "bath"
        }
    }
}
