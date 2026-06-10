//
//  IslandRetentionDashboardScreenModel.swift
//  Ohana
//
//  Snapshot builder for the retention dashboard.
//

import Foundation

struct RetentionPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let score: Int
    let photos: Int
    let milestones: Int
    let unlocked: Int
    let totalAchievements: Int
}

struct IslandRetentionDashboardScreenModel {
    let pets: [Pet]
    let selectedPetId: UUID?

    var activePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    var summaries: [RetentionPetSummary] {
        selectedPets.map { pet in
            let achievements = AchievementManager.compute(for: pet)
            return RetentionPetSummary(
                id: pet.id,
                pet: pet,
                score: retentionScore(for: pet, achievements: achievements),
                photos: pet.photoLogs.count,
                milestones: pet.milestones.count,
                unlocked: achievements.filter(\.isUnlocked).count,
                totalAchievements: achievements.count
            )
        }
    }

    private func retentionScore(for pet: Pet, achievements: [Achievement]) -> Int {
        [
            !pet.weightLogs.isEmpty || !pet.healthLogs.isEmpty,
            !pet.photoLogs.isEmpty || !pet.milestones.isEmpty,
            !pet.expenseLogs.isEmpty,
            !pet.documents.isEmpty || !pet.insurances.isEmpty || !pet.medications.isEmpty,
            achievements.contains(where: \.isUnlocked) || pet.currentStreak > 0
        ].filter { $0 }.count
    }
}
