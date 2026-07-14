//
//  SharedCareDeferredFinalization.swift
//  Ohana
//
//  Focused staging and settlement helpers for the shared-care undo window.
//

import Foundation
import SwiftData

@MainActor
enum SharedCareDeferredReceiptFactory {
    static func insertReceipt(
        request: SharedCareDeferredFinalizationRequest,
        descriptor: SharedPetActionDescriptor,
        session: SharedCareSession,
        sessionTargets: [Pet],
        writtenTargets: [Pet],
        executorID: String?,
        context: ModelContext
    ) -> SharedCareUndoReceipt {
        let occurrences: [SharedCareUndoReminderOccurrence] = if let careType = descriptor.reminderCareType {
            writtenTargets.compactMap { target in
                QuickActionReminderCompletionSyncService.nearestPetCareReminderOccurrence(
                    pet: target,
                    type: careType,
                    context: context,
                    now: descriptor.date
                )
            }
        } else {
            []
        }
        let receipt = SharedCareUndoReceipt(
            sharedSessionId: session.id,
            sourcePetId: descriptor.sourcePet.id,
            targetPetIds: sessionTargets.map(\.id),
            executorId: executorID,
            actionKind: descriptor.actionKind,
            occurredAt: descriptor.date,
            undoDeadline: request.undoDeadline,
            reminderOccurrences: occurrences,
            corePayloadJSON: request.corePayloadJSON,
            externalEffectsPayloadJSON: request.externalEffectsPayloadJSON
        )
        context.insert(receipt)
        return receipt
    }

    static func pendingResult(
        receipt: SharedCareUndoReceipt,
        session: SharedCareSession,
        sessionTargets: [Pet],
        facts: SharedPetRecordedFacts
    ) -> SharedPetActionResult {
        SharedPetActionResult(
            sessionID: session.id,
            targetPetIDs: sessionTargets.map(\.id),
            careLogIDs: facts.careLogs.map(\.1.id),
            pottyLogIDs: facts.pottyLogs.map(\.1.id),
            pottyLogID: facts.pottyLog?.id,
            pottyLog: facts.pottyLog,
            hygieneLogIDs: facts.hygieneLogs.map(\.1.id),
            expenseLogIDs: facts.expenseLogs.map(\.1.id),
            walkLogIDs: facts.walkLogs.map(\.1.id),
            walkLogs: facts.walkLogs.map(\.1),
            reward: (0, 0),
            disposition: .active,
            undoReceiptID: receipt.id,
            undoDeadline: receipt.undoDeadline
        )
    }
}

@MainActor
enum SharedLitterDeferredFinalizer {
    private struct EconomyRewardTrace {
        let walletEntryIDs: [UUID]
        let budgetUsageIDs: [UUID]

        static let empty = EconomyRewardTrace(walletEntryIDs: [], budgetUsageIDs: [])
    }

    private struct RewardOutcome {
        let reward: (humanGot: Int, petGot: Int)
        let trace: EconomyRewardTrace
    }

    private struct Inputs {
        let session: SharedCareSession
        let careLogs: [PetCareLog]
        let targets: [Pet]
        let descriptor: SharedPetActionDescriptor
        let pairs: [(Pet, PetCareLog)]
    }

    static func finalize(
        receipt: SharedCareUndoReceipt,
        context: ModelContext,
        dependencies providedDependencies: CareEventServiceDependencies?
    ) throws -> SharedPetActionResult {
        guard receipt.actionKind == .litterScoop else {
            throw SharedCareDeferredFinalizationError.unsupportedAction
        }
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
        let inputs = try loadInputs(receipt: receipt, context: context)
        let existingLedgers = existingLedgers(inputs: inputs, context: context)
        let existingLogIDs = Set(existingLedgers.compactMap(\.legacyModelId))
        let rewardOutcome = try settleReward(
            receipt: receipt,
            inputs: inputs,
            existingLedgers: existingLedgers,
            context: context,
            dependencies: dependencies
        )
        recordMissingLedgers(
            receipt: receipt,
            inputs: inputs,
            existingLedgers: existingLedgers,
            existingLogIDs: existingLogIDs,
            rewardOutcome: rewardOutcome,
            context: context,
            dependencies: dependencies
        )
        try completeFrozenReminders(receipt: receipt, context: context, dependencies: dependencies)
        SharedCareRevisionDeriver.derive(
            SharedPetActionRevisionInput(
                descriptor: inputs.descriptor,
                session: inputs.session,
                targets: inputs.targets,
                careLogs: inputs.careLogs,
                pottyLogs: [],
                pottyLog: nil,
                hygieneLogs: [],
                expenseLogs: [],
                walkLogs: [],
                reward: rewardOutcome.reward
            ),
            derivations: CareDerivationExecutor(revisions: dependencies.revisions)
        )
        return result(receipt: receipt, inputs: inputs, reward: rewardOutcome.reward)
    }

    private static func loadInputs(
        receipt: SharedCareUndoReceipt,
        context: ModelContext
    ) throws -> Inputs {
        let sessionID = receipt.sharedSessionId
        var sessionDescriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { $0.id == sessionID }
        )
        sessionDescriptor.fetchLimit = 1
        guard let session = try context.fetch(sessionDescriptor).first else {
            throw SharedCareDeferredFinalizationError.missingSession
        }
        let careLogs = SharedCareSessionMaintenance.fetchCareLogs(
            sessionID: session.id.uuidString,
            context: context
        )
        let targetIDs = Set(receipt.targetPetIds)
        guard let fallbackTarget = careLogs.compactMap(\.pet).first else {
            throw SharedCareDeferredFinalizationError.missingTargets
        }
        let targets = SharedPetTargetResolver.normalizedTargets(
            careLogs.compactMap(\.pet).filter { targetIDs.contains($0.id) },
            fallback: fallbackTarget
        )
        guard targets.count == targetIDs.count,
              let sourcePet = targets.first(where: { $0.id == receipt.sourcePetId }) else {
            throw SharedCareDeferredFinalizationError.missingTargets
        }
        let pairs = careLogs.compactMap { log -> (Pet, PetCareLog)? in
            guard let pet = log.pet, targetIDs.contains(pet.id) else { return nil }
            return (pet, log)
        }
        guard pairs.count == targetIDs.count else {
            throw SharedCareDeferredFinalizationError.missingTargets
        }
        return Inputs(
            session: session,
            careLogs: careLogs,
            targets: targets,
            descriptor: descriptor(receipt: receipt, sourcePet: sourcePet, targets: targets),
            pairs: pairs
        )
    }

    private static func descriptor(
        receipt: SharedCareUndoReceipt,
        sourcePet: Pet,
        targets: [Pet]
    ) -> SharedPetActionDescriptor {
        SharedPetActionDescriptor(
            actionKind: .litterScoop,
            sourcePet: sourcePet,
            targets: targets,
            date: receipt.occurredAt,
            executorId: receipt.executorId,
            childLogStrategy: .care(type: .litter),
            reward: .potty(isLitter: true),
            rewardTitle: L10n.current.tr(
                zh: "共同铲砂",
                en: "Shared litter scoop",
                de: "Gemeinsames Katzenklo-Reinigen"
            ),
            reminderCareType: .litter
        )
    }

    private static func existingLedgers(
        inputs: Inputs,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        SharedCareSessionMaintenance.ledgerEvents(
            careLogs: inputs.careLogs,
            pottyLogs: [],
            hygieneLogs: [],
            expenseLogs: [],
            walkLogs: [],
            context: context
        )
    }

    private static func settleReward(
        receipt: SharedCareUndoReceipt,
        inputs: Inputs,
        existingLedgers: [CareLedgerEvent],
        context: ModelContext,
        dependencies: CareEventServiceDependencies
    ) throws -> RewardOutcome {
        guard existingLedgers.isEmpty else {
            return RewardOutcome(reward: (0, 0), trace: .empty)
        }
        let idempotencyKey = "sharedCareFinalize:\(inputs.session.id.uuidString)"
        let reward = dependencies.economy.awardDeferredSharedCareAction(
            type: .potty(isLitter: true),
            pets: inputs.targets,
            context: context,
            quality: .none,
            title: inputs.descriptor.rewardTitle,
            executorId: receipt.executorId,
            date: receipt.occurredAt,
            idempotencyKey: idempotencyKey
        )
        guard rewardWasPersisted(idempotencyKey: idempotencyKey, context: context) else {
            throw SharedCareDeferredFinalizationError.rewardPersistenceFailed
        }
        return RewardOutcome(
            reward: reward,
            trace: rewardTrace(
                idempotencyKey: idempotencyKey,
                metadataJSON: dependencies.economy.rewardMetadata(for: reward),
                occurredAt: receipt.occurredAt,
                expectedTargetCount: inputs.targets.count,
                context: context
            )
        )
    }

    private static func recordMissingLedgers(
        receipt: SharedCareUndoReceipt,
        inputs: Inputs,
        existingLedgers: [CareLedgerEvent],
        existingLogIDs: Set<String>,
        rewardOutcome: RewardOutcome,
        context: ModelContext,
        dependencies: CareEventServiceDependencies
    ) {
        let firstMissingLogID = inputs.pairs.first {
            !existingLogIDs.contains($0.1.id.uuidString)
        }?.1.id
        for pair in inputs.pairs where !existingLogIDs.contains(pair.1.id.uuidString) {
            let isPrimary = pair.1.id == firstMissingLogID && existingLedgers.isEmpty
            dependencies.careLedger.recordPetCare(
                log: pair.1,
                pet: pair.0,
                source: .quickAction,
                sourceEventId: nil,
                sourceReminderId: nil,
                coconutDelta: isPrimary ? dependencies.careLedger.rewardDelta(rewardOutcome.reward) : 0,
                metadataJSON: isPrimary
                    ? rewardMetadata(
                        rewardOutcome,
                        sessionID: inputs.session.id,
                        targetCount: inputs.targets.count,
                        executorIds: receipt.executorId.map { [$0] } ?? [],
                        economy: dependencies.economy
                    )
                    : sharedMetadata(
                        sessionID: inputs.session.id,
                        targetCount: inputs.targets.count,
                        executorIds: receipt.executorId.map { [$0] } ?? []
                    ),
                context: context,
                save: true
            )
        }
    }

    private static func completeFrozenReminders(
        receipt: SharedCareUndoReceipt,
        context: ModelContext,
        dependencies: CareEventServiceDependencies
    ) throws {
        for occurrence in receipt.reminderOccurrences {
            let reminderID = occurrence.reminderId
            var descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { $0.id == reminderID }
            )
            descriptor.fetchLimit = 1
            guard let reminder = try context.fetch(descriptor).first else { continue }
            _ = dependencies.reminderCompletion.complete(
                reminder,
                by: receipt.executorId,
                occurrenceDate: occurrence.occurrenceAt,
                context: context
            )
        }
    }

    private static func result(
        receipt: SharedCareUndoReceipt,
        inputs: Inputs,
        reward: (humanGot: Int, petGot: Int)
    ) -> SharedPetActionResult {
        SharedPetActionResult(
            sessionID: inputs.session.id,
            targetPetIDs: inputs.targets.map(\.id),
            careLogIDs: inputs.careLogs.map(\.id),
            pottyLogID: nil,
            pottyLog: nil,
            expenseLogIDs: [],
            walkLogIDs: [],
            walkLogs: [],
            reward: reward,
            disposition: .active,
            undoReceiptID: receipt.id,
            undoDeadline: receipt.undoDeadline
        )
    }

    private static func rewardMetadata(
        _ outcome: RewardOutcome,
        sessionID: UUID,
        targetCount: Int,
        executorIds: [String],
        economy: CareEventEconomyAwarding
    ) -> String {
        let rewardJSON = economy.rewardMetadata(for: outcome.reward)
        var object = (try? JSONSerialization.jsonObject(with: Data(rewardJSON.utf8)) as? [String: Any]) ?? [:]
        object["sharedSessionId"] = sessionID.uuidString
        object["targets"] = targetCount
        object["walletEntryIds"] = outcome.trace.walletEntryIDs.map(\.uuidString)
        object["budgetUsageIds"] = outcome.trace.budgetUsageIDs.map(\.uuidString)
        if executorIds.count > 1 {
            object["executorIds"] = executorIds
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return sharedMetadata(sessionID: sessionID, targetCount: targetCount, executorIds: executorIds)
        }
        return json
    }

    private static func sharedMetadata(
        sessionID: UUID,
        targetCount: Int,
        executorIds: [String]
    ) -> String {
        var object: [String: Any] = [
            "sharedSessionId": sessionID.uuidString,
            "targets": targetCount
        ]
        if executorIds.count > 1 {
            object["executorIds"] = executorIds
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"sharedSessionId\":\"\(sessionID.uuidString)\",\"targets\":\(targetCount)}"
        }
        return json
    }

    private static func rewardTrace(
        idempotencyKey: String,
        metadataJSON: String,
        occurredAt: Date,
        expectedTargetCount: Int,
        context: ModelContext
    ) -> EconomyRewardTrace {
        let sourceModelName = "SharedCareFinalization"
        do {
            var walletDescriptor = FetchDescriptor<CoconutLedgerEntry>(
                predicate: #Predicate<CoconutLedgerEntry> {
                    $0.sourceModelName == sourceModelName && $0.sourceModelId == idempotencyKey
                },
                sortBy: [SortDescriptor(\.occurredAt)]
            )
            walletDescriptor.fetchLimit = max(4, expectedTargetCount + 2)
            var budgetDescriptor = FetchDescriptor<EconomyBudgetUsageEvent>(
                predicate: #Predicate<EconomyBudgetUsageEvent> {
                    $0.metadataJSON == metadataJSON && $0.occurredAt == occurredAt
                },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            budgetDescriptor.fetchLimit = max(4, expectedTargetCount + 3)
            return EconomyRewardTrace(
                walletEntryIDs: try context.fetch(walletDescriptor).map(\.id),
                budgetUsageIDs: try context.fetch(budgetDescriptor).map(\.id)
            )
        } catch {
            OhanaLog.warning(
                "SharedLitterDeferredFinalizer failed to capture economy trace: \(error.localizedDescription)",
                category: "Economy"
            )
            return .empty
        }
    }

    private static func rewardWasPersisted(
        idempotencyKey: String,
        context: ModelContext
    ) -> Bool {
        let sourceModelName = "SharedCareFinalization"
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> {
                $0.sourceModelName == sourceModelName && $0.sourceModelId == idempotencyKey
            }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor)) ?? []).isEmpty == false
    }
}
