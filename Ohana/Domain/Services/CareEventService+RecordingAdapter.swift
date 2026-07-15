//
//  CareEventService+RecordingAdapter.swift
//  Ohana
//

import Foundation
import SwiftData

extension CareEventService {
    func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        quality: DomainCareRewardQuality,
        date: Date,
        foodKind: FeedFoodKind
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordManualFeed(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            foodKind: foodKind,
            dependencies: dependencies
        )
    }

    func recordSharedManualFeedFact(
        sourcePet: Pet,
        targets: [Pet],
        totalGrams: Double,
        foodKind: FeedFoodKind,
        context: ModelContext,
        executorId: String?,
        quality: DomainCareRewardQuality,
        date: Date
    ) -> SharedPetActionResult {
        CareEventService.recordSharedManualFeedFact(
            sourcePet: sourcePet,
            targets: targets,
            totalGrams: totalGrams,
            foodKind: foodKind,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            dependencies: dependencies
        )
    }

    func recordManualFeedFact(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        quality: DomainCareRewardQuality,
        date: Date,
        foodKind: FeedFoodKind,
        source: CareLedgerSource
    ) -> (result: CareEventService.CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog) {
        CareEventService.recordManualFeedFact(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            foodKind: foodKind,
            source: source,
            dependencies: dependencies
        )
    }

    func recordSharedManualFeed(
        sourcePet: Pet,
        targets: [Pet],
        totalGrams: Double,
        foodKind: FeedFoodKind,
        context: ModelContext,
        executorId: String?,
        quality: DomainCareRewardQuality,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordSharedManualFeed(
            sourcePet: sourcePet,
            targets: targets,
            totalGrams: totalGrams,
            foodKind: foodKind,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            dependencies: dependencies
        )
    }

    func recordTreatFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        date: Date,
        treatKind: FeedTreatKind
    ) -> PetCareLog {
        CareEventService.recordTreatFeed(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            date: date,
            treatKind: treatKind,
            dependencies: dependencies
        )
    }

    func recordTreatFeedFact(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        date: Date,
        treatKind: FeedTreatKind
    ) -> (result: CareEventService.TreatFeedRecordResult, log: PetCareLog) {
        CareEventService.recordTreatFeedFact(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            date: date,
            treatKind: treatKind,
            dependencies: dependencies
        )
    }

    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: DomainCareRewardQuality,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)? {
        CareEventService.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: context,
            quality: quality,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func completePlannedFeedResult(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: DomainCareRewardQuality,
        executorId: String?,
        occurredAt: Date?,
        operationDate: Date
    ) -> PlannedCareCompletionResult {
        CareEventService.completePlannedFeedResult(
            pet: pet,
            reminder: reminder,
            context: context,
            quality: quality,
            executorId: executorId,
            occurredAt: occurredAt,
            operationDate: operationDate,
            dependencies: dependencies
        )
    }

    func completePlannedWater(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int)? {
        CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func completePlannedWaterResult(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        occurredAt: Date?,
        operationDate: Date
    ) -> PlannedCareCompletionResult {
        CareEventService.completePlannedWaterResult(
            pet: pet,
            reminder: reminder,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            occurredAt: occurredAt,
            operationDate: operationDate,
            dependencies: dependencies
        )
    }

    func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        reward: DomainCareRewardAction,
        quality: DomainCareRewardQuality,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordCare(
            pet: pet,
            type: type,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            reward: reward,
            quality: quality,
            date: date,
            dependencies: dependencies
        )
    }

    func recordCareFact(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        reward: DomainCareRewardAction,
        quality: DomainCareRewardQuality,
        date: Date,
        source: CareLedgerSource,
        createsLinkedPottyLog: Bool
    ) -> (result: CareEventService.CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?) {
        CareEventService.recordCareFact(
            pet: pet,
            type: type,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            reward: reward,
            quality: quality,
            date: date,
            source: source,
            createsLinkedPottyLog: createsLinkedPottyLog,
            dependencies: dependencies
        )
    }

    func recordSharedWatering(
        sourcePet: Pet,
        targets: [Pet],
        totalMl: Double,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordSharedWatering(
            sourcePet: sourcePet,
            targets: targets,
            totalMl: totalMl,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordSharedWateringFact(
        sourcePet: Pet,
        targets: [Pet],
        totalMl: Double,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> SharedPetActionResult {
        CareEventService.recordSharedWateringFact(
            sourcePet: sourcePet,
            targets: targets,
            totalMl: totalMl,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordSharedCare(
        _ request: SharedCareRecordRequest,
        context: ModelContext
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordSharedCare(
            request,
            context: context,
            dependencies: dependencies
        )
    }

    func recordSharedCareFact(
        _ request: SharedCareRecordRequest,
        context: ModelContext
    ) -> SharedPetActionResult {
        CareEventService.recordSharedCareFact(
            request,
            context: context,
            dependencies: dependencies
        )
    }

    func recordSharedLitterCare(
        sourcePet: Pet,
        targets: [Pet],
        context: ModelContext,
        executorId: String?,
        date: Date,
        isFullChange: Bool
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordSharedLitterCare(
            sourcePet: sourcePet,
            targets: targets,
            context: context,
            executorId: executorId,
            date: date,
            isFullChange: isFullChange,
            dependencies: dependencies
        )
    }

    func recordSharedLitterCareFact(
        sourcePet: Pet,
        targets: [Pet],
        context: ModelContext,
        executorId: String?,
        date: Date,
        isFullChange: Bool
    ) -> SharedPetActionResult {
        CareEventService.recordSharedLitterCareFact(
            sourcePet: sourcePet,
            targets: targets,
            context: context,
            executorId: executorId,
            date: date,
            isFullChange: isFullChange,
            dependencies: dependencies
        )
    }

    func recordPendingSharedLitterScoopFact(
        sourcePet: Pet,
        targets: [Pet],
        context: ModelContext,
        executorId: String?,
        date: Date,
        undoDeadline: Date,
        corePayloadJSON: String,
        externalEffectsPayloadJSON: String
    ) -> SharedPetActionResult {
        CareEventService.recordPendingSharedLitterScoopFact(
            sourcePet: sourcePet,
            targets: targets,
            context: context,
            executorId: executorId,
            date: date,
            undoDeadline: undoDeadline,
            corePayloadJSON: corePayloadJSON,
            externalEffectsPayloadJSON: externalEffectsPayloadJSON,
            dependencies: dependencies
        )
    }

    func recordUnknownSharedPotty(
        sourcePet: Pet,
        targets: [Pet],
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> PetPottyLog? {
        CareEventService.recordUnknownSharedPotty(
            sourcePet: sourcePet,
            targets: targets,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordPotty(
        pet: Pet,
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordPotty(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordPottyFact(
        pet: Pet,
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (result: CareEventService.PottyRecordResult, reward: (humanGot: Int, petGot: Int), log: PetPottyLog?) {
        CareEventService.recordPottyFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordHygiene(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordHygiene(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordHygieneFact(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (result: CareEventService.HygieneRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHygieneLog) {
        CareEventService.recordHygieneFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordHealth(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordHealth(
            pet: pet,
            type: type,
            note: note,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordHealthFact(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (result: CareEventService.HealthRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHealthLog?) {
        CareEventService.recordHealthFact(
            pet: pet,
            type: type,
            note: note,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        )
    }

    func recordSharedExpense(
        sourcePet: Pet,
        targets: [Pet],
        amount: Double,
        category: ExpenseCategory,
        note: String,
        context: ModelContext,
        attribution: ExpenseActorAttribution,
        date: Date,
        currencyCode: String,
        source: CareLedgerSource
    ) -> SharedPetActionResult {
        CareEventService.recordSharedExpense(
            sourcePet: sourcePet,
            targets: targets,
            amount: amount,
            category: category,
            note: note,
            context: context,
            attribution: attribution,
            date: date,
            currencyCode: currencyCode,
            source: source,
            dependencies: dependencies
        )
    }
}
