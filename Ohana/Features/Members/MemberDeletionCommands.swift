//
//  MemberDeletionCommands.swift
//  Ohana
//
//  Domain write boundaries for member deletion.
//

import Foundation
import SwiftData

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
        let petID = pet.id
        let petIDString = petID.uuidString
        let relatedEvents = fetchEvents(relatedEntityID: petIDString, context: context)
        for event in relatedEvents {
            context.delete(event)
        }

        let removedQuickActionCount = removeQuickAccessItems(forPetID: petID, userDefaults: userDefaults)
        context.delete(pet)
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
        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? [] // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let hasRemainingHuman = humans.contains { $0.id.uuidString != humanIDString }
        let deletedCurrentHuman = activeHumanID == humanIDString
        let requiresReplacementHuman = !hasRemainingHuman
        let requiresAccountSwitch = deletedCurrentHuman && hasRemainingHuman

        context.delete(human)
        context.safeSave()

        return MemberDeletionCommandResult(
            entityID: humanID,
            kind: EntityKind.human.rawValue,
            removedRelatedEventIDs: [],
            removedQuickActionCount: 0,
            requiresReplacementHuman: requiresReplacementHuman,
            requiresAccountSwitch: requiresAccountSwitch,
            clearsActiveHumanID: deletedCurrentHuman || requiresReplacementHuman
        )
    }

    @discardableResult
    @MainActor
    static func deletePlant(_ plant: Plant, context: ModelContext) -> MemberDeletionCommandResult {
        let plantID = plant.id
        context.delete(plant)
        context.safeSave()

        return MemberDeletionCommandResult(
            entityID: plantID,
            kind: EntityKind.plant.rawValue,
            removedRelatedEventIDs: [],
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
        return (try? context.fetch(descriptor)) ?? []
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
