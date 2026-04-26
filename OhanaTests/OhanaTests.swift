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
        try context.save()

        #expect(pet.foodConsumedSinceRestock == 170)
        #expect(pet.remainingFoodGrams == 830)
        #expect(pet.remainingFoodDays == 16)
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

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV37.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
