//
//  OhanaTests.swift
//  OhanaTests
//
//  Created by Guanchenulous on 01.03.26.
//

import Testing
import Foundation
import SwiftData
@testable import Ohana

struct OhanaTests {

    @MainActor
    @Test func coconutLedgerAuditReconcilesRollingLog() async throws {
        let logs = [
            CoconutLogEntry(emoji: "🥥", title: "奖励", amount: 8),
            CoconutLogEntry(emoji: "🎁", title: "兑换", amount: -3)
        ]

        let audit = CoconutLedgerAudit.evaluate(
            islandCount: 5,
            logs: logs,
            petBalances: [2],
            humanBalances: [3]
        )

        #expect(audit.rollingLogDelta == 5)
        #expect(audit.rollingLogReconciles == true)
        #expect(audit.isHealthy)
    }

    @MainActor
    @Test func coconutLedgerAuditDetectsNegativeAccounts() async throws {
        let audit = CoconutLedgerAudit.evaluate(
            islandCount: 1,
            logs: [CoconutLogEntry(emoji: "🥥", title: "奖励", amount: 1)],
            petBalances: [-1],
            humanBalances: [2]
        )

        #expect(audit.hasNegativeAccount)
        #expect(!audit.isHealthy)
    }

    @MainActor
    @Test func privacyServiceMapsHumanQuickActions() async throws {
        let owner = Human(name: "Owner")
        let viewer = Human(name: "Viewer")
        owner.setPrivate(.weight, true)

        let item = QuickActionItem(
            label: "体重",
            icon: "scalemass",
            colorHex: "00D4AA",
            actionType: "humanWeight",
            entityId: owner.id,
            entityKind: .human
        )

        #expect(PrivacyService.field(forHumanAction: "humanWeight") == .weight)
        #expect(PrivacyService.isHumanQuickActionLocked(item, human: owner, viewedBy: viewer.id))
        #expect(!PrivacyService.isHumanQuickActionLocked(item, human: owner, viewedBy: owner.id))
        #expect(PrivacyService.badgeText(for: .weight, human: owner, viewedBy: viewer.id) == "仅自己")
    }

    @MainActor
    @Test func reminderCompletionServiceCompletesAndSkips() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let reminder = Reminder(scheduledAt: Date())
        context.insert(reminder)

        ReminderCompletionService.complete(reminder, by: "human-1", context: context)
        #expect(reminder.statusEnum == ReminderStatus.completed)
        #expect(reminder.completedAt != nil)
        #expect(reminder.completedBy == "human-1")

        ReminderCompletionService.skip(reminder, by: "human-2", context: context)
        #expect(reminder.statusEnum == ReminderStatus.skipped)
        #expect(reminder.completedAt == nil)
        #expect(reminder.completedBy == "human-2")
    }

    @MainActor
    @Test func careEventServiceRecordsManualFeed() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)

        CareEventService.recordManualFeed(pet: pet, amountGrams: 42, context: context, executorId: "human-1")

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.careType == .feeding)
        #expect(logs.first?.amountGrams == 42)
        #expect(logs.first?.executorId == "human-1")

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(ledger.first?.eventKindEnum == .care)
        #expect(ledger.first?.legacyModelName == "PetCareLog")
        #expect(ledger.first?.legacyModelId == logs.first?.id.uuidString)
    }

    @MainActor
    @Test func reminderCompletionServiceWritesLedgerEvent() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "喂药", relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: UUID().uuidString)
        let reminder = Reminder(event: event, scheduledAt: Date())
        context.insert(event)
        context.insert(reminder)

        ReminderCompletionService.complete(reminder, by: "human-1", context: context)

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(ledger.first?.eventKindEnum == .reminder)
        #expect(ledger.first?.actionType == "complete")
        #expect(ledger.first?.sourceReminderId == reminder.id.uuidString)
    }

    @MainActor
    @Test func reminderSchedulingServiceSkipsPastDueAndWritesLedger() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "过期提醒", relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: UUID().uuidString)
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(-60))
        context.insert(event)
        context.insert(reminder)

        let result = await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: context)

        #expect(result == .skippedPastDue)
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.first?.actionType == "scheduleSkippedPastDue")
        #expect(ledger.first?.sourceReminderId == reminder.id.uuidString)
    }

    @MainActor
    @Test func reminderSchedulingServiceDeduplicatesEventAndScheduledMinute() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "重复提醒", relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: UUID().uuidString)
        let scheduledAt = Date().addingTimeInterval(3_600)
        let first = Reminder(event: event, scheduledAt: scheduledAt)
        let duplicate = Reminder(event: event, scheduledAt: scheduledAt.addingTimeInterval(10))
        context.insert(event)
        context.insert(first)
        context.insert(duplicate)
        try context.save()

        let kept = ReminderSchedulingService.deduplicate(reminders: [duplicate, first], context: context)

        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(kept.count == 1)
        #expect(reminders.count == 1)
        #expect(reminders.first?.id == first.id)
        #expect(ledger.first?.actionType == "dedupeRemoved")
        #expect(ledger.first?.sourceReminderId == duplicate.id.uuidString)
    }

    @MainActor
    @Test func reminderSchedulingServiceCompensatesOverdueReminders() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let petId = UUID().uuidString
        let foodEvent = Event(title: "早餐", eventType: EventType.foodChange.rawValue, relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: petId)
        let taskEvent = Event(title: "清洁", eventType: EventType.grooming.rawValue, relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: petId)
        let foodReminder = Reminder(event: foodEvent, scheduledAt: Date().addingTimeInterval(-3_600))
        let taskReminder = Reminder(event: taskEvent, scheduledAt: Date().addingTimeInterval(-3_600))
        context.insert(foodEvent)
        context.insert(taskEvent)
        context.insert(foodReminder)
        context.insert(taskReminder)

        ReminderSchedulingService.compensate(reminders: [foodReminder, taskReminder], context: context)

        #expect(foodReminder.statusEnum == ReminderStatus.failed)
        #expect(taskReminder.statusEnum == ReminderStatus.skipped)
        let actions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType)
        #expect(actions.contains("compensateFailed"))
        #expect(actions.contains("compensateSkipped"))
    }

    @MainActor
    @Test func reminderCompletionServiceReopenAndSnoozeWriteLedgerEvents() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "服药", relatedEntityType: EntityKind.human.rawValue, relatedEntityId: UUID().uuidString)
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(3_600))
        context.insert(event)
        context.insert(reminder)

        ReminderCompletionService.complete(reminder, by: "human-1", context: context)
        ReminderCompletionService.reopen(reminder, by: "human-1", context: context, reschedule: false)
        ReminderCompletionService.snoozeOneDay(reminder, by: "human-1", context: context, reschedule: false)

        let actions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType)
        #expect(actions.contains("complete"))
        #expect(actions.contains("reopen"))
        #expect(actions.contains("snoozeOneDay"))
        #expect(reminder.statusEnum == ReminderStatus.pending)
        #expect(reminder.scheduledAt > Date())
    }

    @MainActor
    @Test func plannedFeedCompletionArchivesReminderAndActualCareLog() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "早餐 45g",
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(-60))
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)

        CareEventService.completePlannedFeed(pet: pet, reminder: reminder, context: context, executorId: "human-1")

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(reminder.statusEnum == ReminderStatus.completed)
        #expect(ledger.contains { $0.actionType == "completePlannedCare" && $0.sourceReminderId == reminder.id.uuidString })
        #expect(ledger.contains { $0.eventKindEnum == .care && $0.sourceEventId == event.id.uuidString && $0.sourceReminderId == reminder.id.uuidString })
    }

    @MainActor
    @Test func feedTodayStateUsesManualGoalWhenNoPlanExists() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        context.insert(PetCareLog(date: now.addingTimeInterval(-3_600), type: .feeding, amountGrams: 30, note: PetCareLog.manualFeedNoteMarker, pet: pet))
        context.insert(PetCareLog(date: now.addingTimeInterval(-1_800), type: .feeding, amountGrams: 40, note: PetCareLog.manualFeedNoteMarker, pet: pet))
        try context.save()

        let state = FeedTodayState(pet: pet, allEvents: [], manualGoalCount: 3, now: now, calendar: calendar)

        #expect(!state.hasTodayPlan)
        #expect(state.completedCount == 2)
        #expect(state.targetCount == 3)
        #expect(!state.isComplete)
        #expect(state.todayFeedGrams == 70)
    }

    @MainActor
    @Test func feedTodayStateUsesPlanProgressAndKeepsOverduePlanActionable() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        let breakfast = Event(
            title: "早餐 35g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let dinner = Event(
            title: "晚餐 45g",
            startDate: dateForTest(year: 2026, month: 5, day: 8, hour: 11),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let completedBreakfast = Reminder(event: breakfast, scheduledAt: breakfast.startDate)
        completedBreakfast.statusEnum = .completed
        let failedDinner = Reminder(event: dinner, scheduledAt: dinner.startDate)
        failedDinner.statusEnum = .failed
        context.insert(pet)
        context.insert(breakfast)
        context.insert(dinner)
        context.insert(completedBreakfast)
        context.insert(failedDinner)
        context.insert(PetCareLog(date: now, type: .feeding, amountGrams: 20, note: PetCareLog.manualFeedNoteMarker, pet: pet))
        try context.save()

        let state = FeedTodayState(pet: pet, allEvents: [breakfast, dinner], manualGoalCount: 1, now: now, calendar: calendar)

        #expect(state.hasTodayPlan)
        #expect(state.completedCount == 1)
        #expect(state.targetCount == 2)
        #expect(!state.isComplete)
        #expect(state.nextPendingReminder?.id == failedDinner.id)
        #expect(state.hasOverduePlan)
        #expect(state.manualTodayLogs.count == 1)
    }

    @MainActor
    @Test func careLedgerBackfillIsIdempotent() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let log = PetCareLog(date: Date(), type: .watering, amountMl: 200, pet: pet, executorId: "human-1")
        context.insert(pet)
        context.insert(log)
        try context.save()

        try CareLedgerBackfillService.backfill(context: context)
        try CareLedgerBackfillService.backfill(context: context)

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(ledger.first?.legacyModelName == "PetCareLog")
        #expect(ledger.first?.legacyModelId == log.id.uuidString)
    }

    @MainActor
    @Test func backupRestoresHumanFieldsAndLogRelationships() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let human = Human(name: "Ava", avatarEmoji: "A")
        human.mbti = "INTJ"
        human.themeColorHex = "C8FF00"
        human.heightCm = 168
        human.setPrivate(.weight, true)
        human.avatarImageData = Data([1, 2, 3])
        sourceContext.insert(human)
        sourceContext.insert(HumanWeightLog(weight: 55, human: human))
        sourceContext.insert(HumanWorkoutLog(type: .running, durationMinutes: 30, human: human))
        CareLedgerService.record(
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .weight,
            actionType: "humanWeight",
            amountValue: 55,
            amountUnit: "kg",
            source: .service,
            legacyModelName: "HumanWeightLog",
            legacyModelId: "weight-log",
            context: sourceContext,
            save: false
        )
        try sourceContext.save()

        let url = try await DataBackupManager.shared.exportJSON(context: sourceContext)
        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        try await DataBackupManager.shared.importJSON(from: url, context: targetContext)

        let restoredHumans = try targetContext.fetch(FetchDescriptor<Human>())
        let restored = try #require(restoredHumans.first)
        #expect(restored.mbti == "INTJ")
        #expect(restored.themeColorHex == "C8FF00")
        #expect(restored.heightCm == 168)
        #expect(restored.isPrivate(.weight, viewedBy: UUID()))
        #expect(restored.avatarImageData == Data([1, 2, 3]))

        let weights = try targetContext.fetch(FetchDescriptor<HumanWeightLog>())
        let workouts = try targetContext.fetch(FetchDescriptor<HumanWorkoutLog>())
        #expect(weights.first?.human?.id == restored.id)
        #expect(workouts.first?.human?.id == restored.id)

        let ledger = try targetContext.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.first?.eventKindEnum == .weight)
        #expect(ledger.first?.subjectId == restored.id.uuidString)
    }

    @MainActor
    @Test func backupRestoresReminderAndLedgerArchiveRelationship() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let petId = UUID().uuidString
        let event = Event(title: "晚餐", eventType: EventType.foodChange.rawValue, relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: petId)
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(3_600))
        sourceContext.insert(event)
        sourceContext.insert(reminder)
        CareLedgerService.recordReminderState(
            reminder: reminder,
            actionType: "scheduleSuccess",
            actorId: nil,
            source: .service,
            context: sourceContext
        )
        try sourceContext.save()

        let url = try await DataBackupManager.shared.exportJSON(context: sourceContext)
        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        try await DataBackupManager.shared.importJSON(from: url, context: targetContext)

        let restoredEvents = try targetContext.fetch(FetchDescriptor<Event>())
        let restoredReminders = try targetContext.fetch(FetchDescriptor<Reminder>())
        let restoredLedger = try targetContext.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(restoredEvents.count == 1)
        #expect(restoredReminders.first?.event?.id == restoredEvents.first?.id)
        #expect(restoredLedger.first?.sourceEventId == event.id.uuidString)
        #expect(restoredLedger.first?.sourceReminderId == reminder.id.uuidString)
    }

    @MainActor
    @Test func backupRestoresRetentionAndMedicationModels() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Ava", avatarEmoji: "A")
        sourceContext.insert(pet)
        sourceContext.insert(human)

        sourceContext.insert(PetPhotoLog(imageData: Data([9, 8, 7]), note: "first photo", pet: pet, locationLatitude: 1.2, locationLongitude: 3.4, locationPlacename: "Home"))

        let document = PetDocument(title: "Passport", category: .passport, pet: pet)
        document.issueDate = Date()
        document.issuingAuthority = "Vet"
        document.notes = "with attachment"
        let attachment = PetDocumentAttachment(data: Data([1, 1, 2]), filename: "pass.png", isImage: true)
        document.attachments.append(attachment)
        sourceContext.insert(document)
        sourceContext.insert(attachment)

        let insurance = PetInsurance(companyName: "SafePet", policyNumber: "P1", productName: "Care", annualPremium: 120, coverageAmount: 1_000, pet: pet)
        let claim = InsuranceClaim(totalExpense: 200, claimedAmount: 100, approvedAmount: 80, status: .approved, note: "claim", insurance: insurance)
        sourceContext.insert(insurance)
        sourceContext.insert(claim)

        let petMedication = PetMedication(name: "Meds", dosage: "1 pill", frequency: .weekly, pet: pet)
        petMedication.customFrequencyNote = "Sunday"
        sourceContext.insert(petMedication)

        let humanMedication = HumanMedication(humanId: human.id.uuidString, name: "Vitamin", dosage: "1", frequency: .daily)
        sourceContext.insert(humanMedication)
        sourceContext.insert(HumanMedicationLog(humanId: human.id.uuidString, medicationId: humanMedication.id.uuidString, scheduledTime: Date(), status: .taken, recordedTime: Date()))

        sourceContext.insert(SymptomLog(category: .skin, symptomName: "itch", severity: .moderate, note: "watch", photoData: Data([4, 5]), pet: pet))
        sourceContext.insert(HeatCycleLog(status: .estrus, note: "normal", isMated: true, pet: pet))
        try sourceContext.save()

        let url = try await DataBackupManager.shared.exportJSON(context: sourceContext)
        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        try await DataBackupManager.shared.importJSON(from: url, context: targetContext)

        #expect(try targetContext.fetch(FetchDescriptor<PetPhotoLog>()).first?.imageData == Data([9, 8, 7]))
        #expect(try targetContext.fetch(FetchDescriptor<PetDocument>()).first?.attachments.first?.data == Data([1, 1, 2]))
        #expect(try targetContext.fetch(FetchDescriptor<PetInsurance>()).first?.claims.first?.approvedAmount == 80)
        #expect(try targetContext.fetch(FetchDescriptor<PetMedication>()).first?.customFrequencyNote == "Sunday")
        #expect(try targetContext.fetch(FetchDescriptor<HumanMedication>()).first?.name == "Vitamin")
        #expect(try targetContext.fetch(FetchDescriptor<HumanMedicationLog>()).first?.status == .taken)
        #expect(try targetContext.fetch(FetchDescriptor<SymptomLog>()).first?.photoData == Data([4, 5]))
        #expect(try targetContext.fetch(FetchDescriptor<HeatCycleLog>()).first?.isMated == true)
    }

    @MainActor
    @Test func reminderSchedulingServiceSkipsMissingEventAndDuplicateNotification() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let orphan = Reminder(scheduledAt: Date().addingTimeInterval(3_600))
        context.insert(orphan)
        let missingResult = await ReminderSchedulingService.scheduleIfNeeded(reminder: orphan, context: context)
        #expect(missingResult == .missingEvent)

        let event = Event(title: "喂水", relatedEntityType: EntityKind.pet.rawValue, relatedEntityId: UUID().uuidString)
        let duplicate = Reminder(event: event, scheduledAt: Date().addingTimeInterval(3_600))
        context.insert(event)
        context.insert(duplicate)
        let duplicateResult = await ReminderSchedulingService.scheduleIfNeeded(
            reminder: duplicate,
            context: context,
            existingNotificationIds: [duplicate.notificationId]
        )
        #expect(duplicateResult == .skippedDuplicate)

        let actions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType)
        #expect(actions.contains("scheduleMissingEvent"))
        #expect(actions.contains("scheduleDuplicate"))
    }

    @MainActor
    @Test func careLedgerServiceRecordsCoconutAndPetCareAmounts() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let feed = PetCareLog(type: .feeding, amountGrams: 36, pet: pet, executorId: "human-1")
        context.insert(pet)
        context.insert(feed)

        CareLedgerService.recordPetCare(log: feed, pet: pet, source: .quickAction, coconutDelta: 3, context: context)
        CareLedgerService.recordCoconut(delta: 2, title: "奖励", actorId: "human-1", actorName: "Ava", source: .economy, context: context)

        let events = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(CareLedgerService.rewardDelta((humanGot: -1, petGot: 4)) == 4)
        #expect(events.contains { $0.eventKindEnum == .care && $0.actionType == CareType.feeding.rawValue && $0.amountValue == 36 && $0.amountUnit == "g" })
        #expect(events.contains { $0.eventKindEnum == .coconut && $0.coconutDelta == 2 && $0.note.contains("Ava") })
    }

    @MainActor
    @Test func privacyServiceCoversHumanSensitiveActions() async throws {
        let owner = Human(name: "Owner")
        let viewer = Human(name: "Viewer")
        owner.setPrivate(.workout, true)
        owner.setPrivate(.medication, true)
        owner.setPrivate(.wishlist, true)
        owner.setPrivate(.expense, true)

        #expect(PrivacyService.field(forHumanAction: "humanWorkout") == .workout)
        #expect(PrivacyService.field(forHumanAction: "medication") == .medication)
        #expect(PrivacyService.field(forHumanAction: "wishlist") == .wishlist)
        #expect(PrivacyService.field(forHumanAction: "humanExpense") == .expense)
        #expect(PrivacyService.badgeText(for: .medication, human: owner, viewedBy: viewer.id) == "仅自己")
        #expect(PrivacyService.badgeText(for: .expense, human: owner, viewedBy: owner.id) == "公开")
        #expect(PrivacyService.lockedMessage(for: .workout) == "运动数据仅本人可见")
    }

    @MainActor
    @Test func quickActionLimitCountsOnlyTargetPetItems() async throws {
        let pet = Pet(name: "Momo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "狗")
        let petItems = (0..<8).map { index in
            QuickActionItem(label: "动作\(index)", icon: "pawprint", colorHex: "C8FF00", petId: pet.id, actionType: "action\(index)")
        }
        let humanItem = QuickActionItem(label: "体重", icon: "scalemass", colorHex: "80FFEA", petId: pet.id, actionType: "humanWeight", entityId: UUID(), entityKind: .human)
        let otherPetItem = QuickActionItem(label: "喂食", icon: "fork.knife", colorHex: "FFDD44", petId: otherPet.id, actionType: "feed")

        #expect(QuickActionLimit.maxItemsPerEntity == 8)
        #expect(QuickActionLimit.count(for: pet, in: petItems + [humanItem, otherPetItem]) == 8)
        #expect(QuickActionLimit.count(for: otherPet, in: petItems + [otherPetItem]) == 1)
    }

    @MainActor
    @Test func petFoodStockUsesActualFeedAmountsAfterRestock() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let restock = Date().addingTimeInterval(-86_400)
        pet.foodTrackingMode = .precise
        pet.restockDate = restock
        pet.restockWeight = 1
        pet.dailyPortionGrams = 50
        context.insert(pet)
        context.insert(PetCareLog(date: restock.addingTimeInterval(-60), type: .feeding, amountGrams: 500, pet: pet))
        context.insert(PetCareLog(date: restock.addingTimeInterval(60), type: .feeding, amountGrams: 120, pet: pet))
        context.insert(PetCareLog(date: restock.addingTimeInterval(120), type: .feeding, amountGrams: 0, pet: pet))
        context.insert(PetCareLog(date: restock.addingTimeInterval(180), type: .feeding, amountGrams: 10, note: FeedLogMetadata.treatFeedNoteMarker, pet: pet))
        try context.save()

        #expect(pet.foodConsumedSinceRestock == 170)
        #expect(pet.remainingFoodGrams == 830)
        #expect(pet.remainingFoodDays == 4)
    }

    @MainActor
    @Test func feedStockCalculatorUsesRecentMainFoodAverageBeforeFallbacks() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        let restock = dateForTest(year: 2026, month: 5, day: 1)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pet = Pet(name: "Momo", species: "猫")
        pet.restockDate = restock
        pet.restockWeight = 2
        pet.dailyPortionGrams = 60
        context.insert(pet)
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 7, hour: 8), type: .feeding, amountGrams: 100, pet: pet))
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 8, hour: 8), type: .feeding, amountGrams: 50, pet: pet))
        context.insert(PetCareLog(date: dateForTest(year: 2026, month: 5, day: 8, hour: 9), type: .feeding, amountGrams: 10, note: FeedLogMetadata.treatFeedNoteMarker, pet: pet))
        let auto = Event(
            title: "自动喂食器 40g",
            startDate: now,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(auto)
        try context.save()

        let snapshot = FeedStockCalculator.snapshot(for: pet, events: [auto], now: now, calendar: calendar)

        #expect(snapshot.consumedGrams == 150)
        #expect(snapshot.remainingGrams == 1850)
        #expect(snapshot.estimatedDailyBasis == .recentAverage)
        #expect(abs(snapshot.estimatedDailyGrams - 75) < 0.001)
    }

    @MainActor
    @Test func feedStockCalculatorFallsBackToAutoRulesThenDefaultPortion() async throws {
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 12)
        let pet = Pet(name: "Momo", species: "猫")
        pet.restockDate = dateForTest(year: 2026, month: 5, day: 8)
        pet.restockWeight = 2
        pet.dailyPortionGrams = 60
        let auto = Event(
            title: "自动喂食器 40g",
            startDate: now,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )

        let autoEstimate = FeedStockCalculator.snapshot(for: pet, events: [auto], now: now)
        let defaultEstimate = FeedStockCalculator.snapshot(for: pet, events: [], now: now)

        #expect(autoEstimate.estimatedDailyBasis == .autoRules)
        #expect(autoEstimate.estimatedDailyGrams == 40)
        #expect(defaultEstimate.estimatedDailyBasis == .defaultPortion)
        #expect(defaultEstimate.estimatedDailyGrams == 60)
    }

    @MainActor
    @Test func autoFeederMaterializesDueLogsIdempotently() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = dateForTest(year: 2026, month: 5, day: 8, hour: 21)
        let pet = Pet(name: "Momo", species: "猫")
        let auto = Event(
            title: "自动喂食器 40g",
            startDate: dateForTest(year: 2026, month: 5, day: 7, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        auto.recurrenceDays = 1
        context.insert(pet)
        context.insert(auto)
        try context.save()

        let first = FeedAutoLogMaterializer.materializeDueLogs(pet: pet, allEvents: [auto], context: context, now: now, calendar: calendar)
        let second = FeedAutoLogMaterializer.materializeDueLogs(pet: pet, allEvents: [auto], context: context, now: now, calendar: calendar)
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(first == 2)
        #expect(second == 0)
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.isAutoFeedLogEntry && $0.amountGrams == 40 })
    }

    @MainActor
    @Test func legacyPlannedFeedEventsStayManualReminders() async throws {
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "早餐 45g",
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )

        let state = FeedRuleState(pet: pet, allEvents: [event])

        #expect(state.manualReminderEvents.count == 1)
        #expect(state.autoFeederEvents.isEmpty)
    }

    @MainActor
    @Test func todayFocusServiceRefreshesAndPrioritizesContent() async throws {
        let pet = Pet(name: "Momo", species: "猫")
        let feedQuest = IslandQuest(id: "q_feed_\(pet.id.uuidString)", emoji: "🍖", title: "喂食", subtitle: "今天还没喂", isCompleted: false, targetPetId: pet.id, targetPlantId: nil)
        let feedLog = PetCareLog(type: .feeding, amountGrams: 20, pet: pet)

        let refreshed = TodayFocusService.refreshedQuests([feedQuest], careLogs: [feedLog], walkLogs: [], pottyLogs: [])
        #expect(refreshed.first?.isCompleted == true)
        #expect(refreshed.first?.emoji == "✅")

        let pending = IslandQuest(id: "q_custom", emoji: "!", title: "待办", subtitle: "优先", isCompleted: false, targetPetId: nil, targetPlantId: nil)
        if case .quest(let selected) = TodayFocusService.decide(pets: [], plants: [], quests: [pending], careLogs: [], walkLogs: [], pottyLogs: [], memory: nil) {
            #expect(selected.id == "q_custom")
        } else {
            Issue.record("未完成委托应优先成为 Today Focus")
        }

        let done = IslandQuest(id: "q_done", emoji: "✅", title: "已完成", subtitle: "", isCompleted: true, targetPetId: nil, targetPlantId: nil)
        if case .celebrate = TodayFocusService.decide(pets: [], plants: [], quests: [done], careLogs: [], walkLogs: [], pottyLogs: [], memory: nil) {
        } else {
            Issue.record("全部完成后应进入庆祝态")
        }

        if case .welcome = TodayFocusService.decide(pets: [], plants: [], quests: [], careLogs: [], walkLogs: [], pottyLogs: [], memory: nil) {
        } else {
            Issue.record("没有任务和历史时应进入欢迎态")
        }

        if case .celebrate = TodayFocusService.decide(pets: [pet], plants: [], quests: [], careLogs: [], walkLogs: [], pottyLogs: [], memory: nil) {
        } else {
            Issue.record("有成员但没有任务时应显示恭喜提示")
        }
    }

    @MainActor
    @Test func todayFocusTreatsWalkAsPlayCompletion() async throws {
        let pet = Pet(name: "Momo", species: "狗")
        let playQuest = IslandQuest(
            id: "q_play_\(pet.id.uuidString)",
            emoji: "🎾",
            title: "陪 Momo 玩一会儿",
            subtitle: "",
            isCompleted: false,
            targetPetId: pet.id,
            targetPlantId: nil
        )
        let walkLog = PetWalkLog(pet: pet)

        let refreshed = TodayFocusService.refreshedQuests([playQuest], pets: [pet], careLogs: [], walkLogs: [walkLog], pottyLogs: [])

        #expect(refreshed.first?.isCompleted == true)
    }

    @MainActor
    @Test func islandNegativeFeedbackDoesNotWarnAfterTodayCareCheckIn() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.currentStreak = 0
        pet.lastCheckInDate = nil
        context.insert(pet)
        context.insert(PetCareLog(type: .watering, amountMl: 250, pet: pet))
        try context.save()

        let signals = IslandNegativeFeedback.signals(pets: [pet])
        #expect(!signals.contains { $0.title == "今日还未打卡" })
    }

    @MainActor
    @Test func islandQuestEngineDefaultsToLightweightNewPetTasks() async throws {
        let pet = Pet(name: "Momo", species: "猫")

        let quests = IslandQuestEngine.todayQuests(pets: [pet], reminders: [])
        let ids = quests.map(\.id)

        #expect(ids.contains("q_play_\(pet.id.uuidString)"))
        #expect(ids.contains("q_weight_\(pet.id.uuidString)"))
        #expect(ids.contains("q_moment_\(pet.id.uuidString)"))
        #expect(!ids.contains { $0.hasPrefix("q_feed_") })
        #expect(!ids.contains { $0.hasPrefix("q_water_") })
    }

    @MainActor
    @Test func islandQuestEngineDoesNotCreatePlayTaskForEveryPetAfterInteraction() async throws {
        let momo = Pet(name: "Momo", species: "狗")
        let lilo = Pet(name: "Lilo", species: "猫")
        momo.walkLogs.append(PetWalkLog(pet: momo))

        let quests = IslandQuestEngine.todayQuests(pets: [momo, lilo], reminders: [])

        #expect(!quests.contains { $0.id.hasPrefix("q_play_") })
    }

    @Test func humanMedicationScheduleMetadataRoundTripsAndHidesNotes() async throws {
        let metadata = HumanMedicationScheduleMetadata(doseMinutes: [20 * 60, 8 * 60, 8 * 60], weeklyWeekday: 5)
        let notes = HumanMedicationScheduleMetadata.composeNotes(visibleNotes: "饭后服用", metadata: metadata)
        let parsed = HumanMedicationScheduleMetadata.parse(from: notes)

        #expect(parsed?.doseMinutes == [8 * 60, 20 * 60])
        #expect(parsed?.weeklyWeekday == 5)
        #expect(HumanMedicationScheduleMetadata.visibleNotes(from: notes) == "饭后服用")
        #expect(!HumanMedicationScheduleMetadata.visibleNotes(from: notes).contains("ohana-human-medication-schedule"))
    }

    @Test func humanMedicationScheduleGeneratesFixedWeeklyAndManualDoses() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let thursday = dateForTest(year: 2026, month: 5, day: 7, hour: 10, minute: 0)

        let twice = HumanMedication(
            humanId: UUID().uuidString,
            name: "Vitamin",
            dosage: "1",
            frequency: .twiceDaily,
            startDate: thursday
        )
        twice.notes = HumanMedicationScheduleMetadata.composeNotes(
            visibleNotes: "",
            metadata: HumanMedicationScheduleMetadata(doseMinutes: [8 * 60, 20 * 60])
        )
        #expect(HumanMedicationSchedulePlan.doses(on: thursday, for: twice, calendar: calendar).count == 2)

        let weekly = HumanMedication(
            humanId: UUID().uuidString,
            name: "Weekly",
            dosage: "1",
            frequency: .weekly,
            startDate: thursday
        )
        weekly.notes = HumanMedicationScheduleMetadata.composeNotes(
            visibleNotes: "",
            metadata: HumanMedicationScheduleMetadata(doseMinutes: [9 * 60], weeklyWeekday: 5)
        )
        #expect(HumanMedicationSchedulePlan.doses(on: thursday, for: weekly, calendar: calendar).count == 1)
        #expect(HumanMedicationSchedulePlan.doses(on: dateForTest(year: 2026, month: 5, day: 8), for: weekly, calendar: calendar).isEmpty)

        let manual = HumanMedication(
            humanId: UUID().uuidString,
            name: "As needed",
            dosage: "1",
            frequency: .asNeeded,
            startDate: thursday
        )
        #expect(HumanMedicationSchedulePlan.doses(on: thursday, for: manual, calendar: calendar).isEmpty)
    }

    @Test func humanMedicationScheduleFallsBackToLegacyFirstDoseTime() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = dateForTest(year: 2026, month: 5, day: 7)
        let firstDose = dateForTest(year: 2026, month: 5, day: 7, hour: 9, minute: 30)
        let med = HumanMedication(
            humanId: UUID().uuidString,
            name: "Legacy",
            dosage: "1",
            frequency: .twiceDaily,
            firstDoseTime: firstDose,
            startDate: day
        )

        #expect(HumanMedicationSchedulePlan.doseMinutes(for: med, calendar: calendar) == [9 * 60 + 30, 21 * 60 + 30])
    }

    @MainActor
    @Test func humanMedicationDoseLogStoreUpsertsScheduledMinute() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let humanId = UUID().uuidString
        let medicationId = UUID().uuidString
        let scheduled = dateForTest(year: 2026, month: 5, day: 7, hour: 8, minute: 0)

        let first = HumanMedicationLogStore.applyDoseStatus(
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduled,
            status: .taken,
            existingLogs: [],
            context: context
        )
        #expect(first.didChange)
        #expect(first.shouldRecordLedgerEvent)
        try context.save()

        let logs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        let second = HumanMedicationLogStore.applyDoseStatus(
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduled.addingTimeInterval(12),
            status: .taken,
            existingLogs: logs,
            context: context
        )
        #expect(!second.didChange)
        #expect(!second.shouldRecordLedgerEvent)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).count == 1)

        let third = HumanMedicationLogStore.applyDoseStatus(
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduled,
            status: .skipped,
            existingLogs: logs,
            context: context
        )
        #expect(third.didChange)
        #expect(third.shouldRecordLedgerEvent)
        #expect(third.log?.status == .skipped)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).count == 1)
    }

    @MainActor
    @Test func humanMedicationDisplayGroupsAndFrequencyLocalization() async throws {
        let now = dateForTest(year: 2026, month: 5, day: 7)
        let humanId = UUID().uuidString
        let current = HumanMedication(humanId: humanId, name: "Current", frequency: .daily, startDate: now)
        let future = HumanMedication(humanId: humanId, name: "Future", frequency: .daily, startDate: dateForTest(year: 2026, month: 5, day: 8))
        let ended = HumanMedication(humanId: humanId, name: "Ended", frequency: .daily, startDate: dateForTest(year: 2026, month: 5, day: 1), endDate: dateForTest(year: 2026, month: 5, day: 2))
        let stopped = HumanMedication(humanId: humanId, name: "Stopped", frequency: .daily, startDate: now)
        stopped.isActive = false
        let manual = HumanMedication(humanId: humanId, name: "Manual", frequency: .asNeeded, startDate: now)

        #expect(HumanMedicationSchedulePlan.displayGroup(for: current, now: now) == .current)
        #expect(HumanMedicationSchedulePlan.displayGroup(for: future, now: now) == .notStarted)
        #expect(HumanMedicationSchedulePlan.displayGroup(for: ended, now: now) == .ended)
        #expect(HumanMedicationSchedulePlan.displayGroup(for: stopped, now: now) == .stopped)
        #expect(HumanMedicationSchedulePlan.displayGroup(for: manual, now: now) == .manual)
        #expect(MedicationFrequency.twiceDaily.displayTitle(l: L10n("zh")) == "每天两次")
        #expect(MedicationFrequency.twiceDaily.displayTitle(l: L10n("en")) == "Twice daily")
        #expect(MedicationFrequency.twiceDaily.displayTitle(l: L10n("de")) == "Zweimal täglich")
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsBasicInfoForEmptyProfile() async throws {
        let pet = Pet(name: "Momo", species: "猫")

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 0)
        #expect(snapshot.nextStep.kind == .basicInfo)
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsDocumentsAfterBasicInfo() async throws {
        let pet = archiveReadyPet()

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 1)
        #expect(snapshot.nextStep.kind == .documents)
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsMomentsAfterProtection() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = archiveReadyPet()
        context.insert(pet)
        context.insert(PetDocument(title: "疫苗本", category: .vaccine, pet: pet))
        try context.save()

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 2)
        #expect(snapshot.nextStep.kind == .moments)
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsWeightAfterMemory() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = archiveReadyPet()
        context.insert(pet)
        context.insert(PetInsurance(companyName: "Ohana Care", pet: pet))
        context.insert(PetPhotoLog(imageData: Data([1, 2, 3]), note: "first photo", pet: pet))
        try context.save()

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 3)
        #expect(snapshot.nextStep.kind == .weight)
    }

    @MainActor
    @Test func archiveMemorySnapshotRecommendsRetentionWhenComplete() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = archiveReadyPet()
        pet.currentStreak = 3
        context.insert(pet)
        context.insert(PetDocument(title: "疫苗本", category: .vaccine, pet: pet))
        context.insert(PetPhotoLog(imageData: Data([1, 2, 3]), note: "first photo", pet: pet))
        context.insert(PetWeightLog(weight: 4.2, pet: pet))
        try context.save()

        let snapshot = ArchiveMemorySnapshot(pet: pet)

        #expect(snapshot.score == 5)
        #expect(snapshot.nextStep.kind == .retention)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV37.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func archiveReadyPet() -> Pet {
        Pet(
            name: "Momo",
            species: "猫",
            breed: "狸花猫",
            birthday: dateForTest(year: 2023, month: 4, day: 2),
            homeDate: dateForTest(year: 2024, month: 1, day: 3)
        )
    }

    private func dateForTest(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
