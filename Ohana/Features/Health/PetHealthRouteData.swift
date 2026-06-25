//
//  PetHealthRouteData.swift
//  Ohana
//
//  Route-scoped health rows loaded after the first visible frame.
//

import Foundation
import SwiftData

struct PetHealthRouteData {
    var healthLogs: [PetHealthLog] = []
    var symptomLogs: [SymptomLog] = []
    var heatCycleLogs: [HeatCycleLog] = []
    var alertSource: PetHealthAlertSource?
    var hasLoaded = false

    static func load(petID: UUID, from context: ModelContext) -> PetHealthRouteData {
        let healthLogs = fetchHealthLogs(petID: petID, context: context)
        let symptomLogs = fetchSymptomLogs(petID: petID, context: context)
        let heatCycleLogs = fetchHeatCycleLogs(petID: petID, context: context)
        return PetHealthRouteData(
            healthLogs: healthLogs,
            symptomLogs: symptomLogs,
            heatCycleLogs: heatCycleLogs,
            alertSource: fetchAlertSource(
                petID: petID,
                healthLogs: healthLogs,
                symptomLogs: symptomLogs,
                heatCycleLogs: heatCycleLogs,
                context: context
            ),
            hasLoaded: true
        )
    }

    private static func fetchAlertSource(
        petID: UUID,
        healthLogs: [PetHealthLog],
        symptomLogs: [SymptomLog],
        heatCycleLogs: [HeatCycleLog],
        context: ModelContext
    ) -> PetHealthAlertSource? {
        guard let pet = fetchPet(petID: petID, context: context) else { return nil }
        return PetHealthAlertSource(
            pet: pet,
            healthLogs: healthLogs,
            weightLogs: fetchWeightLogs(petID: petID, context: context),
            careLogs: fetchCareLogs(petID: petID, context: context),
            pottyLogs: fetchPottyLogs(petID: petID, context: context),
            walkLogs: fetchWalkLogs(petID: petID, context: context),
            documents: fetchDocuments(petID: petID, context: context),
            symptomLogs: symptomLogs,
            heatCycleLogs: heatCycleLogs
        )
    }

    private static func fetchPet(petID: UUID, context: ModelContext) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == petID
            }
        )
        descriptor.fetchLimit = 1
        return fetch(descriptor, context: context, name: "Pet").first
    }

    private static func fetchHealthLogs(petID: UUID, context: ModelContext) -> [PetHealthLog] {
        var descriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 600
        return fetch(descriptor, context: context, name: "PetHealthLog")
    }

    private static func fetchSymptomLogs(petID: UUID, context: ModelContext) -> [SymptomLog] {
        var descriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 300
        return fetch(descriptor, context: context, name: "SymptomLog")
    }

    private static func fetchHeatCycleLogs(petID: UUID, context: ModelContext) -> [HeatCycleLog] {
        var descriptor = FetchDescriptor<HeatCycleLog>(
            predicate: #Predicate<HeatCycleLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 160
        return fetch(descriptor, context: context, name: "HeatCycleLog")
    }

    private static func fetchWeightLogs(petID: UUID, context: ModelContext) -> [PetWeightLog] {
        var descriptor = FetchDescriptor<PetWeightLog>(
            predicate: #Predicate<PetWeightLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return fetch(descriptor, context: context, name: "PetWeightLog")
    }

    private static func fetchCareLogs(petID: UUID, context: ModelContext) -> [PetCareLog] {
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 160
        return fetch(descriptor, context: context, name: "PetCareLog")
    }

    private static func fetchPottyLogs(petID: UUID, context: ModelContext) -> [PetPottyLog] {
        var descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return fetch(descriptor, context: context, name: "PetPottyLog")
    }

    private static func fetchWalkLogs(petID: UUID, context: ModelContext) -> [PetWalkLog] {
        var descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return fetch(descriptor, context: context, name: "PetWalkLog")
    }

    private static func fetchDocuments(petID: UUID, context: ModelContext) -> [PetDocument] {
        var descriptor = FetchDescriptor<PetDocument>(
            predicate: #Predicate<PetDocument> { document in
                document.pet?.id == petID
            }
        )
        descriptor.fetchLimit = 80
        return fetch(descriptor, context: context, name: "PetDocument")
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
                "Pet health route data failed to fetch \(name): \(error.localizedDescription)",
                category: "Health"
            )
            return []
        }
    }
}

nonisolated enum PetHealthAlertSourceRouteData {
    static func load(pets: [Pet], from context: ModelContext) -> [PetHealthAlertSource] {
        let activePets = pets.filter(\.canWriteHealthFacts)
        let petIDs = Set(activePets.map(\.id))
        guard !petIDs.isEmpty else { return [] }

        let healthLogsByPetID = groupedByPetID(
            fetch(
                healthDescriptor(limit: 900),
                context: context,
                name: "PetHealthLog"
            ),
            petID: { $0.pet?.id },
            allowedPetIDs: petIDs
        )
        let symptomLogsByPetID = groupedByPetID(
            fetch(
                symptomDescriptor(limit: 500),
                context: context,
                name: "SymptomLog"
            ),
            petID: { $0.pet?.id },
            allowedPetIDs: petIDs
        )
        let heatCycleLogsByPetID = groupedByPetID(
            fetch(
                heatCycleDescriptor(limit: 260),
                context: context,
                name: "HeatCycleLog"
            ),
            petID: { $0.pet?.id },
            allowedPetIDs: petIDs
        )
        let weightLogsByPetID = groupedByPetID(
            fetch(
                weightDescriptor(limit: 260),
                context: context,
                name: "PetWeightLog"
            ),
            petID: { $0.pet?.id },
            allowedPetIDs: petIDs
        )
        let careLogsByPetID = groupedByPetID(
            fetch(
                careDescriptor(limit: 700),
                context: context,
                name: "PetCareLog"
            ),
            petID: { $0.pet?.id },
            allowedPetIDs: petIDs
        )
        let pottyLogsByPetID = groupedByPetID(
            fetch(
                pottyDescriptor(limit: 360),
                context: context,
                name: "PetPottyLog"
            ),
            petID: { $0.pet?.id },
            allowedPetIDs: petIDs
        )
        let walkLogsByPetID = groupedByPetID(
            fetch(
                walkDescriptor(limit: 360),
                context: context,
                name: "PetWalkLog"
            ),
            petID: { $0.pet?.id },
            allowedPetIDs: petIDs
        )
        let documentsByPetID = groupedByPetID(
            fetch(
                documentDescriptor(limit: 360),
                context: context,
                name: "PetDocument"
            ),
            petID: { $0.pet?.id },
            allowedPetIDs: petIDs
        )

        return activePets.map { pet in
            PetHealthAlertSource(
                pet: pet,
                healthLogs: healthLogsByPetID[pet.id] ?? [],
                weightLogs: weightLogsByPetID[pet.id] ?? [],
                careLogs: careLogsByPetID[pet.id] ?? [],
                pottyLogs: pottyLogsByPetID[pet.id] ?? [],
                walkLogs: walkLogsByPetID[pet.id] ?? [],
                documents: documentsByPetID[pet.id] ?? [],
                symptomLogs: symptomLogsByPetID[pet.id] ?? [],
                heatCycleLogs: heatCycleLogsByPetID[pet.id] ?? []
            )
        }
    }

    private static func healthDescriptor(limit: Int) -> FetchDescriptor<PetHealthLog> {
        var descriptor = FetchDescriptor<PetHealthLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    private static func symptomDescriptor(limit: Int) -> FetchDescriptor<SymptomLog> {
        var descriptor = FetchDescriptor<SymptomLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    private static func heatCycleDescriptor(limit: Int) -> FetchDescriptor<HeatCycleLog> {
        var descriptor = FetchDescriptor<HeatCycleLog>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    private static func weightDescriptor(limit: Int) -> FetchDescriptor<PetWeightLog> {
        var descriptor = FetchDescriptor<PetWeightLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    private static func careDescriptor(limit: Int) -> FetchDescriptor<PetCareLog> {
        var descriptor = FetchDescriptor<PetCareLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    private static func pottyDescriptor(limit: Int) -> FetchDescriptor<PetPottyLog> {
        var descriptor = FetchDescriptor<PetPottyLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    private static func walkDescriptor(limit: Int) -> FetchDescriptor<PetWalkLog> {
        var descriptor = FetchDescriptor<PetWalkLog>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    private static func documentDescriptor(limit: Int) -> FetchDescriptor<PetDocument> {
        var descriptor = FetchDescriptor<PetDocument>()
        descriptor.fetchLimit = limit
        return descriptor
    }

    private static func groupedByPetID<T>(
        _ rows: [T],
        petID: (T) -> UUID?,
        allowedPetIDs: Set<UUID>
    ) -> [UUID: [T]] {
        var grouped: [UUID: [T]] = [:]
        for row in rows {
            guard let id = petID(row), allowedPetIDs.contains(id) else { continue }
            grouped[id, default: []].append(row)
        }
        return grouped
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
                "Pet health alert source route data failed to fetch \(name): \(error.localizedDescription)",
                category: "Health"
            )
            return []
        }
    }
}

struct IslandHealthRouteData {
    var pets: [Pet] = []
    var healthLogsByPetID: [UUID: [PetHealthLog]] = [:]
    var hasLoaded = false

    static func load(from context: ModelContext) -> IslandHealthRouteData {
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]),
            context: context,
            name: "Pet"
        )
        let healthLogs = fetch(
            FetchDescriptor<PetHealthLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]),
            context: context,
            name: "PetHealthLog"
        )
        var healthLogsByPetID: [UUID: [PetHealthLog]] = [:]
        for log in healthLogs {
            guard let petID = log.pet?.id else { continue }
            healthLogsByPetID[petID, default: []].append(log)
        }
        return IslandHealthRouteData(
            pets: pets,
            healthLogsByPetID: healthLogsByPetID,
            hasLoaded: true
        )
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
                "Island health route data failed to fetch \(name): \(error.localizedDescription)",
                category: "Health"
            )
            return []
        }
    }
}
