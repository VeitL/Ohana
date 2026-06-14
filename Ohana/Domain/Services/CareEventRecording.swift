import Foundation
import SwiftData

typealias CareRecordResult = CareEventService.CareRecordResult
@MainActor
protocol CareEventRecording {
    @discardableResult
    func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        quality: QuestManager.QualityBonus,
        date: Date,
        foodKind: FeedFoodKind
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordManualFeedFact(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        quality: QuestManager.QualityBonus,
        date: Date,
        foodKind: FeedFoodKind,
        source: CareLedgerSource
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog)

    @discardableResult
    func recordSharedManualFeed(
        sourcePet: Pet,
        targets: [Pet],
        totalGrams: Double,
        foodKind: FeedFoodKind,
        context: ModelContext,
        executorId: String?,
        quality: QuestManager.QualityBonus,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordSharedManualFeedFact(
        sourcePet: Pet,
        targets: [Pet],
        totalGrams: Double,
        foodKind: FeedFoodKind,
        context: ModelContext,
        executorId: String?,
        quality: QuestManager.QualityBonus,
        date: Date
    ) -> SharedPetActionResult

    @discardableResult
    func recordTreatFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        date: Date,
        treatKind: FeedTreatKind
    ) -> PetCareLog

    @discardableResult
    func recordTreatFeedFact(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        date: Date,
        treatKind: FeedTreatKind
    ) -> (result: CareEventService.TreatFeedRecordResult, log: PetCareLog)

    @discardableResult
    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)?

    @discardableResult
    func completePlannedFeedResult(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        executorId: String?,
        occurredAt: Date?,
        operationDate: Date
    ) -> PlannedCareCompletionResult

    @discardableResult
    func completePlannedWater(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)?

    @discardableResult
    func completePlannedWaterResult(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        occurredAt: Date?,
        operationDate: Date
    ) -> PlannedCareCompletionResult

    @discardableResult
    func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordCareFact(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus,
        date: Date,
        source: CareLedgerSource,
        createsLinkedPottyLog: Bool
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?)

    @discardableResult
    func recordSharedWatering(
        sourcePet: Pet,
        targets: [Pet],
        totalMl: Double,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordSharedWateringFact(
        sourcePet: Pet,
        targets: [Pet],
        totalMl: Double,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> SharedPetActionResult

    @discardableResult
    func recordSharedCare(
        sourcePet: Pet,
        targets: [Pet],
        type: CareType,
        actionKind: SharedCareActionKind,
        context: ModelContext,
        executorId: String?,
        reward: QuestManager.OhanaActionType,
        rewardTitle: String?,
        quality: QuestManager.QualityBonus,
        date: Date,
        source: CareLedgerSource
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordSharedCareFact(
        sourcePet: Pet,
        targets: [Pet],
        type: CareType,
        actionKind: SharedCareActionKind,
        context: ModelContext,
        executorId: String?,
        reward: QuestManager.OhanaActionType,
        rewardTitle: String?,
        quality: QuestManager.QualityBonus,
        date: Date,
        source: CareLedgerSource
    ) -> SharedPetActionResult

    @discardableResult
    func recordSharedLitterCare(
        sourcePet: Pet,
        targets: [Pet],
        context: ModelContext,
        executorId: String?,
        date: Date,
        isFullChange: Bool
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordSharedLitterCareFact(
        sourcePet: Pet,
        targets: [Pet],
        context: ModelContext,
        executorId: String?,
        date: Date,
        isFullChange: Bool
    ) -> SharedPetActionResult

    @discardableResult
    func recordUnknownSharedPotty(
        sourcePet: Pet,
        targets: [Pet],
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> PetPottyLog?

    @discardableResult
    func recordPotty(
        pet: Pet,
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordPottyFact(
        pet: Pet,
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (result: CareEventService.PottyRecordResult, reward: (humanGot: Int, petGot: Int), log: PetPottyLog?)

    @discardableResult
    func recordHygiene(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordHygieneFact(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (result: CareEventService.HygieneRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHygieneLog)

    @discardableResult
    func recordHealth(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordHealthFact(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (result: CareEventService.HealthRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHealthLog?)

    @discardableResult
    func recordSharedExpense(
        sourcePet: Pet,
        targets: [Pet],
        amount: Double,
        category: ExpenseCategory,
        note: String,
        context: ModelContext,
        executorId: String?,
        date: Date,
        currencyCode: String,
        source: CareLedgerSource
    ) -> SharedPetActionResult
}
