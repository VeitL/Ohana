//
//  RainbowBridgeService.swift
//  Ohana
//
//  Pet lifecycle boundary for memorial mode.
//

import Foundation
import SwiftData

@MainActor
struct RainbowBridgeService {
    init() {}

    /// 标记宠物离世：只写生命周期事实；活跃退场由读取与命令边界负责。
    func markPassedAway(pet: Pet, date: Date = Date(), context: ModelContext) {
        pet.passedAwayDate = date
        CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: date)
    }

    /// 撤销离世标记（误操作恢复）
    func undoPassedAway(pet: Pet, context: ModelContext) {
        pet.passedAwayDate = nil
        CloudSyncMutationRecorder.markModified(pet, context: context)
    }
}

enum MemberLifecycleActiveScheduleNotifications {
    @MainActor
    static func futureNotificationIDs(for pet: Pet, passedAwayAt date: Date, context: ModelContext) -> [String] {
        futureNotificationIDs(context: context, passedAwayAt: date) { event in
            MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                event,
                petId: pet.id.uuidString,
                petMedications: pet.medications,
                insurances: pet.insurances
            )
        }
    }

    @MainActor
    static func futureNotificationIDs(for human: Human, passedAwayAt date: Date, context: ModelContext) -> [String] {
        let medications = fetchHumanMedications(humanKey: human.id.uuidString, context: context)
        return futureNotificationIDs(context: context, passedAwayAt: date) { event in
            MemberLifecycleActiveScheduleResolver.eventBelongsToHuman(
                event,
                humanId: human.id.uuidString,
                humanMedications: medications
            )
        }
    }

    @MainActor
    static func cancel(_ notificationIDs: [String]) {
        for notificationID in notificationIDs {
            OhanaNotifications.current.cancel(notificationId: notificationID)
        }
    }

    @MainActor
    private static func futureNotificationIDs(
        context: ModelContext,
        passedAwayAt date: Date,
        belongsToMember: (Event) -> Bool
    ) -> [String] {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let notificationIDs = events
            .filter {
                belongsToMember($0) &&
                    MemberLifecycleActiveScheduleResolver.isActiveSchedule($0, now: date)
            }
            .flatMap {
                MemberLifecycleActiveScheduleResolver.futureActionableReminders(in: $0, cutoff: date)
            }
            .map(\.notificationId)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(notificationIDs)).sorted()
    }

    @MainActor
    private static func fetchHumanMedications(humanKey: String, context: ModelContext) -> [HumanMedication] {
        let descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.humanId == humanKey
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
