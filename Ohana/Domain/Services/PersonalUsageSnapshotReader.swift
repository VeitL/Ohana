//
//  PersonalUsageSnapshotReader.swift
//  Ohana
//
//  Command-time SwiftData projection for Free/Personal quota decisions.
//

import Foundation
import SwiftData

enum PersonalUsageSnapshotReader {
    @MainActor
    static func activePetCount(context: ModelContext) throws -> Int {
        try context.fetchCount(
            FetchDescriptor<Pet>(predicate: #Predicate { $0.passedAwayDate == nil })
        )
    }

    @MainActor
    static func activeHumanCount(context: ModelContext) throws -> Int {
        try context.fetchCount(
            FetchDescriptor<Human>(predicate: #Predicate { $0.passedAwayDate == nil })
        )
    }

    /// Builds one logical usage snapshot at a write boundary. Generated care
    /// recommendations are not user-created plans and therefore never consume
    /// the Free plan allowance.
    @MainActor
    static func snapshot(
        context: ModelContext,
        now: Date = Date()
    ) throws -> PersonalUsageSnapshot {
        let pets = try context.fetch(FetchDescriptor<Pet>())
        let activePetCount = pets.count(where: { !$0.hasPassedAway })
        let activeHumanCount = try activeHumanCount(context: context)
        let activePlantCount = try context.fetchCount(
            FetchDescriptor<Plant>(predicate: #Predicate { $0.archivedAt == nil })
        )
        let candidateEvents = try context.fetch(
            FetchDescriptor<Event>(
                predicate: #Predicate { !$0.isCompleted || $0.recurrenceDays > 0 }
            )
        )
        let activePlanStatus = FamilyTaskPlanStatus.active.rawValue
        let familyTaskPlans = try context.fetch(
            FetchDescriptor<FamilyTaskPlan>(
                predicate: #Predicate<FamilyTaskPlan> { $0.statusRaw == activePlanStatus }
            )
        )
        let familyTaskOccurrences = try context.fetch(FetchDescriptor<FamilyCollaborationTask>())
        let occurrencesByPlan = Dictionary(grouping: familyTaskOccurrences.compactMap { task in
            task.planId.map { ($0, task) }
        }, by: { $0.0 })

        var ordinaryActivePlanKeys = Set<String>()
        var healthCriticalActivePlanKeys = Set<String>()
        for plan in familyTaskPlans where isActiveFamilyTaskPlan(
            plan,
            occurrences: occurrencesByPlan[plan.id.uuidString]?.map(\.1) ?? [],
            now: now
        ) {
            let key = "family-task-plan:\(plan.id.uuidString)"
            let quotaClass = EventType(rawValue: plan.eventTypeRaw)
                .map(PersonalPlanQuotaClassifier.quotaClass(for:)) ?? .ordinary
            switch quotaClass {
            case .ordinary:
                ordinaryActivePlanKeys.insert(key)
            case .healthCritical:
                healthCriticalActivePlanKeys.insert(key)
            }
        }
        for event in candidateEvents where isActivePlan(event, now: now) {
            guard event.familyTaskPlanId == nil else { continue }
            let hasPendingReminder = event.reminders.contains(where: \.isPending)
            guard !CarePlanCalendarSync.isDefaultGeneratedCalendarPlan(event, pets: pets) else { continue }
            guard !PlantCarePlanScheduleService.isGeneratedCalendarPlan(event) else { continue }
            guard !isInformationalProjection(event) else { continue }
            guard !isInactiveModeScopedPlan(
                event,
                pets: pets,
                allEvents: candidateEvents,
                now: now
            ) else { continue }

            if event.eventTypeEnum == .birthday || event.eventTypeEnum == .anniversary {
                guard hasPendingReminder else { continue }
            }

            let quotaClass = event.eventTypeEnum.map(PersonalPlanQuotaClassifier.quotaClass(for:)) ?? .ordinary
            let key = logicalPlanKey(for: event)
            switch quotaClass {
            case .ordinary:
                ordinaryActivePlanKeys.insert(key)
            case .healthCritical:
                healthCriticalActivePlanKeys.insert(key)
            }
        }

        return PersonalUsageSnapshot(
            activePetCount: activePetCount,
            activeHumanCount: activeHumanCount,
            activePlantCount: activePlantCount,
            ordinaryActivePlanCount: ordinaryActivePlanKeys.count,
            healthCriticalActivePlanCount: healthCriticalActivePlanKeys.count
        )
    }

    @MainActor
    static func countsAsOrdinaryActiveUserPlan(
        _ event: Event,
        context: ModelContext,
        now: Date = Date()
    ) throws -> Bool {
        guard event.familyTaskPlanId == nil else { return false }
        guard isActivePlan(event, now: now) else { return false }
        guard event.recurrenceDays > 0 || event.reminders.contains(where: \.isPending) else { return false }
        let quotaClass = event.eventTypeEnum.map(PersonalPlanQuotaClassifier.quotaClass(for:)) ?? .ordinary
        guard quotaClass == .ordinary else { return false }
        let pets = try context.fetch(FetchDescriptor<Pet>())
        guard !CarePlanCalendarSync.isDefaultGeneratedCalendarPlan(event, pets: pets) else { return false }
        guard !PlantCarePlanScheduleService.isGeneratedCalendarPlan(event) else { return false }
        return !isInformationalProjection(event)
    }

    @MainActor
    static func isOrdinaryUserPlanCandidate(
        _ event: Event,
        context: ModelContext,
        now: Date = Date()
    ) throws -> Bool {
        guard event.familyTaskPlanId == nil else { return false }
        let quotaClass = event.eventTypeEnum.map(PersonalPlanQuotaClassifier.quotaClass(for:)) ?? .ordinary
        guard quotaClass == .ordinary else { return false }
        let pets = try context.fetch(FetchDescriptor<Pet>())
        guard !CarePlanCalendarSync.isDefaultGeneratedCalendarPlan(event, pets: pets) else { return false }
        guard !PlantCarePlanScheduleService.isGeneratedCalendarPlan(event) else { return false }
        guard !isInformationalProjection(event) else { return false }
        let allEvents = try context.fetch(FetchDescriptor<Event>())
        return !isInactiveModeScopedPlan(event, pets: pets, allEvents: allEvents, now: now)
    }

    static func logicalPlanKey(for event: Event) -> String {
        if let planID = event.familyTaskPlanId, !planID.isEmpty {
            return "family-task-plan:\(planID)"
        }
        if !event.feedPlanGroupId.isEmpty {
            return "feed-group:\(event.feedPlanGroupId)"
        }
        if !event.feedRuleKindRaw.isEmpty {
            return "feed:\(event.relatedEntityId):\(event.feedRuleKindRaw)"
        }
        if DomainEntityLinkRegistry.role(for: event) == .petWaterPlan {
            return "water:\(event.relatedEntityId)"
        }
        return "event:\(event.id.uuidString)"
    }

    private static func isActivePlan(_ event: Event, now: Date) -> Bool {
        if event.recurrenceDays > 0 {
            guard let recurrenceEndDate = event.recurrenceEndDate else { return true }
            return recurrenceEndDate >= Calendar.current.startOfDay(for: now)
        }
        guard !event.isCompleted else { return false }
        return event.reminders.contains(where: \.isPending)
    }

    private static func isActiveFamilyTaskPlan(
        _ plan: FamilyTaskPlan,
        occurrences: [FamilyCollaborationTask],
        now: Date
    ) -> Bool {
        guard plan.status == .active else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = plan.timeZone
        if let endsAt = plan.endsAt,
           calendar.startOfDay(for: endsAt) < calendar.startOfDay(for: now) {
            return false
        }
        guard plan.recurrenceRule == .once else { return true }
        guard !occurrences.isEmpty else { return plan.anchorAt >= now }
        return occurrences.contains { task in
            task.status == .active || task.status == .claimed || task.status == .pendingReview || task.status == .declined
        }
    }

    private static func isInformationalProjection(_ event: Event) -> Bool {
        let role = DomainEntityLinkRegistry.role(for: event)
        if role == .petFoodStock { return true }
        guard event.eventTypeEnum == .birthday || event.eventTypeEnum == .anniversary else {
            return false
        }
        return role == .directPet || role == .directHuman
    }

    private static func isInactiveModeScopedPlan(
        _ event: Event,
        pets: [Pet],
        allEvents: [Event],
        now: Date
    ) -> Bool {
        guard let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else {
            return false
        }
        if FeedRuleMetadata.isManualReminderEvent(event, pet: pet) {
            return FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: now) != .manualReminder
        }
        if FeedRuleMetadata.isAutoFeederEvent(event, pet: pet) {
            return FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: now) != .autoFeeder
        }
        if WaterPlanWriter.isPlanEvent(event, pet: pet) {
            return WaterOperatingMode.stored(pet.id) == .manual
        }
        return false
    }
}
