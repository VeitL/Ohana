import Foundation

@MainActor
enum WalkFeaturePolicy {
    static func canStartWalk(for pet: Pet) -> Bool {
        isDog(pet) && !pet.hasPassedAway
    }

    static func normalizedWalkTargets(_ targets: [Pet], fallback sourcePet: Pet) -> [Pet] {
        SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
            .filter(canStartWalk)
    }

    static func activeWalkLogs(for pet: Pet) -> [PetWalkLog] {
        pet.walkLogs
    }

    static func activePottyLogs(for pet: Pet) -> [PetPottyLog] {
        pet.pottyLogs
    }

    static func activePoopMarkers(for walk: PetWalkLog, pet: Pet) -> [WalkPoopMarker] {
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
