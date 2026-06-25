//
//  AchievementPetActivityRouteData.swift
//  Ohana
//
//  Route-scoped activity summaries for achievement computation.
//

import Foundation
import SwiftData

enum AchievementPetActivityRouteData {
    static func loadPetActivitySummaries(
        from context: ModelContext,
        petIDs: Set<UUID>? = nil
    ) -> [UUID: AchievementPetActivitySummary] {
        var summaries: [UUID: AchievementPetActivitySummary] = [:]

        func update(_ petID: UUID?, _ body: (inout AchievementPetActivitySummary) -> Void) {
            guard let petID else { return }
            if let petIDs, !petIDs.contains(petID) { return }
            var summary = summaries[petID] ?? .empty
            body(&summary)
            summaries[petID] = summary
        }

        for record in fetch(
            FetchDescriptor<PetFoodRecord>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]),
            context: context,
            name: "PetFoodRecord"
        ) {
            update(record.pet?.id) { $0.foodRecordDates.append(record.startDate) }
        }

        for log in fetch(
            FetchDescriptor<PetPhotoLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]),
            context: context,
            name: "PetPhotoLog"
        ) {
            update(log.pet?.id) { $0.photoDates.append(log.date) }
        }

        for milestone in fetch(
            FetchDescriptor<PetMilestone>(sortBy: [SortDescriptor(\.date, order: .reverse)]),
            context: context,
            name: "PetMilestone"
        ) {
            update(milestone.pet?.id) { $0.milestoneDates.append(milestone.date) }
        }

        for document in fetch(
            FetchDescriptor<PetDocument>(),
            context: context,
            name: "PetDocument"
        ) {
            update(document.pet?.id) { summary in
                summary.documentCount += 1
                if let issueDate = document.issueDate {
                    summary.documentIssueDates.append(issueDate)
                }
            }
        }

        for insurance in fetch(
            FetchDescriptor<PetInsurance>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
            context: context,
            name: "PetInsurance"
        ) {
            update(insurance.pet?.id) { summary in
                summary.insuranceCount += 1
                summary.insuranceCreatedDates.append(insurance.createdAt)
            }
        }

        for medication in fetch(
            FetchDescriptor<PetMedication>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
            context: context,
            name: "PetMedication"
        ) {
            update(medication.pet?.id) { summary in
                guard medication.isActive, let endDate = medication.endDate else { return }
                summary.activeMedicationEndDates.append(endDate)
            }
        }

        for log in fetch(
            FetchDescriptor<SymptomLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]),
            context: context,
            name: "SymptomLog"
        ) {
            update(log.pet?.id) { $0.symptomDates.append(log.date) }
        }

        return summaries
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
                "Achievement pet activity route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Achievements"
            )
            return []
        }
    }
}
