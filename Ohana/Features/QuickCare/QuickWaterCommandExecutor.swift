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

enum QuickWaterCommandError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(reason):
            if let reason, !reason.isEmpty {
                return "饮水记录保存失败：\(reason)"
            }
            return "饮水记录保存失败，请稍后重试。"
        }
    }
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
        guard canWriteActiveWaterData(for: pet) else { return }
        WaterCareSettingsStore.saveWaterSettings(
            petKey: pet.id.uuidString,
            intervalDays: intervalDays,
            reminderOn: reminderOn,
            cycleAnchor: cycleAnchor
        )
    }

    func persistWaterAmountSettings(pet: Pet, enabled: Bool, amountMl: Double?) {
        guard canWriteActiveWaterData(for: pet) else { return }
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
        guard canWriteActiveWaterData(for: pet) else { return }
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
        guard canWriteActiveWaterData(for: pet) else {
            CarePlanCalendarSync.removeActiveCalendarPlans(for: pet, context: context)
            deriveWaterMutation(
                .waterPlan(petID: pet.id, action: "save_water_change"),
                pets: [pet],
                wroteBusinessFact: false,
                note: "water_change_plan_noop"
            )
            return []
        }
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
        deriveWaterMutation(.waterPlan(petID: pet.id, action: "save_water_change"), pets: [pet])
        return carePlanReminders(pet: pet, allEvents: allEvents, kinds: ["waterChange"])
    }

    func syncFilterPlan(
        pet: Pet,
        allEvents: [Event],
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        reminderOn: Bool
    ) -> [Reminder] {
        guard canWriteActiveWaterData(for: pet) else {
            CarePlanCalendarSync.removeActiveCalendarPlans(for: pet, context: context)
            deriveWaterMutation(
                .waterPlan(petID: pet.id, action: "save_filter"),
                pets: [pet],
                wroteBusinessFact: false,
                note: "filter_plan_noop"
            )
            return []
        }
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
        deriveWaterMutation(.waterPlan(petID: pet.id, action: "save_filter"), pets: [pet])
        return carePlanReminders(pet: pet, allEvents: allEvents, kinds: ["filterClean", "filterReplace"])
    }

    func saveWaterPlan(
        pet: Pet,
        targets: [Pet],
        times: [Date],
        count: Int,
        allEvents: [Event]
    ) throws -> QuickWaterPlanSaveResult {
        let normalized = WaterPlanWriter.normalizedTimes(times, count: count)
        var latestEvents = allEvents
        var reminders: [Reminder] = []
        var writableTargets: [Pet] = []
        for target in targets {
            let targetIsWritable = canWriteActiveWaterData(for: target)
            let created = try WaterPlanWriter.replacePlan(
                pet: target,
                times: normalized,
                allEvents: latestEvents,
                context: context
            )
            reminders.append(contentsOf: created)
            let replacedEventIds = Set(WaterPlanWriter.planEvents(pet: target, allEvents: latestEvents).map(\.id))
            latestEvents = latestEvents
                .filter { !replacedEventIds.contains($0.id) } + created.compactMap(\.event)
            if targetIsWritable { writableTargets.append(target) }
        }
        for target in writableTargets {
            WaterOperatingMode.set(target.id, mode: .reminder)
        }
        deriveWaterMutation(
            .waterPlan(petID: pet.id, action: "save_drink"),
            pets: writableTargets.isEmpty ? [pet] : writableTargets,
            wroteBusinessFact: !writableTargets.isEmpty,
            note: "targets:\(writableTargets.count)"
        )
        return QuickWaterPlanSaveResult(
            normalizedTimes: normalized,
            optimisticPlanEvents: WaterPlanWriter.planEvents(pet: pet, allEvents: latestEvents),
            reminders: reminders,
            targetCount: writableTargets.count
        )
    }

    func setWaterMode(_ mode: WaterOperatingMode, pet: Pet) {
        guard canWriteActiveWaterData(for: pet) else {
            deriveWaterMutation(
                .waterMode(petID: pet.id, mode: mode.rawValue),
                pets: [pet],
                wroteBusinessFact: false,
                note: "water_mode_noop"
            )
            return
        }
        let previousMode = WaterOperatingMode.stored(pet.id)
        WaterOperatingMode.set(pet.id, mode: mode)
        deriveWaterMutation(
            .waterMode(petID: pet.id, mode: mode.rawValue),
            pets: [pet],
            wroteBusinessFact: previousMode != mode,
            note: "optimistic_mode"
        )
    }

    func deactivateWaterPlanReminders(pet: Pet, allEvents: [Event]) throws {
        try WaterPlanWriter.deactivateReminderOperations(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
    }

    func deleteWaterPlan(pet: Pet, allEvents: [Event]) throws {
        try WaterPlanWriter.deletePlan(pet: pet, allEvents: allEvents, context: context)
        deriveWaterMutation(.waterPlan(petID: pet.id, action: "delete_drink"), pets: [pet])
    }

    func ensureUpcomingWaterPlanReminders(pet: Pet, allEvents: [Event]) throws -> [Reminder] {
        guard WaterRuleState(pet: pet, allEvents: allEvents).operatingMode == .reminder else {
            try deactivateWaterPlanReminders(pet: pet, allEvents: allEvents)
            return []
        }
        return try WaterPlanWriter.ensureUpcomingReminders(pet: pet, allEvents: allEvents, context: context)
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
            pets: [pet],
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
                pets: [pet],
                wroteBusinessFact: false,
                note: "manual_water_noop"
            )
            return QuickWaterRewardResult(didRecord: false, allowsDerivedEffects: false, coconutDelta: 0, targetCount: 0)
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "manual"),
                pets: [pet],
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
                pets: [pet],
                wroteBusinessFact: false,
                note: "manual_water_noop"
            )
            return QuickWaterRewardResult(didRecord: false, allowsDerivedEffects: false, coconutDelta: 0, targetCount: 0)
        }
        deriveWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_manual" : "manual"),
            pets: liveTargets,
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
                pets: [pet],
                wroteBusinessFact: false,
                note: "water_change_noop"
            )
            return .noOp
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "water_change"),
                pets: [pet],
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
                pets: [pet],
                wroteBusinessFact: false,
                note: "water_change_noop"
            )
            return .noOp
        }
        deriveWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_water_change" : "water_change"),
            pets: liveTargets,
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
                pets: [pet],
                wroteBusinessFact: false,
                note: "filter_clean_noop"
            )
            return .noOp
        }
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !liveTargets.isEmpty else {
            deriveWaterMutation(
                .waterLog(petID: pet.id, source: "filter_clean"),
                pets: [pet],
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
                pets: [pet],
                wroteBusinessFact: false,
                note: "filter_clean_noop"
            )
            return .noOp
        }
        deriveWaterMutation(
            .waterLog(petID: pet.id, source: liveTargets.count > 1 ? "shared_filter_clean" : "filter_clean"),
            pets: liveTargets,
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

    func deleteLog(_ log: PetCareLog) throws -> QuickWaterDeletedLogKind {
        let kind: QuickWaterDeletedLogKind = if log.type == CareType.waterChange.rawValue {
            .waterChange
        } else if log.type == CareType.filterClean.rawValue {
            .filterClean
        } else {
            .other
        }
        let pet = log.pet
        CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context)
        context.delete(log)
        try saveQuickWaterChanges()
        if let pet {
            deriveWaterMutation(.waterLog(petID: pet.id, source: "delete"), pets: [pet], note: "\(kind)")
        }
        return kind
    }

    func careLog(id: UUID) -> PetCareLog? {
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchQuickWaterModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch water care log by id"
        ).first
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
        pets: [Pet],
        wroteBusinessFact: Bool = true,
        note: String? = nil
    ) {
        let affectedEntityIDs = Set(pets.map(\.id))
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
        let effectPlans = DomainEffectWriteAuthorizer.authorizePetEffects(
            pets: pets,
            writeKind: .care,
            context: context,
            logPrefix: "QuickWaterCommandExecutor.derive"
        )
        guard !effectPlans.isEmpty else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: affectedEntityIDs,
                    note: note ?? "\(command).unauthorized"
                )
            )
            return
        }
        derivations.derive(
            .derivedMutation(
                command: command,
                effectPlans: effectPlans,
                note: note
            )
        )
    }

    private func saveQuickWaterChanges() throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw QuickWaterCommandError.persistenceFailed(saveResult.errorDescription)
        }
    }

    private func canWriteActiveWaterData(for pet: Pet) -> Bool {
        MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects
    }

    private func singleCareResult(
        _ recorded: (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?)
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
            disposition: recorded.result.disposition,
            didPersist: recorded.result.didPersist,
            persistenceErrorDescription: recorded.result.persistenceErrorDescription
        )
    }
}
