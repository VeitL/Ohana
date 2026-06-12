//
//  IslandFoodDashboardSnapshotStore.swift
//  Ohana
//
//  Cross-pet feeding dashboard read model.
//

import Combine
import Foundation

struct FoodDayPoint: Identifiable {
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    let date: Date
    let grams: Double
    let count: Int
}

struct FoodPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let todayCount: Int
    let todayGrams: Double
    let weekCount: Int
    let weekGrams: Double
}

struct FoodLedgerEntry: Identifiable, Hashable {
    let id: UUID
    let petId: UUID
    let date: Date
    let amountGrams: Double
}

struct FoodStockOverview {
    let remainingGrams: Double
    let totalGrams: Double
    let estimatedDailyGrams: Double

    var hasStock: Bool { totalGrams > 0 }
    var remainingDays: Int? {
        estimatedDailyGrams > 0 ? Int(remainingGrams / estimatedDailyGrams) : nil
    }

    var progress: Double {
        guard totalGrams > 0 else { return 0.04 }
        return max(0.04, min(1, remainingGrams / totalGrams))
    }
}

struct IslandFoodDashboardSnapshot {
    let activePets: [Pet]
    let selectedPets: [Pet]
    let todayFeedCount: Int
    let todayGrams: Double
    let weekFeedCount: Int
    let weekGrams: Double
    let dailyPoints: [FoodDayPoint]
    let petSummaries: [FoodPetSummary]
    let lowestFoodDaysPet: Pet?
    let stockByPetID: [UUID: FoodStockOverview]

    static let empty = IslandFoodDashboardSnapshot(
        activePets: [],
        selectedPets: [],
        todayFeedCount: 0,
        todayGrams: 0,
        weekFeedCount: 0,
        weekGrams: 0,
        dailyPoints: [],
        petSummaries: [],
        lowestFoodDaysPet: nil,
        stockByPetID: [:]
    )

    static func build(
        pets: [Pet],
        selectedPetId: UUID?,
        allEvents: [Event],
        allFeedingLedgerEvents: [CareLedgerEvent],
        legacyStockCareLogs: [PetCareLog],
        allFoodRecords: [PetFoodRecord],
        allSharedCareSessions: [SharedCareSession] = [],
        now: Date,
        calendar: Calendar = .current
    ) -> IslandFoodDashboardSnapshot {
        let activePets = pets
            .filter { !$0.hasPassedAway }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let selectedPets = selectedPetId.map { id in
            activePets.filter { $0.id == id }
        } ?? activePets
        let today = calendar.startOfDay(for: now)
        let cutoff = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let activePetsByID = petsByID(activePets)
        let ledgerEntries = feedingLedgerEntries(from: allFeedingLedgerEvents)
        let ledgerEntriesByPetID = Dictionary(grouping: ledgerEntries, by: \.petId)
        let legacyStockLogsByPetID = Dictionary(grouping: legacyStockCareLogs.compactMap { log -> (UUID, PetCareLog)? in
            guard log.careType == .feeding, let petID = log.pet?.id else { return nil }
            return (petID, log)
        }, by: \.0)
            .mapValues { $0.map(\.1) }
        let recordsByPetID = Dictionary(grouping: allFoodRecords.compactMap { record -> (UUID, PetFoodRecord)? in
            guard let petID = record.pet?.id else { return nil }
            return (petID, record)
        }, by: \.0)
            .mapValues { $0.map(\.1) }

        let entriesByPetID = Dictionary(uniqueKeysWithValues: activePets.map { pet in
            (pet.id, ledgerEntriesByPetID[pet.id] ?? [])
        })
        let selectedLogs = selectedPets.flatMap { entriesByPetID[$0.id] ?? [] }
        let todayLogs = selectedLogs.filter { calendar.isDate($0.date, inSameDayAs: now) }
        let weekLogs = selectedLogs.filter { $0.date >= cutoff }
        let dailyPoints = (0 ..< 7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayLogs = selectedLogs.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return FoodDayPoint(
                date: day,
                grams: dayLogs.reduce(0) { $0 + amountGrams(for: $1, petsByID: activePetsByID) },
                count: dayLogs.count
            )
        }
        let petSummaries = selectedPets.map { pet in
            let petLogs = entriesByPetID[pet.id] ?? []
            let todayLogs = petLogs.filter { calendar.isDate($0.date, inSameDayAs: now) }
            let weekLogs = petLogs.filter { $0.date >= cutoff }
            return FoodPetSummary(
                id: pet.id,
                pet: pet,
                todayCount: todayLogs.count,
                todayGrams: todayLogs.reduce(0) { $0 + amountGrams(for: $1, petsByID: activePetsByID) },
                weekCount: weekLogs.count,
                weekGrams: weekLogs.reduce(0) { $0 + amountGrams(for: $1, petsByID: activePetsByID) }
            )
        }
        let stockByPetID = Dictionary(uniqueKeysWithValues: selectedPets.compactMap { pet -> (UUID, FoodStockOverview)? in
            guard let stock = foodStockOverview(
                for: pet,
                allEvents: allEvents,
                legacyStockCareLogs: legacyStockLogsByPetID[pet.id] ?? [],
                foodRecords: recordsByPetID[pet.id] ?? [],
                sharedCareSessions: allSharedCareSessions,
                now: now,
                calendar: calendar
            ) else { return nil }
            return (pet.id, stock)
        })
        let lowestFoodDaysPet = selectedPets
            .filter { stockByPetID[$0.id]?.remainingDays != nil }
            .min {
                (stockByPetID[$0.id]?.remainingDays ?? Int.max) <
                    (stockByPetID[$1.id]?.remainingDays ?? Int.max)
            }

        return IslandFoodDashboardSnapshot(
            activePets: activePets,
            selectedPets: selectedPets,
            todayFeedCount: todayLogs.count,
            todayGrams: todayLogs.reduce(0) { $0 + amountGrams(for: $1, petsByID: activePetsByID) },
            weekFeedCount: weekLogs.count,
            weekGrams: weekLogs.reduce(0) { $0 + amountGrams(for: $1, petsByID: activePetsByID) },
            dailyPoints: dailyPoints,
            petSummaries: petSummaries,
            lowestFoodDaysPet: lowestFoodDaysPet,
            stockByPetID: stockByPetID
        )
    }

    func stock(for pet: Pet) -> FoodStockOverview? {
        stockByPetID[pet.id]
    }

    private static func feedingLedgerEntries(from events: [CareLedgerEvent]) -> [FoodLedgerEntry] {
        events.compactMap { event in
            guard event.eventKindEnum == .care,
                  event.actionType == CareType.feeding.rawValue,
                  event.subjectKind == CareLedgerSubjectKind.pet.rawValue,
                  let subjectId = event.subjectId,
                  let petId = UUID(uuidString: subjectId)
            else { return nil }
            return FoodLedgerEntry(
                id: event.id,
                petId: petId,
                date: event.occurredAt,
                amountGrams: max(0, event.amountValue)
            )
        }
        .sorted { $0.date > $1.date }
    }

    private static func petsByID(_ pets: [Pet]) -> [UUID: Pet] {
        Dictionary(uniqueKeysWithValues: pets.map { ($0.id, $0) })
    }

    private static func amountGrams(for entry: FoodLedgerEntry, petsByID: [UUID: Pet]) -> Double {
        if entry.amountGrams > 0 { return entry.amountGrams }
        return petsByID[entry.petId]?.dailyPortionGrams ?? 0
    }

    private static func foodStockOverview(
        for pet: Pet,
        allEvents: [Event],
        legacyStockCareLogs: [PetCareLog],
        foodRecords: [PetFoodRecord],
        sharedCareSessions: [SharedCareSession],
        now: Date,
        calendar: Calendar
    ) -> FoodStockOverview? {
        let dry = FeedStockCalculator.snapshot(
            for: pet,
            foodKind: .dry,
            events: allEvents,
            careLogs: legacyStockCareLogs,
            foodRecords: foodRecords,
            sharedCareSessions: sharedCareSessions,
            now: now,
            calendar: calendar
        )
        let wet = FeedStockCalculator.snapshot(
            for: pet,
            foodKind: .wet,
            events: allEvents,
            careLogs: legacyStockCareLogs,
            foodRecords: foodRecords,
            sharedCareSessions: sharedCareSessions,
            now: now,
            calendar: calendar
        )
        let modernTotal = dry.totalGrams + wet.totalGrams
        if modernTotal > 0 {
            return FoodStockOverview(
                remainingGrams: dry.remainingGrams + wet.remainingGrams,
                totalGrams: modernTotal,
                estimatedDailyGrams: dry.estimatedDailyGrams + wet.estimatedDailyGrams
            )
        }

        switch pet.foodTrackingMode {
        case .precise:
            guard pet.restockWeight > 0 else { return nil }
            return FoodStockOverview(
                remainingGrams: pet.remainingFoodGrams,
                totalGrams: pet.restockWeight,
                estimatedDailyGrams: pet.dailyPortionGrams
            )
        case .casual:
            guard let days = pet.casualRemainingDays, pet.casualDurationDays > 0 else { return nil }
            let progress = max(0.04, min(1, Double(days) / Double(pet.casualDurationDays)))
            return FoodStockOverview(
                remainingGrams: Double(days),
                totalGrams: Double(pet.casualDurationDays),
                estimatedDailyGrams: progress > 0 ? 1 : 0
            )
        }
    }
}

struct IslandFoodDashboardSnapshotRevision: Equatable {
    let petRevision: Int
    let eventRevision: Int
    let feedingLedgerRevision: Int
    let legacyStockLogRevision: Int
    let foodRecordRevision: Int
    let sharedSessionRevision: Int
    let selectedPetRawValue: String
    let timeRevision: Int

    static func make(
        pets: [Pet],
        selectedPetId: UUID?,
        allEvents: [Event],
        allFeedingLedgerEvents: [CareLedgerEvent],
        legacyStockCareLogs: [PetCareLog],
        allFoodRecords: [PetFoodRecord],
        allSharedCareSessions: [SharedCareSession],
        now: Date
    ) -> IslandFoodDashboardSnapshotRevision {
        IslandFoodDashboardSnapshotRevision(
            petRevision: revisionHash(pets.prefix(80)) { hasher, pet in
                hasher.combine(pet.id)
                hasher.combine(pet.name)
                hasher.combine(pet.hasPassedAway)
                hasher.combine(pet.restockWeight)
                hasher.combine(pet.remainingFoodGrams)
                hasher.combine(pet.dailyPortionGrams)
                hasher.combine(pet.foodTrackingModeRaw)
                hasher.combine(pet.casualRemainingDays ?? -1)
                hasher.combine(pet.casualDurationDays)
            },
            eventRevision: revisionHash(allEvents.prefix(160)) { hasher, event in
                hasher.combine(event.id)
                hasher.combine(event.startDate.timeIntervalSince1970)
                hasher.combine(event.relatedEntityType)
                hasher.combine(event.relatedEntityId)
                hasher.combine(event.feedRuleKindRaw)
                hasher.combine(event.foodKindRaw)
                hasher.combine(event.feedAmountGrams)
            },
            feedingLedgerRevision: revisionHash(allFeedingLedgerEvents.prefix(500)) { hasher, event in
                hasher.combine(event.id)
                hasher.combine(event.occurredAt.timeIntervalSince1970)
                hasher.combine(event.subjectId)
                hasher.combine(event.actionType)
                hasher.combine(event.amountValue)
            },
            legacyStockLogRevision: revisionHash(legacyStockCareLogs.prefix(500)) { hasher, log in
                hasher.combine(log.id)
                hasher.combine(log.date.timeIntervalSince1970)
                hasher.combine(log.amountGrams)
                hasher.combine(log.type)
                hasher.combine(log.pet?.id)
                hasher.combine(log.foodKindRaw)
                hasher.combine(log.note)
            },
            foodRecordRevision: revisionHash(allFoodRecords.prefix(220)) { hasher, record in
                hasher.combine(record.id)
                hasher.combine(record.pet?.id)
                hasher.combine(record.startDate.timeIntervalSince1970)
                hasher.combine(record.totalGrams)
                hasher.combine(record.foodKindRaw)
                hasher.combine(record.remainingCorrectionGrams ?? -1)
                hasher.combine(record.remainingCorrectionDate?.timeIntervalSince1970 ?? 0)
            },
            sharedSessionRevision: revisionHash(allSharedCareSessions.prefix(220)) { hasher, session in
                hasher.combine(session.id)
                hasher.combine(session.date.timeIntervalSince1970)
                hasher.combine(session.actionKindRaw)
                hasher.combine(session.stockOwnerPetId)
                hasher.combine(session.totalAmountGrams)
            },
            selectedPetRawValue: selectedPetId?.uuidString ?? "all",
            timeRevision: Int(now.timeIntervalSince1970 / 60)
        )
    }

    private static func revisionHash<Element>(
        _ values: some Sequence<Element>,
        combine: (inout Hasher, Element) -> Void
    ) -> Int {
        var hasher = Hasher()
        var count = 0
        for value in values {
            combine(&hasher, value)
            count += 1
        }
        hasher.combine(count)
        return hasher.finalize()
    }
}

@MainActor
final class IslandFoodDashboardSnapshotStore: ObservableObject {
    @Published private(set) var snapshot = IslandFoodDashboardSnapshot.empty
    private var revision: IslandFoodDashboardSnapshotRevision?

    func rebuild(
        pets: [Pet],
        selectedPetId: UUID?,
        allEvents: [Event],
        allFeedingLedgerEvents: [CareLedgerEvent],
        legacyStockCareLogs: [PetCareLog],
        allFoodRecords: [PetFoodRecord],
        allSharedCareSessions: [SharedCareSession],
        now: Date = Date(),
        force: Bool = false
    ) {
        let nextRevision = IslandFoodDashboardSnapshotRevision.make(
            pets: pets,
            selectedPetId: selectedPetId,
            allEvents: allEvents,
            allFeedingLedgerEvents: allFeedingLedgerEvents,
            legacyStockCareLogs: legacyStockCareLogs,
            allFoodRecords: allFoodRecords,
            allSharedCareSessions: allSharedCareSessions,
            now: now
        )
        guard force || nextRevision != revision else { return }
        snapshot = IslandFoodDashboardSnapshot.build(
            pets: pets,
            selectedPetId: selectedPetId,
            allEvents: allEvents,
            allFeedingLedgerEvents: allFeedingLedgerEvents,
            legacyStockCareLogs: legacyStockCareLogs,
            allFoodRecords: allFoodRecords,
            allSharedCareSessions: allSharedCareSessions,
            now: now
        )
        revision = nextRevision
    }
}
