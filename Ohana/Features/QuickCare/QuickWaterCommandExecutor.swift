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
    let coconutDelta: Int
    let targetCount: Int
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
    private let revisions: DomainRevisionPublishing

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
        self.revisions = revisions ?? SharedDomainRevisionPublisher()
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
        publishWaterMutation(.waterPlan(petID: pet.id, action: "save_water_change"), affectedEntityIDs: [pet.id])
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
        publishWaterMutation(.waterPlan(petID: pet.id, action: "save_filter"), affectedEntityIDs: [pet.id])
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
        publishWaterMutation(
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
        publishWaterMutation(
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
        publishWaterMutation(.waterPlan(petID: pet.id, action: "delete_drink"), affectedEntityIDs: [pet.id])
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
        let reward = careEvents.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            date: Date()
        )
        publishWaterMutation(
            .waterLog(petID: pet.id, source: "planned"),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: reward != nil,
            note: reward == nil ? "planned_water_noop" : "planned_water_completed"
        )
        return QuickWaterRewardResult(
            coconutDelta: (reward?.humanGot ?? 0) + (reward?.petGot ?? 0),
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
            publishWaterMutation(
                .waterLog(petID: pet.id, source: "manual"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "manual_water_noop"
            )
            return QuickWaterRewardResult(coconutDelta: 0, targetCount: 0)
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            publishWaterMutation(
                .waterLog(petID: pet.id, source: "manual"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "manual_water_noop"
            )
            return QuickWaterRewardResult(coconutDelta: 0, targetCount: 0)
        }
        let reward = liveTargets.count > 1
            ? careEvents.recordSharedWatering(
                sourcePet: pet,
                targets: liveTargets,
                totalMl: amountMl,
                context: context,
                executorId: executorId,
                date: Date()
            )
            : careEvents.recordCare(
                pet: pet,
                type: .watering,
                amountMl: amountMl,
                context: context,
                executorId: executorId,
                reward: .water,
                quality: .none,
                date: Date()
            )
        publishWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_manual" : "manual"),
            affectedEntityIDs: targetIDs(pet: pet, targets: liveTargets),
            note: liveTargets.count > 1 ? "shared_water" : "manual_water"
        )
        return QuickWaterRewardResult(
            coconutDelta: reward.humanGot + reward.petGot,
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
    ) -> [Reminder] {
        guard EconomyWalletWritePolicy.canWrite(pet) else {
            publishWaterMutation(
                .waterLog(petID: pet.id, source: "water_change"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "water_change_noop"
            )
            return []
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            publishWaterMutation(
                .waterLog(petID: pet.id, source: "water_change"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "water_change_noop"
            )
            return []
        }
        let reward = QuestManager.OhanaActionType.general(
            humanReward: 15,
            petReward: 2,
            emoji: CareType.waterChange.emoji,
            title: "\(pet.name) 换水奖励"
        )
        _ = careEvents.recordSharedCare(
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
        publishWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_water_change" : "water_change"),
            affectedEntityIDs: targetIDs(pet: pet, targets: liveTargets),
            note: "water_change"
        )
        return liveTargets.flatMap {
            saveWaterChangePlan(
                pet: $0,
                allEvents: allEvents,
                intervalDays: intervalDays,
                reminderOn: reminderOn,
                cycleAnchor: cycleAnchor
            )
        }
    }

    func recordFilterClean(
        pet: Pet,
        targets: [Pet],
        allEvents: [Event],
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        reminderOn: Bool,
        executorId: String?
    ) -> [Reminder] {
        guard EconomyWalletWritePolicy.canWrite(pet) else {
            publishWaterMutation(
                .waterLog(petID: pet.id, source: "filter_clean"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "filter_clean_noop"
            )
            return []
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            publishWaterMutation(
                .waterLog(petID: pet.id, source: "filter_clean"),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: false,
                note: "filter_clean_noop"
            )
            return []
        }
        let reward = QuestManager.OhanaActionType.general(
            humanReward: 25,
            petReward: 2,
            emoji: CareType.filterClean.emoji,
            title: "\(pet.name) 清理滤材报酬"
        )
        _ = careEvents.recordSharedCare(
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
        publishWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_filter_clean" : "filter_clean"),
            affectedEntityIDs: targetIDs(pet: pet, targets: liveTargets),
            note: "filter_clean"
        )
        return liveTargets.flatMap {
            syncFilterPlan(
                pet: $0,
                allEvents: allEvents,
                cleanIntervalDays: cleanIntervalDays,
                replaceIntervalDays: replaceIntervalDays,
                reminderOn: reminderOn
            )
        }
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
            publishWaterMutation(.waterLog(petID: petID, source: "delete"), affectedEntityIDs: [petID], note: "\(kind)")
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

    private func publishWaterMutation(
        _ command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool = true,
        note: String? = nil
    ) {
        guard wroteBusinessFact else {
            AppPerformanceMonitor.shared.record("domain_command_noop", valueMS: 0, note: note ?? "\(command)")
            return
        }
        revisions.publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affectedEntityIDs,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    private func targetIDs(pet: Pet, targets: [Pet]) -> Set<UUID> {
        let ids = targets.isEmpty ? [pet.id] : targets.map(\.id)
        return Set(ids)
    }
}
