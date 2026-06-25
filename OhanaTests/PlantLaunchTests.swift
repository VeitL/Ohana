import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PlantLaunchTests {
    @Test func carePlanReadsOneDayDeferralLog() throws {
        let now = makeDate(year: 2026, month: 6, day: 8)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
        let plant = Plant(name: "Fern", wateringIntervalDays: 1)
        plant.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        plant.lastWateredDate = Calendar.current.date(byAdding: .day, value: -3, to: now)
        plant.careLogs.append(PlantCareLog(
            date: now,
            careType: .customNote,
            note: "defer:watering:\(ISO8601DateFormatter().string(from: tomorrow))"
        ))

        let task = try #require(PlantCarePlanService.nextTask(for: plant, now: now))

        #expect(task.careType == .watering)
        #expect(task.daysUntilDue == 1)
        #expect(!task.isOverdue)
    }

    @Test func localDiagnosisFallbackAlwaysReturnsUncertaintyAndMultipleCauses() async {
        let result = await LocalPlantIntelligenceFallback().diagnosePlant(
            imageData: nil,
            symptoms: ["黄叶"]
        )

        #expect(!result.uncertaintyMessage.isEmpty)
        #expect(result.causes.count >= 2)
        #expect(result.causes.count <= 3)
        #expect(result.causes.allSatisfy { !$0.steps.isEmpty })
    }

    @Test func plantBackupRoundTripsLaunchProfileFields() throws {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let plant = Plant(
            name: "Spider",
            species: "吊兰",
            location: "Kitchen",
            avatarEmoji: "🌿",
            wateringIntervalDays: 6,
            fertilizingIntervalDays: 40,
            themeColorHex: "4CAF50",
            potDiameterCm: 11,
            potMaterialRaw: "ceramic",
            soilTypeRaw: "airy mix",
            isIndoor: true,
            windowDirection: .east,
            lightLevel: .medium,
            healthStatus: .watching,
            catalogSpeciesId: "chlorophytum-comosum",
            isToxicToCats: false,
            isToxicToDogs: false,
            isToxicToChildren: false,
            isIndoorSuitable: true,
            remindersEnabled: false
        )
        plant.lastHealthCheckDate = makeDate(year: 2026, month: 6, day: 7)
        sourceContext.insert(plant)
        try sourceContext.save()

        let backup = try TestDataBackupManagerProjection.manager.buildBackup(context: sourceContext)
        let target = try makeInMemoryContainer()
        try TestDataBackupManagerProjection.manager.applyBackup(
            backup,
            context: target.mainContext,
            projectionManager: nil
        )

        let restored = try #require(try target.mainContext.fetch(FetchDescriptor<Plant>()).first)
        #expect(PlantUnlockPolicy.hasExistingPlantData())
        #expect(restored.potDiameterCm == 11)
        #expect(restored.potMaterialRaw == "ceramic")
        #expect(restored.soilTypeRaw == "airy mix")
        #expect(restored.windowDirection == .east)
        #expect(restored.lightLevel == .medium)
        #expect(restored.healthStatus == .watching)
        #expect(restored.catalogSpeciesId == "chlorophytum-comosum")
        #expect(restored.remindersEnabled == false)
        #expect(restored.lastHealthCheckDate == plant.lastHealthCheckDate)
    }

    @Test func plantBackupRoundTripsCareLogsAndPhotos() throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let date = makeDate(year: 2026, month: 6, day: 8, hour: 7)
        let plant = Plant(name: "Pilea", species: "Pilea peperomioides", location: "Desk")
        let log = PlantCareLog(
            date: date,
            careType: .newLeaf,
            note: "Tiny new leaf",
            executorId: "plant-owner",
            photoData: Data([9, 8, 7]),
            healthStatus: .thriving
        )
        log.id = UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? log.id
        plant.careLogs.append(log)
        sourceContext.insert(plant)
        sourceContext.insert(log)
        try sourceContext.save()

        let backup = try TestDataBackupManagerProjection.manager.buildBackup(context: sourceContext)
        let target = try makeInMemoryContainer()
        try TestDataBackupManagerProjection.manager.applyBackup(
            backup,
            context: target.mainContext,
            projectionManager: nil
        )

        let restoredLogs = try target.mainContext.fetch(FetchDescriptor<PlantCareLog>())
        let restored = try #require(restoredLogs.first)
        #expect(restoredLogs.count == 1)
        #expect(restored.id == log.id)
        #expect(restored.date == date)
        #expect(restored.careType == .newLeaf)
        #expect(restored.note == "Tiny new leaf")
        #expect(restored.executorId == "plant-owner")
        #expect(restored.photoData == Data([9, 8, 7]))
        #expect(restored.healthStatus == .thriving)
        #expect(restored.plant?.name == "Pilea")
    }

    @Test func creatingPlantMarksExistingPlantDataForGrandfatherAccess() throws {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let container = try makeInMemoryContainer()
        let input = PlantCreationCommandInput(
            name: "Fern",
            species: "Boston fern",
            location: "Living room",
            avatarEmoji: "🌿",
            wateringIntervalDays: 3,
            fertilizingIntervalDays: 30
        )

        PlantCreationCommandService.createPlant(
            input: input,
            context: container.mainContext,
            scheduleNotifications: false
        )

        #expect(PlantUnlockPolicy.hasExistingPlantData())
        #expect(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
    }

    @Test func plantCarePlanSyncMaterializesCalendarEventsAndReminders() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 17, hour: 8)
        let plant = Plant(name: "Fern", wateringIntervalDays: 1, fertilizingIntervalDays: 14)
        plant.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        plant.lastWateredDate = Calendar.current.date(byAdding: .day, value: -2, to: now)
        plant.lastFertilizedDate = Calendar.current.date(byAdding: .day, value: -20, to: now)
        context.insert(plant)
        try context.save()

        let result = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: false
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let planEvents = events.filter { $0.isAllDay && $0.title.contains("植物计划") }
        #expect(result.eventIDs.count == 7)
        #expect(result.reminderIDs.count == 7)
        #expect(planEvents.count == 7)
        #expect(reminders.count == 7)
        #expect(planEvents.contains { $0.eventType == EventType.watering.rawValue && $0.recurrenceDays == 1 })
        #expect(planEvents.contains { $0.eventType == EventType.fertilizing.rawValue && $0.recurrenceDays == 14 })
        #expect(planEvents.contains { $0.eventType == EventType.plantPestCheck.rawValue })
        let remindersArePending = reminders.allSatisfy(\.isPending)
        #expect(remindersArePending)
    }

    @Test func disabledPlantRemindersRemoveMaterializedPlantPlansAndNotifications() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 18, hour: 8)
        let plant = Plant(name: "Pilea", wateringIntervalDays: 1, fertilizingIntervalDays: 14)
        plant.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        context.insert(plant)
        try context.save()

        PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: false
        )
        let notificationIDs = Set(try context.fetch(FetchDescriptor<Reminder>()).map(\.notificationId))
        plant.remindersEnabled = false
        let notifications = PlantReminderNotificationSchedulerSpy()

        let removed = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: false,
            notifications: notifications
        )

        #expect(removed.removedEventIDs.count == 7)
        #expect(removed.removedReminderIDs.count == 7)
        let remainingEvents = try context.fetch(FetchDescriptor<Event>())
        let remainingReminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(remainingEvents.isEmpty)
        #expect(remainingReminders.isEmpty)
        #expect(Set(notifications.cancelledNotificationIDs) == notificationIDs)
    }

    @Test func recordingPlantCareRefreshesNextPlanReminder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 19, hour: 9)
        let plant = Plant(name: "Mint", wateringIntervalDays: 2)
        plant.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        plant.lastWateredDate = Calendar.current.date(byAdding: .day, value: -3, to: now)
        context.insert(plant)
        try context.save()

        PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: false
        )
        PlantCareCommandService.recordCare(
            .watering,
            plant: plant,
            executorId: nil,
            context: context,
            now: now,
            scheduleNotifications: false
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        let wateringPlan = try #require(events.first {
            $0.isAllDay && $0.title.contains("植物计划") && $0.eventType == EventType.watering.rawValue
        })
        let expectedDue = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: now))
        #expect(wateringPlan.startDate == expectedDue)
        #expect(wateringPlan.reminders.contains { $0.isPending && $0.scheduledAt > now })
        #expect(events.contains { !$0.isAllDay && $0.eventType == EventType.watering.rawValue })
    }

    @Test func completingPlantCalendarEventWritesCareLogAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 9, hour: 8)
        let plant = Plant(name: "Monstera", wateringIntervalDays: 3)
        let event = Event(
            title: "给龟背竹浇水",
            startDate: now,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        context.insert(plant)
        context.insert(event)
        try context.save()

        let result = CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: now,
            pets: [],
            context: context,
            executorId: nil,
            now: now,
            schedulePlantCareNotifications: false
        )

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result.isCompleted)
        #expect(plant.lastWateredDate == now)
        #expect(logs.count == 1)
        #expect(logs.first?.careType == .watering)
        #expect(logs.first?.plant?.id == plant.id)
        #expect(ledgers.contains {
            $0.eventKind == CareLedgerEventKind.plantCare.rawValue &&
                $0.source == CareLedgerSource.calendar.rawValue &&
                $0.sourceEventId == event.id.uuidString &&
                $0.legacyModelName == "PlantCareLog"
        })
    }

    @Test func completingPlantReminderWritesCareLogAndKeepsReminderLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 10, hour: 10)
        let plant = Plant(name: "Basil", fertilizingIntervalDays: 14)
        let event = Event(
            title: "给罗勒施肥",
            startDate: now,
            eventType: EventType.fertilizing.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: now)
        context.insert(plant)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let didComplete = ReminderCompletionService.complete(
            reminder,
            by: nil,
            context: context,
            notifications: NoopReminderNotificationScheduler(),
            schedulePlantCareNotifications: false
        )

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(didComplete)
        #expect(reminder.statusEnum == .completed)
        #expect(plant.lastFertilizedDate == now)
        #expect(logs.count == 1)
        #expect(logs.first?.careType == .fertilizing)
        #expect(ledgers.contains {
            $0.eventKind == CareLedgerEventKind.plantCare.rawValue &&
                $0.source == CareLedgerSource.reminder.rawValue &&
                $0.sourceEventId == event.id.uuidString &&
                $0.sourceReminderId == reminder.id.uuidString
        })
        #expect(ledgers.contains {
            $0.eventKind == CareLedgerEventKind.reminder.rawValue &&
                $0.actionType == "complete" &&
                $0.sourceReminderId == reminder.id.uuidString
        })
    }

    @Test func calendarCompletedPlantCareCountsForTodayFocusCoconutReward() throws {
        let hadExistingPlantData = PlantUnlockPolicy.hasExistingPlantData()
        PlantUnlockPolicy.noteExistingPlantData()
        defer {
            if hadExistingPlantData {
                PlantUnlockPolicy.noteExistingPlantData()
            } else {
                PlantUnlockPolicy.clearExistingPlantData()
            }
        }

        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 11, hour: 9)
        let human = Human(name: "Plant Owner")
        let pet = Pet(name: "Momo", species: "猫")
        let humanWeightLog = HumanWeightLog(date: now, weight: 66, human: human)
        let playLog = PetCareLog(date: now, type: .play, pet: pet)
        let playLedger = CareLedgerEvent(
            occurredAt: now,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue
        )
        let petWeightLog = PetWeightLog(date: now, weight: 4.8, pet: pet)
        let petWeightLedger = CareLedgerEvent(
            occurredAt: now,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: petWeightLog.weightInKg,
            amountUnit: "kg",
            legacyModelName: "PetWeightLog",
            legacyModelId: petWeightLog.id.uuidString
        )
        let photoLog = PetPhotoLog(imageData: Data([1, 2, 3]), date: now, note: "today", pet: pet)
        let plant = Plant(name: "Pothos", wateringIntervalDays: 1)
        plant.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        plant.lastWateredDate = Calendar.current.date(byAdding: .day, value: -3, to: now)
        plant.lastFertilizedDate = now
        let event = Event(
            title: "给绿萝浇水",
            startDate: now,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        human.weightLogs.append(humanWeightLog)
        pet.careLogs.append(playLog)
        pet.weightLogs.append(petWeightLog)
        pet.photoLogs.append(photoLog)
        context.insert(human)
        context.insert(pet)
        context.insert(humanWeightLog)
        context.insert(playLog)
        context.insert(playLedger)
        context.insert(petWeightLog)
        context.insert(petWeightLedger)
        context.insert(photoLog)
        context.insert(plant)
        context.insert(event)
        try context.save()

        let userKey = human.id.uuidString
        let oldActiveHuman = UserDefaults.standard.string(forKey: "currentActiveHumanId")
        let manager = TestQuestManagerProjection.manager
        let oldCount = manager.coconutCount
        let oldLogs = manager.coconutLogs
        let oldLastReward = manager.lastEconomyRewardResult
        let oldPetWizard = manager.isPetWizardCompleted
        let oldFirstMeal = manager.isFirstMealRecorded
        let oldThemeColor = manager.isThemeColorSet
        defer {
            if let oldActiveHuman {
                UserDefaults.standard.set(oldActiveHuman, forKey: "currentActiveHumanId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")
            }
            manager.coconutCount = oldCount
            manager.coconutLogs = oldLogs
            manager.lastEconomyRewardResult = oldLastReward
            manager.isPetWizardCompleted = oldPetWizard
            manager.isFirstMealRecorded = oldFirstMeal
            manager.isThemeColorSet = oldThemeColor
            manager.persistQuestFlags()
            TodayFocusEconomyService.resetDailyCompletionMarker(userKey: userKey, date: now)
        }

        manager.isPetWizardCompleted = true
        manager.isFirstMealRecorded = true
        manager.isThemeColorSet = true
        manager.persistQuestFlags()
        UserDefaults.standard.set(userKey, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
            memberKey: userKey,
            date: now
        )
        TodayFocusEconomyService.resetDailyCompletionMarker(userKey: userKey, date: now)

        CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: now,
            pets: [],
            context: context,
            executorId: userKey,
            now: now,
            schedulePlantCareNotifications: false
        )
        let reward = TodayFocusEconomyService.awardDailyCompletionIfNeeded(
            context: context,
            executorId: userKey,
            visibleQuests: [
                IslandQuest(
                    id: "q_water_plant_\(plant.id.uuidString)",
                    emoji: "💧",
                    title: "给绿萝浇水",
                    subtitle: "",
                    isCompleted: false,
                    targetPetId: nil,
                    targetPlantId: plant.id
                )
            ],
            now: now,
            questManager: manager
        )
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(reward != nil)
        #expect(plant.lastWateredDate == now)
        #expect(human.coconutBalance == (reward?.totalCoconuts ?? -1))
        #expect(ledger.contains { $0.eventKind == CareLedgerEventKind.plantCare.rawValue })
        #expect(ledger.contains {
            $0.eventKind == CareLedgerEventKind.coconut.rawValue &&
                $0.actionType == "todayFocusDailyCompletion"
        })
    }

    @Test func duePlantWateringAwardsActiveHumanAndCareLedgerDelta() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 12, hour: 9)
        let human = Human(name: "Plant Keeper")
        let plant = Plant(name: "Calathea", wateringIntervalDays: 1)
        plant.lastWateredDate = Calendar.current.date(byAdding: .day, value: -3, to: now)
        context.insert(human)
        context.insert(plant)
        try context.save()

        let restore = prepareEconomyDefaults(
            memberKey: human.id.uuidString,
            careObjectKeys: [plantBudgetKey(plant)],
            date: now
        )
        defer { restore() }

        let result = PlantCareCommandService.recordCare(
            .watering,
            plant: plant,
            executorId: human.id.uuidString,
            context: context,
            now: now,
            economy: StaticCareEventEconomyAwarder(questManager: QuestManager()),
            syncCarePlan: false
        )

        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first(where: {
            $0.eventKind == CareLedgerEventKind.plantCare.rawValue &&
                $0.legacyModelName == "PlantCareLog"
        }))
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let walletTotal = walletEntries.reduce(0) { $0 + $1.delta }

        #expect(result.coconutDelta >= 2)
        #expect(human.coconutBalance == result.coconutDelta)
        #expect(ledger.coconutDelta == result.coconutDelta)
        #expect(walletTotal == result.coconutDelta)
    }

    @Test func notDuePlantWateringDoesNotCallEconomy() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 13, hour: 9)
        let plant = Plant(name: "Mint", wateringIntervalDays: 3)
        plant.lastWateredDate = now
        context.insert(plant)
        try context.save()
        let economy = PlantCareEconomyAwarderSpy(reward: (humanGot: 9, petGot: 0))

        let result = PlantCareCommandService.recordCare(
            .watering,
            plant: plant,
            executorId: nil,
            context: context,
            now: now,
            economy: economy,
            syncCarePlan: false
        )

        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first(where: {
            $0.eventKind == CareLedgerEventKind.plantCare.rawValue
        }))
        #expect(economy.awardCalls.isEmpty)
        #expect(result.coconutDelta == 0)
        #expect(ledger.coconutDelta == 0)
    }

    @Test func differentPlantsHaveIndependentWateringCooldownBuckets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 14, hour: 9)
        let human = Human(name: "Green Thumb")
        let first = Plant(name: "Fern", wateringIntervalDays: 1)
        let second = Plant(name: "Pilea", wateringIntervalDays: 1)
        first.lastWateredDate = Calendar.current.date(byAdding: .day, value: -2, to: now)
        second.lastWateredDate = Calendar.current.date(byAdding: .day, value: -2, to: now)
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let restore = prepareEconomyDefaults(
            memberKey: human.id.uuidString,
            careObjectKeys: [plantBudgetKey(first), plantBudgetKey(second)],
            date: now
        )
        defer { restore() }

        let questManager = QuestManager()
        let economy = StaticCareEventEconomyAwarder(questManager: questManager)
        let firstResult = PlantCareCommandService.recordCare(
            .watering,
            plant: first,
            executorId: human.id.uuidString,
            context: context,
            now: now,
            economy: economy,
            syncCarePlan: false
        )
        let secondResult = PlantCareCommandService.recordCare(
            .watering,
            plant: second,
            executorId: human.id.uuidString,
            context: context,
            now: now,
            economy: economy,
            syncCarePlan: false
        )

        #expect(firstResult.coconutDelta >= 2)
        #expect(secondResult.coconutDelta >= 2)
        #expect(human.coconutBalance == firstResult.coconutDelta + secondResult.coconutDelta)
    }

    @Test func plantWateringAndFertilizingUseLaunchRewardAmounts() {
        let now = makeDate(year: 2026, month: 6, day: 15, hour: 9)
        let household = "plant-policy-\(UUID().uuidString)"
        let member = "plant-member-\(UUID().uuidString)"
        let plantKey = "plant.\(UUID().uuidString)"

        let watering = CoconutEconomyPolicyV2.reward(
            for: .plantWatering,
            quality: .none,
            isOnCooldown: false,
            userKey: household,
            memberKey: member,
            careObjectKeys: [plantKey],
            careObjectCount: 1,
            hasHumanAccount: true,
            hasPetAccount: false,
            date: now,
            forcedLuck: EconomyLuckTier.none
        )
        let fertilizing = CoconutEconomyPolicyV2.reward(
            for: .plantFertilizing,
            quality: .none,
            isOnCooldown: false,
            userKey: household,
            memberKey: member,
            careObjectKeys: [plantKey],
            careObjectCount: 1,
            hasHumanAccount: true,
            hasPetAccount: false,
            date: now,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(watering.totalCoconuts == 2)
        #expect(watering.humanCoconuts == 2)
        #expect(watering.petCoconuts == 0)
        #expect(watering.growthXP == 5)
        #expect(fertilizing.totalCoconuts == 3)
        #expect(fertilizing.humanCoconuts == 3)
        #expect(fertilizing.petCoconuts == 0)
        #expect(fertilizing.growthXP == 8)
    }

    @Test func plantCareSharesMemberDailyBudgetWithPetCare() {
        let now = makeDate(year: 2026, month: 6, day: 16, hour: 9)
        let household = "shared-plant-pet-budget-\(UUID().uuidString)"
        let member = "shared-member-\(UUID().uuidString)"
        let petKeys = (0 ..< 10).map { "pet.\($0).\(UUID().uuidString)" }
        let plantKey = "plant.\(UUID().uuidString)"
        EconomyDailyBudgetStore.reset(householdKey: household, memberKey: member, careObjectKeys: petKeys + [plantKey], date: now)
        defer {
            EconomyDailyBudgetStore.reset(householdKey: household, memberKey: member, careObjectKeys: petKeys + [plantKey], date: now)
        }

        for index in 0 ..< 20 {
            let objectKey = petKeys[index % petKeys.count]
            let result = CoconutEconomyPolicyV2.reward(
                for: .health,
                quality: .none,
                isOnCooldown: false,
                userKey: household,
                memberKey: member,
                careObjectKeys: [objectKey],
                careObjectCount: petKeys.count + 1,
                hasHumanAccount: true,
                hasPetAccount: true,
                date: now,
                forcedLuck: EconomyLuckTier.none
            )
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: household,
                memberKey: member,
                careObjectKeys: [objectKey],
                date: now
            )
            if result.budgetStage == .recordOnly {
                break
            }
        }

        let plantResult = CoconutEconomyPolicyV2.reward(
            for: .plantWatering,
            quality: .none,
            isOnCooldown: false,
            userKey: household,
            memberKey: member,
            careObjectKeys: [plantKey],
            careObjectCount: petKeys.count + 1,
            hasHumanAccount: true,
            hasPetAccount: false,
            date: now,
            forcedLuck: EconomyLuckTier.none
        )

        #expect(plantResult.budgetStage == .recordOnly)
        #expect(plantResult.totalCoconuts == 0)
        #expect(plantResult.reason == "dailyBudgetRecordOnly")
    }

    @Test func plantCareRewardsFeedOasisCareEchoAndShopKeepsPlantsFree() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 20, hour: 9)
        let human = Human(name: "Ava")
        let plant = Plant(name: "Fern", wateringIntervalDays: 1)
        plant.lastWateredDate = Calendar.current.date(byAdding: .day, value: -2, to: now)
        let critter = OasisElectronicPet(
            catalogId: OasisUpgradeRewardCatalog.firstCritterId,
            nameZh: "nana",
            nameEn: "nana",
            nameDe: "nana",
            emoji: "🥥",
            rarity: .rare,
            health: 50,
            isFeaturedOnOasis: true,
            sourceLevel: 10
        )
        context.insert(human)
        context.insert(plant)
        context.insert(critter)
        try context.save()
        let restore = prepareEconomyDefaults(
            memberKey: human.id.uuidString,
            careObjectKeys: [plantBudgetKey(plant)],
            date: now
        )
        defer { restore() }

        PlantCareCommandService.recordCare(
            .watering,
            plant: plant,
            executorId: human.id.uuidString,
            context: context,
            now: now,
            economy: StaticCareEventEconomyAwarder(questManager: QuestManager()),
            syncCarePlan: false
        )
        let oasisLogs = try context.fetch(FetchDescriptor<OasisCritterActionLog>())
        let treeBoost = try #require(ShopCatalog.item(id: "boost_tree"))

        #expect(critter.health > 50)
        #expect(oasisLogs.contains { $0.action == .careEcho })
        #expect(treeBoost.descriptionText.resolve("zh").contains("基础植物照护不靠购买"))
        #expect(treeBoost.isConsumable)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV73.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: ArkMigrationPlan.self, configurations: [config])
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 9, minute: Int = 0) -> Date {
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

    private func plantBudgetKey(_ plant: Plant) -> String {
        "plant.\(plant.id.uuidString)"
    }

    private func prepareEconomyDefaults(
        memberKey: String,
        careObjectKeys: [String],
        date: Date
    ) -> () -> Void {
        let defaults = UserDefaults.standard
        let oldActiveHuman = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        defaults.set(memberKey, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
            memberKey: memberKey,
            careObjectKeys: careObjectKeys,
            date: date
        )
        return {
            if let oldActiveHuman {
                defaults.set(oldActiveHuman, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldCooldownLogs {
                defaults.set(oldCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
            EconomyDailyBudgetStore.reset(
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
                memberKey: memberKey,
                careObjectKeys: careObjectKeys,
                date: date
            )
        }
    }

    private struct NoopReminderNotificationScheduler: ReminderNotificationScheduling {
        func schedule(reminder _: Reminder) {}
        func schedule(
            reminder _: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.skippedUserDisabled(""))
        }

        func schedule(
            reminder _: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.skippedUserDisabled(""))
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId _: String) {}
        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    private final class PlantReminderNotificationSchedulerSpy: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var cancelledNotificationIDs: [String] = []

        func schedule(reminder _: Reminder) {}
        func schedule(
            reminder _: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.scheduled)
        }

        func schedule(
            reminder _: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.scheduled)
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId: String) { cancelledNotificationIDs.append(notificationId) }
        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    @MainActor
    private final class PlantCareEconomyAwarderSpy: CareEventEconomyAwarding {
        struct AwardCall {
            let type: DomainCareRewardAction
            let petID: UUID?
            let quality: DomainCareRewardQuality
            let date: Date
            let executorId: String?
            let careObjectKey: UUID?
        }

        let reward: (humanGot: Int, petGot: Int)
        private(set) var awardCalls: [AwardCall] = []

        init(reward: (humanGot: Int, petGot: Int)) {
            self.reward = reward
        }

        func awardCareAction(
            type: DomainCareRewardAction,
            pet: Pet?,
            context _: ModelContext,
            quality: DomainCareRewardQuality,
            date: Date,
            executorId: String?,
            careObjectKey: UUID?
        ) -> (humanGot: Int, petGot: Int) {
            awardCalls.append(AwardCall(
                type: type,
                petID: pet?.id,
                quality: quality,
                date: date,
                executorId: executorId,
                careObjectKey: careObjectKey
            ))
            return reward
        }

        func awardSharedCareAction(
            type _: DomainCareRewardAction,
            pets _: [Pet],
            context _: ModelContext,
            quality _: DomainCareRewardQuality,
            title _: String?,
            executorId _: String?
        ) -> (humanGot: Int, petGot: Int) {
            reward
        }

        func rewardMetadata(for reward: (humanGot: Int, petGot: Int)?) -> String {
            guard let reward else { return "" }
            return "{\"humanCoconuts\":\(max(0, reward.humanGot)),\"petCoconuts\":\(max(0, reward.petGot))}"
        }

        func recordFirstMeal(actorId _: String?, context _: ModelContext) {}
        func clearCooldown(petId _: UUID?, type _: DomainCareRewardAction) {}
        func refreshProjectionAfterRollback(context _: ModelContext) {}
    }
}
