//
//  SharedPetTargetResolver.swift
//  Ohana
//

import Foundation
import SwiftData

enum SharedPetTargetResolver {
    static func normalizedSpecies(_ value: String) -> String {
        PetSpeciesKey.normalized(value)
    }

    @MainActor
    static func normalizedTargets(_ targets: [Pet], fallback sourcePet: Pet) -> [Pet] {
        guard EconomyWalletWritePolicy.canWrite(sourcePet) else { return [] }
        let candidates = targets.isEmpty ? [sourcePet] : targets
        let sourceSpecies = normalizedSpecies(sourcePet.species)
        var seen = Set<UUID>()
        var liveTargets: [Pet] = []
        for pet in candidates {
            guard EconomyWalletWritePolicy.canWrite(pet),
                  normalizedSpecies(pet.species) == sourceSpecies else {
                // A stale multi-target selection is one user intent. Do not
                // silently turn it into a smaller, partially successful write.
                return []
            }
            guard !seen.contains(pet.id) else { continue }
            seen.insert(pet.id)
            liveTargets.append(pet)
        }
        if EconomyWalletWritePolicy.canWrite(sourcePet), !liveTargets.contains(where: { $0.id == sourcePet.id }) {
            liveTargets.insert(sourcePet, at: 0)
        }
        return liveTargets.sorted { lhs, rhs in
            if lhs.id == sourcePet.id { return true }
            if rhs.id == sourcePet.id { return false }
            return lhs.createdAt < rhs.createdAt
        }
    }

    @MainActor
    static func sameSpeciesTargets(sourcePet: Pet, allPets: [Pet], explicitTargetIds: Set<UUID> = []) -> [Pet] {
        let species = normalizedSpecies(sourcePet.species)
        let sameSpecies = allPets.filter { pet in
            EconomyWalletWritePolicy.canWrite(pet) && normalizedSpecies(pet.species) == species
        }
        let selected = explicitTargetIds.isEmpty ? sameSpecies : sameSpecies.filter { explicitTargetIds.contains($0.id) }
        if !explicitTargetIds.isEmpty,
           Set(selected.map(\.id)) != explicitTargetIds {
            return []
        }
        return normalizedTargets(selected, fallback: sourcePet)
    }
}
