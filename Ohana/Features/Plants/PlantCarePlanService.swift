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
    let dueDate: Date
    let isOverdue: Bool
    let daysUntilDue: Int
    let priority: Int
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
    static func tasks(
        for plant: Plant,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlantCareTaskSnapshot] {
        let wateringDays = intervalDays(for: .watering, plant: plant)
        let fertilizingDays = intervalDays(for: .fertilizing, plant: plant)
        let base = plant.createdAt
        var candidates: [(PlantCareType, Date?, Int, Int, String)] = [
            (.watering, plant.lastWateredDate, wateringDays, 0, wateringSubtitle(for: plant)),
            (.fertilizing, plant.lastFertilizedDate, fertilizingDays, 2, fertilizingSubtitle(for: plant)),
            (.pestCheck, latestCareDate(for: plant, types: [.pestCheck, .pestFound]) ?? plant.lastHealthCheckDate, 21, 1, "查看叶背、土面和新芽"),
            (.leafCleaning, latestCareDate(for: plant, types: [.leafCleaning]), intervalDays(for: .leafCleaning, plant: plant), 3, "擦掉灰尘，让叶片更好接光"),
            (.rotating, latestCareDate(for: plant, types: [.rotating]), intervalDays(for: .rotating, plant: plant), 4, rotatingSubtitle(for: plant)),
            (.pruning, latestCareDate(for: plant, types: [.pruning]), 60, 5, "剪掉黄叶、枯叶或过密枝叶"),
            (.repotting, latestCareDate(for: plant, types: [.repotting]), intervalDays(for: .repotting, plant: plant), 6, repottingSubtitle(for: plant))
        ]
        if shouldScheduleMisting(for: plant) {
            candidates.append((
                .misting,
                latestCareDate(for: plant, types: [.misting]),
                intervalDays(for: .misting, plant: plant),
                3,
                mistingSubtitle(for: plant)
            ))
        }

        return candidates
            .compactMap { type, lastDate, interval, priority, subtitle in
                makeTask(
                    type: type,
                    plant: plant,
                    lastDate: lastDate ?? base,
                    intervalDays: interval,
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

    private static func makeTask(
        type: PlantCareType,
        plant: Plant,
        lastDate: Date,
        intervalDays: Int,
        subtitle: String,
        priority: Int,
        now: Date,
        calendar: Calendar
    ) -> PlantCareTaskSnapshot? {
        var dueDate = calendar.date(byAdding: .day, value: max(intervalDays, 1), to: calendar.startOfDay(for: lastDate))
            ?? calendar.startOfDay(for: lastDate)
        if let deferredDate = deferredUntil(for: type, plant: plant, calendar: calendar),
           deferredDate > dueDate {
            dueDate = deferredDate
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
            dueDate: dueDay,
            isOverdue: dueDay < today,
            daysUntilDue: daysUntilDue,
            priority: priority
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
        let prefix = "defer:\(type.rawValue):"
        let formatter = ISO8601DateFormatter()
        return plant.careLogs
            .filter { $0.careType == .customNote && $0.note.hasPrefix(prefix) }
            .compactMap { log -> Date? in
                let rawDate = String(log.note.dropFirst(prefix.count))
                return formatter.date(from: rawDate)
            }
            .map { calendar.startOfDay(for: $0) }
            .max()
    }
}
