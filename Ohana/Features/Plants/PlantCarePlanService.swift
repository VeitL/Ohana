//
//  PlantCarePlanService.swift
//  Ohana
//
//  Deterministic local plant-care planning. AI/weather providers can enrich this
//  later, but the free launch path must work fully offline.
//

import Foundation

nonisolated struct PlantCareTaskSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let plantID: UUID
    let careType: PlantCareType
    let title: String
    let subtitle: String
    let explanation: String
    let dueDate: Date
    let isOverdue: Bool
    let daysUntilDue: Int
    let priority: Int
    let effectiveIntervalDays: Int
    let learningSummary: String
}

@MainActor
protocol PlantCarePlanReading {
    func tasks(
        for plant: Plant,
        now: Date,
        calendar: Calendar
    ) -> [PlantCareTaskSnapshot]

    func tasks(
        for plants: [Plant],
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> [PlantCareTaskSnapshot]

    func nextTask(
        for plant: Plant,
        now: Date,
        calendar: Calendar
    ) -> PlantCareTaskSnapshot?

    func intervalDays(for type: PlantCareType, plant: Plant) -> Int
}

extension PlantCarePlanReading {
    func tasks(
        for plant: Plant,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlantCareTaskSnapshot] {
        tasks(for: plant, now: now, calendar: calendar)
    }

    func tasks(
        for plants: [Plant],
        days: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlantCareTaskSnapshot] {
        tasks(for: plants, days: days, now: now, calendar: calendar)
    }

    func nextTask(
        for plant: Plant,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantCareTaskSnapshot? {
        nextTask(for: plant, now: now, calendar: calendar)
    }
}

struct StaticPlantCarePlanReader: PlantCarePlanReading {
    func tasks(
        for plant: Plant,
        now: Date,
        calendar: Calendar
    ) -> [PlantCareTaskSnapshot] {
        PlantCarePlanService.tasks(for: plant, now: now, calendar: calendar)
    }

    func tasks(
        for plants: [Plant],
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> [PlantCareTaskSnapshot] {
        PlantCarePlanService.tasks(for: plants, days: days, now: now, calendar: calendar)
    }

    func nextTask(
        for plant: Plant,
        now: Date,
        calendar: Calendar
    ) -> PlantCareTaskSnapshot? {
        PlantCarePlanService.nextTask(for: plant, now: now, calendar: calendar)
    }

    func intervalDays(for type: PlantCareType, plant: Plant) -> Int {
        PlantCarePlanService.intervalDays(for: type, plant: plant)
    }
}

nonisolated enum PlantCarePlanService {
    private struct IntervalPlan {
        let referenceDays: Int
        let environmentDays: Int
        let effectiveDays: Int
        let learning: LearningAdjustment

        var environmentDelta: Int {
            environmentDays - referenceDays
        }
    }

    private struct LearningAdjustment {
        let deltaDays: Int
        let summary: String

        static let none = LearningAdjustment(deltaDays: 0, summary: "")
    }

    static func tasks(
        for plant: Plant,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlantCareTaskSnapshot] {
        guard !plant.isArchived else { return [] }

        let wateringPlan = intervalPlan(for: .watering, plant: plant, calendar: calendar)
        let fertilizingPlan = intervalPlan(for: .fertilizing, plant: plant, calendar: calendar)
        let base = plant.createdAt
        var candidates: [(PlantCareType, Date?, IntervalPlan, Int, String)] = [
            (.watering, plant.lastWateredDate, wateringPlan, 0, wateringSubtitle(for: plant)),
            (.fertilizing, plant.lastFertilizedDate, fertilizingPlan, 2, fertilizingSubtitle(for: plant)),
            (
                .pestCheck,
                latestCareDate(for: plant, types: [.pestCheck, .pestFound]) ?? plant.lastHealthCheckDate,
                intervalPlan(for: .pestCheck, plant: plant, calendar: calendar),
                1,
                L10n.current.tr(zh: "查看叶背、土面和新芽", en: "Check leaf undersides, soil surface, and new growth", de: "Blattunterseiten, Erdoberfläche und neue Triebe prüfen")
            ),
            (
                .leafCleaning,
                latestCareDate(for: plant, types: [.leafCleaning]),
                intervalPlan(for: .leafCleaning, plant: plant, calendar: calendar),
                3,
                L10n.current.tr(zh: "擦掉灰尘，让叶片更好接光", en: "Wipe dust so leaves can receive light better", de: "Staub abwischen, damit Blätter besser Licht bekommen")
            ),
            (
                .rotating,
                latestCareDate(for: plant, types: [.rotating]),
                intervalPlan(for: .rotating, plant: plant, calendar: calendar),
                4,
                rotatingSubtitle(for: plant)
            ),
            (
                .pruning,
                latestCareDate(for: plant, types: [.pruning]),
                intervalPlan(for: .pruning, plant: plant, calendar: calendar),
                5,
                L10n.current.tr(zh: "剪掉黄叶、枯叶或过密枝叶", en: "Trim yellow, dry, or crowded leaves", de: "Gelbe, trockene oder zu dichte Blätter schneiden")
            ),
            (
                .repotting,
                latestCareDate(for: plant, types: [.repotting]),
                intervalPlan(for: .repotting, plant: plant, calendar: calendar),
                6,
                repottingSubtitle(for: plant)
            )
        ]
        if shouldScheduleMisting(for: plant) {
            candidates.append((
                .misting,
                latestCareDate(for: plant, types: [.misting]),
                intervalPlan(for: .misting, plant: plant, calendar: calendar),
                3,
                mistingSubtitle(for: plant)
            ))
        }

        return candidates
            .compactMap { type, lastDate, plan, priority, subtitle in
                makeTask(
                    type: type,
                    plant: plant,
                    lastDate: lastDate ?? base,
                    intervalPlan: plan,
                    subtitle: subtitle,
                    priority: priority,
                    now: now,
                    calendar: calendar
                )
            }
            .sorted {
                if $0.isOverdue != $1.isOverdue { return $0.isOverdue && !$1.isOverdue }
                if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
                return $0.priority < $1.priority
            }
    }

    static func nextTask(
        for plant: Plant,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantCareTaskSnapshot? {
        tasks(for: plant, now: now, calendar: calendar).first
    }

    static func tasks(
        for plants: [Plant],
        days: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlantCareTaskSnapshot] {
        let end = calendar.date(byAdding: .day, value: days, to: now) ?? now.addingTimeInterval(Double(days) * 86400)
        return plants
            .flatMap { tasks(for: $0, now: now, calendar: calendar).filter { $0.dueDate <= end } }
            .sorted {
                if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
                return $0.priority < $1.priority
            }
    }

    static func nextDueDate(
        for type: PlantCareType,
        plant: Plant,
        from date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let interval = intervalDays(for: type, plant: plant)
        return calendar.date(byAdding: .day, value: interval, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(Double(interval) * 86400)
    }

    static func intervalDays(for type: PlantCareType, plant: Plant) -> Int {
        intervalPlan(for: type, plant: plant, calendar: .current).effectiveDays
    }

    private static func intervalPlan(
        for type: PlantCareType,
        plant: Plant,
        calendar: Calendar
    ) -> IntervalPlan {
        let reference = referenceIntervalDays(for: type, plant: plant)
        let environment = environmentAdjustedIntervalDays(for: type, plant: plant)
        let learning = learningAdjustment(for: type, plant: plant, environmentDays: environment, calendar: calendar)
        return IntervalPlan(
            referenceDays: reference,
            environmentDays: environment,
            effectiveDays: clampInterval(environment + learning.deltaDays),
            learning: learning
        )
    }

    private static func referenceIntervalDays(for type: PlantCareType, plant: Plant) -> Int {
        let catalog = PlantCatalog.entry(id: plant.catalogSpeciesId)
        return switch type {
        case .watering:
            preferredInterval(
                customDays: plant.wateringIntervalDays,
                catalogDays: catalog?.defaultWateringDays,
                fallbackDays: 7
            )
        case .fertilizing:
            preferredInterval(
                customDays: plant.fertilizingIntervalDays,
                catalogDays: catalog?.defaultFertilizingDays,
                fallbackDays: 30
            )
        case .pestCheck:
            21
        case .leafCleaning:
            30
        case .rotating:
            14
        case .pruning:
            60
        case .repotting:
            365
        case .misting:
            7
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote:
            14
        }
    }

    private static func environmentAdjustedIntervalDays(for type: PlantCareType, plant: Plant) -> Int {
        switch type {
        case .watering:
            adjustedWateringDays(for: plant, catalog: PlantCatalog.entry(id: plant.catalogSpeciesId))
        case .fertilizing:
            adjustedFertilizingDays(
                for: plant,
                catalog: PlantCatalog.entry(id: plant.catalogSpeciesId)
            )
        case .pestCheck:
            21
        case .leafCleaning:
            plant.isNearClimateSource ? 21 : 30
        case .rotating:
            adjustedRotationDays(for: plant)
        case .pruning:
            60
        case .repotting:
            adjustedRepottingDays(for: plant)
        case .misting:
            adjustedMistingDays(for: plant)
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote:
            14
        }
    }

    private static func clampInterval(_ days: Int) -> Int {
        min(max(days, 1), 365)
    }

    private static func adjustedFertilizingDays(for plant: Plant, catalog: PlantCatalogEntry?) -> Int {
        var days = preferredInterval(
            customDays: plant.fertilizingIntervalDays,
            catalogDays: catalog?.defaultFertilizingDays,
            fallbackDays: 30
        )
        if plant.isHydroponic {
            days = min(days, 21)
        }
        if plant.isSucculent {
            days = max(days, 45)
        }
        if plant.healthStatus == .stressed {
            days += 14
        }
        return max(days, 1)
    }

    private static func adjustedRotationDays(for plant: Plant) -> Int {
        if plant.lightLevel == .direct || plant.windowDirection == .south || plant.windowDirection == .west {
            return 10
        }
        if plant.windowDirection == .unknown {
            return 21
        }
        return 14
    }

    private static func adjustedRepottingDays(for plant: Plant) -> Int {
        if plant.isHydroponic {
            return 180
        }
        if plant.potDiameterCm > 0, plant.currentHeightCm > plant.potDiameterCm * 4 {
            return 270
        }
        if !plant.potHasDrainage {
            return 270
        }
        return 365
    }

    private static func adjustedMistingDays(for plant: Plant) -> Int {
        if plant.isNearClimateSource {
            return 3
        }
        if plant.humidityPreference == .humid {
            return 5
        }
        return 7
    }

    private static func shouldScheduleMisting(for plant: Plant) -> Bool {
        plant.humidityPreference == .humid || plant.isNearClimateSource
    }

    private static func adjustedWateringDays(for plant: Plant, catalog: PlantCatalogEntry?) -> Int {
        var days = preferredInterval(
            customDays: plant.wateringIntervalDays,
            catalogDays: catalog?.defaultWateringDays,
            fallbackDays: 7
        )
        if plant.isHydroponic {
            return max(3, min(days, 7))
        }
        if plant.isSucculent {
            days = max(days + 7, 14)
        }
        if plant.lightLevel == .direct {
            days = max(1, days - 2)
        } else if plant.lightLevel == .low {
            days += 2
        }
        if plant.lastLightMeasurementLux >= 10000 {
            days = max(1, days - 2)
        } else if plant.lastLightMeasurementLux > 0, plant.lastLightMeasurementLux < 1000 {
            days += 2
        }
        switch plant.windowDirection {
        case .south, .west:
            days = max(1, days - 1)
        case .north:
            days += 1
        case .east, .unknown:
            break
        }
        if plant.potDiameterCm > 0, plant.potDiameterCm < 10 {
            days = max(1, days - 1)
        } else if plant.potDiameterCm >= 24 {
            days += 2
        }
        if plant.potMaterial.localizedCaseInsensitiveContains("陶") ||
            plant.potMaterial.localizedCaseInsensitiveContains("terracotta") ||
            plant.potMaterial.localizedCaseInsensitiveContains("clay") {
            days = max(1, days - 1)
        }
        if !plant.potHasDrainage {
            days += 2
        }
        if plant.isNearClimateSource {
            days = max(1, days - 1)
        }
        if !plant.isIndoor {
            days = max(1, days - 1)
        }
        return days
    }

    private static func preferredInterval(
        customDays: Int,
        catalogDays: Int?,
        fallbackDays: Int
    ) -> Int {
        if customDays > 0 { return customDays }
        if let catalogDays, catalogDays > 0 { return catalogDays }
        return max(fallbackDays, 1)
    }

    private static func learningAdjustment(
        for type: PlantCareType,
        plant: Plant,
        environmentDays: Int,
        calendar: Calendar
    ) -> LearningAdjustment {
        guard type == .watering else { return .none }

        var delta = 0
        var summaries: [String] = []
        let wetCount = consecutiveWetSoilFeedbackCount(for: plant, type: type)
        if wetCount >= 2 {
            let extensionDays = min(6, wetCount * 2)
            delta += extensionDays
            summaries.append(L10n.current.tr(zh: "最近 \(wetCount) 次反馈土还湿，周期自动延长 \(extensionDays) 天", en: "Last \(wetCount) wet-soil feedback entries extend the cadence by \(extensionDays) days", de: "Die letzten \(wetCount) Rückmeldungen zu feuchter Erde verlängern den Rhythmus um \(extensionDays) Tage"))
        }

        let skipCount = consecutiveSkipFeedbackCount(for: plant, type: type)
        if skipCount >= 2 {
            let extensionDays = min(4, skipCount)
            delta += extensionDays
            summaries.append(L10n.current.tr(zh: "最近 \(skipCount) 次跳过浇水，周期自动延长 \(extensionDays) 天", en: "Last \(skipCount) skipped watering entries extend the cadence by \(extensionDays) days", de: "Die letzten \(skipCount) übersprungenen Gießaufgaben verlängern den Rhythmus um \(extensionDays) Tage"))
        }

        let earlyCount = earlyCompletionCount(for: plant, type: type, intervalDays: environmentDays, calendar: calendar)
        if earlyCount >= 2 {
            let shorteningDays = min(4, earlyCount)
            delta -= shorteningDays
            summaries.append(L10n.current.tr(zh: "最近 \(earlyCount) 次提前浇水，周期自动缩短 \(shorteningDays) 天", en: "Last \(earlyCount) early watering entries shorten the cadence by \(shorteningDays) days", de: "Die letzten \(earlyCount) frühen Gießvorgänge verkürzen den Rhythmus um \(shorteningDays) Tage"))
        }

        guard delta != 0, !summaries.isEmpty else { return .none }
        return LearningAdjustment(deltaDays: delta, summary: summaries.joined(separator: "；"))
    }

    private static func consecutiveWetSoilFeedbackCount(for plant: Plant, type: PlantCareType) -> Int {
        consecutiveFeedbackCount(for: plant, type: type) { log in
            noteIndicatesWetSoil(log.note)
        }
    }

    private static func consecutiveSkipFeedbackCount(for plant: Plant, type: PlantCareType) -> Int {
        consecutiveFeedbackCount(for: plant, type: type) { log in
            isSkipFeedback(log, for: type)
        }
    }

    private static func consecutiveFeedbackCount(
        for plant: Plant,
        type: PlantCareType,
        matchesFeedback: (PlantCareLog) -> Bool
    ) -> Int {
        var count = 0
        for log in plant.careLogs.sorted(by: { $0.date > $1.date }) {
            if log.careType == type {
                break
            }
            if matchesFeedback(log) {
                count += 1
                if count >= 4 { break }
            }
        }
        return count
    }

    private static func earlyCompletionCount(
        for plant: Plant,
        type: PlantCareType,
        intervalDays: Int,
        calendar: Calendar
    ) -> Int {
        let dates = plant.careLogs
            .filter { $0.careType == type }
            .map(\.date)
            .sorted()
        guard dates.count >= 3 else { return 0 }

        let threshold = max(1, Int((Double(max(intervalDays, 1)) * 0.75).rounded(.down)))
        let intervals = zip(dates.dropFirst(), dates).compactMap { current, previous -> Int? in
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: previous),
                to: calendar.startOfDay(for: current)
            ).day
            guard let days, days > 0 else { return nil }
            return days
        }

        return intervals.suffix(3).count(where: { $0 <= threshold })
    }

    private static func isSkipFeedback(_ log: PlantCareLog, for type: PlantCareType) -> Bool {
        log.careType == .customNote && log.note.hasPrefix("skip:\(type.rawValue):")
    }

    private static func noteIndicatesWetSoil(_ note: String) -> Bool {
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return normalized.contains("soilwet") ||
            normalized.contains("soil still wet") ||
            normalized.contains("still wet") ||
            normalized.contains("too wet") ||
            normalized.contains("wet soil") ||
            normalized.contains("土还湿") ||
            normalized.contains("土还是湿") ||
            normalized.contains("土很湿") ||
            normalized.contains("盆土湿") ||
            normalized.contains("湿土")
    }

    private static func wateringSubtitle(for plant: Plant) -> String {
        let l = L10n.current
        if plant.isHydroponic {
            return l.tr(zh: "水培 · 检查水位并定期换水，避免根系缺氧", en: "Hydroponic · check water level and change water regularly to avoid low root oxygen", de: "Hydrokultur · Wasserstand prüfen und regelmäßig wechseln, damit die Wurzeln Sauerstoff bekommen")
        }
        let factors = environmentFactors(for: plant)
        return factors.isEmpty
            ? l.tr(zh: "按土壤干湿微调", en: "Adjust by soil moisture", de: "Nach Erdfeuchte anpassen")
            : l.tr(zh: "\(factors.joined(separator: " · "))，按土壤干湿微调", en: "\(factors.joined(separator: " · ")) · adjust by soil moisture", de: "\(factors.joined(separator: " · ")) · nach Erdfeuchte anpassen")
    }

    private static func fertilizingSubtitle(for plant: Plant) -> String {
        let l = L10n.current
        if plant.isHydroponic {
            return l.tr(zh: "水培营养液少量勤换；水质异常先换水", en: "Use small hydroponic nutrient changes; change water first if water looks off", de: "Hydrokultur-Nährlösung sparsam und öfter wechseln; bei auffälligem Wasser zuerst Wasser wechseln")
        }
        if plant.isSucculent {
            return l.tr(zh: "多肉少肥；生长期薄肥，休眠或状态紧张时延后", en: "Succulents need little fertilizer; use light feeding in growth season and defer during dormancy or stress", de: "Sukkulenten brauchen wenig Dünger; in der Wachstumszeit schwach düngen, bei Ruhe oder Stress verschieben")
        }
        if plant.healthStatus == .stressed {
            return l.tr(zh: "状态紧张时先稳定环境，施肥自动后移", en: "When stressed, stabilize the environment first; fertilizing moves later", de: "Bei Stress zuerst Umgebung stabilisieren; Düngen wird nach hinten verschoben")
        }
        return l.tr(zh: "生长期薄肥；冬季可以延后", en: "Use light fertilizer in growth season; winter can be deferred", de: "In der Wachstumszeit schwach düngen; im Winter kann es warten")
    }

    private static func mistingSubtitle(for plant: Plant) -> String {
        plant.isNearClimateSource
            ? L10n.current.tr(zh: "靠近空调/暖气，先补湿再观察叶尖", en: "Near AC/heater; add humidity and watch leaf tips", de: "Nahe an Klimaanlage/Heizung; Feuchte erhöhen und Blattspitzen beobachten")
            : L10n.current.tr(zh: "喜湿环境，少量喷雾并保持通风", en: "Prefers humidity; mist lightly and keep airflow", de: "Mag feuchtere Luft; leicht sprühen und lüften")
    }

    private static func rotatingSubtitle(for plant: Plant) -> String {
        switch plant.windowDirection {
        case .south, .west:
            L10n.current.tr(zh: "强单侧光，定期转盆避免偏冠和晒伤", en: "Strong one-sided light; rotate to avoid leaning and scorch", de: "Starkes einseitiges Licht; drehen gegen Schiefwuchs und Sonnenbrand")
        case .north:
            L10n.current.tr(zh: "北向光较弱，转盆同时观察徒长", en: "North light is weaker; rotate and watch for legginess", de: "Nordlicht ist schwächer; drehen und auf Vergeilen achten")
        case .east, .unknown:
            L10n.current.tr(zh: "让受光更均匀", en: "Keep light exposure more even", de: "Licht gleichmäßiger verteilen")
        }
    }

    private static func repottingSubtitle(for plant: Plant) -> String {
        let l = L10n.current
        if plant.isHydroponic {
            return l.tr(zh: "水培容器、根系和水质需要定期复查", en: "Check hydroponic container, roots, and water quality regularly", de: "Hydrokulturgefäß, Wurzeln und Wasserqualität regelmäßig prüfen")
        }
        if !plant.potHasDrainage {
            return l.tr(zh: "无排水孔更容易积水，优先检查根系和介质", en: "No drainage hole increases waterlogging risk; check roots and medium first", de: "Ohne Abzugsloch staut sich leichter Wasser; zuerst Wurzeln und Substrat prüfen")
        }
        if plant.potDiameterCm > 0, plant.currentHeightCm > plant.potDiameterCm * 4 {
            return l.tr(zh: "株高明显大于盆径，留意头重脚轻或根系拥挤", en: "Plant is much taller than pot width; watch for top-heaviness or crowded roots", de: "Pflanze ist deutlich höher als der Topf breit; auf Kopflastigkeit oder enge Wurzeln achten")
        }
        return l.tr(zh: "根系拥挤或土壤板结时优先", en: "Prioritize when roots are crowded or soil is compacted", de: "Priorisieren, wenn Wurzeln eng sind oder Erde verdichtet ist")
    }

    private static func environmentFactors(for plant: Plant) -> [String] {
        let l = L10n.current
        var factors = [plant.isIndoor ? l.tr(zh: "室内", en: "Indoor", de: "Drinnen") : l.tr(zh: "阳台/花园", en: "Balcony/garden", de: "Balkon/Garten"), plant.lightLevel.displayName]
        if plant.windowDirection != .unknown {
            factors.append(plant.windowDirection.displayName)
        }
        if plant.lastLightMeasurementLux > 0 {
            factors.append(l.tr(zh: "实测 \(plant.lastLightMeasurementLux) lux", en: "Measured \(plant.lastLightMeasurementLux) lux", de: "Gemessen \(plant.lastLightMeasurementLux) lux"))
        }
        if plant.isNearClimateSource {
            factors.append(l.tr(zh: "靠近空调/暖气", en: "Near AC/heater", de: "Nahe an Klimaanlage/Heizung"))
        }
        if !plant.potHasDrainage {
            factors.append(l.tr(zh: "无排水孔", en: "No drainage hole", de: "Kein Abzugsloch"))
        }
        if plant.isSucculent {
            factors.append(l.tr(zh: "多肉", en: "Succulent", de: "Sukkulente"))
        }
        return factors
    }

    private static func explanation(
        for type: PlantCareType,
        plant: Plant,
        intervalPlan: IntervalPlan
    ) -> String {
        let l = L10n.current
        var parts = [l.tr(zh: "基础 \(intervalPlan.referenceDays) 天", en: "Base \(intervalPlan.referenceDays)d", de: "Basis \(intervalPlan.referenceDays) T.")]
        let factors = explanationFactors(for: type, plant: plant)
        if !factors.isEmpty {
            parts.append(l.tr(zh: "\(factors.joined(separator: " + "))影响节奏", en: "\(factors.joined(separator: " + ")) affects cadence", de: "\(factors.joined(separator: " + ")) beeinflusst den Rhythmus"))
        }
        if intervalPlan.environmentDelta != 0 {
            parts.append(l.tr(zh: "环境周期\(deltaText(intervalPlan.environmentDelta))", en: "Environment \(deltaText(intervalPlan.environmentDelta))", de: "Umgebung \(deltaText(intervalPlan.environmentDelta))"))
        }
        if !intervalPlan.learning.summary.isEmpty {
            parts.append(intervalPlan.learning.summary)
        }
        parts.append(l.tr(zh: "当前有效周期 \(intervalPlan.effectiveDays) 天", en: "Effective cadence \(intervalPlan.effectiveDays)d", de: "Aktueller Rhythmus \(intervalPlan.effectiveDays) T."))
        return parts.joined(separator: "；")
    }

    private static func explanationFactors(for type: PlantCareType, plant: Plant) -> [String] {
        switch type {
        case .watering:
            let l = L10n.current
            var factors: [String] = []
            if plant.isHydroponic { factors.append(l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur")) }
            if plant.isSucculent { factors.append(l.tr(zh: "多肉", en: "Succulent", de: "Sukkulente")) }
            if plant.lightLevel == .direct { factors.append(l.tr(zh: "直射光", en: "Direct sun", de: "Direktes Licht")) }
            if plant.lightLevel == .low { factors.append(l.tr(zh: "弱光", en: "Low light", de: "Schwaches Licht")) }
            if plant.lastLightMeasurementLux >= 10000 {
                factors.append(l.tr(zh: "高 lux", en: "High lux", de: "Hohe Lux"))
            } else if plant.lastLightMeasurementLux > 0, plant.lastLightMeasurementLux < 1000 {
                factors.append(l.tr(zh: "低 lux", en: "Low lux", de: "Niedrige Lux"))
            }
            if plant.windowDirection == .south || plant.windowDirection == .west {
                factors.append(plant.windowDirection.displayName)
            } else if plant.windowDirection == .north {
                factors.append(l.tr(zh: "北向", en: "North-facing", de: "Nach Norden"))
            }
            if plant.potDiameterCm > 0, plant.potDiameterCm < 10 {
                factors.append(l.tr(zh: "小盆", en: "Small pot", de: "Kleiner Topf"))
            } else if plant.potDiameterCm >= 24 {
                factors.append(l.tr(zh: "大盆", en: "Large pot", de: "Großer Topf"))
            }
            if plant.potMaterial.localizedCaseInsensitiveContains("陶") ||
                plant.potMaterial.localizedCaseInsensitiveContains("terracotta") ||
                plant.potMaterial.localizedCaseInsensitiveContains("clay") {
                factors.append(l.tr(zh: "陶盆", en: "Clay pot", de: "Tontopf"))
            }
            if !plant.potHasDrainage { factors.append(l.tr(zh: "无排水孔", en: "No drainage hole", de: "Kein Abzugsloch")) }
            if plant.isNearClimateSource { factors.append(l.tr(zh: "空调/暖气旁", en: "Near AC/heater", de: "Neben Klimaanlage/Heizung")) }
            if !plant.isIndoor { factors.append(l.tr(zh: "阳台/花园", en: "Balcony/garden", de: "Balkon/Garten")) }
            return factors
        case .fertilizing:
            return [
                plant.isHydroponic ? L10n.current.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur") : nil,
                plant.isSucculent ? L10n.current.tr(zh: "多肉", en: "Succulent", de: "Sukkulente") : nil,
                plant.healthStatus == .stressed ? L10n.current.tr(zh: "状态紧张", en: "Stressed", de: "Gestresst") : nil
            ].compactMap(\.self)
        case .leafCleaning:
            return plant.isNearClimateSource ? [L10n.current.tr(zh: "空调/暖气旁", en: "Near AC/heater", de: "Neben Klimaanlage/Heizung")] : []
        case .rotating:
            switch plant.windowDirection {
            case .south, .west:
                return [plant.windowDirection.displayName]
            case .north:
                return [L10n.current.tr(zh: "北向弱光", en: "North-facing low light", de: "Nordseitiges schwaches Licht")]
            case .east, .unknown:
                return []
            }
        case .repotting:
            return [
                plant.isHydroponic ? L10n.current.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur") : nil,
                !plant.potHasDrainage ? L10n.current.tr(zh: "无排水孔", en: "No drainage hole", de: "Kein Abzugsloch") : nil,
                plant.potDiameterCm > 0 && plant.currentHeightCm > plant.potDiameterCm * 4 ? L10n.current.tr(zh: "株高明显大于盆径", en: "Height much larger than pot diameter", de: "Höhe deutlich größer als Topfdurchmesser") : nil
            ].compactMap(\.self)
        case .misting:
            return [
                plant.humidityPreference == .humid ? L10n.current.tr(zh: "喜湿", en: "Humidity-loving", de: "Mag Feuchtigkeit") : nil,
                plant.isNearClimateSource ? L10n.current.tr(zh: "空调/暖气旁", en: "Near AC/heater", de: "Neben Klimaanlage/Heizung") : nil
            ].compactMap(\.self)
        case .pestCheck:
            return plant.healthStatus == .watching || plant.healthStatus == .stressed ? [L10n.current.tr(zh: "健康状态需观察", en: "Health needs watching", de: "Zustand beobachten")] : []
        case .pruning:
            return plant.healthStatus == .stressed ? [L10n.current.tr(zh: "状态紧张", en: "Stressed", de: "Gestresst")] : []
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote:
            return []
        }
    }

    private static func deltaText(_ delta: Int) -> String {
        delta < 0
            ? L10n.current.tr(zh: "缩短 \(abs(delta)) 天", en: "shortens by \(abs(delta))d", de: "verkürzt um \(abs(delta)) T.")
            : L10n.current.tr(zh: "延长 \(delta) 天", en: "extends by \(delta)d", de: "verlängert um \(delta) T.")
    }

    private static func makeTask(
        type: PlantCareType,
        plant: Plant,
        lastDate: Date,
        intervalPlan: IntervalPlan,
        subtitle: String,
        priority: Int,
        now: Date,
        calendar: Calendar
    ) -> PlantCareTaskSnapshot? {
        var dueDate = calendar.date(byAdding: .day, value: intervalPlan.effectiveDays, to: calendar.startOfDay(for: lastDate))
            ?? calendar.startOfDay(for: lastDate)
        var explanation = explanation(for: type, plant: plant, intervalPlan: intervalPlan)
        if let deferredDate = deferredUntil(for: type, plant: plant, calendar: calendar),
           deferredDate > dueDate {
            dueDate = deferredDate
            explanation += "；\(L10n.current.tr(zh: "最近一次跳过/延后反馈已纳入本次到期日", en: "The latest skip/defer feedback is included in this due date", de: "Die letzte Überspringen-/Verschieben-Rückmeldung ist in diesem Termin berücksichtigt"))"
        }
        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        let l = L10n.current
        let plantName = plant.name.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.name
        return PlantCareTaskSnapshot(
            id: "\(plant.id.uuidString)-\(type.rawValue)-\(Int(dueDay.timeIntervalSince1970))",
            plantID: plant.id,
            careType: type,
            title: "\(type.displayName(l: l)) · \(plantName)",
            subtitle: subtitle,
            explanation: explanation,
            dueDate: dueDay,
            isOverdue: dueDay < today,
            daysUntilDue: daysUntilDue,
            priority: priority,
            effectiveIntervalDays: intervalPlan.effectiveDays,
            learningSummary: intervalPlan.learning.summary
        )
    }

    private static func latestCareDate(for plant: Plant, types: [PlantCareType]) -> Date? {
        plant.careLogs
            .filter { types.contains($0.careType) }
            .map(\.date)
            .max()
    }

    private static func deferredUntil(
        for type: PlantCareType,
        plant: Plant,
        calendar: Calendar
    ) -> Date? {
        let formatter = ISO8601DateFormatter()
        let prefixes = [
            "defer:\(type.rawValue):",
            "skip:\(type.rawValue):"
        ]
        return plant.careLogs
            .filter { log in
                log.careType == .customNote && prefixes.contains { log.note.hasPrefix($0) }
            }
            .compactMap { log -> Date? in
                let prefix = prefixes.first { log.note.hasPrefix($0) } ?? ""
                let raw = String(log.note.dropFirst(prefix.count))
                let rawDate = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? raw
                return formatter.date(from: rawDate)
            }
            .map { calendar.startOfDay(for: $0) }
            .max()
    }
}
