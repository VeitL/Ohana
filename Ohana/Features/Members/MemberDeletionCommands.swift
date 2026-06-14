//
//  MemberDeletionCommands.swift
//  Ohana
//
//  Domain write boundaries for member deletion.
//

import Foundation
import SwiftData

@MainActor
private func fetchMemberDeletionModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "MemberDeletionCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

struct MemberDeletionCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let removedRelatedEventIDs: [UUID]
    let removedQuickActionCount: Int
    let requiresReplacementHuman: Bool
    let requiresAccountSwitch: Bool
    let clearsActiveHumanID: Bool
}

enum MemberDeletionCommandService {
    private static let quickActionItemsKey = "quickActionItems_v2"

    @discardableResult
    @MainActor
    static func deletePet(
        _ pet: Pet,
        context: ModelContext,
        userDefaults: UserDefaults = .standard
    ) -> MemberDeletionCommandResult {
        let now = Date()
        let petID = pet.id
        let petIDString = petID.uuidString
        let relatedEvents = fetchEvents(relatedEntityID: petIDString, context: context)
        for event in relatedEvents {
            PhysicalDeletionService.deleteEvent(
                event,
                context: context,
                deletedAt: now
            )
        }

        let removedQuickActionCount = removeQuickAccessItems(forPetID: petID, userDefaults: userDefaults)
        PhysicalDeletionService.deletePet(
            pet,
            context: context,
            deletedAt: now
        )
        context.safeSave()

        return MemberDeletionCommandResult(
            entityID: petID,
            kind: EntityKind.pet.rawValue,
            removedRelatedEventIDs: relatedEvents.map(\.id),
            removedQuickActionCount: removedQuickActionCount,
            requiresReplacementHuman: false,
            requiresAccountSwitch: false,
            clearsActiveHumanID: false
        )
    }

    @discardableResult
    @MainActor
    static func deleteHuman(
        _ human: Human,
        activeHumanID: String,
        context: ModelContext
    ) -> MemberDeletionCommandResult {
        let humanID = human.id
        let humanIDString = humanID.uuidString
        let remainingHumanDescriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { candidate in
                candidate.id != humanID && candidate.passedAwayDate == nil
            }
        )
        let remainingHumans = fetchMemberDeletionModelsOrLog(
            remainingHumanDescriptor,
            context: context,
            operation: "fetch remaining humans for deletion"
        )
        let hasRemainingHuman = !remainingHumans.isEmpty
        let deletedCurrentHuman = activeHumanID == humanIDString
        let requiresReplacementHuman = !hasRemainingHuman
        let requiresAccountSwitch = deletedCurrentHuman && hasRemainingHuman

        let now = Date()
        let relatedEvents = fetchEvents(relatedEntityID: humanIDString, context: context)
        for event in relatedEvents {
            PhysicalDeletionService.deleteEvent(
                event,
                context: context,
                deletedAt: now,
                deletedByHumanId: activeHumanID
            )
        }
        PhysicalDeletionService.deleteHuman(
            human,
            context: context,
            deletedAt: now,
            deletedByHumanId: activeHumanID
        )
        context.safeSave()

        return MemberDeletionCommandResult(
            entityID: humanID,
            kind: EntityKind.human.rawValue,
            removedRelatedEventIDs: relatedEvents.map(\.id),
            removedQuickActionCount: 0,
            requiresReplacementHuman: requiresReplacementHuman,
            requiresAccountSwitch: requiresAccountSwitch,
            clearsActiveHumanID: deletedCurrentHuman || requiresReplacementHuman
        )
    }

    @discardableResult
    @MainActor
    static func deletePlant(_ plant: Plant, context: ModelContext) -> MemberDeletionCommandResult {
        let now = Date()
        let plantID = plant.id
        let relatedEvents = fetchEvents(relatedEntityID: plantID.uuidString, context: context)
        for event in relatedEvents {
            PhysicalDeletionService.deleteEvent(
                event,
                context: context,
                deletedAt: now
            )
        }
        PhysicalDeletionService.deletePlant(
            plant,
            context: context,
            deletedAt: now
        )
        context.safeSave()

        return MemberDeletionCommandResult(
            entityID: plantID,
            kind: EntityKind.plant.rawValue,
            removedRelatedEventIDs: relatedEvents.map(\.id),
            removedQuickActionCount: 0,
            requiresReplacementHuman: false,
            requiresAccountSwitch: false,
            clearsActiveHumanID: false
        )
    }

    @MainActor
    private static func fetchEvents(relatedEntityID: String, context: ModelContext) -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == relatedEntityID
            }
        )
        return fetchMemberDeletionModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch related events for pet deletion"
        )
    }

    private static func removeQuickAccessItems(forPetID petID: UUID, userDefaults: UserDefaults) -> Int {
        guard let json = userDefaults.string(forKey: quickActionItemsKey),
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let items = object as? [[String: Any]]
        else { return 0 }

        let petIDString = petID.uuidString
        var removedCount = 0
        let filtered = items.filter { item in
            let petId = item["petId"] as? String
            let entityId = item["entityId"] as? String
            let entityKindRaw = item["entityKindRaw"] as? String
            let shouldRemove = petId == petIDString || (entityId == petIDString && entityKindRaw == EntityKind.pet.rawValue)
            if shouldRemove {
                removedCount += 1
            }
            return !shouldRemove
        }

        guard removedCount > 0,
              let newData = try? JSONSerialization.data(withJSONObject: filtered, options: []),
              let newJSON = String(data: newData, encoding: .utf8)
        else { return removedCount }
        userDefaults.set(newJSON, forKey: quickActionItemsKey)
        return removedCount
    }
}
