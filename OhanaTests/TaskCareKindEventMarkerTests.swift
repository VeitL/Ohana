import Foundation
import Testing
@testable import Ohana

@MainActor
struct TaskCareKindEventMarkerTests {
    @Test func eventAndScheduleWriterDefaultToNoTypedCareMarker() {
        let event = Event(title: "Ordinary task")
        let intent = DomainScheduleCreateIntent(
            title: "Ordinary task",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            writeKind: .care
        )
        let unpersistedEvent = DomainScheduleWriter.makeUnpersistedEvent(intent: intent)

        #expect(event.taskCareKindRaw.isEmpty)
        #expect(intent.taskCareKindRaw.isEmpty)
        #expect(unpersistedEvent.taskCareKindRaw.isEmpty)
    }

    @Test func scheduleIntentAndWriterPreserveTypedCareMarkerAcrossCopies() {
        let rawValue = TaskCareKind.plantWatering.rawValue
        let intent = DomainScheduleCreateIntent(
            title: "Water Fern",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: UUID().uuidString,
            assigneeId: UUID().uuidString,
            taskCareKindRaw: rawValue,
            writeKind: .care
        )
        let event = DomainScheduleWriter.makeUnpersistedEvent(intent: intent)
        let copiedIntent = DomainScheduleCreateIntent(
            event: event,
            writeKind: .care
        )
        let reassignedIntent = copiedIntent.withAssigneeId(UUID().uuidString)

        #expect(event.taskCareKindRaw == rawValue)
        #expect(copiedIntent.taskCareKindRaw == rawValue)
        #expect(reassignedIntent.taskCareKindRaw == rawValue)
    }

    @Test func calendarPlanInputCarriesTypedCareMarkerWithoutChangingLegacyDefault() {
        let commonDate = Date(timeIntervalSince1970: 1_800_000_000)
        let typed = CalendarEventPlanCommandInput(
            title: "Feed Momo",
            startDate: commonDate,
            isAllDay: false,
            eventType: .daily,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString,
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: 0,
            assigneeId: nil,
            taskCareKindRaw: TaskCareKind.petFeeding.rawValue
        )
        let legacy = CalendarEventPlanCommandInput(
            title: "Ordinary task",
            startDate: commonDate,
            isAllDay: false,
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: nil,
            assigneeId: nil
        )

        #expect(typed.taskCareKindRaw == TaskCareKind.petFeeding.rawValue)
        #expect(legacy.taskCareKindRaw.isEmpty)
    }

    @Test func petCompletionResolversPreferTypedMarkerOverEditableTitle() {
        let feeding = Event(
            title: "A title without care keywords",
            taskCareKindRaw: TaskCareKind.petFeeding.rawValue
        )
        let teeth = Event(
            title: "Bath",
            eventType: EventType.grooming.rawValue,
            taskCareKindRaw: TaskCareKind.petHygieneTeeth.rawValue
        )
        let potty = Event(
            title: "A title without care keywords",
            taskCareKindRaw: TaskCareKind.petPotty.rawValue
        )

        #expect(CalendarTaskCompletionSyncService.careType(for: feeding) == .feeding)
        #expect(CalendarTaskCompletionSyncService.hygieneType(for: teeth) == .teeth)
        #expect(CalendarTaskCompletionSyncService.pottyType(for: potty) == .perfectPoop)
    }

    @Test func nonemptyTypedMarkerNeverFallsBackToLegacyTitleHeuristics() {
        let plantMarkerWithPetTitle = Event(
            title: "Feed and bathe",
            eventType: EventType.grooming.rawValue,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )
        let unknownMarkerWithPetTitle = Event(
            title: "Feed and bathe",
            eventType: EventType.grooming.rawValue,
            taskCareKindRaw: "unknown.care.kind"
        )

        for event in [plantMarkerWithPetTitle, unknownMarkerWithPetTitle] {
            #expect(CalendarTaskCompletionSyncService.careType(for: event) == nil)
            #expect(CalendarTaskCompletionSyncService.pottyType(for: event) == nil)
            #expect(CalendarTaskCompletionSyncService.hygieneType(for: event) == nil)
        }
    }

    @Test func emptyMarkerRetainsLegacyPetCompletionBehavior() {
        let feeding = Event(title: "Feed Momo")
        let hygiene = Event(
            title: "Brush Momo",
            eventType: EventType.grooming.rawValue
        )

        #expect(CalendarTaskCompletionSyncService.careType(for: feeding) == .feeding)
        #expect(CalendarTaskCompletionSyncService.hygieneType(for: hygiene) == .brushing)
    }

    @Test func typedPlantMarkerIsActionableButUnmarkedManualPlantEventIsNot() {
        let plantID = UUID()
        let typed = Event(
            title: "Anything",
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plantID.uuidString,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )
        let unmarkedManual = Event(
            title: "Water Fern",
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plantID.uuidString
        )

        #expect(PlantCareScheduleSyncService.careType(for: typed) == .watering)
        #expect(PlantCareScheduleSyncService.isPlantCareEvent(typed))
        #expect(PlantCareScheduleSyncService.careType(for: unmarkedManual) == .watering)
        #expect(!PlantCareScheduleSyncService.isPlantCareEvent(unmarkedManual))
    }

    @Test func emptyMarkerRetainsGeneratedPlantPlanBehavior() {
        let event = Event(
            title: "Fern \(PlantReminderPreferenceStore.generatedPlanTitleMarker)",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            isAllDay: true,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: UUID().uuidString
        )
        event.recurrenceDays = 1

        #expect(event.taskCareKindRaw.isEmpty)
        #expect(PlantCareScheduleSyncService.isPlantCareEvent(event))
        #expect(PlantCareScheduleSyncService.careType(for: event) == .watering)
    }
}
