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
        var liveTargets = candidates.filter { pet in
            guard EconomyWalletWritePolicy.canWrite(pet), !seen.contains(pet.id) else { return false }
            guard normalizedSpecies(pet.species) == sourceSpecies else { return false }
            seen.insert(pet.id)
            return true
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
        return normalizedTargets(selected, fallback: sourcePet)
    }
}
