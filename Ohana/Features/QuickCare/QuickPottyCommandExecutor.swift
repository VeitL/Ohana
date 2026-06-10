//
//  QuickPottyCommandExecutor.swift
//  Ohana
//
//  Write-side boundary for the compact potty check-in sheet.
//

import Foundation
import SwiftData

struct QuickPottyCommandResult: Equatable {
    let petID: UUID
    let careLogID: UUID?
    let pottyLogID: UUID?
    let coconutDelta: Int
    let action: String
    let targetCount: Int
}

@MainActor
struct QuickPottyCommandExecutor {
    private let context: ModelContext
    private let careEvents: CareEventRecording
    private let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(
            context: context,
            careEvents: CareEventService(),
            revisions: SharedDomainRevisionPublisher()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            careEvents: CareEventService(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter)
        )
    }

    init(
        context: ModelContext,
        careEvents: CareEventRecording,
        revisions: DomainRevisionPublishing
    ) {
        self.context = context
        self.careEvents = careEvents
        self.revisions = revisions
    }

    func record(
        petID: UUID,
        selectedType: PottyType,
        isLitter: Bool,
        executorId: String?,
        date: Date
    ) -> QuickPottyCommandResult? {
        let action = isLitter ? CareType.litter.rawValue : selectedType.rawValue
        guard let pet = fetchPet(id: petID), !pet.hasPassedAway else {
            revisions.publish(
                DomainMutationResult(
                    command: .quickCare(entityID: petID, action: action),
                    affectedEntityIDs: [petID],
                    wroteBusinessFact: false,
                    note: "quickPotty.missingPet"
                )
            )
            return nil
        }

        if isLitter {
            let recorded = careEvents.recordCareFact(
                pet: pet,
                type: .litter,
                amountMl: 0,
                context: context,
                executorId: executorId,
                reward: .potty(isLitter: true),
                quality: .none,
                date: date,
                source: .quickAction,
                createsLinkedPottyLog: false
            )
            publish(petID: pet.id, action: action, affectedIDs: [pet.id, recorded.result.logID], note: "quickPotty.litter")
            return QuickPottyCommandResult(
                petID: pet.id,
                careLogID: recorded.result.logID,
                pottyLogID: nil,
                coconutDelta: recorded.result.coconutDelta,
                action: action,
                targetCount: 1
            )
        }

        let reward = careEvents.recordPotty(
            pet: pet,
            type: selectedType,
            context: context,
            executorId: executorId,
            date: date
        )
        let logID = latestPottyLogID(petID: pet.id, type: selectedType, date: date)
        var affectedIDs: Set<UUID> = [pet.id]
        if let logID {
            affectedIDs.insert(logID)
        }
        publish(
            petID: pet.id,
            action: action,
            affectedIDs: affectedIDs,
            note: "quickPotty.record"
        )
        return QuickPottyCommandResult(
            petID: pet.id,
            careLogID: nil,
            pottyLogID: logID,
            coconutDelta: reward.humanGot + reward.petGot,
            action: action,
            targetCount: 1
        )
    }

    func recordUnknownSharedPotty(
        sourcePetID: UUID,
        targetIDs: Set<UUID>,
        type: PottyType,
        executorId: String?,
        date: Date
    ) -> QuickPottyCommandResult? {
        guard let sourcePet = fetchPet(id: sourcePetID), !sourcePet.hasPassedAway else {
            publishNoop(petID: sourcePetID, action: "unknownSharedPotty", note: "quickPotty.unknown.missingPet")
            return nil
        }
        let targets = fetchTargets(sourcePet: sourcePet, targetIDs: targetIDs)
        let log = careEvents.recordUnknownSharedPotty(
            sourcePet: sourcePet,
            targets: targets,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        )
        publish(
            petID: sourcePet.id,
            action: "unknownSharedPotty",
            affectedIDs: Set(targets.map(\.id)).union([sourcePet.id, log.id]),
            note: "quickPotty.unknownShared"
        )
        return QuickPottyCommandResult(
            petID: sourcePet.id,
            careLogID: nil,
            pottyLogID: log.id,
            coconutDelta: 0,
            action: "unknownSharedPotty",
            targetCount: targets.count
        )
    }

    func recordLitterCare(
        sourcePetID: UUID,
        targetIDs: Set<UUID>,
        executorId: String?,
        date: Date,
        isFullChange: Bool
    ) -> QuickPottyCommandResult? {
        guard let sourcePet = fetchPet(id: sourcePetID), !sourcePet.hasPassedAway else {
            publishNoop(petID: sourcePetID, action: isFullChange ? "litterFullChange" : "litterScoop", note: "quickPotty.litter.missingPet")
            return nil
        }
        let targets = fetchTargets(sourcePet: sourcePet, targetIDs: targetIDs)
        let reward: (humanGot: Int, petGot: Int)
        let careLogID: UUID?
        if targets.count > 1 {
            reward = careEvents.recordSharedLitterCare(
                sourcePet: sourcePet,
                targets: targets,
                context: context,
                executorId: executorId,
                date: date,
                isFullChange: isFullChange
            )
            careLogID = nil
        } else {
            let recorded = careEvents.recordCareFact(
                pet: sourcePet,
                type: .litter,
                amountMl: 0,
                context: context,
                executorId: executorId,
                reward: .potty(isLitter: true),
                quality: .none,
                date: date,
                source: .quickAction,
                createsLinkedPottyLog: false
            )
            reward = recorded.reward
            careLogID = recorded.result.logID
        }

        let action = isFullChange ? "litterFullChange" : "litterScoop"
        var affectedIDs = Set(targets.map(\.id))
        affectedIDs.insert(sourcePet.id)
        if let careLogID {
            affectedIDs.insert(careLogID)
        }
        publish(
            petID: sourcePet.id,
            action: action,
            affectedIDs: affectedIDs,
            note: isFullChange ? "quickPotty.litterFullChange" : "quickPotty.litterScoop"
        )
        return QuickPottyCommandResult(
            petID: sourcePet.id,
            careLogID: careLogID,
            pottyLogID: nil,
            coconutDelta: reward.humanGot + reward.petGot,
            action: action,
            targetCount: targets.count
        )
    }

    private func fetchPet(id: UUID) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchTargets(sourcePet: Pet, targetIDs: Set<UUID>) -> [Pet] {
        let ids = targetIDs.isEmpty ? [sourcePet.id] : Array(targetIDs)
        let targets = ids.compactMap { fetchPet(id: $0) }
            .filter { !$0.hasPassedAway }
        return targets.isEmpty ? [sourcePet] : targets
    }

    private func latestPottyLogID(petID: UUID, type: PottyType, date: Date) -> UUID? {
        var descriptor = FetchDescriptor<PetPottyLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 12
        return (try? context.fetch(descriptor))?
            .first { log in
                log.pet?.id == petID &&
                    log.pottyType == type &&
                    abs(log.date.timeIntervalSince(date)) < 0.001
            }?
            .id
    }

    private func publish(petID: UUID, action: String, affectedIDs: Set<UUID>, note: String) {
        revisions.publish(
            DomainMutationResult(
                command: .quickCare(entityID: petID, action: action),
                affectedEntityIDs: affectedIDs,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    private func publishNoop(petID: UUID, action: String, note: String) {
        revisions.publish(
            DomainMutationResult(
                command: .quickCare(entityID: petID, action: action),
                affectedEntityIDs: [petID],
                wroteBusinessFact: false,
                note: note
            )
        )
    }
}
