//
//  TodayCareWidgetSnapshotBuilder.swift
//  Ohana
//
//  Privacy-minimized projection from Task Center values to WidgetKit values.
//

import Foundation

nonisolated enum TodayCareWidgetSnapshotBuilder {
    private static let maximumVisibleItems = 3
    private static let minimumTimelineInterval: TimeInterval = 60 * 15

    static func make(
        taskCenter: TaskCenterSnapshot,
        languageCode: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayCareWidgetSnapshot {
        let localization = L10n(languageCode)
        let candidates = (taskCenter.overdue + taskCenter.today + taskCenter.upcoming)
            .filter(isSafeForWidget)
        let items = candidates.prefix(maximumVisibleItems).map { item in
            TodayCareWidgetItem(
                id: item.id,
                title: safeTitle(for: item, localization: localization),
                subjectName: safeSubjectName(for: item),
                symbolName: safeSymbol(for: item),
                dueAt: item.dueAt,
                urgency: widgetUrgency(item.urgency)
            )
        }

        return TodayCareWidgetSnapshot(
            generatedAt: now,
            languageCode: AppLanguage.normalize(languageCode),
            access: .personal,
            completedTodayCount: taskCenter.todayCompletedCount,
            totalTodayCount: taskCenter.todayTotalCount,
            overdueCount: taskCenter.overdue.count(where: isSafeForWidget),
            items: items,
            nextRefreshAt: nextRefreshDate(
                candidates: candidates,
                now: now,
                calendar: calendar
            )
        )
    }

    private static func safeTitle(
        for item: TaskCenterItemSnapshot,
        localization: L10n
    ) -> String {
        if let eventType = item.eventType {
            return eventType.localizedLabel(localization)
        }
        return localization.tr(
            zh: "家庭待办",
            en: "Household task",
            de: "Haushaltsaufgabe",
            es: "Tarea del hogar",
            pt: "Tarefa da família",
            fr: "Tâche du foyer",
            ja: "家族のタスク",
            ko: "가족 할 일",
            it: "Attività della famiglia"
        )
    }

    private static func safeSubjectName(for item: TaskCenterItemSnapshot) -> String? {
        guard item.subject.kind != .household else { return nil }
        let name = item.subject.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return name?.isEmpty == false ? name : nil
    }

    private static func safeSymbol(for item: TaskCenterItemSnapshot) -> String {
        item.eventType?.silhouetteSymbol ?? "checkmark.circle.fill"
    }

    private static func isSafeForWidget(_ item: TaskCenterItemSnapshot) -> Bool {
        guard item.source != .systemJourney else { return false }
        guard let eventType = item.eventType else { return true }
        return switch eventType {
        case .health, .vaccine, .externalDeworming, .internalDeworming, .vetVisit,
             .medication, .petMedication, .petMedicationDose, .insurancePremium:
            false
        default:
            true
        }
    }

    private static func widgetUrgency(_ urgency: TaskCenterUrgency) -> TodayCareWidgetUrgency {
        switch urgency {
        case .standard: .standard
        case .overdue: .overdue
        case .critical: .critical
        }
    }

    private static func nextRefreshDate(
        candidates: [TaskCenterItemSnapshot],
        now: Date,
        calendar: Calendar
    ) -> Date {
        let minimumRefreshDate = now.addingTimeInterval(minimumTimelineInterval)
        let nextDueDate = candidates
            .compactMap(\.dueAt)
            .filter { $0 > now }
            .min()
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? now.addingTimeInterval(60 * 60 * 24)
        let nextDueRefresh = nextDueDate.map { max($0, minimumRefreshDate) }
        return min(nextDueRefresh ?? nextMidnight, nextMidnight)
    }
}
