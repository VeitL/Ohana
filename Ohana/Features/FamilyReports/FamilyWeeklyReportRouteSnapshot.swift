//
//  FamilyWeeklyReportRouteSnapshot.swift
//  Ohana
//
//  Route-scoped, sendable weekly report snapshot built off the main actor.
//

import Foundation
import SwiftData

@ModelActor
actor FamilyWeeklyReportRouteDataActor {
    func load(languageCode: String, now: Date = Date()) throws -> FamilyWeeklyReportRouteSnapshot {
        try Task.checkCancellation()
        let snapshot = FamilyWeeklyReportRouteSnapshot.load(
            from: modelContext,
            languageCode: languageCode,
            now: now
        )
        try Task.checkCancellation()
        return snapshot
    }
}

nonisolated struct FamilyWeeklyReportRouteSnapshot: Sendable {
    var visibleHumanCount: Int
    var weekInterval: DateInterval
    var entries: [CareLedgerReportEntry]
    var workloadCount: Int
    var coverageCount: Int
    var petCoverageCount: Int
    var plantCoverageCount: Int
    var rankedMembers: [FamilyWeeklyReportMemberStat]
    var topPet: FamilyWeeklyReportTopPet?
    var mostActiveDay: FamilyWeeklyReportActiveDayStat?
    var photoMemories: [FamilyWeeklyPhotoMemory]
    var weightTrends: [FamilyWeeklyReportWeightTrend]
    var healthAlerts: [HealthAlert]
    var petCoverages: [FamilyWeeklyReportPetCoverage]
    var previousWeeks: [FamilyWeeklyReportWeekTrend]
    var hasLoaded: Bool

    static var empty: FamilyWeeklyReportRouteSnapshot {
        FamilyWeeklyReportRouteSnapshot(
            visibleHumanCount: 0,
            weekInterval: currentWeekInterval(),
            entries: [],
            workloadCount: 0,
            coverageCount: 0,
            petCoverageCount: 0,
            plantCoverageCount: 0,
            rankedMembers: [],
            topPet: nil,
            mostActiveDay: nil,
            photoMemories: [],
            weightTrends: [],
            healthAlerts: [],
            petCoverages: [],
            previousWeeks: emptyPreviousWeeks(),
            hasLoaded: false
        )
    }

    static func load(
        from context: ModelContext,
        languageCode: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FamilyWeeklyReportRouteSnapshot {
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
            context: context,
            name: "Pet"
        )
        let humans = fetch(
            FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
            context: context,
            name: "Human"
        )
        let plants = fetch(
            FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)]),
            context: context,
            name: "Plant"
        )
        let ledgerEvents = fetchLedgerEvents(from: context, now: now, calendar: calendar)
        let activePets = pets.filter { !$0.hasPassedAway }
        let activePlants = plants.filter { !$0.isArchived }
        let visibleHumans = humans.filter { !$0.hasPassedAway }
        let weekInterval = currentWeekInterval(now: now, calendar: calendar)
        let l = L10n(languageCode)
        let statsService = CareLedgerStatsService()
        let entries = statsService.reportEntries(
            events: ledgerEvents,
            pets: activePets,
            plants: activePlants,
            humans: humans,
            interval: weekInterval,
            l: l
        )
        let totals = statsService.totals(
            events: ledgerEvents,
            pets: activePets,
            plants: activePlants,
            interval: weekInterval
        )
        let rankedMembers = rankedMembers(
            from: entries,
            visibleHumans: visibleHumans,
            l: l
        )
        let petCoverages = activePets.map { pet in
            FamilyWeeklyReportPetCoverage(
                pet: pet,
                count: statsService.coverageCount(
                    events: ledgerEvents,
                    pets: [pet],
                    interval: weekInterval
                )
            )
        }
        let healthAlerts = PetHealthAlertEngine().scanAlerts(
            sources: PetHealthAlertSourceRouteData.load(pets: pets, from: context),
            localization: l
        )

        return FamilyWeeklyReportRouteSnapshot(
            visibleHumanCount: visibleHumans.count,
            weekInterval: weekInterval,
            entries: entries,
            workloadCount: totals.workloadCount,
            coverageCount: totals.coverageCount,
            petCoverageCount: totals.petCoverageCount,
            plantCoverageCount: totals.plantCoverageCount,
            rankedMembers: rankedMembers,
            topPet: topPet(from: entries),
            mostActiveDay: mostActiveDay(from: entries, calendar: calendar),
            photoMemories: fetchPhotoMemories(pets: pets, from: context, now: now, calendar: calendar),
            weightTrends: weightTrends(
                pets: activePets,
                ledgerEvents: ledgerEvents,
                weekInterval: weekInterval,
                calendar: calendar
            ),
            healthAlerts: healthAlerts,
            petCoverages: petCoverages,
            previousWeeks: previousWeeks(
                activePets: activePets,
                activePlants: activePlants,
                ledgerEvents: ledgerEvents,
                now: now,
                calendar: calendar,
                statsService: statsService,
                fallbackWeekInterval: weekInterval
            ),
            hasLoaded: true
        )
    }

    private static func rankedMembers(
        from entries: [CareLedgerReportEntry],
        visibleHumans: [Human],
        l: L10n
    ) -> [FamilyWeeklyReportMemberStat] {
        var dict: [String: FamilyWeeklyReportMemberStat] = [:]
        let visibleHumansById = Dictionary(uniqueKeysWithValues: visibleHumans.map { ($0.id.uuidString, $0) })
        for entry in entries {
            let contributorIDs = entry.participantActorIds.isEmpty
                ? [entry.actorId ?? "unknown"]
                : entry.participantActorIds
            for id in contributorIDs {
                guard id == "unknown" || visibleHumansById[id] != nil else { continue }
                let human = visibleHumansById[id]
                let name = human?.name ?? l.tr(zh: "未指定", en: "Unassigned", de: "Nicht zugewiesen")
                let emoji = human?.avatarEmoji ?? "👤"
                var stat = dict[id] ?? FamilyWeeklyReportMemberStat(
                    id: id,
                    name: name,
                    emoji: emoji,
                    count: 0,
                    coconuts: 0
                )
                stat.count += 1
                if id == entry.actorId || (entry.actorId == nil && id == contributorIDs.first) {
                    stat.coconuts += entry.coconuts
                }
                dict[id] = stat
            }
        }
        return dict.values.sorted {
            if $0.count == $1.count { return $0.coconuts > $1.coconuts }
            return $0.count > $1.count
        }
    }

    private static func topPet(from entries: [CareLedgerReportEntry]) -> FamilyWeeklyReportTopPet? {
        let petCoverages = entries.flatMap(\.subjectCoverages).filter(\.isPet)
        let grouped = Dictionary(grouping: petCoverages, by: \.id)
        let ranked: [FamilyWeeklyReportTopPet] = grouped.values
            .compactMap { coverages -> FamilyWeeklyReportTopPet? in
                guard let first = coverages.first else { return nil }
                return FamilyWeeklyReportTopPet(name: first.name, count: coverages.count)
            }
            .sorted { $0.count > $1.count }
        return ranked.first
    }

    private static func mostActiveDay(
        from entries: [CareLedgerReportEntry],
        calendar: Calendar
    ) -> FamilyWeeklyReportActiveDayStat? {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { FamilyWeeklyReportActiveDayStat(date: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count { return $0.date > $1.date }
                return $0.count > $1.count
            }
            .first
    }

    private static func weightTrends(
        pets: [Pet],
        ledgerEvents: [CareLedgerEvent],
        weekInterval: DateInterval,
        calendar: Calendar
    ) -> [FamilyWeeklyReportWeightTrend] {
        pets.compactMap { pet in
            let logs = ledgerEvents
                .filter {
                    $0.subjectKind == CareLedgerSubjectKind.pet.rawValue &&
                        $0.subjectId == pet.id.uuidString &&
                        $0.eventKindEnum == .weight &&
                        $0.occurredAt < weekInterval.end &&
                        $0.amountValue > 0
                }
                .map { FamilyWeeklyReportWeightSample(date: $0.occurredAt, weight: $0.amountValue) }
                .sorted { $0.date < $1.date }
            guard let latest = logs.last else { return nil }
            let baseline = logs.last { $0.date < weekInterval.start } ?? logs.dropLast().last
            guard let baseline else { return nil }
            let days = max(1, calendar.dateComponents([.day], from: baseline.date, to: latest.date).day ?? 1)
            return FamilyWeeklyReportWeightTrend(
                id: pet.id,
                petName: pet.name,
                latestKg: latest.weight,
                deltaKg: latest.weight - baseline.weight,
                days: days
            )
        }
    }

    private static func previousWeeks(
        activePets: [Pet],
        activePlants: [Plant],
        ledgerEvents: [CareLedgerEvent],
        now: Date,
        calendar: Calendar,
        statsService: CareLedgerStatsService,
        fallbackWeekInterval: DateInterval
    ) -> [FamilyWeeklyReportWeekTrend] {
        (0 ..< 4).map { offset in
            let base = calendar.date(byAdding: .weekOfYear, value: -(3 - offset), to: now) ?? now
            let interval = calendar.dateInterval(of: .weekOfYear, for: base) ?? fallbackWeekInterval
            let count = statsService.count(
                events: ledgerEvents,
                pets: activePets,
                plants: activePlants,
                interval: interval
            )
            return FamilyWeeklyReportWeekTrend(label: "W\(offset + 1)", count: count)
        }
    }

    private static func fetchLedgerEvents(
        from context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [CareLedgerEvent] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let plantSubject = CareLedgerSubjectKind.plant.rawValue
        let start = fourWeekWindowStart(now: now, calendar: calendar)
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                (event.subjectKind == petSubject || event.subjectKind == plantSubject) &&
                    event.occurredAt >= start
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1200
        return fetch(descriptor, context: context, name: "CareLedgerEvent")
    }

    private static func fetchPhotoMemories(
        pets: [Pet],
        from context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [FamilyWeeklyPhotoMemory] {
        let activePetNames = Dictionary(uniqueKeysWithValues: pets.filter { !$0.hasPassedAway }.map { ($0.id, $0.name) })
        guard !activePetNames.isEmpty else { return [] }
        let interval = currentWeekInterval(now: now, calendar: calendar)
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<PetPhotoLog>(
            predicate: #Predicate<PetPhotoLog> { log in
                log.date >= start &&
                    log.date < end
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return fetch(descriptor, context: context, name: "PetPhotoLog")
            .compactMap { log in
                guard let petID = log.pet?.id,
                      let petName = activePetNames[petID] else { return nil }
                return FamilyWeeklyPhotoMemory(
                    id: log.id,
                    modelID: log.persistentModelID,
                    petName: petName,
                    imageSignature: log.imageThumbnailSignature,
                    canAttemptImageAttachmentLoad: log.canAttemptImageAttachmentLoad,
                    note: log.note,
                    date: log.date
                )
            }
    }

    private static func fourWeekWindowStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        return calendar.date(byAdding: .weekOfYear, value: -3, to: currentWeekStart)
            ?? currentWeekStart.addingTimeInterval(-21 * 86400)
    }

    private static func currentWeekInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: now)
            ?? DateInterval(start: now.addingTimeInterval(-6 * 86400), duration: 7 * 86400)
    }

    private static func emptyPreviousWeeks() -> [FamilyWeeklyReportWeekTrend] {
        (1 ... 4).map { FamilyWeeklyReportWeekTrend(label: "W\($0)", count: 0) }
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
                "Family weekly report failed to fetch \(name): \(error.localizedDescription)",
                category: "FamilyReports"
            )
            return []
        }
    }
}

nonisolated struct FamilyWeeklyReportMemberStat: Identifiable, Sendable {
    let id: String
    let name: String
    let emoji: String
    var count: Int
    var coconuts: Int
}

nonisolated struct FamilyWeeklyReportTopPet: Sendable {
    let name: String
    let count: Int
}

nonisolated struct FamilyWeeklyReportActiveDayStat: Sendable {
    let date: Date
    let count: Int
}

nonisolated struct FamilyWeeklyReportWeightTrend: Identifiable, Sendable {
    let id: UUID
    let petName: String
    let latestKg: Double
    let deltaKg: Double
    let days: Int
}

private nonisolated struct FamilyWeeklyReportWeightSample {
    let date: Date
    let weight: Double
}

nonisolated struct FamilyWeeklyReportWeekTrend: Sendable {
    let label: String
    let count: Int
}

nonisolated struct FamilyWeeklyReportPetCoverage: Identifiable, Sendable {
    let id: UUID
    let modelID: PersistentIdentifier
    let name: String
    let fallbackText: String
    let themeColorHex: String
    let avatarImageSignature: String
    let count: Int

    init(pet: Pet, count: Int) {
        id = pet.id
        modelID = pet.persistentModelID
        name = pet.name
        fallbackText = pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji
        themeColorHex = pet.safeThemeColorHex
        avatarImageSignature = pet.avatarThumbnailSignature
        self.count = count
    }
}

struct FamilyWeeklyPhotoMemory: Identifiable, Equatable, Sendable {
    let id: UUID
    let modelID: PersistentIdentifier
    let petName: String
    let imageSignature: String
    let canAttemptImageAttachmentLoad: Bool
    let note: String
    let date: Date
}
