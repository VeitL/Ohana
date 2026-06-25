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
                "查看叶背、土面和新芽"
            ),
            (
                .leafCleaning,
                latestCareDate(for: plant, types: [.leafCleaning]),
                intervalPlan(for: .leafCleaning, plant: plant, calendar: calendar),
                3,
                "擦掉灰尘，让叶片更好接光"
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
                "剪掉黄叶、枯叶或过密枝叶"
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
            .filter(\.remindersEnabled)
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
            summaries.append("最近 \(wetCount) 次反馈土还湿，周期自动延长 \(extensionDays) 天")
        }

        let skipCount = consecutiveSkipFeedbackCount(for: plant, type: type)
        if skipCount >= 2 {
            let extensionDays = min(4, skipCount)
            delta += extensionDays
            summaries.append("最近 \(skipCount) 次跳过浇水，周期自动延长 \(extensionDays) 天")
        }

        let earlyCount = earlyCompletionCount(for: plant, type: type, intervalDays: environmentDays, calendar: calendar)
        if earlyCount >= 2 {
            let shorteningDays = min(4, earlyCount)
            delta -= shorteningDays
            summaries.append("最近 \(earlyCount) 次提前浇水，周期自动缩短 \(shorteningDays) 天")
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
        if plant.isHydroponic {
            return "水培 · 检查水位并定期换水，避免根系缺氧"
        }
        let factors = environmentFactors(for: plant)
        return factors.isEmpty ? "按土壤干湿微调" : "\(factors.joined(separator: " · "))，按土壤干湿微调"
    }

    private static func fertilizingSubtitle(for plant: Plant) -> String {
        if plant.isHydroponic {
            return "水培营养液少量勤换；水质异常先换水"
        }
        if plant.isSucculent {
            return "多肉少肥；生长期薄肥，休眠或状态紧张时延后"
        }
        if plant.healthStatus == .stressed {
            return "状态紧张时先稳定环境，施肥自动后移"
        }
        return "生长期薄肥；冬季可以延后"
    }

    private static func mistingSubtitle(for plant: Plant) -> String {
        plant.isNearClimateSource ? "靠近空调/暖气，先补湿再观察叶尖" : "喜湿环境，少量喷雾并保持通风"
    }

    private static func rotatingSubtitle(for plant: Plant) -> String {
        switch plant.windowDirection {
        case .south, .west:
            "强单侧光，定期转盆避免偏冠和晒伤"
        case .north:
            "北向光较弱，转盆同时观察徒长"
        case .east, .unknown:
            "让受光更均匀"
        }
    }

    private static func repottingSubtitle(for plant: Plant) -> String {
        if plant.isHydroponic {
            return "水培容器、根系和水质需要定期复查"
        }
        if !plant.potHasDrainage {
            return "无排水孔更容易积水，优先检查根系和介质"
        }
        if plant.potDiameterCm > 0, plant.currentHeightCm > plant.potDiameterCm * 4 {
            return "株高明显大于盆径，留意头重脚轻或根系拥挤"
        }
        return "根系拥挤或土壤板结时优先"
    }

    private static func environmentFactors(for plant: Plant) -> [String] {
        var factors = [plant.isIndoor ? "室内" : "阳台/花园", plant.lightLevel.displayName]
        if plant.windowDirection != .unknown {
            factors.append(plant.windowDirection.displayName)
        }
        if plant.lastLightMeasurementLux > 0 {
            factors.append("实测 \(plant.lastLightMeasurementLux) lux")
        }
        if plant.isNearClimateSource {
            factors.append("靠近空调/暖气")
        }
        if !plant.potHasDrainage {
            factors.append("无排水孔")
        }
        if plant.isSucculent {
            factors.append("多肉")
        }
        return factors
    }

    private static func explanation(
        for type: PlantCareType,
        plant: Plant,
        intervalPlan: IntervalPlan
    ) -> String {
        var parts = ["基础 \(intervalPlan.referenceDays) 天"]
        let factors = explanationFactors(for: type, plant: plant)
        if !factors.isEmpty {
            parts.append("\(factors.joined(separator: " + "))影响节奏")
        }
        if intervalPlan.environmentDelta != 0 {
            parts.append("环境周期\(deltaText(intervalPlan.environmentDelta))")
        }
        if !intervalPlan.learning.summary.isEmpty {
            parts.append(intervalPlan.learning.summary)
        }
        parts.append("当前有效周期 \(intervalPlan.effectiveDays) 天")
        return parts.joined(separator: "；")
    }

    private static func explanationFactors(for type: PlantCareType, plant: Plant) -> [String] {
        switch type {
        case .watering:
            var factors: [String] = []
            if plant.isHydroponic { factors.append("水培") }
            if plant.isSucculent { factors.append("多肉") }
            if plant.lightLevel == .direct { factors.append("直射光") }
            if plant.lightLevel == .low { factors.append("弱光") }
            if plant.lastLightMeasurementLux >= 10000 {
                factors.append("高 lux")
            } else if plant.lastLightMeasurementLux > 0, plant.lastLightMeasurementLux < 1000 {
                factors.append("低 lux")
            }
            if plant.windowDirection == .south || plant.windowDirection == .west {
                factors.append(plant.windowDirection.displayName)
            } else if plant.windowDirection == .north {
                factors.append("北向")
            }
            if plant.potDiameterCm > 0, plant.potDiameterCm < 10 {
                factors.append("小盆")
            } else if plant.potDiameterCm >= 24 {
                factors.append("大盆")
            }
            if plant.potMaterial.localizedCaseInsensitiveContains("陶") ||
                plant.potMaterial.localizedCaseInsensitiveContains("terracotta") ||
                plant.potMaterial.localizedCaseInsensitiveContains("clay") {
                factors.append("陶盆")
            }
            if !plant.potHasDrainage { factors.append("无排水孔") }
            if plant.isNearClimateSource { factors.append("空调/暖气旁") }
            if !plant.isIndoor { factors.append("阳台/花园") }
            return factors
        case .fertilizing:
            return [
                plant.isHydroponic ? "水培" : nil,
                plant.isSucculent ? "多肉" : nil,
                plant.healthStatus == .stressed ? "状态紧张" : nil
            ].compactMap(\.self)
        case .leafCleaning:
            return plant.isNearClimateSource ? ["空调/暖气旁"] : []
        case .rotating:
            switch plant.windowDirection {
            case .south, .west:
                return [plant.windowDirection.displayName]
            case .north:
                return ["北向弱光"]
            case .east, .unknown:
                return []
            }
        case .repotting:
            return [
                plant.isHydroponic ? "水培" : nil,
                !plant.potHasDrainage ? "无排水孔" : nil,
                plant.potDiameterCm > 0 && plant.currentHeightCm > plant.potDiameterCm * 4 ? "株高明显大于盆径" : nil
            ].compactMap(\.self)
        case .misting:
            return [
                plant.humidityPreference == .humid ? "喜湿" : nil,
                plant.isNearClimateSource ? "空调/暖气旁" : nil
            ].compactMap(\.self)
        case .pestCheck:
            return plant.healthStatus == .watching || plant.healthStatus == .stressed ? ["健康状态需观察"] : []
        case .pruning:
            return plant.healthStatus == .stressed ? ["状态紧张"] : []
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote:
            return []
        }
    }

    private static func deltaText(_ delta: Int) -> String {
        delta < 0 ? "缩短 \(abs(delta)) 天" : "延长 \(delta) 天"
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
            explanation += "；最近一次跳过/延后反馈已纳入本次到期日"
        }
        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        let plantName = plant.name.isEmpty ? "植物" : plant.name
        return PlantCareTaskSnapshot(
            id: "\(plant.id.uuidString)-\(type.rawValue)-\(Int(dueDay.timeIntervalSince1970))",
            plantID: plant.id,
            careType: type,
            title: "\(type.displayName) · \(plantName)",
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
