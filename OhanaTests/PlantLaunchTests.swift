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

        PlantCreationCommandService.createPlant(input: input, context: container.mainContext)

        #expect(PlantUnlockPolicy.hasExistingPlantData())
        #expect(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
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
            now: now
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
            notifications: NoopReminderNotificationScheduler()
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
            now: now
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
}
