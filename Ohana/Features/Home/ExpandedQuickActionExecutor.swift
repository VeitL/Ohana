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

    static func performFeedCheckIn(
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        humans: [Human],
        modelContext: ModelContext,
        now: Date,
        antiRepeatTitle: String,
        antiRepeatMessage: @escaping ((executorName: String, minutesAgo: Int)) -> String,
        openFeedDetail: @escaping (_ opensManualSheet: Bool) -> Void,
        completePlannedFeed: @escaping (Pet) -> Bool,
        showAntiRepeat: @escaping (_ title: String, _ message: String, _ pendingAction: @escaping () -> Void) -> Void,
        feedback: @escaping (Feedback) -> Void,
        careEvents: CareEventRecording
    ) {
        let performFeed = {
            let dashboard = ExpandedQuickActionLogic.feedDashboard(
                for: pet,
                allEvents: allEvents,
                allFeedCareLogs: allFeedCareLogs,
                now: now
            )
            switch dashboard.operatingMode {
            case .manual:
                let amount = pet.dailyPortionGrams
                guard amount > 0 else {
                    openFeedDetail(true)
                    return
                }
                let reward = careEvents.recordManualFeed(
                    pet: pet,
                    amountGrams: amount,
                    context: modelContext,
                    executorId: executorId,
                    quality: .none,
                    date: now,
                    foodKind: pet.mainFoodKind
                )
                let coconutDelta = reward.humanGot + reward.petGot
                feedback(Feedback(cardId: pet.id, coconutDelta: coconutDelta, label: coconutDelta > 0 ? "喂食 +\(coconutDelta)🥥" : nil))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .manualReminder:
                if completePlannedFeed(pet) { return }
                openFeedDetail(false)
            case .autoFeeder:
                openFeedDetail(false)
            }
        }

        let dashboard = ExpandedQuickActionLogic.feedDashboard(
            for: pet,
            allEvents: allEvents,
            allFeedCareLogs: allFeedCareLogs,
            now: now
        )
        let willWriteFeedLog = (dashboard.operatingMode == .manual && pet.dailyPortionGrams > 0) ||
            (dashboard.operatingMode == .manualReminder && dashboard.nextManualReminder != nil)

        if willWriteFeedLog,
           let warning = AntiRepeatCareManager.checkRecentCareLog(
               for: pet,
               type: .feeding,
               thresholdMinutes: 120,
               currentUserId: executorId,
               in: humans
           ) {
            showAntiRepeat(antiRepeatTitle, antiRepeatMessage(warning), performFeed)
        } else {
            performFeed()
        }
    }

    static func performWaterCheckIn(
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        modelContext: ModelContext,
        now: Date,
        openWaterManagement: (Pet) -> Void,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) {
        guard !WaterQuickActionPolicy.isAquatic(species: pet.species) else {
            openWaterManagement(pet)
            return
        }

        let state = ExpandedQuickActionLogic.waterRuleState(for: pet, allEvents: allEvents)
        if state.operatingMode == .reminder {
            if let reminder = state.nextPendingReminder {
                let reward = careEvents.completePlannedWater(
                    pet: pet,
                    reminder: reminder,
                    amountMl: ExpandedQuickActionLogic.defaultWaterAmountMl(for: pet) ?? 0,
                    context: modelContext,
                    executorId: executorId
                )
                let delta = (reward?.humanGot ?? 0) + (reward?.petGot ?? 0)
                feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "喂水 +\(delta)🥥" : nil))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return
            }
            openWaterManagement(pet)
            return
        }

        let got = careEvents.recordCare(
            pet: pet,
            type: .watering,
            amountMl: ExpandedQuickActionLogic.defaultWaterAmountMl(for: pet) ?? 0,
            context: modelContext,
            executorId: executorId,
            reward: .water,
            quality: .none,
            date: now
        )
        let delta = got.humanGot + got.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "喂水 +\(delta)🥥" : nil))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func performMedicationCheckIn(
        pet: Pet,
        allEvents: [Event],
        modelContext: ModelContext,
        openMedication: (Pet) -> Void,
        feedback: (Feedback) -> Void,
        questManager: QuestManager,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) {
        let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
        let activeMeds = pet.medications.filter(\.isActiveToday)
        guard !activeMeds.isEmpty else {
            openMedication(pet)
            return
        }

        let targetMedication = activeMeds.first { medication in
            let required = PetMedicationDoseLogging.requiredDoses(on: Date(), for: medication)
            guard required > 0 else { return false }
            let done = PetMedicationDoseLogging.todayDoseCount(events: allEvents, medicationId: medication.id)
            return done < required
        } ?? activeMeds.first(where: { PetMedicationDoseLogging.requiredDoses(on: Date(), for: $0) == 0 })

        guard let medication = targetMedication else {
            openMedication(pet)
            return
        }

        PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: modelContext,
            awardCoconut: true,
            questManager: questManager,
            medicationReminders: medicationReminders
        )
        medicationReminders.scheduleMedicationReminders(for: pet, context: modelContext)
        feedback(Feedback(cardId: pet.id, coconutDelta: 1, label: "用药 +1🥥"))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func performActionType(
        _ actionType: String,
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        humans: [Human],
        modelContext: ModelContext,
        now: Date,
        antiRepeatTitle: String,
        antiRepeatMessage: @escaping ((executorName: String, minutesAgo: Int)) -> String,
        openFeedDetail: @escaping (_ opensManualSheet: Bool) -> Void,
        completePlannedFeed: @escaping (Pet) -> Bool,
        showAntiRepeat: @escaping (_ title: String, _ message: String, _ pendingAction: @escaping () -> Void) -> Void,
        startWalk: (Pet) -> Void,
        openWaterManagement: (Pet) -> Void,
        openMedication: (Pet) -> Void,
        feedback: @escaping (Feedback) -> Void,
        careEvents: CareEventRecording,
        questManager: QuestManager,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) {
        let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
        switch actionType {
        case "feed":
            performFeedCheckIn(
                pet: pet,
                executorId: executorId,
                allEvents: allEvents,
                allFeedCareLogs: allFeedCareLogs,
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
            performWaterCheckIn(
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "litter":
            let got = careEvents.recordCare(
                pet: pet,
                type: .litter,
                amountMl: 0,
                context: modelContext,
                executorId: executorId,
                reward: .potty(isLitter: true),
                quality: .none,
                date: now
            )
            let delta = got.humanGot + got.petGot
            feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "铲屎 +\(delta)🥥" : nil))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "play":
            performSpecialCare(.play, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "medication":
            performMedicationCheckIn(
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
        case "cageCleaning":
            performSpecialCare(.cageCleaning, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "freeFlight":
            performSpecialCare(.freeFlight, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "misting":
            performSpecialCare(.misting, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "substrateChange":
            performSpecialCare(.substrateChange, pet: pet, executorId: executorId, modelContext: modelContext, feedback: feedback, careEvents: careEvents)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        default:
            break
        }
    }

    static func applyGroomCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        modelContext: ModelContext,
        showSingleUseNotice: (String, String) -> Void,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) {
        let type: HygieneType
        switch raw {
        case "bath": type = .bath
        case "teeth": type = .teeth
        case "nails": type = .nails
        case "brushing": type = .brushing
        case "ears": type = .ears
        default: return
        }

        guard !pet.hygieneLogs.contains(where: { $0.type == type.rawValue && Calendar.current.isDateInToday($0.date) }) else {
            showSingleUseNotice("今天已经完成了", "\(pet.name) 今天已经记录过\(type.rawValue)了，这类护理一天记录一次就够了。")
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        let got = careEvents.recordHygiene(
            pet: pet,
            type: type,
            context: modelContext,
            executorId: executorId,
            date: Date()
        )
        let delta = got.humanGot + got.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        let got = careEvents.recordPotty(pet: pet, type: type, context: modelContext, executorId: executorId, date: Date())
        let delta = got.humanGot + got.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    static func applyHealthCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        modelContext: ModelContext,
        openHealth: (Pet) -> Void,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) {
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
            return
        }
        let reward = careEvents.recordHealth(
            pet: pet,
            type: type,
            note: "快捷打卡",
            context: modelContext,
            executorId: executorId,
            date: Date()
        )
        let delta = reward.humanGot + reward.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "💉 +\(delta)🥥" : nil))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func performSpecialCare(
        _ type: CareType,
        pet: Pet,
        executorId: String?,
        modelContext: ModelContext,
        feedback: (Feedback) -> Void,
        careEvents: CareEventRecording
    ) {
        let reward: QuestManager.OhanaActionType = switch type {
        case .play:
            .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 互动奖励")
        case .filterClean:
            .general(humanReward: 25, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        case .cageCleaning:
            .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理鸟笼奖励")
        case .freeFlight:
            .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 放飞互动奖励")
        case .misting:
            .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 保湿打卡奖励")
        case .substrateChange:
            .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 环境清洁奖励")
        default:
            .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 打卡奖励")
        }
        let got = careEvents.recordCare(pet: pet, type: type, amountMl: 0, context: modelContext, executorId: executorId, reward: reward, quality: .none, date: Date())
        let delta = got.humanGot + got.petGot
        feedback(Feedback(cardId: pet.id, coconutDelta: delta, label: delta > 0 ? "\(type.emoji) +\(delta)🥥" : nil))
    }
}
