//
//  CoHealthDashboardSnapshot.swift
//  Ohana
//
//  Route-scoped value snapshot for human-pet health dashboards.
//

import Foundation
import SwiftData

struct CoHealthDashboardSnapshot: Equatable {
    var humanWeightPoints: [CoHealthWeightPoint] = []
    var associatedPets: [CoHealthPetSnapshot] = []
    var hasLoaded = false

    static let empty = CoHealthDashboardSnapshot()

    static func load(human: Human, context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> CoHealthDashboardSnapshot {
        let humanID = human.id
        let humanName = human.name
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]),
            context: context,
            name: "Pet"
        )
        let humanWeights = fetchHumanWeightLogs(humanID: humanID, context: context)
        let past30Days = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(-29 * 86400)
        let humanWeightPoints = humanWeights
            .filter { $0.date >= past30Days && $0.weight.isFinite }
            .sorted { $0.date < $1.date }
            .suffix(10)
            .enumerated()
            .map { index, log in
                CoHealthWeightPoint(id: log.id, index: index, date: log.date, value: log.weight, label: humanName)
            }

        return CoHealthDashboardSnapshot(
            humanWeightPoints: humanWeightPoints,
            associatedPets: pets.map { pet in
                CoHealthPetSnapshot.load(pet: pet, context: context)
            },
            hasLoaded: true
        )
    }

    var latestHumanWeightKg: Double? {
        humanWeightPoints.sorted { $0.date > $1.date }.first?.value
    }

    func associatedPets(for humanID: UUID, dogsOnly: Bool) -> [CoHealthPetSnapshot] {
        associatedPets.filter { pet in
            (!dogsOnly || pet.species == "狗") && pet.hasWalk(by: humanID)
        }
    }

    func thisMonthWalkKm(for humanID: UUID, pets: [CoHealthPetSnapshot], now: Date = Date(), calendar: Calendar = .current) -> Double {
        let start = calendar.dateInterval(of: .month, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let totalMeters = pets.reduce(0.0) { total, pet in
            total + pet.walkMeters(for: humanID, since: start)
        }
        return totalMeters / 1000
    }

    func petWeightDelta(for pets: [CoHealthPetSnapshot], now: Date = Date(), calendar: Calendar = .current) -> Double? {
        guard let pet = pets.first else { return nil }
        let start = calendar.dateInterval(of: .month, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let points = pet.weightPoints.filter { $0.date >= start }.sorted { $0.date < $1.date }
        guard points.count >= 2, let first = points.first?.value, let last = points.last?.value else { return nil }
        return last - first
    }

    func last7DaysWalkData(for humanID: UUID, pets: [CoHealthPetSnapshot], now: Date = Date(), calendar: Calendar = .current) -> [CoHealthWalkDayPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = AppLanguage.effectiveLocale
        return (0 ..< 7).map { offset in
            let day = calendar.date(byAdding: .day, value: -(6 - offset), to: now)
                ?? now.addingTimeInterval(Double(-(6 - offset)) * 86400)
            let totalMeters = pets.reduce(0.0) { total, pet in
                total + pet.walkMeters(for: humanID, onSameDayAs: day, calendar: calendar)
            }
            let isToday = calendar.isDate(day, inSameDayAs: now)
            let todayLabel = L10n(AppLanguage.code).tr(zh: "今", en: "Today", de: "Heute")
            return CoHealthWalkDayPoint(
                label: isToday ? todayLabel : formatter.string(from: day),
                km: totalMeters / 1000,
                isToday: isToday
            )
        }
    }

    private static func fetchHumanWeightLogs(humanID: UUID, context: ModelContext) -> [HumanWeightLog] {
        var descriptor = FetchDescriptor<HumanWeightLog>(
            predicate: #Predicate<HumanWeightLog> { log in
                log.human?.id == humanID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return fetch(descriptor, context: context, name: "HumanWeightLog")
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "CoHealth dashboard snapshot failed to fetch \(name): \(error.localizedDescription)",
                category: "Health"
            )
            return []
        }
    }
}

struct CoHealthPetSnapshot: Identifiable, Equatable {
    let id: UUID
    let name: String
    let species: String
    let avatarImageData: Data?
    let avatarEmoji: String
    let themeColorHex: String
    let walkEvents: [CoHealthWalkEvent]
    let weightPoints: [CoHealthWeightPoint]

    var latestWeightKg: Double? {
        weightPoints.sorted { $0.date > $1.date }.first?.value
    }

    static func load(pet: Pet, context: ModelContext) -> CoHealthPetSnapshot {
        let petID = pet.id
        return CoHealthPetSnapshot(
            id: petID,
            name: pet.name,
            species: pet.species,
            avatarImageData: pet.avatarImageData,
            avatarEmoji: pet.avatarEmoji,
            themeColorHex: pet.safeThemeColorHex,
            walkEvents: fetchWalkEvents(petID: petID, context: context),
            weightPoints: fetchWeightPoints(petID: petID, petName: pet.name, context: context)
        )
    }

    func hasWalk(by humanID: UUID) -> Bool {
        let id = humanID.uuidString
        return walkEvents.contains { $0.executorIDs.contains(id) }
    }

    func walkMeters(for humanID: UUID, since start: Date) -> Double {
        let id = humanID.uuidString
        return walkEvents
            .filter { $0.date >= start && $0.executorIDs.contains(id) }
            .reduce(0.0) { $0 + $1.distanceMeters }
    }

    func walkMeters(for humanID: UUID, onSameDayAs day: Date, calendar: Calendar) -> Double {
        let id = humanID.uuidString
        return walkEvents
            .filter { $0.executorIDs.contains(id) && calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0.0) { $0 + $1.distanceMeters }
    }

    private static func fetchWalkEvents(petID: UUID, context: ModelContext) -> [CoHealthWalkEvent] {
        let petIDString = petID.uuidString
        let walkKind = CareLedgerEventKind.walk.rawValue
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petIDString &&
                    event.eventKind == walkKind
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 120
        return fetchLedgerEvents(descriptor, context: context, name: "Walk").map { event in
            CoHealthWalkEvent(
                id: event.id,
                date: event.occurredAt,
                distanceMeters: max(0, event.amountValue),
                executorIDs: executorIDs(from: event)
            )
        }
    }

    private static func fetchWeightPoints(petID: UUID, petName: String, context: ModelContext) -> [CoHealthWeightPoint] {
        let petIDString = petID.uuidString
        let weightKind = CareLedgerEventKind.weight.rawValue
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petIDString &&
                    event.eventKind == weightKind
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return fetchLedgerEvents(descriptor, context: context, name: "Weight")
            .filter { $0.amountValue.isFinite && $0.amountValue > 0 }
            .sorted { $0.occurredAt < $1.occurredAt }
            .enumerated()
            .map { index, event in
                CoHealthWeightPoint(
                    id: event.id,
                    index: index,
                    date: event.occurredAt,
                    value: event.amountValue,
                    label: petName
                )
            }
    }

    private static func fetchLedgerEvents(
        _ descriptor: FetchDescriptor<CareLedgerEvent>,
        context: ModelContext,
        name: String
    ) -> [CareLedgerEvent] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "CoHealth pet snapshot failed to fetch \(name) ledger events: \(error.localizedDescription)",
                category: "Health"
            )
            return []
        }
    }

    private static func executorIDs(from event: CareLedgerEvent) -> [String] {
        let metadataExecutorIDs = CareLedgerMetadata.stringArrayValue(named: "executorIds", in: event.metadataJSON)
        let source = metadataExecutorIDs.isEmpty ? [event.actorId].compactMap(\.self) : metadataExecutorIDs
        var seen: Set<String> = []
        return source.compactMap { rawID in
            let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else { return nil }
            return id
        }
    }
}

struct CoHealthWalkEvent: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let distanceMeters: Double
    let executorIDs: [String]
}

struct CoHealthWeightPoint: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let date: Date
    let value: Double
    let label: String
}

struct CoHealthWalkDayPoint: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let km: Double
    let isToday: Bool
}
