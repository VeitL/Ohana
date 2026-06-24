//
//  CareEventService.swift
//  Ohana
//
//  Centralized care/reminder/economy write paths.
//

import Foundation
import SwiftData

@MainActor
protocol CareEventEconomyAwarding {
    @discardableResult
    func awardCareAction(
        type: DomainCareRewardAction,
        pet: Pet?,
        context: ModelContext,
        quality: DomainCareRewardQuality,
        date: Date,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func awardSharedCareAction(
        type: DomainCareRewardAction,
        pets: [Pet],
        context: ModelContext,
        quality: DomainCareRewardQuality,
        title: String?,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)

    func rewardMetadata(for reward: (humanGot: Int, petGot: Int)?) -> String
    func recordFirstMeal(actorId: String?, context: ModelContext)
    func clearCooldown(petId: UUID?, type: DomainCareRewardAction)
    func refreshProjectionAfterRollback(context: ModelContext)
}

@MainActor
struct CareEventServiceDependencies {
    let economy: CareEventEconomyAwarding
    let careLedger: CareLedgerRecording
    let reminderCompletion: ReminderCompleting
    let quickActionReminderCompletion: QuickActionReminderCompleting
    let familyTasks: FamilyTaskManaging
    let revisions: DomainRevisionPublishing
    let notifications: ReminderNotificationScheduling

    init(
        economy: CareEventEconomyAwarding,
        careLedger: CareLedgerRecording,
        reminderCompletion: ReminderCompleting,
        quickActionReminderCompletion: QuickActionReminderCompleting,
        familyTasks: FamilyTaskManaging,
        revisions: DomainRevisionPublishing,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) {
        self.economy = economy
        self.careLedger = careLedger
        self.reminderCompletion = reminderCompletion
        self.quickActionReminderCompletion = quickActionReminderCompletion
        self.familyTasks = familyTasks
        self.revisions = revisions
        self.notifications = notifications
    }
}

nonisolated enum CareFactWriteDisposition: Equatable {
    case active
    case noOp

    var didWriteFact: Bool {
        self == .active
    }

    var writesFact: Bool {
        didWriteFact
    }

    var allowsDerivedEffects: Bool {
        self == .active
    }
}

struct PlannedCareCompletionResult {
    let logID: UUID?
    let subjectID: UUID?
    let factDate: Date?
    let operationDate: Date
    let reward: (humanGot: Int, petGot: Int)
    let disposition: CareFactWriteDisposition

    var didRecord: Bool {
        disposition.didWriteFact && logID != nil
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }

    var coconutDelta: Int {
        max(0, reward.humanGot) + max(0, reward.petGot)
    }

    static func noOp(operationDate: Date) -> PlannedCareCompletionResult {
        PlannedCareCompletionResult(
            logID: nil,
            subjectID: nil,
            factDate: nil,
            operationDate: operationDate,
            reward: (0, 0),
            disposition: .noOp
        )
    }
}

enum CareFactWritePolicy {
    @MainActor
    static func disposition(
        pet: Pet,
        date _: Date,
        executorId _: String?,
        context: ModelContext
    ) -> CareFactWriteDisposition {
        authorizePetCareFact(pet: pet, context: context)?.allowsCareFactWrite == true ? .active : .noOp
    }

    @MainActor
    static func authorizePetCareFact(
        pet: Pet,
        context: ModelContext
    ) -> AuthorizedMutationPlan? {
        DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .careFact,
                source: .domainService,
                subjectRequest: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: pet.id.uuidString
                ),
                writeKind: .care
            ),
            context: context
        )
    }

    @MainActor
    static func executorResolution(
        requestedExecutorId: String?,
        context: ModelContext,
        logPrefix: String
    ) -> EconomyRewardOwnerResolution {
        EconomyRewardOwnerResolver.executorResolution(
            executorId: requestedExecutorId,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            context: context,
            logPrefix: logPrefix
        )
    }

    static func plannedFactDate(scheduledAt: Date, operationDate: Date) -> Date {
        scheduledAt < operationDate ? scheduledAt : operationDate
    }
}

@MainActor
final class CareEventService: CareEventRecording {
    let dependencies: CareEventServiceDependencies

    init(dependencies: CareEventServiceDependencies) {
        self.dependencies = dependencies
    }

    struct CareRecordResult: Equatable {
        let logID: UUID
        let subjectID: UUID
        let careType: CareType
        let linkedPottyLogID: UUID?
        let coconutDelta: Int
        let disposition: CareFactWriteDisposition

        init(
            logID: UUID,
            subjectID: UUID,
            careType: CareType,
            linkedPottyLogID: UUID?,
            coconutDelta: Int,
            disposition: CareFactWriteDisposition = .active
        ) {
            self.logID = logID
            self.subjectID = subjectID
            self.careType = careType
            self.linkedPottyLogID = linkedPottyLogID
            self.coconutDelta = coconutDelta
            self.disposition = disposition
        }

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
    }

    struct PottyRecordResult: Equatable {
        let logID: UUID?
        let subjectID: UUID
        let pottyType: PottyType
        let coconutDelta: Int
        let disposition: CareFactWriteDisposition

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
    }

    struct HealthRecordResult: Equatable {
        let logID: UUID?
        let subjectID: UUID
        let healthType: HealthLogType
        let coconutDelta: Int
        let disposition: CareFactWriteDisposition

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
    }

    struct TreatFeedRecordResult: Equatable {
        let logID: UUID
        let subjectID: UUID
        let grams: Double
        let disposition: CareFactWriteDisposition

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
    }
}
