import Foundation
import SwiftData

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
    ) -> (result: CareEventService.CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog)

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
    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)?

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
    ) -> (result: CareEventService.CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?)

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
    ) -> PetPottyLog

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

extension CareEventService {
    func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        quality: QuestManager.QualityBonus,
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
        quality: QuestManager.QualityBonus,
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
        quality: QuestManager.QualityBonus,
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
        quality: QuestManager.QualityBonus,
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

    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
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

    func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus,
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
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus,
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
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordSharedCare(
            sourcePet: sourcePet,
            targets: targets,
            type: type,
            actionKind: actionKind,
            context: context,
            executorId: executorId,
            reward: reward,
            rewardTitle: rewardTitle,
            quality: quality,
            date: date,
            source: source,
            dependencies: dependencies
        )
    }

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
    ) -> SharedPetActionResult {
        CareEventService.recordSharedCareFact(
            sourcePet: sourcePet,
            targets: targets,
            type: type,
            actionKind: actionKind,
            context: context,
            executorId: executorId,
            reward: reward,
            rewardTitle: rewardTitle,
            quality: quality,
            date: date,
            source: source,
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

    func recordUnknownSharedPotty(
        sourcePet: Pet,
        targets: [Pet],
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> PetPottyLog {
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
        executorId: String?,
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
            executorId: executorId,
            date: date,
            currencyCode: currencyCode,
            source: source,
            dependencies: dependencies
        )
    }
}

@MainActor
final class StaticCareEventEconomyAwarder: CareEventEconomyAwarding {
    private let questManager: QuestManager
    private let oasisRewards: OasisRewardManaging

    init(questManager: QuestManager, oasisRewards: OasisRewardManaging? = nil) {
        self.questManager = questManager
        self.oasisRewards = oasisRewards ?? StaticOasisRewardManager(
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager
        )
    }

    func awardCareAction(
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int) {
        let reward = EconomyRewardDiscipline.awardCareAction(
            type: type,
            pet: pet,
            context: context,
            quality: quality,
            executorId: executorId,
            questManager: questManager
        )
        oasisRewards.rewardFeaturedCritterFromCare(type: type, context: context)
        return reward
    }

    func awardSharedCareAction(
        type: QuestManager.OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        title: String?,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int) {
        let reward = EconomyRewardDiscipline.awardSharedCareAction(
            type: type,
            pets: pets,
            context: context,
            quality: quality,
            title: title,
            executorId: executorId,
            questManager: questManager
        )
        oasisRewards.rewardFeaturedCritterFromCare(type: type, context: context)
        return reward
    }
}
