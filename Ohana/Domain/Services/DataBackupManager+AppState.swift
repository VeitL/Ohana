//
//  DataBackupManager+AppState.swift
//  Ohana
//
//  AppState and plant-reminder preference backup mapping.
//

import Foundation

nonisolated extension DataBackupManager {
    // MARK: - App State

    func applyAppStateDefaults(_ state: AppStateBackup, to target: UserDefaults) {
        if !state.bountyTasksJSON.isEmpty { target.set(state.bountyTasksJSON, forKey: "bountyTasks") }
        if !state.purchasedShopItems.isEmpty { target.set(state.purchasedShopItems, forKey: "purchasedShopItems") }
        if let selectedAppIcon = state.selectedAppIcon, !selectedAppIcon.isEmpty {
            target.set(selectedAppIcon, forKey: AppIconCatalog.selectedIconKey)
        }
        if !state.gachaHistoryJSON.isEmpty { target.set(state.gachaHistoryJSON, forKey: "gachaHistory") }
        if !state.celebratedMilestoneDays.isEmpty {
            target.set(state.celebratedMilestoneDays, forKey: "celebratedMilestoneDays")
        }
        if let inventory = state.shopConsumableInventory {
            target.set(max(0, inventory.backdatePassCount), forKey: CheckInStreakStore.makeupPackKey)
            target.set(max(0, inventory.avatar2DExtraPassCount), forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory)
            target.set(inventory.doubleRewardBoostActive, forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
            if let expiry = parseDate(inventory.streakShieldExpiry) {
                target.set(expiry, forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
            } else {
                target.removeObject(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
            }
        }
        if let plantReminderPreferences = state.plantReminderPreferences {
            applyPlantReminderPreferences(plantReminderPreferences, defaults: target)
        }
    }

    func makePlantReminderPreferencesBackup(
        defaults: UserDefaults,
        plants: [Plant]
    ) -> PlantReminderPreferencesBackup {
        let disabledCareTypes = PlantReminderPreferenceStore.controllableCareTypes
            .filter { !PlantReminderPreferenceStore.isCareTypeReminderEnabled($0, defaults: defaults) }
            .map(\.rawValue)
        let plantCareOverrides = makePlantCarePreferenceOverrides(defaults: defaults, plants: plants)

        return PlantReminderPreferencesBackup(
            timeWindowRaw: PlantReminderPreferenceStore.timeWindow(defaults: defaults).rawValue,
            weekendQuietEnabled: PlantReminderPreferenceStore.isWeekendQuietEnabled(defaults: defaults),
            travelModeEnabled: PlantReminderPreferenceStore.isTravelModeEnabled(defaults: defaults),
            disabledCareTypesRaw: disabledCareTypes,
            plantCareOverrides: plantCareOverrides.isEmpty ? nil : plantCareOverrides
        )
    }

    private func makePlantCarePreferenceOverrides(
        defaults: UserDefaults,
        plants: [Plant]
    ) -> [PlantCarePreferenceOverrideBackup] {
        plants.flatMap { plant in
            PlantReminderPreferenceStore.controllableCareTypes.compactMap { careType in
                let planCalendarEnabled = PlantReminderPreferenceStore.planCalendarOverride(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                let systemReminderEnabled = PlantReminderPreferenceStore.systemReminderOverride(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                let completionCalendarEnabled = PlantReminderPreferenceStore.completionCalendarOverride(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                let reminderLeadDays = PlantReminderPreferenceStore.reminderLeadDaysOverride(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                let recurrenceEndDate = PlantReminderPreferenceStore.recurrenceEndDate(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                guard planCalendarEnabled != nil ||
                    systemReminderEnabled != nil ||
                    completionCalendarEnabled != nil ||
                    reminderLeadDays != nil ||
                    recurrenceEndDate != nil else {
                    return nil
                }
                return PlantCarePreferenceOverrideBackup(
                    plantID: plant.id.uuidString,
                    careTypeRaw: careType.rawValue,
                    planCalendarEnabled: planCalendarEnabled,
                    systemReminderEnabled: systemReminderEnabled,
                    completionCalendarEnabled: completionCalendarEnabled,
                    reminderLeadDays: reminderLeadDays,
                    recurrenceEndDate: recurrenceEndDate.map { iso.string(from: $0) }
                )
            }
        }
    }

    private func applyPlantReminderPreferences(
        _ preferences: PlantReminderPreferencesBackup,
        defaults: UserDefaults
    ) {
        if let rawValue = preferences.timeWindowRaw,
           let timeWindow = PlantReminderTimeWindow(rawValue: rawValue) {
            PlantReminderPreferenceStore.setTimeWindow(timeWindow, defaults: defaults)
        }
        if let weekendQuietEnabled = preferences.weekendQuietEnabled {
            PlantReminderPreferenceStore.setWeekendQuietEnabled(weekendQuietEnabled, defaults: defaults)
        }
        if let travelModeEnabled = preferences.travelModeEnabled {
            PlantReminderPreferenceStore.setTravelModeEnabled(travelModeEnabled, defaults: defaults)
        }
        if let disabledCareTypesRaw = preferences.disabledCareTypesRaw {
            let disabledCareTypes = Set(disabledCareTypesRaw)
            for careType in PlantReminderPreferenceStore.controllableCareTypes {
                PlantReminderPreferenceStore.setCareTypeReminderEnabled(
                    !disabledCareTypes.contains(careType.rawValue),
                    for: careType,
                    defaults: defaults
                )
            }
        }
        for override in preferences.plantCareOverrides ?? [] {
            applyPlantCarePreferenceOverride(override, defaults: defaults)
        }
    }

    private func applyPlantCarePreferenceOverride(
        _ override: PlantCarePreferenceOverrideBackup,
        defaults: UserDefaults
    ) {
        guard let plantID = UUID(uuidString: override.plantID),
              let careType = PlantCareType(rawValue: override.careTypeRaw) else {
            return
        }
        if let planCalendarEnabled = override.planCalendarEnabled {
            PlantReminderPreferenceStore.setPlanCalendarEnabled(
                planCalendarEnabled,
                forPlantID: plantID,
                careType: careType,
                defaults: defaults
            )
        }
        if let systemReminderEnabled = override.systemReminderEnabled {
            PlantReminderPreferenceStore.setSystemReminderEnabled(
                systemReminderEnabled,
                forPlantID: plantID,
                careType: careType,
                defaults: defaults
            )
        }
        if let completionCalendarEnabled = override.completionCalendarEnabled {
            PlantReminderPreferenceStore.setCompletionCalendarEnabled(
                completionCalendarEnabled,
                forPlantID: plantID,
                careType: careType,
                defaults: defaults
            )
        }
        if let reminderLeadDays = override.reminderLeadDays {
            PlantReminderPreferenceStore.setReminderLeadDays(
                reminderLeadDays,
                forPlantID: plantID,
                careType: careType,
                defaults: defaults
            )
        }
        PlantReminderPreferenceStore.setRecurrenceEndDate(
            override.recurrenceEndDate.flatMap { parseDate($0) },
            forPlantID: plantID,
            careType: careType,
            defaults: defaults
        )
    }
}
