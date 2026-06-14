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
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        date: Date,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func awardSharedCareAction(
        type: QuestManager.OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        title: String?,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)
}

@MainActor
struct CareEventServiceDependencies {
    let questManager: QuestManager
    let economy: CareEventEconomyAwarding
    let careLedger: CareLedgerRecording
    let reminderCompletion: ReminderCompleting
    let quickActionReminderCompletion: QuickActionReminderCompleting
    let familyTasks: FamilyTaskManaging
    let revisions: DomainRevisionPublishing

    static func live() -> CareEventServiceDependencies {
        let wallet = SwiftDataCoconutWalletManager()
        let revisions = SharedDomainRevisionPublisher()
        let questManager = QuestManager(wallet: wallet, revisions: revisions)
        let careLedger = CareLedgerService()
        let familyTasks = StaticFamilyTaskManager(wallet: wallet, careLedger: careLedger, questManager: questManager)
        let reminderCompletion = ReminderCompletionService(careLedger: careLedger, familyTasks: familyTasks)
        return CareEventServiceDependencies(
            questManager: questManager,
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            careLedger: careLedger,
            reminderCompletion: reminderCompletion,
            quickActionReminderCompletion: QuickActionReminderCompletionSyncService(reminderCompletion: reminderCompletion),
            familyTasks: familyTasks,
            revisions: revisions
        )
    }
}

enum CareFactWriteDisposition: Equatable {
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
        context _: ModelContext
    ) -> CareFactWriteDisposition {
        guard EconomyWalletWritePolicy.canWrite(pet) else { return .noOp }
        return .active
    }

    static func plannedFactDate(scheduledAt: Date, operationDate: Date) -> Date {
        scheduledAt < operationDate ? scheduledAt : operationDate
    }
}

@MainActor
final class CareEventService: CareEventRecording {
    let dependencies: CareEventServiceDependencies

    convenience init() {
        self.init(dependencies: .live())
    }

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
