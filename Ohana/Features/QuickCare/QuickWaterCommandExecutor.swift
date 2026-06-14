//
//  QuickWaterCommandExecutor.swift
//  Ohana
//
//  Domain-scoped write and service operations for quick water flows.
//

import Foundation
import SwiftData

struct QuickWaterPlanSaveResult {
    let normalizedTimes: [Date]
    let optimisticPlanEvents: [Event]
    let reminders: [Reminder]
    let targetCount: Int
}

struct QuickWaterRewardResult {
    let didRecord: Bool
    let allowsDerivedEffects: Bool
    let coconutDelta: Int
    let targetCount: Int
}

struct QuickWaterCareResult {
    let didRecord: Bool
    let allowsDerivedEffects: Bool
    let reminders: [Reminder]

    static let noOp = QuickWaterCareResult(didRecord: false, allowsDerivedEffects: false, reminders: [])
}

enum QuickWaterDeletedLogKind {
    case waterChange
    case filterClean
    case other
}

@MainActor
private func fetchQuickWaterModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String,
    fallback: [T] = []
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "QuickWaterCommandExecutor failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return fallback
    }
}

@MainActor
struct QuickWaterCommandExecutor {
    private let context: ModelContext
    private let activeHumanSelection: ActiveHumanSelecting
    private let careEvents: CareEventRecording
    private let userNotifications: UserNotificationManaging
    private let reminderScheduling: ReminderSchedulingManaging
    private let derivations: CareDerivationExecutor

    init(
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection()
    ) {
        self.init(
            context: context,
            activeHumanSelection: activeHumanSelection,
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager()
        )
    }

    init(
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting,
        careEvents: CareEventRecording,
        userNotifications: UserNotificationManaging,
        reminderScheduling: ReminderSchedulingManaging,
        revisions: DomainRevisionPublishing? = nil
    ) {
        self.context = context
        self.activeHumanSelection = activeHumanSelection
        self.careEvents = careEvents
        self.userNotifications = userNotifications
        self.reminderScheduling = reminderScheduling
        derivations = CareDerivationExecutor(revisions: revisions ?? SharedDomainRevisionPublisher())
    }

    func latestAllEvents(fallback: [Event]) -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        let events = fetchQuickWaterModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch latest events",
            fallback: fallback
        )
        return events
    }

    func suggestedWaterPlanTimes(count: Int) -> [Date] {
        WaterPlanWriter.suggestedTimes(count: count)
    }

    func normalizedWaterPlanTimes(_ times: [Date], count: Int) -> [Date] {
        WaterPlanWriter.normalizedTimes(times, count: count)
    }

    func waterPlanEvents(pet: Pet, allEvents: [Event]) -> [Event] {
        WaterPlanWriter.planEvents(pet: pet, allEvents: allEvents)
    }

    func persistWaterSettings(
        pet: Pet,
        intervalDays: Int,
        reminderOn: Bool,
        cycleAnchor: Date
    ) {
        WaterCareSettingsStore.saveWaterSettings(
            petKey: pet.id.uuidString,
            intervalDays: intervalDays,
            reminderOn: reminderOn,
            cycleAnchor: cycleAnchor
        )
    }

    func persistWaterAmountSettings(pet: Pet, enabled: Bool, amountMl: Double?) {
        WaterCareSettingsStore.saveWaterAmountSettings(
            petKey: pet.id.uuidString,
            enabled: enabled,
            amountMl: amountMl
        )
    }

    func persistFilterSettings(
        pet: Pet,
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        reminderOn: Bool
    ) {
        WaterCareSettingsStore.saveFilterSettings(
            petKey: pet.id.uuidString,
            cleanIntervalDays: cleanIntervalDays,
            replaceIntervalDays: replaceIntervalDays,
            reminderOn: reminderOn
        )
    }

    func saveWaterChangePlan(
        pet: Pet,
        allEvents: [Event],
        intervalDays: Int,
        reminderOn: Bool,
        cycleAnchor: Date
    ) -> [Reminder] {
        persistWaterSettings(
            pet: pet,
            intervalDays: intervalDays,
            reminderOn: reminderOn,
            cycleAnchor: cycleAnchor
        )
        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet,
            context: context,
            intervalDays: intervalDays,
            enabled: reminderOn,
            cycleAnchor: cycleAnchor
        )
        deriveWaterMutation(.waterPlan(petID: pet.id, action: "save_water_change"), affectedEntityIDs: [pet.id])
        return carePlanReminders(pet: pet, allEvents: allEvents, kinds: ["waterChange"])
    }

    func syncFilterPlan(
        pet: Pet,
        allEvents: [Event],
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        reminderOn: Bool
    ) -> [Reminder] {
        persistFilterSettings(
            pet: pet,
            cleanIntervalDays: cleanIntervalDays,
            replaceIntervalDays: replaceIntervalDays,
            reminderOn: reminderOn
        )
        CarePlanCalendarSync.syncFilterPlan(
            pet: pet,
            context: context,
            cleanIntervalDays: cleanIntervalDays,
            replaceIntervalDays: replaceIntervalDays,
            enabled: reminderOn
        )
        deriveWaterMutation(.waterPlan(petID: pet.id, action: "save_filter"), affectedEntityIDs: [pet.id])
        return carePlanReminders(pet: pet, allEvents: allEvents, kinds: ["filterClean", "filterReplace"])
    }

    func saveWaterPlan(
        pet: Pet,
        targets: [Pet],
        times: [Date],
        count: Int,
        allEvents: [Event]
    ) -> QuickWaterPlanSaveResult {
        let normalized = WaterPlanWriter.normalizedTimes(times, count: count)
        var latestEvents = allEvents
        var reminders: [Reminder] = []
        for target in targets {
            let created = WaterPlanWriter.replacePlan(
                pet: target,
                times: normalized,
                allEvents: latestEvents,
                context: context
            )
            reminders.append(contentsOf: created)
            let replacedEventIds = Set(WaterPlanWriter.planEvents(pet: target, allEvents: latestEvents).map(\.id))
            latestEvents = latestEvents
                .filter { !replacedEventIds.contains($0.id) } + created.compactMap(\.event)
            WaterOperatingMode.set(target.id, mode: .reminder)
        }
        deriveWaterMutation(
            .waterPlan(petID: pet.id, action: "save_drink"),
            affectedEntityIDs: targetIDs(pet: pet, targets: targets),
            note: "targets:\(targets.count)"
        )
        return QuickWaterPlanSaveResult(
            normalizedTimes: normalized,
            optimisticPlanEvents: WaterPlanWriter.planEvents(pet: pet, allEvents: latestEvents),
            reminders: reminders,
            targetCount: targets.count
        )
    }

    func setWaterMode(_ mode: WaterOperatingMode, pet: Pet) {
        let previousMode = WaterOperatingMode.stored(pet.id)
        WaterOperatingMode.set(pet.id, mode: mode)
        deriveWaterMutation(
            .waterMode(petID: pet.id, mode: mode.rawValue),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: previousMode != mode,
            note: "optimistic_mode"
        )
    }

    func deactivateWaterPlanReminders(pet: Pet, allEvents: [Event]) {
        WaterPlanWriter.deactivateReminderOperations(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
    }

    func deleteWaterPlan(pet: Pet, allEvents: [Event]) {
        WaterPlanWriter.deletePlan(pet: pet, allEvents: allEvents, context: context)
        deriveWaterMutation(.waterPlan(petID: pet.id, action: "delete_drink"), affectedEntityIDs: [pet.id])
    }

    func ensureUpcomingWaterPlanReminders(pet: Pet, allEvents: [Event]) -> [Reminder] {
        guard WaterRuleState(pet: pet, allEvents: allEvents).operatingMode == .reminder else {
            deactivateWaterPlanReminders(pet: pet, allEvents: allEvents)
            return []
        }
        return WaterPlanWriter.ensureUpcomingReminders(pet: pet, allEvents: allEvents, context: context)
    }

    func scheduleReminders(_ reminders: [Reminder], requestPermission: Bool) async {
        guard !reminders.isEmpty else { return }
        if requestPermission {
            guard await userNotifications.requestPermission() else { return }
        }
        guard !Task.isCancelled else { return }
        await reminderScheduling.scheduleManyIfNeeded(
            reminders: reminders,
            context: context,
            source: .detail
        )
    }

    func completePlannedWater(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        executorId: String?
    ) -> QuickWaterRewardResult {
        let completed = careEvents.completePlannedWaterResult(
            pet: pet,
            reminder: reminder,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            occurredAt: nil,
            operationDate: Date()
        )
        deriveWaterMutation(
            .waterLog(petID: pet.id, source: "planned"),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: completed.didRecord && completed.allowsDerivedEffects,
            note: completed.didRecord && completed.allowsDerivedEffects ? "planned_water_completed" : "planned_water_noop"
        )
        return QuickWaterRewardResult(
            didRecord: completed.didRecord,
            allowsDerivedEffects: completed.allowsDerivedEffects,
            coconutDelta: completed.coconutDelta,
            targetCount: 1
        )
    }

    func recordWater(
        pet: Pet,
        targets: [Pet],
        amountMl: Double,
        executorId: String?
    ) -> QuickWaterRewardResult {
        guard EconomyWalletWritePolicy.canWrite(pet) else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "manual"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "manual_water_noop"
            )
            return QuickWaterRewardResult(didRecord: false, allowsDerivedEffects: false, coconutDelta: 0, targetCount: 0)
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "manual"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "manual_water_noop"
            )
            return QuickWaterRewardResult(didRecord: false, allowsDerivedEffects: false, coconutDelta: 0, targetCount: 0)
        }
        let recorded = if liveTargets.count > 1 {
            careEvents.recordSharedWateringFact(
                sourcePet: pet,
                targets: liveTargets,
                totalMl: amountMl,
                context: context,
                executorId: executorId,
                date: Date()
            )
        } else {
            singleCareResult(careEvents.recordCareFact(
                pet: pet,
                type: .watering,
                amountMl: amountMl,
                context: context,
                executorId: executorId,
                reward: .water,
                quality: .none,
                date: Date(),
                source: .quickAction,
                createsLinkedPottyLog: false
            ))
        }
        guard recorded.didWriteFact else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "manual"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "manual_water_noop"
            )
            return QuickWaterRewardResult(didRecord: false, allowsDerivedEffects: false, coconutDelta: 0, targetCount: 0)
        }
        deriveWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_manual" : "manual"),
            affectedEntityIDs: targetIDs(pet: pet, targets: liveTargets),
            wroteBusinessFact: recorded.allowsDerivedEffects,
            note: liveTargets.count > 1 ? "shared_water" : "manual_water"
        )
        return QuickWaterRewardResult(
            didRecord: true,
            allowsDerivedEffects: recorded.allowsDerivedEffects,
            coconutDelta: recorded.reward.humanGot + recorded.reward.petGot,
            targetCount: liveTargets.count
        )
    }

    func recordWaterChange(
        pet: Pet,
        targets: [Pet],
        allEvents: [Event],
        intervalDays: Int,
        reminderOn: Bool,
        cycleAnchor: Date,
        executorId: String?
    ) -> QuickWaterCareResult {
        guard EconomyWalletWritePolicy.canWrite(pet) else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "water_change"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "water_change_noop"
            )
            return .noOp
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "water_change"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "water_change_noop"
            )
            return .noOp
        }
        let reward = QuestManager.OhanaActionType.general(
            humanReward: 15,
            petReward: 2,
            emoji: CareType.waterChange.emoji,
            title: "\(pet.name) 换水奖励"
        )
        let recorded = careEvents.recordSharedCareFact(
            sourcePet: pet,
            targets: liveTargets,
            type: .waterChange,
            actionKind: .waterChange,
            context: context,
            executorId: executorId,
            reward: reward,
            rewardTitle: liveTargets.count > 1 ? "共同换水 · \(liveTargets.count)只" : nil,
            quality: .none,
            date: Date(),
            source: .quickAction
        )
        guard recorded.didWriteFact, recorded.allowsDerivedEffects else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "water_change"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "water_change_noop"
            )
            return .noOp
        }
        deriveWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_water_change" : "water_change"),
            affectedEntityIDs: targetIDs(pet: pet, targets: liveTargets),
            note: "water_change"
        )
        let reminders = liveTargets.flatMap {
            saveWaterChangePlan(
                pet: $0,
                allEvents: allEvents,
                intervalDays: intervalDays,
                reminderOn: reminderOn,
                cycleAnchor: cycleAnchor
            )
        }
        return QuickWaterCareResult(didRecord: true, allowsDerivedEffects: true, reminders: reminders)
    }

    func recordFilterClean(
        pet: Pet,
        targets: [Pet],
        allEvents: [Event],
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        reminderOn: Bool,
        executorId: String?
    ) -> QuickWaterCareResult {
        guard EconomyWalletWritePolicy.canWrite(pet) else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "filter_clean"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "filter_clean_noop"
            )
            return .noOp
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "filter_clean"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "filter_clean_noop"
            )
            return .noOp
        }
        let reward = QuestManager.OhanaActionType.general(
            humanReward: 25,
            petReward: 2,
            emoji: CareType.filterClean.emoji,
            title: "\(pet.name) 清理滤材报酬"
        )
        let recorded = careEvents.recordSharedCareFact(
            sourcePet: pet,
            targets: liveTargets,
            type: .filterClean,
            actionKind: .filterClean,
            context: context,
            executorId: executorId,
            reward: reward,
            rewardTitle: liveTargets.count > 1 ? "共同清理滤材 · \(liveTargets.count)只" : nil,
            quality: .none,
            date: Date(),
            source: .quickAction
        )
        guard recorded.didWriteFact, recorded.allowsDerivedEffects else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "filter_clean"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "filter_clean_noop"
            )
            return .noOp
        }
        deriveWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_filter_clean" : "filter_clean"),
            affectedEntityIDs: targetIDs(pet: pet, targets: liveTargets),
            note: "filter_clean"
        )
        let reminders = liveTargets.flatMap {
            syncFilterPlan(
                pet: $0,
                allEvents: allEvents,
                cleanIntervalDays: cleanIntervalDays,
                replaceIntervalDays: replaceIntervalDays,
                reminderOn: reminderOn
            )
        }
        return QuickWaterCareResult(didRecord: true, allowsDerivedEffects: true, reminders: reminders)
    }

    func deleteLog(_ log: PetCareLog) -> QuickWaterDeletedLogKind {
        let kind: QuickWaterDeletedLogKind = if log.type == CareType.waterChange.rawValue {
            .waterChange
        } else if log.type == CareType.filterClean.rawValue {
            .filterClean
        } else {
            .other
        }
        let petID = log.pet?.id
        CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context)
        context.delete(log)
        context.safeSave()
        if let petID {
            deriveWaterMutation(.waterLog(petID: petID, source: "delete"), affectedEntityIDs: [petID], note: "\(kind)")
        }
        return kind
    }

    func activeExecutorId() -> String? {
        activeHumanSelection.currentHumanId
    }

    private func carePlanReminders(pet: Pet, allEvents: [Event], kinds: Set<String>) -> [Reminder] {
        CarePlanCalendarSync.waterMaintenancePlanEvents(
            pet: pet,
            kinds: kinds,
            allEvents: latestAllEvents(fallback: allEvents)
        )
        .flatMap(\.reminders)
    }

    private func deriveWaterMutation(
        _ command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool = true,
        note: String? = nil
    ) {
        guard wroteBusinessFact else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: affectedEntityIDs,
                    note: note ?? "\(command)"
                )
            )
            return
        }
        derivations.derive(
            .derivedMutation(
                command: command,
                affectedEntityIDs: affectedEntityIDs,
                note: note
            )
        )
    }

    private func targetIDs(pet: Pet, targets: [Pet]) -> Set<UUID> {
        let ids = targets.isEmpty ? [pet.id] : targets.map(\.id)
        return Set(ids)
    }

    private func singleCareResult(
        _ recorded: (result: CareEventService.CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?)
    ) -> SharedPetActionResult {
        SharedPetActionResult(
            sessionID: recorded.result.logID,
            targetPetIDs: recorded.result.didWriteFact ? [recorded.result.subjectID] : [],
            careLogIDs: recorded.result.didWriteFact ? [recorded.result.logID] : [],
            pottyLogID: recorded.result.linkedPottyLogID,
            pottyLog: recorded.pottyLog,
            expenseLogIDs: [],
            walkLogIDs: [],
            walkLogs: [],
            reward: recorded.reward,
            disposition: recorded.result.disposition
        )
    }
}
