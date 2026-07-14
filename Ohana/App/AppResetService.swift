import Foundation
import SwiftData
import UserNotifications

@MainActor
enum AppResetService {
    struct Options {
        var preserveLocalePreferences = true
        var cancelPendingNotifications = true
        var deleteCustomBackground = true
        var deleteHumanNoteAttachments = true
        var resetSharedRuntimeState = true
        var cleanUpAutomaticBackups = true
    }

    struct ResetResult: Equatable {
        let automaticBackupCleanup: AutomaticBackupResetCleanupResult
        let humanNoteAttachmentCleanup: HumanNoteAttachmentCleanupResult

        init(
            automaticBackupCleanup: AutomaticBackupResetCleanupResult,
            humanNoteAttachmentCleanup: HumanNoteAttachmentCleanupResult = .notRequired
        ) {
            self.automaticBackupCleanup = automaticBackupCleanup
            self.humanNoteAttachmentCleanup = humanNoteAttachmentCleanup
        }
    }

    @discardableResult
    static func reset(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> HumanNoteAttachmentCleanupResult {
        let options = Options()
        return try reset(
            context: context,
            defaults: defaults,
            options: options
        )
    }

    @discardableResult
    static func reset(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        options: Options
    ) throws -> HumanNoteAttachmentCleanupResult {
        let questManager = options.resetSharedRuntimeState ? QuestManager() : nil
        return try resetInternal(
            context: context,
            defaults: defaults,
            options: options,
            questManager: questManager,
            attachmentStorage: .live,
            saveChanges: { $0.safeSaveResult(publishFailureEvent: true) }
        )
    }

    @discardableResult
    static func reset(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        options: Options,
        questManager: QuestManager
    ) throws -> HumanNoteAttachmentCleanupResult {
        try resetInternal(
            context: context,
            defaults: defaults,
            options: options,
            questManager: questManager,
            attachmentStorage: .live,
            saveChanges: { $0.safeSaveResult(publishFailureEvent: true) }
        )
    }

    @discardableResult
    static func reset(
        context: ModelContext,
        defaults: UserDefaults,
        options: Options,
        attachmentStorage: HumanNoteAttachmentStorage,
        saveChanges: (ModelContext) -> ModelContextSaveResult
    ) throws -> HumanNoteAttachmentCleanupResult {
        let questManager = options.resetSharedRuntimeState ? QuestManager() : nil
        return try resetInternal(
            context: context,
            defaults: defaults,
            options: options,
            questManager: questManager,
            attachmentStorage: attachmentStorage,
            saveChanges: saveChanges
        )
    }

    private static func resetInternal(
        context: ModelContext,
        defaults: UserDefaults,
        options: Options,
        questManager: QuestManager?,
        attachmentStorage: HumanNoteAttachmentStorage,
        saveChanges: (ModelContext) -> ModelContextSaveResult
    ) throws -> HumanNoteAttachmentCleanupResult {
        let preservedDefaults = preservedDefaultValues(in: defaults, options: options)
        try deleteAllPersistentModels(in: context)
        try saveResetChanges(context: context, saveChanges: saveChanges)
        let humanNoteAttachmentCleanup = options.deleteHumanNoteAttachments
            ? HumanNoteAttachmentStore.deleteAll(storage: attachmentStorage)
            : .notRequired

        resetLocalDefaults(defaults, preservedValues: preservedDefaults)
        // The local reset boundary always disables future automatic backups.
        // The shared asynchronous coordinator owns cancellation and removal of
        // the existing managed iCloud Drive file.
        AutomaticBackupStatusStore.resetAfterAppReset(defaults: defaults)
        if options.deleteCustomBackground {
            CustomAppBackgroundStore.deleteImage()
        }
        if options.cancelPendingNotifications {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        if options.resetSharedRuntimeState, let questManager {
            resetSharedRuntimeState(questManager: questManager)
        }

        defaults.set(false, forKey: "ohana_has_onboarded")
        defaults.set("", forKey: "currentActiveHumanId")
        defaults.set(false, forKey: "ohana_show_first_success_card")
        defaults.set(false, forKey: "ohana_first_quick_checkin_completed")
        return humanNoteAttachmentCleanup
    }

    private static func deleteAllPersistentModels(in context: ModelContext) throws {
        try delete(CloudSyncRecordState.self, in: context)
        try delete(PetDocumentAttachment.self, in: context)
        try delete(InsuranceClaim.self, in: context)
        try delete(Reminder.self, in: context)
        try delete(Event.self, in: context)
        try delete(CareLedgerEvent.self, in: context)
        try delete(CoconutLedgerEntry.self, in: context)
        try delete(CoconutAccount.self, in: context)
        try delete(EconomyBudgetUsageEvent.self, in: context)
        try delete(FamilyCollaborationTask.self, in: context)
        try delete(CoconutExchangeRequest.self, in: context)
        try delete(SharedCareUndoReceipt.self, in: context)
        try delete(SharedCareSession.self, in: context)
        try delete(RecycleBinBatch.self, in: context) // legacy V69 compatibility row
        try delete(ShopPurchaseRecord.self, in: context)
        try delete(GachaDrawLog.self, in: context)
        try delete(GachaOwnedItem.self, in: context)
        try delete(OasisCritterActionLog.self, in: context)
        try delete(OasisUnlock.self, in: context)
        try delete(OasisCritterFragmentBalance.self, in: context)
        try delete(OasisElectronicPet.self, in: context)
        try delete(OasisUpgradeCoconut.self, in: context)
        try delete(HumanHealthMetricLog.self, in: context)
        try delete(HumanMedicationLog.self, in: context)
        try delete(HumanMedication.self, in: context)
        try delete(HumanHealthReport.self, in: context)
        try delete(HumanWorkoutLog.self, in: context)
        try delete(HumanWeightLog.self, in: context)
        try delete(WishlistItem.self, in: context)
        try delete(PetPhotoLog.self, in: context)
        try delete(PetInsurance.self, in: context)
        try delete(PetMedication.self, in: context)
        try delete(SymptomLog.self, in: context)
        try delete(HeatCycleLog.self, in: context)
        try delete(PlantCareLog.self, in: context)
        try delete(WaterLog.self, in: context)
        try delete(PetMilestone.self, in: context)
        try delete(PetFoodRecord.self, in: context)
        try delete(PetExpenseLog.self, in: context)
        try delete(PetDocument.self, in: context)
        try delete(PetHealthLog.self, in: context)
        try delete(PetWeightLog.self, in: context)
        try delete(PetHygieneLog.self, in: context)
        try delete(PetWalkLog.self, in: context)
        try delete(PetPottyLog.self, in: context)
        try delete(PetCareLog.self, in: context)
        try delete(PetRelationship.self, in: context)
        try delete(Household.self, in: context)
        try delete(Plant.self, in: context)
        try delete(Pet.self, in: context)
        try delete(Human.self, in: context)
    }

    private static func delete<T: PersistentModel>(_: T.Type, in context: ModelContext) throws {
        let values = try context.fetch(FetchDescriptor<T>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        for value in values {
            context.delete(value) // derived-state: allow privacy reset local wipe intentionally bypasses sync tombstones
        }
    }

    private static func preservedDefaultValues(
        in defaults: UserDefaults,
        options: Options
    ) -> [String: Any] {
        guard options.preserveLocalePreferences else { return [:] }
        let preservedKeys = [
            "appLanguage",
            "appThemePreference",
            AppCountry.storageKey,
            AppMeasurementSystem.storageKey,
            AppCurrency.storageKey
        ]
        return preservedKeys.reduce(into: [:]) { values, key in
            if let value = defaults.object(forKey: key) {
                values[key] = value
            }
        }
    }

    private static func resetLocalDefaults(
        _ defaults: UserDefaults,
        preservedValues: [String: Any]
    ) {
        for key in defaults.dictionaryRepresentation().keys where shouldResetDefaultKey(key) {
            defaults.removeObject(forKey: key)
        }
        for (key, value) in preservedValues {
            defaults.set(value, forKey: key)
        }
    }

    private static func resetSharedRuntimeState(questManager: QuestManager) {
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        questManager.isPetWizardCompleted = false
        questManager.isFirstMealRecorded = false
        questManager.isThemeColorSet = false
        AppWorkloadPolicy.shared.refresh(reason: "appReset")
    }

    private static func shouldResetDefaultKey(_ key: String) -> Bool {
        exactResetDefaultKeys.contains(key)
            || resetDefaultPrefixes.contains { key.hasPrefix($0) }
    }

    private static func saveResetChanges(
        context: ModelContext,
        saveChanges: (ModelContext) -> ModelContextSaveResult
    ) throws {
        let saveResult = saveChanges(context)
        guard saveResult.didSave else {
            context.rollback()
            throw AppResetPersistenceError.persistenceFailed(saveResult.errorDescription)
        }
    }

    private static let exactResetDefaultKeys: Set<String> = [
        "bountyTasks",
        "celebratedMilestoneDays",
        "coconutCount",
        "coconutLogs",
        "currentActiveHumanId",
        "debugShowDummyCards",
        "defaultFeedGrams",
        "goFocusHomeCardOrder.v1",
        "hiddenHomePetIDs.v1",
        "islandNegativeBannerDismissedDate",
        "lastTreeHarvestDate",
        OnboardingJourneyCoordinator.Key.existingUserUpgradeSeen,
        OnboardingJourneyCoordinator.Key.firstCareCompleted,
        OnboardingJourneyCoordinator.Key.journeyStartedAt,
        OnboardingJourneyCoordinator.Key.roadmapPromptSeen,
        StarterGiftStorageKey.ceremonySeen,
        StarterGiftStorageKey.claimed,
        StarterGiftStorageKey.oasisTabPromptPending,
        StarterGiftStorageKey.pending,
        "ohanaGrowthLastSeenTreeLevelV1",
        "ohanaGrowthOnboardingCompletedV1",
        "petBondVaultRevision",
        "purchasedShopItems",
        "quickActionItems_v2"
    ]

    private static let resetDefaultPrefixes = [
        "achievement_",
        "appBackground",
        "appCustomBackground",
        "automaticBackup.",
        "appPowerSavingMode",
        "avatar2d_",
        "calendar_",
        "checkIn_",
        "economyV2.",
        "feedGoal_",
        "feedOperatingMode_",
        "feedRecordMode_",
        "filterCleanInterval_",
        "filterReminder_",
        "filterReplaceInterval_",
        "gacha",
        "home.",
        "home_",
        "inventory_",
        "lastLitterChangeDate_",
        "medication_remaining_",
        "notif_",
        "ohana_",
        "ohanaExisting",
        "ohanaGrowth",
        "ohanaStarter",
        "oasis_",
        "petBondVaultConsumed_",
        "petBondVaultUnlocked_",
        "quest_",
        "shop_",
        "scoopAnchorDate_",
        "scoopIntervalDays_",
        "streakRewards_",
        "today_focus_",
        "waterAmountEnabled_",
        "waterAmountMl_",
        "waterChangeCycleAnchor_",
        "waterInterval_",
        "waterReminder_",
        "water_operating_mode_"
    ]
}

enum AppResetPersistenceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "app.reset.persistence.failed",
                defaultValue: "Unable to reset local data.",
                comment: "Shown when app reset cannot save the delete-all operation."
            )
        }
    }
}
