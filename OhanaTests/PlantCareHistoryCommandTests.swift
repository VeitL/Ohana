import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PlantCareHistoryCommandTests {
    @Test func manualEditRecalculatesDatesKeepsAuditIdentityAndDoesNotDuplicateOnReplay() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let dates = testDates()
        let plant = Plant(name: "Fern", healthStatus: .stable, remindersEnabled: false)
        let earlierWatering = PlantCareLog(date: dates.first, careType: .watering, note: "earlier")
        let target = PlantCareLog(
            date: dates.second,
            careType: .watering,
            note: "old",
            executorId: "executor-1",
            careTransactionId: "care-transaction-1",
            photoData: Data([1, 2, 3]),
            healthStatus: .stable
        )
        earlierWatering.plant = plant
        target.plant = plant
        plant.lastWateredDate = dates.second
        plant.lastFertilizedDate = dates.zero
        let sourceEvent = Event(
            title: "Watered Fern",
            startDate: dates.second,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        let wallet = makeWalletEntry(plant: plant, sourceModelID: target.id, occurredAt: dates.second)
        let budget = makeBudgetEntry(plant: plant, occurredAt: dates.second)
        context.insert(plant)
        context.insert(earlierWatering)
        context.insert(target)
        context.insert(sourceEvent)
        context.insert(wallet)
        context.insert(budget)
        let originalLedger = CareLedgerService.record(
            occurredAt: dates.second,
            actorKind: .human,
            actorId: "executor-1",
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            note: "old",
            source: .detail,
            sourceEventId: sourceEvent.id.uuidString,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: target.id.uuidString,
            coconutDelta: 5,
            rewardLogId: wallet.id.uuidString,
            metadataJSON: #"{"careTransactionId":"care-transaction-1","reward":"kept"}"#,
            context: context,
            save: false
        )
        try context.save()
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        disablePlans(for: plant.id, defaults: defaults)
        let operationID = UUID()
        let originalLedgerID = originalLedger.id
        let intent = PlantCareHistoryEditIntent(
            recordID: PlantCareHistoryRecordID(plantID: plant.id, logID: target.id),
            operationID: operationID,
            expectedCareTransactionID: target.careTransactionId,
            date: dates.third,
            careType: .fertilizing,
            note: " corrected ",
            healthStatus: .stressed,
            photoMutation: .remove,
            editedByHumanID: "editor-2",
            now: dates.fourth
        )

        let result = PlantCareHistoryCommandService.edit(
            intent,
            context: context,
            options: options(defaults: defaults)
        )
        let replay = PlantCareHistoryCommandService.edit(
            intent,
            context: context,
            options: options(defaults: defaults)
        )

        #expect(result.disposition == .updated)
        #expect(replay.disposition == .unchanged)
        #expect(target.date == dates.third)
        #expect(target.careType == .fertilizing)
        #expect(target.note == "corrected")
        #expect(target.executorId == "executor-1")
        #expect(target.careTransactionId == "care-transaction-1")
        #expect(target.healthStatus == .stressed)
        #expect(!target.hasPhotoAttachment)
        #expect(plant.lastWateredDate == dates.first)
        #expect(plant.lastFertilizedDate == dates.third)
        #expect(plant.healthStatus == .stable)
        #expect(sourceEvent.startDate == dates.third)
        #expect(sourceEvent.eventType == EventType.fertilizing.rawValue)
        let ledgers = try linkedLedgers(logID: target.id, context: context)
        #expect(ledgers.count == 1)
        #expect(ledgers[0].id != originalLedgerID)
        #expect(ledgers[0].coconutDelta == 5)
        #expect(ledgers[0].rewardLogId == wallet.id.uuidString)
        #expect(ledgers[0].metadataJSON.contains(operationID.uuidString))
        #expect(ledgers[0].metadataJSON.contains("historyFinancialEffectsPreserved"))
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).map(\.id) == [wallet.id])
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).map(\.id) == [budget.id])
    }

    @Test func scheduledEditLocksTypeAndDateButAllowsObservationFields() throws {
        let fixture = try makeScheduledFixture(source: .calendar)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let recordID = PlantCareHistoryRecordID(plantID: fixture.plant.id, logID: fixture.log.id)
        let snapshot = try PlantCareHistoryCommandService.snapshot(recordID: recordID, context: fixture.context)
        let rejected = PlantCareHistoryCommandService.edit(
            PlantCareHistoryEditIntent(
                recordID: recordID,
                expectedCareTransactionID: fixture.log.careTransactionId,
                date: fixture.log.date.addingTimeInterval(-3600),
                careType: .fertilizing,
                note: "changed",
                healthStatus: .watching,
                editedByHumanID: "editor",
                now: fixture.now
            ),
            context: fixture.context,
            options: options(defaults: fixture.defaults)
        )
        let allowed = PlantCareHistoryCommandService.edit(
            PlantCareHistoryEditIntent(
                recordID: recordID,
                expectedCareTransactionID: fixture.log.careTransactionId,
                date: fixture.log.date,
                careType: fixture.log.careType,
                note: "observed after completion",
                healthStatus: .watching,
                editedByHumanID: "editor",
                now: fixture.now
            ),
            context: fixture.context,
            options: options(defaults: fixture.defaults)
        )

        #expect(snapshot.source == .calendar)
        #expect(snapshot.sourceFieldsAreLocked)
        #expect(rejected.failure == .sourceFieldsLocked)
        #expect(allowed.disposition == .updated)
        #expect(fixture.log.note == "observed after completion")
        #expect(fixture.log.healthStatus == .watching)
        #expect(fixture.plant.healthStatus == .stable)
    }

    @Test func editRejectsPendingRewardWithoutChangingRewardPayload() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let dates = testDates()
        let plant = Plant(name: "Pending Fern", remindersEnabled: false)
        let log = PlantCareLog(
            date: dates.second,
            careType: .watering,
            note: "original",
            careTransactionId: UUID().uuidString
        )
        log.plant = plant
        context.insert(plant)
        context.insert(log)
        let ledger = CareLedgerService.record(
            occurredAt: dates.second,
            actorKind: .unknown,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            source: .detail,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: log.id.uuidString,
            metadataJSON: #"{"plantCareRewardState":"pending"}"#,
            context: context,
            save: false
        )
        try context.save()

        let result = PlantCareHistoryCommandService.edit(
            PlantCareHistoryEditIntent(
                recordID: PlantCareHistoryRecordID(plantID: plant.id, logID: log.id),
                expectedCareTransactionID: log.careTransactionId,
                date: dates.third,
                careType: .fertilizing,
                note: "changed",
                healthStatus: .stressed,
                editedByHumanID: nil,
                now: dates.fourth
            ),
            context: context
        )

        #expect(result.failure == .pendingRewardSettlement)
        #expect(log.date == dates.second)
        #expect(log.careType == .watering)
        #expect(log.note == "original")
        #expect(ledger.metadataJSON.contains(#""plantCareRewardState":"pending""#))
        #expect(!context.hasChanges)
    }

    @Test func deleteRejectsPendingRewardUntilSettlementCompletes() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let dates = testDates()
        let plant = Plant(name: "Pending Reward Fern")
        let log = PlantCareLog(
            date: dates.second,
            careType: .watering,
            note: "pending delete",
            careTransactionId: UUID().uuidString
        )
        log.plant = plant
        plant.lastWateredDate = dates.second
        context.insert(plant)
        context.insert(log)
        let metadata = CareLedgerMetadata.addingString(
            PlantCareCommandService.rewardStateMetadataKey,
            value: PlantCareCommandService.rewardStatePending,
            to: ""
        )
        CareLedgerService.record(
            occurredAt: dates.second,
            actorKind: .unknown,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            source: .detail,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: log.id.uuidString,
            metadataJSON: metadata,
            context: context,
            save: false
        )
        try context.save()

        let result = PlantCareHistoryCommandService.delete(
            PlantCareHistoryDeleteIntent(
                recordID: PlantCareHistoryRecordID(plantID: plant.id, logID: log.id),
                expectedCareTransactionID: log.careTransactionId,
                deletedByHumanID: nil,
                now: dates.fourth
            ),
            context: context
        )

        #expect(result.failure == .pendingRewardSettlement)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).contains { $0.id == log.id })
        #expect(try linkedLedgers(logID: log.id, context: context).count == 1)
        #expect(plant.lastWateredDate == dates.second)
        #expect(!context.hasChanges)
    }

    @Test func manualDeleteRemovesFactAndOneOffScheduleButKeepsSettledEconomyAndIsReplaySafe() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let dates = testDates()
        let plant = Plant(name: "Mint", remindersEnabled: false)
        let earlier = PlantCareLog(date: dates.first, careType: .watering, note: "earlier")
        let target = PlantCareLog(
            date: dates.second,
            careType: .watering,
            note: "latest",
            executorId: "human-1",
            careTransactionId: "delete-transaction"
        )
        earlier.plant = plant
        target.plant = plant
        plant.lastWateredDate = dates.second
        let event = Event(
            title: "Watered Mint",
            startDate: dates.second,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: dates.second)
        event.reminders.append(reminder)
        let wallet = makeWalletEntry(plant: plant, sourceModelID: target.id, occurredAt: dates.second)
        let budget = makeBudgetEntry(plant: plant, occurredAt: dates.second)
        context.insert(plant)
        context.insert(earlier)
        context.insert(target)
        context.insert(event)
        context.insert(reminder)
        context.insert(wallet)
        context.insert(budget)
        CareLedgerService.record(
            occurredAt: dates.second,
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            source: .detail,
            sourceEventId: event.id.uuidString,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: target.id.uuidString,
            coconutDelta: 5,
            rewardLogId: wallet.id.uuidString,
            context: context,
            save: false
        )
        try context.save()
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        disablePlans(for: plant.id, defaults: defaults)
        let targetID = target.id
        let eventID = event.id
        let reminderID = reminder.id
        let intent = PlantCareHistoryDeleteIntent(
            recordID: PlantCareHistoryRecordID(plantID: plant.id, logID: targetID),
            expectedCareTransactionID: target.careTransactionId,
            deletedByHumanID: "human-1",
            now: dates.third
        )

        let result = PlantCareHistoryCommandService.delete(
            intent,
            context: context,
            options: options(defaults: defaults)
        )
        let replay = PlantCareHistoryCommandService.delete(
            intent,
            context: context,
            options: options(defaults: defaults)
        )

        #expect(result.disposition == .deleted)
        #expect(replay.disposition == .alreadyDeleted)
        #expect(plant.lastWateredDate == dates.first)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).map(\.id) == [earlier.id])
        #expect(!(try context.fetch(FetchDescriptor<Event>())).contains { $0.id == eventID })
        #expect(!(try context.fetch(FetchDescriptor<Reminder>())).contains { $0.id == reminderID })
        #expect(try linkedLedgers(logID: targetID, context: context).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).contains { $0.id == wallet.id })
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).contains { $0.id == budget.id })
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).contains {
            $0.actionType == "historyDeleted" &&
                $0.metadataJSON.contains("historyFinancialEffectsPreserved")
        })
    }

    @Test func calendarScheduleDeleteReopensOccurrenceAndRestoresPreviousProjection() throws {
        let fixture = try makeScheduledFixture(source: .calendar)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let occurrence = fixture.log.date
        let logID = fixture.log.id
        #expect(fixture.event.isOccurrenceMarkedComplete(on: occurrence))
        let result = PlantCareHistoryCommandService.delete(
            PlantCareHistoryDeleteIntent(
                recordID: PlantCareHistoryRecordID(plantID: fixture.plant.id, logID: logID),
                expectedCareTransactionID: fixture.log.careTransactionId,
                deletedByHumanID: "human-1",
                now: fixture.now
            ),
            context: fixture.context,
            options: options(defaults: fixture.defaults)
        )

        #expect(result.disposition == .deleted)
        #expect(fixture.plant.lastWateredDate == fixture.previousDate)
        #expect(!fixture.event.isOccurrenceMarkedComplete(on: occurrence))
        #expect(try fixture.context.fetch(FetchDescriptor<PlantCareLog>()).allSatisfy { $0.id != logID })
        #expect(try linkedLedgers(logID: logID, context: fixture.context).isEmpty)
    }

    @Test func rewardedCalendarScheduleDeleteReopensAndPreservesFinancialEffects() throws {
        let fixture = try makeScheduledFixture(source: .calendar)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let occurrence = fixture.log.date
        let logID = fixture.log.id
        let rewardLogID = UUID().uuidString
        let linked = try #require(try linkedLedgers(logID: logID, context: fixture.context).first)
        linked.coconutDelta = 5
        linked.rewardLogId = rewardLogID
        linked.metadataJSON = CareLedgerMetadata.addingString(
            PlantCareCommandService.rewardStateMetadataKey,
            value: PlantCareCommandService.rewardStateSettled,
            to: linked.metadataJSON
        )
        try fixture.context.save()

        let result = PlantCareHistoryCommandService.delete(
            PlantCareHistoryDeleteIntent(
                recordID: PlantCareHistoryRecordID(plantID: fixture.plant.id, logID: logID),
                expectedCareTransactionID: fixture.log.careTransactionId,
                deletedByHumanID: "human-1",
                now: fixture.now
            ),
            context: fixture.context,
            options: options(defaults: fixture.defaults)
        )

        #expect(result.disposition == .deleted)
        #expect(!fixture.event.isOccurrenceMarkedComplete(on: occurrence))
        #expect(try linkedLedgers(logID: logID, context: fixture.context).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<CareLedgerEvent>()).contains {
            $0.actionType == "historyDeleted" &&
                $0.metadataJSON.contains("historyFinancialEffectsPreserved") &&
                $0.metadataJSON.contains(rewardLogID)
        })
    }

    @Test func reminderScheduleDeleteReopensReminderAndWritesAuditInSameCommit() throws {
        let fixture = try makeScheduledFixture(source: .reminder)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let reminder = try #require(fixture.reminder)
        let result = PlantCareHistoryCommandService.delete(
            PlantCareHistoryDeleteIntent(
                recordID: PlantCareHistoryRecordID(plantID: fixture.plant.id, logID: fixture.log.id),
                expectedCareTransactionID: fixture.log.careTransactionId,
                deletedByHumanID: "human-1",
                now: fixture.now
            ),
            context: fixture.context,
            options: options(defaults: fixture.defaults)
        )

        #expect(result.disposition == .deleted)
        #expect(fixture.plant.lastWateredDate == fixture.previousDate)
        #expect(reminder.statusEnum == .pending)
        #expect(reminder.completedAt == nil)
        #expect(try fixture.context.fetch(FetchDescriptor<CareLedgerEvent>()).contains {
            $0.eventKindEnum == .reminder && $0.actionType == "reopen"
        })
    }

    @Test func internalPlanFeedbackIsNotExposedAsEditableHistory() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let plant = Plant(name: "Fern")
        let internalLog = PlantCareLog(careType: .customNote, note: "skip:watering:tomorrow|notNeeded")
        internalLog.plant = plant
        context.insert(plant)
        context.insert(internalLog)
        try context.save()

        #expect(PlantCareHistoryPolicy.isInternalFeedback(internalLog))
        do {
            _ = try PlantCareHistoryCommandService.snapshot(
                recordID: PlantCareHistoryRecordID(plantID: plant.id, logID: internalLog.id),
                context: context
            )
            Issue.record("Expected internal feedback to stay outside editable history")
        } catch let failure as PlantCareHistoryCommandFailure {
            #expect(failure == .internalFeedback)
        }
    }

    @Test func editedUserNoteCannotTurnIntoHiddenPlanFeedback() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let plant = Plant(name: "Fern", remindersEnabled: false)
        let log = PlantCareLog(careType: .customNote, note: "visible note")
        log.plant = plant
        context.insert(plant)
        context.insert(log)
        try context.save()
        let recordID = PlantCareHistoryRecordID(plantID: plant.id, logID: log.id)

        let result = PlantCareHistoryCommandService.edit(
            PlantCareHistoryEditIntent(
                recordID: recordID,
                expectedCareTransactionID: log.careTransactionId,
                date: log.date,
                careType: .customNote,
                note: "skip:my own note",
                healthStatus: nil,
                editedByHumanID: nil
            ),
            context: context
        )

        #expect(result.failure == .reservedFeedbackNote)
        #expect(log.note == "visible note")
        #expect(!PlantCareHistoryPolicy.isInternalFeedback(log))
        #expect(try PlantCareHistoryCommandService.snapshot(recordID: recordID, context: context).note == "visible note")
        #expect(!context.hasChanges)
    }

    @Test func injectedSaveFailureRollsBackHistoryLedgerSummaryAndPlan() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let dates = testDates()
        let plant = Plant(name: "Rollback Fern", remindersEnabled: false)
        let log = PlantCareLog(
            date: dates.second,
            careType: .watering,
            note: "before",
            careTransactionId: "rollback-transaction"
        )
        log.plant = plant
        plant.lastWateredDate = dates.second
        context.insert(plant)
        context.insert(log)
        let ledger = CareLedgerService.record(
            occurredAt: dates.second,
            actorKind: .unknown,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            note: log.note,
            source: .detail,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: log.id.uuidString,
            context: context,
            save: false
        )
        try context.save()
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        disablePlans(for: plant.id, defaults: defaults)
        var failingOptions = options(defaults: defaults)
        var saveCallCount = 0
        failingOptions.persistChanges = { _ in
            saveCallCount += 1
            return ModelContextSaveResult(
                didSave: false,
                errorDescription: "injected history save failure"
            )
        }

        let result = PlantCareHistoryCommandService.edit(
            PlantCareHistoryEditIntent(
                recordID: PlantCareHistoryRecordID(plantID: plant.id, logID: log.id),
                expectedCareTransactionID: log.careTransactionId,
                date: dates.third,
                careType: .fertilizing,
                note: "after",
                healthStatus: .stressed,
                editedByHumanID: "editor",
                now: dates.fourth
            ),
            context: context,
            options: failingOptions
        )

        let persistedLog = try #require(try context.fetch(FetchDescriptor<PlantCareLog>()).first)
        let persistedPlant = try #require(try context.fetch(FetchDescriptor<Plant>()).first { $0.id == plant.id })
        let persistedLedgers = try linkedLedgers(logID: log.id, context: context)
        #expect(result.failure == .persistenceFailed)
        #expect(saveCallCount == 1)
        #expect(persistedLog.date == dates.second)
        #expect(persistedLog.careType == .watering)
        #expect(persistedLog.note == "before")
        #expect(persistedPlant.lastWateredDate == dates.second)
        #expect(persistedPlant.lastFertilizedDate == nil)
        #expect(persistedLedgers.map(\.id) == [ledger.id])
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    private struct Dates {
        let zero: Date
        let first: Date
        let second: Date
        let third: Date
        let fourth: Date
    }

    private struct ScheduledFixture {
        let container: ModelContainer
        let context: ModelContext
        let plant: Plant
        let log: PlantCareLog
        let event: Event
        let reminder: Reminder?
        let previousDate: Date
        let now: Date
        let defaults: UserDefaults
        let suiteName: String
    }

    private func makeScheduledFixture(source: CareLedgerSource) throws -> ScheduledFixture {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let dates = testDates()
        let plant = Plant(name: "Plan Fern", wateringIntervalDays: 2, remindersEnabled: true)
        plant.createdAt = dates.zero
        plant.lastWateredDate = dates.second
        let log = PlantCareLog(
            date: dates.second,
            careType: .watering,
            note: "Plan complete",
            executorId: "human-1",
            careTransactionId: "scheduled-transaction"
        )
        log.plant = plant
        let event = Event(
            title: "Plan Fern watering",
            startDate: dates.second,
            isAllDay: true,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString,
            taskCareKindRaw: TaskCareKind.plantWatering.rawValue
        )
        event.id = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: .watering)
        event.recurrenceDays = 2
        event.setOccurrenceMarkedComplete(true, on: dates.second)
        let reminder: Reminder? = if source == .reminder {
            Reminder(event: event, scheduledAt: dates.second, occurrenceAt: dates.second)
        } else {
            nil
        }
        reminder?.statusEnum = .completed
        reminder?.completedAt = dates.second
        if let reminder { event.reminders.append(reminder) }
        context.insert(plant)
        context.insert(log)
        context.insert(event)
        if let reminder { context.insert(reminder) }
        let metadata = "{\"scheduleCompletion\":true,\"hasPreviousCareDate\":true,\"previousCareDate\":\(dates.first.timeIntervalSince1970)}"
        CareLedgerService.record(
            occurredAt: dates.second,
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            note: log.note,
            source: source,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder?.id.uuidString,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: log.id.uuidString,
            coconutDelta: 0,
            metadataJSON: metadata,
            context: context,
            save: false
        )
        try context.save()
        let (defaults, suiteName) = isolatedDefaults()
        for type in PlantCareCategory.schedulableCareTypes {
            PlantReminderPreferenceStore.setPlanCalendarEnabled(
                type == .watering,
                forPlantID: plant.id,
                careType: type,
                defaults: defaults
            )
            PlantReminderPreferenceStore.setSystemReminderEnabled(
                false,
                forPlantID: plant.id,
                careType: type,
                defaults: defaults
            )
        }
        return ScheduledFixture(
            container: container,
            context: context,
            plant: plant,
            log: log,
            event: event,
            reminder: reminder,
            previousDate: dates.first,
            now: dates.fourth,
            defaults: defaults,
            suiteName: suiteName
        )
    }

    private func linkedLedgers(logID: UUID, context: ModelContext) throws -> [CareLedgerEvent] {
        let modelName = String(describing: PlantCareLog.self)
        let modelID = logID.uuidString
        return try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.legacyModelName == modelName && $0.legacyModelId == modelID
        }
    }

    private func makeWalletEntry(plant: Plant, sourceModelID: UUID, occurredAt: Date) -> CoconutLedgerEntry {
        CoconutLedgerEntry(
            transactionKey: "wallet-\(sourceModelID.uuidString)",
            accountKey: CoconutAccountKey.system("history-test"),
            ownerKind: .system,
            ownerId: "history-test",
            ownerName: "History test",
            delta: 5,
            balanceBefore: 0,
            balanceAfter: 5,
            entryKind: .reward,
            source: .careEvent,
            title: "Plant care reward",
            emoji: "🥥",
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            sourceModelName: String(describing: PlantCareLog.self),
            sourceModelId: sourceModelID.uuidString,
            occurredAt: occurredAt
        )
    }

    private func makeBudgetEntry(plant: Plant, occurredAt: Date) -> EconomyBudgetUsageEvent {
        EconomyBudgetUsageEvent(
            dayKey: "2026-08-01",
            householdKey: "history-test",
            memberKey: "history-test",
            careObjectKey: plant.id.uuidString,
            scope: .careObject,
            scopeKey: plant.id.uuidString,
            growthXPUsed: 0,
            coconutUsed: 5,
            actionKey: "plantCare",
            source: "test",
            occurredAt: occurredAt
        )
    }

    private func options(defaults: UserDefaults) -> PlantCareHistoryCommandOptions {
        PlantCareHistoryCommandOptions(
            scheduleNotifications: false,
            notifications: ReminderNotificationSchedulerRegistry.disabledScheduler(),
            defaults: defaults
        )
    }

    private func disablePlans(for plantID: UUID, defaults: UserDefaults) {
        for type in PlantCareCategory.schedulableCareTypes {
            PlantReminderPreferenceStore.setPlanCalendarEnabled(
                false,
                forPlantID: plantID,
                careType: type,
                defaults: defaults
            )
            PlantReminderPreferenceStore.setSystemReminderEnabled(
                false,
                forPlantID: plantID,
                careType: type,
                defaults: defaults
            )
        }
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "PlantCareHistoryCommandTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    private func testDates() -> Dates {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 8,
            day: 1,
            hour: 9
        ))!
        return Dates(
            zero: base,
            first: base.addingTimeInterval(86400),
            second: base.addingTimeInterval(2 * 86400),
            third: base.addingTimeInterval(3 * 86400),
            fourth: base.addingTimeInterval(4 * 86400)
        )
    }
}
