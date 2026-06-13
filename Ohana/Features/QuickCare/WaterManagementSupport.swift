//
//  WaterManagementSupport.swift
//  Ohana
//
//  Water care mode, rule-state, and plan writer support.
//

import Foundation
import SwiftData

enum WaterOperatingMode: String, CaseIterable, Identifiable, Equatable {
    case manual
    case reminder

    var id: String { rawValue }

    static func stored(_ petId: UUID) -> WaterOperatingMode? {
        let raw = UserDefaults.standard.string(forKey: storageKey(petId))
        return raw.flatMap(WaterOperatingMode.init(rawValue:))
    }

    static func set(_ petId: UUID, mode: WaterOperatingMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: storageKey(petId))
    }

    private static func storageKey(_ petId: UUID) -> String {
        "water_operating_mode_\(petId.uuidString)"
    }
}

nonisolated enum WaterPlanCatchUpPolicy {
    static let catchUpWindowHours = 6
    static let catchUpWindow: TimeInterval = .init(catchUpWindowHours * 60 * 60)

    static func isCatchUpEligible(scheduledAt: Date, now: Date) -> Bool {
        scheduledAt < now && now.timeIntervalSince(scheduledAt) <= catchUpWindow
    }

    static func isExpiredMiss(scheduledAt: Date, now: Date) -> Bool {
        scheduledAt < now && now.timeIntervalSince(scheduledAt) > catchUpWindow
    }

    static func isCatchUpEligible(_ reminder: Reminder, now: Date) -> Bool {
        guard !reminder.isCompleted, reminder.isPending || reminder.isFailed else { return false }
        return isCatchUpEligible(scheduledAt: reminder.scheduledAt, now: now)
    }

    static func isExpiredMiss(_ reminder: Reminder, now: Date) -> Bool {
        guard !reminder.isCompleted, reminder.isPending || reminder.isFailed else { return false }
        return isExpiredMiss(scheduledAt: reminder.scheduledAt, now: now)
    }
}

struct WaterRuleState {
    let pet: Pet
    let allEvents: [Event]
    let now: Date
    let calendar: Calendar

    init(pet: Pet, allEvents: [Event], now: Date = Date(), calendar: Calendar = .current) {
        self.pet = pet
        self.allEvents = allEvents
        self.now = now
        self.calendar = calendar
    }

    var planEvents: [Event] {
        WaterPlanWriter.planEvents(pet: pet, allEvents: allEvents)
    }

    var operatingMode: WaterOperatingMode {
        if let stored = WaterOperatingMode.stored(pet.id) {
            return stored == .reminder && planEvents.isEmpty ? .manual : stored
        }
        return planEvents.isEmpty ? .manual : .reminder
    }

    var todayPlanReminders: [Reminder] {
        allPlanReminders
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var allPlanReminders: [Reminder] {
        planEvents
            .flatMap(\.reminders)
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var pendingTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { $0.isPending || $0.isFailed }
    }

    var missedPlanReminders: [Reminder] {
        allPlanReminders.filter { WaterPlanCatchUpPolicy.isCatchUpEligible($0, now: now) }
    }

    var expiredMissedPlanReminders: [Reminder] {
        allPlanReminders.filter { WaterPlanCatchUpPolicy.isExpiredMiss($0, now: now) }
    }

    var completedTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter(\.isCompleted)
    }

    var nextPendingReminder: Reminder? {
        guard expiredMissedPlanReminders.isEmpty else { return nil }
        return missedPlanReminders.first ?? pendingTodayPlanReminders.first
    }

    var missedCount: Int {
        missedPlanReminders.count
    }

    var completionText: String {
        "\(completedTodayPlanReminders.count)/\(max(todayPlanReminders.count, planEvents.count, 1))"
    }
}

nonisolated enum WaterRuleMetadata {
    static func localizedTitle(for event: Event, l: L10n = L10n()) -> String? {
        if event.relatedEntityType == WaterPlanWriter.entityType {
            return localizedWaterPlanTitle(for: event, l: l)
        }

        guard let kind = CarePlanCalendarSync.waterMaintenanceKind(for: event) ?? legacyMaintenanceKind(from: event.title) else {
            return nil
        }
        return localizedMaintenanceTitle(kind: kind, event: event, l: l)
    }

    private static func localizedWaterPlanTitle(for event: Event, l: L10n) -> String {
        let petName = petName(from: event.title, removing: ["喂水", "补充饮水"])
        return l.tr(
            zh: "\(petName) 喂水",
            en: "Water \(petName)",
            de: "\(petName) Wasser geben"
        )
    }

    private static func localizedMaintenanceTitle(kind: String, event: Event, l: L10n) -> String {
        switch kind {
        case "waterChange":
            let petName = petName(from: event.title, removing: ["换水"])
            return l.tr(
                zh: "\(petName) 换水",
                en: "Change \(petName)'s water",
                de: "Wasser von \(petName) wechseln"
            )
        case "filterClean":
            let petName = petName(from: event.title, removing: ["清洗滤芯", "过滤检查"])
            return l.tr(
                zh: "\(petName) 清洗滤芯",
                en: "Clean \(petName)'s filter",
                de: "Filter von \(petName) reinigen"
            )
        case "filterReplace":
            let petName = petName(from: event.title, removing: ["更换滤芯"])
            return l.tr(
                zh: "\(petName) 更换滤芯",
                en: "Replace \(petName)'s filter",
                de: "Filter von \(petName) ersetzen"
            )
        default:
            return event.title
        }
    }

    private static func legacyMaintenanceKind(from title: String) -> String? {
        if title.contains("清洗滤芯") { return "filterClean" }
        if title.contains("更换滤芯") { return "filterReplace" }
        if title.contains("换水") { return "waterChange" }
        return nil
    }

    private static func petName(from title: String, removing suffixes: [String]) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in suffixes where trimmed.hasSuffix(suffix) {
            let name = trimmed.dropLast(suffix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return String(name) }
        }
        return trimmed.isEmpty ? "Ohana" : trimmed
    }
}

enum WaterPlanWriter {
    nonisolated static let entityType = "pet_water_plan"
    private static let reminderWindowDays = 14

    static func suggestedTimes(count: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let clamped = min(max(count, 1), 6)
        let hours: [Int] = switch clamped {
        case 1: [10]
        case 2: [10, 18]
        case 3: [9, 14, 20]
        case 4: [8, 12, 16, 21]
        case 5: [7, 11, 15, 18, 22]
        default: [7, 10, 13, 16, 19, 22]
        }
        return hours.prefix(clamped).map {
            calendar.date(bySettingHour: $0, minute: 0, second: 0, of: now) ?? now
        }
    }

    static func normalizedTimes(_ times: [Date], count: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let clamped = min(max(count, 1), 6)
        let fallback = suggestedTimes(count: clamped, now: now, calendar: calendar)
        return (0 ..< clamped).map { index in
            index < times.count ? times[index] : fallback[index]
        }
    }

    @MainActor
    @discardableResult
    static func replacePlan(
        pet: Pet,
        times: [Date],
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        CarePlanCalendarSync.suppressDefaultPlan(kind: "drink", pet: pet, context: context)
        deletePlan(pet: pet, allEvents: allEvents, context: context, save: false)

        var createdReminders: [Reminder] = []
        for time in normalizedTimes(times, count: times.count, now: now, calendar: calendar) {
            let startDate = nextOccurrenceDate(forTimeOfDay: time, after: now, calendar: calendar)
            let event = Event(
                title: "\(pet.name) 喂水",
                startDate: startDate,
                eventType: EventType.daily.rawValue,
                relatedEntityType: entityType,
                relatedEntityId: pet.id.uuidString
            )
            event.recurrenceDays = 1
            event.isAllDay = false
            context.insert(event)
            createdReminders.append(contentsOf: createUpcomingReminders(for: event, context: context, now: now, calendar: calendar))
        }

        context.safeSave()
        return createdReminders
    }

    @MainActor
    static func deletePlan(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        save: Bool = true
    ) {
        var didDelete = false
        for event in planEvents(pet: pet, allEvents: allEvents) {
            deleteEvent(event, context: context)
            didDelete = true
        }
        if save, didDelete {
            context.safeSave()
        }
    }

    @MainActor
    static func deactivateReminderOperations(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date()
    ) {
        var didChange = false
        for event in planEvents(pet: pet, allEvents: allEvents) {
            let pendingReminders = event.reminders.filter(\.isPending)
            for reminder in pendingReminders {
                OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
                if reminder.scheduledAt > now {
                    context.delete(reminder)
                    didChange = true
                }
            }
        }
        if didChange {
            context.safeSave()
        }
    }

    @MainActor
    @discardableResult
    static func ensureUpcomingReminders(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        var created: [Reminder] = []
        for event in planEvents(pet: pet, allEvents: allEvents) {
            created.append(contentsOf: createUpcomingReminders(for: event, context: context, now: now, calendar: calendar))
        }
        if !created.isEmpty {
            context.safeSave()
        }
        return created
    }

    static func planEvents(pet: Pet, allEvents: [Event]) -> [Event] {
        allEvents
            .filter { isPlanEvent($0, pet: pet) }
            .sorted { $0.startDate < $1.startDate }
    }

    static func isPlanEvent(_ event: Event, pet: Pet) -> Bool {
        event.relatedEntityType == entityType &&
            event.relatedEntityId == pet.id.uuidString &&
            event.eventType == EventType.daily.rawValue
    }

    @MainActor
    private static func deleteEvent(_ event: Event, context: ModelContext) {
        for reminder in event.reminders {
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            context.delete(reminder)
        }
        context.delete(event)
    }

    @MainActor
    private static func createUpcomingReminders(
        for event: Event,
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [Reminder] {
        let existingKeys = Set(event.reminders.map { reminderKey(eventId: event.id, scheduledAt: $0.scheduledAt) })
        var created: [Reminder] = []
        for occurrence in upcomingOccurrences(for: event, now: now, daysAhead: reminderWindowDays, calendar: calendar) {
            let key = reminderKey(eventId: event.id, scheduledAt: occurrence)
            guard !existingKeys.contains(key) else { continue }
            let reminder = Reminder(event: event, scheduledAt: occurrence)
            context.insert(reminder)
            created.append(reminder)
        }
        return created
    }

    private static func upcomingOccurrences(
        for event: Event,
        now: Date,
        daysAhead: Int,
        calendar: Calendar
    ) -> [Date] {
        let end = calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now.addingTimeInterval(Double(daysAhead) * 86400)
        var cursor = event.startDate
        var guardCount = 0
        while cursor < now, guardCount < 500 {
            guard let next = calendar.date(byAdding: .day, value: max(event.recurrenceDays, 1), to: cursor) else { break }
            cursor = next
            guardCount += 1
        }

        var occurrences: [Date] = []
        while cursor <= end, guardCount < 1000 {
            occurrences.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: max(event.recurrenceDays, 1), to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return occurrences
    }

    private static func nextOccurrenceDate(forTimeOfDay time: Date, after now: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        var candidate = calendar.date(
            bySettingHour: components.hour ?? 9,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86400)
        }
        return candidate
    }

    private static func reminderKey(eventId: UUID, scheduledAt: Date) -> String {
        "\(eventId.uuidString):\(Int(scheduledAt.timeIntervalSince1970 / 60))"
    }
}
