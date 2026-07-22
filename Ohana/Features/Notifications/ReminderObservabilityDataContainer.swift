import SwiftData
import SwiftUI
import UserNotifications

nonisolated struct ReminderObservabilityRiskItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let scheduledAt: Date
    let status: ReminderStatus
}

nonisolated struct ReminderObservabilityActionCount: Identifiable, Equatable, Sendable {
    var id: String { action }
    let action: String
    let count: Int
}

nonisolated struct ReminderObservabilitySnapshot: Equatable, Sendable {
    let pendingCount: Int
    let upcomingCount: Int
    let overdueCount: Int
    let failedCount: Int
    let completedThisWeekCount: Int
    let totalCount: Int
    let riskItems: [ReminderObservabilityRiskItem]
    let actionCounts: [ReminderObservabilityActionCount]
    let hasLoaded: Bool

    static let empty = ReminderObservabilitySnapshot(
        pendingCount: 0,
        upcomingCount: 0,
        overdueCount: 0,
        failedCount: 0,
        completedThisWeekCount: 0,
        totalCount: 0,
        riskItems: [],
        actionCounts: [],
        hasLoaded: false
    )
}

nonisolated struct ReminderSafetySnapshot: Equatable, Sendable {
    let overdueCount: Int
    let failedCount: Int
    let hasLoaded: Bool

    static let empty = ReminderSafetySnapshot(
        overdueCount: 0,
        failedCount: 0,
        hasLoaded: false
    )
}

@ModelActor
actor ReminderObservabilityDataActor {
    func loadSafety(now: Date = Date()) throws -> ReminderSafetySnapshot {
        try Task.checkCancellation()
        let pendingRaw = ReminderStatus.pending.rawValue
        let failedRaw = ReminderStatus.failed.rawValue
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingRaw || reminder.status == failedRaw
            },
            sortBy: [SortDescriptor(\.scheduledAt)]
        )
        descriptor.fetchLimit = 600
        let reminders = try modelContext.fetch(descriptor) // route-first-frame: allow deferred-fetch
        return ReminderSafetySnapshot(
            overdueCount: reminders.count {
                $0.status == pendingRaw && $0.scheduledAt < now
            },
            failedCount: reminders.count { $0.status == failedRaw },
            hasLoaded: true
        )
    }

    func load(now: Date = Date()) throws -> ReminderObservabilitySnapshot {
        try Task.checkCancellation()
        let pendingRaw = ReminderStatus.pending.rawValue
        let failedRaw = ReminderStatus.failed.rawValue
        let completedRaw = ReminderStatus.completed.rawValue
        let weekCutoff = Calendar.current.date(byAdding: .day, value: -7, to: now)
            ?? now.addingTimeInterval(-7 * 86_400)

        var reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingRaw ||
                    reminder.status == failedRaw
            },
            sortBy: [SortDescriptor(\.scheduledAt)]
        )
        reminderDescriptor.fetchLimit = 600
        let activeReminders = try modelContext.fetch(reminderDescriptor) // route-first-frame: allow deferred-fetch

        var completedDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.status == completedRaw },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        completedDescriptor.fetchLimit = 200
        let completedReminders = try modelContext.fetch(completedDescriptor) // route-first-frame: allow deferred-fetch
        let reminders = activeReminders + completedReminders

        let reminderKind = CareLedgerEventKind.reminder.rawValue
        let ledgerCutoff = Calendar.current.date(byAdding: .day, value: -90, to: now)
            ?? now.addingTimeInterval(-90 * 86_400)
        var ledgerDescriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.eventKind == reminderKind && event.occurredAt >= ledgerCutoff
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        ledgerDescriptor.fetchLimit = 400
        let ledgerEvents = try modelContext.fetch(ledgerDescriptor) // route-first-frame: allow deferred-fetch

        try Task.checkCancellation()
        let pending = reminders.filter { $0.status == pendingRaw }
        let overdue = pending.filter { $0.scheduledAt < now }
        let upcoming = pending.filter { $0.scheduledAt >= now }
        let failed = reminders.filter { $0.status == failedRaw }
        let completedThisWeek = reminders.filter {
            $0.status == completedRaw && ($0.completedAt ?? .distantPast) >= weekCutoff
        }
        let risky = (overdue + failed)
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .prefix(10)
            .map {
                ReminderObservabilityRiskItem(
                    id: $0.id,
                    title: $0.event?.title ?? "",
                    scheduledAt: $0.scheduledAt,
                    status: $0.statusEnum
                )
            }
        let actionCounts = Dictionary(grouping: ledgerEvents.prefix(160), by: \.actionType)
            .map { ReminderObservabilityActionCount(action: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        let totalCount = try modelContext.fetchCount(FetchDescriptor<Reminder>())
        return ReminderObservabilitySnapshot(
            pendingCount: pending.count,
            upcomingCount: upcoming.count,
            overdueCount: overdue.count,
            failedCount: failed.count,
            completedThisWeekCount: completedThisWeek.count,
            totalCount: totalCount,
            riskItems: Array(risky),
            actionCounts: actionCounts,
            hasLoaded: true
        )
    }
}

struct ReminderObservabilityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var snapshot = ReminderObservabilitySnapshot.empty
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ReminderObservabilityContentView(snapshot: snapshot)
            .onAppear { scheduleLoad() }
            .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
                scheduleLoad(force: true)
            }
            .onDisappear {
                loadTask?.cancel()
                loadTask = nil
            }
    }

    private func scheduleLoad(force: Bool = false) {
        guard force || !snapshot.hasLoaded else { return }
        loadTask?.cancel()
        let container = modelContext.container
        loadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 80)
            guard !Task.isCancelled else { return }
            do {
                snapshot = try await ReminderObservabilityDataActor(modelContainer: container).load()
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Reminder observability snapshot load failed: \(error.localizedDescription)",
                    category: "Notifications"
                )
            }
            loadTask = nil
        }
    }
}

/// Safety-critical reminder state remains readable before the full Lv.8 panel
/// unlocks. It intentionally omits the scheduling ledger and trend analysis.
struct ReminderSafetySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var snapshot = ReminderSafetySnapshot.empty
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var loadTask: Task<Void, Never>?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                l.tr(zh: "提醒安全状态", en: "Reminder safety status", de: "Sicherheitsstatus der Erinnerungen"),
                systemImage: "bell.badge.fill"
            )
            .font(OhanaFont.title3(.black))
            .foregroundStyle(Color.ohanaPrimaryText)

            HStack(spacing: 10) {
                safetyMetric(
                    l.tr(zh: "权限", en: "Permission", de: "Rechte"),
                    permissionLabel,
                    permissionColor
                )
                safetyMetric(
                    l.tr(zh: "已过期", en: "Overdue", de: "Überfällig"),
                    "\(snapshot.overdueCount)",
                    snapshot.overdueCount == 0 ? .goTeal : .goOrange
                )
                safetyMetric(
                    l.tr(zh: "失败", en: "Failed", de: "Fehler"),
                    "\(snapshot.failedCount)",
                    snapshot.failedCount == 0 ? .goTeal : .goRed
                )
            }

            Text(safetyMessage)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityIdentifier("reminder-safety-summary")
        .task { await load() }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleReload()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func safetyMetric(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private var permissionLabel: String {
        switch authorizationStatus {
        case .authorized, .provisional: l.tr(zh: "正常", en: "Ready", de: "Bereit")
        case .denied: l.tr(zh: "关闭", en: "Off", de: "Aus")
        case .notDetermined: l.tr(zh: "未请求", en: "Not asked", de: "Nicht gefragt")
        case .ephemeral: l.tr(zh: "临时", en: "Temporary", de: "Temporär")
        @unknown default: l.tr(zh: "未知", en: "Unknown", de: "Unbekannt")
        }
    }

    private var permissionColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional: .goTeal
        case .denied: .goRed
        default: .goOrange
        }
    }

    private var safetyMessage: String {
        if authorizationStatus == .denied {
            return l.tr(
                zh: "通知权限已关闭，系统提醒可能无法送达。",
                en: "Notifications are off, so system reminders may not arrive.",
                de: "Mitteilungen sind aus; Systemerinnerungen erreichen dich möglicherweise nicht."
            )
        }
        if snapshot.failedCount > 0 || snapshot.overdueCount > 0 {
            return l.tr(
                zh: "存在失败或逾期提醒，请打开待办确认。",
                en: "Some reminders failed or are overdue. Open Tasks to review them.",
                de: "Einige Erinnerungen sind fehlgeschlagen oder überfällig. Bitte in Aufgaben prüfen."
            )
        }
        return l.tr(
            zh: "当前没有需要处理的提醒安全问题。",
            en: "No reminder safety issues need attention right now.",
            de: "Derzeit gibt es keine Sicherheitsprobleme bei Erinnerungen."
        )
    }

    private func scheduleReload() {
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    private func load() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard !Task.isCancelled else { return }
        do {
            let loaded = try await ReminderObservabilityDataActor(
                modelContainer: modelContext.container
            ).loadSafety()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                authorizationStatus = settings.authorizationStatus
                snapshot = loaded
            }
        } catch is CancellationError {
            return
        } catch {
            OhanaLog.warning(
                "Reminder safety snapshot load failed: \(error.localizedDescription)",
                category: "Notifications"
            )
        }
    }
}
