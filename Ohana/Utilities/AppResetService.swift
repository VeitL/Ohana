import Foundation
import SwiftData
import UserNotifications

@MainActor
enum AppResetService {
    struct Options {
        var preserveLocalePreferences = true
        var cancelPendingNotifications = true
        var deleteCustomBackground = true
        var resetSharedRuntimeState = true
    }

    static func reset(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        try reset(context: context, defaults: defaults, options: Options())
    }

    static func reset(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        options: Options
    ) throws {
        let preservedDefaults = preservedDefaultValues(in: defaults, options: options)
        try deleteAllPersistentModels(in: context)
        try context.save()

        resetLocalDefaults(defaults, preservedValues: preservedDefaults)
        if options.deleteCustomBackground {
            CustomAppBackgroundStore.deleteImage()
        }
        if options.cancelPendingNotifications {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        if options.resetSharedRuntimeState {
            resetSharedRuntimeState()
        }

        defaults.set(false, forKey: "ohana_has_onboarded")
        defaults.set("", forKey: "currentActiveHumanId")
        defaults.set(false, forKey: "ohana_show_first_success_card")
        defaults.set(false, forKey: "ohana_first_quick_checkin_completed")
    }

    private static func deleteAllPersistentModels(in context: ModelContext) throws {
        try delete(PetDocumentAttachment.self, in: context)
        try delete(InsuranceClaim.self, in: context)
        try delete(Reminder.self, in: context)
        try delete(Event.self, in: context)
        try delete(CareLedgerEvent.self, in: context)
        try delete(CoconutLedgerEntry.self, in: context)
        try delete(CoconutAccount.self, in: context)
        try delete(FamilyCollaborationTask.self, in: context)
        try delete(CoconutExchangeRequest.self, in: context)
        try delete(SharedCareSession.self, in: context)
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

    private static func delete<T: PersistentModel>(_ model: T.Type, in context: ModelContext) throws {
        let values = try context.fetch(FetchDescriptor<T>())
        for value in values {
            context.delete(value)
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
            AppCurrency.storageKey,
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

    private static func resetSharedRuntimeState() {
        QuestManager.shared.coconutCount = 0
        QuestManager.shared.coconutLogs = []
        QuestManager.shared.isPetWizardCompleted = false
        QuestManager.shared.isFirstMealRecorded = false
        QuestManager.shared.isThemeColorSet = false
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
        "petBondVaultRevision",
        "purchasedShopItems",
        "quickActionItems_v2",
    ]

    private static let resetDefaultPrefixes = [
        "achievement_",
        "appBackground",
        "appCustomBackground",
        "appPowerSavingMode",
        "avatar2d_",
        "calendar_",
        "checkIn_",
        "feedOperatingMode_",
        "feedRecordMode_",
        "gacha",
        "home.",
        "home_",
        "inventory_",
        "lastLitterChangeDate_",
        "medication_remaining_",
        "notif_",
        "ohana_",
        "oasis_",
        "petBondVaultUnlocked_",
        "quest_",
        "shop_",
        "streakRewards_",
        "today_focus_",
        "water_operating_mode_",
    ]
}
