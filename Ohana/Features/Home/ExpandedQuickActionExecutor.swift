//
//  ExpandedQuickActionExecutor.swift
//  Ohana
//
//  Side-effect executor for expanded-card quick actions. The home view decides
//  routing; this type performs model writes, reward bookkeeping, and reminder
//  sync so those details stay out of the wallet animation path.
//

import SwiftData
import SwiftUI

@MainActor
enum ExpandedQuickActionExecutor {
    struct Feedback {
        let cardId: UUID
        let coconutDelta: Int
        let label: String?
    }

    @discardableResult
    static func performFeedCheckIn(
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        allFoodRecords: [PetFoodRecord],
        humans: [Human],
        modelContext: ModelContext,
        now: Date,
        antiRepeatTitle: String,
        antiRepeatMessage: @escaping ((executorName: String, minutesAgo: Int)) -> String,
        openFeedDetail: @escaping (_ opensManualSheet: Bool) -> Void,
        completePlannedFeed: @escaping (Pet) -> Bool,
        showAntiRepeat: @escaping (_ title: String, _ message: String, _ pendingAction: @escaping () -> Bool) -> Void,
        feedback: @escaping (Feedback) -> Void,
        careEvents: CareEventRecording
    ) -> Bool {
        let performFeed: () -> Bool = {
            let dashboard = ExpandedQuickActionLogic.feedDashboard(
                for: pet,
                allEvents: allEvents,
                now: now
            )
            switch dashboard.operatingMode {
            case .manual:
                let amount = pet.dailyPortionGrams
                guard amount > 0 else {
                    openFeedDetail(true)
                    return false
                }
                let result = ManualFeedCommand.recordManual(
                    pet: pet,
                    targets: [pet],
                    grams: amount,
                    foodKind: pet.mainFoodKind,
                    saveAsDefault: false,
                    foodRecords: allFoodRecords,
                    allEvents: allEvents,
                    context: modelContext,
                    executorId: executorId,
                    careEvents: careEvents,
                    date: now
                )
                guard result.didPersist, result.didRecord, result.allowsDerivedEffects else { return false }
                let coconutDelta = result.coconutDelta
                feedback(Feedback(cardId: pet.id, coconutDelta: coconutDelta, label: rewardLabel(actionType: "feed", delta: coconutDelta)))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return true
            case .manualReminder:
                if completePlannedFeed(pet) { return true }
                openFeedDetail(false)
                return false
            case .autoFeeder:
                openFeedDetail(false)
                return false
            }
        }

        let dashboard = ExpandedQuickActionLogic.feedDashboard(
            for: pet,
            allEvents: allEvents,
            now: now
        )
        let willWriteFeedLog = (dashboard.operatingMode == .manual && pet.dailyPortionGrams > 0) ||
            (dashboard.operatingMode == .manualReminder && dashboard.nextManualReminder != nil)

        if willWriteFeedLog,
           let warning = AntiRepeatCareManager.checkRecentCareLedger(
               for: pet,
               type: .feeding,
               ledgerEvents: recentCareLedgerEvents(
                   for: pet,
                   type: .feeding,
                   thresholdMinutes: 120,
                   context: modelContext,
                   now: now
               ),
               thresholdMinutes: 120,
               currentUserId: executorId,
               in: humans,
               now: now
           ) {
            showAntiRepeat(antiRepeatTitle, antiRepeatMessage(warning), performFeed)
            return false
        } else {
            return performFeed()
        }
    }

    @discardableResult
    static func performWaterCheckIn(
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        modelContext: ModelContext,
        now: Date,
        openWaterManagement: (Pet) -> Void,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) -> Bool {
        guard !WaterQuickActionPolicy.isAquatic(species: pet.species) else {
            openWaterManagement(pet)
            return false
        }

        let state = ExpandedQuickActionLogic.waterRuleState(for: pet, allEvents: allEvents, now: now)
        if state.operatingMode == .reminder {
            if let reminder = state.nextPendingReminder {
                let result = careEvents.completePlannedWaterResult(
                    pet: pet,
                    reminder: reminder,
                    amountMl: ExpandedQuickActionLogic.defaultWaterAmountMl(for: pet) ?? 0,
                    context: modelContext,
                    executorId: executorId,
                    occurredAt: nil,
                    operationDate: now
                )
                guard result.didRecord, result.allowsDerivedEffects else { return false }
                let delta = result.coconutDelta
                feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: rewardLabel(actionType: "water", delta: delta)))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return true
            }
            openWaterManagement(pet)
            return false
        }

        let recorded = careEvents.recordCareFact(
            pet: pet,
            type: .watering,
            amountMl: ExpandedQuickActionLogic.defaultWaterAmountMl(for: pet) ?? 0,
            context: modelContext,
            executorId: executorId,
            reward: .water,
            quality: .none,
            date: now,
            source: .quickAction,
            createsLinkedPottyLog: false
        )
        guard recorded.result.didWriteFact, recorded.result.allowsDerivedEffects else { return false }
        let delta = recorded.reward.humanGot + recorded.reward.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: rewardLabel(actionType: "water", delta: delta)))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    @discardableResult
    static func performMedicationCheckIn(
        pet: Pet,
        allEvents: [Event],
        modelContext: ModelContext,
        openMedication: (Pet) -> Void,
        feedback: (Feedback) -> Void,
        questManager: QuestManager,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> Bool {
        let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
        let activeMeds = pet.medications.filter(\.isActiveToday)
        guard !activeMeds.isEmpty else {
            openMedication(pet)
            return false
        }

        let targetMedication = activeMeds.first { medication in
            let required = PetMedicationDoseLogging.requiredDoses(on: Date(), for: medication)
            guard required > 0 else { return false }
            let done = PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: medication.id)
            return done < required
        } ?? activeMeds.first(where: { PetMedicationDoseLogging.requiredDoses(on: Date(), for: $0) == 0 })

        guard let medication = targetMedication else {
            openMedication(pet)
            return false
        }

        let result = PetMedicationDoseLogging.recordDoseResult(
            medication: medication,
            pet: pet,
            modelContext: modelContext,
            awardCoconut: true,
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            medicationReminders: medicationReminders
        )
        guard result.didPersist, result.didRecord, result.allowsDerivedEffects else { return false }
        medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
        feedback(Feedback(cardId: pet.id, coconutDelta: result.coconutDelta, label: rewardLabel(actionType: "medication", delta: result.coconutDelta)))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    @discardableResult
    static func performActionType(
        _ actionType: String,
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        allFoodRecords: [PetFoodRecord],
        humans: [Human],
        modelContext: ModelContext,
        now: Date,
        antiRepeatTitle: String,
        antiRepeatMessage: @escaping ((executorName: String, minutesAgo: Int)) -> String,
        openFeedDetail: @escaping (_ opensManualSheet: Bool) -> Void,
        completePlannedFeed: @escaping (Pet) -> Bool,
        showAntiRepeat: @escaping (_ title: String, _ message: String, _ pendingAction: @escaping () -> Bool) -> Void,
        startWalk: (Pet) -> Void,
        openWaterManagement: (Pet) -> Void,
        openMedication: (Pet) -> Void,
        feedback: @escaping (Feedback) -> Void,
        careEvents: CareEventRecording,
        questManager: QuestManager,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> Bool {
        let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
        switch actionType {
        case "feed":
            return performFeedCheckIn(
                pet: pet,
                executorId: executorId,
                allEvents: allEvents,
                allFoodRecords: allFoodRecords,
                humans: humans,
                modelContext: modelContext,
                now: now,
                antiRepeatTitle: antiRepeatTitle,
                antiRepeatMessage: antiRepeatMessage,
                openFeedDetail: openFeedDetail,
                completePlannedFeed: completePlannedFeed,
                showAntiRepeat: showAntiRepeat,
                feedback: feedback,
                careEvents: careEvents
            )
        case "water":
            return performWaterCheckIn(
                pet: pet,
                executorId: executorId,
                allEvents: allEvents,
                modelContext: modelContext,
                now: now,
                openWaterManagement: openWaterManagement,
                feedback: feedback,
                careEvents: careEvents
            )
        case "walk":
            startWalk(pet)
            return false
        case "litter":
            let recorded = careEvents.recordCareFact(
                pet: pet,
                type: .litter,
                amountMl: 0,
                context: modelContext,
                executorId: executorId,
                reward: .potty(isLitter: true),
                quality: .none,
                date: now,
                source: .quickAction,
                createsLinkedPottyLog: false
            )
            guard recorded.result.didWriteFact, recorded.result.allowsDerivedEffects else { return false }
            let delta = recorded.reward.humanGot + recorded.reward.petGot
            feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: rewardLabel(actionType: "litter", delta: delta)))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        case "play":
            let didRecord = performSpecialCare(.play, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            if didRecord { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            return didRecord
        case "medication":
            return performMedicationCheckIn(
                pet: pet,
                allEvents: allEvents,
                modelContext: modelContext,
                openMedication: openMedication,
                feedback: feedback,
                questManager: questManager,
                medicationReminders: medicationReminders
            )
        case "waterChange", "filterClean":
            openWaterManagement(pet)
            return false
        case "cageCleaning":
            let didRecord = performSpecialCare(.cageCleaning, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            if didRecord { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            return didRecord
        case "freeFlight":
            let didRecord = performSpecialCare(.freeFlight, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            if didRecord { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            return didRecord
        case "misting":
            let didRecord = performSpecialCare(.misting, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            if didRecord { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            return didRecord
        case "substrateChange":
            let didRecord = performSpecialCare(.substrateChange, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            if didRecord { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            return didRecord
        default:
            return false
        }
    }

    @discardableResult
    static func applyGroomCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        modelContext: ModelContext,
        showSingleUseNotice: (String, String) -> Void,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) -> Bool {
        let type: HygieneType
        switch raw {
        case "bath": type = .bath
        case "teeth": type = .teeth
        case "nails": type = .nails
        case "brushing": type = .brushing
        case "ears": type = .ears
        default: return false
        }

        guard !hasCompletedHygieneToday(pet: pet, type: type, context: modelContext) else {
            let l = L10n()
            showSingleUseNotice(
                l.tr(zh: "今天已经完成了", en: "Already done today", de: "Heute schon erledigt"),
                l.tr(
                    zh: "\(pet.name) 今天已经记录过\(l.hygieneTypeUILabel(type))了，这类护理一天记录一次就够了。",
                    en: "\(pet.name) already has \(l.hygieneTypeUILabel(type)) logged today. Once a day is enough for this care type.",
                    de: "\(pet.name) hat heute bereits \(l.hygieneTypeUILabel(type)) erfasst. Einmal pro Tag reicht fuer diese Pflege."
                )
            )
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return false
        }

        let recorded = careEvents.recordHygieneFact(
            pet: pet,
            type: type,
            context: modelContext,
            executorId: executorId,
            date: Date()
        )
        guard recorded.result.didWriteFact, recorded.result.allowsDerivedEffects else { return false }
        let delta = recorded.reward.humanGot + recorded.reward.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: rewardLabel(title: L10n().hygieneTypeUILabel(type), delta: delta)))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    static func applyPottyCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        modelContext: ModelContext,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) -> Bool {
        guard let type = PottyType(rawValue: raw) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return false
        }
        let recorded = careEvents.recordPottyFact(pet: pet, type: type, context: modelContext, executorId: executorId, date: Date())
        guard recorded.result.didWriteFact, recorded.result.allowsDerivedEffects else { return false }
        let delta = recorded.reward.humanGot + recorded.reward.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: rewardLabel(title: L10n().pottyTypeUILabel(type), delta: delta)))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    @discardableResult
    static func applyHealthCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        modelContext: ModelContext,
        openHealth: (Pet) -> Void,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) -> Bool {
        let type: HealthLogType
        switch raw {
        case "vaccine":
            type = .vaccine
        case "deworming":
            type = .dewormingExternal
        case "visit":
            type = .checkup
        default:
            openHealth(pet)
            return false
        }
        let recorded = careEvents.recordHealthFact(
            pet: pet,
            type: type,
            note: L10n().tr(zh: "快捷打卡", en: "Quick check-in", de: "Schnell-Check-in"),
            context: modelContext,
            executorId: executorId,
            date: Date()
        )
        guard recorded.result.didWriteFact, recorded.result.allowsDerivedEffects else { return false }
        let delta = recorded.reward.humanGot + recorded.reward.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: rewardLabel(actionType: "health", delta: delta)))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    @discardableResult
    static func performSpecialCare(
        _ type: CareType,
        pet: Pet,
        executorId: String?,
        modelContext: ModelContext,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) -> Bool {
        let rewardAmounts: (human: Int, pet: Int) = switch type {
        case .filterClean: (25, 2)
        case .cageCleaning, .freeFlight, .substrateChange: (10, 2)
        case .play, .misting: (3, 2)
        default: (3, 2)
        }
        let reward = QuestManager.OhanaActionType.general(
            humanReward: rewardAmounts.human,
            petReward: rewardAmounts.pet,
            emoji: type.emoji,
            title: specialCareRewardTitle(type, petName: pet.name)
        )
        let recorded = careEvents.recordCareFact(
            pet: pet,
            type: type,
            amountMl: 0,
            context: modelContext,
            executorId: executorId,
            reward: reward,
            quality: .none,
            date: Date(),
            source: .quickAction,
            createsLinkedPottyLog: false
        )
        guard recorded.result.didWriteFact, recorded.result.allowsDerivedEffects else { return false }
        let delta = recorded.reward.humanGot + recorded.reward.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: rewardLabel(title: L10n().careTypeUILabel(type), delta: delta)))
        return true
    }

    static func rewardLabel(actionType: String, delta: Int, l: L10n = L10n()) -> String? {
        guard delta > 0 else { return nil }
        let title = switch actionType {
        case "feed": l.homeQAFeed
        case "water": l.homeQAWater
        case "medication": l.homeQAMeds
        case "litter": l.homeQALitter
        case "health": l.goFeatHealth
        default: l.tr(zh: "打卡", en: "Check-in", de: "Check-in")
        }
        return rewardLabel(title: title, delta: delta)
    }

    static func rewardLabel(title: String, delta: Int) -> String? {
        guard delta > 0 else { return nil }
        return "\(title) +\(delta)🥥"
    }

    static func specialCareRewardTitle(_ type: CareType, petName: String, l: L10n = L10n()) -> String {
        let careTitle = l.careTypeUILabel(type)
        return l.tr(
            zh: "\(petName) \(careTitle)奖励",
            en: "\(petName) \(careTitle) reward",
            de: "\(petName) \(careTitle) Belohnung"
        )
    }

    private static func hasCompletedHygieneToday(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        let subjectKind = CareLedgerSubjectKind.pet.rawValue
        let subjectId = pet.id.uuidString
        let eventKind = CareLedgerEventKind.hygiene.rawValue
        let actionType = type.rawValue
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == subjectKind &&
                    event.subjectId == subjectId &&
                    event.eventKind == eventKind &&
                    event.actionType == actionType &&
                    event.occurredAt >= startOfDay &&
                    event.occurredAt < endOfDay
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).isEmpty == false
        } catch {
            OhanaLog.warning(
                "Expanded quick action failed to fetch hygiene ledger duplicate state: \(error.localizedDescription)",
                category: "Care"
            )
            return false
        }
    }

    private static func recentCareLedgerEvents(
        for pet: Pet,
        type: CareType,
        thresholdMinutes: Int,
        context: ModelContext,
        now: Date
    ) -> [CareLedgerEvent] {
        let subjectKind = CareLedgerSubjectKind.pet.rawValue
        let subjectId = pet.id.uuidString
        let eventKind = CareLedgerEventKind.care.rawValue
        let actionType = type.rawValue
        let since = now.addingTimeInterval(-Double(thresholdMinutes * 60))
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == subjectKind &&
                    event.subjectId == subjectId &&
                    event.eventKind == eventKind &&
                    event.actionType == actionType &&
                    event.occurredAt >= since &&
                    event.occurredAt <= now
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 12
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Expanded quick action failed to fetch recent care ledger events: \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }
}
