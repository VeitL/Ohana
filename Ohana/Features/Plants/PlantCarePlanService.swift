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

nonisolated enum PlantCarePlanService {
    static func tasks(
        for plant: Plant,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlantCareTaskSnapshot] {
        let wateringDays = intervalDays(for: .watering, plant: plant)
        let fertilizingDays = intervalDays(for: .fertilizing, plant: plant)
        let base = plant.createdAt
        let candidates: [(PlantCareType, Date?, Int, Int, String)] = [
            (.watering, plant.lastWateredDate, wateringDays, 0, lightSubtitle(for: plant)),
            (.fertilizing, plant.lastFertilizedDate, fertilizingDays, 2, "生长期薄肥；冬季可以延后"),
            (.pestCheck, latestCareDate(for: plant, types: [.pestCheck, .pestFound]) ?? plant.lastHealthCheckDate, 21, 1, "查看叶背、土面和新芽"),
            (.leafCleaning, latestCareDate(for: plant, types: [.leafCleaning]), 30, 3, "擦掉灰尘，让叶片更好接光"),
            (.rotating, latestCareDate(for: plant, types: [.rotating]), 14, 4, "让受光更均匀"),
            (.pruning, latestCareDate(for: plant, types: [.pruning]), 60, 5, "剪掉黄叶、枯叶或过密枝叶"),
            (.repotting, latestCareDate(for: plant, types: [.repotting]), 365, 6, "根系拥挤或土壤板结时优先")
        ]

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
            preferredInterval(
                customDays: plant.fertilizingIntervalDays,
                catalogDays: PlantCatalog.entry(id: plant.catalogSpeciesId)?.defaultFertilizingDays,
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

    private static func adjustedWateringDays(for plant: Plant, catalog: PlantCatalogEntry?) -> Int {
        var days = preferredInterval(
            customDays: plant.wateringIntervalDays,
            catalogDays: catalog?.defaultWateringDays,
            fallbackDays: 7
        )
        if plant.lightLevel == .direct {
            days = max(1, days - 2)
        } else if plant.lightLevel == .low {
            days += 2
        }
        if plant.potDiameterCm > 0, plant.potDiameterCm < 10 {
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

    private static func lightSubtitle(for plant: Plant) -> String {
        let placement = plant.isIndoor ? "室内" : "阳台/花园"
        return "\(placement) · \(plant.lightLevel.displayName)，按土壤干湿微调"
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
