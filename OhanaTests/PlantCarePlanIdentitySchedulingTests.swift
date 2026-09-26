import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PlantCarePlanIdentitySchedulingTests {
    @Test func structuredIdentityIsStableAndDoesNotClaimOrdinaryTypedPlantTask() {
        let plantID = UUID()
        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plantID, careType: .watering)
        let repeatedID = PlantCarePlanIdentity.expectedEventID(plantID: plantID, careType: .watering)
        let otherCareID = PlantCarePlanIdentity.expectedEventID(plantID: plantID, careType: .fertilizing)

        let generated = makePlanEvent(
            id: expectedID,
            title: "Water Fern",
            plantID: plantID,
            careType: .watering,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )
        let ordinary = makePlanEvent(
            id: UUID(),
            title: "Water Fern",
            plantID: plantID,
            careType: .watering,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )

        #expect(expectedID == repeatedID)
        #expect(expectedID != otherCareID)
        #expect(PlantCarePlanIdentity.isStructuredMatch(generated, plantID: plantID, careType: .watering))
        #expect(PlantCarePlanIdentity.isGeneratedPlan(generated))
        #expect(!PlantCarePlanIdentity.isGeneratedPlan(ordinary))
        #expect(!PlantReminderPreferenceStore.isGeneratedPlantCareEvent(ordinary))
        #expect(!PlantCarePlanScheduleService.isGeneratedCalendarPlan(ordinary))
    }

    @Test func ordinarySameShapeWithoutStoredPointerIsNeverClaimed() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clearDefaults(defaults) }
        let plant = Plant(name: "Fern", wateringIntervalDays: 7)
        context.insert(plant)
        configureOnlyWatering(for: plant, defaults: defaults)

        let ordinary = makePlanEvent(
            id: UUID(),
            title: "My editable watering task",
            plantID: plant.id,
            careType: .watering,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )
        context.insert(ordinary)
        try context.save()
        let key = storageKey(plantID: plant.id, careType: .watering)

        let result = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: Date(),
            scheduleNotifications: false,
            notifications: RecordingNotificationScheduler(),
            defaults: defaults,
            localization: L10n("en")
        )

        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: .watering)
        let events = try context.fetch(FetchDescriptor<Event>()).filter {
            $0.relatedEntityId == plant.id.uuidString && $0.eventType == EventType.watering.rawValue
        }
        #expect(result.didPersist)
        #expect(result.eventIDs == [expectedID])
        #expect(result.removedEventIDs.isEmpty)
        #expect(ordinary.title == "My editable watering task")
        #expect(events.contains { $0.id == ordinary.id })
        #expect(events.contains { $0.id == expectedID })
        #expect(defaults.string(forKey: key) == expectedID.uuidString)
    }

    @Test func storedPointerWithLocalizedEditedTitleMigratesByTaskKind() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clearDefaults(defaults) }
        let notifications = RecordingNotificationScheduler()
        let plant = Plant(name: "Fern", wateringIntervalDays: 7)
        context.insert(plant)
        configureOnlyWatering(for: plant, defaults: defaults)

        let pointed = makePlanEvent(
            id: UUID(),
            title: "Arroser ma fougère — personnalisé",
            plantID: plant.id,
            careType: .watering,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )
        let reminder = Reminder(event: pointed, scheduledAt: Date().addingTimeInterval(86400))
        reminder.notificationId = "localized-pointed-plan"
        context.insert(pointed)
        context.insert(reminder)
        try context.save()
        let pointedID = pointed.id
        let key = storageKey(plantID: plant.id, careType: .watering)
        defaults.set(pointedID.uuidString, forKey: key)

        #expect(PlantCarePlanIdentity.isStoredPointerMigrationEvidence(
            pointed,
            plantID: plant.id,
            careType: .watering
        ))
        #expect(!PlantCarePlanIdentity.isGeneratedPlan(pointed))

        let result = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: Date(),
            scheduleNotifications: false,
            notifications: notifications,
            defaults: defaults,
            localization: L10n("en")
        )

        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: .watering)
        let migrated = try #require(fetchEvent(id: expectedID, context: context))
        #expect(result.didPersist)
        #expect(result.eventIDs == [expectedID])
        #expect(result.removedEventIDs == [pointedID])
        #expect(fetchEvent(id: pointedID, context: context) == nil)
        #expect(PlantCarePlanIdentity.isStructuredMatch(migrated, plantID: plant.id, careType: .watering))
        #expect(defaults.string(forKey: key) == expectedID.uuidString)
        #expect(notifications.cancelledNotificationIDs.contains("localized-pointed-plan"))
    }

    @Test func storedPointerWithoutTaskKindMigratesByLegacyEventTypeAfterTitleEdit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clearDefaults(defaults) }
        let plant = Plant(name: "Fern", wateringIntervalDays: 7)
        context.insert(plant)
        configureOnlyWatering(for: plant, defaults: defaults)

        let pointed = makePlanEvent(
            id: UUID(),
            title: "My completely renamed recurring task",
            plantID: plant.id,
            careType: .watering,
            taskCareKindRaw: ""
        )
        context.insert(pointed)
        try context.save()
        let pointedID = pointed.id
        let key = storageKey(plantID: plant.id, careType: .watering)
        defaults.set(pointedID.uuidString, forKey: key)

        #expect(PlantCarePlanIdentity.isStoredPointerMigrationEvidence(
            pointed,
            plantID: plant.id,
            careType: .watering
        ))
        #expect(!PlantCarePlanIdentity.isGeneratedPlan(pointed))

        let result = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: Date(),
            scheduleNotifications: false,
            notifications: RecordingNotificationScheduler(),
            defaults: defaults,
            localization: L10n("en")
        )

        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: .watering)
        let migrated = try #require(fetchEvent(id: expectedID, context: context))
        #expect(result.didPersist)
        #expect(result.removedEventIDs == [pointedID])
        #expect(fetchEvent(id: pointedID, context: context) == nil)
        #expect(PlantCarePlanIdentity.isStructuredMatch(migrated, plantID: plant.id, careType: .watering))
        #expect(defaults.string(forKey: key) == expectedID.uuidString)
    }

    @Test func legacyMarkerPlanMigratesToStructuredIdentityInOneSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clearDefaults(defaults) }
        let notifications = RecordingNotificationScheduler()
        let plant = Plant(name: "Fern", wateringIntervalDays: 7)
        context.insert(plant)
        configureOnlyWatering(for: plant, defaults: defaults)

        let legacy = makePlanEvent(
            id: UUID(),
            title: "💧 Fern · Watering\(PlantCarePlanIdentity.legacyTitleMarker)",
            plantID: plant.id,
            careType: .watering,
            taskCareKindRaw: ""
        )
        let legacyReminder = Reminder(event: legacy, scheduledAt: Date().addingTimeInterval(86400))
        legacyReminder.notificationId = "legacy-plant-plan"
        context.insert(legacy)
        context.insert(legacyReminder)
        try context.save()
        let legacyID = legacy.id
        let key = storageKey(plantID: plant.id, careType: .watering)
        defaults.set(legacyID.uuidString, forKey: key)

        let result = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: Date(),
            scheduleNotifications: false,
            notifications: notifications,
            defaults: defaults,
            localization: L10n("en")
        )

        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: .watering)
        let migrated = try #require(fetchEvent(id: expectedID, context: context))
        #expect(result.didPersist)
        #expect(result.removedEventIDs.contains(legacyID))
        #expect(fetchEvent(id: legacyID, context: context) == nil)
        #expect(migrated.taskCareKindRaw == TaskCareKind.plantWatering.rawValue)
        #expect(!migrated.title.contains(PlantCarePlanIdentity.legacyTitleMarker))
        #expect(PlantCarePlanIdentity.isStructuredMatch(migrated, plantID: plant.id, careType: .watering))
        #expect(defaults.string(forKey: key) == expectedID.uuidString)
        #expect(notifications.cancelledNotificationIDs.contains("legacy-plant-plan"))
    }

    @Test func stablePlanWinsAndBoundedOwnedCandidatesAreDeduplicatedAndRemoved() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clearDefaults(defaults) }
        let notifications = RecordingNotificationScheduler()
        let plant = Plant(name: "Fern", wateringIntervalDays: 7)
        context.insert(plant)
        configureOnlyWatering(for: plant, defaults: defaults)

        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: .watering)
        let stable = makePlanEvent(
            id: expectedID,
            title: "Stable generated plan",
            plantID: plant.id,
            careType: .watering,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )
        let pointed = makePlanEvent(
            id: UUID(),
            title: "Benutzerdefinierter Gießplan",
            plantID: plant.id,
            careType: .watering,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )
        let markerLegacy = makePlanEvent(
            id: UUID(),
            title: "Old watering \(PlantCarePlanIdentity.legacyTitleMarker)",
            plantID: plant.id,
            careType: .watering,
            taskCareKindRaw: ""
        )
        let pointedReminder = Reminder(event: pointed, scheduledAt: Date().addingTimeInterval(86400))
        pointedReminder.notificationId = "pointed-duplicate-plan"
        let markerReminder = Reminder(event: markerLegacy, scheduledAt: Date().addingTimeInterval(86400))
        markerReminder.notificationId = "marker-duplicate-plan"
        context.insert(stable)
        context.insert(pointed)
        context.insert(markerLegacy)
        context.insert(pointedReminder)
        context.insert(markerReminder)
        try context.save()
        let pointedID = pointed.id
        let markerID = markerLegacy.id
        let key = storageKey(plantID: plant.id, careType: .watering)
        defaults.set(pointedID.uuidString, forKey: key)

        let result = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: Date(),
            scheduleNotifications: false,
            notifications: notifications,
            defaults: defaults,
            localization: L10n("en")
        )

        let surviving = try #require(fetchEvent(id: expectedID, context: context))
        let relatedEvents = try context.fetch(FetchDescriptor<Event>()).filter {
            $0.relatedEntityId == plant.id.uuidString && $0.eventType == EventType.watering.rawValue
        }
        #expect(result.didPersist)
        #expect(result.eventIDs == [expectedID])
        #expect(result.removedEventIDs.count == 2)
        #expect(Set(result.removedEventIDs) == Set([pointedID, markerID]))
        #expect(relatedEvents.map(\.id) == [expectedID])
        #expect(PlantCarePlanIdentity.isStructuredMatch(surviving, plantID: plant.id, careType: .watering))
        #expect(defaults.string(forKey: key) == expectedID.uuidString)
        #expect(notifications.cancelledNotificationIDs.contains("pointed-duplicate-plan"))
        #expect(notifications.cancelledNotificationIDs.contains("marker-duplicate-plan"))
    }

    @Test func generatedTitlesUseAllRegisteredLanguagesWithoutLegacyMarkerPollution() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clearDefaults(defaults) }
        let plant = Plant(
            name: "Fern",
            wateringIntervalDays: 7,
            isToxicToCats: true,
            isToxicToChildren: true
        )
        context.insert(plant)
        configureOnlyWatering(for: plant, defaults: defaults)
        try context.save()

        let petSafetyCopy = [
            "zh": "放到宠物够不到处",
            "en": "Keep out of pets' reach",
            "de": "Außer Reichweite von Haustieren",
            "es": "Mantener fuera del alcance de las mascotas",
            "pt": "Manter fora do alcance dos animais",
            "fr": "Garder hors de portée des animaux",
            "ja": "ペットの手が届かない場所に置く",
            "ko": "반려동물이 닿지 않는 곳에 두기",
            "it": "Tenere fuori dalla portata degli animali"
        ]
        let childSafetyCopy = [
            "zh": "注意儿童误食",
            "en": "Watch for child ingestion",
            "de": "Auf Verschlucken durch Kinder achten",
            "es": "Evitar que los niños la ingieran",
            "pt": "Evitar que crianças a ingiram",
            "fr": "Éviter l'ingestion par les enfants",
            "ja": "子どもの誤飲に注意",
            "ko": "어린이 섭취 주의",
            "it": "Evitare l'ingestione da parte dei bambini"
        ]

        for language in AppLanguage.supported.map(\.code) {
            let expectedPetCopy = try #require(petSafetyCopy[language])
            let expectedChildCopy = try #require(childSafetyCopy[language])
            defaults.set(true, forKey: "ohana_onboarding_has_pets")
            defaults.set(true, forKey: "ohana_onboarding_has_children")
            let petResult = PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                scheduleNotifications: false,
                notifications: RecordingNotificationScheduler(),
                defaults: defaults,
                localization: L10n(language)
            )
            let eventID = try #require(petResult.eventIDs.first)
            let petTitle = try #require(fetchEvent(id: eventID, context: context)).title
            #expect(petTitle.contains(expectedPetCopy))
            #expect(!petTitle.contains(PlantCarePlanIdentity.legacyTitleMarker))

            defaults.set(false, forKey: "ohana_onboarding_has_pets")
            let childResult = PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                scheduleNotifications: false,
                notifications: RecordingNotificationScheduler(),
                defaults: defaults,
                localization: L10n(language)
            )
            let childEventID = try #require(childResult.eventIDs.first)
            let childTitle = try #require(fetchEvent(id: childEventID, context: context)).title
            #expect(childTitle.contains(expectedChildCopy))
            #expect(!childTitle.contains(PlantCarePlanIdentity.legacyTitleMarker))
            if language != "zh" {
                #expect(!petTitle.contains("放到宠物够不到处"))
                #expect(!childTitle.contains("注意儿童误食"))
            }
        }
    }

    @Test func injectedManagerReceivesPostCommitIDsAndLowLevelSchedulerIsFallbackOnly() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clearDefaults(defaults) }
        let plant = Plant(name: "Fern", wateringIntervalDays: 7)
        context.insert(plant)
        configureOnlyWatering(for: plant, defaults: defaults)
        try context.save()
        let manager = RecordingReminderSchedulingManager()
        let notifications = RecordingNotificationScheduler()
        let dispatcher = PlantPlanPostCommitDispatcher()

        let result = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            reminderScheduling: manager,
            notifications: notifications,
            defaults: defaults,
            postCommitDispatcher: dispatcher
        )
        let handle = try #require(result.postCommitDispatchHandle)
        let outcome = await handle.wait()

        #expect(result.didPersist)
        #expect(outcome.state == .dispatched)
        #expect(outcome.requestedReminderIDs == result.reminderIDsToSchedule)
        #expect(outcome.resolvedReminderIDs == result.reminderIDsToSchedule)
        #expect(manager.scheduledBatches == [result.reminderIDsToSchedule])
        #expect(notifications.scheduledReminderIDs.isEmpty)
        #expect(dispatcher.activeDispatchCount == 0)
    }

    @Test func dispatcherRetainsShortLivedStoreUntilSchedulingFinishes() async throws {
        let manager = RecordingReminderSchedulingManager()
        let dispatcher = PlantPlanPostCommitDispatcher()
        let request = try makeShortLivedDispatch(dispatcher: dispatcher, manager: manager)

        let outcome = await request.handle.wait()

        #expect(outcome.state == .dispatched)
        #expect(outcome.requestedReminderIDs == request.reminderIDs)
        #expect(outcome.resolvedReminderIDs == request.reminderIDs)
        #expect(manager.scheduledBatches == [request.reminderIDs])
        #expect(dispatcher.activeDispatchCount == 0)
    }

    @Test func registeredDependencyExpiresWithItsOwner() {
        let manager = RecordingReminderSchedulingManager()
        var owner: RegistryOwner? = RegistryOwner()
        DomainServiceDependencyRegistry.register(
            owner: owner!,
            reminderScheduling: { _ in manager }
        )

        #expect(
            DomainServiceDependencyRegistry.registeredReminderScheduling(
                careLedger: CareLedgerService()
            ) != nil
        )
        owner = nil
        #expect(
            DomainServiceDependencyRegistry.registeredReminderScheduling(
                careLedger: CareLedgerService()
            ) == nil
        )
    }

    @Test func persistenceFailureRollsBackWithoutDefaultsOrNotificationDispatch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clearDefaults(defaults) }
        let plant = Plant(name: "Fern", wateringIntervalDays: 7)
        context.insert(plant)
        configureOnlyWatering(for: plant, defaults: defaults)
        try context.save()
        let manager = RecordingReminderSchedulingManager()
        let notifications = RecordingNotificationScheduler()
        let dispatcher = PlantPlanPostCommitDispatcher()

        let result = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            reminderScheduling: manager,
            notifications: notifications,
            defaults: defaults,
            postCommitDispatcher: dispatcher,
            persistenceSave: { _ in .failed(InjectedSaveError()) }
        )

        #expect(!result.didPersist)
        #expect(result.postCommitDispatchHandle == nil)
        #expect(manager.scheduledBatches.isEmpty)
        #expect(notifications.scheduledReminderIDs.isEmpty)
        #expect(notifications.cancelledNotificationIDs.isEmpty)
        #expect(dispatcher.activeDispatchCount == 0)
        #expect(defaults.string(forKey: storageKey(plantID: plant.id, careType: .watering)) == nil)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    private struct InjectedSaveError: LocalizedError {
        var errorDescription: String? { "Injected plant-plan save failure" }
    }

    private struct ShortLivedDispatchRequest {
        let handle: PlantPlanPostCommitDispatchHandle
        let reminderIDs: [UUID]
    }

    private final class RegistryOwner {}

    private func makeShortLivedDispatch(
        dispatcher: PlantPlanPostCommitDispatcher,
        manager: RecordingReminderSchedulingManager
    ) throws -> ShortLivedDispatchRequest {
        let container = try makeContainer()
        let context = container.mainContext
        let event = Event(title: "Water Fern", startDate: Date().addingTimeInterval(3600))
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(event)
        context.insert(reminder)
        try context.save()
        let reminderIDs = [reminder.id]
        let handle = dispatcher.dispatch(
            reminderIDs: reminderIDs,
            context: context,
            reminderScheduling: manager,
            source: .service
        )
        return ShortLivedDispatchRequest(handle: handle, reminderIDs: reminderIDs)
    }

    private final class RecordingNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var scheduledReminderIDs: [UUID] = []
        private(set) var cancelledNotificationIDs: [String] = []

        func schedule(reminder: Reminder) {
            scheduledReminderIDs.append(reminder.id)
        }

        func schedule(
            reminder: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            scheduledReminderIDs.append(reminder.id)
            completion?(.scheduled)
        }

        func schedule(
            reminder: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            scheduledReminderIDs.append(reminder.id)
            completion?(.scheduled)
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId: String) { cancelledNotificationIDs.append(notificationId) }
        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    private final class RecordingReminderSchedulingManager: ReminderSchedulingManaging {
        private(set) var scheduledBatches: [[UUID]] = []

        func scheduleIfNeeded(
            reminder _: Reminder,
            context _: ModelContext,
            source _: CareLedgerSource,
            existingNotificationIds _: Set<String>?,
            operation _: String,
            saveLedger _: Bool
        ) async -> ReminderNotificationScheduleResult {
            .scheduled
        }

        func scheduleManyIfNeeded(
            reminders: [Reminder],
            context _: ModelContext,
            source _: CareLedgerSource
        ) async {
            scheduledBatches.append(reminders.map(\.id))
        }

        func cancelAndReschedule(reminder _: Reminder, context _: ModelContext, source _: CareLedgerSource) async {}
        func refillMissingPendingNotifications(reminders _: [Reminder], context _: ModelContext) async {}
        func compensate(reminders _: [Reminder], context _: ModelContext) {}
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "PlantCarePlanIdentitySchedulingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func clearDefaults(_ defaults: UserDefaults) {
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }

    private func configureOnlyWatering(for plant: Plant, defaults: UserDefaults) {
        for careType in PlantCareCategory.schedulableCareTypes {
            let enabled = careType == .watering
            PlantReminderPreferenceStore.setPlanCalendarEnabled(
                enabled,
                forPlantID: plant.id,
                careType: careType,
                defaults: defaults
            )
            PlantReminderPreferenceStore.setSystemReminderEnabled(
                enabled,
                forPlantID: plant.id,
                careType: careType,
                defaults: defaults
            )
        }
    }

    private func storageKey(plantID: UUID, careType: PlantCareType) -> String {
        "ohana_plant_care_plan_event_v1_\(plantID.uuidString)_\(careType.rawValue)"
    }

    private func makePlanEvent(
        id: UUID,
        title: String,
        plantID: UUID,
        careType: PlantCareType,
        taskCareKindRaw: String
    ) -> Event {
        let event = Event(
            title: title,
            startDate: Date().addingTimeInterval(86400),
            isAllDay: true,
            eventType: careType.eventType.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plantID.uuidString,
            taskCareKindRaw: taskCareKindRaw
        )
        event.id = id
        event.recurrenceDays = 7
        return event
    }

    private func fetchEvent(id: UUID, context: ModelContext) -> Event? {
        var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
