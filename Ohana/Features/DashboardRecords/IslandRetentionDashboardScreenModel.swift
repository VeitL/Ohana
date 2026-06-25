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
    let documents: Int
    let unlocked: Int
    let totalAchievements: Int
}

struct IslandRetentionDashboardScreenModel {
    let pets: [Pet]
    let selectedPetId: UUID?
    var careLedgerEvents: [CareLedgerEvent] = []
    var archiveMetricsByPetId: [UUID: PetRetentionArchiveMetrics] = [:]

    var activePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    var summaries: [RetentionPetSummary] {
        selectedPets.map { pet in
            let metrics = archiveMetrics(for: pet.id)
            let context = AchievementComputationContext(
                careLedgerEvents: careLedgerEvents,
                petActivitySummaries: [pet.id: metrics.achievementActivitySummary]
            )
            let achievements = AchievementManager.compute(for: pet, context: context)
            return RetentionPetSummary(
                id: pet.id,
                pet: pet,
                score: retentionScore(for: pet, metrics: metrics, achievements: achievements),
                photos: metrics.activitySummary.photoCount,
                milestones: metrics.activitySummary.milestoneCount,
                documents: metrics.activitySummary.documentCount,
                unlocked: achievements.filter(\.isUnlocked).count,
                totalAchievements: achievements.count
            )
        }
    }

    func archiveMetrics(for petID: UUID) -> PetRetentionArchiveMetrics {
        archiveMetricsByPetId[petID] ?? .empty(petID: petID)
    }

    private func retentionScore(for pet: Pet, metrics: PetRetentionArchiveMetrics, achievements: [Achievement]) -> Int {
        let activitySummary = metrics.activitySummary
        return [
            activitySummary.weightCount > 0 || activitySummary.healthCount > 0,
            activitySummary.photoCount > 0 || activitySummary.milestoneCount > 0,
            activitySummary.expenseCount > 0,
            activitySummary.documentCount > 0 || activitySummary.insuranceCount > 0 || activitySummary.medicationCount > 0,
            achievements.contains(where: \.isUnlocked) || pet.currentStreak > 0
        ].count(where: { $0 })
    }
}
