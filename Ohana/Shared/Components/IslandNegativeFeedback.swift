//
//  IslandNegativeFeedback.swift
//  Ohana
//
//  Shared negative feedback signal generator for Home and Today Focus.
//

import Foundation

nonisolated struct IslandNegativeCareLedgerEntry: Equatable, Sendable {
    let petId: UUID
    let eventKind: CareLedgerEventKind
    let actionType: String
    let date: Date
    let amountValue: Double

    init(
        petId: UUID,
        eventKind: CareLedgerEventKind,
        actionType: String,
        date: Date,
        amountValue: Double = 0
    ) {
        self.petId = petId
        self.eventKind = eventKind
        self.actionType = actionType
        self.date = date
        self.amountValue = amountValue
    }
}

nonisolated enum IslandNegativeFeedback {
    @MainActor
    static func signals(
        pets: [Pet],
        plants: [Plant] = [],
        healthAlerts: PetHealthAlerting,
        careLedgerEntries: [IslandNegativeCareLedgerEntry] = []
    ) -> [IslandNegativeSignal] {
        signals(
            pets: pets,
            plants: plants,
            clinicalAlerts: healthAlerts.scanAlerts(pets: pets),
            careLedgerEntries: careLedgerEntries
        )
    }

    static func signals(
        pets: [Pet],
        plants: [Plant] = [],
        clinicalAlerts: [HealthAlert],
        careLedgerEntries: [IslandNegativeCareLedgerEntry] = []
    ) -> [IslandNegativeSignal] {
        var result: [IslandNegativeSignal] = []
        let calendar = Calendar.current
        let now = Date()

        let filteredClinicalAlerts = clinicalAlerts.filter { alert in
            switch alert.type {
            case .noCheckIn, .noWalk, .noPotty:
                false
            default:
                true
            }
        }
        for alert in filteredClinicalAlerts.prefix(2) {
            result.append(IslandNegativeSignal(
                iconName: iconName(for: alert),
                emoji: alert.emoji,
                title: localized(
                    zh: "\(alert.petName)：\(alert.title)",
                    en: "\(alert.petName): \(clinicalTitle(for: alert))"
                ),
                detail: localized(
                    zh: alert.detail,
                    en: clinicalDetail(for: alert)
                ),
                severity: alert.severity == .urgent ? .critical : .warning,
                petId: alert.petId,
                healthAlertType: alert.type,
                routeHint: routeHint(for: alert.type)
            ))
        }

        for pet in pets where !pet.hasPassedAway {
            if let signal = appetiteTrendSignal(for: pet, careLedgerEntries: careLedgerEntries, calendar: calendar, now: now) {
                result.append(signal)
            }
            if let signal = abnormalPottyTrendSignal(for: pet, careLedgerEntries: careLedgerEntries, calendar: calendar, now: now) {
                result.append(signal)
            }
            if let signal = drinkingTrendSignal(for: pet, careLedgerEntries: careLedgerEntries, calendar: calendar, now: now) {
                result.append(signal)
            }
        }

        let brokenStreakPets = pets.filter { pet in
            !pet.hasPassedAway &&
                pet.currentStreak == 0 &&
                !hasAnyPetCheckInToday(pet, careLedgerEntries: careLedgerEntries, calendar: calendar)
        }
        if !brokenStreakPets.isEmpty {
            let names = joinedNames(brokenStreakPets.prefix(2).map(\.name))
            result.append(IslandNegativeSignal(
                iconName: "cloud.fill",
                emoji: "🌥",
                title: localized(zh: "今日还未打卡", en: "No check-in yet today"),
                detail: localized(
                    zh: "给 \(names.zh) 完成一次喂食、喂水或遛狗打卡即可",
                    en: "Log a feeding, water, or walk check-in for \(names.en)"
                ),
                severity: .warning,
                petId: brokenStreakPets.first?.id,
                routeHint: .petOverview
            ))
        }

        for pet in pets {
            for med in pet.medications where med.isActiveToday {
                let need = med.frequency.dosesPerDay
                guard need > 0 else { continue }
                let taken = MedicationDoseProgressStore.dosesTakenToday(for: med.id)
                let hour = calendar.component(.hour, from: now)
                if hour >= 22, taken < need {
                    result.append(IslandNegativeSignal(
                        iconName: "pills.fill",
                        emoji: "💊",
                        title: localized(zh: "\(pet.name) 今日漏药", en: "\(pet.name) missed medication today"),
                        detail: localized(
                            zh: "\(med.name) 还差 \(need - taken) 次",
                            en: "\(med.name) has \(need - taken) dose\(need - taken == 1 ? "" : "s") left"
                        ),
                        severity: .critical,
                        petId: pet.id,
                        routeHint: .medication
                    ))
                    break
                }
            }
        }

        for pet in pets where !pet.hasPassedAway {
            let lastFeed = careLedgerEntries
                .filter { $0.petId == pet.id && $0.eventKind == .care && $0.actionType == CareType.feeding.rawValue }
                .map(\.date)
                .max()
            if let lastFeed, now.timeIntervalSince(lastFeed) > 72 * 3600 {
                let hours = Int(now.timeIntervalSince(lastFeed) / 3600)
                result.append(IslandNegativeSignal(
                    iconName: "fork.knife",
                    emoji: "🍗",
                    title: localized(zh: "\(pet.name) 喂食超期", en: "\(pet.name)'s feeding is overdue"),
                    detail: localized(
                        zh: "距离上次已 \(hours) 小时，建议先记录一次喂食",
                        en: "\(hours) hour\(hours == 1 ? "" : "s") since the last feeding. Log one first."
                    ),
                    severity: .warning,
                    petId: pet.id,
                    routeHint: .feed
                ))
                break
            }
        }

        if PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel) {
            for plant in plants {
                if let lastWatered = plant.lastWateredDate, now.timeIntervalSince(lastWatered) > 7 * 86400 {
                    let days = Int(now.timeIntervalSince(lastWatered) / 86400)
                    result.append(IslandNegativeSignal(
                        iconName: "drop.triangle.fill",
                        emoji: "🥀",
                        title: localized(zh: "\(plant.name) 叶子发黄", en: "\(plant.name)'s leaves are yellowing"),
                        detail: localized(
                            zh: "已 \(days) 天未浇水",
                            en: "\(days) day(s) since watering"
                        ),
                        severity: .warning,
                        plantId: plant.id,
                        routeHint: .plant
                    ))
                    break
                }
            }
        }

        return result.sorted {
            if $0.severity == $1.severity { return false }
            return $0.severity == .critical
        }
    }

    @MainActor
    static func hasAnyNegativeSignal(
        pets: [Pet],
        plants: [Plant] = [],
        healthAlerts: PetHealthAlerting,
        careLedgerEntries: [IslandNegativeCareLedgerEntry] = []
    ) -> Bool {
        !signals(pets: pets, plants: plants, healthAlerts: healthAlerts, careLedgerEntries: careLedgerEntries).isEmpty
    }

    private static func hasAnyPetCheckInToday(
        _ pet: Pet,
        careLedgerEntries: [IslandNegativeCareLedgerEntry],
        calendar: Calendar
    ) -> Bool {
        if let lastCheckInDate = pet.lastCheckInDate, calendar.isDateInToday(lastCheckInDate) {
            return true
        }
        let checkInKinds: Set<CareLedgerEventKind> = [.care, .walk, .potty, .hygiene]
        return careLedgerEntries.contains { entry in
            entry.petId == pet.id &&
                checkInKinds.contains(entry.eventKind) &&
                calendar.isDateInToday(entry.date)
        }
    }

    private static func localized(zh: String, en: String) -> String {
        AppLocalizedText(zh: zh, en: en).resolve()
    }

    private static func joinedNames(_ names: some Sequence<String>) -> (zh: String, en: String) {
        let values = names.map { $0.isEmpty ? localized(zh: "伙伴", en: "companion") : $0 }
        return (
            zh: values.joined(separator: "、"),
            en: values.joined(separator: ", ")
        )
    }

    private static func clinicalTitle(for alert: HealthAlert) -> String {
        switch alert.type {
        case .vaccineExpired: "Vaccination expired"
        case .vaccineExpiringSoon: "Vaccination expiring soon"
        case .dewormingDue: "Deworming due"
        case .weightGainAlert: "Weight increased noticeably"
        case .weightLossAlert: "Weight dropped noticeably"
        case .noCheckIn: "No care check-in"
        case .noPotty: "Potty tracking overdue"
        case .noWalk: "Walk overdue"
        case .checkupOverdue: "Checkup overdue"
        case .documentExpiringSoon: "Document expiring soon"
        case .activeSymptom: "Active symptom needs attention"
        case .heatCycleAlert: "Heat cycle alert"
        case .pregnancyCountdown: "Pregnancy countdown"
        case .drinkingWeightAlert: "Drinking and weight change"
        case .lowActivityAlert: "Low activity"
        }
    }

    private static func clinicalDetail(for alert: HealthAlert) -> String {
        switch alert.type {
        case .vaccineExpired:
            "A vaccination record has expired. Schedule a booster soon."
        case .vaccineExpiringSoon:
            "A vaccination record is nearing expiry. Consider booking ahead."
        case .dewormingDue:
            "Deworming is due soon. Keep the preventive care plan on track."
        case .weightGainAlert:
            "Recent weight is trending up. Review feeding and activity."
        case .weightLossAlert:
            "Recent weight is trending down. Check appetite and health signs."
        case .noCheckIn:
            "No recent feeding or water check-in has been recorded."
        case .noPotty:
            "Potty tracking is overdue. Watch elimination patterns."
        case .noWalk:
            "Walk activity is overdue. Add a walk when possible."
        case .checkupOverdue:
            "A health checkup is overdue or missing."
        case .documentExpiringSoon:
            "A document is expiring soon. Review it before the due date."
        case .activeSymptom:
            "A recent symptom was marked severe. Consider contacting a vet."
        case .heatCycleAlert:
            "Heat-cycle care needs extra attention."
        case .pregnancyCountdown:
            "Pregnancy care is approaching a key date."
        case .drinkingWeightAlert:
            "Drinking changes and weight movement appeared together."
        case .lowActivityAlert:
            "Recent activity is very low. Watch comfort and mobility."
        }
    }

    private static func iconName(for alert: HealthAlert) -> String {
        switch alert.type {
        case .vaccineExpired, .vaccineExpiringSoon:
            "syringe.fill"
        case .dewormingDue:
            "pills.fill"
        case .weightGainAlert, .weightLossAlert:
            "scalemass.fill"
        case .checkupOverdue, .activeSymptom:
            "cross.case.fill"
        case .documentExpiringSoon:
            "doc.badge.clock.fill"
        case .drinkingWeightAlert:
            "drop.triangle.fill"
        case .lowActivityAlert:
            "chart.line.downtrend.xyaxis"
        case .heatCycleAlert:
            "heart.text.square.fill"
        case .pregnancyCountdown:
            "figure.2.and.child.holdinghands"
        case .noCheckIn, .noPotty, .noWalk:
            "exclamationmark.triangle.fill"
        }
    }

    private static func routeHint(for alertType: HealthAlert.AlertType) -> IslandNegativeSignal.RouteHint {
        switch alertType {
        case .weightGainAlert, .weightLossAlert:
            .weight
        case .drinkingWeightAlert:
            .water
        case .noPotty:
            .potty
        case .noWalk:
            .walk
        case .dewormingDue:
            .medication
        case .documentExpiringSoon:
            .allFeatures
        default:
            .health
        }
    }

    private static func appetiteTrendSignal(
        for pet: Pet,
        careLedgerEntries: [IslandNegativeCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> IslandNegativeSignal? {
        let feedLogs = careLedgerEntries.filter {
            $0.petId == pet.id &&
                $0.eventKind == .care &&
                $0.actionType == CareType.feeding.rawValue &&
                $0.amountValue > 0
        }
        guard feedLogs.count >= 4 else { return nil }
        let recent = dailyAverageAmount(feedLogs, daysAgo: 0 ..< 3, calendar: calendar, now: now)
        let previous = dailyAverageAmount(feedLogs, daysAgo: 3 ..< 6, calendar: calendar, now: now)
        guard previous > 0, recent > 0, recent < previous * 0.65 else { return nil }
        return IslandNegativeSignal(
            iconName: "fork.knife.circle.fill",
            emoji: "🍽",
            title: localized(zh: "\(pet.name) 食欲下降", en: "\(pet.name)'s appetite dropped"),
            detail: localized(
                zh: "近 3 天喂食量比前 3 天低约 \(Int((1 - recent / previous) * 100))%，建议观察精神和便便",
                en: "Feeding volume is about \(Int((1 - recent / previous) * 100))% lower than the previous 3 days. Watch energy and stool."
            ),
            severity: .warning,
            petId: pet.id,
            routeHint: .feed
        )
    }

    private static func abnormalPottyTrendSignal(
        for pet: Pet,
        careLedgerEntries: [IslandNegativeCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> IslandNegativeSignal? {
        let start = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let abnormal = careLedgerEntries.filter {
            $0.petId == pet.id &&
                $0.eventKind == .potty &&
                $0.date >= start &&
                ($0.actionType == PottyType.softPoop.rawValue || $0.actionType == PottyType.liquidPoop.rawValue)
        }
        guard abnormal.count >= 2 else { return nil }
        return IslandNegativeSignal(
            iconName: "exclamationmark.triangle.fill",
            emoji: "🚽",
            title: localized(zh: "\(pet.name) 便便异常", en: "\(pet.name)'s stool looks unusual"),
            detail: localized(
                zh: "近 3 天记录到 \(abnormal.count) 次软便/水便，建议留意饮食变化",
                en: "\(abnormal.count) soft or liquid stool record(s) in the last 3 days. Watch diet changes."
            ),
            severity: abnormal.contains { $0.actionType == PottyType.liquidPoop.rawValue } ? .critical : .warning,
            petId: pet.id,
            routeHint: .potty
        )
    }

    private static func drinkingTrendSignal(
        for pet: Pet,
        careLedgerEntries: [IslandNegativeCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> IslandNegativeSignal? {
        let waterLogs = careLedgerEntries.filter {
            $0.petId == pet.id &&
                $0.eventKind == .care &&
                $0.actionType == CareType.watering.rawValue &&
                $0.amountValue > 0
        }
        guard waterLogs.count >= 4 else { return nil }
        let recent = dailyAverageAmount(waterLogs, daysAgo: 0 ..< 3, calendar: calendar, now: now)
        let previous = dailyAverageAmount(waterLogs, daysAgo: 3 ..< 6, calendar: calendar, now: now)
        guard previous > 0, recent > 0 else { return nil }
        if recent > previous * 1.7 {
            return IslandNegativeSignal(
                iconName: "drop.triangle.fill",
                emoji: "💧",
                title: localized(zh: "\(pet.name) 喝水增多", en: "\(pet.name) is drinking more"),
                detail: localized(
                    zh: "近 3 天饮水量明显高于之前，建议结合体重和尿尿观察",
                    en: "Water intake is much higher over the last 3 days. Compare with weight and pee patterns."
                ),
                severity: .warning,
                petId: pet.id,
                routeHint: .water
            )
        }
        if recent < previous * 0.45 {
            return IslandNegativeSignal(
                iconName: "drop.triangle.fill",
                emoji: "💧",
                title: localized(zh: "\(pet.name) 喝水减少", en: "\(pet.name) is drinking less"),
                detail: localized(
                    zh: "近 3 天饮水量明显偏低，建议检查水碗和精神状态",
                    en: "Water intake is low over the last 3 days. Check the bowl and energy level."
                ),
                severity: .warning,
                petId: pet.id,
                routeHint: .water
            )
        }
        return nil
    }

    private static func dailyAverageAmount(
        _ entries: [IslandNegativeCareLedgerEntry],
        daysAgo: Range<Int>,
        calendar: Calendar,
        now: Date
    ) -> Double {
        let values = daysAgo.map { dayOffset -> Double in
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { return 0 }
            return entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amountValue }
        }
        let nonZero = values.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0, +) / Double(nonZero.count)
    }
}
