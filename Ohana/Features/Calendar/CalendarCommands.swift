//
//  CalendarCommands.swift
//  Ohana
//
//  Domain write boundaries for calendar events, event completion, deletion, and reminders.
//

import Foundation
import SwiftData

struct EventCompletionRewardResult: Equatable {
    let awarded: Bool
    let skippedByExistingCare: Bool
    let coconutDelta: Int
}

struct CalendarEventPlanCommandInput: Equatable {
    let title: String
    let startDate: Date
    let isAllDay: Bool
    let eventType: EventType
    let relatedEntityType: String
    let relatedEntityId: String
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let reminderLeadMinutes: Int?
    let assigneeId: String?

    var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CalendarEventPlanCommandResult: Equatable {
    let eventID: UUID
    let reminderIDs: [UUID]
    let scheduledReminderSync: Bool
}

enum CalendarEventPlanCommandService {
    private static let maxReminderOccurrences = 500

    @discardableResult
    @MainActor
    static func createEvent(
        input: CalendarEventPlanCommandInput,
        context: ModelContext,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> CalendarEventPlanCommandResult? {
        guard !input.cleanTitle.isEmpty else { return nil }

        let event = Event(
            title: input.cleanTitle,
            startDate: input.startDate,
            endDate: nil,
            isAllDay: input.isAllDay,
            eventType: input.eventType.rawValue,
            relatedEntityType: input.relatedEntityType,
            relatedEntityId: input.relatedEntityId
        )
        event.recurrenceDays = input.recurrenceDays
        event.recurrenceEndDate = input.recurrenceDays > 0 ? input.recurrenceEndDate : nil
        event.assigneeId = input.assigneeId
        context.insert(event)

        let createdReminders = createReminders(for: event, input: input, context: context)
        context.safeSave()

        let shouldScheduleReminders = scheduleNotifications && !createdReminders.isEmpty
        if shouldScheduleReminders {
            let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager()
            Task { @MainActor in
                await reminderScheduling.scheduleManyIfNeeded(
                    reminders: createdReminders,
                    context: context,
                    source: .calendar
                )
            }
        }

        return CalendarEventPlanCommandResult(
            eventID: event.id,
            reminderIDs: createdReminders.map(\.id),
            scheduledReminderSync: shouldScheduleReminders
        )
    }

    @MainActor
    private static func createReminders(
        for event: Event,
        input: CalendarEventPlanCommandInput,
        context: ModelContext
    ) -> [Reminder] {
        guard let leadMinutes = input.reminderLeadMinutes else { return [] }

        let calendar = Calendar.current
        if input.recurrenceDays >= 1, let recurrenceEndDate = input.recurrenceEndDate {
            var reminders: [Reminder] = []
            var cursor = input.startDate
            var safetyCount = 0
            while cursor <= recurrenceEndDate, safetyCount < maxReminderOccurrences {
                let scheduled = calendar.date(byAdding: .minute, value: -leadMinutes, to: cursor) ?? cursor
                let reminder = Reminder(event: event, scheduledAt: scheduled)
                context.insert(reminder)
                reminders.append(reminder)

                guard let next = calendar.date(byAdding: .day, value: input.recurrenceDays, to: cursor),
                      next > cursor else {
                    break
                }
                cursor = next
                safetyCount += 1
            }
            return reminders
        }

        let scheduled = calendar.date(byAdding: .minute, value: -leadMinutes, to: input.startDate) ?? input.startDate
        let reminder = Reminder(event: event, scheduledAt: scheduled)
        context.insert(reminder)
        return [reminder]
    }
}

enum EventCompletionCommandService {
    @discardableResult
    @MainActor
    static func awardCompletionIfEligible(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        executorId: String? = nil,
        now: Date = Date()
    ) -> EventCompletionRewardResult {
        guard event.isActionableTask else {
            return EventCompletionRewardResult(awarded: false, skippedByExistingCare: false, coconutDelta: 0)
        }
        guard !hasTodayCareCheckIn(for: event, context: context, now: now) else {
            return EventCompletionRewardResult(awarded: false, skippedByExistingCare: true, coconutDelta: 0)
        }

        let occurrenceKey = Event.occurrenceStorageKey(for: occurrenceDate)
        let transactionKey = "eventReward:\(event.id.uuidString):\(occurrenceKey)"
        guard !hasExistingCalendarReward(transactionKey: transactionKey, context: context) else {
            return EventCompletionRewardResult(awarded: false, skippedByExistingCare: false, coconutDelta: 0)
        }

        let human = currentHuman(id: executorId, context: context)
        let budgetKeys = calendarBudgetKeys(for: human, fallbackMemberId: executorId, context: context)
        let budget = EconomyDailyBudgetStore.snapshot(
            householdKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            date: now,
            context: context
        )
        let requestedCoconuts = 5
        let scaledCoconuts = Int(ceil(Double(requestedCoconuts) * budget.budgetStage.coconutMultiplier))
        let awardedCoconuts = min(scaledCoconuts, budget.remainingFatigueCoconuts)
        let effectiveStage: EconomyBudgetStage = if budget.budgetStage == .normal, awardedCoconuts < requestedCoconuts {
            .fatigue
        } else if budget.budgetStage != .cooldown, awardedCoconuts == 0 {
            .recordOnly
        } else {
            budget.budgetStage
        }
        guard awardedCoconuts > 0 else {
            return EventCompletionRewardResult(awarded: false, skippedByExistingCare: false, coconutDelta: 0)
        }

        let rewardTitle = event.title + " 完成奖励"
        let result = EconomyRewardResult(
            growthXP: 0,
            humanCoconuts: awardedCoconuts,
            petCoconuts: 0,
            bonusCoconuts: 0,
            luckyCoconuts: 0,
            budgetMultiplier: budget.budgetStage.coconutMultiplier,
            budgetStage: effectiveStage,
            reason: effectiveStage.reason,
            actionKey: "calendarEventCompletion",
            isOnCooldown: false,
            baseGrowthXP: 0,
            baseCoconuts: min(requestedCoconuts, awardedCoconuts),
            luck: .none
        )
        let metadataJSON = rewardMetadata(result: result, occurrenceKey: occurrenceKey)
        let delta: CoconutWalletDelta = if let human {
            .human(
                human,
                delta: awardedCoconuts,
                entryKind: .reward,
                source: .service,
                title: rewardTitle,
                emoji: "🥥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: subjectKind(for: event),
                subjectId: event.relatedEntityId.isEmpty ? nil : event.relatedEntityId,
                sourceModelName: "CalendarEventCompletionReward",
                sourceModelId: "\(event.id.uuidString):\(occurrenceKey)",
                metadataJSON: metadataJSON,
                occurredAt: now,
                transactionKey: transactionKey
            )
        } else {
            .system(
                delta: awardedCoconuts,
                entryKind: .reward,
                source: .service,
                title: rewardTitle,
                emoji: "🥥",
                actorId: executorId ?? "system",
                actorName: nil,
                sourceModelName: "CalendarEventCompletionReward",
                sourceModelId: "\(event.id.uuidString):\(occurrenceKey)",
                metadataJSON: metadataJSON,
                occurredAt: now,
                transactionKey: transactionKey
            )
        }

        let walletEntries: [CoconutLedgerEntry]
        do {
            walletEntries = try wallet.apply(
                deltas: [delta],
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: nil
            )
        } catch {
            AppPerformanceMonitor.shared.record(
                "calendar.eventCompletion.walletFailed",
                valueMS: 0,
                note: error.localizedDescription
            )
            return EventCompletionRewardResult(awarded: false, skippedByExistingCare: false, coconutDelta: 0)
        }
        let coconutDelta = walletEntries.reduce(0) { $0 + max(0, $1.delta) }
        careLedger.record(
            occurredAt: now,
            actorKind: human == nil ? .unknown : .human,
            actorId: human?.id.uuidString ?? executorId,
            subjectKind: subjectKind(for: event),
            subjectId: event.relatedEntityId.isEmpty ? nil : event.relatedEntityId,
            eventKind: .coconut,
            actionType: "eventCompletionReward",
            amountValue: 0,
            amountUnit: "",
            note: event.title,
            source: .calendar,
            sourceEventId: event.id.uuidString,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: coconutDelta,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: false
        )
        EconomyDailyBudgetStore.commit(
            result,
            householdKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            date: now,
            context: context,
            save: false,
            writeDefaults: false
        )
        do {
            try context.save()
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: budgetKeys.household,
                memberKey: budgetKeys.member,
                date: now,
                context: nil,
                save: false
            )
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context)
            AppPerformanceMonitor.shared.record(
                "calendar.eventCompletion.saveFailed",
                valueMS: 0,
                note: error.localizedDescription
            )
            return EventCompletionRewardResult(awarded: false, skippedByExistingCare: false, coconutDelta: 0)
        }
        return EventCompletionRewardResult(awarded: coconutDelta > 0, skippedByExistingCare: false, coconutDelta: coconutDelta)
    }

    @MainActor
    private static func hasTodayCareCheckIn(for event: Event, context: ModelContext, now: Date) -> Bool {
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet" else { return false }
        let petId = event.relatedEntityId
        let text = "\(event.title) \(event.eventType)".lowercased()
        let isFeeding = text.contains("喂") || text.contains("feed") || text.contains("吃")
        let isWatering = text.contains("水") || text.contains("喝")
        let isPotty = text.contains("便") || text.contains("铲") || text.contains("potty")
        let isWalk = text.contains("遛") || text.contains("散步") || text.contains("巡岛") || text.contains("walk")
        guard isFeeding || isWatering || isPotty || isWalk else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        if isPotty {
            let descriptor = FetchDescriptor<PetPottyLog>(
                predicate: #Predicate { log in
                    log.date >= today && log.date < tomorrow
                }
            )
            let logs = fetchModelsOrLog(descriptor, context: context, operation: "fetch today potty logs for event completion")
            return logs.contains { $0.pet?.id.uuidString == petId }
        }
        if isWalk {
            let descriptor = FetchDescriptor<PetWalkLog>(
                predicate: #Predicate { log in
                    log.startDate >= today && log.startDate < tomorrow
                }
            )
            let logs = fetchModelsOrLog(descriptor, context: context, operation: "fetch today walk logs for event completion")
            return logs.contains { $0.pet?.id.uuidString == petId }
        }

        let careType = isFeeding ? CareType.feeding.rawValue : CareType.watering.rawValue
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate { log in
                log.date >= today && log.date < tomorrow
            }
        )
        let logs = fetchModelsOrLog(descriptor, context: context, operation: "fetch today care logs for event completion")
        return logs.contains { $0.pet?.id.uuidString == petId && $0.type == careType }
    }

    private static func subjectKind(for event: Event) -> CareLedgerSubjectKind {
        switch event.relatedEntityType {
        case EntityKind.pet.rawValue, "pet":
            .pet
        case EntityKind.human.rawValue, "human":
            .human
        case EntityKind.plant.rawValue, "plant":
            .plant
        default:
            event.relatedEntityId.isEmpty ? .system : .unknown
        }
    }

    @MainActor
    private static func hasExistingCalendarReward(transactionKey: String, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { $0.transactionKey == transactionKey }
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(descriptor, context: context, operation: "fetch existing calendar reward").isEmpty == false
    }

    @MainActor
    private static func currentHuman(id: String?, context: ModelContext) -> Human? {
        guard let id, let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(descriptor, context: context, operation: "fetch calendar reward executor").first
    }

    @MainActor
    private static func fetchModelsOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "EventCompletionCommandService failed to \(operation): \(error.localizedDescription)",
                category: "Calendar"
            )
            return []
        }
    }

    private static func calendarBudgetKeys(
        for human: Human?,
        fallbackMemberId: String?,
        context: ModelContext
    ) -> (household: String, member: String) {
        (
            CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            human?.id.uuidString ?? fallbackMemberId ?? CoconutEconomyPolicyV2.currentUserKey()
        )
    }

    private static func rewardMetadata(result: EconomyRewardResult, occurrenceKey: String) -> String {
        guard let data = result.metadataJSON.data(using: .utf8),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "{\"occurrence\":\"\(occurrenceKey)\"}"
        }
        object["occurrence"] = occurrenceKey
        guard let mergedData = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: mergedData, encoding: .utf8) else {
            return result.metadataJSON
        }
        return json
    }
}

@MainActor
struct EventCompletionCommandExecutor {
    let context: ModelContext
    let wallet: CoconutWalletManaging
    let careLedger: CareLedgerRecording
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter)
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            wallet: services.coconutWallet,
            careLedger: services.careLedger,
            revisions: services.domainRevisions
        )
    }

    init(
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        revisions: DomainRevisionPublishing
    ) {
        self.context = context
        self.wallet = wallet
        self.careLedger = careLedger
        self.revisions = revisions
    }

    @discardableResult
    func awardCompletionIfEligible(
        event: Event,
        occurrenceDate: Date,
        executorId: String?,
        now: Date = Date(),
        note: String
    ) -> EventCompletionRewardResult {
        let result = EventCompletionCommandService.awardCompletionIfEligible(
            event: event,
            occurrenceDate: occurrenceDate,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            executorId: executorId,
            now: now
        )
        revisions.publish(
            DomainMutationResult(
                command: .todayFocus(entityID: event.id, action: "eventCompleteReward"),
                affectedEntityIDs: [event.id],
                wroteBusinessFact: result.awarded,
                note: note
            )
        )
        return result
    }
}

struct CalendarEventCompletionResult: Equatable {
    let eventID: UUID
    let isCompleted: Bool
    let syncedReminderCount: Int
}

enum CalendarEventDeletionScope: Equatable {
    case wholeEvent
    case singleOccurrence
    case thisAndFuture

    var revisionActionKey: String {
        switch self {
        case .wholeEvent:
            "wholeEvent"
        case .singleOccurrence:
            "singleOccurrence"
        case .thisAndFuture:
            "thisAndFuture"
        }
    }
}

enum CalendarEventDeletionOutcome: Equatable {
    case deletedEvent(UUID)
    case advancedStart(UUID)
    case truncated(UUID)
    case split(originalID: UUID, newEventID: UUID)

    var primaryEventID: UUID {
        switch self {
        case let .deletedEvent(id), let .advancedStart(id), let .truncated(id):
            id
        case let .split(originalID, _):
            originalID
        }
    }

    var affectedEventIDs: Set<UUID> {
        switch self {
        case let .deletedEvent(id), let .advancedStart(id), let .truncated(id):
            [id]
        case let .split(originalID, newEventID):
            [originalID, newEventID]
        }
    }
}

enum CalendarEventCommandService {
    @discardableResult
    @MainActor
    static func toggleCompletion(
        event: Event,
        occurrenceDate: Date,
        pets: [Pet],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        reminderCompletion providedReminderCompletion: ReminderCompleting? = nil
    ) -> CalendarEventCompletionResult {
        let reminderCompletion = providedReminderCompletion ?? ReminderCompletionService()
        let shouldComplete = !event.isOccurrenceMarkedComplete(on: occurrenceDate)
        event.setOccurrenceMarkedComplete(shouldComplete, on: occurrenceDate)
        CalendarTaskCompletionSyncService.syncPetTask(
            event: event,
            occurrenceDate: occurrenceDate,
            isCompleted: shouldComplete,
            pets: pets,
            context: context,
            executorId: executorId
        )

        let remindersToSync = remindersForCompletionSync(event: event, now: now)
        for reminder in remindersToSync {
            if shouldComplete {
                reminderCompletion.complete(reminder, by: executorId, context: context)
            } else {
                reminderCompletion.reopen(reminder, by: executorId, context: context, reschedule: true)
            }
        }
        if remindersToSync.isEmpty {
            context.safeSave()
        }

        return CalendarEventCompletionResult(
            eventID: event.id,
            isCompleted: shouldComplete,
            syncedReminderCount: remindersToSync.count
        )
    }

    private static func remindersForCompletionSync(event: Event, now: Date) -> [Reminder] {
        guard event.recurrenceDays == 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return event.reminders.filter { reminder in
            reminder.scheduledAt >= today && reminder.scheduledAt < tomorrow
        }
    }

    @discardableResult
    @MainActor
    static func delete(
        event: Event,
        occurrenceDate: Date,
        scope: CalendarEventDeletionScope,
        context: ModelContext
    ) -> CalendarEventDeletionOutcome {
        let outcome: CalendarEventDeletionOutcome
        switch scope {
        case .wholeEvent:
            outcome = .deletedEvent(event.id)
            deleteEventWithTombstones(event, context: context)
        case .singleOccurrence:
            outcome = deleteSingleOccurrence(event: event, occurrenceDate: occurrenceDate, context: context)
        case .thisAndFuture:
            outcome = deleteThisAndFuture(event: event, occurrenceDate: occurrenceDate, context: context)
        }
        context.safeSave()
        return outcome
    }

    @MainActor
    private static func deleteSingleOccurrence(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext
    ) -> CalendarEventDeletionOutcome {
        let calendar = Calendar.current
        let occurrenceStart = calendar.startOfDay(for: occurrenceDate)
        let eventStart = calendar.startOfDay(for: event.startDate)

        if occurrenceStart == eventStart {
            guard let next = calendar.date(byAdding: .day, value: event.recurrenceDays, to: eventStart) else {
                deleteEventWithTombstones(event, context: context)
                return .deletedEvent(event.id)
            }
            let hasMore = event.recurrenceEndDate.map { next <= calendar.startOfDay(for: $0) } ?? true
            if hasMore {
                event.startDate = next
                return .advancedStart(event.id)
            }
            deleteEventWithTombstones(event, context: context)
            return .deletedEvent(event.id)
        }

        let dayBefore = calendar.date(byAdding: .day, value: -1, to: occurrenceStart) ?? occurrenceStart
        let nextOccurrence = calendar.date(byAdding: .day, value: event.recurrenceDays, to: occurrenceStart) ?? occurrenceStart
        let hasAfter = event.recurrenceEndDate.map { nextOccurrence <= calendar.startOfDay(for: $0) } ?? true

        if hasAfter {
            let newEvent = Event(
                title: event.title,
                startDate: nextOccurrence,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                eventType: event.eventType,
                relatedEntityType: event.relatedEntityType,
                relatedEntityId: event.relatedEntityId
            )
            newEvent.recurrenceDays = event.recurrenceDays
            newEvent.recurrenceEndDate = event.recurrenceEndDate
            newEvent.assigneeId = event.assigneeId
            newEvent.feedRuleKindRaw = event.feedRuleKindRaw
            newEvent.foodKindRaw = event.foodKindRaw
            newEvent.feedAmountGrams = event.feedAmountGrams
            context.insert(newEvent)
            event.recurrenceEndDate = dayBefore
            return .split(originalID: event.id, newEventID: newEvent.id)
        }

        event.recurrenceEndDate = dayBefore
        return .truncated(event.id)
    }

    @MainActor
    private static func deleteThisAndFuture(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext
    ) -> CalendarEventDeletionOutcome {
        let calendar = Calendar.current
        let occurrenceStart = calendar.startOfDay(for: occurrenceDate)
        let eventStart = calendar.startOfDay(for: event.startDate)

        if occurrenceStart <= eventStart {
            deleteEventWithTombstones(event, context: context)
            return .deletedEvent(event.id)
        }

        let dayBefore = calendar.date(byAdding: .day, value: -1, to: occurrenceStart) ?? occurrenceStart
        event.recurrenceEndDate = dayBefore
        return .truncated(event.id)
    }

    @MainActor
    private static func deleteEventWithTombstones(_ event: Event, context: ModelContext) {
        let reminders = event.reminders
        CloudSyncMutationRecorder.markDeleted(event, context: context)
        for reminder in reminders {
            CloudSyncMutationRecorder.markDeleted(reminder, context: context)
        }
        context.delete(event)
    }
}

@MainActor
struct CalendarCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let reminderScheduling: ReminderSchedulingManaging
    let reminderCompletion: ReminderCompleting

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            reminderScheduling: ReminderSchedulingManager(),
            reminderCompletion: ReminderCompletionService()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            reminderScheduling: ReminderSchedulingManager(),
            reminderCompletion: ReminderCompletionService()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            reminderScheduling: services.reminderScheduling,
            reminderCompletion: services.reminderCompletion
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        reminderScheduling: ReminderSchedulingManaging,
        reminderCompletion: ReminderCompleting
    ) {
        self.context = context
        self.revisions = revisions
        self.reminderScheduling = reminderScheduling
        self.reminderCompletion = reminderCompletion
    }

    @discardableResult
    func createEvent(input: CalendarEventPlanCommandInput) -> CalendarEventPlanCommandResult? {
        let command = DomainCommand.calendarEventPlan(eventID: nil)
        guard let result = CalendarEventPlanCommandService.createEvent(
            input: input,
            context: context,
            reminderScheduling: reminderScheduling
        ) else {
            revisions.publish(
                DomainMutationResult(
                    command: command,
                    wroteBusinessFact: false,
                    note: "calendar.event.create.empty"
                )
            )
            return nil
        }

        revisions.publishCalendarEventPlan(
            result,
            relatedEntityId: input.relatedEntityId,
            note: result.scheduledReminderSync ? "calendar.event.created.reminders" : "calendar.event.created"
        )
        return result
    }

    @discardableResult
    func toggleCompletion(
        event: Event,
        occurrenceDate: Date,
        pets: [Pet],
        executorId: String?,
        note: String
    ) -> CalendarEventCompletionResult {
        let result = CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: pets,
            context: context,
            executorId: executorId,
            reminderCompletion: reminderCompletion
        )
        revisions.publishCalendarEventCompletion(result, note: note)
        return result
    }

    @discardableResult
    func delete(
        event: Event,
        occurrenceDate: Date,
        scope: CalendarEventDeletionScope,
        note: String
    ) -> CalendarEventDeletionOutcome {
        let outcome = CalendarEventCommandService.delete(
            event: event,
            occurrenceDate: occurrenceDate,
            scope: scope,
            context: context
        )
        revisions.publishCalendarEventDeletion(outcome, scope: scope, note: note)
        return outcome
    }
}

struct ReminderCommandResult: Equatable {
    let reminderID: UUID
    let eventID: UUID?
    let action: String
}

@MainActor
struct ReminderCommandExecutor {
    let context: ModelContext
    let wallet: CoconutWalletManaging
    let careLedger: CareLedgerRecording
    let revisions: DomainRevisionPublishing
    let reminderCompletion: ReminderCompleting

    init(context: ModelContext) {
        self.init(
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher(),
            reminderCompletion: ReminderCompletionService()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            reminderCompletion: ReminderCompletionService()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            wallet: services.coconutWallet,
            careLedger: services.careLedger,
            revisions: services.domainRevisions,
            reminderCompletion: services.reminderCompletion
        )
    }

    init(
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        revisions: DomainRevisionPublishing,
        reminderCompletion: ReminderCompleting
    ) {
        self.context = context
        self.wallet = wallet
        self.careLedger = careLedger
        self.revisions = revisions
        self.reminderCompletion = reminderCompletion
    }

    @discardableResult
    func complete(_ reminder: Reminder, by humanId: String?, note: String) -> ReminderCommandResult {
        reminderCompletion.complete(reminder, by: humanId, context: context)
        return publish(reminder, action: "complete", note: note)
    }

    @discardableResult
    func completeWithCoconutReward(
        _ reminder: Reminder,
        by humanId: String?,
        amount: Int,
        title: String,
        emoji: String = "✅",
        note: String
    ) -> ReminderCommandResult {
        reminderCompletion.complete(reminder, by: humanId, context: context)
        if amount != 0 {
            var didApplyWalletDelta = false
            do {
                try wallet.applyActorDelta(
                    amount: amount,
                    emoji: emoji,
                    title: title,
                    actorId: humanId,
                    actorName: nil,
                    entryKind: amount > 0 ? .reward : .spend,
                    source: .service,
                    context: context,
                    save: false,
                    postsRewardFeedback: true
                )
                didApplyWalletDelta = true
            } catch {
                AppPerformanceMonitor.shared.record(
                    "reminder.reward.walletFailed",
                    valueMS: 0,
                    note: error.localizedDescription
                )
            }
            if didApplyWalletDelta {
                careLedger.recordCoconut(
                    delta: amount,
                    title: title,
                    actorId: humanId,
                    actorName: nil,
                    source: .economy,
                    context: context
                )
            }
        }
        return publish(reminder, action: "complete.reward", note: note)
    }

    @discardableResult
    func skip(_ reminder: Reminder, by humanId: String?, note: String) -> ReminderCommandResult {
        reminderCompletion.skip(reminder, by: humanId, context: context)
        return publish(reminder, action: "skip", note: note)
    }

    @discardableResult
    func reopen(
        _ reminder: Reminder,
        by humanId: String?,
        reschedule: Bool = true,
        note: String
    ) -> ReminderCommandResult {
        reminderCompletion.reopen(reminder, by: humanId, context: context, reschedule: reschedule)
        return publish(reminder, action: "reopen", note: note)
    }

    @discardableResult
    func snoozeOneDay(
        _ reminder: Reminder,
        by humanId: String?,
        reschedule: Bool = true,
        note: String
    ) -> ReminderCommandResult {
        reminderCompletion.snoozeOneDay(reminder, by: humanId, context: context, reschedule: reschedule)
        return publish(reminder, action: "snoozeOneDay", note: note)
    }

    @discardableResult
    private func publish(_ reminder: Reminder, action: String, note: String) -> ReminderCommandResult {
        let result = ReminderCommandResult(
            reminderID: reminder.id,
            eventID: reminder.event?.id,
            action: action
        )
        var affected: Set<UUID> = [result.reminderID]
        if let eventID = result.eventID {
            affected.insert(eventID)
        }
        revisions.publish(
            DomainMutationResult(
                command: .reminderCompletion(reminderID: result.reminderID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
        return result
    }
}
