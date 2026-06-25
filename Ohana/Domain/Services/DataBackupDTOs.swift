//
//  DataBackupDTOs.swift
//  Ohana
//
//  Codable backup payload types used by DataBackupManager.
//

import Foundation

// MARK: - 顶层备份结构
nonisolated struct OhanaBackup: Codable {
    var schemaVersion: Int = 26
    var exportedAt: String
    // 核心实体
    var pets: [PetBackup]
    var humans: [HumanBackup]
    var events: [EventBackup]
    var reminders: [ReminderBackup]
    var households: [HouseholdBackup]
    var plants: [PlantBackup]
    // 日志
    var petCareLogs: [PetCareLogBackup]
    var petPottyLogs: [PetPottyLogBackup]
    var petWalkLogs: [PetWalkLogBackup]
    var petWeightLogs: [PetWeightLogBackup]
    var petExpenseLogs: [PetExpenseLogBackup]
    var petHealthLogs: [PetHealthLogBackup]
    var petHygieneLogs: [PetHygieneLogBackup]
    var petFoodRecords: [PetFoodRecordBackup]
    var petDocuments: [PetDocumentBackup]
    var petDocumentAttachments: [PetDocumentAttachmentBackup]?
    var petMilestones: [PetMilestoneBackup]
    var petPhotoLogs: [PetPhotoLogBackup]?
    var petInsurances: [PetInsuranceBackup]?
    var insuranceClaims: [InsuranceClaimBackup]?
    var petMedications: [PetMedicationBackup]?
    var symptomLogs: [SymptomLogBackup]?
    var heatCycleLogs: [HeatCycleLogBackup]?
    var humanWeightLogs: [HumanWeightLogBackup]
    var humanWorkoutLogs: [HumanWorkoutLogBackup]
    var humanMedications: [HumanMedicationBackup]?
    var humanMedicationLogs: [HumanMedicationLogBackup]?
    var humanHealthMetricLogs: [HumanHealthMetricLogBackup]?
    var waterLogs: [WaterLogBackup]
    var wishlistItems: [WishlistItemBackup]
    var careLedgerEvents: [CareLedgerEventBackup]?
    var coconutAccounts: [CoconutAccountBackup]?
    var coconutLedgerEntries: [CoconutLedgerEntryBackup]?
    var familyCollaborationTasks: [FamilyCollaborationTaskBackup]?
    var sharedCareSessions: [SharedCareSessionBackup]?
    var coconutExchangeRequests: [CoconutExchangeRequestBackup]?
    var oasisUpgradeCoconuts: [OasisUpgradeCoconutBackup]?
    var oasisElectronicPets: [OasisElectronicPetBackup]?
    var oasisCritterFragments: [OasisCritterFragmentBackup]?
    var oasisUnlocks: [OasisUnlockBackup]?
    var oasisCritterActionLogs: [OasisCritterActionLogBackup]?
    var gachaOwnedItems: [GachaOwnedItemBackup]?
    var gachaDrawLogs: [GachaDrawLogBackup]?
    var shopPurchaseRecords: [ShopPurchaseRecordBackup]? = nil
    // App 状态
    var appState: AppStateBackup
}

// MARK: - AppState
nonisolated struct AppStateBackup: Codable {
    var coconutCount: Int
    var coconutLogsJSON: String
    var bountyTasksJSON: String
    var purchasedShopItems: String
    var selectedAppIcon: String?
    var gachaHistoryJSON: String
    var celebratedMilestoneDays: String
    var shopConsumableInventory: ShopConsumableInventoryBackup?
}

nonisolated struct ShopConsumableInventoryBackup: Codable {
    var backdatePassCount: Int
    var avatar2DExtraPassCount: Int
    var doubleRewardBoostActive: Bool
    var streakShieldExpiry: String?
}

// MARK: - 实体 Backup DTOs
nonisolated struct PetBackup: Codable {
    var id: String
    var name: String
    var species: String
    var breed: String
    var birthday: String?
    var gender: String
    var isNeutered: Bool
    var avatarEmoji: String
    var microchipID: String
    var vetContact: String
    var allergies: String
    var passportNumber: String
    var passportExpiryDate: String?
    var formerName: String
    var lineageInfo: String
    var themeColorHex: String
    var homeDate: String?
    var birthCountry: String
    var birthCity: String
    var foodBrand: String
    var restockDate: String?
    var restockWeight: Double
    var dailyPortionGrams: Double
    var mainFoodKindRaw: String?
    var foodPrice: Double
    var isShared: Bool
    var createdAt: String
    var notes: String
    var coatColor: String
    var eyeColor: String
    var currentStreak: Int
    var lastCheckInDate: String?
    var foodTrackingModeRaw: String
    var casualOpenDate: String?
    var casualDurationDays: Int
    var foodReminderEnabled: Bool?
    var foodReminderAdvanceDays: Int?
    var coconutBalance: Int
    var passedAwayDate: String?
    var cardStyleRaw: String?
    var cardPopoutImageBase64: String?
    var cardPopoutSourceRaw: String?
    /// ArkSchemaV26：性格标签 id，逗号分隔；旧备份缺省为 nil
    var personalityTagsRaw: String?
}

nonisolated struct HumanBackup: Codable {
    var id: String
    var name: String
    var birthday: String?
    var bloodType: String
    var avatarEmoji: String
    var role: String
    var appleUserIdentifier: String?
    var genderIdentityRaw: String?
    var notes: String
    var createdAt: String
    var nationality: String
    var city: String
    var coconutBalance: Int
    var shouldShowOnHome: Bool
    /// ArkSchemaV35：旧备份缺省为 nil
    var mbti: String?
    var privateFieldsRaw: String?
    var themeColorHex: String?
    var heightCm: Double?
    var avatarImageBase64: String?
    var passedAwayDate: String?
    // Intentionally excluded from backups: pinHash, pinSalt, pinFailedAttempts, pinLockedUntil.
}

nonisolated struct EventBackup: Codable {
    var id: String
    var title: String
    var startDate: String
    var endDate: String?
    var isAllDay: Bool
    var eventType: String
    var relatedEntityId: String
    var relatedEntityType: String
    var recurrenceDays: Int
    var recurrenceEndDate: String?
    var isCompleted: Bool
    var createdAt: String
    var completedOccurrences: [String]?
    var assigneeId: String?
    var feedRuleKindRaw: String?
    var foodKindRaw: String?
    var feedAmountGrams: Double?
    var feedPlanGroupId: String?
}

nonisolated struct ReminderBackup: Codable {
    var id: String
    var scheduledAt: String
    var status: String
    var notificationId: String
    var eventId: String?
    var completedAt: String?
    var completedBy: String?
    var createdAt: String?
}

nonisolated struct GachaOwnedItemBackup: Codable {
    var id: String
    var ownerHumanId: String
    var seriesId: String
    var itemId: String
    var rarityRaw: String
    var isHidden: Bool
    var ownedCount: Int
    var firstObtainedAt: String
    var latestObtainedAt: String
    var createdAt: String
}

nonisolated struct GachaDrawLogBackup: Codable {
    var id: String
    var ownerHumanId: String
    var ownerName: String
    var seriesId: String
    var itemId: String
    var rarityRaw: String
    var isHidden: Bool
    var isNew: Bool
    var outcomeKindRaw: String?
    var instantResultId: String?
    var instantTitleZh: String?
    var instantTitleEn: String?
    var instantTitleDe: String?
    var instantDetailZh: String?
    var instantDetailEn: String?
    var instantDetailDe: String?
    var instantSymbol: String?
    var instantCoconutDelta: Int?
    var costCoconuts: Int
    var dailySequence: Int
    var drawDate: String
    var createdAt: String
}

nonisolated struct ShopPurchaseRecordBackup: Codable {
    var id: String
    var transactionKey: String
    var itemId: String
    var buyerHumanId: String
    var purchasedAt: String
    var sourceRaw: String
    var isLegacyImport: Bool
    var createdAt: String
}

nonisolated struct HouseholdBackup: Codable {
    var id: String
    var name: String
    var createdAt: String
    var totalProsperity: Int
}

nonisolated struct PlantBackup: Codable {
    var id: String
    var name: String
    var species: String
    var avatarEmoji: String
    var location: String
    var notes: String
    var createdAt: String
    var lastWateredDate: String?
    var wateringIntervalDays: Int
    var lastFertilizedDate: String?
    var fertilizingIntervalDays: Int
    var themeColorHex: String?
    var lastHealthCheckDate: String?
    var potDiameterCm: Double?
    var potMaterialRaw: String?
    var soilTypeRaw: String?
    var isIndoor: Bool?
    var windowDirectionRaw: String?
    var lightLevelRaw: String?
    var healthStatusRaw: String?
    var catalogSpeciesId: String?
    var isToxicToCats: Bool?
    var isToxicToDogs: Bool?
    var isToxicToChildren: Bool?
    var isIndoorSuitable: Bool?
    var remindersEnabled: Bool?
}

nonisolated struct PetCareLogBackup: Codable {
    var id: String
    var date: String
    var type: String
    var amountGrams: Double
    var amountMl: Double
    var note: String
    var foodKindRaw: String?
    var treatKindRaw: String?
    var sharedSessionId: String?
    var executorId: String?
    var petId: String?
}

nonisolated struct PetPottyLogBackup: Codable {
    var id: String
    var date: String
    var type: String
    var executorId: String?
    var petId: String?
    var latitude: Double?
    var longitude: Double?
    var locationAccuracyMeters: Double?
    var walkLogId: String?
    var sharedSessionId: String?
}

nonisolated struct SharedCareSessionBackup: Codable {
    var id: String
    var date: String
    var actionKindRaw: String
    var executorId: String?
    var executorIdsRaw: String?
    var sourcePetId: String
    var targetPetIdsRaw: String
    var speciesRaw: String
    var totalAmountGrams: Double
    var totalAmountMl: Double
    var totalExpenseAmount: Double?
    var expenseCategoryRaw: String?
    var currencyCode: String?
    var allocationModeRaw: String
    var foodKindRaw: String
    var stockOwnerPetId: String
    var primaryLegacyModelName: String?
    var primaryLegacyModelId: String?
    var note: String
    var createdAt: String
}

nonisolated struct PetWalkLogBackup: Codable {
    var id: String
    var startDate: String
    var endDate: String?
    var distanceMeters: Double
    var coconutsEarned: Int
    var executorId: String?
    var executorIdsRaw: String?
    var petId: String?
    var sharedSessionId: String?
    var behaviorNotes: String?
    var moodRating: Int?
}

nonisolated struct PetWeightLogBackup: Codable {
    var id: String
    var date: String
    var weight: Double
    var petId: String?
    var executorId: String?
}

nonisolated struct PetExpenseLogBackup: Codable {
    var id: String
    var date: String
    var amount: Double
    var category: String
    var note: String
    var petId: String?
    var executorId: String?
    var sharedSessionId: String?
}

nonisolated struct PetHealthLogBackup: Codable {
    var id: String
    var date: String
    var type: String
    var note: String
    var expirationDate: String?
    var vetName: String
    var cost: Double
    var petId: String?
    var executorId: String?
}

nonisolated struct PetHygieneLogBackup: Codable {
    var id: String
    var date: String
    var type: String
    var petId: String?
    var executorId: String?
    var sharedSessionId: String?
}

nonisolated struct PetFoodRecordBackup: Codable {
    var id: String
    var date: String
    var brand: String
    var dailyGrams: Double
    var totalGrams: Double?
    var foodKindRaw: String?
    var petId: String?
    var purchaseDate: String?
    var remainingCorrectionGrams: Double?
    var remainingCorrectionDate: String?
    var notes: String?
    var executorId: String?
}

nonisolated struct PetDocumentBackup: Codable {
    var id: String
    var title: String
    var categoryRaw: String
    var expiryDate: String?
    var petId: String?
    var issueDate: String?
    var issuingAuthority: String?
    var notes: String?
    var reminderDate: String?
    var cost: Double?
    var attachmentBase64: String?
    var attachmentFilename: String?
}

nonisolated struct PetDocumentAttachmentBackup: Codable {
    var id: String
    var documentId: String
    var dataBase64: String
    var filename: String
    var isImage: Bool
}

nonisolated struct PetMilestoneBackup: Codable {
    var id: String
    var date: String
    var title: String
    var emoji: String
    var notes: String
    var petId: String?
}

nonisolated struct HumanWeightLogBackup: Codable {
    var id: String
    var date: String
    var weight: Double
    var humanId: String?
    var executorId: String?
}

nonisolated struct HumanWorkoutLogBackup: Codable {
    var id: String
    var date: String
    var typeRaw: String
    var durationMinutes: Int
    var notes: String
    var humanId: String?
}

nonisolated struct PetPhotoLogBackup: Codable {
    var id: String
    var date: String
    var note: String
    var createdAt: String
    var imageBase64: String
    var petId: String?
    var locationLatitude: Double
    var locationLongitude: Double
    var locationPlacename: String
}

nonisolated struct PetInsuranceBackup: Codable {
    var id: String
    var companyName: String
    var policyNumber: String
    var productName: String
    var annualPremium: Double
    var coverageAmount: Double
    var startDate: String
    var renewalDate: String
    var notes: String
    var isActive: Bool
    var createdAt: String
    var paymentFrequencyRaw: String
    var paymentDayOfMonth: Int
    var showInCalendar: Bool
    var otherFeeAmount: Double
    var otherFeeNote: String
    var firstPremiumPaymentDate: String?
    var petId: String?
}

nonisolated struct InsuranceClaimBackup: Codable {
    var id: String
    var insuranceId: String?
    var claimDate: String
    var incidentDate: String
    var totalExpense: Double
    var claimedAmount: Double
    var approvedAmount: Double
    var statusRaw: String
    var note: String
    var relatedExpenseLogId: String?
    var approvedAt: String?
    var createdAt: String
}

nonisolated struct PetMedicationBackup: Codable {
    var id: String
    var name: String
    var dosage: String
    var frequencyRaw: String
    var customFrequencyNote: String
    var startDate: String
    var endDate: String?
    var colorHex: String
    var notes: String
    var isActive: Bool
    var remainingAmount: Double?
    var createdAt: String
    var petId: String?
}

nonisolated struct HumanMedicationBackup: Codable {
    var id: String
    var humanId: String
    var name: String
    var dosage: String
    var frequencyRaw: String
    var customFrequencyNote: String
    var firstDoseTime: String
    var startDate: String
    var endDate: String?
    var colorHex: String
    var notes: String
    var isActive: Bool
    var createdAt: String
}

nonisolated struct HumanMedicationLogBackup: Codable {
    var id: String
    var humanId: String
    var medicationId: String
    var scheduledTime: String
    var recordedTime: String?
    var statusRaw: String
    var createdAt: String
}

nonisolated struct HumanHealthMetricLogBackup: Codable {
    var id: String
    var metricKey: String
    var unitCode: String
    var value: Double
    var date: String
    var notes: String
    var humanId: String?
    var createdAt: String
}

nonisolated struct SymptomLogBackup: Codable {
    var id: String
    var date: String
    var categoryRaw: String
    var symptomName: String
    var severityRaw: Int
    var note: String
    var photoBase64: String?
    var petId: String?
}

nonisolated struct HeatCycleLogBackup: Codable {
    var id: String
    var startDate: String
    var endDate: String?
    var statusRaw: String
    var note: String
    var isMated: Bool
    var expectedDeliveryDate: String?
    var petId: String?
}

nonisolated struct WaterLogBackup: Codable {
    var id: String
    var date: String
    var amountMl: Double
    var note: String
}

nonisolated struct WishlistItemBackup: Codable {
    var id: String
    var title: String
    var cost: Int
    var creatorId: String
    var isRedeemed: Bool
    var createdAt: String
}

nonisolated struct CareLedgerEventBackup: Codable {
    var id: String
    var occurredAt: String
    var actorKind: String
    var actorId: String?
    var subjectKind: String
    var subjectId: String?
    var eventKind: String
    var actionType: String
    var amountValue: Double
    var amountUnit: String
    var note: String
    var source: String
    var sourceEventId: String?
    var sourceReminderId: String?
    var legacyModelName: String?
    var legacyModelId: String?
    var coconutDelta: Int
    var rewardLogId: String?
    var privacyFieldRaw: String?
    var metadataJSON: String
    var createdAt: String
}

nonisolated struct CoconutAccountBackup: Codable {
    var id: String
    var accountKey: String
    var ownerKindRaw: String
    var ownerId: String
    var displayName: String
    var balance: Int
    var createdAt: String
    var updatedAt: String
    var metadataJSON: String
}

nonisolated struct CoconutLedgerEntryBackup: Codable {
    var id: String
    var transactionKey: String
    var accountKey: String
    var ownerKindRaw: String
    var ownerId: String
    var ownerName: String
    var delta: Int
    var balanceBefore: Int
    var balanceAfter: Int
    var affectsBalance: Bool
    var entryKindRaw: String
    var sourceRaw: String
    var title: String
    var emoji: String
    var actorId: String?
    var actorName: String?
    var subjectKindRaw: String
    var subjectId: String?
    var sourceModelName: String
    var sourceModelId: String
    var careLedgerEventId: String?
    var metadataJSON: String
    var occurredAt: String
    var createdAt: String
}

nonisolated struct FamilyCollaborationTaskBackup: Codable {
    var id: String
    var title: String
    var note: String
    var kindRaw: String
    var statusRaw: String
    var relatedPetId: String?
    var relatedEventId: String?
    var relatedReminderId: String?
    var createdById: String
    var createdByName: String
    var assignedToId: String?
    var assignedToName: String?
    var claimedById: String?
    var claimedByName: String?
    var completedById: String?
    var completedByName: String?
    var rewardCoconuts: Int
    var dueAt: String?
    var completedAt: String?
    var createdAt: String
    var updatedAt: String
    var emoji: String
}

nonisolated struct CoconutExchangeRequestBackup: Codable {
    var id: String
    var senderId: String
    var senderName: String
    var receiverId: String
    var receiverName: String
    var coconutCost: Int
    var currencyCode: String
    var localAmount: Double
    var statusRaw: String
    var createdAt: String
    var confirmedAt: String?
    var cancelledAt: String?
    var updatedAt: String
    var note: String
}

nonisolated struct OasisUpgradeCoconutBackup: Codable {
    var id: String
    var level: Int
    var createdAt: String
    var openedAt: String?
    var rewardKindRaw: String
    var rewardCatalogId: String
    var guaranteedCritterId: String?
    var coconutAmount: Int
    var treeEnergyAmount: Int
    var fragmentAmount: Int
    var decorUnlockId: String?
    var storyStyleUnlockId: String?
    var temporaryEffectId: String?
    var titleZh: String
    var titleEn: String
    var titleDe: String
    var descriptionZh: String
    var descriptionEn: String
    var descriptionDe: String
}

nonisolated struct OasisElectronicPetBackup: Codable {
    var id: String
    var catalogId: String
    var nameZh: String
    var nameEn: String
    var nameDe: String
    var emoji: String
    var rarityRaw: String
    var nickname: String
    var level: Int
    var starLevel: Int
    var xp: Int
    var hunger: Int
    var mood: Int
    var health: Int?
    var bond: Int
    var appearanceStage: Int
    var isFeaturedOnOasis: Bool?
    var habitatSlot: Int?
    var equippedDecorId: String?
    var favoriteItemId: String?
    var personalityRaw: String?
    var featuredPoseRaw: String?
    var sourceLevel: Int
    var obtainedAt: String
    var lastInteractionAt: String
    var lastStateRefreshAt: String?
    var lifeStateRaw: String?
    var deathReasonRaw: String?
    var riskStartedAt: String?
    var criticalStartedAt: String?
    var diedAt: String?
    var lastGentlePromptAt: String?
    var isArchived: Bool
}

nonisolated struct OasisCritterFragmentBackup: Codable {
    var id: String
    var catalogId: String
    var amount: Int
    var updatedAt: String
}

nonisolated struct OasisUnlockBackup: Codable {
    var id: String
    var unlockId: String
    var unlockKindRaw: String
    var sourceLevel: Int
    var createdAt: String
    var metadataJSON: String
}

nonisolated struct OasisCritterActionLogBackup: Codable {
    var id: String
    var critterId: String?
    var critterCatalogId: String
    var actionRaw: String
    var createdAt: String
    var coconutDelta: Int
    var fragmentDelta: Int
    var xpDelta: Int
    var sourceLevel: Int
    var noteZh: String
    var noteEn: String
    var noteDe: String
}
