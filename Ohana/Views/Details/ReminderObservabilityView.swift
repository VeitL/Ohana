//
//  ReminderObservabilityView.swift
//  Ohana
//
//  Operational health panel for reminders and notification scheduling.
//

import SwiftUI
import SwiftData
import UserNotifications

struct ReminderObservabilityView: View {
    @Query(sort: \Reminder.scheduledAt) private var reminders: [Reminder]
    @Query(sort: \CareLedgerEvent.occurredAt, order: .reverse) private var ledgerEvents: [CareLedgerEvent]

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingNotificationCount: Int = 0

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
            ArkBackgroundView()
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
        .navigationTitle("提醒健康")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshNotificationStatus() }
    }

    private var healthHeader: some View {
        let score = reminderHealthScore
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("提醒系统可观测面板")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text(score.message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(score.value)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(score.color)
            }
            ProgressView(value: Double(score.value), total: 100)
                .tint(score.color)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var notificationPermissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("通知权限与系统队列", icon: "bell.badge.fill")
            HStack(spacing: 10) {
                metric("权限", authorizationStatusLabel, authorizationStatusColor)
                metric("系统待发", "\(pendingNotificationCount)", .goPrimary)
                metric("App 待办", "\(pending.count)", .goTeal)
            }
            if authorizationStatus != .authorized && authorizationStatus != .provisional {
                Text("通知权限未开启或状态异常，提醒可能只能在 App 内补偿。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.goOrange)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var statusBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("提醒状态", icon: "chart.bar.fill")
            HStack(spacing: 10) {
                metric("未来待办", "\(upcoming.count)", .goPrimary)
                metric("已过期", "\(overdue.count)", overdue.isEmpty ? .goTeal : .goOrange)
                metric("失败", "\(failed.count)", failed.isEmpty ? .goTeal : .goRed)
            }
            HStack(spacing: 10) {
                metric("本周完成", "\(completedThisWeek.count)", .goLime)
                metric("总提醒", "\(reminders.count)", .secondary)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var schedulingLedgerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("调度账本", icon: "list.clipboard.fill")
            let stats = Dictionary(grouping: reminderLedgerEvents.prefix(80), by: \.actionType)
                .map { ($0.key, $0.value.count) }
                .sorted { $0.1 > $1.1 }
            if stats.isEmpty {
                emptyText("暂无调度账本事件")
            } else {
                ForEach(stats, id: \.0) { action, count in
                    HStack {
                        Text(actionDisplayName(action))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(actionColor(action))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var riskListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("需要处理", icon: "exclamationmark.triangle.fill")
            let risky = (overdue + failed).sorted { $0.scheduledAt < $1.scheduledAt }
            if risky.isEmpty {
                emptyText("当前没有过期或失败提醒")
            } else {
                ForEach(risky.prefix(10)) { reminder in
                    HStack(spacing: 10) {
                        Image(systemName: reminder.statusEnum == .failed ? "xmark.octagon.fill" : "clock.badge.exclamationmark.fill")
                            .foregroundStyle(reminder.statusEnum == .failed ? Color.goRed : Color.goOrange)
                            .frame(width: 28, height: 28)
                            .background((reminder.statusEnum == .failed ? Color.goRed : Color.goOrange).opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.event?.title ?? "未命名提醒")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text("\(reminder.status) · \(reminder.scheduledAt.formatted(.dateTime.month().day().hour().minute()))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 22)
    }

    private var reminderHealthScore: (value: Int, color: Color, message: String) {
        var score = 100
        if authorizationStatus != .authorized && authorizationStatus != .provisional { score -= 35 }
        score -= min(overdue.count * 8, 32)
        score -= min(failed.count * 10, 30)
        if pendingNotificationCount == 0 && !upcoming.isEmpty { score -= 12 }
        let final = max(0, score)
        if final >= 85 { return (final, .goTeal, "提醒系统运行良好") }
        if final >= 60 { return (final, .goOrange, "提醒系统有少量风险") }
        return (final, .goRed, "提醒系统需要尽快检查")
    }

    private var authorizationStatusLabel: String {
        switch authorizationStatus {
        case .notDetermined: return "未请求"
        case .denied: return "拒绝"
        case .authorized: return "已开启"
        case .provisional: return "临时"
        case .ephemeral: return "临时"
        @unknown default: return "未知"
        }
    }

    private var authorizationStatusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional: return .goTeal
        case .denied: return .goRed
        default: return .goOrange
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let ids = await NotificationManager.shared.pendingNotificationIds()
        await MainActor.run {
            authorizationStatus = settings.authorizationStatus
            pendingNotificationCount = ids.count
        }
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.goPrimary)
            Text(title).font(.system(size: 15, weight: .black, design: .rounded))
            Spacer()
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionDisplayName(_ action: String) -> String {
        switch action {
        case "scheduleSuccess", "scheduled": return "调度成功"
        case "scheduleFailed", "failed", "refillFailed": return "调度失败"
        case "scheduleSkippedDuplicate", "skippedDuplicate", "refillSkippedExisting": return "重复跳过"
        case "scheduleSkippedPastDue", "skippedPastDue", "refillSkippedPastDue": return "过期跳过"
        case "refillSuccess": return "补注册成功"
        case "compensateFailed": return "过期失败补偿"
        case "compensateSkipped": return "过期跳过补偿"
        case "dedupeRemoved": return "重复提醒清理"
        default: return action
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
