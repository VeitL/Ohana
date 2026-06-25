//
//  PetMedicationRouteData.swift
//  Ohana
//
//  Route-scoped medication rows loaded after the first visible frame.
//

import Foundation
import SwiftData

struct PetMedicationRouteData {
    var medications: [PetMedication] = []
    var doseEvents: [Event] = []
    var hasLoaded = false

    static func load(petID: UUID, from context: ModelContext, now: Date = Date()) -> PetMedicationRouteData {
        let medications = fetchMedications(petID: petID, context: context)
        return PetMedicationRouteData(
            medications: medications,
            doseEvents: fetchDoseEvents(for: Set(medications.map(\.id)), context: context, now: now),
            hasLoaded: true
        )
    }

    static func loadDoseEvents(medicationID: UUID, from context: ModelContext, now: Date = Date()) -> [Event] {
        fetchDoseEvents(for: [medicationID], context: context, now: now)
    }

    private static func fetchMedications(petID: UUID, context: ModelContext) -> [PetMedication] {
        let descriptor = FetchDescriptor<PetMedication>(
            predicate: #Predicate<PetMedication> { medication in
                medication.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return fetch(descriptor, context: context, name: "PetMedication")
    }

    private static func fetchDoseEvents(for medicationIDs: Set<UUID>, context: ModelContext, now: Date) -> [Event] {
        guard !medicationIDs.isEmpty else { return [] }
        let eventType = EventType.petMedicationDose.rawValue
        let windowStart = Calendar.current.date(byAdding: .day, value: -180, to: now)
            ?? now.addingTimeInterval(-180 * 86400)
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.eventType == eventType &&
                    event.startDate >= windowStart
            },
            sortBy: [SortDescriptor(\Event.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        return fetch(descriptor, context: context, name: "Event")
            .filter { event in
                guard let medicationID = PetMedicationDoseLogging.doseMedicationId(for: event) else { return false }
                return medicationIDs.contains(medicationID)
            }
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
                "Medication route data failed to fetch \(name): \(error.localizedDescription)",
                category: "Medication"
            )
            return []
        }
    }
}

struct IslandMedicationRouteData {
    var pets: [Pet] = []
    var medicationsByPetID: [UUID: [PetMedication]] = [:]
    var hasLoaded = false

    static func load(from context: ModelContext) -> IslandMedicationRouteData {
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]),
            context: context,
            name: "Pet"
        )
        let medications = fetch(
            FetchDescriptor<PetMedication>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
            context: context,
            name: "PetMedication"
        )
        var medicationsByPetID: [UUID: [PetMedication]] = [:]
        for medication in medications {
            guard let petID = medication.pet?.id else { continue }
            medicationsByPetID[petID, default: []].append(medication)
        }
        return IslandMedicationRouteData(
            pets: pets,
            medicationsByPetID: medicationsByPetID,
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
                "Island medication route data failed to fetch \(name): \(error.localizedDescription)",
                category: "Medication"
            )
            return []
        }
    }
}
