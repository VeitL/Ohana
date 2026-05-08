//
//  FeedManagementSupport.swift
//  Ohana
//
//  Shared feeding helpers for food stock, feed log source metadata, and auto feeder rules.
//

import Foundation
import SwiftData

enum FeedLogSource: String {
    case manualMain
    case manualReminder
    case autoMain
    case treat
}

enum FeedLogMetadata {
    static let autoFeedNotePrefix = "ohana_auto_feed:"
    static let treatFeedNoteMarker = "ohana_treat_feed"

    static func source(for log: PetCareLog) -> FeedLogSource? {
        guard log.careType == .feeding else { return nil }
        if log.note.hasPrefix(PetCareLog.plannedFeedNotePrefix) { return .manualReminder }
        if log.note.hasPrefix(autoFeedNotePrefix) { return .autoMain }
        if log.note.hasPrefix(treatFeedNoteMarker) { return .treat }
        return .manualMain
    }

    static func isMainFoodLog(_ log: PetCareLog) -> Bool {
        guard let source = source(for: log) else { return false }
        return source != .treat
    }

    static func isTreatLog(_ log: PetCareLog) -> Bool {
        source(for: log) == .treat
    }

    static func autoDedupKey(eventId: UUID, scheduledAt: Date) -> String {
        "\(eventId.uuidString):\(Int(scheduledAt.timeIntervalSince1970 / 60))"
    }

    static func autoNote(eventId: UUID, scheduledAt: Date) -> String {
        "\(autoFeedNotePrefix)\(autoDedupKey(eventId: eventId, scheduledAt: scheduledAt))"
    }

    static func autoDedupKey(from note: String) -> String? {
        guard note.hasPrefix(autoFeedNotePrefix) else { return nil }
        return String(note.dropFirst(autoFeedNotePrefix.count))
    }
}

enum FeedRuleKind: String, CaseIterable {
    case manualReminder
    case autoFeeder

    var iconName: String {
        switch self {
        case .manualReminder: return "bell.badge.fill"
        case .autoFeeder: return "dot.radiowaves.left.and.right"
        }
    }
}

enum FeedRuleMetadata {
    static let autoFeederEntityType = "pet_auto_feeder"

    static func isManualReminderEvent(_ event: Event, pet: Pet) -> Bool {
        (event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet") &&
        event.relatedEntityId == pet.id.uuidString &&
        event.eventType == EventType.foodChange.rawValue
    }

    static func isAutoFeederEvent(_ event: Event, pet: Pet) -> Bool {
        event.relatedEntityType == autoFeederEntityType &&
        event.relatedEntityId == pet.id.uuidString &&
        event.eventType == EventType.foodChange.rawValue
    }

    static func amountGrams(from event: Event, fallback: Double = 0) -> Double {
        let pattern = #"(\d+(?:[\.,]\d+)?)\s*g"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(event.title.startIndex..<event.title.endIndex, in: event.title)
            if let match = regex.firstMatch(in: event.title, options: [], range: range),
               let capture = Range(match.range(at: 1), in: event.title) {
                let raw = String(event.title[capture]).replacingOccurrences(of: ",", with: ".")
                if let value = Double(raw) { return value }
            }
        }
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? fallback
    }

    static func title(kind: FeedRuleKind, date: Date, amountGrams: Double) -> String {
        let rounded = Int(amountGrams.rounded())
        switch kind {
        case .manualReminder:
            return rounded > 0 ? "\(mealName(for: date)) \(rounded)g" : mealName(for: date)
        case .autoFeeder:
            return rounded > 0 ? "自动喂食器 \(rounded)g" : "自动喂食器"
        }
    }

    static func mealName(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<10: return "早餐"
        case 10..<14: return "午餐"
        case 14..<17: return "下午餐"
        case 17..<21: return "晚餐"
        default: return "夜宵"
        }
    }

    static func dueOccurrences(for event: Event, through now: Date, calendar: Calendar = .current, maxLookbackDays: Int = 45) -> [Date] {
        let intervalDays = max(event.recurrenceDays, 1)
        let end = min(event.recurrenceEndDate ?? now, now)
        guard event.startDate <= end else { return [] }

        let lookback = calendar.date(byAdding: .day, value: -maxLookbackDays, to: now) ?? event.startDate
        var cursor = event.startDate
        if cursor < lookback {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: event.startDate),
                to: calendar.startOfDay(for: lookback)
            ).day ?? 0
            let steps = max(0, days / intervalDays)
            cursor = calendar.date(byAdding: .day, value: steps * intervalDays, to: event.startDate) ?? event.startDate
            while cursor < lookback {
                guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
                cursor = next
            }
        }

        var dates: [Date] = []
        var guardCount = 0
        while cursor <= end && guardCount < 500 {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return dates
    }
}

struct FeedStockSnapshot {
    let totalGrams: Double
    let consumedGrams: Double
    let remainingGrams: Double
    let estimatedDailyGrams: Double
    let estimatedDailyBasis: FeedStockDailyBasis
    let remainingDays: Int
    let runOutDate: Date?
}

enum FeedStockDailyBasis {
    case recentAverage
    case autoRules
    case defaultPortion
    case unavailable
}

enum FeedStockCalculator {
    static func mainFoodLogs(for pet: Pet, since startDate: Date? = nil) -> [PetCareLog] {
        pet.careLogs.filter { log in
            log.careType == .feeding &&
            FeedLogMetadata.isMainFoodLog(log) &&
            (startDate.map { log.date >= $0 } ?? true)
        }
    }

    static func treatLogs(for pet: Pet, since startDate: Date? = nil) -> [PetCareLog] {
        pet.careLogs.filter { log in
            log.careType == .feeding &&
            FeedLogMetadata.isTreatLog(log) &&
            (startDate.map { log.date >= $0 } ?? true)
        }
    }

    static func mainConsumedSinceRestock(for pet: Pet) -> Double {
        mainFoodLogs(for: pet, since: pet.restockDate)
            .reduce(0) { total, log in
                total + effectiveMainFoodAmount(for: log, pet: pet)
            }
    }

    static func effectiveMainFoodAmount(for log: PetCareLog, pet: Pet) -> Double {
        log.amountGrams > 0 ? log.amountGrams : pet.dailyPortionGrams
    }

    static func recentDailyAverageGrams(for pet: Pet, now: Date = Date(), calendar: Calendar = .current) -> Double? {
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return nil }
        let logs = mainFoodLogs(for: pet, since: maxDate(windowStart, pet.restockDate))
            .filter { $0.date <= now }
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
        let dayTotals = grouped.values.map { logs in
            logs.reduce(0) { $0 + effectiveMainFoodAmount(for: $1, pet: pet) }
        }.filter { $0 > 0 }
        guard !dayTotals.isEmpty else { return nil }
        return dayTotals.reduce(0, +) / Double(dayTotals.count)
    }

    static func autoRuleDailyTotalGrams(for pet: Pet, events: [Event]) -> Double {
        events
            .filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }
            .reduce(0) { total, event in
                total + max(0, FeedRuleMetadata.amountGrams(from: event))
            }
    }

    static func estimatedDailyMainFoodGrams(for pet: Pet, events: [Event] = [], now: Date = Date(), calendar: Calendar = .current) -> (Double, FeedStockDailyBasis) {
        if let average = recentDailyAverageGrams(for: pet, now: now, calendar: calendar), average > 0 {
            return (average, .recentAverage)
        }
        let autoTotal = autoRuleDailyTotalGrams(for: pet, events: events)
        if autoTotal > 0 { return (autoTotal, .autoRules) }
        if pet.dailyPortionGrams > 0 { return (pet.dailyPortionGrams, .defaultPortion) }
        return (0, .unavailable)
    }

    static func snapshot(for pet: Pet, events: [Event] = [], now: Date = Date(), calendar: Calendar = .current) -> FeedStockSnapshot {
        let total = max(0, pet.restockWeight * 1000)
        let consumed = mainConsumedSinceRestock(for: pet)
        let remaining = max(0, total - consumed)
        let estimate = estimatedDailyMainFoodGrams(for: pet, events: events, now: now, calendar: calendar)
        let days = estimate.0 > 0 ? Int(remaining / estimate.0) : 0
        let runOut = days > 0 ? calendar.date(byAdding: .day, value: days, to: now) : nil
        return FeedStockSnapshot(
            totalGrams: total,
            consumedGrams: consumed,
            remainingGrams: remaining,
            estimatedDailyGrams: estimate.0,
            estimatedDailyBasis: estimate.1,
            remainingDays: days,
            runOutDate: runOut
        )
    }

    private static func maxDate(_ lhs: Date, _ rhs: Date?) -> Date {
        guard let rhs else { return lhs }
        return max(lhs, rhs)
    }
}

struct FeedRuleState {
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

    var manualReminderEvents: [Event] {
        allEvents
            .filter { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }
            .sorted { $0.startDate < $1.startDate }
    }

    var autoFeederEvents: [Event] {
        allEvents
            .filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }
            .sorted { $0.startDate < $1.startDate }
    }

    var todayManualReminders: [Reminder] {
        manualReminderEvents
            .flatMap(\.reminders)
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var pendingTodayManualReminders: [Reminder] {
        todayManualReminders.filter { $0.isPending || $0.isFailed }
    }

    var completedTodayManualReminders: [Reminder] {
        todayManualReminders.filter { $0.isCompleted }
    }

    var nextPendingManualReminder: Reminder? {
        pendingTodayManualReminders.first
    }

    var autoDailyTotalGrams: Double {
        FeedStockCalculator.autoRuleDailyTotalGrams(for: pet, events: allEvents)
    }
}

enum FeedAutoLogMaterializer {
    @discardableResult
    @MainActor
    static func materializeDueLogs(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let autoEvents = FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar).autoFeederEvents
        guard !autoEvents.isEmpty else { return 0 }

        var existingKeys = Set(
            pet.careLogs.compactMap { FeedLogMetadata.autoDedupKey(from: $0.note) }
        )
        var inserted = 0

        for event in autoEvents {
            let grams = FeedRuleMetadata.amountGrams(from: event, fallback: pet.dailyPortionGrams)
            guard grams > 0 else { continue }
            for dueDate in FeedRuleMetadata.dueOccurrences(for: event, through: now, calendar: calendar) {
                let key = FeedLogMetadata.autoDedupKey(eventId: event.id, scheduledAt: dueDate)
                guard !existingKeys.contains(key) else { continue }
                let log = PetCareLog(
                    date: dueDate,
                    type: .feeding,
                    amountGrams: grams,
                    note: FeedLogMetadata.autoNote(eventId: event.id, scheduledAt: dueDate),
                    pet: pet,
                    executorId: nil
                )
                context.insert(log)
                CareLedgerService.recordPetCare(
                    log: log,
                    pet: pet,
                    source: .service,
                    sourceEventId: event.id.uuidString,
                    coconutDelta: 0,
                    context: context
                )
                existingKeys.insert(key)
                inserted += 1
            }
        }

        if inserted > 0 {
            context.safeSave()
        }
        return inserted
    }
}
