//
//  FeedCommands.swift
//  Ohana
//
//  Write-side commands for feeding flows.
//

import Foundation
import SwiftData

struct ManualFeedCommandResult {
    let foodKind: FeedFoodKind
    let grams: Double
    let targetCount: Int
    let affectsStock: Bool
    let stockReminders: [Reminder]
    let didRecord: Bool
    let allowsDerivedEffects: Bool
    let coconutDelta: Int
    let didPersist: Bool
    let persistenceErrorDescription: String?
    var recordReference: PetRecordReference? = nil
}

enum ManualFeedCommand {
    @discardableResult
    @MainActor
    static func saveSettings(
        pet: Pet,
        foodKind: FeedFoodKind,
        grams: Double,
        defaultEnabled: Bool = true,
        context: ModelContext
    ) -> Bool {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return false
        }
        guard pet.mainFoodKind != foodKind ||
            pet.dailyPortionGrams != (defaultEnabled ? grams : 0)
        else { return false }
        pet.mainFoodKind = foodKind
        pet.dailyPortionGrams = defaultEnabled ? grams : 0
        CloudSyncMutationRecorder.markModified(pet, context: context)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        if !saveResult.didSave { context.rollback() }
        return saveResult.didSave
    }

    @MainActor
    static func recordManual(
        pet: Pet,
        targets: [Pet],
        grams: Double,
        foodKind: FeedFoodKind,
        saveAsDefault: Bool,
        foodRecords: [PetFoodRecord],
        allEvents: [Event],
        context: ModelContext,
        executorId: String?,
        careEvents: CareEventRecording? = nil,
        date: Date = Date(),
        note: String = ""
    ) -> ManualFeedCommandResult {
        let careEvents = careEvents ?? CareEventService()

        let quality = QuestManager.QualityBonus.compose(precise: true, hasNote: !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, hasPhoto: false)
        let normalizedTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        let previousFoodKind = pet.mainFoodKind
        let previousPortion = pet.dailyPortionGrams
        let savesDefault = saveAsDefault && MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects
        if savesDefault {
            pet.mainFoodKind = foodKind
            pet.dailyPortionGrams = grams
            CloudSyncMutationRecorder.markModified(pet, context: context)
        }
        // The fact's first commit also commits an explicitly chosen default.
        // A failed/no-op fact restores the default and never asks for another record.
        let recorded = if normalizedTargets.count > 1 {
            careEvents.recordSharedManualFeedFact(
                sourcePet: pet,
                targets: normalizedTargets,
                totalGrams: grams,
                foodKind: foodKind,
                context: context,
                executorId: executorId,
                quality: quality,
                date: date,
                note: note
            )
        } else {
            singleCareResult(careEvents.recordManualFeedFact(
                pet: pet,
                amountGrams: grams,
                context: context,
                executorId: executorId,
                quality: quality,
                date: date,
                foodKind: foodKind,
                source: .quickAction,
                note: note
            ))
        }

        guard recorded.didPersist else {
            if savesDefault { pet.mainFoodKind = previousFoodKind; pet.dailyPortionGrams = previousPortion }
            return ManualFeedCommandResult(
                foodKind: foodKind,
                grams: grams,
                targetCount: 0,
                affectsStock: false,
                stockReminders: [],
                didRecord: false,
                allowsDerivedEffects: false,
                coconutDelta: 0,
                didPersist: false,
                persistenceErrorDescription: recorded.persistenceErrorDescription
            )
        }
        guard recorded.didWriteFact else {
            if savesDefault { pet.mainFoodKind = previousFoodKind; pet.dailyPortionGrams = previousPortion }
            return ManualFeedCommandResult(
                foodKind: foodKind,
                grams: grams,
                targetCount: 0,
                affectsStock: false,
                stockReminders: [],
                didRecord: false,
                allowsDerivedEffects: false,
                coconutDelta: 0,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        let allowsDerivedEffects = recorded.allowsDerivedEffects
        let stockReminders = allowsDerivedEffects
            ? FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context,
                now: date
            )
            : []

        return ManualFeedCommandResult(
            foodKind: foodKind,
            grams: grams,
            targetCount: recorded.targetPetIDs.count,
            affectsStock: allowsDerivedEffects &&
                FeedStockCalculator.activeStockRecord(for: pet, foodKind: foodKind, foodRecords: foodRecords, now: date) != nil,
            stockReminders: stockReminders,
            didRecord: true,
            allowsDerivedEffects: allowsDerivedEffects,
            coconutDelta: recorded.reward.humanGot + recorded.reward.petGot,
            didPersist: true,
            persistenceErrorDescription: nil,
            recordReference: recorded.recordReference(for: pet.id, ids: recorded.careLogIDs)
        )
    }

    @MainActor
    static func completePlanned(
        pet: Pet,
        reminder: Reminder,
        foodRecords: [PetFoodRecord],
        allEvents: [Event],
        context: ModelContext,
        executorId: String?,
        careEvents: CareEventRecording? = nil,
        date: Date = Date()
    ) -> ManualFeedCommandResult {
        let careEvents = careEvents ?? CareEventService()
        let event = reminder.event
        let foodKind = event?.foodKind ?? pet.mainFoodKind
        let grams = event.map { FeedRuleMetadata.amountGrams(from: $0, fallback: pet.dailyPortionGrams) } ?? pet.dailyPortionGrams
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsCareFactWrite else {
            return ManualFeedCommandResult(
                foodKind: foodKind,
                grams: grams,
                targetCount: 0,
                affectsStock: false,
                stockReminders: [],
                didRecord: false,
                allowsDerivedEffects: false,
                coconutDelta: 0,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let completed = careEvents.completePlannedFeedResult(
            pet: pet,
            reminder: reminder,
            context: context,
            quality: .precise,
            executorId: executorId,
            occurredAt: nil,
            operationDate: date
        )
        guard completed.didPersist else {
            return ManualFeedCommandResult(
                foodKind: foodKind,
                grams: grams,
                targetCount: 0,
                affectsStock: false,
                stockReminders: [],
                didRecord: false,
                allowsDerivedEffects: false,
                coconutDelta: 0,
                didPersist: false,
                persistenceErrorDescription: completed.persistenceErrorDescription
            )
        }
        guard completed.didRecord else {
            return ManualFeedCommandResult(
                foodKind: foodKind,
                grams: grams,
                targetCount: 0,
                affectsStock: false,
                stockReminders: [],
                didRecord: false,
                allowsDerivedEffects: false,
                coconutDelta: 0,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let stockReminders = completed.allowsDerivedEffects
            ? FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context,
                now: date
            )
            : []
        return ManualFeedCommandResult(
            foodKind: foodKind,
            grams: grams,
            targetCount: 1,
            affectsStock: completed.allowsDerivedEffects &&
                FeedStockCalculator.activeStockRecord(for: pet, foodKind: foodKind, foodRecords: foodRecords, now: date) != nil,
            stockReminders: stockReminders,
            didRecord: true,
            allowsDerivedEffects: completed.allowsDerivedEffects,
            coconutDelta: completed.coconutDelta,
            didPersist: true,
            persistenceErrorDescription: nil,
            recordReference: completed.logID.map { PetRecordReference(petID: pet.id, recordID: $0) }
        )
    }
}

private func singleCareResult(
    _ recorded: (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog)
) -> SharedPetActionResult {
    SharedPetActionResult(
        sessionID: recorded.result.logID,
        targetPetIDs: recorded.result.didWriteFact ? [recorded.result.subjectID] : [],
        careLogIDs: recorded.result.didWriteFact ? [recorded.result.logID] : [],
        pottyLogID: nil,
        pottyLog: nil,
        expenseLogIDs: [],
        walkLogIDs: [],
        walkLogs: [],
        reward: recorded.reward,
        disposition: recorded.result.disposition,
        didPersist: recorded.result.didPersist,
        persistenceErrorDescription: recorded.result.persistenceErrorDescription
    )
}
