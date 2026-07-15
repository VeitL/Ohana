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
            deletePersistentData: { $0.deleteAllData() }
        )
    }

    @discardableResult
    static func reset(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        options: Options,
        questManager: QuestManager
    ) throws -> HumanNoteAttachmentCleanupResult {
        try reset(
            context: context,
            defaults: defaults,
            options: options,
            questManager: questManager,
            attachmentStorage: .live,
            deletePersistentData: { $0.deleteAllData() }
        )
    }

    @discardableResult
    static func reset(
        context: ModelContext,
        defaults: UserDefaults,
        options: Options,
        questManager: QuestManager,
        attachmentStorage: HumanNoteAttachmentStorage,
        deletePersistentData: (ModelContainer) throws -> Void
    ) throws -> HumanNoteAttachmentCleanupResult {
        try resetInternal(
            context: context,
            defaults: defaults,
            options: options,
            questManager: questManager,
            attachmentStorage: attachmentStorage,
            deletePersistentData: deletePersistentData
        )
    }

    @discardableResult
    static func reset(
        context: ModelContext,
        defaults: UserDefaults,
        options: Options,
        attachmentStorage: HumanNoteAttachmentStorage,
        deletePersistentData: (ModelContainer) throws -> Void
    ) throws -> HumanNoteAttachmentCleanupResult {
        let questManager = options.resetSharedRuntimeState ? QuestManager() : nil
        if let questManager {
            return try reset(
                context: context,
                defaults: defaults,
                options: options,
                questManager: questManager,
                attachmentStorage: attachmentStorage,
                deletePersistentData: deletePersistentData
            )
        }
        return try resetInternal(
            context: context,
            defaults: defaults,
            options: options,
            questManager: nil,
            attachmentStorage: attachmentStorage,
            deletePersistentData: deletePersistentData
        )
    }

    private static func resetInternal(
        context: ModelContext,
        defaults: UserDefaults,
        options: Options,
        questManager: QuestManager?,
        attachmentStorage: HumanNoteAttachmentStorage,
        deletePersistentData: (ModelContainer) throws -> Void
    ) throws -> HumanNoteAttachmentCleanupResult {
        let preservedDefaults = preservedDefaultValues(in: defaults, options: options)
        try deletePersistentModels(context: context, deletePersistentData: deletePersistentData)
        let humanNoteAttachmentCleanup = options.deleteHumanNoteAttachments
            ? HumanNoteAttachmentStore.deleteAll(storage: attachmentStorage)
            : .notRequired

        resetLocalDefaults(defaults, preservedValues: preservedDefaults)
        // AutomaticBackupStatusStore exclusively owns its prefix so reset does
        // not enumerate and remove the same CFPreferences keys twice. The
        // shared asynchronous coordinator owns cancellation and removal of the
        // existing managed iCloud Drive file.
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

    private static func deletePersistentModels(
        context: ModelContext,
        deletePersistentData: (ModelContainer) throws -> Void
    ) throws {
        // Reset owns the entire local store. ModelContainer.deleteAllData()
        // is Apple's runtime-safe delete-all API: one store-level operation
        // that neither materializes every object graph nor issues dozens of
        // batch-delete requests. Both alternatives crash on iOS 26.2.
        context.rollback()
        do {
            try deletePersistentData(context.container) // derived-state: intentional local reset bypasses sync tombstones
        } catch {
            throw AppResetPersistenceError.persistenceFailed(error.localizedDescription)
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
        OnboardingJourneyCoordinator.Key.firstHumanID,
        OnboardingJourneyCoordinator.Key.initialPetChoice,
        "ohanaStarterFirstCareCompletedV1",
        OnboardingJourneyCoordinator.Key.journeyStartedAt,
        OnboardingJourneyCoordinator.Key.roadmapPromptSeen,
        StarterGiftStorageKey.ceremonySeen,
        StarterGiftStorageKey.ceremonyRequested,
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
                comment: "Shown when app reset cannot delete the local store."
            )
        }
    }
}
