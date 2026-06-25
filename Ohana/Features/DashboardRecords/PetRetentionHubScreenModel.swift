//
//  PetRetentionHubScreenModel.swift
//  Ohana
//
//  Snapshot builder for the pet retention hub.
//

import Foundation
import SwiftData

struct PetRetentionArchiveMetrics: Equatable {
    let petID: UUID
    let activitySummary: PetAllFeaturesActivitySummary
    let latestMemoryDate: Date?
    let expiringProtectionCount: Int
    let achievementActivitySummary: AchievementPetActivitySummary
    let isLoaded: Bool

    static func empty(petID: UUID) -> PetRetentionArchiveMetrics {
        PetRetentionArchiveMetrics(
            petID: petID,
            activitySummary: .empty,
            latestMemoryDate: nil,
            expiringProtectionCount: 0,
            achievementActivitySummary: .empty,
            isLoaded: false
        )
    }

    var memoryCount: Int {
        activitySummary.photoCount + activitySummary.milestoneCount
    }

    var protectionCount: Int {
        activitySummary.documentCount + activitySummary.insuranceCount
    }

    var hasHealthBaseline: Bool {
        activitySummary.latestWeightKg != nil || activitySummary.healthCount > 0
    }

    func timelineCount(careLedgerEvents: [CareLedgerEvent]) -> Int {
        let ledgerCount = careLedgerEvents.isEmpty
            ? activitySummary.totalNonFeedingCareCount + activitySummary.totalWalkCount + activitySummary.healthCount + activitySummary.weightCount
            : careLedgerEvents.count { event in
                switch event.eventKindEnum {
                case .care, .walk, .health, .weight:
                    true
                case .potty, .hygiene, .medication, .workout, .expense, .reminder, .plantCare, .coconut, .milestone, .unknown:
                    false
                }
            }
        return memoryCount + ledgerCount
    }

    @MainActor
    static func load(petID: UUID, context: ModelContext, now: Date = Date()) -> PetRetentionArchiveMetrics {
        let activitySummary = PetAllFeaturesActivitySummary.load(petID: petID, context: context, now: now)
        let latestMemoryDateValue = latestMemoryDate(petID: petID, context: context)
        let expiringProtectionCount = expiringProtectionCount(petID: petID, context: context)
        let achievementActivitySummary = AchievementPetActivityRouteData
            .loadPetActivitySummaries(from: context, petIDs: [petID])[petID] ?? .empty
        return PetRetentionArchiveMetrics(
            petID: petID,
            activitySummary: activitySummary,
            latestMemoryDate: latestMemoryDateValue,
            expiringProtectionCount: expiringProtectionCount,
            achievementActivitySummary: achievementActivitySummary,
            isLoaded: true
        )
    }

    @MainActor
    private static func latestMemoryDate(petID: UUID, context: ModelContext) -> Date? {
        var photoDescriptor = FetchDescriptor<PetPhotoLog>(
            predicate: #Predicate<PetPhotoLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        photoDescriptor.fetchLimit = 1
        var milestoneDescriptor = FetchDescriptor<PetMilestone>(
            predicate: #Predicate<PetMilestone> { milestone in
                milestone.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        milestoneDescriptor.fetchLimit = 1
        let latestPhoto = fetch(photoDescriptor, context: context, operation: "fetch latest pet photo").first?.date
        let latestMilestone = fetch(milestoneDescriptor, context: context, operation: "fetch latest pet milestone").first?.date
        return [latestPhoto, latestMilestone].compactMap(\.self).max()
    }

    @MainActor
    private static func expiringProtectionCount(petID: UUID, context: ModelContext) -> Int {
        let documents = fetch(
            FetchDescriptor<PetDocument>(
                predicate: #Predicate<PetDocument> { document in
                    document.pet?.id == petID
                }
            ),
            context: context,
            operation: "fetch pet protection documents"
        )
        let insurances = fetch(
            FetchDescriptor<PetInsurance>(
                predicate: #Predicate<PetInsurance> { insurance in
                    insurance.pet?.id == petID
                }
            ),
            context: context,
            operation: "fetch pet insurances"
        )
        let expiringDocs = documents.count(where: { $0.isExpired || $0.isExpiringSoon })
        let expiringInsurances = insurances.count(where: { $0.daysUntilRenewal <= 30 })
        return expiringDocs + expiringInsurances
    }

    @MainActor
    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning("PetRetentionArchiveMetrics failed to \(operation): \(error.localizedDescription)", category: "DashboardRecords")
            return []
        }
    }
}

struct PetRetentionHubScreenModel {
    let pet: Pet
    var careLedgerEvents: [CareLedgerEvent] = []
    var archiveMetrics: PetRetentionArchiveMetrics

    var achievementProgress: (unlocked: Int, total: Int) {
        let achievements = AchievementManager.compute(
            for: pet,
            context: AchievementComputationContext(
                careLedgerEvents: careLedgerEvents,
                petActivitySummaries: [pet.id: archiveMetrics.achievementActivitySummary]
            )
        )
        return (achievements.filter(\.isUnlocked).count, achievements.count)
    }

    init(
        pet: Pet,
        careLedgerEvents: [CareLedgerEvent] = [],
        archiveMetrics: PetRetentionArchiveMetrics? = nil
    ) {
        self.pet = pet
        self.careLedgerEvents = careLedgerEvents
        self.archiveMetrics = archiveMetrics ?? .empty(petID: pet.id)
    }
}
