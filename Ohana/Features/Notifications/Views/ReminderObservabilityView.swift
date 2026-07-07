//
//  ReminderObservabilityView.swift
//  Ohana
//
//  Operational health panel for reminders and notification scheduling.
//

import SwiftData
import SwiftUI
import UserNotifications

struct ReminderObservabilityContentView: View {
    let reminders: [Reminder]
    let ledgerEvents: [CareLedgerEvent]

    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingNotificationCount: Int = 0

    private var l: L10n { L10n(appLanguage) }
    private var now: Date { Date() }
    private var pending: [Reminder] { reminders.filter(\.isPending) }
    private var overdue: [Reminder] { pending.filter { $0.scheduledAt < now } }
    private var upcoming: [Reminder] { pending.filter { $0.scheduledAt >= now } }
    private var failed: [Reminder] { reminders.filter { $0.statusEnum == .failed } }
    private var completedThisWeek: [Reminder] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return reminders.filter { $0.statusEnum == .completed && ($0.completedAt ?? .distantPast) >= cutoff }
    }

    private var reminderLedgerEvents: [CareLedgerEvent] {
        ledgerEvents.filter { $0.eventKindEnum == .reminder }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    healthHeader
                    notificationPermissionCard
                    statusBreakdownCard
                    schedulingLedgerCard
                    riskListCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(l.tr(zh: "提醒健康", en: "Reminder health", de: "Erinnerungsstatus"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("reminder-observability-screen")
        .task { await refreshNotificationStatus() }
    }

    private var healthHeader: some View {
        let score = reminderHealthScore
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "提醒系统可观测面板", en: "Reminder observability panel", de: "Reminder-Beobachtung"))
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                    Text(score.message)
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text("\(score.value)")
                    .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(score.color)
            }
            ProgressView(value: Double(score.value), total: 100)
                .tint(score.color)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("reminder-observability-ledger-card")
    }

    private var notificationPermissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "通知权限与系统队列", en: "Notification permission and system queue", de: "Mitteilungsrechte und Systemwarteschlange"), icon: "bell.badge.fill")
            HStack(spacing: 10) {
                metric(l.tr(zh: "权限", en: "Permission", de: "Rechte"), authorizationStatusLabel, authorizationStatusColor)
                metric(l.tr(zh: "系统待发", en: "System queued", de: "Systemwarteschlange"), "\(pendingNotificationCount)", .goPrimary)
                metric(l.tr(zh: "App 待办", en: "App pending", de: "App offen"), "\(pending.count)", .goTeal)
            }
            if authorizationStatus != .authorized, authorizationStatus != .provisional {
                Text(l.tr(
                    zh: "通知权限未开启或状态异常，提醒可能只能在 App 内补偿。",
                    en: "Notifications are disabled or in an unusual state, so reminders may only be recovered inside the app.",
                    de: "Mitteilungen sind deaktiviert oder in einem ungewoehnlichen Zustand; Erinnerungen koennen nur in der App kompensiert werden."
                ))
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.goOrange)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var statusBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "提醒状态", en: "Reminder status", de: "Reminder-Status"), icon: "chart.bar.fill")
            HStack(spacing: 10) {
                metric(l.tr(zh: "未来待办", en: "Upcoming", de: "Anstehend"), "\(upcoming.count)", .goPrimary)
                metric(l.tr(zh: "已过期", en: "Overdue", de: "Ueberfaellig"), "\(overdue.count)", overdue.isEmpty ? .goTeal : .goOrange)
                metric(l.tr(zh: "失败", en: "Failed", de: "Fehlgeschlagen"), "\(failed.count)", failed.isEmpty ? .goTeal : .goRed)
            }
            HStack(spacing: 10) {
                metric(l.tr(zh: "本周完成", en: "Done this week", de: "Diese Woche erledigt"), "\(completedThisWeek.count)", .goPrimary)
                metric(l.tr(zh: "总提醒", en: "Total reminders", de: "Reminder gesamt"), "\(reminders.count)", .secondary)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var schedulingLedgerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "调度账本", en: "Scheduling ledger", de: "Planungsprotokoll"), icon: "list.clipboard.fill")
            let stats = Dictionary(grouping: reminderLedgerEvents.prefix(80), by: \.actionType)
                .map { ($0.key, $0.value.count) }
                .sorted { $0.1 > $1.1 }
            if stats.isEmpty {
                emptyText(l.tr(zh: "暂无调度账本事件", en: "No scheduling ledger events yet", de: "Noch keine Planungsereignisse"))
            } else {
                ForEach(stats, id: \.0) { action, count in
                    HStack {
                        Text(Self.actionDisplayName(action, l))
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        Spacer()
                        Text("\(count)")
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(actionColor(action))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var riskListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "需要处理", en: "Needs attention", de: "Benötigt Aufmerksamkeit"), icon: "exclamationmark.triangle.fill")
            let risky = (overdue + failed).sorted { $0.scheduledAt < $1.scheduledAt }
            if risky.isEmpty {
                emptyText(l.tr(zh: "当前没有过期或失败提醒", en: "No overdue or failed reminders right now", de: "Derzeit keine ueberfaelligen oder fehlgeschlagenen Reminder"))
            } else {
                ForEach(risky.prefix(10)) { reminder in
                    HStack(spacing: 10) {
                        Image(systemName: reminder.statusEnum == .failed ? "xmark.octagon.fill" : "clock.badge.exclamationmark.fill")
                            .foregroundStyle(reminder.statusEnum == .failed ? Color.goRed : Color.goOrange)
                            .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                            .background((reminder.statusEnum == .failed ? Color.goRed : Color.goOrange).opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.event?.title ?? l.tr(zh: "未命名提醒", en: "Unnamed reminder", de: "Unbenannter Reminder"))
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text("\(reminder.statusEnum.localizedLabel(l)) · \(reminder.scheduledAt.formatted(.dateTime.month().day().hour().minute()))")
                                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var reminderHealthScore: (value: Int, color: Color, message: String) {
        var score = 100
        if authorizationStatus != .authorized, authorizationStatus != .provisional { score -= 35 }
        score -= min(overdue.count * 8, 32)
        score -= min(failed.count * 10, 30)
        if pendingNotificationCount == 0, !upcoming.isEmpty { score -= 12 }
        let final = max(0, score)
        if final >= 85 { return (final, .goTeal, l.tr(zh: "提醒系统运行良好", en: "Reminder system looks healthy", de: "Reminder-System sieht gesund aus")) }
        if final >= 60 { return (final, .goOrange, l.tr(zh: "提醒系统有少量风险", en: "Reminder system has a few risks", de: "Reminder-System hat einige Risiken")) }
        return (final, .goRed, l.tr(zh: "提醒系统需要尽快检查", en: "Reminder system needs attention soon", de: "Reminder-System braucht bald Aufmerksamkeit"))
    }

    private var authorizationStatusLabel: String {
        switch authorizationStatus {
        case .notDetermined: return l.tr(zh: "未请求", en: "Not requested", de: "Nicht gefragt")
        case .denied: return l.tr(zh: "拒绝", en: "Denied", de: "Abgelehnt")
        case .authorized: return l.tr(zh: "已开启", en: "Enabled", de: "Aktiviert")
        case .provisional: return l.tr(zh: "临时", en: "Provisional", de: "Vorlaeufig")
        case .ephemeral: return l.tr(zh: "临时", en: "Temporary", de: "Temporär")
        @unknown default: return l.tr(zh: "未知", en: "Unknown", de: "Unbekannt")
        }
    }

    private var authorizationStatusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional: .goTeal
        case .denied: .goRed
        default: .goOrange
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let ids = await appServices.userNotifications.pendingNotificationIds()
        await MainActor.run {
            authorizationStatus = settings.authorizationStatus
            pendingNotificationCount = ids.count
        }
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.goPrimary)
            Text(title).font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
            Spacer()
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    nonisolated static func actionDisplayName(_ action: String, _ l: L10n) -> String {
        switch action {
        case "scheduleSuccess", "scheduled": l.tr(zh: "调度成功", en: "Scheduled", de: "Geplant")
        case "scheduleDeferred", "refillDeferred": l.tr(zh: "夜间延后", en: "Deferred overnight", de: "Nachts verschoben")
        case "scheduleFailed", "failed", "refillFailed": l.tr(zh: "调度失败", en: "Schedule failed", de: "Planung fehlgeschlagen")
        case "scheduleSkippedDuplicate", "skippedDuplicate", "refillSkippedExisting": l.tr(zh: "重复跳过", en: "Duplicate skipped", de: "Duplikat uebersprungen")
        case "scheduleSkippedPastDue", "skippedPastDue", "refillSkippedPastDue": l.tr(zh: "过期跳过", en: "Past due skipped", de: "Ueberfaellig uebersprungen")
        case "scheduleSkippedBudget", "refillSkippedBudget": l.tr(zh: "预算跳过", en: "Budget skipped", de: "Budget uebersprungen")
        case "scheduleMerged", "refillMerged": l.tr(zh: "同类合并", en: "Merged", de: "Zusammengefuehrt")
        case "refillSuccess": l.tr(zh: "补注册成功", en: "Refill registered", de: "Nachfuellung registriert")
        case "compensateFailed": l.tr(zh: "过期失败补偿", en: "Overdue failure recovered", de: "Ueberfaellige Fehlschlaege kompensiert")
        case "compensateSkipped": l.tr(zh: "过期跳过补偿", en: "Overdue skip recovered", de: "Ueberfaellige Ueberspruenge kompensiert")
        case "dedupeRemoved": l.tr(zh: "重复提醒清理", en: "Duplicate reminders removed", de: "Doppelte Reminder entfernt")
        default: action
        }
    }

    private func actionColor(_ action: String) -> Color {
        if action.localizedCaseInsensitiveContains("Failed") || action.localizedCaseInsensitiveContains("failed") {
            return .goRed
        }
        if action.localizedCaseInsensitiveContains("Skipped") || action.localizedCaseInsensitiveContains("dedupe") {
            return .goOrange
        }
        return .goTeal
    }
}
