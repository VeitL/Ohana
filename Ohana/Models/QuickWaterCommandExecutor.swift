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

    init(context: ModelContext) {
        self.context = context
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
        let defaults = UserDefaults.standard
        let petKey = pet.id.uuidString
        defaults.set(intervalDays, forKey: "waterInterval_\(petKey)")
        defaults.set(cycleAnchor.timeIntervalSince1970, forKey: "waterChangeCycleAnchor_\(petKey)")
        defaults.set(reminderOn, forKey: "waterReminder_\(petKey)")
    }

    func persistWaterAmountSettings(pet: Pet, enabled: Bool, amountMl: Double?) {
        let defaults = UserDefaults.standard
        let petKey = pet.id.uuidString
        defaults.set(enabled, forKey: "waterAmountEnabled_\(petKey)")
        if let amountMl {
            defaults.set(amountMl, forKey: "waterAmountMl_\(petKey)")
        }
    }

    func persistFilterSettings(
        pet: Pet,
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        reminderOn: Bool
    ) {
        let defaults = UserDefaults.standard
        let petKey = pet.id.uuidString
        defaults.set(cleanIntervalDays, forKey: "filterCleanInterval_\(petKey)")
        defaults.set(replaceIntervalDays, forKey: "filterReplaceInterval_\(petKey)")
        defaults.set(reminderOn, forKey: "filterReminder_\(petKey)")
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
            guard await NotificationManager.shared.requestPermission() else { return }
        }
        guard !Task.isCancelled else { return }
        await ReminderSchedulingService.scheduleManyIfNeeded(
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
        let reward = CareEventService.completePlannedWater(
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
            ? CareEventService.recordSharedWatering(
                sourcePet: pet,
                targets: targets,
                totalMl: amountMl,
                context: context,
                executorId: executorId
            )
            : CareEventService.recordCare(
                pet: pet,
                type: .watering,
                amountMl: amountMl,
                context: context,
                executorId: executorId,
                reward: .water
            )
        return QuickWaterRewardResult(
            coconutDelta: reward.humanGot + reward.petGot,
            targetCount: max(targets.count, 1)
        )
    }

    func recordWaterChange(
        pet: Pet,
        allEvents: [Event],
        intervalDays: Int,
        reminderOn: Bool,
        cycleAnchor: Date,
        executorId: String?
    ) -> [Reminder] {
        _ = CareEventService.recordCare(
            pet: pet,
            type: .waterChange,
            context: context,
            executorId: executorId,
            reward: .general(
                humanReward: 15,
                petReward: 2,
                emoji: CareType.waterChange.emoji,
                title: "\(pet.name) 换水奖励"
            )
        )
        return saveWaterChangePlan(
            pet: pet,
            allEvents: allEvents,
            intervalDays: intervalDays,
            reminderOn: reminderOn,
            cycleAnchor: cycleAnchor
        )
    }

    func recordFilterClean(
        pet: Pet,
        allEvents: [Event],
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        reminderOn: Bool,
        executorId: String?
    ) -> [Reminder] {
        _ = CareEventService.recordCare(
            pet: pet,
            type: .filterClean,
            context: context,
            executorId: executorId,
            reward: .general(
                humanReward: 25,
                petReward: 2,
                emoji: CareType.filterClean.emoji,
                title: "\(pet.name) 清理滤材报酬"
            )
        )
        return syncFilterPlan(
            pet: pet,
            allEvents: allEvents,
            cleanIntervalDays: cleanIntervalDays,
            replaceIntervalDays: replaceIntervalDays,
            reminderOn: reminderOn
        )
    }

    func deleteLog(_ log: PetCareLog) -> QuickWaterDeletedLogKind {
        let kind: QuickWaterDeletedLogKind
        if log.type == CareType.waterChange.rawValue {
            kind = .waterChange
        } else if log.type == CareType.filterClean.rawValue {
            kind = .filterClean
        } else {
            kind = .other
        }
        context.delete(log)
        context.safeSave()
        return kind
    }

    func activeExecutorId() -> String? {
        UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
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
