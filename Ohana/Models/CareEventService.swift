//
//  CareEventService.swift
//  Ohana
//
//  Centralized care/reminder/economy write paths.
//

import Foundation
import SwiftData

enum CareEventService {
    @discardableResult
    @MainActor
    static func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: PetCareLog.manualFeedNoteMarker,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()

        QuestManager.shared.recordFirstMeal()
        let reward = CoconutEconomyService.awardCareAction(type: .feed, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            context: context
        )
        return reward
    }

    @discardableResult
    @MainActor
    static func recordTreatFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date()
    ) -> PetCareLog {
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: FeedLogMetadata.treatFeedNoteMarker,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: 0,
            context: context
        )
        return log
    }

    @discardableResult
    @MainActor
    static func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .precise,
        executorId: String? = nil
    ) -> (humanGot: Int, petGot: Int)? {
        guard let event = reminder.event else { return nil }

        let log = PetCareLog(
            date: Date(),
            type: .feeding,
            amountGrams: feedAmount(from: event, fallback: pet.dailyPortionGrams),
            note: "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString)",
            pet: pet,
            executorId: executorId
        )
        context.insert(log)

        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        if let executorId {
            reminder.completedBy = executorId
        }
        NotificationManager.shared.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        CareLedgerService.recordReminderState(
            reminder: reminder,
            actionType: "completePlannedCare",
            actorId: executorId,
            source: .reminder,
            context: context
        )

        QuestManager.shared.recordFirstMeal()
        let reward = CoconutEconomyService.awardCareAction(type: .feed, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .reminder,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            context: context
        )
        return reward
    }

    @discardableResult
    @MainActor
    static func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double = 0,
        context: ModelContext,
        executorId: String? = nil,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let log = PetCareLog(
            date: date,
            type: type,
            amountMl: amountMl,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()

        let award = CoconutEconomyService.awardCareAction(type: reward, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: CareLedgerService.rewardDelta(award),
            context: context
        )
        return award
    }

    @discardableResult
    @MainActor
    static func recordPotty(
        pet: Pet,
        type: PottyType = .perfectPoop,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let log = PetPottyLog(date: date, type: type, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()

        let reward = CoconutEconomyService.awardCareAction(type: .potty(isLitter: false), pet: pet, context: context)
        CareLedgerService.recordPetPotty(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            context: context
        )
        return reward
    }

    static func feedAmount(from event: Event, fallback: Double) -> Double {
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? fallback
    }
}

enum CalendarTaskCompletionSyncService {
    private static let calendarSource = CareLedgerSource.calendar.rawValue

    @MainActor
    static func syncPetTask(
        event: Event,
        occurrenceDate: Date,
        isCompleted: Bool,
        pets: [Pet],
        context: ModelContext,
        executorId: String?
    ) {
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet",
              let pet = pets.first(where: { $0.id.uuidString == event.relatedEntityId }) else { return }

        if !isCompleted {
            deleteCalendarGeneratedRecords(event: event, occurrenceDate: occurrenceDate, context: context)
            return
        }
        guard calendarLedgerEntries(event: event, occurrenceDate: occurrenceDate, context: context).isEmpty else { return }

        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        if let careType = careType(for: event) {
            insertCareLog(
                pet: pet,
                event: event,
                careType: careType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                executorId: executorId,
                context: context
            )
        } else if let pottyType = pottyType(for: event) {
            insertPottyLog(
                pet: pet,
                event: event,
                pottyType: pottyType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                executorId: executorId,
                context: context
            )
        } else if let hygieneType = hygieneType(for: event) {
            insertHygieneLog(
                pet: pet,
                event: event,
                hygieneType: hygieneType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                executorId: executorId,
                context: context
            )
        }
    }

    @MainActor
    private static func insertCareLog(
        pet: Pet,
        event: Event,
        careType: CareType,
        occurredAt: Date,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext
    ) {
        let amountGrams = careType == .feeding ? CareEventService.feedAmount(from: event, fallback: pet.dailyPortionGrams) : 0
        let amountMl = careType == .watering ? 250.0 : 0
        let log = PetCareLog(
            date: occurredAt,
            type: careType,
            amountGrams: amountGrams,
            amountMl: amountMl,
            note: noteMarker(for: event, occurrenceDate: occurrenceDate, careType: careType),
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            eventKind: .care,
            actionType: careType.rawValue,
            amountValue: careType == .feeding ? amountGrams : amountMl,
            amountUnit: careType == .feeding ? "g" : (careType == .watering ? "ml" : ""),
            legacyModelName: "PetCareLog",
            legacyModelId: log.id.uuidString,
            context: context
        )
    }

    @MainActor
    private static func insertPottyLog(
        pet: Pet,
        event: Event,
        pottyType: PottyType,
        occurredAt: Date,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext
    ) {
        let log = PetPottyLog(date: occurredAt, type: pottyType, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            eventKind: .potty,
            actionType: pottyType.rawValue,
            legacyModelName: "PetPottyLog",
            legacyModelId: log.id.uuidString,
            context: context
        )
    }

    @MainActor
    private static func insertHygieneLog(
        pet: Pet,
        event: Event,
        hygieneType: HygieneType,
        occurredAt: Date,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext
    ) {
        let log = PetHygieneLog(date: occurredAt, type: hygieneType, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            eventKind: .hygiene,
            actionType: hygieneType.rawValue,
            legacyModelName: "PetHygieneLog",
            legacyModelId: log.id.uuidString,
            context: context
        )
    }

    @MainActor
    private static func recordCalendarLedger(
        occurredAt: Date,
        executorId: String?,
        pet: Pet,
        event: Event,
        occurrenceDate: Date,
        eventKind: CareLedgerEventKind,
        actionType: String,
        amountValue: Double = 0,
        amountUnit: String = "",
        legacyModelName: String,
        legacyModelId: String,
        context: ModelContext
    ) {
        CareLedgerService.record(
            occurredAt: occurredAt,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: eventKind,
            actionType: actionType,
            amountValue: amountValue,
            amountUnit: amountUnit,
            note: event.title,
            source: .calendar,
            sourceEventId: event.id.uuidString,
            legacyModelName: legacyModelName,
            legacyModelId: legacyModelId,
            metadataJSON: occurrenceMetadata(for: occurrenceDate),
            context: context
        )
    }

    @MainActor
    private static func deleteCalendarGeneratedRecords(event: Event, occurrenceDate: Date, context: ModelContext) {
        let ledgers = calendarLedgerEntries(event: event, occurrenceDate: occurrenceDate, context: context)
        for ledger in ledgers {
            deleteLegacyModel(name: ledger.legacyModelName, idString: ledger.legacyModelId, context: context)
            context.delete(ledger)
        }
        if !ledgers.isEmpty { context.safeSave() }
    }

    @MainActor
    private static func deleteLegacyModel(name: String?, idString: String?, context: ModelContext) {
        guard let name, let idString, let id = UUID(uuidString: idString) else { return }
        switch name {
        case "PetCareLog":
            var descriptor = FetchDescriptor<PetCareLog>(predicate: #Predicate<PetCareLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = try? context.fetch(descriptor).first { context.delete(model) }
        case "PetPottyLog":
            var descriptor = FetchDescriptor<PetPottyLog>(predicate: #Predicate<PetPottyLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = try? context.fetch(descriptor).first { context.delete(model) }
        case "PetHygieneLog":
            var descriptor = FetchDescriptor<PetHygieneLog>(predicate: #Predicate<PetHygieneLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = try? context.fetch(descriptor).first { context.delete(model) }
        default:
            return
        }
    }

    @MainActor
    private static func calendarLedgerEntries(event: Event, occurrenceDate: Date, context: ModelContext) -> [CareLedgerEvent] {
        let eventId = event.id.uuidString
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { $0.sourceEventId == eventId }
        )
        descriptor.fetchLimit = 20
        let key = occurrenceKey(for: occurrenceDate)
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.source == calendarSource && $0.metadataJSON.contains("\"occurrence\":\"\(key)\"")
        }
    }

    private static func occurrenceTimestamp(for event: Event, occurrenceDate: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(occurrenceDate) { return Date() }
        if event.isAllDay { return calendar.startOfDay(for: occurrenceDate) }
        return Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
    }

    private static func noteMarker(for event: Event, occurrenceDate: Date, careType: CareType) -> String {
        let key = occurrenceKey(for: occurrenceDate)
        if careType == .feeding {
            return "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString):calendar:\(key)"
        }
        return "ohana_calendar_event:\(event.id.uuidString):\(key)"
    }

    private static func occurrenceMetadata(for occurrenceDate: Date) -> String {
        "{\"occurrence\":\"\(occurrenceKey(for: occurrenceDate))\"}"
    }

    private static func occurrenceKey(for occurrenceDate: Date) -> String {
        Event.occurrenceStorageKey(for: occurrenceDate)
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType)".lowercased()
    }

    private static func careType(for event: Event) -> CareType? {
        let text = normalizedText(for: event)
        if text.contains("换水") || text.contains("water change") { return .waterChange }
        if text.contains("滤") || text.contains("filter") { return .filterClean }
        if text.contains("猫砂") || text.contains("铲") || event.eventType == EventType.litterBox.rawValue { return .litter }
        if text.contains("喂水") || text.contains("喝水") || text.contains("饮水") || text.contains("drink") { return .watering }
        if event.eventType == EventType.foodChange.rawValue || text.contains("喂") || text.contains("feed") || text.contains("吃") { return .feeding }
        if text.contains("逗") || text.contains("陪玩") || text.contains("play") { return .play }
        return nil
    }

    private static func pottyType(for event: Event) -> PottyType? {
        let text = normalizedText(for: event)
        if text.contains("便") || text.contains("potty") || text.contains("poop") { return .perfectPoop }
        return nil
    }

    private static func hygieneType(for event: Event) -> HygieneType? {
        let text = normalizedText(for: event)
        guard event.eventType == EventType.grooming.rawValue
                || text.contains("洗") || text.contains("澡") || text.contains("刷牙")
                || text.contains("剪") || text.contains("梳") || text.contains("清耳")
                || text.contains("groom") || text.contains("bath") else { return nil }
        if text.contains("刷牙") || text.contains("teeth") { return .teeth }
        if text.contains("剪") || text.contains("nail") { return .nails }
        if text.contains("耳") || text.contains("ear") { return .ears }
        if text.contains("梳") || text.contains("brush") { return .brushing }
        return .bath
    }
}

enum ReminderCompletionService {
    @MainActor
    static func complete(_ reminder: Reminder, by humanId: String?, context: ModelContext) {
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        reminder.completedBy = humanId ?? ""
        NotificationManager.shared.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "complete", actorId: humanId, source: .service, context: context)
    }

    @MainActor
    static func skip(_ reminder: Reminder, by humanId: String?, context: ModelContext) {
        reminder.statusEnum = .skipped
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        NotificationManager.shared.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "skip", actorId: humanId, source: .service, context: context)
    }

    @MainActor
    static func reopen(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) {
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        if reschedule {
            Task { @MainActor in
                await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: context, source: .service)
            }
        }
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "reopen", actorId: humanId, source: .service, context: context)
    }

    @MainActor
    static func snoozeOneDay(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) {
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        reminder.scheduledAt = Calendar.current.date(byAdding: .day, value: 1, to: reminder.scheduledAt)
            ?? Date().addingTimeInterval(86_400)
        if reschedule {
            Task { @MainActor in
                await ReminderSchedulingService.cancelAndReschedule(reminder: reminder, context: context, source: .service)
            }
        }
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "snoozeOneDay", actorId: humanId, source: .service, context: context)
    }
}

enum CoconutEconomyService {
    @discardableResult
    @MainActor
    static func awardCareAction(
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .none
    ) -> (humanGot: Int, petGot: Int) {
        QuestManager.shared.awardAction(type: type, pet: pet, context: context, quality: quality)
    }
}
