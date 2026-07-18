import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PersonalFeaturePlanQuotaTests {
    @Test func freeHygienePlanBoundaryRejectsFourthOrdinaryPlanWithoutWriting() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "dog", breed: "Mixed")
        context.insert(pet)
        for index in 0 ..< PersonalFreeLimits.current.ordinaryActivePlans {
            let event = Event(title: "Existing \(index)", eventType: EventType.task.rawValue)
            event.recurrenceDays = 7
            context.insert(event)
        }
        try context.save()

        let executor = PetHygieneCommandExecutor(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            personalAccessLevel: .free,
            reminderScheduling: ReminderSchedulingManager()
        )
        do {
            _ = try executor.createPlanEnforcingPersonalAccess(
                pet: pet,
                type: .brushing,
                input: PetHygienePlanCommandInput(
                    startDate: Date().addingTimeInterval(3600),
                    isAllDay: false,
                    startTime: Date().addingTimeInterval(3600),
                    hasEndDate: false,
                    endDate: Date().addingTimeInterval(3600),
                    repeatDays: 7,
                    customNote: ""
                ),
                scheduleNotification: false,
                note: "test.personal.hygiene"
            )
            Issue.record("Expected the fourth Free hygiene plan to require Personal")
        } catch let PersonalPlanQuotaCommandError.personalUpgradeRequired(denial) {
            #expect(denial.resource == .ordinaryActivePlan)
            #expect(denial.currentCount == 3)
            #expect(denial.attemptedCount == 4)
        }

        #expect(try context.fetchCount(FetchDescriptor<Event>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<Reminder>()) == 0)
    }

    @Test func healthCriticalPlansRemainExemptAtTheFeatureGate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for index in 0 ..< PersonalFreeLimits.current.ordinaryActivePlans {
            let event = Event(title: "Existing \(index)", eventType: EventType.task.rawValue)
            event.recurrenceDays = 7
            context.insert(event)
        }
        try context.save()

        try PersonalPlanQuotaCommandGate.requirePlanChange(
            context: context,
            personalAccessLevel: .free,
            quotaClass: .healthCritical,
            addingActivePlanCount: 1
        )
    }

    @Test func grandfatheredPlanReplacementIsAllowedButGrowthIsDenied() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var existing: [Event] = []
        for index in 0 ..< 5 {
            let event = Event(title: "Grandfathered \(index)", eventType: EventType.task.rawValue)
            event.recurrenceDays = 7
            context.insert(event)
            existing.append(event)
        }
        try context.save()

        try PersonalPlanQuotaCommandGate.requirePlanChange(
            context: context,
            personalAccessLevel: .free,
            addingActivePlanCount: 1,
            replacingPlans: [existing[0]]
        )

        do {
            try PersonalPlanQuotaCommandGate.requirePlanChange(
                context: context,
                personalAccessLevel: .free,
                addingActivePlanCount: 2,
                replacingPlans: [existing[0]]
            )
            Issue.record("Expected grandfathered growth to require Personal")
        } catch let PersonalPlanQuotaCommandError.personalUpgradeRequired(denial) {
            #expect(denial.preservesGrandfatheredData)
            #expect(denial.currentCount == 5)
            #expect(denial.attemptedCount == 6)
        }
    }

    @Test func defaultGeneratedPetPlanIsExemptWhileExplicitFeaturePlanCounts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "dog", breed: "Mixed")
        context.insert(pet)

        let defaultPlan = Event(title: "Default care", eventType: EventType.daily.rawValue)
        defaultPlan.relatedEntityType = EntityKind.pet.rawValue
        defaultPlan.relatedEntityId = pet.id.uuidString
        defaultPlan.recurrenceDays = 1
        context.insert(defaultPlan)

        let explicitPlan = Event(title: "Play plan", eventType: EventType.task.rawValue)
        explicitPlan.relatedEntityType = EntityKind.pet.rawValue
        explicitPlan.relatedEntityId = pet.id.uuidString
        explicitPlan.recurrenceDays = 3
        context.insert(explicitPlan)
        try context.save()

        let defaultKey = "careCalendarEventId_default_feed_\(pet.id.uuidString)"
        let explicitKey = "careCalendarEventId_play_\(pet.id.uuidString)"
        UserDefaults.standard.set(defaultPlan.id.uuidString, forKey: defaultKey)
        UserDefaults.standard.set(explicitPlan.id.uuidString, forKey: explicitKey)
        defer {
            UserDefaults.standard.removeObject(forKey: defaultKey)
            UserDefaults.standard.removeObject(forKey: explicitKey)
        }

        let usage = try PersonalUsageSnapshotReader.snapshot(context: context)
        #expect(usage.ordinaryActivePlanCount == 1)
    }

    @Test func multiMealFeedScheduleConsumesOneLogicalFreeSlot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "dog", breed: "Mixed")
        context.insert(pet)
        for index in 0 ..< 2 {
            let event = Event(title: "Existing \(index)", eventType: EventType.task.rawValue)
            event.recurrenceDays = 7
            context.insert(event)
        }
        try context.save()

        let executor = QuickFeedCommandExecutor(
            context: context,
            careEvents: CareEventService(),
            revisions: SharedDomainRevisionPublisher(),
            reminderScheduling: ReminderSchedulingManager(),
            personalAccessLevel: .free
        )
        let times = FeedPlanDraft.suggestedTimes(for: 4)
        let draft = FeedPlanDraft(
            kind: .manualReminder,
            dailyCount: 4,
            gramsPerMeal: 40,
            times: times
        )

        let result = try executor.savePlan(
            pet: pet,
            targets: [pet],
            kind: .manualReminder,
            draft: draft,
            allEvents: []
        )

        #expect(result.didChange)
        #expect(try context.fetchCount(FetchDescriptor<Event>()) == 6)
        #expect(try PersonalUsageSnapshotReader.snapshot(context: context).ordinaryActivePlanCount == 3)
    }

    @Test func multiTimeWaterScheduleConsumesOneLogicalFreeSlot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "dog", breed: "Mixed")
        context.insert(pet)
        for index in 0 ..< 2 {
            let event = Event(title: "Existing \(index)", eventType: EventType.task.rawValue)
            event.recurrenceDays = 7
            context.insert(event)
        }
        try context.save()

        let executor = QuickWaterCommandExecutor(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager(),
            personalAccessLevel: .free
        )
        let result = try executor.saveWaterPlan(
            pet: pet,
            targets: [pet],
            times: WaterPlanWriter.suggestedTimes(count: 4),
            count: 4,
            allEvents: []
        )

        #expect(result.optimisticPlanEvents.count == 4)
        #expect(try context.fetchCount(FetchDescriptor<Event>()) == 6)
        #expect(try PersonalUsageSnapshotReader.snapshot(context: context).ordinaryActivePlanCount == 3)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV94.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
