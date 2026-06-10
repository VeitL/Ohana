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
struct QuickWaterCommandExecutor {
    private let context: ModelContext
    private let activeHumanSelection: ActiveHumanSelecting
    private let careEvents: CareEventRecording
    private let userNotifications: UserNotificationManaging
    private let reminderScheduling: ReminderSchedulingManaging

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
        reminderScheduling: ReminderSchedulingManaging
    ) {
        self.context = context
        self.activeHumanSelection = activeHumanSelection
        self.careEvents = careEvents
        self.userNotifications = userNotifications
        self.reminderScheduling = reminderScheduling
    }

    func latestAllEvents(fallback: [Event]) -> [Event] {
        var descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        descriptor.fetchLimit = 0
        return (try? context.fetch(descriptor)) ?? fallback
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
        return carePlanReminders(pet: pet, allEvents: allEvents, titleContains: "换水")
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
        return carePlanReminders(pet: pet, allEvents: allEvents, titleContains: "滤芯")
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
        return QuickWaterPlanSaveResult(
            normalizedTimes: normalized,
            optimisticPlanEvents: WaterPlanWriter.planEvents(pet: pet, allEvents: latestEvents),
            reminders: reminders,
            targetCount: targets.count
        )
    }

    func setWaterMode(_ mode: WaterOperatingMode, pet: Pet) {
        WaterOperatingMode.set(pet.id, mode: mode)
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
            executorId: executorId
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
        let reward = targets.count > 1
            ? careEvents.recordSharedWatering(
                sourcePet: pet,
                targets: targets,
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
        return QuickWaterRewardResult(
            coconutDelta: reward.humanGot + reward.petGot,
            targetCount: max(targets.count, 1)
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
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
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
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
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
        context.delete(log)
        context.safeSave()
        return kind
    }

    func activeExecutorId() -> String? {
        activeHumanSelection.currentHumanId
    }

    private func carePlanReminders(pet: Pet, allEvents: [Event], titleContains text: String) -> [Reminder] {
        latestAllEvents(fallback: allEvents)
            .filter { event in
                event.relatedEntityId == pet.id.uuidString &&
                    event.title.contains(text)
            }
            .flatMap(\.reminders)
    }
}
