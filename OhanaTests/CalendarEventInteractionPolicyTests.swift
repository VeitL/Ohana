//
//  CalendarEventInteractionPolicyTests.swift
//  OhanaTests
//

import Foundation
import SwiftData
import Testing
@testable import Ohana

struct CalendarEventInteractionPolicyTests {
    @MainActor
    @Test func userAuthoredPetEventOpensEditableDetailInsteadOfPetRoute() {
        let pet = Pet(name: "Momo", species: "Cat")
        let event = Event(
            title: "Vet vaccine appointment",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.vaccine.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )

        #expect(CalendarEventInteractionPolicy.tapInteraction(for: event, pets: [pet]) == .userEventDetail)
        #expect(CalendarEventInteractionPolicy.allowsUserEventDetail(for: event, pets: [pet]))
        #expect(!CalendarEventInteractionPolicy.shouldOpenRelatedDestination(for: event, pets: [pet]))
    }

    @MainActor
    @Test func generatedFeedingPlanOpensRelatedDestinationInsteadOfEditableDetail() {
        let pet = Pet(name: "Momo", species: "Cat")
        let event = Event(
            title: "Feed Momo",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue

        #expect(CalendarEventInteractionPolicy.tapInteraction(for: event, pets: [pet]) == .relatedDestination)
        #expect(!CalendarEventInteractionPolicy.allowsUserEventDetail(for: event, pets: [pet]))
        #expect(CalendarEventInteractionPolicy.shouldOpenRelatedDestination(for: event, pets: [pet]))
    }

    @MainActor
    @Test func feedTitlePetEventWithoutPlanMetadataOpensEditableDetail() {
        let pet = Pet(name: "Momo", species: "Cat")
        let event = Event(
            title: "Feed Momo after vet visit",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )

        #expect(CalendarEventInteractionPolicy.tapInteraction(for: event, pets: [pet]) == .userEventDetail)
        #expect(CalendarEventInteractionPolicy.allowsUserEventDetail(for: event, pets: [pet]))
        #expect(!CalendarEventInteractionPolicy.shouldOpenRelatedDestination(for: event, pets: [pet]))
    }

    @MainActor
    @Test func userAuthoredFeedingTitlePetEventOpensEditableDetail() {
        let pet = Pet(name: "Momo", species: "Cat")
        let event = Event(
            title: "喂食后观察胃口",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )

        #expect(CalendarEventInteractionPolicy.tapInteraction(for: event, pets: [pet]) == .userEventDetail)
        #expect(CalendarEventInteractionPolicy.allowsUserEventDetail(for: event, pets: [pet]))
        #expect(!CalendarEventInteractionPolicy.shouldOpenRelatedDestination(for: event, pets: [pet]))
    }

    @MainActor
    @Test func generatedWaterPlanAndPlantPlanOpenRelatedDestinations() {
        let pet = Pet(name: "Momo", species: "Cat")
        let water = Event(
            title: "Water reminder",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.daily.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petWaterPlan,
            relatedEntityId: pet.id.uuidString
        )
        let plantID = UUID()
        let plant = Event(
            title: "Pothos · Watering植物计划",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            isAllDay: true,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plantID.uuidString
        )
        plant.recurrenceDays = 7

        #expect(CalendarEventInteractionPolicy.tapInteraction(for: water, pets: [pet]) == .relatedDestination)
        #expect(CalendarEventInteractionPolicy.tapInteraction(for: plant, pets: [pet]) == .relatedDestination)
    }

    @MainActor
    @Test func directPlantEventWithoutPlanMarkerOpensEditableDetail() {
        let plantID = UUID()
        let plant = Event(
            title: "Water plant before vacation",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plantID.uuidString
        )

        #expect(CalendarEventInteractionPolicy.tapInteraction(for: plant, pets: []) == .userEventDetail)
        #expect(CalendarEventInteractionPolicy.allowsUserEventDetail(for: plant, pets: []))
        #expect(!CalendarEventInteractionPolicy.shouldOpenRelatedDestination(for: plant, pets: []))
    }

    @MainActor
    @Test func userEventDetailExposesEditCompleteDeleteActions() {
        let event = Event(
            title: "Buy food",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.task.rawValue
        )

        #expect(CalendarEventInteractionPolicy.detailActions(for: event, allowsEditing: true) == [.edit, .complete, .delete])
    }

    @MainActor
    @Test func informationalEventDetailKeepsCompletionActionHidden() {
        let event = Event(
            title: "Birthday",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.birthday.rawValue
        )

        #expect(CalendarEventInteractionPolicy.detailActions(for: event, allowsEditing: true) == [.edit, .delete])
    }

    @MainActor
    @Test func generatedEventDetailDoesNotExposeEditOrDeleteActions() {
        let event = Event(
            title: "Generated task",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.task.rawValue
        )

        #expect(CalendarEventInteractionPolicy.detailActions(for: event, allowsEditing: false) == [.complete])
    }

    @MainActor
    @Test func familyTaskProjectionOpensReadOnlyDetailWithoutCalendarActions() {
        let event = Event(
            title: "Weekly kitchen duty",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.chore.rawValue
        )
        event.familyTaskPlanId = UUID().uuidString
        event.familyTaskOccurrenceKey = "family-occurrence"

        #expect(CalendarEventInteractionPolicy.tapInteraction(for: event, pets: []) == .userEventDetail)
        #expect(CalendarEventInteractionPolicy.allowsUserEventDetail(for: event, pets: []))
        #expect(!CalendarEventInteractionPolicy.allowsDirectMutation(for: event))
        #expect(CalendarEventInteractionPolicy.detailActions(for: event, allowsEditing: true).isEmpty)
        #expect(CalendarEventInteractionPolicy.detailDeletionScopes(for: event).isEmpty)
    }

    @MainActor
    @Test func calendarCommandsRejectFamilyTaskProjectionMutationWithoutChangingEvent() throws {
        let schema = Schema(ArkSchemaV95.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let event = Event(
            title: "Weekly kitchen duty",
            startDate: start,
            eventType: EventType.chore.rawValue
        )
        event.familyTaskPlanId = UUID().uuidString
        event.familyTaskOccurrenceKey = "family-occurrence"
        context.insert(event)
        try context.save()

        let update = CalendarEventPlanCommandInput(
            title: "Changed outside collaboration",
            startDate: start.addingTimeInterval(3600),
            isAllDay: false,
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: nil,
            assigneeId: nil
        )
        #expect(throws: CalendarCommandError.familyTaskProjectionRequiresCollaboration) {
            try CalendarEventPlanCommandService.updateEvent(
                event: event,
                input: update,
                context: context,
                scheduleNotifications: false
            )
        }
        #expect(throws: CalendarCommandError.familyTaskProjectionRequiresCollaboration) {
            try CalendarEventCommandService.toggleCompletion(
                event: event,
                occurrenceDate: start,
                pets: [],
                context: context,
                executorId: nil
            )
        }
        #expect(throws: CalendarCommandError.familyTaskProjectionRequiresCollaboration) {
            try CalendarEventCommandService.delete(
                event: event,
                occurrenceDate: start,
                scope: .wholeEvent,
                context: context
            )
        }

        #expect(event.title == "Weekly kitchen duty")
        #expect(event.startDate == start)
        #expect(!event.isCompleted)
        #expect(try context.fetchCount(FetchDescriptor<Event>()) == 1)
    }

    @MainActor
    @Test func detailDeleteScopesMirrorSwipeDeleteScopes() {
        let single = Event(
            title: "Single task",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.task.rawValue
        )
        let repeating = Event(
            title: "Repeating task",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.task.rawValue
        )
        repeating.recurrenceDays = 7

        #expect(CalendarEventInteractionPolicy.detailDeletionScopes(for: single) == [.wholeEvent])
        #expect(CalendarEventInteractionPolicy.detailDeletionScopes(for: repeating) == [.singleOccurrence, .thisAndFuture])
    }

    @MainActor
    @Test func readOnlyDetailKeepsScheduleConfigurationOutOfSummary() {
        let event = Event(
            title: "Repeating task",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.task.rawValue
        )
        event.recurrenceDays = 7
        event.reminders = [Reminder(event: event)]

        #expect(!CalendarEventInteractionPolicy.showsScheduleConfigurationInReadOnlyDetail(for: event))
    }

    @Test func swipeableCalendarRowTapOpensUserEventDetailWithEditCompleteDeleteActions() throws {
        let rowSource = try source("Ohana/Shared/Components/SwipeableEventRow.swift")
        let viewSource = try source("Ohana/Features/Calendar/Views/CalendarView.swift")
        let listSource = try source("Ohana/Features/Calendar/Views/CalendarView+List.swift")
        let supportSource = try source("Ohana/Features/Calendar/Views/CalendarViewSupport.swift")

        #expect(rowSource.contains(".highPriorityGesture("))
        #expect(rowSource.contains("TapGesture().onEnded"))
        #expect(rowSource.contains("onOpenDetail?()"))
        #expect(rowSource.contains("var allowsMutation = true"))
        #expect(listSource.contains("allowsMutation: allowsDirectMutation"))
        #expect(!rowSource.contains("showDetail = true"))
        #expect(viewSource.contains("@State var eventDetailPresentation"))
        #expect(viewSource.contains(".fullScreenCover(item: $eventDetailPresentation)"))
        #expect(!viewSource.contains(".sheet(item: $eventDetailPresentation)"))
        #expect(listSource.contains("openEventDetail("))
        #expect(supportSource.contains("struct CalendarEventDetailPresentation"))
        #expect(rowSource.contains("struct CalendarEventDetailPage"))
        #expect(rowSource.contains("calendar-event-detail-page"))
        #expect(!rowSource.contains("calendar-event-detail-sheet"))
        #expect(rowSource.contains("calendar-event-edit-action"))
        #expect(rowSource.contains("calendar-event-complete-action"))
        #expect(rowSource.contains("calendar-event-delete-action"))
    }

    @Test func calendarScrollPositionChangesAreCoalescedOffFrame() throws {
        let viewSource = try source("Ohana/Features/Calendar/Views/CalendarView.swift")
        let listSource = try source("Ohana/Features/Calendar/Views/CalendarView+List.swift")
        let supportSource = try source("Ohana/Features/Calendar/Views/CalendarViewSupport.swift")

        #expect(viewSource.contains("@StateObject var timelinePositionCoordinator"))
        #expect(listSource.contains("scheduleVisibleTimelineDateHandling(from: dateID)"))
        #expect(listSource.contains("timelinePositionCoordinator.scheduleUpdate(to: dateID)"))
        #expect(supportSource.contains("final class CalendarTimelinePositionCoordinator"))
        #expect(supportSource.contains("OhanaFrameScheduler.runAfterNextFrame"))
        #expect(!listSource.contains("guard isCalendarPrepared else { return }\n                    scheduleVisibleCalendarMonthUpdate(from: dateID)"))
    }

    @Test func calendarMemberFilterPreservesTimelinePositionInsteadOfResettingToToday() throws {
        let contentSource = try source("Ohana/Features/Calendar/Views/CalendarView+Content.swift")
        let listSource = try source("Ohana/Features/Calendar/Views/CalendarView+List.swift")
        let viewSource = try source("Ohana/Features/Calendar/Views/CalendarView.swift")

        #expect(viewSource.contains("@State var pendingFilterTimelineAnchorDate"))
        #expect(contentSource.contains("prepareCalendarListForFilterChange()"))
        #expect(contentSource.contains("pendingFilterTimelineAnchorDate = listVisibleTopDate"))
        #expect(contentSource.contains("didScrollListToToday = true"))
        #expect(contentSource.contains("timelinePositionCoordinator.cancel()"))
        #expect(!contentSource.contains("if viewMode == .list {\n                resetCalendarListPositionForModeSwitch()"))
        #expect(listSource.contains("handleTimelineDateSignatureChange(proxy: proxy)"))
        #expect(listSource.contains("stabilizeVisibleTimelinePositionAfterFilterChange(proxy: proxy)"))
        #expect(listSource.contains("stabilizeVisibleTimelinePositionAfterDateSetChange(proxy: proxy)"))
        #expect(listSource.contains("scrollTimeline(proxy, to: fallbackID, animated: false)"))
        #expect(listSource.contains("guard pendingFilterTimelineAnchorDate == nil else"))
        #expect(listSource.contains("pendingFilterTimelineAnchorDate = nil"))
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
