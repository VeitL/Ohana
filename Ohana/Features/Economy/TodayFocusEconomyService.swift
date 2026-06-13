//
//  TodayFocusEconomyService.swift
//  Ohana
//
//  V2 economy reward for clearing the daily Today Focus list.
//

import Foundation
import SwiftData

@MainActor
enum TodayFocusEconomyService {
    private static let rewardMarkerPrefix = "economyV2.todayFocusCompletion"

    @discardableResult
    static func awardDailyCompletionIfNeeded(
        context: ModelContext,
        executorId: String?,
        visibleQuests: [IslandQuest],
        visibleSnapshot: TodayFocusSnapshot? = nil,
        now: Date = Date(),
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        revisions providedRevisions: DomainRevisionPublishing? = nil
    ) -> EconomyRewardResult? {
        let questManager = providedQuestManager ?? QuestManager()
        let questProgress = TodayFocusQuestProgress(questManager: questManager)
        let completionData = TodayFocusCompletionData(context: context, now: now)
        guard visibleQuestsAreCompleted(
            visibleQuests,
            data: completionData,
            now: now,
            questProgress: questProgress
        ) else { return nil }
        let currentQuests = currentQuestDeck(
            data: completionData,
            now: now,
            questProgress: questProgress
        )
        guard currentQuests.isEmpty || questsAreCompleted(currentQuests, data: completionData, now: now, questProgress: questProgress) else { return nil }
        guard visibleSnapshotHasNoBlockingNonQuestCards(visibleSnapshot, now: now) else { return nil }

        let careLedger: CareLedgerRecording = providedCareLedger ?? CareLedgerService()
        let revisions: DomainRevisionPublishing = providedRevisions ?? SharedDomainRevisionPublisher()
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let markerKey = "\(rewardMarkerPrefix).\(normalizedUserKey(householdKey)).\(EconomyDailyBudgetStore.dayKey(for: now))"
        guard !UserDefaults.standard.bool(forKey: markerKey) else { return nil }

        let reward = EconomyRewardDiscipline.awardNonCareReward(
            type: .dailyFocusCompletion,
            pet: nil,
            context: context,
            quality: .none,
            date: now,
            executorId: executorId,
            questManager: questManager
        )
        guard let result = questManager.lastEconomyRewardResult else { return nil }
        guard result.growthXP > 0 || result.totalCoconuts > 0 || reward.humanGot > 0 || reward.petGot > 0 else { return nil }

        careLedger.record(
            occurredAt: now,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .household,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "todayFocusDailyCompletion",
            amountValue: 0,
            amountUnit: "",
            note: "today_focus.daily_completion",
            source: .service,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: careLedger.rewardDelta(reward),
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: result.metadataJSON,
            context: context,
            save: true
        )
        UserDefaults.standard.set(true, forKey: markerKey)
        revisions.publishTodayFocusDailyCompletion(note: "today_focus.daily_completion_reward")
        return result
    }

    static func resetDailyCompletionMarker(userKey: String, date: Date = Date()) {
        let day = EconomyDailyBudgetStore.dayKey(for: date)
        UserDefaults.standard.removeObject(
            forKey: "\(rewardMarkerPrefix).\(normalizedUserKey(userKey)).\(day)"
        )
        UserDefaults.standard.removeObject(
            forKey: "\(rewardMarkerPrefix).\(normalizedUserKey(CoconutEconomyPolicyV2.householdBudgetKey())).\(day)"
        )
    }

    private static func normalizedUserKey(_ value: String) -> String {
        value.isEmpty ? "system" : value
    }

    private static func visibleQuestsAreCompleted(
        _ visibleQuests: [IslandQuest],
        data: TodayFocusCompletionData,
        now: Date,
        questProgress: TodayFocusQuestProgress
    ) -> Bool {
        guard !visibleQuests.isEmpty else { return false }
        return questsAreCompleted(visibleQuests, data: data, now: now, questProgress: questProgress)
    }

    private static func currentQuestDeck(
        data: TodayFocusCompletionData,
        now: Date,
        questProgress: TodayFocusQuestProgress
    ) -> [IslandQuest] {
        IslandQuestEngine.todayQuests(
            pets: data.pets,
            reminders: data.reminders,
            plants: data.plants,
            events: data.events,
            humans: data.humans,
            careLedgerEntries: data.careLedgerEntries,
            now: now,
            questProgress: questProgress
        )
    }

    private static func questsAreCompleted(
        _ quests: [IslandQuest],
        data: TodayFocusCompletionData,
        now: Date,
        questProgress: TodayFocusQuestProgress
    ) -> Bool {
        let refreshed = TodayFocusService.refreshedQuests(
            quests,
            pets: data.pets,
            humans: data.humans,
            events: data.events,
            careLedgerEntries: data.careLedgerEntries,
            humanWeightLogs: data.humanWeightLogs,
            calendar: .current,
            now: now,
            questProgress: questProgress
        )

        return refreshed.allSatisfy { quest in
            if isPlantQuestCompleted(quest, plants: data.plants, now: now) {
                return true
            }
            return quest.isCompleted
        }
    }

    private static func isPlantQuestCompleted(
        _ quest: IslandQuest,
        plants: [Plant],
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard PlantFeatureGate.allows(.plants) else { return false }
        guard let plantId = quest.targetPlantId,
              let plant = plants.first(where: { $0.id == plantId }) else {
            return false
        }
        if quest.id == "q_water_plant" || quest.id.hasPrefix("q_water_plant_") {
            return plant.lastWateredDate.map { calendar.isDate($0, inSameDayAs: now) } == true
        }
        if quest.id == "q_fertilize_plant" || quest.id.hasPrefix("q_fertilize_plant_") {
            return plant.lastFertilizedDate.map { calendar.isDate($0, inSameDayAs: now) } == true
        }
        return false
    }

    private static func fetchPets(context: ModelContext) -> [Pet] {
        var descriptor = FetchDescriptor<Pet>(
            sortBy: [SortDescriptor(\Pet.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return fetchOrLog(descriptor, context: context, operation: "fetch today focus pets")
    }

    private static func fetchHumans(context: ModelContext) -> [Human] {
        var descriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return fetchOrLog(descriptor, context: context, operation: "fetch today focus humans")
    }

    private static func fetchPlants(context: ModelContext) -> [Plant] {
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\Plant.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 60
        return fetchOrLog(descriptor, context: context, operation: "fetch today focus plants")
    }

    private static func fetchTodayReminders(
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [Reminder] {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.scheduledAt >= start && reminder.scheduledAt < end
            },
            sortBy: [SortDescriptor(\Reminder.scheduledAt)]
        )
        descriptor.fetchLimit = 80
        return fetchOrLog(descriptor, context: context, operation: "fetch today focus reminders")
    }

    private static func fetchTodayFocusEvents(
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [Event] {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start.addingTimeInterval(14 * 24 * 60 * 60)
        var windowDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.startDate >= start && event.startDate <= end
            },
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        windowDescriptor.fetchLimit = 400
        let windowEvents: [Event] = fetchOrLog(
            windowDescriptor,
            context: context,
            operation: "fetch today focus event window"
        )

        var recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.recurrenceDays > 0 && event.startDate <= end
            },
            sortBy: [SortDescriptor(\Event.startDate, order: .reverse)]
        )
        recurringDescriptor.fetchLimit = 400
        let recurringEvents: [Event] = fetchOrLog(
            recurringDescriptor,
            context: context,
            operation: "fetch today focus recurring events"
        )
        .filter { event in
            guard let recurrenceEndDate = event.recurrenceEndDate else { return true }
            return calendar.startOfDay(for: recurrenceEndDate) >= start
        }

        var seen: Set<UUID> = []
        return (windowEvents + recurringEvents)
            .filter { event in
                guard !seen.contains(event.id) else { return false }
                seen.insert(event.id)
                return true
            }
            .sorted { $0.startDate < $1.startDate }
    }

    private static func fetchTodayCareLedgerEntries(
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [TodayFocusCareLedgerEntry] {
        let start = calendar.startOfDay(for: now)
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let walkKind = CareLedgerEventKind.walk.rawValue
        let pottyKind = CareLedgerEventKind.potty.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.occurredAt >= start &&
                    event.subjectKind == petSubject &&
                    (event.eventKind == careKind ||
                        event.eventKind == walkKind ||
                        event.eventKind == pottyKind)
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 360
        return fetchOrLog(descriptor, context: context, operation: "fetch today focus care ledger")
            .compactMap(todayFocusCareLedgerEntry(from:))
    }

    private static func fetchTodayHumanWeightLogs(
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [HumanWeightLog] {
        let start = calendar.startOfDay(for: now)
        var descriptor = FetchDescriptor<HumanWeightLog>(
            predicate: #Predicate<HumanWeightLog> { log in
                log.date >= start
            },
            sortBy: [SortDescriptor(\HumanWeightLog.date, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return fetchOrLog(descriptor, context: context, operation: "fetch today focus human weight logs")
    }

    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Today Focus economy \(operation) failed: \(error.localizedDescription)",
                category: "Economy"
            )
            return []
        }
    }

    private static func todayFocusCareLedgerEntry(from event: CareLedgerEvent) -> TodayFocusCareLedgerEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return TodayFocusCareLedgerEntry(
            id: event.id,
            petId: subjectId,
            eventKind: event.eventKindEnum,
            actionType: event.actionType,
            date: event.occurredAt,
            sourceEventId: event.sourceEventId.flatMap(UUID.init(uuidString:)),
            actorId: event.actorId
        )
    }

    private static func visibleSnapshotHasNoBlockingNonQuestCards(
        _ snapshot: TodayFocusSnapshot?,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let snapshot else { return true }
        let skippedFocusKeys = TodayFocusHiddenStateStore.loadSkippedFocusKeys(date: now, calendar: calendar)
        let closedNegativeKeys = TodayFocusHiddenStateStore.loadClosedNegativeKeys(date: now, calendar: calendar)
        let visibleFamilyTasks = snapshot.assignedFamilyTasks.prefix(TodayFocusLimits.maxFamilyTaskCards).contains {
            !skippedFocusKeys.contains("familyTask:\($0.id.uuidString)")
        }
        let visibleExchangeRequests = CoconutExchangeFeatureGate.isEnabled &&
            snapshot.pendingExchangeRequests.prefix(TodayFocusLimits.maxExchangeCards).contains {
                !skippedFocusKeys.contains("coconutExchange:\($0.id.uuidString)")
            }
        let visibleNegativeSignals = snapshot.negativeSignals.prefix(TodayFocusLimits.maxNegativeCards).contains {
            !closedNegativeKeys.contains($0.id)
        }
        return !visibleFamilyTasks && !visibleExchangeRequests && !visibleNegativeSignals
    }

    private struct TodayFocusCompletionData {
        let pets: [Pet]
        let humans: [Human]
        let plants: [Plant]
        let reminders: [Reminder]
        let events: [Event]
        let careLedgerEntries: [TodayFocusCareLedgerEntry]
        let humanWeightLogs: [HumanWeightLog]

        init(context: ModelContext, now: Date, calendar: Calendar = .current) {
            pets = TodayFocusEconomyService.fetchPets(context: context)
            humans = TodayFocusEconomyService.fetchHumans(context: context)
            plants = PlantFeatureGate.allows(.plants) ? TodayFocusEconomyService.fetchPlants(context: context) : []
            reminders = TodayFocusEconomyService.fetchTodayReminders(context: context, now: now, calendar: calendar)
            events = TodayFocusEconomyService.fetchTodayFocusEvents(context: context, now: now, calendar: calendar)
            careLedgerEntries = TodayFocusEconomyService.fetchTodayCareLedgerEntries(context: context, now: now, calendar: calendar)
            humanWeightLogs = TodayFocusEconomyService.fetchTodayHumanWeightLogs(context: context, now: now, calendar: calendar)
        }
    }
}
