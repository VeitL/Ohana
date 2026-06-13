import Foundation

@MainActor
enum WalkFeaturePolicy {
    static func canStartWalk(for pet: Pet) -> Bool {
        isDog(pet) && !pet.hasPassedAway && pet.trashedAt == nil
    }

    static func normalizedWalkTargets(_ targets: [Pet], fallback sourcePet: Pet) -> [Pet] {
        SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
            .filter(canStartWalk)
    }

    static func activeWalkLogs(for pet: Pet) -> [PetWalkLog] {
        guard pet.trashedAt == nil else { return [] }
        return pet.walkLogs.activeRecycleBinItems
    }

    static func activePottyLogs(for pet: Pet) -> [PetPottyLog] {
        guard pet.trashedAt == nil else { return [] }
        return pet.pottyLogs.activeRecycleBinItems
    }

    static func activePoopMarkers(for walk: PetWalkLog, pet: Pet) -> [WalkPoopMarker] {
        guard walk.trashedAt == nil else { return [] }
        let walkID = walk.id.uuidString
        return activePottyLogs(for: pet)
            .filter { $0.walkLogId == walkID }
            .sorted { $0.date < $1.date }
            .map(WalkPoopMarker.init(log:))
    }

    private static func isDog(_ pet: Pet) -> Bool {
        PetSpeciesKey.normalized(pet.species) == "dog"
    }
}
