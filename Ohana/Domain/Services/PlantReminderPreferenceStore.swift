//
//  PlantReminderPreferenceStore.swift
//  Ohana
//
//  User-controlled plant reminder preferences. These settings tune notification
//  delivery and materialized reminder rows without changing the underlying care
//  plan or plant facts.
//

import Foundation

enum PlantReminderTimeWindow: String, CaseIterable, Identifiable, Sendable {
    case morning
    case midday
    case evening

    nonisolated var id: String { rawValue }

    nonisolated var startHour: Int {
        switch self {
        case .morning: 9
        case .midday: 12
        case .evening: 18
        }
    }

    nonisolated var endHour: Int {
        switch self {
        case .morning: 11
        case .midday: 14
        case .evening: 20
        }
    }

    nonisolated var minute: Int { 30 }
}

nonisolated enum PlantReminderPreferenceStore {
    static let timeWindowStorageName = "plantReminder.timeWindow.v1"
    static let weekendQuietStorageName = "plantReminder.weekendQuiet.v1"
    static let travelModeStorageName = "plantReminder.travelMode.v1"
    static let generatedPlanTitleMarker = "植物计划"
    private static let careTypeStoragePrefix = "plantReminder.careTypeEnabled.v1."
    private static let plantCareLeadDaysPrefix = "plantReminder.plantCareLeadDays.v1."
    private static let plantCareRecurrenceEndPrefix = "plantReminder.plantCareRecurrenceEnd.v1."

    static let controllableCareTypes: [PlantCareType] = [
        .watering,
        .fertilizing,
        .repotting,
        .pruning,
        .misting,
        .rotating,
        .leafCleaning,
        .pestCheck
    ]

    static func timeWindow(defaults: UserDefaults = .standard) -> PlantReminderTimeWindow {
        defaults.string(forKey: timeWindowStorageName)
            .flatMap(PlantReminderTimeWindow.init(rawValue:)) ?? .morning
    }

    static func setTimeWindow(_ window: PlantReminderTimeWindow, defaults: UserDefaults = .standard) {
        defaults.set(window.rawValue, forKey: timeWindowStorageName)
    }

    static func isWeekendQuietEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: weekendQuietStorageName) == nil ? false : defaults.bool(forKey: weekendQuietStorageName)
    }

    static func setWeekendQuietEnabled(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: weekendQuietStorageName)
    }

    static func isTravelModeEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: travelModeStorageName) == nil ? false : defaults.bool(forKey: travelModeStorageName)
    }

    static func setTravelModeEnabled(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: travelModeStorageName)
    }

    static func isCareTypeReminderEnabled(_ type: PlantCareType, defaults: UserDefaults = .standard) -> Bool {
        guard controllableCareTypes.contains(type) else { return true }
        let key = careTypeKey(type)
        return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    static func setCareTypeReminderEnabled(
        _ value: Bool,
        for type: PlantCareType,
        defaults: UserDefaults = .standard
    ) {
        guard controllableCareTypes.contains(type) else { return }
        defaults.set(value, forKey: careTypeKey(type))
    }

    static func reminderLeadDays(
        forPlantID plantID: UUID,
        careType: PlantCareType,
        defaults: UserDefaults = .standard
    ) -> Int {
        let key = plantCareKey(prefix: plantCareLeadDaysPrefix, plantID: plantID, careType: careType)
        guard defaults.object(forKey: key) != nil else { return 0 }
        return min(max(defaults.integer(forKey: key), 0), 14)
    }

    static func setReminderLeadDays(
        _ days: Int,
        forPlantID plantID: UUID,
        careType: PlantCareType,
        defaults: UserDefaults = .standard
    ) {
        let key = plantCareKey(prefix: plantCareLeadDaysPrefix, plantID: plantID, careType: careType)
        defaults.set(min(max(days, 0), 14), forKey: key)
    }

    static func recurrenceEndDate(
        forPlantID plantID: UUID,
        careType: PlantCareType,
        defaults: UserDefaults = .standard
    ) -> Date? {
        let key = plantCareKey(prefix: plantCareRecurrenceEndPrefix, plantID: plantID, careType: careType)
        guard defaults.object(forKey: key) != nil else { return nil }
        let timestamp = defaults.double(forKey: key)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func setRecurrenceEndDate(
        _ date: Date?,
        forPlantID plantID: UUID,
        careType: PlantCareType,
        defaults: UserDefaults = .standard
    ) {
        let key = plantCareKey(prefix: plantCareRecurrenceEndPrefix, plantID: plantID, careType: careType)
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static func shouldDeliverNotification(for event: Event, defaults: UserDefaults = .standard) -> Bool {
        guard !isTravelModeEnabled(defaults: defaults) else { return false }
        guard let type = careType(forEventType: event.eventType) else { return true }
        return isCareTypeReminderEnabled(type, defaults: defaults)
    }

    static func isPlantCareEvent(_ event: Event) -> Bool {
        isGeneratedPlantCareEvent(event)
    }

    static func isGeneratedPlantCareEvent(_ event: Event) -> Bool {
        DomainEntityLinkRegistry.plantId(for: event) != nil &&
            careType(forEventType: event.eventType) != nil &&
            event.isAllDay &&
            event.recurrenceDays > 0 &&
            event.title.contains(generatedPlanTitleMarker)
    }

    static func careType(forEventType rawValue: String) -> PlantCareType? {
        switch EventType(rawValue: rawValue) {
        case .watering:
            .watering
        case .fertilizing:
            .fertilizing
        case .plantRepotting:
            .repotting
        case .plantPruning:
            .pruning
        case .plantMisting:
            .misting
        case .plantRotation:
            .rotating
        case .plantLeafCleaning:
            .leafCleaning
        case .plantPestCheck:
            .pestCheck
        case .plantHealthCheck:
            .customNote
        default:
            nil
        }
    }

    static func reminderDate(
        for dueDate: Date,
        now: Date,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        leadDays: Int = 0
    ) -> Date {
        let dueDay = calendar.startOfDay(for: dueDate)
        let today = calendar.startOfDay(for: now)
        let preferredLeadDay = calendar.date(byAdding: .day, value: -min(max(leadDays, 0), 14), to: dueDay) ?? dueDay
        let targetDay = preferredLeadDay < today ? today : preferredLeadDay
        let preferred = deliveryDate(for: targetDay, calendar: calendar, defaults: defaults)
        guard preferred <= now else { return preferred }
        return now.addingTimeInterval(5 * 60)
    }

    static func deliveryDate(
        for scheduledAt: Date,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> Date {
        let allowedDay = weekendAdjustedDay(for: scheduledAt, calendar: calendar, defaults: defaults)
        let window = timeWindow(defaults: defaults)
        return calendar.date(
            bySettingHour: window.startHour,
            minute: window.minute,
            second: 0,
            of: allowedDay
        ) ?? allowedDay
    }

    private static func weekendAdjustedDay(
        for date: Date,
        calendar: Calendar,
        defaults: UserDefaults
    ) -> Date {
        guard isWeekendQuietEnabled(defaults: defaults) else { return date }
        var candidate = calendar.startOfDay(for: date)
        while calendar.isDateInWeekend(candidate) {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86400)
        }
        return candidate
    }

    private static func careTypeKey(_ type: PlantCareType) -> String {
        "\(careTypeStoragePrefix)\(type.rawValue)"
    }

    private static func plantCareKey(prefix: String, plantID: UUID, careType: PlantCareType) -> String {
        "\(prefix)\(plantID.uuidString).\(careType.rawValue)"
    }
}
