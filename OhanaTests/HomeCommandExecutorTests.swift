import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HomeCommandExecutorTests {
    @MainActor
    @Test func quickCareByIdWritesOneWaterFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []
        var openedWaterRoute = false

        executor.performActionType(
            "water",
            petID: pet.id,
            executorId: executorHuman.id.uuidString,
            now: Date(timeIntervalSince1970: 1_800_000_000),
            antiRepeatTitle: "Already logged",
            antiRepeatMessage: { "\($0.executorName) \($0.minutesAgo)" },
            openFeedDetail: { _, _ in },
            showAntiRepeat: { _, _, pendingAction in pendingAction() },
            startWalk: { _ in },
            openWaterManagement: { _ in openedWaterRoute = true },
            openMedication: { _ in },
            feedback: { feedbacks.append($0) }
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.careType == .watering)
        #expect(feedbacks.map(\.cardId) == [pet.id])
        #expect(openedWaterRoute == false)
    }

    @MainActor
    @Test func homeFeedQuickActionCompletesFreshPlanWhenCardSnapshotIsStale() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 17, hour: 9, minute: 0)
        let scheduledAt = makeDate(year: 2026, month: 6, day: 17, hour: 10, minute: 0)
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 45
        pet.mainFoodKind = .dry
        let executorHuman = insertExecutorHuman(in: context)
        let planEvent = Event(
            title: "Breakfast dry 45g",
            startDate: scheduledAt,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        planEvent.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        planEvent.feedAmountGrams = 45
        planEvent.foodKindRaw = FeedFoodKind.dry.rawValue
        let reminder = Reminder(event: planEvent, scheduledAt: scheduledAt)
        context.insert(pet)
        context.insert(planEvent)
        context.insert(reminder)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(executorHuman.id.uuidString, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()

        let medicationReminders = MedicationReminderManagerSpy()
        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)
        let executor = HomeCommandExecutor(
            modelContext: context,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: revisions,
            questManager: QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: revisions),
            medicationReminders: medicationReminders,
            todayFocus: StaticTodayFocusManager()
        )
        var openedFeedDetail: Bool?
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []

        let didRecord = executor.performActionType(
            "feed",
            petID: pet.id,
            executorId: executorHuman.id.uuidString,
            now: now,
            antiRepeatTitle: "Already logged",
            antiRepeatMessage: { "\($0.executorName) \($0.minutesAgo)" },
            openFeedDetail: { _, opensManualSheet in openedFeedDetail = opensManualSheet },
            showAntiRepeat: { _, _, pendingAction in pendingAction() },
            startWalk: { _ in },
            openWaterManagement: { _ in },
            openMedication: { _ in },
            feedback: { feedbacks.append($0) }
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(didRecord == true)
        #expect(openedFeedDetail == nil)
        #expect(reminder.isCompleted)
        #expect(logs.count == 1)
        #expect(logs.first?.note.hasPrefix(PetCareLog.plannedFeedNotePrefix) == true)
        #expect(feedbacks.map(\.cardId) == [pet.id])
        #expect(medicationReminders.scheduledPetIDs.isEmpty)
    }

    @Test func homeFeedQuickCommandDoesNotFetchLegacyCareLogsForRouting() throws {
        let rootURL = repositoryRootURL()
        let commandExecutor = try source("Ohana/Features/Home/HomeCommandExecutor.swift", rootURL: rootURL)
        let quickActionExecutor = try source("Ohana/Features/Home/ExpandedQuickActionExecutor.swift", rootURL: rootURL)
        let quickActionLogic = try source("Ohana/Features/Home/ExpandedQuickActionLogic.swift", rootURL: rootURL)

        #expect(!commandExecutor.contains("fetchRecentCareLogs"))
        #expect(!commandExecutor.contains("allFeedCareLogs"))
        #expect(!quickActionExecutor.contains("allFeedCareLogs"))
        #expect(!quickActionLogic.contains("allFeedCareLogs"))
        #expect(commandExecutor.contains("fetchFoodRecords"))
    }

    @MainActor
    @Test func plannedFeedForDeceasedPetNoopsWithoutHomeRevision() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let executorHuman = insertExecutorHuman(in: context)
        let scheduledAt = Date(timeIntervalSince1970: 1_800_000_000)
        let operationDate = scheduledAt.addingTimeInterval(3 * 24 * 60 * 60)
        let pet = Pet(name: "Momo", species: "猫")
        pet.passedAwayDate = scheduledAt.addingTimeInterval(60)
        pet.dailyPortionGrams = 50
        pet.mainFoodKind = .dry
        let event = Event(
            title: "Breakfast dry 50g",
            startDate: scheduledAt,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        event.feedAmountGrams = 50
        event.foodKindRaw = FeedFoodKind.dry.rawValue
        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let executor = HomeCommandExecutor(
            modelContext: context,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(
                wallet: SwiftDataCoconutWalletManager(),
                revisions: SharedDomainRevisionPublisher(center: revisionCenter)
            ),
            medicationReminders: MedicationReminderManagerSpy(),
            todayFocus: StaticTodayFocusManager()
        )
        let beforeRevision = revisionCenter.homeRevision.value

        let result = executor.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            allEvents: [event],
            foodRecords: [],
            executorId: executorHuman.id.uuidString,
            now: operationDate
        )
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(result.didRecord == false)
        #expect(!result.allowsDerivedEffects)
        #expect(logs.isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision)
        #expect(revisionCenter.lastMutation == nil)
    }

    @MainActor
    @Test func manualCareRewardUsesExecutorWalletInsteadOfActiveHuman() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Executor")
        let pet = Pet(name: "Momo", species: "猫")
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldCooldownLogs {
                defaults.set(oldCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
            memberKey: executor.id.uuidString,
            careObjectKeys: [pet.id.uuidString]
        )
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        try context.save()
        let dependencies = CareEventServiceDependencies.live()

        let result = CareEventService.recordManualFeedFact(
            pet: pet,
            amountGrams: 30,
            context: context,
            executorId: executor.id.uuidString,
            date: makeDate(year: 2026, month: 6, day: 13, hour: 8, minute: 30),
            dependencies: dependencies
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careRewardEntries = walletEntries.filter { $0.source == .careEvent && $0.ownerKind == .human && $0.delta > 0 }
        #expect(result.reward.humanGot > 0)
        #expect(executor.coconutBalance >= result.reward.humanGot)
        #expect(activeHuman.coconutBalance == 0)
        #expect(careRewardEntries.contains { $0.ownerId == executor.id.uuidString && $0.delta == result.reward.humanGot })
        #expect(!careRewardEntries.contains { $0.ownerId == activeHuman.id.uuidString })
    }

    @MainActor
    @Test func petMedicationDoseRewardUsesExecutorBudgetAndCooldownPipeline() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Executor")
        let pet = Pet(name: "Momo", species: "狗")
        let medication = PetMedication(
            name: "Apoquel",
            dosage: "1 tablet",
            frequency: .daily,
            remainingAmount: 2,
            pet: pet
        )
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        let oldAppLanguage = defaults.object(forKey: "appLanguage")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldCooldownLogs {
                defaults.set(oldCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
            if let oldAppLanguage {
                defaults.set(oldAppLanguage, forKey: "appLanguage")
            } else {
                defaults.removeObject(forKey: "appLanguage")
            }
            EconomyDailyBudgetStore.reset(
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: executor.id.uuidString,
                careObjectKeys: [pet.id.uuidString]
            )
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defaults.set("en", forKey: "appLanguage")
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            memberKey: executor.id.uuidString,
            careObjectKeys: [pet.id.uuidString]
        )
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        context.insert(medication)
        try context.save()
        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let medicationReminders = MedicationReminderManagerSpy()

        let first = PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: context,
            awardCoconut: true,
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            activeHumanSelection: FixedActiveHumanSelection(currentHumanId: executor.id.uuidString),
            medicationReminders: medicationReminders
        )
        let second = PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: context,
            awardCoconut: true,
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            activeHumanSelection: FixedActiveHumanSelection(currentHumanId: executor.id.uuidString),
            medicationReminders: medicationReminders
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        let medicationEvents = try context.fetch(FetchDescriptor<Event>()).filter {
            $0.eventType == EventType.petMedicationDose.rawValue
        }
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(first.assigneeId == executor.id.uuidString)
        #expect(second.assigneeId == executor.id.uuidString)
        #expect(first.title == "💊 Momo took Apoquel")
        #expect(medicationEvents.count == 2)
        #expect(medicationEvents.allSatisfy { $0.title == "💊 Momo took Apoquel" })
        #expect(ledgerEvents.count == 2)
        #expect(ledgerEvents.allSatisfy { $0.note == "💊 Momo took Apoquel" })
        #expect(executor.coconutBalance > 0)
        #expect(activeHuman.coconutBalance == 0)
        #expect(walletEntries.count(where: { $0.ownerId == executor.id.uuidString && $0.delta > 0 }) == 1)
        #expect(budgetEvents.contains {
            $0.memberKey == executor.id.uuidString && $0.actionKey.contains("Medication dose")
        })
        #expect(!budgetEvents.contains { $0.actionKey.contains("记录喂药") })
        #expect(medicationReminders.recordedMedicationIDs == [medication.id, medication.id])
    }

    @MainActor
    @Test func quickFeedByIdDoesNotDuplicateFoodStockReminderEvents() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0)
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        pet.dailyPortionGrams = 50
        pet.mainFoodKind = .dry
        pet.foodTrackingMode = .precise
        pet.foodReminderEnabled = true
        pet.foodReminderAdvanceDays = 2
        let foodRecord = PetFoodRecord(
            brand: "Test",
            dailyGrams: 50,
            totalGrams: 10000,
            foodKind: .dry,
            startDate: now,
            pet: pet
        )
        context.insert(pet)
        context.insert(foodRecord)
        try context.save()

        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)
        let executor = HomeCommandExecutor(
            modelContext: context,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: revisions,
            questManager: QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: revisions),
            medicationReminders: MedicationReminderManagerSpy(),
            todayFocus: StaticTodayFocusManager()
        )
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []
        let beforeRevision = revisionCenter.homeRevision.value

        func performQuickFeed(at date: Date) {
            executor.performActionType(
                "feed",
                petID: pet.id,
                executorId: executorHuman.id.uuidString,
                now: date,
                antiRepeatTitle: "Already logged",
                antiRepeatMessage: { "\($0.executorName) \($0.minutesAgo)" },
                openFeedDetail: { _, _ in },
                showAntiRepeat: { _, _, pendingAction in
                    pendingAction()
                },
                startWalk: { _ in },
                openWaterManagement: { _ in },
                openMedication: { _ in },
                feedback: { feedbacks.append($0) }
            )
        }

        performQuickFeed(at: now)
        #expect(stockReminderEvents(for: pet, context: context).count == 1)

        performQuickFeed(at: now.addingTimeInterval(60))

        let feedingLogs = try context.fetch(FetchDescriptor<PetCareLog>()).filter { $0.careType == .feeding }
        #expect(feedingLogs.count == 2)
        #expect(stockReminderEvents(for: pet, context: context).count == 1)
        #expect(feedbacks.map(\.cardId) == [pet.id, pet.id])
        #expect(revisionCenter.homeRevision.value == beforeRevision + 2)
    }

    @MainActor
    @Test func quickFeedByIdUsesLedgerForAntiRepeatWarning() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0)
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        pet.dailyPortionGrams = 50
        pet.mainFoodKind = .dry
        let previousFeed = CareLedgerEvent(
            occurredAt: now.addingTimeInterval(-300),
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction,
            legacyModelName: "PetCareLog",
            legacyModelId: UUID().uuidString
        )
        context.insert(pet)
        context.insert(human)
        context.insert(previousFeed)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)
        var antiRepeatAlerts: [(String, String)] = []
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []

        executor.performActionType(
            "feed",
            petID: pet.id,
            executorId: "human-2",
            now: now,
            antiRepeatTitle: "Already logged",
            antiRepeatMessage: { "\($0.executorName) \($0.minutesAgo)" },
            openFeedDetail: { _, _ in },
            showAntiRepeat: { title, message, _ in
                antiRepeatAlerts.append((title, message))
            },
            startWalk: { _ in },
            openWaterManagement: { _ in },
            openMedication: { _ in },
            feedback: { feedbacks.append($0) }
        )

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(careLogs.isEmpty)
        #expect(ledgerEvents.map(\.id) == [previousFeed.id])
        #expect(antiRepeatAlerts.map(\.0) == ["Already logged"])
        #expect(antiRepeatAlerts.map(\.1) == ["Guan 5"])
        #expect(feedbacks.isEmpty)
    }

    @MainActor
    @Test func quickGroomByIdWritesOneHygieneFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)
        var notices: [(String, String)] = []
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []

        executor.applyGroomCheckIn(
            raw: "bath",
            petID: pet.id,
            executorId: executorHuman.id.uuidString,
            showSingleUseNotice: { notices.append(($0, $1)) },
            feedback: { feedbacks.append($0) }
        )

        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let healthLogs = try context.fetch(FetchDescriptor<PetHealthLog>())
        #expect(hygieneLogs.count == 1)
        #expect(hygieneLogs.first?.pet?.id == pet.id)
        #expect(hygieneLogs.first?.hygieneType == .bath)
        #expect(careLogs.isEmpty)
        #expect(healthLogs.isEmpty)
        #expect(notices.isEmpty)
        #expect(feedbacks.map(\.cardId) == [pet.id])
    }

    @MainActor
    @Test func quickGroomByIdUsesLedgerForSingleUseGuard() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let todayLedger = CareLedgerEvent(
            occurredAt: Date(),
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: HygieneType.bath.rawValue,
            source: .quickAction,
            legacyModelName: "PetHygieneLog",
            legacyModelId: UUID().uuidString
        )
        context.insert(pet)
        context.insert(todayLedger)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)
        var notices: [(String, String)] = []
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []

        executor.applyGroomCheckIn(
            raw: "bath",
            petID: pet.id,
            executorId: "human-1",
            showSingleUseNotice: { notices.append(($0, $1)) },
            feedback: { feedbacks.append($0) }
        )

        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(hygieneLogs.isEmpty)
        #expect(ledgerEvents.map(\.id) == [todayLedger.id])
        #expect(notices.count == 1)
        #expect(feedbacks.isEmpty)
    }

    @MainActor
    @Test func quickHealthByIdWritesOneHealthFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)
        var openedHealthRoute = false
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []

        executor.applyHealthCheckIn(
            raw: "vaccine",
            petID: pet.id,
            executorId: executorHuman.id.uuidString,
            openHealth: { _ in openedHealthRoute = true },
            feedback: { feedbacks.append($0) }
        )

        let healthLogs = try context.fetch(FetchDescriptor<PetHealthLog>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        #expect(healthLogs.count == 1)
        #expect(healthLogs.first?.pet?.id == pet.id)
        #expect(healthLogs.first?.healthLogType == .vaccine)
        #expect(healthLogs.first?.note == L10n().tr(zh: "快捷打卡", en: "Quick check-in", de: "Schnell-Check-in"))
        #expect(careLogs.isEmpty)
        #expect(hygieneLogs.isEmpty)
        #expect(openedHealthRoute == false)
        #expect(feedbacks.map(\.cardId) == [pet.id])
    }

    @MainActor
    @Test func petCareTrackingCommandServiceRecordsManualFeedAmount() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 0
        questManager.coconutLogs = []

        let date = makeDate(year: 2026, month: 6, day: 8)
        let recorded = PetCareTrackingCommandService.recordCare(
            pet: pet,
            type: .feeding,
            amountGrams: 88,
            context: context,
            executorId: executorHuman.id.uuidString,
            date: date
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == recorded.result.careLogID)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.careType == .feeding)
        #expect(logs.first?.amountGrams == 88)
        #expect(logs.first?.note == PetCareLog.manualFeedNoteMarker)
        #expect(recorded.result.petID == pet.id)
        #expect(recorded.result.careType == .feeding)
        #expect(recorded.result.linkedPottyLogID == nil)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.legacyModelId == recorded.result.careLogID.uuidString)
        #expect(ledgerEvents.first?.source == CareLedgerSource.detail.rawValue)
    }

    @MainActor
    @Test func petCareTrackingCommandServiceRecordsPlayFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let date = makeDate(year: 2026, month: 6, day: 8, hour: 17, minute: 30)
        let recorded = PetCareTrackingCommandService.recordCare(
            pet: pet,
            type: .play,
            context: context,
            executorId: executorHuman.id.uuidString,
            date: date
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == recorded.result.careLogID)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.careType == .play)
        #expect(logs.first?.date == date)
        #expect(logs.first?.executorId == executorHuman.id.uuidString)
        #expect(recorded.result.petID == pet.id)
        #expect(recorded.result.careType == .play)
        #expect(recorded.result.linkedPottyLogID == nil)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.care.rawValue)
        #expect(ledgerEvents.first?.actionType == CareType.play.rawValue)
        #expect(ledgerEvents.first?.legacyModelId == recorded.result.careLogID.uuidString)
    }

    @MainActor
    @Test func quickPlayCommandExecutorWritesPlayFactAndPublishesRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 0
        questManager.coconutLogs = []

        let beforeRevision = revisionCenter.homeRevision.value
        let date = makeDate(year: 2026, month: 6, day: 8, hour: 18, minute: 0)
        let result = QuickPlayCommandExecutor(context: context, revisionCenter: revisionCenter).recordPlay(
            petID: pet.id,
            executorId: executorHuman.id.uuidString,
            rewardTitle: "Momo play reward",
            date: date
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result?.petID == pet.id)
        #expect(result?.logID == logs.first?.id)
        #expect(logs.count == 1)
        #expect(logs.first?.careType == .play)
        #expect(logs.first?.date == date)
        #expect(logs.first?.executorId == executorHuman.id.uuidString)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.actionType == CareType.play.rawValue)
        #expect(revisionCenter.homeRevision.value != beforeRevision)
        #expect(revisionCenter.lastMutation?.command == .quickCare(entityID: pet.id, action: CareType.play.rawValue))
    }

    @MainActor
    @Test func quickPlayCommandExecutorNoopsForDeceasedPetAtCommandBoundary() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        pet.passedAwayDate = makeDate(year: 2026, month: 6, day: 8, hour: 12, minute: 0)
        context.insert(pet)
        try context.save()

        let beforeRevision = revisionCenter.homeRevision.value
        let result = QuickPlayCommandExecutor(context: context, revisionCenter: revisionCenter).recordPlay(
            petID: pet.id,
            executorId: "human-1",
            rewardTitle: "Momo play reward",
            date: makeDate(year: 2026, month: 6, day: 8, hour: 18, minute: 0)
        )

        #expect(result == nil)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision)
        #expect(revisionCenter.lastMutation == nil)
    }

    @MainActor
    @Test func quickPlayCommandExecutorWritesForMissingExecutorThroughFallbackOwner() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let activeHuman = Human(name: "Active")
        context.insert(pet)
        context.insert(activeHuman)
        try context.save()
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldCooldownLogs {
                defaults.set(oldCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.resetAll()
        let missingExecutorID = UUID().uuidString

        let beforeRevision = revisionCenter.homeRevision.value
        let result = QuickPlayCommandExecutor(context: context, revisionCenter: revisionCenter).recordPlay(
            petID: pet.id,
            executorId: missingExecutorID,
            rewardTitle: "Momo play reward",
            date: makeDate(year: 2026, month: 6, day: 8, hour: 18, minute: 0)
        )
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)

        #expect(result?.petID == pet.id)
        #expect((result?.coconutDelta ?? 0) > 0)
        #expect(careLog.executorId == activeHuman.id.uuidString)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != missingExecutorID })
        #expect(revisionCenter.homeRevision.value != beforeRevision)
        #expect(revisionCenter.lastMutation != nil)
    }

    @MainActor
    @Test func quickPlayCommandExecutorWritesForPassedAwayExecutorThroughFallbackOwner() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = Human(name: "Memorial caretaker")
        executorHuman.passedAwayDate = makeDate(year: 2026, month: 6, day: 8, hour: 12, minute: 0)
        context.insert(activeHuman)
        context.insert(pet)
        context.insert(executorHuman)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()
        let beforeRevision = revisionCenter.homeRevision.value
        let result = QuickPlayCommandExecutor(context: context, revisionCenter: revisionCenter).recordPlay(
            petID: pet.id,
            executorId: executorHuman.id.uuidString,
            rewardTitle: "Momo play reward",
            date: makeDate(year: 2026, month: 6, day: 8, hour: 18, minute: 0)
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(result?.petID == pet.id)
        #expect(careLog.executorId == activeHuman.id.uuidString)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != executorHuman.id.uuidString })
        #expect(revisionCenter.homeRevision.value != beforeRevision)
        #expect(revisionCenter.lastMutation != nil)
    }

    @MainActor
    @Test func homeQuickCareWritesForDeceasedExecutorThroughFallbackOwner() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = Human(name: "Former caretaker")
        executorHuman.passedAwayDate = makeDate(year: 2026, month: 6, day: 8, hour: 12, minute: 0)
        context.insert(activeHuman)
        context.insert(pet)
        context.insert(executorHuman)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()
        let executor = HomeCommandExecutor(
            modelContext: context,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(),
            medicationReminders: SharedMedicationReminderManager(),
            todayFocus: StaticTodayFocusManager()
        )
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []
        let beforeRevision = revisionCenter.homeRevision.value

        executor.performActionType(
            "play",
            petID: pet.id,
            executorId: executorHuman.id.uuidString,
            now: makeDate(year: 2026, month: 6, day: 8, hour: 18, minute: 0),
            antiRepeatTitle: "Already logged",
            antiRepeatMessage: { "\($0.executorName) \($0.minutesAgo)" },
            openFeedDetail: { _, _ in },
            showAntiRepeat: { _, _, pendingAction in pendingAction() },
            startWalk: { _ in },
            openWaterManagement: { _ in },
            openMedication: { _ in },
            feedback: { feedbacks.append($0) }
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(!feedbacks.isEmpty)
        #expect(careLog.executorId == activeHuman.id.uuidString)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != executorHuman.id.uuidString })
        #expect(revisionCenter.homeRevision.value != beforeRevision)
        #expect(revisionCenter.lastMutation != nil)
    }

    @MainActor
    @Test func quickPottyCommandExecutorWritesPottyFactAndPublishesRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 0
        questManager.coconutLogs = []

        let beforeRevision = revisionCenter.homeRevision.value
        let date = makeDate(year: 2026, month: 6, day: 8, hour: 19, minute: 10)
        let result = QuickPottyCommandExecutor(context: context, revisionCenter: revisionCenter).record(
            petID: pet.id,
            selectedType: .softPoop,
            isLitter: false,
            executorId: executorHuman.id.uuidString,
            date: date
        )

        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result?.petID == pet.id)
        #expect(result?.pottyLogID == pottyLogs.first?.id)
        #expect(result?.careLogID == nil)
        #expect(pottyLogs.count == 1)
        #expect(pottyLogs.first?.pottyType == .softPoop)
        #expect(pottyLogs.first?.executorId == executorHuman.id.uuidString)
        #expect(careLogs.isEmpty)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.actionType == PottyType.softPoop.rawValue)
        #expect(revisionCenter.homeRevision.value != beforeRevision)
        #expect(revisionCenter.lastMutation?.command == .quickCare(entityID: pet.id, action: PottyType.softPoop.rawValue))
    }

    @MainActor
    @Test func quickPottyCommandExecutorNoopsForDeceasedPetAtCommandBoundary() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        pet.passedAwayDate = makeDate(year: 2026, month: 6, day: 8, hour: 12, minute: 0)
        context.insert(pet)
        try context.save()

        let beforeRevision = revisionCenter.homeRevision.value
        let result = QuickPottyCommandExecutor(context: context, revisionCenter: revisionCenter).record(
            petID: pet.id,
            selectedType: .softPoop,
            isLitter: false,
            executorId: "human-1",
            date: makeDate(year: 2026, month: 6, day: 8, hour: 19, minute: 0)
        )

        #expect(result == nil)
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision)
        #expect(revisionCenter.lastMutation == nil)
    }

    @MainActor
    @Test func quickPottyCommandExecutorWritesForDeceasedExecutorThroughFallbackOwner() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = Human(name: "Former caretaker")
        executorHuman.passedAwayDate = makeDate(year: 2026, month: 6, day: 8, hour: 12, minute: 0)
        context.insert(activeHuman)
        context.insert(pet)
        context.insert(executorHuman)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()
        let beforeRevision = revisionCenter.homeRevision.value
        let result = QuickPottyCommandExecutor(context: context, revisionCenter: revisionCenter).record(
            petID: pet.id,
            selectedType: .softPoop,
            isLitter: false,
            executorId: executorHuman.id.uuidString,
            date: makeDate(year: 2026, month: 6, day: 8, hour: 19, minute: 0)
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let pottyLog = try #require(try context.fetch(FetchDescriptor<PetPottyLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(result?.petID == pet.id)
        #expect(pottyLog.executorId == activeHuman.id.uuidString)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != executorHuman.id.uuidString })
        #expect(revisionCenter.homeRevision.value != beforeRevision)
        #expect(revisionCenter.lastMutation != nil)
    }

    @MainActor
    @Test func quickPottyCommandExecutorFindsTargetLogWhenOtherPetsHaveNewerPottyLogs() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let otherPet = Pet(name: "Nori", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        context.insert(otherPet)
        let date = makeDate(year: 2026, month: 6, day: 8, hour: 19, minute: 10)
        for offset in 1 ... 13 {
            context.insert(PetPottyLog(
                date: date.addingTimeInterval(TimeInterval(offset * 60)),
                type: .softPoop,
                pet: otherPet,
                executorId: "noise-\(offset)"
            ))
        }
        try context.save()

        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 0
        questManager.coconutLogs = []

        let result = QuickPottyCommandExecutor(context: context, revisionCenter: revisionCenter).record(
            petID: pet.id,
            selectedType: .softPoop,
            isLitter: false,
            executorId: executorHuman.id.uuidString,
            date: date
        )

        let allPottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let targetLog = try #require(allPottyLogs.first { $0.pet?.id == pet.id })
        #expect(allPottyLogs.count == 14)
        #expect(result?.pottyLogID == targetLog.id)
        #expect(result?.careLogID == nil)
        #expect(revisionCenter.lastMutation?.affectedEntityIDs.contains(targetLog.id) == true)
    }

    @MainActor
    @Test func quickPottyCommandExecutorWritesLitterCareFactAndPublishesRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 0
        questManager.coconutLogs = []

        let beforeRevision = revisionCenter.homeRevision.value
        let date = makeDate(year: 2026, month: 6, day: 8, hour: 20, minute: 15)
        let result = QuickPottyCommandExecutor(context: context, revisionCenter: revisionCenter).record(
            petID: pet.id,
            selectedType: .perfectPoop,
            isLitter: true,
            executorId: executorHuman.id.uuidString,
            date: date
        )

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result?.petID == pet.id)
        #expect(result?.careLogID == careLogs.first?.id)
        #expect(result?.pottyLogID == nil)
        #expect(careLogs.count == 1)
        #expect(careLogs.first?.careType == .litter)
        #expect(careLogs.first?.executorId == executorHuman.id.uuidString)
        #expect(pottyLogs.isEmpty)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.actionType == CareType.litter.rawValue)
        #expect(revisionCenter.homeRevision.value != beforeRevision)
        #expect(revisionCenter.lastMutation?.command == .quickCare(entityID: pet.id, action: CareType.litter.rawValue))
    }

    @MainActor
    @Test func quickPottyUnknownSharedFlowCanBeClaimedAndRefreshesSessionAndLedger() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(first)
        context.insert(second)
        try context.save()

        let beforeRevision = revisionCenter.homeRevision.value
        let date = makeDate(year: 2026, month: 6, day: 8, hour: 21, minute: 20)
        let result = QuickPottyCommandExecutor(context: context, revisionCenter: revisionCenter).recordUnknownSharedPotty(
            sourcePetID: first.id,
            targetIDs: [first.id, second.id],
            type: .softPoop,
            executorId: executorHuman.id.uuidString,
            date: date
        )

        var sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        var pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        var ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let session = try #require(sessions.first)
        let unknownLog = try #require(pottyLogs.first)
        let ledgerEvent = try #require(ledgerEvents.first)
        let claimEntries = QuickPottyUnknownClaimStore.entries(for: second.id, context: context)
        let claimEntry = try #require(claimEntries.first)

        #expect(result?.petID == first.id)
        #expect(result?.pottyLogID == unknownLog.id)
        #expect(result?.careLogID == nil)
        #expect(result?.action == "unknownSharedPotty")
        #expect(result?.targetCount == 2)
        #expect(sessions.count == 1)
        #expect(session.actionKind == .pottyUnknown)
        #expect(Set(session.targetPetIds) == [first.id.uuidString, second.id.uuidString])
        #expect(pottyLogs.count == 1)
        #expect(unknownLog.pet == nil)
        #expect(unknownLog.sharedSessionId == session.id.uuidString)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvent.subjectKind == CareLedgerSubjectKind.unknown.rawValue)
        #expect(ledgerEvent.subjectId == nil)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(revisionCenter.lastMutation?.command == .quickCare(entityID: first.id, action: "unknownSharedPotty"))

        #expect(claimEntry.id == unknownLog.id)
        #expect(claimEntry.targetCount == 2)

        let claimResult = PetCareCommandExecutor(context: context, revisionCenter: revisionCenter).claimUnknownPottyLog(
            unknownLog,
            pet: second,
            note: "test.potty.claim"
        )

        sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let claimedSession = try #require(sessions.first)
        let claimedLog = try #require(pottyLogs.first)
        let claimedLedgerEvent = try #require(ledgerEvents.first)
        #expect(claimResult.petID == second.id)
        #expect(claimResult.logID == unknownLog.id)
        #expect(claimResult.sharedSessionID == session.id.uuidString)
        #expect(claimResult.updatedLedgerEventIDs == [claimedLedgerEvent.id])
        #expect(claimedLog.pet?.id == second.id)
        #expect(claimedSession.sourcePetId == second.id.uuidString)
        #expect(claimedSession.speciesRaw == second.species)
        #expect(claimedSession.targetPetIds == [second.id.uuidString])
        #expect(claimedLedgerEvent.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(claimedLedgerEvent.subjectId == second.id.uuidString)
        #expect(QuickPottyUnknownClaimStore.entries(for: first.id, context: context).isEmpty)
        #expect(QuickPottyUnknownClaimStore.entries(for: second.id, context: context).isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 2)
        #expect(revisionCenter.lastMutation?.command == .quickCare(entityID: second.id, action: "claimUnknownPotty"))
        #expect(revisionCenter.lastMutation?.note == "test.potty.claim")
    }

    @MainActor
    @Test func petCareTrackingCommandServiceRecordsAndDeletesLitterFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 0
        questManager.coconutLogs = []

        let date = makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 30)
        let recorded = PetCareTrackingCommandService.recordCare(
            pet: pet,
            type: .litter,
            context: context,
            executorId: executorHuman.id.uuidString,
            date: date
        )

        var careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        var pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        var ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(careLogs.count == 1)
        #expect(pottyLogs.count == 1)
        #expect(recorded.result.careLogID == careLogs.first?.id)
        #expect(recorded.result.linkedPottyLogID == pottyLogs.first?.id)
        #expect(ledgerEvents.count == 2)
        #expect(ledgerEvents.contains { $0.legacyModelName == "PetCareLog" && $0.legacyModelId == recorded.result.careLogID.uuidString })
        #expect(ledgerEvents.contains { $0.legacyModelName == "PetPottyLog" && $0.legacyModelId == recorded.result.linkedPottyLogID?.uuidString })
        let unrelatedCareLedger = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.litter.rawValue,
            legacyModelName: "PetCareLog",
            legacyModelId: "unrelated-care-log"
        )
        let unrelatedPottyLedger = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: PottyType.perfectPoop.rawValue,
            legacyModelName: "PetPottyLog",
            legacyModelId: "unrelated-potty-log"
        )
        context.insert(unrelatedCareLedger)
        context.insert(unrelatedPottyLedger)
        try context.save()

        let deleteResult = try PetCareTrackingCommandService.deleteCareLog(
            #require(careLogs.first),
            pet: pet,
            context: context
        )

        careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(deleteResult.careLogID == recorded.result.careLogID)
        #expect(deleteResult.linkedPottyLogID == recorded.result.linkedPottyLogID)
        #expect(deleteResult.removedLedgerEventIDs.count == 2)
        #expect(deleteResult.didDelete)
        #expect(careLogs.isEmpty)
        #expect(pottyLogs.isEmpty)
        let remainingLedgerIDs = Set(ledgerEvents.map(\.id))
        let unrelatedLedgerIDs: Set<UUID> = [unrelatedCareLedger.id, unrelatedPottyLedger.id]
        #expect(remainingLedgerIDs == unrelatedLedgerIDs)
    }

    @MainActor
    @Test func petPottyCommandServiceDeletesPottyFactAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let log = PetPottyLog(
            date: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 30),
            type: .perfectPoop,
            pet: pet,
            executorId: "human-1"
        )
        context.insert(pet)
        context.insert(log)
        CareLedgerService.recordPetPotty(log: log, pet: pet, source: .service, context: context)
        try context.save()

        var pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        var ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(pottyLogs.map(\.id) == [log.id])
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.legacyModelName == "PetPottyLog")
        #expect(ledgerEvents.first?.legacyModelId == log.id.uuidString)
        let unrelatedLedger = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: PottyType.softPoop.rawValue,
            legacyModelName: "PetPottyLog",
            legacyModelId: "unrelated-potty-log"
        )
        context.insert(unrelatedLedger)
        try context.save()

        let result = PetPottyCommandService.deletePottyLog(log, pet: pet, context: context)

        pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result.petID == pet.id)
        #expect(result.logID == log.id)
        #expect(result.removedLedgerEventIDs.count == 1)
        #expect(result.didDelete)
        #expect(pottyLogs.isEmpty)
        #expect(ledgerEvents.map(\.id) == [unrelatedLedger.id])
    }

    @MainActor
    @Test func petCareAndPottyDeleteNoopWhenPetDoesNotOwnLog() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let owner = Pet(name: "Momo", species: "狗")
        let other = Pet(name: "Nori", species: "狗")
        let careLog = PetCareLog(
            date: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0),
            type: .play,
            pet: owner,
            executorId: "human-1"
        )
        let pottyLog = PetPottyLog(
            date: makeDate(year: 2026, month: 6, day: 8, hour: 10, minute: 0),
            type: .perfectPoop,
            pet: owner,
            executorId: "human-1"
        )
        context.insert(owner)
        context.insert(other)
        context.insert(careLog)
        context.insert(pottyLog)
        CareLedgerService.recordPetCare(log: careLog, pet: owner, source: .service, context: context)
        CareLedgerService.recordPetPotty(log: pottyLog, pet: owner, source: .service, context: context)
        try context.save()

        let wrongCareDelete = PetCareTrackingCommandService.deleteCareLog(careLog, pet: other, context: context)
        let wrongPottyDelete = PetPottyCommandService.deletePottyLog(pottyLog, pet: other, context: context)

        #expect(wrongCareDelete.didDelete == false)
        #expect(wrongCareDelete.removedLedgerEventIDs.isEmpty)
        #expect(wrongPottyDelete.didDelete == false)
        #expect(wrongPottyDelete.removedLedgerEventIDs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).map(\.id) == [careLog.id])
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).map(\.id) == [pottyLog.id])
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<CloudSyncRecordState>()).allSatisfy { !$0.isDeletionTombstone })
    }

    @MainActor
    @Test func petCareCommandExecutorDeletesUnclaimedSharedPottyLog() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let first = Pet(name: "Momo", species: "猫")
        let second = Pet(name: "Nori", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        let session = SharedCareSession(
            date: makeDate(year: 2026, month: 6, day: 8, hour: 11, minute: 0),
            actionKind: .pottyUnknown,
            sourcePetId: first.id.uuidString,
            targetPetIds: [first.id.uuidString, second.id.uuidString],
            species: first.species
        )
        let log = PetPottyLog(
            date: session.date,
            type: .perfectPoop,
            pet: nil,
            executorId: executorHuman.id.uuidString,
            sharedSessionId: session.id.uuidString
        )
        context.insert(first)
        context.insert(second)
        context.insert(session)
        context.insert(log)
        let ledger = CareLedgerService.record(
            occurredAt: log.date,
            actorKind: .human,
            actorId: executorHuman.id.uuidString,
            subjectKind: .unknown,
            subjectId: nil,
            eventKind: .potty,
            actionType: PottyType.perfectPoop.rawValue,
            source: .service,
            legacyModelName: String(describing: PetPottyLog.self),
            legacyModelId: log.id.uuidString,
            context: context
        )
        try context.save()

        let executor = PetCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let result = executor.deletePottyLog(log, pet: first, note: "test.pet.potty.delete.unclaimed")

        #expect(result.didDelete)
        #expect(result.logID == log.id)
        #expect(result.removedLedgerEventIDs.count == 1)
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        let syncStates = try context.fetch(FetchDescriptor<CloudSyncRecordState>())
        let pottyKey = CloudSyncRecordState.recordKey(entityName: String(describing: PetPottyLog.self), localRecordId: log.id)
        let ledgerKey = CloudSyncRecordState.recordKey(entityName: String(describing: CareLedgerEvent.self), localRecordId: ledger.id)
        #expect(syncStates.contains { $0.recordKey == pottyKey && $0.isDeletionTombstone })
        #expect(syncStates.contains { $0.recordKey == ledgerKey && $0.isDeletionTombstone })
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(revisionCenter.lastMutation?.command == .petPottyDelete(petID: first.id, logID: log.id))
    }

    @MainActor
    @Test func petCareCommandExecutorPublishesCareAndPottyRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let executor = PetCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let recorded = executor.recordCare(
            pet: pet,
            type: .litter,
            executorId: executorHuman.id.uuidString,
            date: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 30),
            note: "test.pet.care.record"
        )
        var mutation = try #require(revisionCenter.lastMutation)
        let linkedPottyID = try #require(recorded.result.linkedPottyLogID)
        #expect(mutation.command == .petCareRecord(petID: pet.id, type: CareType.litter.rawValue))
        #expect(mutation.affectedEntityIDs == [pet.id, recorded.result.careLogID, linkedPottyID])
        #expect(mutation.note == "test.pet.care.record")

        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let deletedCare = executor.deleteCareLog(
            careLog,
            pet: pet,
            note: "test.pet.care.delete"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(deletedCare.careLogID == recorded.result.careLogID)
        #expect(deletedCare.didDelete)
        #expect(mutation.command == .petCareDelete(petID: pet.id, logID: recorded.result.careLogID))
        #expect(mutation.affectedEntityIDs.contains(linkedPottyID))
        #expect(mutation.note == "test.pet.care.delete")

        let potty = PetPottyLog(
            date: makeDate(year: 2026, month: 6, day: 8, hour: 10, minute: 0),
            type: .perfectPoop,
            pet: pet,
            executorId: executorHuman.id.uuidString
        )
        context.insert(potty)
        CareLedgerService.recordPetPotty(log: potty, pet: pet, source: .service, context: context)
        try context.save()

        let deletedPotty = executor.deletePottyLog(
            potty,
            pet: pet,
            note: "test.pet.potty.delete"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(deletedPotty.logID == potty.id)
        #expect(deletedPotty.didDelete)
        #expect(mutation.command == .petPottyDelete(petID: pet.id, logID: potty.id))
        #expect(mutation.note == "test.pet.potty.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func petCareCommandExecutorDoesNotPublishDeleteRevisionForWrongPet() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let owner = Pet(name: "Momo", species: "狗")
        let other = Pet(name: "Nori", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(owner)
        context.insert(other)
        try context.save()

        let executor = PetCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let recorded = executor.recordCare(
            pet: owner,
            type: .play,
            executorId: executorHuman.id.uuidString,
            date: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0),
            note: "test.pet.care.record"
        )
        let recordMutation = try #require(revisionCenter.lastMutation)
        let beforeDeleteRevision = revisionCenter.homeRevision.value
        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)

        let delete = executor.deleteCareLog(careLog, pet: other, note: "test.pet.care.delete.wrongPet")

        #expect(delete.didDelete == false)
        #expect(delete.careLogID == recorded.result.careLogID)
        #expect(revisionCenter.lastMutation == recordMutation)
        #expect(revisionCenter.homeRevision.value == beforeDeleteRevision)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).map(\.id) == [careLog.id])
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)

        let pottyLog = PetPottyLog(
            date: makeDate(year: 2026, month: 6, day: 8, hour: 10, minute: 0),
            type: .perfectPoop,
            pet: owner,
            executorId: executorHuman.id.uuidString
        )
        context.insert(pottyLog)
        CareLedgerService.recordPetPotty(log: pottyLog, pet: owner, source: .service, context: context)
        try context.save()
        let beforePottyDeleteRevision = revisionCenter.homeRevision.value

        let pottyDelete = executor.deletePottyLog(
            pottyLog,
            pet: other,
            note: "test.pet.potty.delete.wrongPet"
        )

        #expect(pottyDelete.didDelete == false)
        #expect(revisionCenter.lastMutation == recordMutation)
        #expect(revisionCenter.homeRevision.value == beforePottyDeleteRevision)
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).map(\.id) == [pottyLog.id])
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 2)
    }

    @MainActor
    @Test func petHealthCommandServiceWritesHealthFactAndDerivedRecords() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let date = makeDate(year: 2026, month: 6, day: 8)
        let expirationDate = makeDate(year: 2027, month: 6, day: 8)
        let result = try #require(PetHealthCommandService.recordHealth(
            pet: pet,
            input: PetHealthRecordCommandInput(
                type: .vaccine,
                date: date,
                name: " Rabies ",
                note: " clinic A ",
                vetName: " Dr. Lee ",
                cost: 48.5,
                expirationDate: expirationDate,
                nextCheckupDate: nil,
                executorId: executorHuman.id.uuidString,
                source: .detail,
                includesNameInNote: true
            ),
            context: context,
            awardsReward: false,
            questManager: makeQuestManager()
        ))

        let healthLogs = try context.fetch(FetchDescriptor<PetHealthLog>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(healthLogs.count == 1)
        #expect(healthLogs.first?.id == result.logID)
        #expect(healthLogs.first?.pet?.id == pet.id)
        #expect(healthLogs.first?.healthLogType == .vaccine)
        #expect(healthLogs.first?.note == "Rabies - clinic A")
        #expect(healthLogs.first?.vetName == "Dr. Lee")
        #expect(healthLogs.first?.cost == 48.5)
        #expect(healthLogs.first?.expirationDate == expirationDate)
        #expect(expenses.count == 1)
        #expect(expenses.first?.id == result.expenseLogID)
        #expect(expenses.first?.pet?.id == pet.id)
        #expect(expenses.first?.amount == 48.5)
        #expect(expenses.first?.category == ExpenseCategory.medical.rawValue)
        #expect(expenses.first?.note == "Rabies")
        #expect(events.count == 1)
        #expect(events.first?.id == result.eventID)
        #expect(events.first?.eventType == EventType.vaccine.rawValue)
        #expect(events.first?.relatedEntityType == EntityKind.pet.rawValue)
        #expect(events.first?.relatedEntityId == pet.id.uuidString)
        #expect(events.first?.startDate == expirationDate)
        #expect(ledgerEvents.count == 2)
        #expect(ledgerEvents.contains { $0.eventKind == CareLedgerEventKind.health.rawValue && $0.legacyModelId == result.logID.uuidString })
        #expect(ledgerEvents.contains { $0.eventKind == CareLedgerEventKind.expense.rawValue && $0.legacyModelId == result.expenseLogID?.uuidString })
        #expect(result.subjectID == pet.id)
        #expect(result.coconutDelta == 0)
    }

    @MainActor
    @Test func petHealthCommandServiceWritesVaccineExpiryReminder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let date = makeDate(year: 2026, month: 6, day: 8)
        let expirationDate = makeDate(year: 2027, month: 6, day: 8)
        let reminderDate = makeDate(year: 2027, month: 5, day: 25)
        let result = try #require(PetHealthCommandService.recordHealth(
            pet: pet,
            input: PetHealthRecordCommandInput(
                type: .vaccine,
                date: date,
                name: "Rabies",
                note: "",
                vetName: "",
                cost: 20,
                expirationDate: expirationDate,
                nextCheckupDate: nil,
                executorId: nil,
                source: .detail,
                includesNameInNote: true,
                expirationReminderLeadDays: 14
            ),
            context: context,
            awardsReward: false,
            schedulesReminderNotification: false,
            questManager: makeQuestManager()
        ))

        let logs = try context.fetch(FetchDescriptor<PetHealthLog>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.note == "Rabies")
        #expect(expenses.count == 1)
        #expect(expenses.first?.id == result.expenseLogID)
        #expect(expenses.first?.note == "Rabies")
        #expect(events.count == 1)
        #expect(events.first?.id == result.eventID)
        #expect(events.first?.startDate == expirationDate)
        #expect(events.first?.eventType == EventType.vaccine.rawValue)
        #expect(reminders.count == 1)
        #expect(reminders.first?.id == result.reminderID)
        #expect(reminders.first?.scheduledAt == reminderDate)
        #expect(reminders.first?.event?.id == result.eventID)
        #expect(reminders.first?.isPending == true)
        #expect(ledgerEvents.count == 2)
    }

    @MainActor
    @Test func insuranceClaimServiceCreatesApprovedClaimAndReimbursement() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        let insurance = PetInsurance(
            companyName: "Ohana Care",
            productName: "Care Plus",
            annualPremium: 120,
            coverageAmount: 1000,
            pet: pet
        )
        context.insert(pet)
        context.insert(insurance)
        try context.save()

        let claimDate = makeDate(year: 2026, month: 6, day: 8)
        let incidentDate = makeDate(year: 2026, month: 6, day: 7)
        let relatedExpenseLogId = UUID().uuidString
        let result = InsurancePolicyCommandService.createClaim(
            insurance: insurance,
            pet: pet,
            input: InsuranceClaimCommandInput(
                claimDate: claimDate,
                incidentDate: incidentDate,
                totalExpense: 240,
                claimedAmount: 120,
                status: .approved,
                note: "  clinic  ",
                executorId: executorHuman.id.uuidString,
                relatedExpenseLogId: relatedExpenseLogId,
                approvedAt: claimDate
            ),
            context: context
        )

        let claims = try context.fetch(FetchDescriptor<InsuranceClaim>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let claim = try #require(claims.first)
        let expense = try #require(expenses.first)
        #expect(claims.count == 1)
        #expect(claim.id == result.claimID)
        #expect(claim.insurance?.id == insurance.id)
        #expect(claim.incidentDate == incidentDate)
        #expect(claim.totalExpense == 240)
        #expect(claim.claimedAmount == 120)
        #expect(claim.approvedAmount == 120)
        #expect(claim.claimStatus == .approved)
        #expect(claim.note == "clinic")
        #expect(claim.approvedAt == claimDate)
        #expect(claim.relatedExpenseLogId == relatedExpenseLogId)
        #expect(expenses.count == 1)
        #expect(expense.id == result.expenseLogID)
        #expect(expense.pet?.id == pet.id)
        #expect(expense.amount == -120)
        #expect(expense.expenseCategory == .insurancePremium)
        #expect(expense.note == "保险报销到账：Care Plus")
        #expect(expense.executorId == executorHuman.id.uuidString)
        #expect(result.policyID == insurance.id)
        #expect(result.petID == pet.id)
        #expect(result.didChange == true)
    }

    @MainActor
    @Test func insuranceClaimServiceApprovesSubmittedClaimOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        let insurance = PetInsurance(
            companyName: "Ohana Care",
            productName: "",
            pet: pet
        )
        let claim = InsuranceClaim(
            incidentDate: makeDate(year: 2026, month: 6, day: 7),
            totalExpense: 200,
            claimedAmount: 80,
            status: .submitted,
            insurance: insurance
        )
        context.insert(pet)
        context.insert(insurance)
        context.insert(claim)
        try context.save()

        let approvedAt = makeDate(year: 2026, month: 6, day: 9)
        let first = InsurancePolicyCommandService.updateClaimStatus(
            claim,
            to: .approved,
            insurance: insurance,
            pet: pet,
            context: context,
            approvedAt: approvedAt,
            executorId: executorHuman.id.uuidString
        )
        let second = InsurancePolicyCommandService.updateClaimStatus(
            claim,
            to: .approved,
            insurance: insurance,
            pet: pet,
            context: context,
            approvedAt: approvedAt,
            executorId: executorHuman.id.uuidString
        )

        let claims = try context.fetch(FetchDescriptor<InsuranceClaim>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let expense = try #require(expenses.first)
        #expect(claims.count == 1)
        #expect(claims.first?.claimStatus == .approved)
        #expect(claims.first?.approvedAmount == 80)
        #expect(claims.first?.approvedAt == approvedAt)
        #expect(expenses.count == 1)
        #expect(expense.amount == -80)
        #expect(expense.note == "保险报销到账：Ohana Care")
        #expect(expense.executorId == executorHuman.id.uuidString)
        #expect(first.expenseLogID == expense.id)
        #expect(first.didChange == true)
        #expect(second.expenseLogID == nil)
        #expect(second.didChange == false)
    }

    @MainActor
    @Test func insurancePolicyServiceTogglesAndDeletesClaimAndPolicy() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let insurance = PetInsurance(companyName: "Ohana Care", pet: pet)
        let claim = InsuranceClaim(totalExpense: 120, claimedAmount: 60, status: .processing, insurance: insurance)
        context.insert(pet)
        context.insert(insurance)
        context.insert(claim)
        try context.save()

        let policyID = insurance.id
        let claimID = claim.id
        let petID = pet.id
        let inactive = InsurancePolicyCommandService.setPolicyActive(
            insurance,
            isActive: false,
            pet: pet,
            context: context
        )
        let deletedClaim = InsurancePolicyCommandService.deleteClaim(
            claim,
            insurance: insurance,
            pet: pet,
            context: context
        )
        let deletedPolicy = InsurancePolicyCommandService.deletePolicy(
            insurance,
            pet: pet,
            context: context
        )

        #expect(inactive.didChange == true)
        #expect(inactive.policyID == policyID)
        #expect(inactive.petID == petID)
        #expect(deletedClaim.claimID == claimID)
        #expect(deletedClaim.didChange == true)
        #expect(deletedPolicy.policyID == policyID)
        #expect(deletedPolicy.petID == petID)
        #expect(try (context.fetch(FetchDescriptor<InsuranceClaim>())).isEmpty)
        let policies = try context.fetch(FetchDescriptor<PetInsurance>())
        #expect(policies.isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: InsuranceClaim.self), id: claimID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: PetInsurance.self), id: policyID, context: context)?.isDeletionTombstone == true)
    }

    @MainActor
    @Test func insurancePolicyServiceCreatesPolicyPaymentScheduleAndCalendarEvents() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let result = InsurancePolicyCommandService.savePolicy(
            existing: nil,
            pet: pet,
            input: InsurancePolicySaveCommandInput(
                companyName: " Ohana Care ",
                policyNumber: " P-1 ",
                productName: " Care Plus ",
                annualPremium: 120,
                coverageAmount: 1000,
                startDate: makeDate(year: 2026, month: 6, day: 8),
                renewalDate: makeDate(year: 2026, month: 12, day: 8),
                notes: " Full cover ",
                paymentFrequency: .once,
                paymentDayOfMonth: 1,
                showInCalendar: true,
                otherFeeAmount: 10,
                otherFeeNote: "Service fee",
                autoGeneratesPayments: true,
                executorId: executorHuman.id.uuidString
            ),
            context: context
        )

        let policies = try context.fetch(FetchDescriptor<PetInsurance>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let policy = try #require(policies.first)
        let expense = try #require(expenses.first)
        let event = try #require(events.first)
        #expect(result.petID == pet.id)
        #expect(result.policyID == policy.id)
        #expect(result.expenseLogIDs == [expense.id])
        #expect(result.eventIDs == [event.id])
        #expect(policy.companyName == "Ohana Care")
        #expect(policy.policyNumber == "P-1")
        #expect(policy.productName == "Care Plus")
        #expect(policy.paymentFrequency == .once)
        #expect(policy.otherFeeAmount == 10)
        #expect(expenses.count == 1)
        #expect(expense.amount == 130)
        #expect(expense.note == "Care Plus 首期保费（含Service fee）")
        #expect(expense.executorId == executorHuman.id.uuidString)
        #expect(events.count == 1)
        #expect(event.relatedEntityId == policy.id.uuidString)
        #expect(event.eventType == EventType.insurancePremium.rawValue)
    }

    @MainActor
    @Test func insurancePolicyServiceUpdatesExistingPolicyWithoutNewSchedule() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let insurance = PetInsurance(companyName: "Old", productName: "Basic", annualPremium: 80, pet: pet)
        context.insert(pet)
        context.insert(insurance)
        try context.save()

        let result = InsurancePolicyCommandService.savePolicy(
            existing: insurance,
            pet: pet,
            input: InsurancePolicySaveCommandInput(
                companyName: "New Care",
                policyNumber: "P-2",
                productName: "Premium",
                annualPremium: 160,
                coverageAmount: 2000,
                startDate: makeDate(year: 2026, month: 6, day: 8),
                renewalDate: makeDate(year: 2027, month: 6, day: 8),
                notes: "Updated",
                paymentFrequency: .annual,
                paymentDayOfMonth: 9,
                showInCalendar: true,
                otherFeeAmount: 0,
                otherFeeNote: "",
                autoGeneratesPayments: true,
                executorId: "human-1"
            ),
            context: context
        )

        let policies = try context.fetch(FetchDescriptor<PetInsurance>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(result.policyID == insurance.id)
        #expect(result.expenseLogIDs.isEmpty)
        #expect(result.eventIDs.isEmpty)
        #expect(policies.count == 1)
        #expect(insurance.companyName == "New Care")
        #expect(insurance.productName == "Premium")
        #expect(insurance.annualPremium == 160)
        #expect(insurance.showInCalendar == true)
        #expect(expenses.isEmpty)
        #expect(events.isEmpty)
    }

    @MainActor
    @Test func petHygieneCommandServiceRecordsAndDeletesFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let date = makeDate(year: 2026, month: 6, day: 8, hour: 10, minute: 30)
        let recorded = PetHygieneCommandService.record(
            pet: pet,
            type: .bath,
            context: context,
            executorId: executorHuman.id.uuidString,
            date: date
        )

        var logs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        var ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let ledgerEventID = try #require(ledgerEvents.first?.id)
        #expect(logs.count == 1)
        #expect(logs.first?.id == recorded.result.logID)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.hygieneType == .bath)
        #expect(logs.first?.date == date)
        #expect(logs.first?.executorId == executorHuman.id.uuidString)
        #expect(recorded.result.subjectID == pet.id)
        #expect(recorded.result.hygieneType == .bath)
        #expect(ledgerEvents.contains { $0.eventKind == CareLedgerEventKind.hygiene.rawValue && $0.legacyModelId == recorded.result.logID.uuidString })
        let unrelatedLedger = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: HygieneType.brushing.rawValue,
            legacyModelName: "PetHygieneLog",
            legacyModelId: "unrelated-hygiene-log"
        )
        context.insert(unrelatedLedger)
        try context.save()

        let deleted = PetHygieneCommandService.delete(
            recorded.log,
            pet: pet,
            context: context
        )

        logs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.isEmpty)
        #expect(ledgerEvents.map(\.id) == [unrelatedLedger.id])
        #expect(deleted.subjectID == pet.id)
        #expect(deleted.logID == recorded.result.logID)
        #expect(deleted.didDelete == true)
        #expect(deleted.removedLedgerEventIDs == [ledgerEventID])
    }

    @MainActor
    @Test func petHygieneCommandServiceCreatesPlanEventAndReminder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let startDate = makeDate(year: 2026, month: 6, day: 8)
        let startTime = makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 15)
        let endDate = makeDate(year: 2026, month: 7, day: 8)
        let result = PetHygieneCommandService.createPlan(
            pet: pet,
            type: .brushing,
            input: PetHygienePlanCommandInput(
                startDate: startDate,
                isAllDay: false,
                startTime: startTime,
                hasEndDate: true,
                endDate: endDate,
                repeatDays: 5,
                customNote: "  coat check  "
            ),
            context: context,
            scheduleNotification: false
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let event = try #require(events.first)
        let reminder = try #require(reminders.first)
        #expect(events.count == 1)
        #expect(reminders.count == 1)
        #expect(result.subjectID == pet.id)
        #expect(result.hygieneType == .brushing)
        #expect(result.eventID == event.id)
        #expect(result.reminderID == reminder.id)
        #expect(event.title == "Momo — 梳毛 — coat check")
        #expect(event.startDate == makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 15))
        #expect(event.endDate == makeDate(year: 2026, month: 7, day: 8, hour: 8, minute: 15))
        #expect(event.isAllDay == false)
        #expect(event.eventType == EventType.grooming.rawValue)
        #expect(event.relatedEntityType == EntityKind.pet.rawValue)
        #expect(event.relatedEntityId == pet.id.uuidString)
        #expect(event.recurrenceDays == 5)
        #expect(event.recurrenceEndDate == Calendar.current.startOfDay(for: endDate))
        #expect(reminder.event?.id == event.id)
        #expect(reminder.scheduledAt == event.startDate)
        #expect(reminder.isPending == true)

        UserDefaults.standard.removeObject(forKey: HygieneType.customCycleDaysKey(petId: pet.id, type: .brushing))
    }

    @MainActor
    @Test func petHygieneCommandExecutorPublishesRecordDeleteAndPlanRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let executor = PetHygieneCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let recorded = executor.record(
            pet: pet,
            type: .bath,
            executorId: executorHuman.id.uuidString,
            date: makeDate(year: 2026, month: 6, day: 8, hour: 10, minute: 30),
            note: "test.hygiene.record"
        )
        let recordMutation = try #require(revisionCenter.lastMutation)

        #expect(recordMutation.command == .petHygieneRecord(petID: pet.id, type: HygieneType.bath.rawValue))
        #expect(recordMutation.affectedEntityIDs == [pet.id, recorded.result.logID])
        #expect(recordMutation.note == "test.hygiene.record")

        let deleted = executor.delete(recorded.log, pet: pet, note: "test.hygiene.delete")
        let deleteMutation = try #require(revisionCenter.lastMutation)
        #expect(deleted.logID == recorded.result.logID)
        #expect(deleteMutation.command == .petHygieneDelete(petID: pet.id, recordID: recorded.result.logID))
        #expect(deleteMutation.affectedEntityIDs.contains(pet.id))
        #expect(deleteMutation.affectedEntityIDs.contains(recorded.result.logID))
        #expect(deleteMutation.note == "test.hygiene.delete")

        let startDate = makeDate(year: 2026, month: 6, day: 9)
        let startTime = makeDate(year: 2026, month: 6, day: 9, hour: 9, minute: 15)
        let plan = executor.createPlan(
            pet: pet,
            type: .brushing,
            input: PetHygienePlanCommandInput(
                startDate: startDate,
                isAllDay: false,
                startTime: startTime,
                hasEndDate: false,
                endDate: startDate,
                repeatDays: 7,
                customNote: "coat"
            ),
            scheduleNotification: false,
            note: "test.hygiene.plan"
        )
        let planMutation = try #require(revisionCenter.lastMutation)
        #expect(planMutation.command == .petHygienePlan(petID: pet.id, type: HygieneType.brushing.rawValue))
        #expect(planMutation.affectedEntityIDs == [pet.id, plan.eventID, plan.reminderID])
        #expect(planMutation.note == "test.hygiene.plan")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)

        UserDefaults.standard.removeObject(forKey: HygieneType.customCycleDaysKey(petId: pet.id, type: .brushing))
    }

    @MainActor
    @Test func petSymptomCommandServiceWritesSymptomFactAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let date = makeDate(year: 2026, month: 6, day: 8, hour: 11, minute: 20)
        let result = try #require(PetSymptomCommandService.recordSymptom(
            pet: pet,
            input: PetSymptomCommandInput(
                date: date,
                category: .digestive,
                symptomName: "  vomiting  ",
                severity: .moderate,
                note: " after breakfast ",
                photoData: Data([1, 2, 3])
            ),
            context: context
        ))

        let logs = try context.fetch(FetchDescriptor<SymptomLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.date == date)
        #expect(logs.first?.category == .digestive)
        #expect(logs.first?.symptomName == "vomiting")
        #expect(logs.first?.severity == .moderate)
        #expect(logs.first?.note == "after breakfast")
        #expect(logs.first?.photoData == Data([1, 2, 3]))
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.id == result.ledgerEventID)
        #expect(ledgerEvents.first?.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(ledgerEvents.first?.subjectId == pet.id.uuidString)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.health.rawValue)
        #expect(ledgerEvents.first?.actionType == "symptom")
        #expect(ledgerEvents.first?.legacyModelName == "SymptomLog")
        #expect(ledgerEvents.first?.legacyModelId == result.logID.uuidString)
    }

    @MainActor
    @Test func petSymptomCommandServiceSkipsBlankSymptomName() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let result = PetSymptomCommandService.recordSymptom(
            pet: pet,
            input: PetSymptomCommandInput(
                date: makeDate(year: 2026, month: 6, day: 8),
                category: .other,
                symptomName: "   ",
                severity: .mild,
                note: "ignored",
                photoData: nil
            ),
            context: context
        )

        let logs = try context.fetch(FetchDescriptor<SymptomLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result == nil)
        #expect(logs.isEmpty)
        #expect(ledgerEvents.isEmpty)
    }

    @MainActor
    @Test func petHealthDeleteServiceDeletesHealthSymptomAndHeatFacts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let health = PetHealthLog(date: makeDate(year: 2026, month: 6, day: 8), type: .checkup, note: "ok", pet: pet)
        let symptom = SymptomLog(
            date: makeDate(year: 2026, month: 6, day: 9),
            category: .skin,
            symptomName: "itchy",
            severity: .mild,
            pet: pet
        )
        let heat = HeatCycleLog(
            startDate: makeDate(year: 2026, month: 6, day: 10),
            status: .estrus,
            pet: pet
        )
        context.insert(pet)
        context.insert(health)
        context.insert(symptom)
        context.insert(heat)
        try context.save()

        let healthID = health.id
        let symptomID = symptom.id
        let heatID = heat.id
        let deletedHealth = PetHealthDeleteCommandService.deleteHealthLog(health, pet: pet, context: context)
        let deletedSymptom = PetHealthDeleteCommandService.deleteSymptomLog(symptom, pet: pet, context: context)
        let deletedHeat = PetHealthDeleteCommandService.deleteHeatCycleLog(heat, pet: pet, context: context)

        let healthLogs = try context.fetch(FetchDescriptor<PetHealthLog>())
        let symptomLogs = try context.fetch(FetchDescriptor<SymptomLog>())
        let heatLogs = try context.fetch(FetchDescriptor<HeatCycleLog>())
        #expect(healthLogs.isEmpty)
        #expect(symptomLogs.isEmpty)
        #expect(heatLogs.isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: PetHealthLog.self), id: healthID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: SymptomLog.self), id: symptomID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: HeatCycleLog.self), id: heatID, context: context)?.isDeletionTombstone == true)
        #expect(deletedHealth.subjectID == pet.id)
        #expect(deletedHealth.kind == "health")
        #expect(deletedSymptom.subjectID == pet.id)
        #expect(deletedSymptom.kind == "symptom")
        #expect(deletedHeat.subjectID == pet.id)
        #expect(deletedHeat.kind == "heat")
    }

    @MainActor
    @Test func petHealthDeleteServiceCleansDerivedExpenseReminderEventAndLedgerFacts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let fakeNotifications = RecordingNotificationScheduler()
        OhanaNotifications.current = fakeNotifications
        defer { OhanaNotifications.useLive() }

        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let date = makeDate(year: 2026, month: 6, day: 8)
        let expirationDate = makeDate(year: 2027, month: 6, day: 8)
        let result = try #require(PetHealthCommandService.recordHealth(
            pet: pet,
            input: PetHealthRecordCommandInput(
                type: .vaccine,
                date: date,
                name: "Rabies",
                note: "",
                vetName: "Clinic",
                cost: 20,
                expirationDate: expirationDate,
                nextCheckupDate: nil,
                executorId: executorHuman.id.uuidString,
                source: .detail,
                includesNameInNote: true,
                expirationReminderLeadDays: 14
            ),
            context: context,
            awardsReward: false,
            schedulesReminderNotification: false,
            questManager: makeQuestManager()
        ))
        let healthLog = try #require(try context.fetch(FetchDescriptor<PetHealthLog>()).first)
        let reminder = try #require(try context.fetch(FetchDescriptor<Reminder>()).first)
        reminder.notificationId = "health-reminder"
        try context.save()

        let deleteResult = PetHealthDeleteCommandService.deleteHealthLog(healthLog, pet: pet, context: context)

        let healthLogs = try context.fetch(FetchDescriptor<PetHealthLog>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(deleteResult.recordID == result.logID)
        #expect(healthLogs.isEmpty)
        #expect(expenses.isEmpty)
        #expect(events.isEmpty)
        #expect(reminders.isEmpty)
        #expect(ledgerEvents.isEmpty)
        #expect(fakeNotifications.cancelledIds == ["health-reminder"])
        #expect(try cloudSyncState(entityName: String(describing: PetHealthLog.self), id: result.logID, context: context)?.isDeletionTombstone == true)
        if let expenseLogID = result.expenseLogID {
            #expect(try cloudSyncState(entityName: String(describing: PetExpenseLog.self), id: expenseLogID, context: context)?.isDeletionTombstone == true)
        }
    }

    @MainActor
    @Test func petHealthWriteCommandsRejectDeceasedPets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let deceasedPet = Pet(name: "Momo", species: "狗")
        deceasedPet.passedAwayDate = makeDate(year: 2026, month: 6, day: 1)
        context.insert(deceasedPet)
        try context.save()

        let healthResult = PetHealthCommandService.recordHealth(
            pet: deceasedPet,
            input: PetHealthRecordCommandInput(
                type: .checkup,
                date: makeDate(year: 2026, month: 6, day: 8),
                name: "Annual",
                note: "",
                vetName: "",
                cost: 0,
                expirationDate: nil,
                nextCheckupDate: nil,
                executorId: nil,
                source: .detail,
                includesNameInNote: true
            ),
            context: context,
            awardsReward: false,
            questManager: makeQuestManager()
        )
        let symptomResult = PetSymptomCommandService.recordSymptom(
            pet: deceasedPet,
            input: PetSymptomCommandInput(
                date: makeDate(year: 2026, month: 6, day: 8),
                category: .other,
                symptomName: "cough",
                severity: .mild,
                note: "",
                photoData: nil
            ),
            context: context
        )
        let heatResult = PetHeatCycleCommandService.recordHeatCycle(
            pet: deceasedPet,
            input: PetHeatCycleCommandInput(
                startDate: makeDate(year: 2026, month: 6, day: 8),
                endDate: nil,
                status: .estrus,
                note: "",
                isMated: false,
                expectedDeliveryDate: nil
            ),
            context: context
        )

        #expect(healthResult == nil)
        #expect(symptomResult == nil)
        #expect(heatResult == nil)

        #expect(try context.fetch(FetchDescriptor<PetHealthLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SymptomLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HeatCycleLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @MainActor
    @Test func petHeatCycleCommandServiceRecordsOneFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let startDate = makeDate(year: 2026, month: 6, day: 8)
        let endDate = makeDate(year: 2026, month: 6, day: 15)
        let deliveryDate = makeDate(year: 2026, month: 8, day: 10)
        context.insert(pet)
        try context.save()

        let result = try #require(PetHeatCycleCommandService.recordHeatCycle(
            pet: pet,
            input: PetHeatCycleCommandInput(
                startDate: startDate,
                endDate: endDate,
                status: .pregnant,
                note: "  follow up  ",
                isMated: true,
                expectedDeliveryDate: deliveryDate
            ),
            context: context
        ))

        let logs = try context.fetch(FetchDescriptor<HeatCycleLog>())
        let log = try #require(logs.first)
        #expect(logs.count == 1)
        #expect(result.subjectID == pet.id)
        #expect(result.logID == log.id)
        #expect(result.status == .pregnant)
        #expect(log.pet?.id == pet.id)
        #expect(log.startDate == startDate)
        #expect(log.endDate == endDate)
        #expect(log.note == "follow up")
        #expect(log.isMated == true)
        #expect(log.expectedDeliveryDate == deliveryDate)
    }

    @MainActor
    @Test func todayFocusCommandServiceCompletesRecurringOccurrenceOnly() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let start = makeDate(year: 2026, month: 6, day: 8)
        let occurrence = makeDate(year: 2026, month: 6, day: 15)
        let event = Event(title: "Water plants", startDate: start, eventType: EventType.task.rawValue)
        event.recurrenceDays = 7
        context.insert(event)
        try context.save()

        let result = TodayFocusCommandService.completeEvent(event, on: occurrence, context: context)

        #expect(result.eventID == event.id)
        #expect(result.isCompleted == true)
        #expect(result.didChange == true)
        #expect(event.isCompleted == false)
        #expect(event.isOccurrenceMarkedComplete(on: occurrence) == true)
        #expect(event.isOccurrenceMarkedComplete(on: start) == false)
    }

    @MainActor
    @Test func todayFocusCommandServiceCompletesSingleEvent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let start = makeDate(year: 2026, month: 6, day: 8)
        let event = Event(title: "Clean shelf", startDate: start, eventType: EventType.task.rawValue)
        context.insert(event)
        try context.save()

        let result = TodayFocusCommandService.completeEvent(event, on: start, context: context)

        #expect(result.eventID == event.id)
        #expect(result.isCompleted == true)
        #expect(result.didChange == true)
        #expect(event.isCompleted == true)
        #expect(event.isOccurrenceMarkedComplete(on: start) == true)
    }

    @MainActor
    @Test func todayFocusExecutorWritesPetTaskFactForMissingExecutor() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let occurrence = makeDate(year: 2026, month: 6, day: 8)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "Feed Momo 42g",
            startDate: occurrence,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(pet)
        context.insert(event)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.removeObject(forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()

        let executor = HomeCommandExecutor(
            modelContext: context,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(),
            medicationReminders: SharedMedicationReminderManager(),
            todayFocus: StaticTodayFocusManager()
        )
        let beforeRevision = revisionCenter.homeRevision.value
        let missingExecutorID = UUID().uuidString

        let didComplete = executor.completeTodayFocusEvent(event, on: occurrence, executorId: missingExecutorID)

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let mutation = try #require(revisionCenter.lastMutation)
        #expect(didComplete == true)
        #expect(event.isOccurrenceMarkedComplete(on: occurrence))
        #expect(careLogs.count == 1)
        #expect(careLogs.first?.pet?.id == pet.id)
        #expect(ledgerEvents.contains { $0.legacyModelId == careLogs.first?.id.uuidString })
        #expect(walletEntries.isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .todayFocus(entityID: event.id, action: "eventComplete"))
        #expect(mutation.wroteBusinessFact == true)
    }

    @MainActor
    @Test func todayFocusCompletionForDeceasedPetNoopsWithoutHistoricalFactOrRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let occurrence = makeDate(year: 2026, month: 6, day: 1, hour: 9, minute: 0)
        let deceasedPet = Pet(name: "Momo", species: "猫")
        deceasedPet.passedAwayDate = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let event = Event(
            title: "Feed Momo 42g",
            startDate: occurrence,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: deceasedPet.id.uuidString
        )
        context.insert(human)
        context.insert(deceasedPet)
        context.insert(event)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldCooldownLogs {
                defaults.set(oldCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
            memberKey: human.id.uuidString,
            careObjectKeys: [deceasedPet.id.uuidString]
        )
        let executor = HomeCommandExecutor(
            modelContext: context,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(),
            medicationReminders: SharedMedicationReminderManager(),
            todayFocus: StaticTodayFocusManager()
        )
        let beforeRevision = revisionCenter.homeRevision.value

        executor.completeTodayFocusEvent(event, on: occurrence, executorId: human.id.uuidString)

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(event.isOccurrenceMarkedComplete(on: occurrence) == false)
        #expect(event.isCompleted == false)
        #expect(careLogs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision)
        #expect(revisionCenter.lastMutation == nil)
    }

    @MainActor
    @Test func plantCareCommandServiceWritesFactEventAndLedgerInOneBoundary() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let plant = Plant(name: "Fern")
        let now = makeDate(year: 2026, month: 6, day: 8, hour: 10, minute: 15)
        context.insert(plant)
        try context.save()

        let result = PlantCareCommandService.recordCare(
            .watering,
            plant: plant,
            executorId: "human-1",
            context: context,
            now: now,
            syncCarePlan: false
        )

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result.plantID == plant.id)
        #expect(result.careType == .watering)
        #expect(result.didPersist)
        #expect(result.persistenceError == nil)
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.date == now)
        #expect(logs.first?.plant?.id == plant.id)
        #expect(plant.lastWateredDate == now)
        #expect(events.count == 1)
        #expect(events.first?.id == result.eventID)
        #expect(events.first?.eventType == EventType.watering.rawValue)
        #expect(events.first?.relatedEntityType == EntityKind.plant.rawValue)
        #expect(events.first?.relatedEntityId == plant.id.uuidString)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.id == result.ledgerEventID)
        #expect(ledgerEvents.first?.sourceEventId == result.eventID.uuidString)
        #expect(ledgerEvents.first?.legacyModelId == result.logID.uuidString)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.plantCare.rawValue)
    }

    @MainActor
    @Test func plantCareCommandExecutorPublishesRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let plant = Plant(name: "Fern")
        context.insert(plant)
        try context.save()

        let beforeRevision = revisionCenter.homeRevision.value
        let result = PlantCareCommandExecutor(context: context, revisionCenter: revisionCenter).recordCare(
            .fertilizing,
            plant: plant,
            executorId: "human-1",
            note: "test.plant.executor",
            syncCarePlan: false
        )
        let mutation = try #require(revisionCenter.lastMutation)

        #expect(result.plantID == plant.id)
        #expect(result.careType == .fertilizing)
        #expect(result.didPersist)
        #expect(plant.lastFertilizedDate != nil)
        #expect(mutation.command == .plantCare(plantID: plant.id, action: PlantCareType.fertilizing.rawValue))
        #expect(mutation.affectedEntityIDs == [result.plantID, result.logID, result.eventID, result.ledgerEventID])
        #expect(mutation.wroteBusinessFact)
        #expect(mutation.note == "test.plant.executor")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
    }

    @MainActor
    @Test func homePlantQuickCareByIdReturnsResultAndWritesWaterFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let plant = Plant(name: "Fern")
        context.insert(plant)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)
        let result = try #require(executor.recordPlantCare(.watering, plantID: plant.id, executorId: "human-1"))

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        #expect(result.plantID == plant.id)
        #expect(result.careType == .watering)
        #expect(result.didPersist)
        #expect(result.persistenceError == nil)
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.plant?.id == plant.id)
        #expect(plant.lastWateredDate != nil)
    }

    @Test func plantQuickCareHomeSurfaceTracksPendingCompletedAndRewardFeedback() throws {
        let rootURL = repositoryRootURL()
        let modelContextSource = try source("Ohana/Shared/Utilities/ModelContextExtensions.swift", rootURL: rootURL)
        let plantCommandSource = try source("Ohana/Features/Plants/PlantCommands.swift", rootURL: rootURL)
        let revisionSource = try source("Ohana/Features/RevisionPublishing/DomainRevisionPublishing+FeaturePublishing.swift", rootURL: rootURL)
        let detailActionsSource = try source("Ohana/Features/Plants/Views/PlantDetailView+Actions.swift", rootURL: rootURL)
        let featureDetailSource = try source("Ohana/Features/Plants/Views/PlantCareFeatureDetailView.swift", rootURL: rootURL)
        let routeContainerSource = try source("Ohana/Features/Home/HomePlantCareLogRouteContainer.swift", rootURL: rootURL)
        let quickActionSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView+QuickActions.swift", rootURL: rootURL)
        let viewSource = try source("Ohana/Features/Home/Views/VerticalSolidHomeView.swift", rootURL: rootURL)
        let plantPageSource = try source("Ohana/Features/Home/Views/VerticalSolidHomePlantsPage.swift", rootURL: rootURL)
        let embeddedSource = try source("Ohana/Features/Home/Views/VerticalHomeEmbeddedQuickActions.swift", rootURL: rootURL)
        let dockSource = try source("Ohana/Features/Plants/Views/PlantDockQuickActionsView.swift", rootURL: rootURL)

        #expect(modelContextSource.contains("struct ModelContextSaveResult"))
        #expect(modelContextSource.contains("safeSaveResult("))
        #expect(plantCommandSource.contains("let didPersist: Bool"))
        #expect(plantCommandSource.contains("let persistenceError: String?"))
        #expect(plantCommandSource.contains("context.safeSaveResult()"))
        #expect(!plantCommandSource.contains("rollbackOnFailure: true"))
        #expect(revisionSource.contains("affectedEntityIDs: result.affectedEntityIDs"))
        #expect(revisionSource.contains("wroteBusinessFact: result.didPersist"))
        #expect(quickActionSource.contains("guard !pendingPlantQuickCareKeys.contains(key) else { return }"))
        #expect(quickActionSource.contains("setPlantQuickCarePending(key)"))
        #expect(quickActionSource.contains("guard result.didPersist else"))
        #expect(quickActionSource.contains("setPlantQuickCareCompleted(key)"))
        #expect(quickActionSource.contains("setPlantQuickCareFailed(key)"))
        #expect(quickActionSource.contains("applyPlantQuickCareRewardFeedback(result)"))
        #expect(quickActionSource.contains("if result.coconutDelta > 0"))
        #expect(detailActionsSource.contains("guard result.didPersist else"))
        #expect(detailActionsSource.contains("failedDetailQuickCareTypes.insert(type)"))
        #expect(featureDetailSource.contains("notificationOccurred(result.didPersist ? .success : .error)"))
        #expect(routeContainerSource.contains("notificationOccurred(result.didPersist ? .success : .error)"))
        #expect(viewSource.contains("@State var pendingPlantQuickCareKeys"))
        #expect(plantPageSource.contains("pendingCareTypes: plantQuickCareTypes(in: pendingQuickCareKeys"))
        #expect(dockSource.contains("statusText(for: dockAction, isDue: isDue, isPending: isPending, didComplete: didComplete, didFail: didFail)"))
        #expect(dockSource.contains("isPrimaryDisabled: isPending"))
        #expect(embeddedSource.contains("\"plant\""))
        #expect(embeddedSource.contains("\"repotting\""))
        #expect(embeddedSource.contains("\"yellowleaf\""))
    }

    @Test func petCareFactsStopDerivedEffectsWhenPersistenceFails() throws {
        let rootURL = repositoryRootURL()
        let careServiceSource = try source("Ohana/Domain/Services/CareEventService.swift", rootURL: rootURL)
        let careFactSource = try source("Ohana/Domain/Services/CareEventService+Care.swift", rootURL: rootURL)
        let feedFactSource = try source("Ohana/Domain/Services/CareEventService+Feed.swift", rootURL: rootURL)
        let sharedRecorderSource = try source("Ohana/Domain/Services/SharedPetActionRecorder.swift", rootURL: rootURL)
        let feedCommandSource = try source("Ohana/Features/Feeding/FeedCommands.swift", rootURL: rootURL)
        let quickWaterSource = try source("Ohana/Features/QuickCare/QuickWaterCommandExecutor.swift", rootURL: rootURL)

        #expect(careServiceSource.contains("let didPersist: Bool"))
        #expect(careServiceSource.contains("didPersist && disposition.didWriteFact"))
        #expect(careServiceSource.contains("didPersist && disposition.allowsDerivedEffects"))
        #expect(sharedRecorderSource.contains("let didPersist: Bool"))
        #expect(sharedRecorderSource.contains("context.safeSaveResult()"))
        #expect(sharedRecorderSource.contains("guard saveResult.didSave else"))
        #expect(!careFactSource.contains("context.safeSave()"))
        #expect(!feedFactSource.contains("context.safeSave()"))
        #expect(!sharedRecorderSource.contains("context.safeSave()"))
        #expect(careFactSource.contains("guard saveResult.didSave else"))
        #expect(feedFactSource.contains("guard saveResult.didSave else"))
        #expect(feedCommandSource.contains("didPersist: recorded.result.didPersist"))
        #expect(quickWaterSource.contains("didPersist: recorded.result.didPersist"))
    }

    @Test func memberLifecycleCommandsSurfacePersistenceFailures() throws {
        let rootURL = repositoryRootURL()
        let resultSource = try source("Ohana/Features/Members/MemberProfileCommands.swift", rootURL: rootURL)
        let lifecycleSource = try source("Ohana/Features/Members/MemberInteractionCommands.swift", rootURL: rootURL)
        let petDetailSource = try source("Ohana/Features/Members/Views/PetBasicInfoDetailView+MemorialDanger.swift", rootURL: rootURL)
        let petSettingsSource = try source("Ohana/Features/Members/Views/PetCardBackSettingsSheet.swift", rootURL: rootURL)
        let humanBasicSource = try source("Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift", rootURL: rootURL)
        let humanDetailSource = try source("Ohana/Features/Members/Views/HumanDetailView+RemindersActions.swift", rootURL: rootURL)
        let crewSource = try source("Ohana/Features/CrewRoster/Views/CrewRosterOverlayEditors.swift", rootURL: rootURL)
        let settingsPetSource = try source("Ohana/Features/Settings/Views/SettingsPetManagementSheet.swift", rootURL: rootURL)

        #expect(resultSource.contains("let didPersist: Bool"))
        #expect(resultSource.contains("static func failed"))
        #expect(lifecycleSource.contains("private static func persistLifecycleMutation"))
        #expect(lifecycleSource.contains("let saveResult = context.safeSaveResult()"))
        #expect(lifecycleSource.contains("context.rollback()"))
        #expect(lifecycleSource.contains("return .failed"))
        #expect(!lifecycleSource.contains("RainbowBridgeService().markPassedAway(pet: pet, date: date, context: context)\n        CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: date)\n        context.safeSave()"))
        #expect(petDetailSource.contains("notificationOccurred(result.didPersist ? .success : .error)"))
        #expect(petSettingsSource.contains("notificationOccurred(result.didPersist ? .success : .error)"))
        #expect(humanBasicSource.contains("notificationOccurred(result.didPersist ? .success : .error)"))
        #expect(humanDetailSource.contains("notificationOccurred(result.didPersist ? .success : .error)"))
        #expect(crewSource.contains("guard result.didPersist else"))
        #expect(settingsPetSource.contains("notificationOccurred(result.didPersist ? .success : .error)"))
    }

    @MainActor
    @Test func plantCareCommandServiceWritesEveryLaunchCareType() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let plant = Plant(name: "Fern")
        context.insert(plant)
        try context.save()

        for (index, type) in PlantCareType.allCases.enumerated() {
            PlantCareCommandService.recordCare(
                type,
                plant: plant,
                executorId: nil,
                context: context,
                now: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: index),
                careNote: "type.\(type.rawValue)",
                healthStatus: type == .yellowLeaf ? .watching : nil,
                syncCarePlan: false
            )
        }

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(logs.count == PlantCareType.allCases.count)
        #expect(events.count == PlantCareType.allCases.count)
        #expect(Set(logs.map(\.careTypeRaw)) == Set(PlantCareType.allCases.map(\.rawValue)))
        #expect(events.contains { $0.eventType == EventType.plantRepotting.rawValue })
        #expect(events.contains { $0.eventType == EventType.plantPestCheck.rawValue })
        #expect(events.contains { $0.eventType == EventType.plantHealthCheck.rawValue })
        #expect(plant.healthStatus == .watching)
    }

    @MainActor
    @Test func plantCreationCommandServiceWritesOnePlantFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let id = UUID()

        let result = PlantCreationCommandService.createPlant(
            input: PlantCreationCommandInput(
                id: id,
                name: "  Fern  ",
                species: "  Boston fern  ",
                location: "  Living room  ",
                avatarEmoji: "  ",
                wateringIntervalDays: 5,
                fertilizingIntervalDays: 40,
                potDiameterCm: 12,
                potMaterialRaw: "  terracotta  ",
                soilTypeRaw: "  airy mix  ",
                isIndoor: false,
                windowDirection: .east,
                lightLevel: .brightIndirect,
                healthStatus: .watching,
                catalogSpeciesId: "chlorophytum-comosum",
                isToxicToCats: true,
                isToxicToDogs: false,
                isToxicToChildren: true,
                isIndoorSuitable: true,
                remindersEnabled: false
            ),
            context: context
        )

        let plants = try context.fetch(FetchDescriptor<Plant>())
        let plant = try #require(plants.first)
        #expect(plants.count == 1)
        #expect(result.plantID == id)
        #expect(result.kind == EntityKind.plant.rawValue)
        #expect(plant.id == id)
        #expect(plant.name == "Fern")
        #expect(plant.species == "Boston fern")
        #expect(plant.location == "Living room")
        #expect(plant.avatarEmoji == "🌱")
        #expect(plant.wateringIntervalDays == 5)
        #expect(plant.fertilizingIntervalDays == 40)
        #expect(plant.potDiameterCm == 12)
        #expect(plant.potMaterialRaw == "terracotta")
        #expect(plant.soilTypeRaw == "airy mix")
        #expect(plant.isIndoor == false)
        #expect(plant.windowDirection == .east)
        #expect(plant.lightLevel == .brightIndirect)
        #expect(plant.healthStatus == .watching)
        #expect(plant.catalogSpeciesId == "chlorophytum-comosum")
        #expect(plant.isToxicToCats)
        #expect(!plant.isToxicToDogs)
        #expect(plant.isToxicToChildren)
        #expect(plant.remindersEnabled == false)
    }

    @MainActor
    @Test func plantCreationCommandExecutorPublishesCreationRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let id = UUID()
        let beforeRevision = revisionCenter.homeRevision.value

        let result = PlantCreationCommandExecutor(context: context, revisionCenter: revisionCenter).createPlant(
            input: PlantCreationCommandInput(
                id: id,
                name: "Fern",
                species: "Boston fern",
                location: "Living room",
                avatarEmoji: "🌿",
                wateringIntervalDays: 5,
                fertilizingIntervalDays: 40
            ),
            note: "test.plant.creation"
        )
        let mutation = try #require(revisionCenter.lastMutation)

        #expect(result.plantID == id)
        #expect(mutation.command == .memberCreation(entityID: id, kind: EntityKind.plant.rawValue))
        #expect(mutation.affectedEntityIDs == [id])
        #expect(mutation.note == "test.plant.creation")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
    }

    @MainActor
    @Test func plantCreationCommandExecutorMaterializesCarePlansForCalendarAndReminders() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let id = UUID()

        PlantCreationCommandExecutor(context: context, revisionCenter: revisionCenter).createPlant(
            input: PlantCreationCommandInput(
                id: id,
                name: "Pothos",
                species: "Epipremnum aureum",
                location: "Living room shelf",
                avatarEmoji: "🌿",
                wateringIntervalDays: 3,
                fertilizingIntervalDays: 21,
                catalogSpeciesId: "epipremnum-aureum",
                remindersEnabled: true
            ),
            note: "test.plant.creation.schedule",
            scheduleNotifications: false
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let plantPlanEvents = events.filter {
            $0.isAllDay &&
                $0.relatedEntityType == EntityKind.plant.rawValue &&
                $0.relatedEntityId == id.uuidString &&
                $0.title.contains("植物计划")
        }
        let plantPlanReminderEventIDs = Set(plantPlanEvents.map(\.id))
        let plantPlanReminders = reminders.filter { reminder in
            guard let event = reminder.event else { return false }
            return plantPlanReminderEventIDs.contains(event.id)
        }

        #expect(!plantPlanEvents.isEmpty)
        #expect(!plantPlanReminders.isEmpty)
        #expect(plantPlanEvents.contains { $0.eventType == EventType.watering.rawValue })
        #expect(plantPlanEvents.contains { $0.eventType == EventType.fertilizing.rawValue })
        for reminder in plantPlanReminders {
            #expect(reminder.isPending)
        }
    }

    @MainActor
    @Test func memberDeletionServiceDeletesPetRelatedEventsAndQuickActions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let defaultsName = "MemberDeletionCommandServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let pet = Pet(name: "Momo", species: "狗")
        let relatedEvent = Event(
            title: "Momo care",
            startDate: makeDate(year: 2026, month: 6, day: 8),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let unrelatedEvent = Event(
            title: "Other care",
            startDate: makeDate(year: 2026, month: 6, day: 8),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString
        )
        context.insert(pet)
        context.insert(relatedEvent)
        context.insert(unrelatedEvent)
        try context.save()

        defaults.set(
            """
            [
              {"id":"remove-pet","label":"Feed","icon":"fork.knife","colorHex":"FFCC00","petId":"\(pet.id.uuidString)","actionType":"feed"},
              {"id":"remove-entity","label":"Care","icon":"pawprint.fill","colorHex":"00D4AA","entityId":"\(pet.id.uuidString)","entityKindRaw":"\(EntityKind.pet.rawValue)","actionType":"health"},
              {"id":"keep","label":"Other","icon":"calendar","colorHex":"FFFFFF","actionType":"calendar"}
            ]
            """,
            forKey: "quickActionItems_v2"
        )

        let result = MemberDeletionCommandService.deletePet(pet, context: context, userDefaults: defaults)

        let pets = try context.fetch(FetchDescriptor<Pet>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let quickActionJSON = try #require(defaults.string(forKey: "quickActionItems_v2"))
        #expect(result.entityID == pet.id)
        #expect(result.kind == EntityKind.pet.rawValue)
        #expect(result.removedRelatedEventIDs == [relatedEvent.id])
        #expect(result.removedQuickActionCount == 2)
        #expect(pets.isEmpty)
        #expect(Set(events.map(\.id)) == Set([unrelatedEvent.id]))
        #expect(try cloudSyncState(entityName: String(describing: Pet.self), id: pet.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: relatedEvent.id, context: context)?.isDeletionTombstone == true)
        #expect(quickActionJSON.contains("\"id\":\"keep\"") || quickActionJSON.contains("\"id\": \"keep\""))
        #expect(!quickActionJSON.contains("remove-pet"))
        #expect(!quickActionJSON.contains("remove-entity"))
    }

    @MainActor
    @Test func memberDeletionServiceDeletesCurrentHumanAndRequestsAccountSwitch() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Guan")
        let remainingHuman = Human(name: "Alex")
        context.insert(activeHuman)
        context.insert(remainingHuman)
        try context.save()

        let result = MemberDeletionCommandService.deleteHuman(
            activeHuman,
            activeHumanID: activeHuman.id.uuidString,
            context: context
        )

        let humans = try context.fetch(FetchDescriptor<Human>())
        #expect(result.entityID == activeHuman.id)
        #expect(result.kind == EntityKind.human.rawValue)
        #expect(result.clearsActiveHumanID == true)
        #expect(result.requiresAccountSwitch == true)
        #expect(result.requiresReplacementHuman == false)
        #expect(Set(humans.map(\.id)) == Set([remainingHuman.id]))
        #expect(try cloudSyncState(entityName: String(describing: Human.self), id: activeHuman.id, context: context)?.isDeletionTombstone == true)
    }

    @MainActor
    @Test func memberDeletionServiceDeletesHumanScopedGachaAndShopRecords() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Guan")
        let remainingHuman = Human(name: "Alex")
        let ownedItem = GachaOwnedItem(
            ownerHumanId: activeHuman.id.uuidString,
            seriesId: GachaSeriesCatalog.defaultSeriesId,
            itemId: "plush_coconut_sleepy",
            rarity: .common,
            ownedCount: 2
        )
        let drawLog = GachaDrawLog(
            ownerHumanId: activeHuman.id.uuidString,
            ownerName: activeHuman.name,
            seriesId: GachaSeriesCatalog.defaultSeriesId,
            itemId: "plush_coconut_sleepy",
            rarity: .common,
            isNew: true,
            drawDate: makeDate(year: 2026, month: 6, day: 14)
        )
        let purchase = ShopPurchaseRecord(
            transactionKey: "shop:fx_lime_glow:\(activeHuman.id.uuidString)",
            itemId: "fx_lime_glow",
            buyerHumanId: activeHuman.id.uuidString,
            purchasedAt: makeDate(year: 2026, month: 6, day: 14)
        )
        context.insert(activeHuman)
        context.insert(remainingHuman)
        context.insert(ownedItem)
        context.insert(drawLog)
        context.insert(purchase)
        try context.save()
        let ownedItemId = ownedItem.id
        let drawLogId = drawLog.id
        let purchaseId = purchase.id

        _ = MemberDeletionCommandService.deleteHuman(
            activeHuman,
            activeHumanID: activeHuman.id.uuidString,
            context: context
        )

        #expect(try context.fetch(FetchDescriptor<GachaOwnedItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: GachaOwnedItem.self), id: ownedItemId, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: GachaDrawLog.self), id: drawLogId, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: ShopPurchaseRecord.self), id: purchaseId, context: context)?.isDeletionTombstone == true)
    }

    @MainActor
    @Test func memberDeletionServiceDeletesLastHumanAndRequestsReplacement() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let result = MemberDeletionCommandService.deleteHuman(
            human,
            activeHumanID: human.id.uuidString,
            context: context
        )

        let humans = try context.fetch(FetchDescriptor<Human>())
        #expect(result.clearsActiveHumanID == true)
        #expect(result.requiresAccountSwitch == false)
        #expect(result.requiresReplacementHuman == true)
        #expect(humans.isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: Human.self), id: human.id, context: context)?.isDeletionTombstone == true)
    }

    @MainActor
    @Test func memberDeletionServiceDeletesPlant() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let plant = Plant(name: "Fern")
        let plantID = plant.id
        let plantEvent = Event(
            title: "Water Fern",
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plantID.uuidString
        )
        let unrelatedEventID = UUID()
        let unrelatedEvent = Event(
            title: "Other event",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: unrelatedEventID.uuidString
        )
        context.insert(plant)
        context.insert(plantEvent)
        context.insert(unrelatedEvent)
        try context.save()

        let result = MemberDeletionCommandService.deletePlant(plant, context: context)

        let plants = try context.fetch(FetchDescriptor<Plant>())
        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(result.entityID == plantID)
        #expect(result.kind == EntityKind.plant.rawValue)
        #expect(result.removedRelatedEventIDs == [plantEvent.id])
        #expect(plants.isEmpty)
        #expect(events.map(\.id) == [unrelatedEvent.id])
        #expect(try cloudSyncState(entityName: String(describing: Plant.self), id: plantID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: plantEvent.id, context: context)?.isDeletionTombstone == true)
    }

    @MainActor
    @Test func revisionCenterPublishesMemberDeletionAffectedIDs() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let entityID = UUID()
        let relatedEventID = UUID()
        let result = MemberDeletionCommandResult(
            entityID: entityID,
            kind: EntityKind.pet.rawValue,
            removedRelatedEventIDs: [relatedEventID],
            removedQuickActionCount: 2,
            requiresReplacementHuman: false,
            requiresAccountSwitch: false,
            clearsActiveHumanID: false
        )
        let beforeRevision = revisionCenter.homeRevision.value
        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)

        revisions.publishMemberDeletion(result, note: "test.member.delete")

        let mutation = try #require(revisionCenter.lastMutation)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .memberDeletion(entityID: entityID, kind: EntityKind.pet.rawValue))
        #expect(mutation.affectedEntityIDs == [entityID, relatedEventID])
        #expect(mutation.wroteBusinessFact == true)
        #expect(mutation.note == "test.member.delete")
    }

    @MainActor
    @Test func revisionCenterPublishesPetCareDeleteAffectedIDs() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let petID = UUID()
        let careLogID = UUID()
        let linkedPottyLogID = UUID()
        let ledgerEventID = UUID()
        let result = PetCareTrackingDeleteCommandResult(
            petID: petID,
            careLogID: careLogID,
            linkedPottyLogID: linkedPottyLogID,
            removedLedgerEventIDs: [ledgerEventID],
            didDelete: true
        )
        let beforeRevision = revisionCenter.homeRevision.value
        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)

        revisions.publishPetCareDelete(result, note: "test.care.delete")

        let mutation = try #require(revisionCenter.lastMutation)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .petCareDelete(petID: petID, logID: careLogID))
        #expect(mutation.affectedEntityIDs == [petID, careLogID, linkedPottyLogID, ledgerEventID])
        #expect(mutation.wroteBusinessFact == true)
        #expect(mutation.note == "test.care.delete")
    }

    @MainActor
    @Test func memberProfileServiceUpdatesPlant() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let plant = Plant(name: "Old")
        plant.themeColorHex = "4CAF50"
        context.insert(plant)
        try context.save()

        let result = MemberProfileCommandService.updatePlant(
            plant,
            input: PlantProfileCommandInput(
                name: "  Fern  ",
                avatarImageData: nil,
                avatarEmoji: "  🪴  ",
                species: "  Boston fern  ",
                location: "  Living room  ",
                wateringIntervalDays: 6,
                fertilizingIntervalDays: 35,
                potDiameterCm: 14,
                potMaterialRaw: "  ceramic  ",
                soilTypeRaw: "  fern mix  ",
                isIndoor: true,
                windowDirection: .north,
                lightLevel: .low,
                healthStatus: .stressed,
                catalogSpeciesId: "epipremnum-aureum",
                isToxicToCats: true,
                isToxicToDogs: true,
                isToxicToChildren: false,
                isIndoorSuitable: false,
                remindersEnabled: false,
                themeHex: "27AE60",
                notes: "  bright corner  "
            ),
            context: context
        )

        #expect(result.entityID == plant.id)
        #expect(result.kind == EntityKind.plant.rawValue)
        #expect(result.changedFields.contains("name"))
        #expect(plant.name == "Fern")
        #expect(plant.avatarEmoji == "🪴")
        #expect(plant.species == "Boston fern")
        #expect(plant.location == "Living room")
        #expect(plant.wateringIntervalDays == 6)
        #expect(plant.fertilizingIntervalDays == 35)
        #expect(plant.potDiameterCm == 14)
        #expect(plant.potMaterialRaw == "ceramic")
        #expect(plant.soilTypeRaw == "fern mix")
        #expect(plant.windowDirection == .north)
        #expect(plant.lightLevel == .low)
        #expect(plant.healthStatus == .stressed)
        #expect(plant.catalogSpeciesId == "epipremnum-aureum")
        #expect(plant.isToxicToCats)
        #expect(plant.isToxicToDogs)
        #expect(!plant.isToxicToChildren)
        #expect(!plant.isIndoorSuitable)
        #expect(!plant.remindersEnabled)
        #expect(plant.themeColorHex == "27AE60")
        #expect(plant.notes == "bright corner")
    }

    @MainActor
    @Test func memberProfileServiceUpdatesPetExtendedProfileFields() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Old", species: "狗")
        pet.avatarEmoji = "🐕"
        pet.dailyPortionGrams = 80
        context.insert(pet)
        try context.save()

        let birthday = makeDate(year: 2023, month: 4, day: 8)
        let homeDate = makeDate(year: 2023, month: 5, day: 8)
        let passportExpiry = makeDate(year: 2027, month: 6, day: 8)
        let result = MemberProfileCommandService.updatePet(
            pet,
            input: PetProfileCommandInput(
                name: " Coco ",
                avatarImageData: nil,
                avatarEmoji: " ",
                species: "猫",
                breed: "  Siamese  ",
                gender: "female",
                isNeutered: true,
                birthday: birthday,
                homeDate: homeDate,
                themeHex: "ffcc00",
                notes: "  calm friend  ",
                coatColor: "  black  ",
                eyeColor: "  green  ",
                microchipID: "  chip-1  ",
                vetContact: "  vet phone  ",
                vetClinicName: "  Island Vet  ",
                vetDoctorName: "  Dr Chen  ",
                vetAddress: "  Coconut Road  ",
                allergies: "  dust  ",
                passportNumber: "  P-123  ",
                hasPassportExpiry: true,
                passportExpiryDate: passportExpiry,
                formerName: "  Little C  ",
                birthCountry: "  CN  ",
                birthCity: "  Shanghai  ",
                lineageInfo: "  rescue  ",
                foodBrand: "  Royal  ",
                dailyPortionGrams: -5
            ),
            context: context
        )

        #expect(result.entityID == pet.id)
        #expect(result.kind == EntityKind.pet.rawValue)
        #expect(result.changedFields.contains("microchipID"))
        #expect(result.changedFields.contains("dailyPortionGrams"))
        #expect(pet.name == "Coco")
        #expect(pet.avatarEmoji == "🐾")
        #expect(pet.species == "猫")
        #expect(pet.breed == "Siamese")
        #expect(pet.gender == "female")
        #expect(pet.isNeutered)
        #expect(pet.birthday == birthday)
        #expect(pet.homeDate == homeDate)
        #expect(pet.notes == "calm friend")
        #expect(pet.coatColor == "black")
        #expect(pet.eyeColor == "green")
        #expect(pet.microchipID == "chip-1")
        #expect(pet.vetContact == "vet phone")
        #expect(pet.vetClinicName == "Island Vet")
        #expect(pet.vetDoctorName == "Dr Chen")
        #expect(pet.vetAddress == "Coconut Road")
        #expect(pet.allergies == "dust")
        #expect(pet.passportNumber == "P-123")
        #expect(pet.passportExpiryDate == passportExpiry)
        #expect(pet.formerName == "Little C")
        #expect(pet.birthCountry == "CN")
        #expect(pet.birthCity == "Shanghai")
        #expect(pet.lineageInfo == "rescue")
        #expect(pet.foodBrand == "Royal")
        #expect(pet.dailyPortionGrams == 0)
    }

    @MainActor
    @Test func petWalkCommandExecutorSavesGoalSummaryAndPublishesRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let walk = PetWalkLog(startDate: makeDate(year: 2026, month: 6, day: 8), pet: pet)
        context.insert(pet)
        context.insert(walk)
        try context.save()

        let executor = PetWalkCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let goalResult = executor.saveWeeklyGoal(-2, for: pet, note: "test.walk.goal")
        let goalMutation = try #require(revisionCenter.lastMutation)

        #expect(goalResult.petID == pet.id)
        #expect(goalResult.goalKm == 0)
        #expect(pet.weeklyWalkGoalKm == 0)
        #expect(goalMutation.command == .petWalkGoal(petID: pet.id))
        #expect(goalMutation.affectedEntityIDs == [pet.id])
        #expect(goalMutation.note == "test.walk.goal")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)

        let summaryResult = executor.saveSummary(
            for: walk,
            pet: pet,
            moodRating: 7,
            notes: "  happy route  ",
            note: "test.walk.summary"
        )
        let summaryMutation = try #require(revisionCenter.lastMutation)

        #expect(summaryResult.petID == pet.id)
        #expect(summaryResult.walkID == walk.id)
        #expect(summaryResult.moodRating == 5)
        #expect(summaryResult.hasNotes)
        #expect(walk.moodRating == 5)
        #expect(walk.behaviorNotes == "happy route")
        #expect(summaryMutation.command == .petWalkSummary(petID: pet.id, walkID: walk.id))
        #expect(summaryMutation.affectedEntityIDs == [pet.id, walk.id])
        #expect(summaryMutation.note == "test.walk.summary")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 2)
    }

    @MainActor
    @Test func memberCommandExecutorPublishesProfileVisibilityAndLifecycle() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Old")
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let executor = MemberCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value

        let profile = executor.updateHumanProfile(
            human,
            input: HumanProfileCommandInput(
                name: " Alex ",
                avatarImageData: nil,
                avatarEmoji: "🧑",
                role: "owner",
                gender: "female",
                birthday: nil,
                bloodType: "O",
                heightText: "170",
                mbti: "intj",
                nationality: " CN ",
                city: " Berlin ",
                themeHex: "ffcc00",
                notes: " note ",
                preservedNoteParts: []
            ),
            note: "test.executor.profile"
        )
        let profileMutation = try #require(revisionCenter.lastMutation)
        #expect(profile.entityID == human.id)
        #expect(human.name == "Alex")
        #expect(profileMutation.command == .memberProfile(entityID: human.id, kind: EntityKind.human.rawValue))
        #expect(profileMutation.note == "test.executor.profile")

        let visibility = executor.setHumanHomeVisibility(
            human,
            visible: false,
            note: "test.executor.visibility"
        )
        let visibilityMutation = try #require(revisionCenter.lastMutation)
        #expect(visibility.entityID == human.id)
        #expect(!human.shouldShowOnHome)
        #expect(visibilityMutation.command == .memberHomeVisibility(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            visible: false
        ))
        #expect(visibilityMutation.note == "test.executor.visibility")

        let lifecycle = executor.markPetPassedAway(
            pet,
            date: makeDate(year: 2026, month: 6, day: 8),
            note: "test.executor.lifecycle"
        )
        let lifecycleMutation = try #require(revisionCenter.lastMutation)
        #expect(lifecycle.entityID == pet.id)
        #expect(pet.hasPassedAway)
        #expect(lifecycleMutation.command == .memberLifecycle(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.mark"
        ))
        #expect(lifecycleMutation.note == "test.executor.lifecycle")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func memberProfileServiceUpdatesHumanAndPreservesRelationNote() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Old")
        human.notes = "关系:爸爸｜性别:男｜old note"
        human.heightCm = 172
        human.shouldShowOnHome = true
        context.insert(human)
        try context.save()

        let birthday = makeDate(year: 1990, month: 5, day: 9)
        let result = MemberProfileCommandService.updateHuman(
            human,
            input: HumanProfileCommandInput(
                name: " Alex ",
                avatarImageData: nil,
                avatarEmoji: " ",
                role: "owner",
                gender: "female",
                birthday: birthday,
                bloodType: "A",
                heightText: "180",
                mbti: "infj",
                nationality: " CN ",
                city: " Berlin ",
                themeHex: "ffcc00",
                notes: " new note ",
                preservedNoteParts: human.notes
                    .split(separator: "｜")
                    .map(String.init)
                    .filter { $0.hasPrefix("关系:") },
                shouldShowOnHome: false,
                privateFieldsRaw: [
                    HumanPrivateField.weight.rawValue,
                    HumanPrivateField.note.rawValue
                ]
            ),
            context: context
        )

        #expect(result.entityID == human.id)
        #expect(result.kind == EntityKind.human.rawValue)
        #expect(human.name == "Alex")
        #expect(human.avatarEmoji == "👤")
        #expect(human.role == "owner")
        #expect(human.birthday == birthday)
        #expect(human.bloodType == "A")
        #expect(human.heightCm == 180)
        #expect(human.mbti == "INFJ")
        #expect(human.nationality == "CN")
        #expect(human.city == "Berlin")
        #expect(human.genderRaw == "女")
        #expect(human.notes == "关系:爸爸｜new note")
        #expect(!human.notes.contains("性别:"))
        #expect(human.shouldShowOnHome == false)
        #expect(human.privateFields.contains(HumanPrivateField.weight.rawValue))
        #expect(human.privateFields.contains(HumanPrivateField.note.rawValue))
        #expect(!human.privateFields.contains(HumanPrivateField.medication.rawValue))
    }

    @MainActor
    @Test func memberCommandsNoOpForPassedAwayProfileVisibilityAndRecordClear() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Old")
        human.shouldShowOnHome = true
        human.passedAwayDate = makeDate(year: 2026, month: 6, day: 1)
        let pet = Pet(name: "Momo", species: "狗")
        pet.passedAwayDate = makeDate(year: 2026, month: 6, day: 1)
        let careLog = PetCareLog(
            date: makeDate(year: 2026, month: 6, day: 8),
            type: .feeding,
            pet: pet
        )
        context.insert(human)
        context.insert(pet)
        context.insert(careLog)
        try context.save()

        let executor = MemberCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let humanProfile = executor.updateHumanProfile(
            human,
            input: HumanProfileCommandInput(
                name: "New",
                avatarImageData: nil,
                avatarEmoji: "🧑",
                role: "owner",
                gender: "female",
                birthday: nil,
                bloodType: "A",
                heightText: "180",
                mbti: "infj",
                nationality: "CN",
                city: "Berlin",
                themeHex: "ffcc00",
                notes: "new note",
                preservedNoteParts: [],
                shouldShowOnHome: false
            ),
            note: "test.member.noop.human"
        )
        let petProfile = executor.updatePetProfile(
            pet,
            input: PetProfileCommandInput(
                name: "New Momo",
                avatarImageData: nil,
                avatarEmoji: "🐕",
                species: "狗",
                breed: "Shiba",
                gender: "female",
                isNeutered: true,
                birthday: nil,
                homeDate: nil,
                themeHex: "ffcc00",
                notes: "new note"
            ),
            note: "test.member.noop.pet"
        )
        let visibility = executor.setHumanHomeVisibility(
            human,
            visible: false,
            note: "test.member.noop.visibility"
        )
        let clearResult = executor.clearPetActivityRecords(
            pet,
            note: "test.member.noop.clear"
        )

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(!humanProfile.didWrite)
        #expect(!petProfile.didWrite)
        #expect(!visibility.didWrite)
        #expect(!clearResult.didWrite)
        #expect(human.name == "Old")
        #expect(human.shouldShowOnHome)
        #expect(pet.name == "Momo")
        #expect(careLogs.map(\.id) == [careLog.id])
        #expect(revisionCenter.homeRevision.value == beforeRevision)
    }

    @MainActor
    @Test func memberHomeVisibilityServiceUpdatesHumanVisibility() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.shouldShowOnHome = true
        context.insert(human)
        try context.save()

        let result = MemberHomeVisibilityCommandService.setHumanHomeVisibility(
            human,
            visible: false,
            context: context
        )

        #expect(result.entityID == human.id)
        #expect(result.kind == EntityKind.human.rawValue)
        #expect(result.visible == false)
        #expect(result.didWrite)
        #expect(human.shouldShowOnHome == false)
    }

    @MainActor
    @Test func memberLifecycleServiceMarksHumanAndClearsPetRecords() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "狗")
        let careLog = PetCareLog(
            date: makeDate(year: 2026, month: 6, day: 8),
            type: .feeding,
            pet: pet
        )
        let event = Event(
            title: "Momo care",
            startDate: makeDate(year: 2026, month: 6, day: 9),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(human)
        context.insert(pet)
        context.insert(careLog)
        context.insert(event)
        try context.save()

        let passedDate = makeDate(year: 2026, month: 6, day: 8)
        let humanResult = MemberLifecycleCommandService.markHumanPassedAway(
            human,
            date: passedDate,
            context: context
        )
        let clearResult = MemberLifecycleCommandService.clearPetActivityRecords(pet, context: context)

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(humanResult.entityID == human.id)
        #expect(humanResult.action == "passed.mark")
        #expect(human.passedAwayDate == passedDate)
        #expect(clearResult.entityID == pet.id)
        #expect(clearResult.action == "records.clear")
        #expect(careLogs.isEmpty)
        #expect(events.isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: PetCareLog.self), id: careLog.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: event.id, context: context)?.isDeletionTombstone == true)
    }

    @MainActor
    @Test func settingsCommandServiceSyncsHomeStackAfterActiveHumanSwitch() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let oldHuman = Human(name: "Old")
        let newHuman = Human(name: "New")
        oldHuman.shouldShowOnHome = true
        newHuman.shouldShowOnHome = false
        context.insert(oldHuman)
        context.insert(newHuman)
        try context.save()

        let result = SettingsCommandService.syncHomeCardStackAfterActiveHumanSwitch(
            from: oldHuman.id.uuidString,
            to: newHuman,
            pets: [],
            humans: [oldHuman, newHuman],
            electronicPets: [],
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: oldHuman.id.uuidString,
            context: context
        )

        #expect(result.humanID == newHuman.id)
        #expect(result.didSyncHomeStack == true)
        #expect(newHuman.shouldShowOnHome == true)
        #expect(result.updatedHomeCardOrderRaw.contains(newHuman.id.uuidString))
    }

    @MainActor
    @Test func settingsCommandExecutorPublishesActiveHumanSwitchRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let oldHuman = Human(name: "Old")
        let newHuman = Human(name: "New")
        oldHuman.shouldShowOnHome = true
        newHuman.shouldShowOnHome = false
        context.insert(oldHuman)
        context.insert(newHuman)
        try context.save()
        let beforeRevision = revisionCenter.homeRevision.value

        let result = SettingsCommandExecutor(context: context, revisionCenter: revisionCenter).syncHomeCardStackAfterActiveHumanSwitch(
            from: oldHuman.id.uuidString,
            to: newHuman,
            pets: [],
            humans: [oldHuman, newHuman],
            electronicPets: [],
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: oldHuman.id.uuidString,
            note: "test.settings.activeHuman"
        )
        let mutation = try #require(revisionCenter.lastMutation)

        #expect(result.humanID == newHuman.id)
        #expect(mutation.command == .settingsActiveHumanSwitch(humanID: newHuman.id))
        #expect(mutation.affectedEntityIDs == [newHuman.id])
        #expect(mutation.wroteBusinessFact == result.didSyncHomeStack)
        #expect(mutation.note == "test.settings.activeHuman")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
    }

    @MainActor
    @Test func settingsCommandServiceAppliesCoconutBalanceTest() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 40
        let questManager = TestQuestManagerProjection.manager
        let wallet = SwiftDataCoconutWalletManager()
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 40
        questManager.coconutLogs = []
        context.insert(human)
        try context.save()
        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            legacyIslandCount: 40,
            legacyLogsJSON: "[]",
            projectionManager: questManager
        )
        let ledgerEntriesBefore = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let coconutLogsBefore = questManager.coconutLogs

        let result = SettingsCommandService.applyCoconutBalanceTest(
            amount: 120,
            human: human,
            title: "Test coconut balance adjustment",
            actorName: human.name,
            context: context,
            wallet: wallet,
            projectionManager: questManager
        )
        let accountKey = CoconutAccountKey.human(human.id)
        let accountDescriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == accountKey }
        )
        let account = try #require(context.fetch(accountDescriptor).first)
        let ledgerEntriesAfter = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())

        #expect(result.humanID == human.id)
        #expect(result.amount == 120)
        #expect(result.legacyDelta == 80)
        #expect(human.coconutBalance == 120)
        #expect(account.balance == 120)
        #expect(questManager.coconutCount == 120)
        #expect(questManager.coconutLogs.map(\.id) == coconutLogsBefore.map(\.id))
        #expect(ledgerEntriesAfter.count == ledgerEntriesBefore.count)
    }

    @MainActor
    @Test func settingsCommandExecutorPublishesCoconutBalanceRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 40
        questManager.coconutLogs = []
        context.insert(human)
        try context.save()
        let beforeRevision = revisionCenter.homeRevision.value

        let result = SettingsCommandExecutor(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager
        ).applyCoconutBalanceTest(
            amount: 120,
            human: human,
            title: "Test coconut balance adjustment",
            actorName: human.name,
            note: "test.settings.coconut"
        )
        let mutation = try #require(revisionCenter.lastMutation)

        #expect(result.humanID == human.id)
        #expect(mutation.command == .settingsCoconutBalance(humanID: human.id, amount: 120))
        #expect(mutation.affectedEntityIDs == [human.id])
        #expect(mutation.wroteBusinessFact == false)
        #expect(mutation.note == "test.settings.coconut")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
    }

    @MainActor
    @Test func humanPrivacyCommandServiceManagesPasscodeLifecycle() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let setResult = try HumanPrivacyCommandService.setPasscode("1234", for: human, context: context)
        #expect(setResult.humanID == human.id)
        #expect(setResult.action == "passcode.set")
        #expect(HumanPasscodeService.hasPasscode(human))
        #expect(human.pinHash != "1234")
        #expect(!human.pinSalt.isEmpty)

        let wrongChange = try HumanPrivacyCommandService.changePasscode(
            currentPin: "0000",
            newPin: "5678",
            for: human,
            now: makeDate(year: 2026, month: 6, day: 8),
            context: context
        )
        guard case let .incorrect(remaining) = wrongChange else {
            Issue.record("Expected incorrect current PIN")
            return
        }
        #expect(remaining == HumanPasscodeService.maxFailedAttempts - 1)
        #expect(human.pinFailedAttempts == 1)

        let changed = try HumanPrivacyCommandService.changePasscode(
            currentPin: "1234",
            newPin: "5678",
            for: human,
            now: makeDate(year: 2026, month: 6, day: 8, hour: 1, minute: 0),
            context: context
        )
        #expect(changed == .success)
        #expect(human.pinFailedAttempts == 0)
        #expect(HumanPrivacyCommandService.verifyPasscode(
            "5678",
            for: human,
            now: makeDate(year: 2026, month: 6, day: 8, hour: 2, minute: 0),
            context: context
        ) == .success)

        let removed = try HumanPrivacyCommandService.removePasscode(
            currentPin: "5678",
            for: human,
            now: makeDate(year: 2026, month: 6, day: 8, hour: 3, minute: 0),
            context: context
        )
        #expect(removed == .success)
        #expect(!HumanPasscodeService.hasPasscode(human))
        #expect(human.pinFailedAttempts == 0)
        #expect(human.pinLockedUntil == nil)
    }

    @MainActor
    @Test func humanPrivacyCommandExecutorPublishesPasscodeLifecycleRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let executor = HumanPrivacyCommandExecutor(context: context, revisionCenter: revisionCenter)
        let setResult = try executor.setPasscode("1234", for: human, note: "test.privacy.passcode.set")
        var mutation = try #require(revisionCenter.lastMutation)
        #expect(setResult.action == "passcode.set")
        #expect(mutation.command == .humanPrivacy(humanID: human.id, action: "passcode.set"))
        #expect(mutation.note == "test.privacy.passcode.set")

        let changeResult = try executor.changePasscode(
            currentPin: "1234",
            newPin: "5678",
            for: human,
            now: makeDate(year: 2026, month: 6, day: 8),
            note: "test.privacy.passcode.change"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(changeResult == .success)
        #expect(mutation.command == .humanPrivacy(humanID: human.id, action: "passcode.change"))
        #expect(mutation.note == "test.privacy.passcode.change")

        let removeResult = try executor.removePasscode(
            currentPin: "5678",
            for: human,
            now: makeDate(year: 2026, month: 6, day: 8, hour: 1, minute: 0),
            note: "test.privacy.passcode.remove"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(removeResult == .success)
        #expect(mutation.command == .humanPrivacy(humanID: human.id, action: "passcode.remove"))
        #expect(mutation.note == "test.privacy.passcode.remove")
        #expect(!HumanPasscodeService.hasPasscode(human))
    }

    @MainActor
    @Test func humanPrivacyCommandServicePersistsPasscodeLockout() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()
        try HumanPrivacyCommandService.setPasscode("1234", for: human, context: context)
        let now = makeDate(year: 2026, month: 6, day: 8)

        for _ in 0 ..< (HumanPasscodeService.maxFailedAttempts - 1) {
            _ = HumanPrivacyCommandService.verifyPasscode("0000", for: human, now: now, context: context)
        }
        let locked = HumanPrivacyCommandService.verifyPasscode("0000", for: human, now: now, context: context)

        guard case let .locked(until) = locked else {
            Issue.record("Expected lockout")
            return
        }
        #expect(human.pinFailedAttempts == HumanPasscodeService.maxFailedAttempts)
        #expect(human.pinLockedUntil == until)
        let fetched = try #require(try context.fetch(FetchDescriptor<Human>()).first)
        #expect(fetched.pinLockedUntil == until)
    }

    @MainActor
    @Test func humanPrivacyCommandServiceTogglesPrivateFields() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let single = HumanPrivacyCommandService.setPrivateField(.weight, isPrivate: true, for: human, context: context)
        #expect(single.humanID == human.id)
        #expect(single.action == "privacy.field")
        #expect(single.changedFields == Set([HumanPrivateField.weight.rawValue]))
        #expect(human.privateFields == Set([HumanPrivateField.weight.rawValue]))

        let allPrivate = HumanPrivacyCommandService.setAllPrivateFields(isPrivate: true, for: human, context: context)
        #expect(allPrivate.action == "privacy.allPrivate")
        #expect(human.privateFields == Set(HumanPrivateField.allCases.map(\.rawValue)))

        let allPublic = HumanPrivacyCommandService.setAllPrivateFields(isPrivate: false, for: human, context: context)
        #expect(allPublic.action == "privacy.allPublic")
        #expect(human.privateFields.isEmpty)
    }

    @MainActor
    @Test func humanPrivacyCommandExecutorPublishesPrivateFieldRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let executor = HumanPrivacyCommandExecutor(context: context, revisionCenter: revisionCenter)
        let single = executor.setPrivateField(
            .weight,
            isPrivate: true,
            for: human,
            note: "test.privacy.field"
        )
        var mutation = try #require(revisionCenter.lastMutation)
        #expect(single.action == "privacy.field")
        #expect(mutation.command == .humanPrivacy(humanID: human.id, action: "privacy.field"))
        #expect(mutation.affectedEntityIDs == [human.id])
        #expect(mutation.note == "test.privacy.field")

        let allPublic = executor.setAllPrivateFields(
            isPrivate: false,
            for: human,
            note: "test.privacy.allPublic"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(allPublic.action == "privacy.allPublic")
        #expect(mutation.command == .humanPrivacy(humanID: human.id, action: "privacy.allPublic"))
        #expect(mutation.note == "test.privacy.allPublic")
        #expect(human.privateFields.isEmpty)
    }

    @MainActor
    @Test func plantCareByIdWritesOnePlantFactAndDerivedRecords() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let plant = Plant(name: "Fern")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(plant)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)

        executor.recordPlantCare(.watering, plantID: plant.id, executorId: executorHuman.id.uuidString)

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let factEvents = events.filter { !$0.isAllDay }
        let planEvents = events.filter { $0.isAllDay && $0.title.contains("植物计划") }
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.plant?.id == plant.id)
        #expect(logs.first?.careType == .watering)
        #expect(logs.first?.executorId == executorHuman.id.uuidString)
        #expect(plant.lastWateredDate != nil)
        #expect(factEvents.count == 1)
        #expect(factEvents.first?.relatedEntityType == EntityKind.plant.rawValue)
        #expect(factEvents.first?.relatedEntityId == plant.id.uuidString)
        #expect(factEvents.first?.assigneeId == executorHuman.id.uuidString)
        #expect(planEvents.contains { $0.eventType == EventType.watering.rawValue && $0.recurrenceDays > 0 })
        #expect(planEvents.contains { $0.eventType == EventType.plantPestCheck.rawValue && $0.recurrenceDays > 0 })
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.plantCare.rawValue)
        #expect(ledgerEvents.first?.legacyModelName == "PlantCareLog")
    }

    @MainActor
    @Test func plantCareBatchByIdsWritesFactsForEachPlant() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let livingRoomFern = Plant(name: "Fern")
        let livingRoomPothos = Plant(name: "Pothos")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(livingRoomFern)
        context.insert(livingRoomPothos)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)

        let recordedIDs = executor.recordPlantCare(
            .watering,
            plantIDs: [livingRoomFern.id, livingRoomPothos.id],
            executorId: executorHuman.id.uuidString
        )

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let factEvents = events.filter { !$0.isAllDay }
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let expectedPlantIDs = Set([livingRoomFern.id, livingRoomPothos.id])
        #expect(Set(recordedIDs) == expectedPlantIDs)
        #expect(Set(logs.compactMap { $0.plant?.id }) == expectedPlantIDs)
        #expect(logs.allSatisfy { $0.careType == .watering })
        #expect(logs.allSatisfy { $0.executorId == executorHuman.id.uuidString })
        #expect(livingRoomFern.lastWateredDate != nil)
        #expect(livingRoomPothos.lastWateredDate != nil)
        #expect(Set(factEvents.compactMap { UUID(uuidString: $0.relatedEntityId) }) == expectedPlantIDs)
        #expect(factEvents.allSatisfy { $0.relatedEntityType == EntityKind.plant.rawValue })
        #expect(ledgerEvents.count(where: { $0.eventKind == CareLedgerEventKind.plantCare.rawValue }) == 2)
    }

    @MainActor
    @Test func plantDueTaskDeferralUsesReminderControlBoundaryFromHome() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let now = makeDate(year: 2026, month: 6, day: 19, hour: 9, minute: 0)
        let plant = Plant(name: "Mint", wateringIntervalDays: 1, fertilizingIntervalDays: 90)
        plant.createdAt = Calendar.current.date(byAdding: .day, value: -5, to: now) ?? now
        plant.lastWateredDate = Calendar.current.date(byAdding: .day, value: -2, to: now)
        plant.lastFertilizedDate = now
        plant.lastHealthCheckDate = now
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(plant)
        try context.save()

        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)
        let executor = HomeCommandExecutor(
            modelContext: context,
            careEvents: CareEventService(),
            coconutExchange: StaticCoconutExchangeManager(),
            revisions: revisions,
            questManager: QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: revisions),
            medicationReminders: SharedMedicationReminderManager(),
            todayFocus: StaticTodayFocusManager()
        )
        let beforeRevision = revisionCenter.homeRevision.value

        let result = executor.deferPlantDueTasksOneDay(
            plants: [plant],
            executorId: executorHuman.id.uuidString,
            now: now
        )

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let wateringTask = try #require(PlantCarePlanService.tasks(for: plant, now: now).first { $0.careType == .watering })
        let mutation = try #require(revisionCenter.lastMutation)
        #expect(result.deferredTaskCount == 1)
        #expect(result.affectedPlantCount == 1)
        #expect(wateringTask.daysUntilDue == 1)
        #expect(logs.count == 1)
        #expect(logs.first?.careType == .customNote)
        #expect(logs.first?.note.hasPrefix("defer:watering:") == true)
        #expect(logs.first?.executorId == executorHuman.id.uuidString)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .command("plants", "deferDueTasksOneDay", ["plantCount": "1"]))
        #expect(mutation.affectedEntityIDs == [plant.id])
        #expect(mutation.wroteBusinessFact)
        #expect(mutation.note == "home.plantCare.deferDueTasks")
    }

    @MainActor
    @Test func plantFertilizingByIdWritesOnePlantFactAndDerivedRecords() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let plant = Plant(name: "Fern")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(plant)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)

        executor.recordPlantCare(.fertilizing, plantID: plant.id, executorId: executorHuman.id.uuidString)

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let factEvents = events.filter { !$0.isAllDay }
        let planEvents = events.filter { $0.isAllDay && $0.title.contains("植物计划") }
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.plant?.id == plant.id)
        #expect(logs.first?.careType == .fertilizing)
        #expect(logs.first?.executorId == executorHuman.id.uuidString)
        #expect(plant.lastFertilizedDate != nil)
        #expect(factEvents.count == 1)
        #expect(factEvents.first?.eventType == EventType.fertilizing.rawValue)
        #expect(factEvents.first?.relatedEntityId == plant.id.uuidString)
        #expect(planEvents.contains { $0.eventType == EventType.fertilizing.rawValue && $0.recurrenceDays > 0 })
        #expect(planEvents.contains { $0.eventType == EventType.plantLeafCleaning.rawValue && $0.recurrenceDays > 0 })
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.plantCare.rawValue)
        #expect(ledgerEvents.first?.actionType == PlantCareType.fertilizing.rawValue)
    }

    @MainActor
    @Test func quickMomentServiceWritesPhotoFactAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let result = MomentCommandService.recordMoment(
            pet: pet,
            note: "park day",
            photoData: [Data([1, 2, 3])],
            locationLatitude: 52.52,
            locationLongitude: 13.40,
            locationPlacename: "Berlin",
            context: context,
            executorId: "human-1",
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let logs = try context.fetch(FetchDescriptor<PetPhotoLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result.savedLogIDs.count == 1)
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.note == "park day")
        #expect(logs.first?.locationPlacename == "Berlin")
        #expect(result.coconutDelta == 0)
        #expect(ledgerEvents.isEmpty)
    }

    @MainActor
    @Test func momentCommandExecutorPublishesQuickMomentRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()
        let beforeRevision = revisionCenter.homeRevision.value

        let result = MomentCommandExecutor(context: context, revisionCenter: revisionCenter).recordMoment(
            pet: pet,
            note: "park day",
            photoData: [Data([1, 2, 3])],
            locationLatitude: 52.52,
            locationLongitude: 13.40,
            locationPlacename: "Berlin",
            executorId: executorHuman.id.uuidString,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            revisionNote: "test.quickMoment"
        )
        let mutation = try #require(revisionCenter.lastMutation)

        let logID = try #require(result.savedLogIDs.first)
        #expect(mutation.command == .quickMoment(petID: pet.id))
        #expect(mutation.affectedEntityIDs == [pet.id, logID])
        #expect(mutation.wroteBusinessFact)
        #expect(mutation.note == "test.quickMoment")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
    }

    @MainActor
    @Test func petPhotoAlbumCommandServiceCreatesUpdatesAndDeletesPhotos() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let createResult = PetPhotoAlbumCommandService.createPhotos(
            data: [Data([1, 2, 3]), Data([4, 5, 6])],
            pet: pet,
            context: context,
            date: makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 0)
        )

        var logs = try context.fetch(FetchDescriptor<PetPhotoLog>())
        #expect(createResult.petID == pet.id)
        #expect(createResult.photoIDs.count == 2)
        #expect(logs.count == 2)
        #expect(Set(logs.map(\.id)) == Set(createResult.photoIDs))
        #expect(logs.allSatisfy { $0.pet?.id == pet.id })

        let photo = try #require(logs.first)
        let updateResult = PetPhotoAlbumCommandService.updateNote(
            "  beach day  ",
            photo: photo,
            pet: pet,
            context: context
        )
        #expect(updateResult.petID == pet.id)
        #expect(updateResult.photoID == photo.id)
        #expect(updateResult.didChange == true)
        #expect(photo.note == "beach day")

        let deleteResult = PetPhotoAlbumCommandService.deletePhoto(photo, pet: pet, context: context)

        logs = try context.fetch(FetchDescriptor<PetPhotoLog>())
        #expect(deleteResult.petID == pet.id)
        #expect(deleteResult.photoID == photo.id)
        #expect(logs.count == 1)
        #expect(!logs.contains { $0.id == photo.id })
        #expect(try cloudSyncState(entityName: String(describing: PetPhotoLog.self), id: photo.id, context: context)?.isDeletionTombstone == true)
    }

    @MainActor
    @Test func petPhotoAlbumCommandExecutorPublishesCreateUpdateAndDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let executor = PetPhotoAlbumCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let created = executor.createPhotos(
            data: [Data([1, 2, 3])],
            pet: pet,
            date: makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 0),
            note: "test.photo.create"
        )
        let createMutation = try #require(revisionCenter.lastMutation)
        let photo = try #require(try context.fetch(FetchDescriptor<PetPhotoLog>()).first)
        #expect(created.photoIDs == [photo.id])
        #expect(createMutation.command == .petPhotoCreate(petID: pet.id))
        #expect(createMutation.affectedEntityIDs == [pet.id, photo.id])
        #expect(createMutation.note == "test.photo.create")

        let updated = executor.updateNote("  beach day  ", photo: photo, pet: pet, note: "test.photo.update")
        let updateMutation = try #require(revisionCenter.lastMutation)
        #expect(updated.didChange == true)
        #expect(photo.note == "beach day")
        #expect(updateMutation.command == .petPhotoUpdate(petID: pet.id, photoID: photo.id))
        #expect(updateMutation.note == "test.photo.update")

        let deleted = executor.deletePhoto(photo, pet: pet, note: "test.photo.delete")
        let deleteMutation = try #require(revisionCenter.lastMutation)
        #expect(deleted.photoID == photo.id)
        let photos = try context.fetch(FetchDescriptor<PetPhotoLog>())
        #expect(photos.isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: PetPhotoLog.self), id: photo.id, context: context)?.isDeletionTombstone == true)
        #expect(deleteMutation.command == .petPhotoDelete(petID: pet.id, photoID: photo.id))
        #expect(deleteMutation.note == "test.photo.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func quickWeightServiceWritesOnePetWeightFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = WeightCommandService.recordPetWeight(
            pet: pet,
            weight: 8.4,
            date: date,
            context: context,
            executorId: executorHuman.id.uuidString
        )

        let logs = try context.fetch(FetchDescriptor<PetWeightLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.weight == 8.4)
        #expect(logs.first?.date == date)
        #expect(logs.first?.executorId == executorHuman.id.uuidString)
        #expect(result.coconutDelta == 0)
    }

    @MainActor
    @Test func petWeightServiceCanWriteDetailLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = WeightCommandService.recordPetWeight(
            pet: pet,
            weight: 8.4,
            date: date,
            context: context,
            executorId: executorHuman.id.uuidString,
            ledgerSource: .detail
        )

        let logs = try context.fetch(FetchDescriptor<PetWeightLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.id == result.ledgerEventID)
        #expect(ledgerEvents.first?.actorKind == CareLedgerActorKind.human.rawValue)
        #expect(ledgerEvents.first?.actorId == executorHuman.id.uuidString)
        #expect(ledgerEvents.first?.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(ledgerEvents.first?.subjectId == pet.id.uuidString)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.weight.rawValue)
        #expect(ledgerEvents.first?.actionType == "petWeight")
        #expect(ledgerEvents.first?.amountValue == 8.4)
        #expect(ledgerEvents.first?.amountUnit == "kg")
        #expect(ledgerEvents.first?.source == CareLedgerSource.detail.rawValue)
        #expect(ledgerEvents.first?.legacyModelName == "PetWeightLog")
        #expect(ledgerEvents.first?.legacyModelId == result.logID.uuidString)
    }

    @MainActor
    @Test func weightServiceWritesOneHumanWeightFactAndReward() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let previousActiveHumanID = UserDefaults.standard.string(forKey: "currentActiveHumanId")
        let previousCooldownLogs = UserDefaults.standard.object(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            if let previousActiveHumanID {
                UserDefaults.standard.set(previousActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")
            }
            if let previousCooldownLogs {
                UserDefaults.standard.set(previousCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
            EconomyDailyBudgetStore.resetAll()
        }
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.resetAll()
        let questManager = QuestManager()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = WeightCommandService.recordHumanWeight(
            human: human,
            weight: 62.5,
            date: date,
            context: context,
            executorId: human.id.uuidString,
            questManager: questManager
        )

        let logs = try context.fetch(FetchDescriptor<HumanWeightLog>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.human?.id == human.id)
        #expect(logs.first?.weight == 62.5)
        #expect(logs.first?.date == date)
        #expect(logs.first?.executorId == human.id.uuidString)
        #expect(result.subjectID == human.id)
        #expect(result.coconutDelta >= 4)
        #expect(human.coconutBalance == result.coconutDelta)
        #expect(questManager.coconutCount == result.coconutDelta)
        #expect(walletEntries.count == 1)
        #expect(walletEntries.first?.ownerKind == .human)
        #expect(walletEntries.first?.ownerId == human.id.uuidString)
        #expect(walletEntries.first?.subjectKindRaw == CareLedgerSubjectKind.human.rawValue)
        #expect(walletEntries.first?.subjectId == human.id.uuidString)
        #expect(walletEntries.first?.entryKind == .reward)
        #expect(walletEntries.first?.source == .careEvent)
        #expect(walletEntries.first?.delta == result.coconutDelta)
    }

    @MainActor
    @Test func quickHumanExpenseServiceWritesExpenseFactAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let previousActiveHumanID = UserDefaults.standard.string(forKey: "currentActiveHumanId")
        let previousCoconutCount = TestQuestManagerProjection.manager.coconutCount
        let previousLogs = TestQuestManagerProjection.manager.coconutLogs
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        TestQuestManagerProjection.manager.coconutCount = 0
        TestQuestManagerProjection.manager.coconutLogs = []
        defer {
            if let previousActiveHumanID {
                UserDefaults.standard.set(previousActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")
            }
            TestQuestManagerProjection.manager.coconutCount = previousCoconutCount
            TestQuestManagerProjection.manager.coconutLogs = previousLogs
        }

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = ExpenseCommandService.recordHumanExpense(
            human: human,
            amount: 12.5,
            date: date,
            note: "coffee",
            context: context,
            category: .medical,
            source: .detail
        )

        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(expenses.count == 1)
        #expect(expenses.first?.id == result.logID)
        #expect(expenses.first?.pet == nil)
        #expect(expenses.first?.executorId == human.id.uuidString)
        #expect(expenses.first?.amount == 12.5)
        #expect(expenses.first?.expenseCategory == .medical)
        #expect(expenses.first?.note == "coffee")
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.subjectKind == CareLedgerSubjectKind.human.rawValue)
        #expect(ledgerEvents.first?.subjectId == human.id.uuidString)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.expense.rawValue)
        #expect(ledgerEvents.first?.actionType == ExpenseCategory.medical.rawValue)
        #expect(ledgerEvents.first?.source == CareLedgerSource.detail.rawValue)
        #expect(ledgerEvents.first?.legacyModelName == "PetExpenseLog")
        #expect(ledgerEvents.first?.legacyModelId == result.logID.uuidString)
        #expect(ledgerEvents.first?.privacyFieldRaw == HumanPrivateField.expense.rawValue)
        #expect(ledgerEvents.first?.coconutDelta == result.coconutDelta)
        #expect(ledgerEvents.first?.id == result.ledgerEventID)
        #expect(result.coconutDelta >= 0)
    }

    @MainActor
    @Test func petExpenseServiceWritesExpenseFactAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let previousActiveHumanID = UserDefaults.standard.string(forKey: "currentActiveHumanId")
        let previousCoconutCount = TestQuestManagerProjection.manager.coconutCount
        let previousLogs = TestQuestManagerProjection.manager.coconutLogs
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        TestQuestManagerProjection.manager.coconutCount = 0
        TestQuestManagerProjection.manager.coconutLogs = []
        defer {
            if let previousActiveHumanID {
                UserDefaults.standard.set(previousActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")
            }
            TestQuestManagerProjection.manager.coconutCount = previousCoconutCount
            TestQuestManagerProjection.manager.coconutLogs = previousLogs
        }

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 36.8,
            date: date,
            category: .medical,
            note: "  clinic  ",
            context: context,
            executorId: human.id.uuidString,
            source: .detail
        )

        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(expenses.count == 1)
        #expect(expenses.first?.id == result.logID)
        #expect(expenses.first?.pet?.id == pet.id)
        #expect(expenses.first?.executorId == human.id.uuidString)
        #expect(expenses.first?.amount == 36.8)
        #expect(expenses.first?.expenseCategory == .medical)
        #expect(expenses.first?.note == "clinic")
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.actorKind == CareLedgerActorKind.human.rawValue)
        #expect(ledgerEvents.first?.actorId == human.id.uuidString)
        #expect(ledgerEvents.first?.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(ledgerEvents.first?.subjectId == pet.id.uuidString)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.expense.rawValue)
        #expect(ledgerEvents.first?.source == CareLedgerSource.detail.rawValue)
        #expect(ledgerEvents.first?.legacyModelName == "PetExpenseLog")
        #expect(ledgerEvents.first?.legacyModelId == result.logID.uuidString)
        #expect(ledgerEvents.first?.coconutDelta == result.coconutDelta)
        #expect(ledgerEvents.first?.id == result.ledgerEventID)
        #expect(result.subjectID == pet.id)
        #expect(result.coconutDelta >= 0)
    }

    @MainActor
    @Test func petExpenseServiceCreatesReceiptDocumentAndAttachments() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let previousActiveHumanID = UserDefaults.standard.string(forKey: "currentActiveHumanId")
        let previousCoconutCount = TestQuestManagerProjection.manager.coconutCount
        let previousLogs = TestQuestManagerProjection.manager.coconutLogs
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        TestQuestManagerProjection.manager.coconutCount = 0
        TestQuestManagerProjection.manager.coconutLogs = []
        defer {
            if let previousActiveHumanID {
                UserDefaults.standard.set(previousActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")
            }
            TestQuestManagerProjection.manager.coconutCount = previousCoconutCount
            TestQuestManagerProjection.manager.coconutLogs = previousLogs
        }

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 88.8,
            date: date,
            category: .medical,
            note: "  x-ray  ",
            context: context,
            executorId: human.id.uuidString,
            source: .detail,
            receiptTitle: "  Clinic receipt  ",
            receiptCategory: .medical,
            receiptAttachments: [
                ExpenseReceiptAttachmentDraft(
                    data: Data([1, 2, 3]),
                    filename: " receipt.jpg ",
                    isImage: true
                ),
                ExpenseReceiptAttachmentDraft(
                    data: Data([4, 5, 6]),
                    filename: "",
                    isImage: false
                )
            ]
        )

        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let documents = try context.fetch(FetchDescriptor<PetDocument>())
        let attachments = try context.fetch(FetchDescriptor<PetDocumentAttachment>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let document = try #require(documents.first)
        #expect(expenses.count == 1)
        #expect(expenses.first?.id == result.logID)
        #expect(documents.count == 1)
        #expect(document.id == result.documentID)
        #expect(document.pet?.id == pet.id)
        #expect(document.title == "Clinic receipt")
        #expect(document.documentCategory == .medical)
        #expect(document.issueDate == date)
        #expect(document.cost == 88.8)
        #expect(document.notes == "x-ray｜关联花费:\(result.logID.uuidString)")
        #expect(ExpenseReceiptMetadata.expenseLogId(from: document.notes) == result.logID.uuidString)
        #expect(ExpenseReceiptMetadata.visibleNotes(from: document.notes) == "x-ray")
        #expect(document.attachmentFilename == "receipt.jpg")
        #expect(document.attachmentData == Data([1, 2, 3]))
        #expect(document.attachments.count == 2)
        #expect(attachments.count == 2)
        #expect(attachments.map(\.filename).sorted() == ["receipt.jpg", "receipt_2"])
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.id == result.ledgerEventID)
        #expect(result.documentID != nil)
    }

    @MainActor
    @Test func quickHumanWorkoutServiceWritesWorkoutFactAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .running,
            durationMinutes: 42,
            date: date,
            context: context
        )

        let logs = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.human?.id == human.id)
        #expect(logs.first?.workoutType == .running)
        #expect(logs.first?.durationMinutes == 42)
        #expect(logs.first?.date == date)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.subjectKind == CareLedgerSubjectKind.human.rawValue)
        #expect(ledgerEvents.first?.subjectId == human.id.uuidString)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.workout.rawValue)
        #expect(ledgerEvents.first?.legacyModelName == "HumanWorkoutLog")
        #expect(ledgerEvents.first?.legacyModelId == result.logID.uuidString)
        #expect(ledgerEvents.first?.amountValue == 42)
        #expect(ledgerEvents.first?.amountUnit == "min")
        #expect(ledgerEvents.first?.source == CareLedgerSource.quickAction.rawValue)
        #expect(ledgerEvents.first?.id == result.ledgerEventID)
    }

    @MainActor
    @Test func detailHumanWorkoutServiceWritesFullWorkoutFactAndLedgerMetadata() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .cycling,
            durationMinutes: 55,
            date: date,
            context: context,
            distanceKm: 12.4,
            calories: 430,
            notes: "  evening ride  ",
            source: .detail
        )

        let logs = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.human?.id == human.id)
        #expect(logs.first?.workoutType == .cycling)
        #expect(logs.first?.durationMinutes == 55)
        #expect(logs.first?.distanceKm == 12.4)
        #expect(logs.first?.calories == 430)
        #expect(logs.first?.notes == "evening ride")
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.id == result.ledgerEventID)
        #expect(ledgerEvents.first?.source == CareLedgerSource.detail.rawValue)
        #expect(ledgerEvents.first?.note == "evening ride")
        #expect(ledgerEvents.first?.metadataJSON == "{\"distanceKm\":12.4,\"calories\":430,\"steps\":0}")
    }

    @MainActor
    @Test func healthKitHumanWorkoutImportWritesSourceMetadataAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .running,
            durationMinutes: 36,
            date: date,
            context: context,
            distanceKm: 6.4,
            calories: 510,
            steps: 7300,
            sourceHealthKit: true,
            healthKitWorkoutUUID: "hk-workout-001",
            healthKitSourceBundleID: "com.apple.Health",
            healthKitSourceName: "Apple Health",
            source: .importData
        )

        let log = try #require(try context.fetch(FetchDescriptor<HumanWorkoutLog>()).first)
        let event = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(log.id == result.logID)
        #expect(log.sourceHealthKit)
        #expect(log.healthKitWorkoutUUID == "hk-workout-001")
        #expect(log.healthKitSourceBundleID == "com.apple.Health")
        #expect(log.healthKitSourceName == "Apple Health")
        #expect(log.steps == 7300)
        #expect(log.distanceKm == 6.4)
        #expect(log.calories == 510)
        #expect(event.source == CareLedgerSource.importData.rawValue)
        #expect(event.coconutDelta == 0)
        #expect(event.rewardLogId == nil)

        let metadataData = try #require(event.metadataJSON.data(using: .utf8))
        let metadata = try #require(JSONSerialization.jsonObject(with: metadataData) as? [String: Any])
        #expect((metadata["steps"] as? NSNumber)?.intValue == 7300)
        #expect((metadata["sourceHealthKit"] as? NSNumber)?.boolValue == true)
        #expect(metadata["healthKitWorkoutUUID"] as? String == "hk-workout-001")
    }

    @MainActor
    @Test func petWalkHumanWorkoutImportWritesSourceMetadataAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let petWalkLogID = UUID().uuidString
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 28,
            date: date,
            context: context,
            distanceKm: 1.9,
            sourcePetWalkLogID: petWalkLogID,
            source: .importData
        )

        let log = try #require(try context.fetch(FetchDescriptor<HumanWorkoutLog>()).first)
        let event = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(log.id == result.logID)
        #expect(log.sourcePetWalkLogID == petWalkLogID)
        #expect(!log.sourceHealthKit)
        #expect(event.source == CareLedgerSource.importData.rawValue)
        #expect(event.coconutDelta == 0)

        let metadataData = try #require(event.metadataJSON.data(using: .utf8))
        let metadata = try #require(JSONSerialization.jsonObject(with: metadataData) as? [String: Any])
        #expect(metadata["sourcePetWalkLogID"] as? String == petWalkLogID)
        #expect((metadata["sourceHealthKit"] as? NSNumber)?.boolValue == false)
    }

    @MainActor
    @Test func duplicateHealthKitHumanWorkoutImportReusesExistingFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 20,
            date: date,
            context: context,
            distanceKm: 2.2,
            sourceHealthKit: true,
            healthKitWorkoutUUID: "hk-workout-dupe",
            source: .importData
        )
        let second = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .running,
            durationMinutes: 60,
            date: date.addingTimeInterval(3600),
            context: context,
            distanceKm: 10,
            calories: 700,
            sourceHealthKit: true,
            healthKitWorkoutUUID: "hk-workout-dupe",
            source: .importData
        )

        let logs = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(ledgerEvents.count == 1)
        #expect(first.logID == second.logID)
        #expect(first.ledgerEventID == second.ledgerEventID)
        #expect(logs.first?.workoutType == .walking)
        #expect(logs.first?.distanceKm == 2.2)
    }

    @MainActor
    @Test func duplicatePetWalkHumanWorkoutImportReusesExistingFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let petWalkLogID = UUID().uuidString
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 20,
            date: date,
            context: context,
            distanceKm: 1.6,
            sourcePetWalkLogID: petWalkLogID,
            source: .importData
        )
        let second = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 45,
            date: date.addingTimeInterval(900),
            context: context,
            distanceKm: 4.2,
            calories: 260,
            sourcePetWalkLogID: petWalkLogID,
            source: .importData
        )

        let logs = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(ledgerEvents.count == 1)
        #expect(first.logID == second.logID)
        #expect(first.ledgerEventID == second.ledgerEventID)
        #expect(logs.first?.durationMinutes == 20)
        #expect(logs.first?.distanceKm == 1.6)
        #expect(logs.first?.sourcePetWalkLogID == petWalkLogID)
    }

    @MainActor
    @Test func overlappingHealthKitAndPetWalkImportsMergeIntoOneWorkoutFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let petWalkLogID = UUID().uuidString
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let petWalkResult = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 30,
            date: date,
            context: context,
            distanceKm: 2.0,
            sourcePetWalkLogID: petWalkLogID,
            source: .importData
        )
        let healthKitResult = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 32,
            date: date.addingTimeInterval(120),
            context: context,
            distanceKm: 2.1,
            calories: 180,
            steps: 3100,
            sourceHealthKit: true,
            healthKitWorkoutUUID: "hk-overlap-001",
            healthKitSourceBundleID: "com.apple.Health",
            healthKitSourceName: "Apple Health",
            source: .importData
        )

        let logs = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let log = try #require(logs.first)
        let event = try #require(ledgerEvents.first)
        #expect(logs.count == 1)
        #expect(ledgerEvents.count == 1)
        #expect(petWalkResult.logID == healthKitResult.logID)
        #expect(log.sourcePetWalkLogID == petWalkLogID)
        #expect(log.sourceHealthKit)
        #expect(log.healthKitWorkoutUUID == "hk-overlap-001")

        let metadataData = try #require(event.metadataJSON.data(using: .utf8))
        let metadata = try #require(JSONSerialization.jsonObject(with: metadataData) as? [String: Any])
        #expect(metadata["sourcePetWalkLogID"] as? String == petWalkLogID)
        #expect(metadata["healthKitWorkoutUUID"] as? String == "hk-overlap-001")
        #expect((metadata["sourceHealthKit"] as? NSNumber)?.boolValue == true)
    }

    @MainActor
    @Test func overlappingPetWalkImportMergesIntoExistingHealthKitWorkoutFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let petWalkLogID = UUID().uuidString
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let healthKitResult = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 31,
            date: date,
            context: context,
            distanceKm: 2.2,
            calories: 190,
            steps: 3200,
            sourceHealthKit: true,
            healthKitWorkoutUUID: "hk-overlap-002",
            healthKitSourceBundleID: "com.apple.Health",
            healthKitSourceName: "Apple Health",
            source: .importData
        )
        let petWalkResult = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 30,
            date: date.addingTimeInterval(180),
            context: context,
            distanceKm: 2.1,
            sourcePetWalkLogID: petWalkLogID,
            source: .importData
        )

        let logs = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let log = try #require(logs.first)
        let event = try #require(ledgerEvents.first)
        #expect(logs.count == 1)
        #expect(ledgerEvents.count == 1)
        #expect(healthKitResult.logID == petWalkResult.logID)
        #expect(log.sourcePetWalkLogID == petWalkLogID)
        #expect(log.healthKitWorkoutUUID == "hk-overlap-002")

        let metadataData = try #require(event.metadataJSON.data(using: .utf8))
        let metadata = try #require(JSONSerialization.jsonObject(with: metadataData) as? [String: Any])
        #expect(metadata["sourcePetWalkLogID"] as? String == petWalkLogID)
        #expect(metadata["healthKitWorkoutUUID"] as? String == "hk-overlap-002")
    }

    @MainActor
    @Test func humanWorkoutDeleteServiceRemovesFactAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let createResult = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 20,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            context: context,
            source: .detail
        )
        let log = try #require(try context.fetch(FetchDescriptor<HumanWorkoutLog>()).first)
        let ledgerEventID = try #require(createResult.ledgerEventID)
        let unrelatedLedger = CareLedgerEvent(
            occurredAt: log.date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .workout,
            actionType: WorkoutType.walking.rawValue,
            amountValue: 10,
            amountUnit: "min",
            legacyModelName: "HumanWorkoutLog",
            legacyModelId: "unrelated-workout-log"
        )
        context.insert(unrelatedLedger)
        try context.save()

        let deleteResult = WorkoutCommandService.deleteHumanWorkout(log, human: human, context: context)

        let logs = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.isEmpty)
        #expect(ledgerEvents.map(\.id) == [unrelatedLedger.id])
        #expect(deleteResult.logID == createResult.logID)
        #expect(deleteResult.subjectID == human.id)
        #expect(deleteResult.removedLedgerEventIDs == [ledgerEventID])
    }

    @MainActor
    @Test func quickHumanMedicationServiceWritesOneMedicationFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let firstDose = makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 30)
        let startDate = makeDate(year: 2026, month: 6, day: 8)
        let metadata = HumanMedicationScheduleMetadata(doseMinutes: [570, 1290])
        let notes = HumanMedicationScheduleMetadata.composeNotes(
            visibleNotes: "after meal",
            metadata: metadata
        )
        let result = try #require(HumanMedicationCommandService.createMedication(
            human: human,
            name: " Vitamin D ",
            dosage: " 1 片 ",
            frequency: .twiceDaily,
            firstDoseTime: firstDose,
            startDate: startDate,
            colorHex: "FF6B8A",
            notes: notes,
            context: context,
            reminderEnabled: false
        ))

        let medications = try context.fetch(FetchDescriptor<HumanMedication>())
        let medicationLogs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        #expect(medications.count == 1)
        #expect(medications.first?.id == result.medicationID)
        #expect(medications.first?.humanId == human.id.uuidString)
        #expect(medications.first?.name == "Vitamin D")
        #expect(medications.first?.dosage == "1 片")
        #expect(medications.first?.frequency == .twiceDaily)
        #expect(medications.first?.firstDoseTime == firstDose)
        #expect(medications.first?.startDate == startDate)
        #expect(medications.first?.colorHex == "FF6B8A")
        #expect(medications.first?.isActive == true)
        #expect(result.subjectID == human.id)
        #expect(result.scheduledReminderSync == false)
        #expect(medicationLogs.isEmpty)
        let parsedMetadata = try #require(HumanMedicationScheduleMetadata.parse(from: medications.first?.notes ?? ""))
        #expect(parsedMetadata.doseMinutes == [570, 1290])
        #expect(HumanMedicationScheduleMetadata.visibleNotes(from: medications.first?.notes ?? "") == "after meal")
    }

    @MainActor
    @Test func humanCareCommandExecutorPublishesQuickWorkoutMedicationMetricAndNoteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let executor = HumanCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let workoutCommand = DomainCommand.quickHumanWorkout(humanID: human.id)
        let workout = executor.recordWorkout(
            human: human,
            type: .running,
            durationMinutes: 35,
            date: makeDate(year: 2026, month: 6, day: 8, hour: 7, minute: 0),
            command: workoutCommand,
            note: "test.human.workout"
        )
        var mutation = try #require(revisionCenter.lastMutation)
        #expect(workout.subjectID == human.id)
        #expect(mutation.command == workoutCommand)
        #expect(mutation.affectedEntityIDs.contains(workout.logID))
        #expect(mutation.note == "test.human.workout")

        let medication = try #require(executor.createQuickMedication(
            human: human,
            name: "Vitamin D",
            dosage: "1 tablet",
            frequency: .daily,
            firstDoseTime: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0),
            startDate: makeDate(year: 2026, month: 6, day: 8),
            colorHex: "FF6B8A",
            notes: "",
            reminderEnabled: false,
            note: "test.human.quickMedication"
        ))
        mutation = try #require(revisionCenter.lastMutation)
        #expect(medication.subjectID == human.id)
        #expect(mutation.command == .quickHumanMedication(humanID: human.id))
        #expect(mutation.affectedEntityIDs == [human.id, medication.medicationID])
        #expect(mutation.note == "test.human.quickMedication")

        let metric = try #require(executor.recordHealthMetric(
            human: human,
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 4.2,
            date: makeDate(year: 2026, month: 6, day: 8),
            notes: "fasting",
            note: "test.human.metric"
        ))
        mutation = try #require(revisionCenter.lastMutation)
        #expect(metric.subjectID == human.id)
        #expect(mutation.command == .humanHealthMetric(humanID: human.id, metricKey: "tsh"))
        #expect(mutation.affectedEntityIDs == [human.id, metric.logID])
        #expect(mutation.note == "test.human.metric")

        let note = try #require(executor.recordNote(
            human: human,
            noteText: "call doctor",
            date: makeDate(year: 2026, month: 6, day: 8, hour: 10, minute: 0),
            imageAttachments: [],
            fileAttachments: [],
            reminderDate: nil,
            appLanguage: "en",
            scheduleNotification: false,
            note: "test.human.note"
        ))
        mutation = try #require(revisionCenter.lastMutation)
        #expect(note.subjectID == human.id)
        #expect(mutation.command == .humanNote(humanID: human.id))
        #expect(mutation.affectedEntityIDs == [human.id])
        #expect(mutation.note == "test.human.note")

        let rawNote = try #require(human.notes.components(separatedBy: "\n\n").last)
        let deletedNote = executor.deleteNote(human: human, rawString: rawNote)
        mutation = try #require(revisionCenter.lastMutation)
        #expect(deletedNote.didDelete == true)
        #expect(mutation.command == .humanNote(humanID: human.id))
        #expect(mutation.note == "human.note.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 5)
    }

    @MainActor
    @Test func humanCareCommandExecutorPublishesMedicationPlanDoseAndDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let executor = HumanCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let input = HumanMedicationPlanCommandInput(
            name: "Vitamin D",
            dosage: "1 tablet",
            frequency: .daily,
            customFrequencyNote: "",
            doseMinutes: [9 * 60],
            weeklyWeekday: 2,
            startDate: makeDate(year: 2026, month: 6, day: 8),
            endDate: nil,
            colorHex: "FF6B8A",
            visibleNotes: "",
            isActive: true,
            appLanguage: "en"
        )
        let created = try #require(executor.saveMedicationPlan(
            human: human,
            editing: nil,
            input: input,
            scheduleReminders: false
        ))
        var mutation = try #require(revisionCenter.lastMutation)
        let medication = try #require(try context.fetch(FetchDescriptor<HumanMedication>()).first)
        #expect(created.medicationID == medication.id)
        #expect(mutation.command == .humanMedicationPlan(humanID: human.id, medicationID: nil))
        #expect(mutation.affectedEntityIDs.contains(medication.id))
        #expect(mutation.note == "human.medication.plan.created")

        let activation = executor.setMedicationPlanActive(
            human: human,
            medication: medication,
            isActive: false,
            appLanguage: "en",
            scheduleReminders: false
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(activation.didChange == true)
        #expect(mutation.command == .humanMedicationPlanActivation(
            humanID: human.id,
            medicationID: medication.id,
            isActive: false
        ))
        #expect(mutation.note == "human.medication.plan.activation")

        let scheduledTime = makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0)
        let dose = executor.setMedicationDoseStatus(
            human: human,
            medicationID: medication.id,
            scheduledTime: scheduledTime,
            status: .taken,
            now: scheduledTime
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(dose.didChange == true)
        #expect(dose.recordedLedgerEvent == true)
        #expect(mutation.command == .humanMedicationDose(
            humanID: human.id,
            medicationID: medication.id,
            scheduledMinute: Int(scheduledTime.timeIntervalSince1970 / 60),
            status: HumanMedicationStatus.taken.rawValue
        ))
        #expect(mutation.note == "human.medication.dose.ledger")

        let deleted = executor.deleteMedicationPlan(
            human: human,
            medication: medication,
            scheduleReminders: false,
            note: "test.human.medication.delete"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(deleted.medicationID == medication.id)
        #expect(deleted.didChange == true)
        #expect(mutation.command == .humanMedicationPlanDelete(humanID: human.id, medicationID: medication.id))
        #expect(mutation.note == "test.human.medication.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 4)
    }

    @MainActor
    @Test func humanCareMedicationCommandsNoopForDeceasedHumanWithoutRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let executor = HumanCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let input = HumanMedicationPlanCommandInput(
            name: "Vitamin D",
            dosage: "1 tablet",
            frequency: .daily,
            customFrequencyNote: "",
            doseMinutes: [9 * 60],
            weeklyWeekday: 2,
            startDate: makeDate(year: 2026, month: 6, day: 8),
            endDate: nil,
            colorHex: "FF6B8A",
            visibleNotes: "",
            isActive: true,
            appLanguage: "en"
        )
        let created = try #require(executor.saveMedicationPlan(
            human: human,
            editing: nil,
            input: input,
            scheduleReminders: false
        ))
        let medication = try #require(try context.fetch(FetchDescriptor<HumanMedication>()).first)
        human.passedAwayDate = makeDate(year: 2026, month: 6, day: 9)
        try context.save()

        let beforeRevision = revisionCenter.homeRevision.value
        let beforeMutation = revisionCenter.lastMutation
        let blockedSave = executor.saveMedicationPlan(
            human: human,
            editing: nil,
            input: HumanMedicationPlanCommandInput(
                name: "New medicine",
                dosage: "2 tablets",
                frequency: .daily,
                customFrequencyNote: "",
                doseMinutes: [10 * 60],
                weeklyWeekday: 2,
                startDate: makeDate(year: 2026, month: 6, day: 10),
                endDate: nil,
                colorHex: "00AEEF",
                visibleNotes: "",
                isActive: true,
                appLanguage: "en"
            ),
            scheduleReminders: false
        )
        let activation = executor.setMedicationPlanActive(
            human: human,
            medication: medication,
            isActive: false,
            appLanguage: "en",
            scheduleReminders: false
        )
        let dose = executor.setMedicationDoseStatus(
            human: human,
            medicationID: created.medicationID,
            scheduledTime: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0),
            status: .taken,
            now: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0)
        )
        let deletion = executor.deleteMedicationPlan(
            human: human,
            medication: medication,
            scheduleReminders: false,
            note: "test.human.medication.delete.noop"
        )

        #expect(blockedSave == nil)
        #expect(activation.didChange == false)
        #expect(dose.didChange == false)
        #expect(dose.recordedLedgerEvent == false)
        #expect(deletion.didChange == false)
        #expect(revisionCenter.homeRevision.value == beforeRevision)
        #expect(revisionCenter.lastMutation == beforeMutation)
        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(medication.isActive == true)
    }

    @MainActor
    @Test func petMedicationPlanServiceCreatesUpdatesAndDeletesPlan() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let defaultsName = "PetMedicationPlanCommandServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let startDate = makeDate(year: 2026, month: 6, day: 8)
        let endDate = makeDate(year: 2026, month: 6, day: 15)
        let created = try #require(PetMedicationPlanCommandService.savePlan(
            pet: pet,
            editing: nil,
            input: PetMedicationPlanCommandInput(
                name: "  Apoquel  ",
                dosage: "  1 tablet  ",
                frequency: .twiceDaily,
                doseMinutes: [8 * 60, 20 * 60],
                startDate: startDate,
                endDate: endDate,
                colorHex: "FF6B6B",
                notes: "  after meal  ",
                isActive: true,
                remainingAmount: 12
            ),
            context: context,
            userDefaults: defaults,
            scheduleReminders: false
        ))

        var medications = try context.fetch(FetchDescriptor<PetMedication>())
        let medication = try #require(medications.first)
        let remainingKey = PetMedicationPlanStorageKeys.remainingAmount(medicationID: medication.id)
        #expect(medications.count == 1)
        #expect(created.subjectID == pet.id)
        #expect(created.medicationID == medication.id)
        #expect(created.created == true)
        #expect(created.scheduledReminderSync == false)
        #expect(medication.pet?.id == pet.id)
        #expect(medication.name == "Apoquel")
        #expect(medication.dosage == "1 tablet")
        #expect(medication.frequency == .twiceDaily)
        #expect(medication.customFrequencyNote == PetMedicationSchedulePlan.encodeDoseMinutes([8 * 60, 20 * 60]))
        #expect(medication.startDate == startDate)
        #expect(medication.endDate == endDate)
        #expect(medication.colorHex == "FF6B6B")
        #expect(medication.notes == "after meal")
        #expect(medication.isActive == true)
        #expect(medication.remainingAmount == 12)
        #expect(defaults.double(forKey: remainingKey) == 12)
        var events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count == 2)
        #expect(created.calendarEventIDs.count == 2)
        #expect(created.removedCalendarEventIDs.isEmpty)
        #expect(events.allSatisfy { $0.eventType == EventType.petMedication.rawValue })
        #expect(events.allSatisfy { $0.relatedEntityType == DomainEntityLinkRegistry.petMedicationPlan })
        #expect(events.allSatisfy { $0.relatedEntityId == medication.id.uuidString })
        #expect(events.allSatisfy { $0.recurrenceDays == 1 })

        let updatedEndDate = makeDate(year: 2026, month: 6, day: 22)
        let updated = try #require(PetMedicationPlanCommandService.savePlan(
            pet: pet,
            editing: medication,
            input: PetMedicationPlanCommandInput(
                name: "Apoquel XR",
                dosage: "2 tablets",
                frequency: .daily,
                doseMinutes: [9 * 60],
                startDate: startDate,
                endDate: updatedEndDate,
                colorHex: "4ECDC4",
                notes: "breakfast",
                isActive: false,
                remainingAmount: nil
            ),
            context: context,
            userDefaults: defaults,
            scheduleReminders: false
        ))

        medications = try context.fetch(FetchDescriptor<PetMedication>())
        #expect(medications.count == 1)
        #expect(updated.medicationID == created.medicationID)
        #expect(updated.created == false)
        #expect(medication.name == "Apoquel XR")
        #expect(medication.dosage == "2 tablets")
        #expect(medication.frequency == .daily)
        #expect(medication.customFrequencyNote == PetMedicationSchedulePlan.encodeDoseMinutes([9 * 60]))
        #expect(medication.endDate == updatedEndDate)
        #expect(medication.colorHex == "4ECDC4")
        #expect(medication.notes == "breakfast")
        #expect(medication.isActive == false)
        #expect(medication.remainingAmount == 0)
        #expect(defaults.object(forKey: remainingKey) == nil)
        events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.isEmpty)
        #expect(updated.removedCalendarEventIDs.count == 2)
        #expect(updated.calendarEventIDs.isEmpty)

        let activated = PetMedicationPlanCommandService.setPlanActive(
            pet: pet,
            medication: medication,
            isActive: true,
            context: context,
            scheduleReminders: false
        )
        #expect(activated.subjectID == pet.id)
        #expect(activated.medicationID == medication.id)
        #expect(activated.didChange == true)
        #expect(activated.isActive == true)
        #expect(medication.isActive == true)
        events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count == 1)
        #expect(activated.calendarEventIDs.count == 1)
        #expect(activated.removedCalendarEventIDs.isEmpty)

        let deleted = PetMedicationPlanCommandService.deletePlan(
            pet: pet,
            medication: medication,
            context: context,
            userDefaults: defaults,
            scheduleReminders: false
        )

        medications = try context.fetch(FetchDescriptor<PetMedication>())
        #expect(deleted.subjectID == pet.id)
        #expect(deleted.medicationID == created.medicationID)
        #expect(medications.isEmpty)
        #expect(defaults.object(forKey: remainingKey) == nil)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(deleted.removedCalendarEventIDs.count == 1)
    }

    @MainActor
    @Test func petMedicationCommandExecutorPublishesCreateActivationAndDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let defaultsName = "PetMedicationCommandExecutorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let executor = PetMedicationCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let created = try #require(executor.savePlan(
            pet: pet,
            editing: nil,
            input: PetMedicationPlanCommandInput(
                name: "Apoquel",
                dosage: "1 tablet",
                frequency: .daily,
                doseMinutes: [9 * 60],
                startDate: makeDate(year: 2026, month: 6, day: 8),
                endDate: nil,
                colorHex: "FF6B6B",
                notes: "after meal",
                isActive: true,
                remainingAmount: 8
            ),
            userDefaults: defaults,
            scheduleReminders: false,
            note: "test.pet.medication.create"
        ))
        let createMutation = try #require(revisionCenter.lastMutation)
        let medication = try #require(try context.fetch(FetchDescriptor<PetMedication>()).first)
        #expect(created.medicationID == medication.id)
        #expect(createMutation.command == .petMedicationPlan(petID: pet.id, medicationID: medication.id))
        #expect(createMutation.affectedEntityIDs.contains(pet.id))
        #expect(createMutation.affectedEntityIDs.contains(medication.id))
        #expect(created.calendarEventIDs.count == 1)
        let createdEventID = try #require(created.calendarEventIDs.first)
        #expect(createMutation.affectedEntityIDs.contains(createdEventID))
        #expect(createMutation.note == "test.pet.medication.create")

        let activation = executor.setPlanActive(
            pet: pet,
            medication: medication,
            isActive: false,
            scheduleReminders: false,
            note: "test.pet.medication.activation"
        )
        let activationMutation = try #require(revisionCenter.lastMutation)
        #expect(activation.didChange == true)
        #expect(medication.isActive == false)
        #expect(activationMutation.command == .petMedicationPlanActivation(
            petID: pet.id,
            medicationID: medication.id,
            isActive: false
        ))
        #expect(activation.removedCalendarEventIDs.count == 1)
        let removedEventID = try #require(activation.removedCalendarEventIDs.first)
        #expect(activationMutation.affectedEntityIDs.contains(removedEventID))
        #expect(activationMutation.note == "test.pet.medication.activation")

        let deleted = executor.deletePlan(
            pet: pet,
            medication: medication,
            userDefaults: defaults,
            scheduleReminders: false,
            note: "test.pet.medication.delete"
        )
        let deleteMutation = try #require(revisionCenter.lastMutation)
        #expect(deleted.medicationID == medication.id)
        #expect(try context.fetch(FetchDescriptor<PetMedication>()).isEmpty)
        #expect(deleteMutation.command == .petMedicationPlanDelete(petID: pet.id, medicationID: medication.id))
        #expect(deleteMutation.note == "test.pet.medication.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func humanMedicationPlanServiceCreatesMedicationAndCalendarEvents() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let input = HumanMedicationPlanCommandInput(
            name: " Vitamin D ",
            dosage: " 1 tablet ",
            frequency: .weekly,
            customFrequencyNote: "",
            doseMinutes: [20 * 60, 8 * 60],
            weeklyWeekday: 2,
            startDate: makeDate(year: 2026, month: 6, day: 8),
            endDate: makeDate(year: 2026, month: 7, day: 8),
            colorHex: "FF6B8A",
            visibleNotes: " after meal ",
            isActive: true,
            appLanguage: "en"
        )

        let result = try #require(HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: nil,
            input: input,
            context: context,
            scheduleReminders: false
        ))

        let medications = try context.fetch(FetchDescriptor<HumanMedication>())
        let events = try context.fetch(FetchDescriptor<Event>())
            .sorted { $0.startDate < $1.startDate }
        #expect(medications.count == 1)
        #expect(medications.first?.id == result.medicationID)
        #expect(medications.first?.name == "Vitamin D")
        #expect(medications.first?.dosage == "1 tablet")
        #expect(medications.first?.frequency == .weekly)
        #expect(medications.first?.customFrequencyNote == "")
        #expect(medications.first?.isActive == true)
        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.eventType == EventType.medication.rawValue })
        #expect(events.allSatisfy { $0.relatedEntityType == DomainEntityLinkRegistry.humanMedicationPlan })
        #expect(events.allSatisfy { $0.relatedEntityId == result.medicationID.uuidString })
        #expect(events.allSatisfy { $0.recurrenceDays == 7 })
        #expect(events.allSatisfy { $0.assigneeId == human.id.uuidString })
        #expect(events.first?.title.contains("Dose 1") == true)
        #expect(events.last?.title.contains("Dose 2") == true)
        #expect(result.calendarEventIDs.count == 2)
        #expect(result.scheduledReminderSync == false)
        let parsedMetadata = try #require(HumanMedicationScheduleMetadata.parse(from: medications.first?.notes ?? ""))
        #expect(parsedMetadata.doseMinutes == [8 * 60, 20 * 60])
        #expect(HumanMedicationScheduleMetadata.visibleNotes(from: medications.first?.notes ?? "") == "after meal")
    }

    @MainActor
    @Test func humanMedicationPlanServiceUpdatesExistingPlanAndReplacesCalendarEvents() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let createInput = HumanMedicationPlanCommandInput(
            name: "Vitamin D",
            dosage: "1 tablet",
            frequency: .twiceDaily,
            customFrequencyNote: "",
            doseMinutes: [8 * 60, 20 * 60],
            weeklyWeekday: 2,
            startDate: makeDate(year: 2026, month: 6, day: 8),
            endDate: nil,
            colorHex: "FF6B8A",
            visibleNotes: "",
            isActive: true,
            appLanguage: "en"
        )
        let created = try #require(HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: nil,
            input: createInput,
            context: context,
            scheduleReminders: false
        ))
        let medication = try #require(try context.fetch(FetchDescriptor<HumanMedication>()).first)

        let updateInput = HumanMedicationPlanCommandInput(
            name: "Vitamin D3",
            dosage: "2 tablets",
            frequency: .daily,
            customFrequencyNote: "",
            doseMinutes: [9 * 60],
            weeklyWeekday: 2,
            startDate: makeDate(year: 2026, month: 6, day: 9),
            endDate: nil,
            colorHex: "14B8A6",
            visibleNotes: "morning",
            isActive: true,
            appLanguage: "en"
        )
        let updated = try #require(HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: medication,
            input: updateInput,
            context: context,
            scheduleReminders: false
        ))

        let medications = try context.fetch(FetchDescriptor<HumanMedication>())
        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(medications.count == 1)
        #expect(medications.first?.id == created.medicationID)
        #expect(medications.first?.name == "Vitamin D3")
        #expect(medications.first?.dosage == "2 tablets")
        #expect(medications.first?.frequency == .daily)
        #expect(events.count == 1)
        #expect(events.first?.title.contains("Vitamin D3") == true)
        #expect(events.first?.recurrenceDays == 1)
        #expect(updated.created == false)
        #expect(updated.removedCalendarEventIDs.count == 2)
        #expect(updated.calendarEventIDs.count == 1)
    }

    @MainActor
    @Test func humanMedicationPlanServiceDeletesPlanEventsButKeepsDoseLogs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let input = HumanMedicationPlanCommandInput(
            name: "Vitamin D",
            dosage: "1 tablet",
            frequency: .daily,
            customFrequencyNote: "",
            doseMinutes: [8 * 60],
            weeklyWeekday: 2,
            startDate: makeDate(year: 2026, month: 6, day: 8),
            endDate: nil,
            colorHex: "FF6B8A",
            visibleNotes: "",
            isActive: true,
            appLanguage: "en"
        )
        _ = try #require(HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: nil,
            input: input,
            context: context,
            scheduleReminders: false
        ))
        let medication = try #require(try context.fetch(FetchDescriptor<HumanMedication>()).first)
        let log = HumanMedicationLog(
            humanId: human.id.uuidString,
            medicationId: medication.id.uuidString,
            scheduledTime: makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 0),
            status: .taken,
            recordedTime: makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 1)
        )
        context.insert(log)
        try context.save()

        let result = HumanMedicationPlanCommandService.deletePlan(
            human: human,
            medication: medication,
            context: context,
            scheduleReminders: false
        )

        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        let logs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == log.id)
        #expect(result.removedCalendarEventIDs.count == 1)
        #expect(result.scheduledReminderSync == false)
    }

    @MainActor
    @Test func humanMedicationPlanActivationServiceRebuildsCalendarEvents() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let input = HumanMedicationPlanCommandInput(
            name: "Vitamin D",
            dosage: "1 tablet",
            frequency: .daily,
            customFrequencyNote: "",
            doseMinutes: [8 * 60],
            weeklyWeekday: 2,
            startDate: makeDate(year: 2026, month: 6, day: 8),
            endDate: nil,
            colorHex: "FF6B8A",
            visibleNotes: "",
            isActive: true,
            appLanguage: "en"
        )
        _ = try #require(HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: nil,
            input: input,
            context: context,
            scheduleReminders: false
        ))
        let medication = try #require(try context.fetch(FetchDescriptor<HumanMedication>()).first)

        let stopped = HumanMedicationPlanCommandService.setPlanActive(
            human: human,
            medication: medication,
            isActive: false,
            appLanguage: "en",
            context: context,
            scheduleReminders: false
        )
        #expect(medication.isActive == false)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(stopped.didChange == true)
        #expect(stopped.removedCalendarEventIDs.count == 1)

        let resumed = HumanMedicationPlanCommandService.setPlanActive(
            human: human,
            medication: medication,
            isActive: true,
            appLanguage: "en",
            context: context,
            scheduleReminders: false
        )
        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(medication.isActive == true)
        #expect(events.count == 1)
        #expect(events.first?.relatedEntityId == medication.id.uuidString)
        #expect(resumed.didChange == true)
        #expect(resumed.calendarEventIDs.count == 1)
    }

    @MainActor
    @Test func humanMedicationDoseServiceWritesDoseFactAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let medication = HumanMedication(
            humanId: human.id.uuidString,
            name: "Vitamin D",
            dosage: "1 tablet",
            frequency: .daily,
            firstDoseTime: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0),
            startDate: makeDate(year: 2026, month: 6, day: 8)
        )
        context.insert(human)
        context.insert(medication)
        try context.save()

        let scheduled = makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0)
        let result = HumanMedicationDoseCommandService.setDoseStatus(
            human: human,
            medicationID: medication.id,
            scheduledTime: scheduled,
            status: .taken,
            context: context,
            now: scheduled
        )

        let logs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.humanId == human.id.uuidString)
        #expect(logs.first?.medicationId == medication.id.uuidString)
        #expect(logs.first?.status == .taken)
        #expect(logs.first?.scheduledTime == scheduled)
        #expect(result.subjectID == human.id)
        #expect(result.medicationID == medication.id)
        #expect(result.didChange == true)
        #expect(result.recordedLedgerEvent == true)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.medication.rawValue)
        #expect(ledgerEvents.first?.actionType == "humanMedicationTaken")
        #expect(ledgerEvents.first?.legacyModelName == "HumanMedicationLog")
        #expect(ledgerEvents.first?.legacyModelId == result.logID?.uuidString)
    }

    @MainActor
    @Test func humanMedicationDoseServiceCanReturnDoseToPendingWithoutLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let medication = HumanMedication(
            humanId: human.id.uuidString,
            name: "Vitamin D",
            frequency: .daily,
            startDate: makeDate(year: 2026, month: 6, day: 8)
        )
        let scheduled = makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0)
        let log = HumanMedicationLog(
            humanId: human.id.uuidString,
            medicationId: medication.id.uuidString,
            scheduledTime: scheduled,
            status: .taken,
            recordedTime: scheduled
        )
        context.insert(human)
        context.insert(medication)
        context.insert(log)
        try context.save()

        let result = HumanMedicationDoseCommandService.setDoseStatus(
            human: human,
            medicationID: medication.id,
            scheduledTime: scheduled,
            status: .pending,
            context: context,
            now: scheduled
        )

        let logs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == log.id)
        #expect(logs.first?.status == .pending)
        #expect(logs.first?.recordedTime == nil)
        #expect(result.didChange == true)
        #expect(result.recordedLedgerEvent == false)
        #expect(ledgerEvents.isEmpty)
    }

    @MainActor
    @Test func humanHealthMetricServiceWritesOneMetricFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let date = makeDate(year: 2026, month: 6, day: 8)
        let result = try #require(HumanHealthMetricCommandService.recordMetric(
            human: human,
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 4.2,
            date: date,
            notes: " fasting ",
            context: context
        ))

        let logs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == result.logID)
        #expect(logs.first?.human?.id == human.id)
        #expect(logs.first?.metricKey == "tsh")
        #expect(logs.first?.unitCode == "mIU_L")
        #expect(logs.first?.value == 4.2)
        #expect(logs.first?.date == date)
        #expect(logs.first?.notes == "fasting")
        #expect(result.subjectID == human.id)
        #expect(result.metricKey == "tsh")
    }

    @MainActor
    @Test func humanHealthMetricServiceDeletesMetricFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let result = try #require(HumanHealthMetricCommandService.recordMetric(
            human: human,
            metricKey: "hba1c",
            unitCode: "percent",
            value: 5.4,
            date: makeDate(year: 2026, month: 6, day: 8),
            notes: "",
            context: context
        ))
        let log = try #require(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).first)

        let deleteResult = HumanHealthMetricCommandService.deleteMetricLog(
            log,
            human: human,
            context: context
        )

        let logs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())
        #expect(deleteResult.humanID == human.id)
        #expect(deleteResult.metricKey == "hba1c")
        #expect(deleteResult.logID == result.logID)
        #expect(logs.isEmpty)
        #expect(human.healthMetricLogs.isEmpty)
    }

    @MainActor
    @Test func humanHealthReportServiceCreatesUpdatesAndDeletesReport() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let createResult = HumanHealthReportCommandService.createReport(
            human: human,
            input: HumanHealthReportCommandInput(
                reportType: .bloodTest,
                conclusion: .attention,
                hospitalName: " City Lab ",
                doctorName: " Dr. Lin ",
                reportDate: makeDate(year: 2026, month: 6, day: 8),
                nextCheckDate: makeDate(year: 2026, month: 12, day: 8),
                summary: "  thyroid review  ",
                notes: "  fasting  "
            ),
            context: context
        )

        var reports = try context.fetch(FetchDescriptor<HumanHealthReport>())
        let report = try #require(reports.first)
        #expect(createResult.humanID == human.id)
        #expect(createResult.reportID == report.id)
        #expect(createResult.reportType == HealthReportType.bloodTest.rawValue)
        #expect(report.humanId == human.id.uuidString)
        #expect(report.reportType == .bloodTest)
        #expect(report.conclusion == .attention)
        #expect(report.hospitalName == "City Lab")
        #expect(report.doctorName == "Dr. Lin")
        #expect(report.summary == "thyroid review")
        #expect(report.notes == "fasting")

        let updateResult = HumanHealthReportCommandService.updateReport(
            report,
            human: human,
            input: HumanHealthReportCommandInput(
                reportType: .physical,
                conclusion: .normal,
                hospitalName: "Home Clinic",
                doctorName: "",
                reportDate: makeDate(year: 2026, month: 7, day: 1),
                nextCheckDate: nil,
                summary: "all good",
                notes: ""
            ),
            context: context
        )
        #expect(updateResult.reportID == report.id)
        #expect(report.reportType == .physical)
        #expect(report.conclusion == .normal)
        #expect(report.nextCheckDate == nil)
        #expect(report.summary == "all good")

        let deleteResult = HumanHealthReportCommandService.deleteReport(report, human: human, context: context)

        reports = try context.fetch(FetchDescriptor<HumanHealthReport>())
        #expect(deleteResult.humanID == human.id)
        #expect(deleteResult.reportID == report.id)
        #expect(deleteResult.reportType == HealthReportType.physical.rawValue)
        #expect(reports.isEmpty)
    }

    @MainActor
    @Test func humanHealthReportCommandExecutorPublishesCreateUpdateAndDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let executor = HumanHealthReportCommandExecutor(context: context, revisionCenter: revisionCenter)
        let createResult = executor.createReport(
            human: human,
            input: HumanHealthReportCommandInput(
                reportType: .bloodTest,
                conclusion: .attention,
                hospitalName: "City Lab",
                doctorName: "Dr. Lin",
                reportDate: makeDate(year: 2026, month: 6, day: 8),
                nextCheckDate: makeDate(year: 2026, month: 12, day: 8),
                summary: "thyroid review",
                notes: "fasting"
            ),
            note: "test.report.create"
        )
        var mutation = try #require(revisionCenter.lastMutation)
        #expect(mutation.command == .humanHealthReport(
            humanID: human.id,
            reportID: createResult.reportID,
            action: "create"
        ))
        #expect(mutation.affectedEntityIDs == [human.id, createResult.reportID])
        #expect(mutation.note == "test.report.create")

        var reports = try context.fetch(FetchDescriptor<HumanHealthReport>())
        let report = try #require(reports.first)
        let updateResult = executor.updateReport(
            report,
            human: human,
            input: HumanHealthReportCommandInput(
                reportType: .physical,
                conclusion: .normal,
                hospitalName: "Home Clinic",
                doctorName: "",
                reportDate: makeDate(year: 2026, month: 7, day: 1),
                nextCheckDate: nil,
                summary: "all good",
                notes: ""
            ),
            note: "test.report.update"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(updateResult.reportID == createResult.reportID)
        #expect(mutation.command == .humanHealthReport(
            humanID: human.id,
            reportID: createResult.reportID,
            action: "update"
        ))
        #expect(mutation.note == "test.report.update")

        let deleteResult = executor.deleteReport(report, human: human, note: "test.report.delete")
        mutation = try #require(revisionCenter.lastMutation)
        reports = try context.fetch(FetchDescriptor<HumanHealthReport>())
        #expect(deleteResult.reportID == createResult.reportID)
        #expect(reports.isEmpty)
        #expect(mutation.command == .humanHealthReport(
            humanID: human.id,
            reportID: createResult.reportID,
            action: "delete"
        ))
        #expect(mutation.note == "test.report.delete")
    }

    @MainActor
    @Test func humanNoteServiceWritesNoteFactAttachmentsAndReminder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let date = makeDate(year: 2026, month: 6, day: 8)
        let reminderDate = makeDate(year: 2026, month: 6, day: 8, hour: 16, minute: 30)
        let result = try #require(HumanNoteCommandService.recordNote(
            human: human,
            note: " remember meds ",
            date: date,
            imageAttachments: [],
            fileAttachments: [
                HumanNoteFileAttachmentPayload(
                    fileName: "lab.pdf",
                    data: Data([1, 2, 3]),
                    isImage: false
                )
            ],
            reminderDate: reminderDate,
            appLanguage: "en",
            context: context,
            scheduleNotification: false
        ))

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let parsed = HumanNoteAttachmentStore.visibleTextAndAttachments(from: human.notes)
        #expect(result.subjectID == human.id)
        #expect(result.attachmentCount == 1)
        #expect(result.eventID == events.first?.id)
        #expect(result.reminderID == reminders.first?.id)
        #expect(human.notes.contains("[2026-06-08] remember meds"))
        #expect(human.notes.contains("Files: lab.pdf"))
        #expect(parsed.attachments.count == 1)
        #expect(parsed.attachments.first?.fileName == "lab.pdf")
        #expect(events.count == 1)
        #expect(events.first?.title == "remember meds")
        #expect(events.first?.eventType == EventType.task.rawValue)
        #expect(events.first?.relatedEntityType == DomainEntityLinkRegistry.humanNote)
        #expect(events.first?.relatedEntityId == human.id.uuidString)
        #expect(events.first?.assigneeId == human.id.uuidString)
        #expect(reminders.count == 1)
        #expect(reminders.first?.event?.id == events.first?.id)
        #expect(reminders.first?.scheduledAt == reminderDate)
    }

    @MainActor
    @Test func humanNoteServiceDeletesOneNoteFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.notes = "[2026-06-08] first\n\n[2026-06-09] second"
        context.insert(human)
        try context.save()

        let result = HumanNoteCommandService.deleteNote(
            human: human,
            rawString: "[2026-06-08] first",
            context: context
        )

        #expect(result.subjectID == human.id)
        #expect(result.didDelete == true)
        #expect(human.notes == "[2026-06-09] second")
    }

    @MainActor
    @Test func eventCompletionRewardServiceIsNoOpForCareTask() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pet = Pet(name: "Momo", species: "狗")
        let event = Event(
            title: "喂食 Momo",
            startDate: now,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let log = PetCareLog(date: now, type: .feeding, pet: pet, executorId: "human-1")
        context.insert(pet)
        context.insert(event)
        context.insert(log)
        try context.save()

        let result = EventCompletionCommandService.awardCompletionIfEligible(
            event: event,
            occurrenceDate: now,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            executorId: "human-1",
            now: now
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result.awarded == false)
        #expect(result.skippedByExistingCare == false)
        #expect(result.coconutDelta == 0)
        #expect(ledgerEvents.isEmpty)
    }

    @MainActor
    @Test func eventCompletionRewardServiceIsNoOpForGeneralTask() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let event = Event(
            title: "整理补给",
            startDate: now,
            eventType: EventType.task.rawValue
        )
        context.insert(event)
        try context.save()

        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: "human-1", date: now)
        defer {
            EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: "human-1", date: now)
        }

        let result = EventCompletionCommandService.awardCompletionIfEligible(
            event: event,
            occurrenceDate: now,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            executorId: "human-1",
            now: now
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(result.awarded == false)
        #expect(result.coconutDelta == 0)
        #expect(ledgerEvents.isEmpty)
        #expect(walletEntries.isEmpty)
    }

    @MainActor
    @Test func eventCompletionRewardServiceStaysNoOpOnReplay() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let human = Human(name: "Li")
        let event = Event(
            title: "整理补给",
            startDate: now,
            eventType: EventType.task.rawValue
        )
        context.insert(human)
        context.insert(event)
        try context.save()

        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: human.id.uuidString, date: now)
        defer {
            EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: human.id.uuidString, date: now)
        }

        let first = EventCompletionCommandService.awardCompletionIfEligible(
            event: event,
            occurrenceDate: now,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            executorId: human.id.uuidString,
            now: now
        )
        let replay = EventCompletionCommandService.awardCompletionIfEligible(
            event: event,
            occurrenceDate: now,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            executorId: human.id.uuidString,
            now: now.addingTimeInterval(30)
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        #expect(first.coconutDelta == 0)
        #expect(first.awarded == false)
        #expect(replay.awarded == false)
        #expect(human.coconutBalance == 0)
        #expect(walletEntries.isEmpty)
        #expect(budgetEvents.count { $0.actionKey == "calendarEventCompletion" } == 0)
    }

    @MainActor
    @Test func eventCompletionRewardServiceDoesNotConsumeDailyBudget() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let human = Human(name: "Li")
        let event = Event(
            title: "整理补给",
            startDate: now,
            eventType: EventType.task.rawValue
        )
        context.insert(human)
        context.insert(event)
        try context.save()

        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: human.id.uuidString, date: now)
        defer {
            EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: human.id.uuidString, date: now)
        }
        EconomyDailyBudgetStore.commit(
            EconomyRewardResult(
                growthXP: 0,
                humanCoconuts: 54,
                petCoconuts: 0,
                bonusCoconuts: 0,
                luckyCoconuts: 0,
                budgetMultiplier: 1,
                budgetStage: .normal,
                reason: "test",
                actionKey: "budget_filler",
                isOnCooldown: false,
                baseGrowthXP: 0,
                baseCoconuts: 54,
                luck: .none
            ),
            householdKey: householdKey,
            memberKey: human.id.uuidString,
            date: now,
            context: context
        )

        let result = EventCompletionCommandService.awardCompletionIfEligible(
            event: event,
            occurrenceDate: now,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            executorId: human.id.uuidString,
            now: now
        )

        #expect(result.awarded == false)
        #expect(result.coconutDelta == 0)
        #expect(human.coconutBalance == 0)
        let rewardEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(rewardEntries.isEmpty)
    }

    @MainActor
    @Test func eventCompletionCommandExecutorDoesNotPublishForNoOpReward() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let event = Event(
            title: "整理补给",
            startDate: now,
            eventType: EventType.task.rawValue
        )
        context.insert(event)
        try context.save()
        let beforeRevision = revisionCenter.homeRevision.value

        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: "human-1", date: now)
        defer {
            EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: "human-1", date: now)
        }

        let result = EventCompletionCommandExecutor(context: context, revisionCenter: revisionCenter).awardCompletionIfEligible(
            event: event,
            occurrenceDate: now,
            executorId: "human-1",
            now: now,
            note: "test.eventCompletion.reward"
        )

        #expect(result.awarded == false)
        #expect(revisionCenter.lastMutation == nil)
        #expect(revisionCenter.homeRevision.value == beforeRevision)
    }

    @MainActor
    @Test func calendarEventPlanServiceCreatesSingleEventAndReminder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let start = makeDate(year: 2026, month: 6, day: 10, hour: 9, minute: 30)
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let input = CalendarEventPlanCommandInput(
            title: "  Vet visit  ",
            startDate: start,
            isAllDay: false,
            eventType: .task,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: 30,
            assigneeId: executorHuman.id.uuidString
        )

        let result = try #require(CalendarEventPlanCommandService.createEvent(
            input: input,
            context: context,
            scheduleNotifications: false
        ))

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let event = try #require(events.first)
        let reminder = try #require(reminders.first)
        #expect(events.count == 1)
        #expect(reminders.count == 1)
        #expect(result.eventID == event.id)
        #expect(result.reminderIDs == [reminder.id])
        #expect(result.scheduledReminderSync == false)
        #expect(event.title == "Vet visit")
        #expect(event.startDate == start)
        #expect(event.eventType == EventType.task.rawValue)
        #expect(event.relatedEntityType == EntityKind.pet.rawValue)
        #expect(event.relatedEntityId == pet.id.uuidString)
        #expect(event.assigneeId == executorHuman.id.uuidString)
        #expect(reminder.event?.id == event.id)
        #expect(reminder.scheduledAt == start.addingTimeInterval(-30 * 60))
    }

    @MainActor
    @Test func calendarEventPlanServiceCreatesAtTimeReminderForNearFutureEvents() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let start = Date().addingTimeInterval(3 * 60)

        let input = CalendarEventPlanCommandInput(
            title: "Soon",
            startDate: start,
            isAllDay: false,
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: 0,
            assigneeId: nil
        )

        let result = try #require(CalendarEventPlanCommandService.createEvent(
            input: input,
            context: context,
            scheduleNotifications: false
        ))

        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let reminder = try #require(reminders.first)
        #expect(reminders.count == 1)
        #expect(result.reminderIDs == [reminder.id])
        #expect(reminder.scheduledAt == start)
    }

    @MainActor
    @Test func calendarEventPlanServiceCreatesRecurringReminders() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let start = makeDate(year: 2026, month: 6, day: 1, hour: 9, minute: 0)
        let end = makeDate(year: 2026, month: 6, day: 22, hour: 23, minute: 59)

        let input = CalendarEventPlanCommandInput(
            title: "Weekly check",
            startDate: start,
            isAllDay: false,
            eventType: .daily,
            relatedEntityType: "",
            relatedEntityId: "",
            recurrenceDays: 7,
            recurrenceEndDate: end,
            reminderLeadMinutes: 60,
            assigneeId: nil
        )

        let result = try #require(CalendarEventPlanCommandService.createEvent(
            input: input,
            context: context,
            scheduleNotifications: false
        ))

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>(
            sortBy: [SortDescriptor(\Reminder.scheduledAt)]
        ))
        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(reminders.count == 4)
        #expect(result.reminderIDs.count == 4)
        #expect(event.recurrenceDays == 7)
        #expect(event.recurrenceEndDate == end)
        #expect(reminders.map(\.scheduledAt) == [
            start.addingTimeInterval(-60 * 60),
            makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 0),
            makeDate(year: 2026, month: 6, day: 15, hour: 8, minute: 0),
            makeDate(year: 2026, month: 6, day: 22, hour: 8, minute: 0)
        ])
    }

    @MainActor
    @Test func calendarEventPlanServiceSkipsBlankTitle() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let input = CalendarEventPlanCommandInput(
            title: "   ",
            startDate: makeDate(year: 2026, month: 6, day: 10),
            isAllDay: false,
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: 30,
            assigneeId: nil
        )

        let result = CalendarEventPlanCommandService.createEvent(
            input: input,
            context: context,
            scheduleNotifications: false
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(result == nil)
        #expect(events.isEmpty)
        #expect(reminders.isEmpty)
    }

    @MainActor
    @Test func calendarEventCompletionServiceSyncsPetCareFactAndUndo() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        let event = Event(
            title: "喂食 Momo 42g",
            startDate: now,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(pet)
        context.insert(event)
        try context.save()

        let completed = CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: now,
            pets: [pet],
            context: context,
            executorId: executorHuman.id.uuidString,
            now: now
        )

        var careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(completed.isCompleted == true)
        #expect(event.isCompleted == true)
        #expect(careLogs.count == 1)
        #expect(careLogs.first?.careType == .feeding)
        #expect(careLogs.first?.pet?.id == pet.id)

        let reopened = CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: now,
            pets: [pet],
            context: context,
            executorId: executorHuman.id.uuidString,
            now: now
        )

        careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(reopened.isCompleted == false)
        #expect(event.isCompleted == false)
        #expect(careLogs.isEmpty)
    }

    @MainActor
    @Test func calendarCommandExecutorWritesPetTaskFactForMissingExecutor() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let occurrence = makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "Feed Momo 42g",
            startDate: occurrence,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(pet)
        context.insert(event)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.removeObject(forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()

        let executor = CalendarCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let missingExecutorID = UUID().uuidString

        let result = executor.toggleCompletion(
            event: event,
            occurrenceDate: occurrence,
            pets: [pet],
            executorId: missingExecutorID,
            note: "test.calendar.missing.executor"
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let mutation = try #require(revisionCenter.lastMutation)
        #expect(result.isCompleted == true)
        #expect(result.didWriteFact == true)
        #expect(result.allowsDerivedEffects == true)
        #expect(event.isOccurrenceMarkedComplete(on: occurrence))
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(ledgerEvents.contains { $0.legacyModelId == logs.first?.id.uuidString })
        #expect(walletEntries.isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .calendarEventCompletion(eventID: event.id, isCompleted: true))
        #expect(mutation.wroteBusinessFact == true)
    }

    @MainActor
    @Test func calendarSingleOccurrenceDeletionSplitsRecurringEvent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let start = makeDate(year: 2026, month: 6, day: 1)
        let occurrence = makeDate(year: 2026, month: 6, day: 5)
        let end = makeDate(year: 2026, month: 6, day: 10)
        let executorHuman = insertExecutorHuman(in: context)
        let event = Event(title: "Daily care", startDate: start, eventType: EventType.daily.rawValue)
        event.recurrenceDays = 1
        event.recurrenceEndDate = end
        event.assigneeId = executorHuman.id.uuidString
        event.feedRuleKindRaw = "manual"
        event.feedAmountGrams = 42
        context.insert(event)
        try context.save()

        let outcome = CalendarEventCommandService.delete(
            event: event,
            occurrenceDate: occurrence,
            scope: .singleOccurrence,
            context: context
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count == 2)
        guard case .split = outcome else {
            Issue.record("Expected split outcome")
            return
        }
        let original = try #require(events.first { $0.id == event.id })
        let split = try #require(events.first { $0.id != event.id })
        #expect(Calendar.current.isDate(original.recurrenceEndDate ?? .distantPast, inSameDayAs: makeDate(year: 2026, month: 6, day: 4)))
        #expect(Calendar.current.isDate(split.startDate, inSameDayAs: makeDate(year: 2026, month: 6, day: 6)))
        #expect(Calendar.current.isDate(split.recurrenceEndDate ?? .distantPast, inSameDayAs: end))
        #expect(split.assigneeId == executorHuman.id.uuidString)
        #expect(split.feedRuleKindRaw == "manual")
        #expect(split.feedAmountGrams == 42)
    }

    @MainActor
    @Test func calendarThisAndFutureDeletionTruncatesRecurringEvent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let start = makeDate(year: 2026, month: 6, day: 1)
        let occurrence = makeDate(year: 2026, month: 6, day: 5)
        let event = Event(title: "Daily care", startDate: start, eventType: EventType.daily.rawValue)
        event.recurrenceDays = 1
        event.recurrenceEndDate = makeDate(year: 2026, month: 6, day: 10)
        context.insert(event)
        try context.save()

        let outcome = CalendarEventCommandService.delete(
            event: event,
            occurrenceDate: occurrence,
            scope: .thisAndFuture,
            context: context
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count == 1)
        #expect(outcome == .truncated(event.id))
        #expect(Calendar.current.isDate(event.recurrenceEndDate ?? .distantPast, inSameDayAs: makeDate(year: 2026, month: 6, day: 4)))
    }

    @MainActor
    @Test func calendarCommandExecutorPublishesCreateCompletionAndDeletionRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let start = makeDate(year: 2026, month: 6, day: 10, hour: 9, minute: 0)
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()
        let input = CalendarEventPlanCommandInput(
            title: " Morning task ",
            startDate: start,
            isAllDay: false,
            eventType: .task,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: human.id.uuidString,
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: nil,
            assigneeId: nil
        )

        let executor = CalendarCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let created = try #require(executor.createEvent(input: input))
        let createMutation = try #require(revisionCenter.lastMutation)
        let event = try #require(try context.fetch(FetchDescriptor<Event>()).first)

        #expect(created.eventID == event.id)
        #expect(event.title == "Morning task")
        #expect(createMutation.command == .calendarEventPlan(eventID: event.id))
        #expect(createMutation.affectedEntityIDs.contains(event.id))
        #expect(createMutation.affectedEntityIDs.contains(human.id))
        #expect(createMutation.note == "calendar.event.created")

        let completed = executor.toggleCompletion(
            event: event,
            occurrenceDate: start,
            pets: [],
            executorId: "human-1",
            note: "test.calendar.complete"
        )
        let completionMutation = try #require(revisionCenter.lastMutation)

        #expect(completed.isCompleted)
        #expect(event.isOccurrenceMarkedComplete(on: start))
        #expect(completionMutation.command == .calendarEventCompletion(eventID: event.id, isCompleted: true))
        #expect(completionMutation.affectedEntityIDs.contains(event.id))
        #expect(completionMutation.affectedEntityIDs.contains(human.id))
        #expect(completionMutation.note == "test.calendar.complete")

        let deletion = executor.delete(
            event: event,
            occurrenceDate: start,
            scope: .wholeEvent,
            note: "test.calendar.delete"
        )
        let deletionMutation = try #require(revisionCenter.lastMutation)
        let remainingEvents = try context.fetch(FetchDescriptor<Event>())

        #expect(deletion == .deletedEvent(event.id))
        #expect(remainingEvents.isEmpty)
        #expect(deletionMutation.command == .calendarEventDeletion(eventID: event.id, scope: "wholeEvent"))
        #expect(deletionMutation.affectedEntityIDs == [event.id])
        #expect(deletionMutation.note == "test.calendar.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func dashboardRecordCommandExecutorPublishesWeightExpenseAndDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Alex")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let executor = DashboardRecordCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let weightCommand = DomainCommand.weightEntry(entityID: pet.id, entityKind: EntityKind.pet.rawValue)
        let weight = executor.recordPetWeight(
            pet: pet,
            weight: 4.2,
            date: makeDate(year: 2026, month: 6, day: 10, hour: 8, minute: 30),
            executorId: human.id.uuidString,
            awardsReward: true,
            ledgerSource: .detail,
            command: weightCommand,
            note: "test.dashboard.weight"
        )
        let weightMutation = try #require(revisionCenter.lastMutation)

        #expect(weight.subjectID == pet.id)
        #expect(weightMutation.command == weightCommand)
        #expect(weightMutation.affectedEntityIDs.contains(pet.id))
        #expect(weightMutation.affectedEntityIDs.contains(weight.logID))
        #expect(weightMutation.note == "test.dashboard.weight")

        let petWeightLog = try #require(try context.fetch(FetchDescriptor<PetWeightLog>()).first)
        let deleteWeight = executor.deletePetWeight(petWeightLog, pet: pet, note: "test.dashboard.weight.delete")
        let weightDeleteMutation = try #require(revisionCenter.lastMutation)
        #expect(deleteWeight.recordID == weight.logID)
        #expect(weightDeleteMutation.command == .weightDelete(
            entityID: pet.id,
            entityKind: EntityKind.pet.rawValue,
            recordID: weight.logID
        ))
        #expect(weightDeleteMutation.note == "test.dashboard.weight.delete")

        let expenseCommand = DomainCommand.quickHumanExpense(humanID: human.id)
        let expense = executor.recordHumanExpense(
            human: human,
            amount: 12.5,
            date: makeDate(year: 2026, month: 6, day: 11, hour: 9, minute: 0),
            note: "Lunch",
            command: expenseCommand,
            revisionNote: "test.dashboard.expense"
        )
        let expenseMutation = try #require(revisionCenter.lastMutation)
        #expect(expense.subjectID == human.id)
        #expect(expenseMutation.command == expenseCommand)
        #expect(expenseMutation.affectedEntityIDs.contains(human.id))
        #expect(expenseMutation.affectedEntityIDs.contains(expense.logID))
        #expect(expenseMutation.note == "test.dashboard.expense")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func dashboardSharedExpenseWritesFactAndRevisionForMissingExecutor() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let first = Pet(name: "Milo", species: "猫")
        let second = Pet(name: "Luna", species: "cat")
        context.insert(first)
        context.insert(second)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.removeObject(forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()

        let executor = DashboardRecordCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let missingExecutorID = UUID().uuidString
        let result = executor.recordSharedPetExpense(
            sourcePet: first,
            targets: [first, second],
            amount: 24,
            date: makeDate(year: 2026, month: 6, day: 11, hour: 9, minute: 0),
            category: .food,
            note: "Shared bag",
            executorId: missingExecutorID,
            command: .expenseEntry(entityID: first.id, entityKind: EntityKind.pet.rawValue),
            revisionNote: "test.dashboard.shared.expense.missing.executor"
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let mutation = try #require(revisionCenter.lastMutation)
        #expect(result.didWriteFact == true)
        #expect(result.allowsDerivedEffects == true)
        #expect(result.coconutDelta == 0)
        #expect(Set(result.targetPetIDs) == Set([first.id, second.id]))
        #expect(sessions.count == 1)
        #expect(expenses.count == 2)
        #expect(Set(expenses.compactMap { $0.pet?.id }) == Set([first.id, second.id]))
        #expect(ledgerEvents.count == 2)
        #expect(Set(ledgerEvents.map(\.legacyModelId)) == Set(expenses.map(\.id.uuidString)))
        #expect(walletEntries.isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .expenseEntry(entityID: first.id, entityKind: EntityKind.pet.rawValue))
        #expect(mutation.wroteBusinessFact == true)
    }

    @MainActor
    @Test func reminderCommandExecutorPublishesReminderRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "Daily check", startDate: makeDate(year: 2026, month: 6, day: 10), eventType: EventType.task.rawValue)
        let reminder = Reminder(event: event, scheduledAt: makeDate(year: 2026, month: 6, day: 10, hour: 8, minute: 0))
        event.reminders.append(reminder)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let executor = ReminderCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let completed = executor.completeWithCoconutReward(
            reminder,
            by: "human-1",
            amount: 0,
            title: "Daily check",
            note: "test.reminder.complete"
        )
        let completeMutation = try #require(revisionCenter.lastMutation)

        #expect(completed.reminderID == reminder.id)
        #expect(completed.eventID == event.id)
        #expect(reminder.statusEnum == .completed)
        #expect(completeMutation.command == .reminderCompletion(reminderID: reminder.id))
        #expect(completeMutation.affectedEntityIDs == [reminder.id, event.id])
        #expect(completeMutation.note == "test.reminder.complete")

        let reopened = executor.reopen(reminder, by: "human-1", reschedule: false, note: "test.reminder.reopen")
        let reopenMutation = try #require(revisionCenter.lastMutation)
        #expect(reopened.action == "reopen")
        #expect(reminder.statusEnum == .pending)
        #expect(reopenMutation.command == .reminderCompletion(reminderID: reminder.id))
        #expect(reopenMutation.note == "test.reminder.reopen")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 2)
    }

    @MainActor
    @Test func petDocumentCommandExecutorPublishesCreateUpdateDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let executor = PetDocumentCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let input = PetDocumentCreateCommandInput(
            title: "Passport",
            category: .passport,
            issuingAuthority: "City",
            notes: "  primary doc  ",
            issueDate: makeDate(year: 2026, month: 6, day: 1),
            expiryDate: nil,
            cost: 0,
            payerId: nil,
            documentNumber: "P-1",
            attachments: []
        )
        let created = executor.createDocument(input: input, pet: pet, note: "test.document.create")
        let createMutation = try #require(revisionCenter.lastMutation)
        let document = try #require(try context.fetch(FetchDescriptor<PetDocument>()).first)

        #expect(created.petID == pet.id)
        #expect(created.documentID == document.id)
        #expect(createMutation.command == .petDocumentCreate(petID: pet.id, category: DocumentCategory.passport.rawValue))
        #expect(createMutation.affectedEntityIDs.contains(pet.id))
        #expect(createMutation.affectedEntityIDs.contains(document.id))
        #expect(createMutation.note == "test.document.create")

        let updateInput = PetDocumentUpdateCommandInput(
            title: "Passport updated",
            category: .registration,
            issuingAuthority: "Vet",
            notes: "updated",
            issueDate: nil,
            expiryDate: nil,
            cost: 0,
            attachmentData: nil,
            clearsAttachment: false
        )
        let updated = executor.updateDocument(document, pet: pet, input: updateInput, note: "test.document.update")
        let updateMutation = try #require(revisionCenter.lastMutation)
        #expect(updated.documentID == document.id)
        #expect(document.title == "Passport updated")
        #expect(updateMutation.command == .petDocumentUpdate(petID: pet.id, documentID: document.id))
        #expect(updateMutation.note == "test.document.update")

        let deleted = executor.deleteDocument(document, pet: pet, note: "test.document.delete")
        let deleteMutation = try #require(revisionCenter.lastMutation)
        #expect(deleted.documentID == document.id)
        let documents = try context.fetch(FetchDescriptor<PetDocument>())
        #expect(documents.isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: PetDocument.self), id: document.id, context: context)?.isDeletionTombstone == true)
        #expect(deleteMutation.command == .petDocumentDelete(petID: pet.id, documentID: document.id))
        #expect(deleteMutation.note == "test.document.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func insuranceCommandExecutorPublishesPolicyAndClaimRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let executor = InsuranceCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let created = executor.savePolicy(
            existing: nil,
            pet: pet,
            input: InsurancePolicySaveCommandInput(
                companyName: "Ohana Care",
                policyNumber: "P-1",
                productName: "Care Plus",
                annualPremium: 120,
                coverageAmount: 1000,
                startDate: makeDate(year: 2026, month: 6, day: 8),
                renewalDate: makeDate(year: 2027, month: 6, day: 8),
                notes: "primary",
                paymentFrequency: .annual,
                paymentDayOfMonth: 8,
                showInCalendar: false,
                otherFeeAmount: 0,
                otherFeeNote: "",
                autoGeneratesPayments: false,
                executorId: "human-1"
            ),
            note: "test.insurance.policy.create"
        )
        let createMutation = try #require(revisionCenter.lastMutation)
        let policy = try #require(try context.fetch(FetchDescriptor<PetInsurance>()).first)

        #expect(created.policyID == policy.id)
        #expect(createMutation.command == .insurancePolicy(petID: pet.id, policyID: policy.id, action: "create"))
        #expect(createMutation.affectedEntityIDs == [pet.id, policy.id])
        #expect(createMutation.note == "test.insurance.policy.create")

        let deactivated = executor.setPolicyActive(
            policy,
            isActive: false,
            pet: pet,
            note: "test.insurance.policy.deactivate"
        )
        let deactivateMutation = try #require(revisionCenter.lastMutation)
        #expect(deactivated.didChange == true)
        #expect(policy.isActive == false)
        #expect(deactivateMutation.command == .insurancePolicy(petID: pet.id, policyID: policy.id, action: "deactivate"))
        #expect(deactivateMutation.note == "test.insurance.policy.deactivate")

        let claim = executor.createClaim(
            insurance: policy,
            pet: pet,
            input: InsuranceClaimCommandInput(
                claimDate: makeDate(year: 2026, month: 6, day: 12),
                incidentDate: makeDate(year: 2026, month: 6, day: 10),
                totalExpense: 80,
                claimedAmount: 50,
                status: .approved,
                note: "covered",
                executorId: "human-1"
            ),
            note: "test.insurance.claim.create"
        )
        let claimMutation = try #require(revisionCenter.lastMutation)
        let claimModel = try #require(try context.fetch(FetchDescriptor<InsuranceClaim>()).first)
        #expect(claim.claimID == claimModel.id)
        #expect(claimMutation.command == .insuranceClaim(
            petID: pet.id,
            policyID: policy.id,
            claimID: claim.claimID,
            action: "create"
        ))
        #expect(claimMutation.affectedEntityIDs.contains(pet.id))
        #expect(claimMutation.affectedEntityIDs.contains(policy.id))
        #expect(claimMutation.affectedEntityIDs.contains(claim.claimID))
        #expect(claimMutation.note == "test.insurance.claim.create")

        let deleted = executor.deleteClaim(
            claimModel,
            insurance: policy,
            pet: pet,
            note: "test.insurance.claim.delete"
        )
        let deleteMutation = try #require(revisionCenter.lastMutation)
        #expect(deleted.claimID == claim.claimID)
        #expect(try context.fetch(FetchDescriptor<InsuranceClaim>()).isEmpty)
        #expect(deleteMutation.command == .insuranceClaim(
            petID: pet.id,
            policyID: policy.id,
            claimID: claim.claimID,
            action: "delete"
        ))
        #expect(deleteMutation.note == "test.insurance.claim.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 4)
    }

    @MainActor
    @Test func petHealthCommandExecutorPublishesRecordSymptomHeatAndDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let executor = PetHealthCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let health = try #require(executor.recordHealth(
            pet: pet,
            input: PetHealthRecordCommandInput(
                type: .vaccine,
                date: makeDate(year: 2026, month: 6, day: 8),
                name: "Rabies",
                note: "ok",
                vetName: "Ohana Vet",
                cost: 0,
                expirationDate: nil,
                nextCheckupDate: nil,
                executorId: executorHuman.id.uuidString,
                source: .detail,
                includesNameInNote: true
            ),
            awardsReward: false,
            schedulesReminderNotification: false,
            note: "test.health.record"
        ))
        let healthMutation = try #require(revisionCenter.lastMutation)
        #expect(healthMutation.command == .petHealthRecord(petID: pet.id, type: HealthLogType.vaccine.rawValue))
        #expect(healthMutation.affectedEntityIDs == [pet.id, health.logID])
        #expect(healthMutation.note == "test.health.record")

        let symptom = try #require(executor.recordSymptom(
            pet: pet,
            input: PetSymptomCommandInput(
                date: makeDate(year: 2026, month: 6, day: 9),
                category: .skin,
                symptomName: "itchy",
                severity: .mild,
                note: "dry skin",
                photoData: nil
            ),
            note: "test.health.symptom"
        ))
        let symptomMutation = try #require(revisionCenter.lastMutation)
        #expect(symptomMutation.command == .petHealthRecord(petID: pet.id, type: "symptom"))
        #expect(symptomMutation.affectedEntityIDs == [pet.id, symptom.logID, symptom.ledgerEventID])
        #expect(symptomMutation.note == "test.health.symptom")

        let heat = try #require(executor.recordHeatCycle(
            pet: pet,
            input: PetHeatCycleCommandInput(
                startDate: makeDate(year: 2026, month: 6, day: 10),
                endDate: makeDate(year: 2026, month: 6, day: 16),
                status: .estrus,
                note: "watch",
                isMated: false,
                expectedDeliveryDate: nil
            ),
            note: "test.health.heat"
        ))
        let heatMutation = try #require(revisionCenter.lastMutation)
        #expect(heatMutation.command == .petHealthRecord(petID: pet.id, type: "heat"))
        #expect(heatMutation.affectedEntityIDs == [pet.id, heat.logID])
        #expect(heatMutation.note == "test.health.heat")

        let healthLog = try #require(try context.fetch(FetchDescriptor<PetHealthLog>()).first)
        let deletedHealth = executor.deleteHealthLog(healthLog, pet: pet, note: "test.health.delete.health")
        let deleteHealthMutation = try #require(revisionCenter.lastMutation)
        #expect(deletedHealth.recordID == health.logID)
        #expect(deleteHealthMutation.command == .petHealthDelete(petID: pet.id, kind: "health", recordID: health.logID))
        #expect(deleteHealthMutation.note == "test.health.delete.health")

        let symptomLog = try #require(try context.fetch(FetchDescriptor<SymptomLog>()).first)
        let deletedSymptom = executor.deleteSymptomLog(symptomLog, pet: pet, note: "test.health.delete.symptom")
        let deleteSymptomMutation = try #require(revisionCenter.lastMutation)
        #expect(deletedSymptom.recordID == symptom.logID)
        #expect(deleteSymptomMutation.command == .petHealthDelete(petID: pet.id, kind: "symptom", recordID: symptom.logID))
        #expect(deleteSymptomMutation.note == "test.health.delete.symptom")

        let heatLog = try #require(try context.fetch(FetchDescriptor<HeatCycleLog>()).first)
        let deletedHeat = executor.deleteHeatCycleLog(heatLog, pet: pet, note: "test.health.delete.heat")
        let deleteHeatMutation = try #require(revisionCenter.lastMutation)
        #expect(deletedHeat.recordID == heat.logID)
        #expect(deleteHeatMutation.command == .petHealthDelete(petID: pet.id, kind: "heat", recordID: heat.logID))
        #expect(deleteHeatMutation.note == "test.health.delete.heat")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 6)
    }

    @MainActor
    @Test func quickFeedExecutorManualRecordPublishesFeedRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let beforeRevision = revisionCenter.homeRevision.value
        let executor = QuickFeedCommandExecutor(context: context, revisionCenter: revisionCenter)
        let result = executor.recordManual(
            pet: pet,
            targets: [],
            grams: 42,
            foodKind: .dry,
            saveAsDefault: true,
            foodRecords: [],
            allEvents: [],
            executorId: executorHuman.id.uuidString
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let mutation = try #require(revisionCenter.lastMutation)
        #expect(result.didRecord == true)
        #expect(result.grams == 42)
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.careType == .feeding)
        #expect(logs.first?.amountGrams == 42)
        #expect(logs.first?.foodKind == .dry)
        #expect(ledgerEvents.contains { $0.legacyModelId == logs.first?.id.uuidString })
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .feedLog(petID: pet.id, source: "manual"))
        #expect(mutation.affectedEntityIDs == [pet.id])
        #expect(mutation.wroteBusinessFact == true)
    }

    @MainActor
    @Test func quickFeedExecutorManualWritesFactAndRevisionForDeceasedExecutorFallbackOwner() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 8)
        let activeHuman = Human(name: "Active")
        let human = Human(name: "Former caretaker")
        human.passedAwayDate = now
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(activeHuman)
        context.insert(human)
        context.insert(pet)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()
        let beforeRevision = revisionCenter.homeRevision.value
        let executor = QuickFeedCommandExecutor(context: context, revisionCenter: revisionCenter)
        let result = executor.recordManual(
            pet: pet,
            targets: [],
            grams: 42,
            foodKind: .dry,
            saveAsDefault: true,
            foodRecords: [],
            allEvents: [],
            executorId: human.id.uuidString
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(result.didRecord)
        #expect(result.allowsDerivedEffects)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != human.id.uuidString })
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(revisionCenter.lastMutation != nil)
    }

    @MainActor
    @Test func quickFeedExecutorManualWritesFactAndDefaultsForMissingExecutor() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.mainFoodKind = .wet
        pet.dailyPortionGrams = 18
        context.insert(pet)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
        }
        defaults.removeObject(forKey: "currentActiveHumanId")

        let beforeRevision = revisionCenter.homeRevision.value
        let executor = QuickFeedCommandExecutor(context: context, revisionCenter: revisionCenter)
        let missingExecutorID = UUID().uuidString
        let result = executor.recordManual(
            pet: pet,
            targets: [],
            grams: 42,
            foodKind: .dry,
            saveAsDefault: true,
            foodRecords: [],
            allEvents: [],
            executorId: missingExecutorID
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let mutation = try #require(revisionCenter.lastMutation)
        #expect(result.didRecord == true)
        #expect(result.allowsDerivedEffects == true)
        #expect(result.coconutDelta == 0)
        #expect(pet.mainFoodKind == .dry)
        #expect(pet.dailyPortionGrams == 42)
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.careType == .feeding)
        #expect(logs.first?.amountGrams == 42)
        #expect(ledgerEvents.contains { $0.legacyModelId == logs.first?.id.uuidString })
        #expect(walletEntries.isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .feedLog(petID: pet.id, source: "manual"))
        #expect(mutation.affectedEntityIDs == [pet.id])
        #expect(mutation.wroteBusinessFact == true)
    }

    @MainActor
    @Test func quickFeedExecutorTreatWritesFactAndRevisionForDeceasedExecutor() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 8)
        let activeHuman = Human(name: "Active")
        let human = Human(name: "Former caretaker")
        human.passedAwayDate = now
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(activeHuman)
        context.insert(human)
        context.insert(pet)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()
        let beforeRevision = revisionCenter.homeRevision.value
        let executor = QuickFeedCommandExecutor(context: context, revisionCenter: revisionCenter)
        let result = executor.recordTreat(
            pet: pet,
            grams: 12,
            treatKind: .freezeDried,
            executorId: human.id.uuidString
        )

        #expect(result.didRecord)
        #expect(result.allowsDerivedEffects)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(revisionCenter.lastMutation != nil)
    }

    @MainActor
    @Test func quickFeedExecutorTreatWritesFactAndRevisionForMissingExecutor() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
        }
        defaults.removeObject(forKey: "currentActiveHumanId")

        let beforeRevision = revisionCenter.homeRevision.value
        let executor = QuickFeedCommandExecutor(context: context, revisionCenter: revisionCenter)
        let missingExecutorID = UUID().uuidString
        let result = executor.recordTreat(
            pet: pet,
            grams: 12,
            treatKind: .freezeDried,
            executorId: missingExecutorID
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let mutation = try #require(revisionCenter.lastMutation)
        #expect(result.didRecord == true)
        #expect(result.allowsDerivedEffects == true)
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.careType == .feeding)
        #expect(logs.first?.amountGrams == 12)
        #expect(logs.first?.treatKind == .freezeDried)
        #expect(ledgerEvents.contains { $0.legacyModelId == logs.first?.id.uuidString })
        #expect(walletEntries.isEmpty)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .feedLog(petID: pet.id, source: "treat"))
        #expect(mutation.affectedEntityIDs == [pet.id])
        #expect(mutation.wroteBusinessFact == true)
    }

    @MainActor
    @Test func dashboardRecordCommandServiceDeletesPetWeightAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let log = PetWeightLog(date: makeDate(year: 2026, month: 6, day: 8), weight: 4.2, pet: pet)
        let ledger = CareLedgerEvent(
            occurredAt: log.date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "weight",
            amountValue: log.weightInKg,
            amountUnit: "kg",
            legacyModelName: "PetWeightLog",
            legacyModelId: log.id.uuidString
        )
        let unrelatedLedger = CareLedgerEvent(
            occurredAt: log.date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "weight",
            amountValue: 4.8,
            amountUnit: "kg",
            legacyModelName: "PetWeightLog",
            legacyModelId: "unrelated-weight-log"
        )
        context.insert(pet)
        context.insert(log)
        context.insert(ledger)
        context.insert(unrelatedLedger)
        try context.save()

        let result = DashboardRecordCommandService.deletePetWeight(log, pet: pet, context: context)

        let remainingLogs = try context.fetch(FetchDescriptor<PetWeightLog>())
        let remainingLedgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result.subjectID == pet.id)
        #expect(result.subjectKind == EntityKind.pet.rawValue)
        #expect(result.recordID == log.id)
        #expect(result.recordKind == "PetWeightLog")
        #expect(result.removedLedgerEventIDs == [ledger.id])
        #expect(remainingLogs.isEmpty)
        #expect(remainingLedgerEvents.map(\.id) == [unrelatedLedger.id])
    }

    @MainActor
    @Test func dashboardRecordCommandServiceDeletesHumanExpenseAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let log = PetExpenseLog(
            date: makeDate(year: 2026, month: 6, day: 8),
            amount: 29,
            category: .food,
            note: "Food",
            executorId: human.id.uuidString
        )
        let ledger = CareLedgerEvent(
            occurredAt: log.date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .expense,
            actionType: "food",
            amountValue: log.amount,
            amountUnit: "currency",
            legacyModelName: "PetExpenseLog",
            legacyModelId: log.id.uuidString
        )
        let unrelatedLedger = CareLedgerEvent(
            occurredAt: log.date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .expense,
            actionType: "food",
            amountValue: 12,
            amountUnit: "currency",
            legacyModelName: "PetExpenseLog",
            legacyModelId: "unrelated-expense-log"
        )
        context.insert(human)
        context.insert(log)
        context.insert(ledger)
        context.insert(unrelatedLedger)
        try context.save()

        let result = DashboardRecordCommandService.deleteHumanExpense(log, human: human, context: context)

        let remainingExpenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let remainingLedgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result.subjectID == human.id)
        #expect(result.subjectKind == EntityKind.human.rawValue)
        #expect(result.recordID == log.id)
        #expect(result.recordKind == "PetExpenseLog")
        #expect(result.removedLedgerEventIDs == [ledger.id])
        #expect(remainingExpenses.isEmpty)
        #expect(remainingLedgerEvents.map(\.id) == [unrelatedLedger.id])
    }

    @MainActor
    @Test func petMilestoneCommandsDoNotCreateLegacyCareLedgerEvents() throws {
        let rootURL = repositoryRootURL()
        let commands = try source("Ohana/Features/Milestones/PetMilestoneCommands.swift", rootURL: rootURL)

        #expect(!commands.contains("recordLedger("))
        #expect(!commands.contains("careLedger.record("))
        #expect(commands.contains("ledgerEvents(for: milestone"))
        #expect(commands.contains("PhysicalDeletionService.deletePetScopedRecord"))
    }

    @MainActor
    @Test func petMilestoneCommandServiceSeedsSystemMilestonesOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.birthday = makeDate(year: 2024, month: 2, day: 8)
        pet.homeDate = makeDate(year: 2024, month: 4, day: 8)
        let weight = PetWeightLog(date: makeDate(year: 2026, month: 6, day: 8), weight: 4.8, pet: pet)
        pet.weightLogs.append(weight)
        context.insert(pet)
        context.insert(weight)
        try context.save()

        let first = PetMilestoneCommandService.seedSystemMilestones(for: pet, context: context)
        let second = PetMilestoneCommandService.seedSystemMilestones(for: pet, context: context)

        let milestones = try context.fetch(FetchDescriptor<PetMilestone>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(first.petID == pet.id)
        #expect(first.milestoneIDs.count == 3)
        #expect(second.milestoneIDs.isEmpty)
        #expect(milestones.count == 3)
        #expect(ledgerEvents.isEmpty)
    }

    @MainActor
    @Test func petMilestoneCommandServiceCreatesRewardsAndDeletesLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let questManager = TestQuestManagerProjection.manager
        let previousCoconutCount = questManager.coconutCount
        let previousLogs = questManager.coconutLogs
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            questManager.coconutCount = previousCoconutCount
            questManager.coconutLogs = previousLogs
            questManager.persistQuestFlags()
        }
        defaults.removeObject(forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
            memberKey: "system"
        )
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        context.insert(pet)
        try context.save()

        let createResult = PetMilestoneCommandService.createMilestone(
            input: PetMilestoneCommandInput(
                date: makeDate(year: 2026, month: 6, day: 8),
                title: " First beach day ",
                emoji: "",
                notes: "Sunny",
                photoData: Data([1, 2, 3]),
                location: "Beach"
            ),
            pet: pet,
            context: context
        )

        var milestones = try context.fetch(FetchDescriptor<PetMilestone>())
        var ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let createdMilestone = try #require(milestones.first)
        #expect(createResult.petID == pet.id)
        #expect(createResult.milestoneIDs == [createdMilestone.id])
        #expect(createResult.coconutDelta == 0)
        #expect(createdMilestone.title == "First beach day")
        #expect(createdMilestone.emoji == "🎉")
        #expect(createdMilestone.pet?.id == pet.id)
        #expect(createdMilestone.hasPhotoAttachment)
        #expect(createdMilestone.canAttemptPhotoAttachmentLoad)
        #expect(createdMilestone.photoImageSignature == MediaPayloadSignature.signature(for: Data([1, 2, 3])))
        #expect(createdMilestone.photoThumbnailSignature == createdMilestone.photoImageSignature)
        #expect(ledgerEvents.isEmpty)
        let matchingLegacyLedger = CareLedgerEvent(
            occurredAt: createdMilestone.date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .milestone,
            actionType: "manual",
            legacyModelName: "PetMilestone",
            legacyModelId: createdMilestone.id.uuidString
        )
        let unrelatedLedger = CareLedgerEvent(
            occurredAt: createdMilestone.date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .milestone,
            actionType: "manual",
            legacyModelName: "PetMilestone",
            legacyModelId: "unrelated-milestone"
        )
        context.insert(matchingLegacyLedger)
        context.insert(unrelatedLedger)
        try context.save()

        let deleteResult = PetMilestoneCommandService.deleteMilestone(
            createdMilestone,
            pet: pet,
            context: context
        )

        milestones = try context.fetch(FetchDescriptor<PetMilestone>())
        ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(deleteResult.petID == pet.id)
        #expect(deleteResult.milestoneID == createdMilestone.id)
        #expect(deleteResult.removedLedgerEventIDs == [matchingLegacyLedger.id])
        #expect(milestones.isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: PetMilestone.self), id: createdMilestone.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: CareLedgerEvent.self), id: matchingLegacyLedger.id, context: context)?.isDeletionTombstone == true)
        #expect(ledgerEvents.map(\.id) == [unrelatedLedger.id])
    }

    @MainActor
    @Test func petMilestoneCommandExecutorPublishesSeedRecordAndDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.birthday = makeDate(year: 2024, month: 2, day: 8)
        pet.homeDate = makeDate(year: 2024, month: 4, day: 8)
        let questManager = TestQuestManagerProjection.manager
        let previousCoconutCount = questManager.coconutCount
        let previousLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = previousCoconutCount
            questManager.coconutLogs = previousLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        context.insert(pet)
        try context.save()

        let executor = PetMilestoneCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let seeded = executor.seedSystemMilestones(for: pet, note: "test.milestone.seed")
        let seedMutation = try #require(revisionCenter.lastMutation)
        #expect(seeded.milestoneIDs.count == 2)
        #expect(seedMutation.command == .petMilestoneSeed(petID: pet.id))
        #expect(seedMutation.affectedEntityIDs.contains(pet.id))
        #expect(seedMutation.note == "test.milestone.seed")

        let created = executor.createMilestone(
            input: PetMilestoneCommandInput(
                date: makeDate(year: 2026, month: 6, day: 8),
                title: " First beach day ",
                emoji: "",
                notes: "Sunny",
                photoData: Data([1, 2, 3]),
                location: "Beach"
            ),
            pet: pet,
            note: "test.milestone.record"
        )
        let recordMutation = try #require(revisionCenter.lastMutation)
        let createdID = try #require(created.milestoneIDs.first)
        let createdMilestone = try #require(
            try context.fetch(FetchDescriptor<PetMilestone>()).first { $0.id == createdID }
        )
        #expect(recordMutation.command == .petMilestoneRecord(petID: pet.id))
        #expect(recordMutation.affectedEntityIDs == [pet.id, createdID])
        #expect(recordMutation.note == "test.milestone.record")

        let deleted = executor.deleteMilestone(createdMilestone, pet: pet, note: "test.milestone.delete")
        let deleteMutation = try #require(revisionCenter.lastMutation)
        #expect(deleted.milestoneID == createdID)
        #expect(deleteMutation.command == .petMilestoneDelete(petID: pet.id, milestoneID: createdID))
        #expect(deleteMutation.affectedEntityIDs.contains(pet.id))
        #expect(deleteMutation.affectedEntityIDs.contains(createdID))
        #expect(deleteMutation.note == "test.milestone.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func petDocumentCommandServiceCreatesExpenseLedgerAndPassportSync() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let result = PetDocumentCommandService.createDocument(
            input: PetDocumentCreateCommandInput(
                title: " Passport ",
                category: .passport,
                issuingAuthority: "Vet Office",
                notes: "Bring original",
                issueDate: makeDate(year: 2026, month: 6, day: 1),
                expiryDate: makeDate(year: 2027, month: 6, day: 1),
                cost: 45,
                payerId: human.id.uuidString,
                documentNumber: "P-123",
                attachments: [
                    PetDocumentAttachmentCommandInput(data: Data([1, 2, 3]), filename: "", isImage: true),
                    PetDocumentAttachmentCommandInput(data: Data([4, 5]), filename: "receipt.pdf", isImage: false)
                ]
            ),
            pet: pet,
            context: context,
            now: makeDate(year: 2026, month: 6, day: 8)
        )

        let documents = try context.fetch(FetchDescriptor<PetDocument>())
        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let document = try #require(documents.first)
        let expense = try #require(expenses.first)
        let ledger = try #require(ledgerEvents.first)
        #expect(result.petID == pet.id)
        #expect(result.documentID == document.id)
        #expect(result.expenseLogIDs == [expense.id])
        #expect(result.ledgerEventIDs == [ledger.id])
        #expect(document.title == "Passport")
        #expect(document.documentCategory == .passport)
        #expect(document.attachmentFilename == "image.jpg")
        #expect(document.hasLegacyAttachment)
        #expect(!document.legacyAttachmentSignature.isEmpty)
        #expect(document.attachments.count == 2)
        #expect(document.attachments.allSatisfy { $0.hasDataAttachment && !$0.dataSignature.isEmpty })
        #expect(pet.passportNumber == "P-123")
        #expect(expense.pet?.id == pet.id)
        #expect(expense.executorId == human.id.uuidString)
        #expect(expense.expenseCategory == .medical)
        #expect(ledger.legacyModelName == "PetExpenseLog")
        #expect(ledger.legacyModelId == expense.id.uuidString)
        #expect(ledger.amountValue == 45)
    }

    @MainActor
    @Test func petDocumentCommandServiceUpdatesAndDeletesDocument() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let document = PetDocument(title: "Old", category: .medical, pet: pet)
        document.attachmentData = Data([9, 9])
        document.attachmentFilename = "old.jpg"
        let ledger = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: "document",
            legacyModelName: "PetDocument",
            legacyModelId: document.id.uuidString
        )
        let unrelatedLedger = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: "document",
            legacyModelName: "PetDocument",
            legacyModelId: "unrelated-document"
        )
        context.insert(pet)
        context.insert(document)
        context.insert(ledger)
        context.insert(unrelatedLedger)
        try context.save()

        let updateResult = PetDocumentCommandService.updateDocument(
            document,
            pet: pet,
            input: PetDocumentUpdateCommandInput(
                title: "",
                category: .registration,
                issuingAuthority: "City",
                notes: "Updated",
                issueDate: nil,
                expiryDate: nil,
                cost: -10,
                attachmentData: nil,
                clearsAttachment: true
            ),
            context: context
        )

        #expect(updateResult.documentID == document.id)
        #expect(document.title == "Momo登记证")
        #expect(document.documentCategory == .registration)
        #expect(document.issuingAuthority == "City")
        #expect(document.cost == 0)
        #expect(document.attachmentData == nil)
        #expect(document.attachmentFilename.isEmpty)
        #expect(document.legacyAttachmentState == .absent)
        #expect(document.legacyAttachmentSignature.isEmpty)

        let deleteResult = PetDocumentCommandService.deleteDocument(document, pet: pet, context: context)

        let documents = try context.fetch(FetchDescriptor<PetDocument>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(deleteResult.petID == pet.id)
        #expect(deleteResult.documentID == document.id)
        #expect(deleteResult.removedLedgerEventIDs.isEmpty)
        #expect(documents.isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: PetDocument.self), id: document.id, context: context)?.isDeletionTombstone == true)
        #expect(Set(ledgerEvents.map(\.id)) == Set([ledger.id, unrelatedLedger.id]))
    }

    @MainActor
    @Test func petDocumentCommandServiceUpdatesAttachmentInputs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let document = PetDocument(title: "Old", category: .medical, pet: pet)
        document.attachmentData = Data([1])
        document.attachmentFilename = "old.jpg"
        context.insert(pet)
        context.insert(document)
        try context.save()

        let result = PetDocumentCommandService.updateDocument(
            document,
            pet: pet,
            input: PetDocumentUpdateCommandInput(
                title: "New",
                category: .medical,
                issuingAuthority: "Vet",
                notes: "",
                issueDate: nil,
                expiryDate: nil,
                cost: 0,
                attachmentData: nil,
                clearsAttachment: false,
                attachments: [
                    PetDocumentAttachmentCommandInput(
                        data: Data([9, 8, 7]),
                        filename: "new.pdf",
                        isImage: false
                    )
                ]
            ),
            context: context
        )

        let attachments = try context.fetch(FetchDescriptor<PetDocumentAttachment>())
        #expect(result.documentID == document.id)
        #expect(document.attachmentData == Data([9, 8, 7]))
        #expect(document.attachmentFilename == "new.pdf")
        #expect(document.hasLegacyAttachment)
        #expect(!document.legacyAttachmentSignature.isEmpty)
        #expect(document.attachments.count == 1)
        #expect(document.attachments.first?.filename == "new.pdf")
        #expect(document.attachments.first?.isImage == false)
        #expect(document.attachments.first?.hasDataAttachment == true)
        #expect(document.attachments.first?.dataSignature.isEmpty == false)
        #expect(attachments.count == 1)
    }

    @MainActor
    @Test func humanWishlistCommandServiceCreatesAndDeletesItem() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let createdAt = makeDate(year: 2026, month: 6, day: 8)
        let createResult = try HumanWishlistCommandService.createItem(
            input: HumanWishlistCommandInput(title: "  New headphones  ", cost: 35, createdAt: createdAt),
            for: human,
            context: context
        )

        var items = try context.fetch(FetchDescriptor<WishlistItem>())
        let item = try #require(items.first)
        #expect(createResult.humanID == human.id)
        #expect(createResult.itemID == item.id)
        #expect(createResult.coconutDelta == 0)
        #expect(item.title == "New headphones")
        #expect(item.cost == 35)
        #expect(item.creatorId == human.id.uuidString)
        #expect(item.createdAt == createdAt)

        let deleteResult = try HumanWishlistCommandService.deleteItem(item, for: human, context: context)

        items = try context.fetch(FetchDescriptor<WishlistItem>())
        #expect(deleteResult.humanID == human.id)
        #expect(deleteResult.itemID == item.id)
        #expect(deleteResult.removedLedgerEventIDs.isEmpty)
        #expect(items.isEmpty)
    }

    @MainActor
    @Test func humanWishlistCommandServiceRedeemsWithLedgerAndCoconutDelta() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 100
        let item = WishlistItem(title: "Camera", cost: 40, creatorId: human.id.uuidString)
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 100
        questManager.coconutLogs = []
        context.insert(human)
        context.insert(item)
        try context.save()

        let result = try HumanWishlistCommandService.redeemItem(
            item,
            for: human,
            redeemedById: "redeemer-1",
            context: context,
            questManager: questManager
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let ledger = try #require(ledgerEvents.first)
        #expect(result.humanID == human.id)
        #expect(result.itemID == item.id)
        #expect(result.coconutDelta == -40)
        #expect(result.ledgerEventID == ledger.id)
        #expect(result.isRedeemed == true)
        #expect(human.coconutBalance == 60)
        #expect(item.isRedeemed == true)
        #expect(item.redeemedById == "redeemer-1")
        #expect(questManager.coconutCount == 60)
        #expect(ledgerEvents.count == 1)
        #expect(ledger.eventKind == CareLedgerEventKind.coconut.rawValue)
        #expect(ledger.actionType == "humanWishlistRedeem")
        #expect(ledger.legacyModelName == "WishlistItem")
        #expect(ledger.legacyModelId == item.id.uuidString)
        #expect(ledger.coconutDelta == -40)
        #expect(ledger.privacyFieldRaw == HumanPrivateField.wishlist.rawValue)
    }

    @MainActor
    @Test func humanWishlistCommandExecutorPublishesCreateRedeemAndDeleteRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 100
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 100
        questManager.coconutLogs = []
        context.insert(human)
        try context.save()

        let executor = HumanWishlistCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let created = try executor.createItem(
            input: HumanWishlistCommandInput(title: "Camera", cost: 40),
            for: human,
            note: "test.wishlist.create"
        )
        let createMutation = try #require(revisionCenter.lastMutation)
        let item = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(created.itemID == item.id)
        #expect(createMutation.command == .humanWishlistCreate(humanID: human.id))
        #expect(createMutation.affectedEntityIDs == [human.id, item.id])
        #expect(createMutation.note == "test.wishlist.create")

        let redeemed = try executor.redeemItem(
            item,
            for: human,
            redeemedById: "redeemer-1",
            questManager: questManager,
            note: "test.wishlist.redeem"
        )
        let redeemMutation = try #require(revisionCenter.lastMutation)
        let ledgerID = try #require(redeemed.ledgerEventID)
        let unrelatedLedger = CareLedgerEvent(
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .coconut,
            actionType: "humanWishlistRedeem",
            legacyModelName: "WishlistItem",
            legacyModelId: "unrelated-wishlist-item"
        )
        context.insert(unrelatedLedger)
        try context.save()
        #expect(human.coconutBalance == 60)
        #expect(item.isRedeemed == true)
        #expect(redeemMutation.command == .humanWishlistRedeem(humanID: human.id, itemID: item.id))
        #expect(redeemMutation.affectedEntityIDs == [human.id, item.id, ledgerID])
        #expect(redeemMutation.note == "test.wishlist.redeem")

        let deleted = try executor.deleteItem(item, for: human, note: "test.wishlist.delete")
        let deleteMutation = try #require(revisionCenter.lastMutation)
        #expect(deleted.itemID == item.id)
        #expect(deleted.removedLedgerEventIDs == [ledgerID])
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.id) == [unrelatedLedger.id])
        #expect(deleteMutation.command == .humanWishlistDelete(humanID: human.id, itemID: item.id))
        #expect(deleteMutation.affectedEntityIDs == [human.id, item.id, ledgerID])
        #expect(deleteMutation.note == "test.wishlist.delete")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func humanWishlistCommandServiceRejectsInsufficientBalanceWithoutWrites() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 5
        let item = WishlistItem(title: "Camera", cost: 10, creatorId: human.id.uuidString)
        context.insert(human)
        context.insert(item)
        try context.save()

        do {
            _ = try HumanWishlistCommandService.redeemItem(item, for: human, redeemedById: nil, context: context)
            Issue.record("Expected insufficient coconuts")
        } catch let error as HumanWishlistCommandError {
            #expect(error == .insufficientCoconuts(missing: 5))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(human.coconutBalance == 5)
        #expect(item.isRedeemed == false)
        #expect(item.redeemedById == nil)
        #expect(ledgerEvents.isEmpty)
    }

    @MainActor
    @Test func shopPurchaseCommandServiceDeductsBalanceAndWritesLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 500
        let item = try #require(ShopCatalog.item(id: "fx_lime_glow"))
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 500
        questManager.coconutLogs = []
        context.insert(human)
        try context.save()

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Redeemed Lime Glow",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let ledger = try #require(ledgerEvents.first)
        #expect(result.humanID == human.id)
        #expect(result.itemID == item.id)
        #expect(result.didPurchase == true)
        #expect(result.cost == item.cost)
        #expect(result.ledgerEventID == ledger.id)
        #expect(result.transactionKey == "shop:\(item.id):\(human.id.uuidString)")
        #expect(human.coconutBalance == 500 - item.cost)
        #expect(questManager.coconutCount == 500 - item.cost)
        #expect(ledgerEvents.count == 1)
        #expect(ledger.eventKind == CareLedgerEventKind.coconut.rawValue)
        #expect(ledger.actionType == "shopPurchase")
        #expect(ledger.subjectKind == CareLedgerSubjectKind.system.rawValue)
        #expect(ledger.coconutDelta == -item.cost)
        #expect(ledger.metadataJSON.contains(item.id))

        let purchaseRecords = try context.fetch(FetchDescriptor<ShopPurchaseRecord>())
        let purchaseRecord = try #require(purchaseRecords.first)
        #expect(purchaseRecords.count == 1)
        #expect(purchaseRecord.itemId == item.id)
        #expect(purchaseRecord.buyerHumanId == human.id.uuidString)
        #expect(purchaseRecord.transactionKey == "shop:\(item.id):\(human.id.uuidString)")

        let duplicate = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Redeemed Lime Glow",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
        #expect(duplicate.didPurchase == true)
        #expect(duplicate.transactionKey == nil)
        #expect(human.coconutBalance == 500 - item.cost)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).count == 1)

        let duplicateRefundDelete = try ShopPurchaseRecordStore.deleteOwnershipRecord(
            itemID: item.id,
            transactionKey: duplicate.transactionKey,
            context: context
        )
        #expect(duplicateRefundDelete == false)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).count == 1)
    }

    @MainActor
    @Test func shopCatalogRejectsUnknownItemAndDeleteUnknownOwnershipIsNoOp() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        #expect(ShopCatalog.item(id: "not_a_real_shop_item") == nil)

        let deleted = try ShopPurchaseRecordStore.deleteOwnershipRecord(
            itemID: "not_a_real_shop_item",
            transactionKey: "shop:not_a_real_shop_item:missing-human",
            context: context
        )

        #expect(deleted == false)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).isEmpty)
    }

    @MainActor
    @Test func consumableShopPurchaseSpendsButDoesNotCreateOwnershipRecordAndAddsInventory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let startingBalance = item.cost + 20
        human.coconutBalance = startingBalance
        let defaults = UserDefaults.standard
        let oldBackdatePassRaw = defaults.object(forKey: CheckInStreakStore.makeupPackKey)
        defer {
            if let oldBackdatePassRaw {
                defaults.set(oldBackdatePassRaw, forKey: CheckInStreakStore.makeupPackKey)
            } else {
                defaults.removeObject(forKey: CheckInStreakStore.makeupPackKey)
            }
        }
        defaults.removeObject(forKey: CheckInStreakStore.makeupPackKey)
        let services = AppServices()
        context.insert(human)
        try context.save()

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Backdate Pack",
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
        let fulfilled = ShopPurchaseFulfillmentService().fulfillConsumable(
            item: item,
            context: context,
            services: services
        )

        #expect(result.didPurchase)
        #expect(fulfilled)
        #expect(human.coconutBalance == startingBalance - item.cost)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
        #expect(services.shopInventory.consumableSnapshot().backdatePassCount == 3)
        #expect(services.shopInventory.consumeBackdatePass() == 2)
    }

    @MainActor
    @Test func plantDecorPurchaseIsCosmeticOnlyAndDoesNotWritePlantCareFacts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Plant Decor Buyer")
        let plant = Plant(name: "Pothos", wateringIntervalDays: 1, fertilizingIntervalDays: 14)
        let item = try #require(ShopCatalog.item(id: OasisPlantDecorID.hangingVines))
        human.coconutBalance = item.cost
        context.insert(human)
        context.insert(plant)
        try context.save()

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Redeemed Hanging Vines",
            context: context,
            questManager: QuestManager(),
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let purchaseRecords = try context.fetch(FetchDescriptor<ShopPurchaseRecord>())

        #expect(result.didPurchase)
        #expect(result.itemID == item.id)
        #expect(human.coconutBalance == 0)
        #expect(purchaseRecords.count == 1)
        #expect(purchaseRecords.first?.itemId == item.id)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.eventKind == CareLedgerEventKind.coconut.rawValue)
        #expect(ledgerEvents.first?.actionType == "shopPurchase")
        #expect(ledgerEvents.allSatisfy { $0.eventKind != CareLedgerEventKind.plantCare.rawValue })
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(plant.lastWateredDate == nil)
        #expect(plant.lastFertilizedDate == nil)
    }

    @MainActor
    @Test func shopPurchaseRecordStoreMigratesLegacyDefaultsOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let defaultsName = "ShopPurchaseRecordStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }
        defaults.set(
            [
                "fx_lime_glow",
                "title_guardian",
                "boost_double",
                Avatar2DAccess.shopItemId,
                AppIconCatalog.defaultItemId
            ].joined(separator: ","),
            forKey: ShopPurchaseRecordStore.legacyDefaultsKey
        )

        let inserted = try ShopPurchaseRecordStore.migrateLegacyDefaultsIfNeeded(
            context: context,
            defaults: defaults,
            now: Date(timeIntervalSinceReferenceDate: 42)
        )
        let secondPass = try ShopPurchaseRecordStore.migrateLegacyDefaultsIfNeeded(
            context: context,
            defaults: defaults,
            now: Date(timeIntervalSinceReferenceDate: 84)
        )
        let records = try context.fetch(FetchDescriptor<ShopPurchaseRecord>())

        #expect(inserted == 2)
        #expect(secondPass == 0)
        #expect(Set(records.map(\.itemId)) == ["fx_lime_glow", "title_guardian"])
        #expect(records.map(\.isLegacyImport).filter { !$0 }.isEmpty)
        #expect(defaults.bool(forKey: ShopPurchaseRecordStore.legacyMigrationDefaultsKey))
    }

    @MainActor
    @Test func shopPurchaseCommandServiceCofundsFromOtherHumanWallets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let buyer = Human(name: "Ava")
        buyer.coconutBalance = 10
        let contributor = Human(name: "Guan")
        contributor.coconutBalance = 100
        contributor.createdAt = buyer.createdAt.addingTimeInterval(1)
        let item = ShopItem(
            id: "test_cofund_shop_item",
            emoji: "🥥",
            nameText: .init(zh: "合资测试", en: "Cofund Test", de: "Mitfinanzierungstest"),
            descriptionText: .init(zh: "测试合资扣款。", en: "Tests cofunded spend.", de: "Testet mitfinanzierte Ausgabe."),
            cost: 50,
            category: .effect
        )
        context.insert(buyer)
        context.insert(contributor)
        try context.save()

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: buyer,
            itemName: "Redeemed Cofund Test",
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(result.didPurchase)
        #expect(result.failure == nil)
        #expect(result.fundingContributions == [
            ShopPurchaseFundingContribution(humanID: buyer.id, amount: 10),
            ShopPurchaseFundingContribution(humanID: contributor.id, amount: 40)
        ])
        #expect(buyer.coconutBalance == 0)
        #expect(contributor.coconutBalance == 60)
        #expect(walletEntries.count(where: { $0.ownerId == buyer.id.uuidString && $0.delta == -10 }) == 1)
        #expect(walletEntries.count(where: { $0.ownerId == contributor.id.uuidString && $0.delta == -40 }) == 1)
        #expect(walletEntries.allSatisfy { $0.balanceAfter >= 0 })
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
    }

    @MainActor
    @Test func shopPurchaseCofundingSkipsFrozenHumanWallets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let buyer = Human(name: "Ava")
        buyer.coconutBalance = 10
        let frozenContributor = Human(name: "Frozen")
        frozenContributor.coconutBalance = 100
        frozenContributor.passedAwayDate = makeDate(year: 2026, month: 6, day: 1)
        let activeContributor = Human(name: "Guan")
        activeContributor.coconutBalance = 100
        let item = ShopItem(
            id: "test_cofund_skip_frozen_item",
            emoji: "🥥",
            nameText: .init(zh: "冻结跳过测试", en: "Frozen Skip Test", de: "Frozen-Skip-Test"),
            descriptionText: .init(zh: "测试合资跳过冻结钱包。", en: "Tests skipping frozen cofunders.", de: "Testet eingefrorene Mitfinanzierer."),
            cost: 50,
            category: .effect
        )
        context.insert(buyer)
        context.insert(frozenContributor)
        context.insert(activeContributor)
        try context.save()

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: buyer,
            itemName: "Redeemed Frozen Skip Test",
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(result.didPurchase)
        #expect(result.fundingContributions == [
            ShopPurchaseFundingContribution(humanID: buyer.id, amount: 10),
            ShopPurchaseFundingContribution(humanID: activeContributor.id, amount: 40)
        ])
        #expect(buyer.coconutBalance == 0)
        #expect(frozenContributor.coconutBalance == 100)
        #expect(activeContributor.coconutBalance == 60)
        #expect(!walletEntries.contains { $0.ownerId == frozenContributor.id.uuidString })
    }

    @MainActor
    @Test func shopPurchaseUsesWalletAccountBalanceWhenCachedHumanBalanceIsStale() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 0
        let item = try #require(ShopCatalog.item(id: "fx_lime_glow"))
        let account = CoconutAccount(
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            displayName: human.name,
            balance: item.cost
        )
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = item.cost
        questManager.coconutLogs = []
        context.insert(human)
        context.insert(account)
        try context.save()

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Redeemed Lime Glow",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(result.didPurchase)
        #expect(account.balance == 0)
        #expect(human.coconutBalance == 0)
        #expect(questManager.coconutCount == 0)
        #expect(walletEntries.count(where: { $0.source == .shop && $0.entryKind == .spend }) == 1)
    }

    @MainActor
    @Test func repeatedConsumableShopPurchasesUseDistinctWalletKeys() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 500
        let item = try #require(ShopCatalog.item(id: "boost_backdate_single"))
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        questManager.coconutCount = 500
        questManager.coconutLogs = []
        context.insert(human)
        try context.save()

        let first = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Backdate Pass",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
        let second = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Backdate Pass",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(first.didPurchase)
        #expect(second.didPurchase)
        #expect(first.transactionKey != nil)
        #expect(second.transactionKey != nil)
        #expect(first.transactionKey != second.transactionKey)
        #expect(human.coconutBalance == 500 - item.cost * 2)
        #expect(questManager.coconutCount == 500 - item.cost * 2)
        #expect(walletEntries.count(where: { $0.source == .shop && $0.entryKind == .spend }) == 2)
    }

    @MainActor
    @Test func shopPurchaseCommandServiceRejectsInsufficientBalanceWithoutWrites() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 10
        let item = try #require(ShopCatalog.item(id: "fx_lime_glow"))
        context.insert(human)
        try context.save()

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Redeemed Lime Glow",
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(result.didPurchase == false)
        #expect(result.failure == .insufficientBalance(missing: item.cost - 10))
        #expect(human.coconutBalance == 10)
        #expect(ledgerEvents.isEmpty)
    }

    @MainActor
    @Test func shopPurchaseCommandServiceRejectsDeceasedHumanWalletWithoutWrites() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 500
        human.passedAwayDate = makeDate(year: 2026, month: 6, day: 1)
        let item = try #require(ShopCatalog.item(id: "fx_lime_glow"))
        context.insert(human)
        try context.save()

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Redeemed Lime Glow",
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        #expect(result.didPurchase == false)
        #expect(result.failure == .walletFrozen)
        #expect(human.coconutBalance == 500)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @MainActor
    @Test func questManagerDoesNotMutateProjectionWhenWalletWriteFails() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let questManager = QuestManager(
            wallet: FailingCoconutWalletManager(),
            revisions: SharedDomainRevisionPublisher()
        )
        questManager.coconutCount = 7
        questManager.coconutLogs = []

        let awarded = questManager.addCoconuts(
            15,
            emoji: "🥥",
            title: "Forced failure",
            actorId: nil,
            actorName: nil,
            context: context,
            save: true
        )

        #expect(awarded == 0)
        #expect(questManager.coconutCount == 7)
        #expect(questManager.coconutLogs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @MainActor
    @Test func legacyAddCoconutsWithoutActorUsesActiveHumanInsteadOfSystemWallet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        context.insert(human)
        try context.save()
        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())

        let awarded = questManager.addCoconuts(
            9,
            emoji: "🥥",
            title: "Legacy reward",
            actorId: nil,
            actorName: nil,
            context: context,
            save: true
        )

        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(awarded == 9)
        #expect(human.coconutBalance == 9)
        #expect(entries.count == 1)
        #expect(entries.first?.ownerKind == .human)
        #expect(entries.first?.ownerId == human.id.uuidString)
        #expect(entries.allSatisfy { $0.ownerKind != .system })
        #expect(questManager.coconutCount == 9)
    }

    @MainActor
    @Test func legacyAddCoconutsWithoutActorDoesNotCreateSystemWalletWhenNoActiveHumanExists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
        }
        defaults.removeObject(forKey: "currentActiveHumanId")
        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())

        let awarded = questManager.addCoconuts(
            9,
            emoji: "🥥",
            title: "Legacy reward",
            actorId: nil,
            actorName: nil,
            context: context,
            save: true
        )

        #expect(awarded == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutAccount>()).isEmpty)
        #expect(questManager.coconutCount == 0)
    }

    @MainActor
    @Test func specialRewardWithoutActorUsesActiveHumanInsteadOfSystemWallet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        context.insert(human)
        try context.save()

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let awarded = try questManager.stageSpecialCoconutReward(
            amount: 7,
            emoji: "✨",
            title: "Special reward",
            actorId: nil,
            sourceModelName: "EconomyModuleTest",
            sourceModelId: "active-human-fallback",
            transactionKey: "economyModuleTest:activeHumanFallback",
            context: context
        )
        try context.save()

        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(awarded == 7)
        #expect(human.coconutBalance == 7)
        #expect(entries.count == 1)
        #expect(entries.first?.ownerKind == .human)
        #expect(entries.first?.ownerId == human.id.uuidString)
        #expect(entries.allSatisfy { $0.ownerKind != .system })
        #expect(questManager.coconutCount == 7)
    }

    @MainActor
    @Test func specialRewardWithoutActorDoesNotCreateSystemWalletWhenNoActiveHumanExists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
        }
        defaults.removeObject(forKey: "currentActiveHumanId")
        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())

        let awarded = try questManager.stageSpecialCoconutReward(
            amount: 7,
            emoji: "✨",
            title: "Special reward",
            actorId: nil,
            sourceModelName: "EconomyModuleTest",
            sourceModelId: "no-active-human",
            transactionKey: "economyModuleTest:noActiveHuman",
            context: context
        )

        #expect(awarded == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutAccount>()).isEmpty)
        #expect(questManager.coconutCount == 0)
    }

    @MainActor
    @Test func repeatableMomentRewardUsesBudgetAndCooldownPipeline() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "猫")
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldCooldownLogs {
                defaults.set(oldCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
            memberKey: human.id.uuidString,
            careObjectKeys: [pet.id.uuidString]
        )
        context.insert(human)
        context.insert(pet)
        try context.save()
        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let now = makeDate(year: 2026, month: 6, day: 13, hour: 9, minute: 0)

        let first = MomentCommandService.recordMoment(
            pet: pet,
            note: "first",
            photoData: [],
            locationLatitude: 0,
            locationLongitude: 0,
            locationPlacename: "",
            context: context,
            executorId: human.id.uuidString,
            date: now,
            questManager: questManager
        )
        let second = MomentCommandService.recordMoment(
            pet: pet,
            note: "second",
            photoData: [],
            locationLatitude: 0,
            locationLongitude: 0,
            locationPlacename: "",
            context: context,
            executorId: human.id.uuidString,
            date: now.addingTimeInterval(60),
            questManager: questManager
        )

        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        #expect(first.coconutDelta == 0)
        #expect(second.coconutDelta == 0)
        #expect(human.coconutBalance == 0)
        #expect(budgetEvents.isEmpty)
    }

    @MainActor
    @Test func achievementRewardCommandServiceClaimsOnceAndUpdatesLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "猫")
        let claim = AchievementRewardClaim(
            badgeID: "human_first_record",
            rewardKey: "\(human.id.uuidString)_human_first_record",
            emoji: "🏅",
            logTitle: "Badge reward · First record",
            isUnlocked: true
        )
        let defaults = UserDefaults.standard
        let oldClaimedRaw = defaults.object(forKey: "achievement_claimedRewardIDs")
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            if let oldClaimedRaw {
                defaults.set(oldClaimedRaw, forKey: "achievement_claimedRewardIDs")
            } else {
                defaults.removeObject(forKey: "achievement_claimedRewardIDs")
            }
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        defaults.removeObject(forKey: "achievement_claimedRewardIDs")
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        context.insert(human)
        context.insert(pet)
        try context.save()

        let result = AchievementRewardCommandService.claimRewards(
            [claim],
            claimedRewardRaw: "",
            amountPerBadge: 10,
            human: human,
            pet: pet,
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager()
        )

        #expect(result.entityID == human.id)
        #expect(result.entityKind == EntityKind.human.rawValue)
        #expect(result.badgeIDs == ["human_first_record"])
        #expect(result.totalAmount == 10)
        #expect(result.didClaim == true)
        #expect(result.updatedClaimedRewardRaw.contains(claim.rewardKey))
        #expect(human.coconutBalance == 10)
        #expect(pet.coconutBalance == 0)
        #expect(questManager.coconutCount == 10)
        #expect(questManager.coconutLogs.count == 1)
        #expect(questManager.coconutLogs.first?.amount == 10)
        #expect(questManager.coconutLogs.first?.actorId == human.id.uuidString)

        let duplicate = AchievementRewardCommandService.claimRewards(
            [claim],
            claimedRewardRaw: result.updatedClaimedRewardRaw,
            amountPerBadge: 10,
            human: human,
            pet: pet,
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager()
        )

        #expect(duplicate.didClaim == false)
        #expect(duplicate.totalAmount == 0)
        #expect(human.coconutBalance == 10)
        #expect(questManager.coconutCount == 10)
        #expect(questManager.coconutLogs.count == 1)
    }

    @MainActor
    @Test func achievementRewardCommandServiceDoesNotClaimFrozenWallet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.passedAwayDate = makeDate(year: 2026, month: 6, day: 1)
        let pet = Pet(name: "Momo", species: "猫")
        let claim = AchievementRewardClaim(
            badgeID: "human_first_record",
            rewardKey: "\(human.id.uuidString)_human_first_record",
            emoji: "🏅",
            logTitle: "Badge reward · First record",
            isUnlocked: true
        )
        let defaults = UserDefaults.standard
        let oldClaimedRaw = defaults.object(forKey: "achievement_claimedRewardIDs")
        defer {
            if let oldClaimedRaw {
                defaults.set(oldClaimedRaw, forKey: "achievement_claimedRewardIDs")
            } else {
                defaults.removeObject(forKey: "achievement_claimedRewardIDs")
            }
        }
        defaults.removeObject(forKey: "achievement_claimedRewardIDs")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let result = AchievementRewardCommandService.claimRewards(
            [claim],
            claimedRewardRaw: "",
            amountPerBadge: 10,
            human: human,
            pet: pet,
            context: context,
            wallet: SwiftDataCoconutWalletManager()
        )

        #expect(result.didClaim == false)
        #expect(result.totalAmount == 0)
        #expect(result.updatedClaimedRewardRaw.isEmpty)
        #expect(human.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @MainActor
    @Test func backdateCheckInCommandServiceAwardsThroughQuestPipeline() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "猫")
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldBoostDouble = defaults.object(forKey: "shop_boostDoubleActive")
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldBoostDouble {
                defaults.set(oldBoostDouble, forKey: "shop_boostDoubleActive")
            } else {
                defaults.removeObject(forKey: "shop_boostDoubleActive")
            }
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
            memberKey: human.id.uuidString
        )
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        context.insert(human)
        context.insert(pet)
        try context.save()

        let result = BackdateCheckInCommandService.award(
            action: .milestone,
            actionKey: "milestone",
            pet: pet,
            context: context,
            questManager: questManager
        )

        #expect(result.petID == pet.id)
        #expect(result.humanID == human.id)
        #expect(result.actionKey == "milestone")
        #expect(result.didAward == true)
        #expect(result.totalCoconuts == result.humanGot + result.petGot)
        #expect(human.coconutBalance == result.humanGot)
        #expect(pet.coconutBalance == result.petGot)
        #expect(questManager.coconutCount == result.totalCoconuts)
        #expect(questManager.coconutLogs.reduce(0) { $0 + $1.amount } == result.totalCoconuts)
    }

    @MainActor
    @Test func petBondVaultUnlockServiceDeductsBalanceUnlocksAndWritesLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let item = try #require(PetBondVaultCatalog.items.first)
        pet.coconutBalance = item.cost + 20
        let defaults = UserDefaults.standard
        let unlockKey = "petBondVaultUnlocked_\(pet.id.uuidString)"
        let oldUnlockRaw = defaults.object(forKey: unlockKey)
        let oldRevision = defaults.object(forKey: PetBondVaultStore.revisionKey)
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            if let oldUnlockRaw {
                defaults.set(oldUnlockRaw, forKey: unlockKey)
            } else {
                defaults.removeObject(forKey: unlockKey)
            }
            if let oldRevision {
                defaults.set(oldRevision, forKey: PetBondVaultStore.revisionKey)
            } else {
                defaults.removeObject(forKey: PetBondVaultStore.revisionKey)
            }
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        defaults.removeObject(forKey: unlockKey)
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        context.insert(pet)
        try context.save()

        let result = PetBondVaultUnlockCommandService.unlock(
            item: item,
            pet: pet,
            title: "Unlocked \(item.id)",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let ledger = try #require(ledgerEvents.first)
        #expect(result.petID == pet.id)
        #expect(result.itemID == item.id)
        #expect(result.didUnlock == true)
        #expect(result.ledgerEventID == ledger.id)
        #expect(pet.coconutBalance == 20)
        #expect(PetBondVaultStore.isUnlocked(item.kind, for: pet.id))
        #expect(ledger.actionType == "petBondVaultUnlock")
        #expect(ledger.coconutDelta == -item.cost)
        #expect(ledger.metadataJSON.contains(item.id))

        let duplicate = PetBondVaultUnlockCommandService.unlock(
            item: item,
            pet: pet,
            title: "Unlocked \(item.id)",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
        let ledgerEventsAfterDuplicate = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(duplicate.didUnlock == false)
        #expect(duplicate.failure == .alreadyUnlocked)
        #expect(pet.coconutBalance == 20)
        #expect(ledgerEventsAfterDuplicate.count == 1)
    }

    @MainActor
    @Test func petBondVaultUnlockServiceRejectsFrozenPetWalletWithoutWrites() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let item = try #require(PetBondVaultCatalog.items.first)
        pet.coconutBalance = item.cost + 20
        pet.passedAwayDate = makeDate(year: 2026, month: 6, day: 1)
        context.insert(pet)
        try context.save()

        let result = PetBondVaultUnlockCommandService.unlock(
            item: item,
            pet: pet,
            title: "Unlocked \(item.id)",
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        #expect(result.didUnlock == false)
        #expect(result.failure == .walletFrozen)
        #expect(pet.coconutBalance == item.cost + 20)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @MainActor
    @Test func familyTaskBountyTransferIsDedupedByWalletTransactionKey() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let payer = Human(name: "Parent")
        let receiver = Human(name: "Kid")
        payer.coconutBalance = 160
        let task = FamilyCollaborationTask(
            title: "Water plants",
            kind: .bounty,
            status: .pendingReview,
            createdById: payer.id.uuidString,
            createdByName: payer.name,
            assignedToId: receiver.id.uuidString,
            assignedToName: receiver.name,
            rewardCoconuts: 40
        )
        task.completedById = receiver.id.uuidString
        task.completedByName = receiver.name
        task.completedAt = makeDate(year: 2026, month: 6, day: 11)
        context.insert(payer)
        context.insert(receiver)
        context.insert(task)
        try context.save()

        FamilyTaskService.confirmCompletion(
            task,
            by: payer,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        task.status = .pendingReview
        try context.save()
        FamilyTaskService.confirmCompletion(
            task,
            by: payer,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.sourceModelId == task.id.uuidString && $0.source == .familyTask }
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
            .filter { $0.metadataJSON.hasPrefix("familyTaskRewardTransfer:\(task.id.uuidString)") }
        #expect(entries.count == 2)
        #expect(Set(entries.map(\.transactionKey)) == [
            "familyTaskRewardTransfer:\(task.id.uuidString):payer",
            "familyTaskRewardTransfer:\(task.id.uuidString):receiver"
        ])
        #expect(ledgerEvents.count == 2)
        #expect(CoconutWalletService.balance(for: payer, context: context) == 120)
        #expect(CoconutWalletService.balance(for: receiver, context: context) == 40)
    }

    @MainActor
    @Test func familyTaskBountyTransferFailureLeavesReviewPendingWithoutLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let payer = Human(name: "Parent")
        let receiver = Human(name: "Kid")
        payer.coconutBalance = 10
        let task = FamilyCollaborationTask(
            title: "Water plants",
            kind: .bounty,
            status: .pendingReview,
            createdById: payer.id.uuidString,
            createdByName: payer.name,
            assignedToId: receiver.id.uuidString,
            assignedToName: receiver.name,
            rewardCoconuts: 40
        )
        task.completedById = receiver.id.uuidString
        task.completedByName = receiver.name
        task.completedAt = makeDate(year: 2026, month: 6, day: 11)
        context.insert(payer)
        context.insert(receiver)
        context.insert(task)
        try context.save()

        let didComplete = FamilyTaskService.confirmCompletion(
            task,
            by: payer,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        #expect(didComplete == false)
        #expect(task.status == .pendingReview)
        #expect(CoconutWalletService.balance(for: payer, context: context) == 10)
        #expect(CoconutWalletService.balance(for: receiver, context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @MainActor
    @Test func economyBudgetUsageSurvivesUserDefaultsReset() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let date = makeDate(year: 2026, month: 6, day: 10)
        let householdKey = "household.test.\(UUID().uuidString)"
        let memberKey = "member.test.\(UUID().uuidString)"
        let petKey = "pet.\(UUID().uuidString)"
        EconomyDailyBudgetStore.reset(
            householdKey: householdKey,
            memberKey: memberKey,
            careObjectKeys: [petKey],
            date: date
        )

        let result = CoconutEconomyPolicyV2.reward(
            for: .feed,
            quality: .none,
            isOnCooldown: false,
            userKey: householdKey,
            memberKey: memberKey,
            careObjectKeys: [petKey],
            careObjectCount: 1,
            hasHumanAccount: true,
            hasPetAccount: true,
            date: date,
            forcedLuck: EconomyLuckTier.none,
            context: context
        )
        EconomyDailyBudgetStore.commit(
            result,
            householdKey: householdKey,
            memberKey: memberKey,
            careObjectKeys: [petKey],
            date: date,
            context: context,
            save: true
        )
        EconomyDailyBudgetStore.reset(
            householdKey: householdKey,
            memberKey: memberKey,
            careObjectKeys: [petKey],
            date: date
        )

        let snapshot = EconomyDailyBudgetStore.snapshot(
            householdKey: householdKey,
            memberKey: memberKey,
            careObjectKeys: [petKey],
            careObjectCount: 1,
            date: date,
            context: context
        )
        let events = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        #expect(snapshot.xpUsed == result.growthXP)
        #expect(snapshot.coconutUsed == result.totalCoconuts)
        #expect(snapshot.memberXPUsed == result.growthXP)
        #expect(snapshot.memberCoconutUsed == result.totalCoconuts)
        #expect(snapshot.careObjectXPUsed[petKey] == result.growthXP)
        #expect(snapshot.careObjectCoconutUsed[petKey] == result.totalCoconuts)
        #expect(events.count == 3)
    }

    @MainActor
    @Test func petBondVaultRepeatableTreatSpendsEveryTimeWithUniqueTransactions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let item = try #require(PetBondVaultCatalog.items.first { $0.isRepeatable })
        pet.coconutBalance = item.cost * 2 + 5
        let defaults = UserDefaults.standard
        let oldRevision = defaults.object(forKey: PetBondVaultStore.revisionKey)
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            if let oldRevision {
                defaults.set(oldRevision, forKey: PetBondVaultStore.revisionKey)
            } else {
                defaults.removeObject(forKey: PetBondVaultStore.revisionKey)
            }
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        context.insert(pet)
        try context.save()

        let first = PetBondVaultUnlockCommandService.unlock(
            item: item,
            pet: pet,
            title: "Treat \(item.id)",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
        let second = PetBondVaultUnlockCommandService.unlock(
            item: item,
            pet: pet,
            title: "Treat \(item.id)",
            context: context,
            questManager: questManager,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let transactionKeys = Set(walletEntries.map(\.transactionKey))
        #expect(first.didUnlock == true)
        #expect(second.didUnlock == true)
        #expect(pet.coconutBalance == 5)
        #expect(PetBondVaultStore.consumptionCount(item.kind, for: pet.id) == 2)
        #expect(ledgerEvents.count(where: { $0.actionType == "petBondVaultConsume" }) == 2)
        #expect(walletEntries.count == 2)
        #expect(transactionKeys.count == 2)
    }

    @MainActor
    @Test func streakMilestoneRewardIsFamilyDedupedAndDoesNotUseDailyBudget() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Li")
        let firstPet = Pet(name: "Momo", species: "猫")
        let secondPet = Pet(name: "Kiki", species: "猫")
        firstPet.currentStreak = 7
        secondPet.currentStreak = 7
        context.insert(human)
        context.insert(firstPet)
        context.insert(secondPet)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldClaimed = defaults.object(forKey: "streakRewards_claimed")
        let questManager = makeQuestManager()
        let careObjectKeys = questManager.careObjectKeys(for: [firstPet, secondPet])
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldClaimed {
                defaults.set(oldClaimed, forKey: "streakRewards_claimed")
            } else {
                defaults.removeObject(forKey: "streakRewards_claimed")
            }
            EconomyDailyBudgetStore.reset(
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: human.id.uuidString,
                careObjectKeys: careObjectKeys,
                date: Date()
            )
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: "streakRewards_claimed")
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            memberKey: human.id.uuidString,
            careObjectKeys: careObjectKeys,
            date: Date()
        )

        let manager = StreakRewardManager()
        manager.checkAndAward(pet: firstPet, questManager: questManager, context: context)
        manager.checkAndAward(pet: secondPet, questManager: questManager, context: context)

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        #expect(human.coconutBalance == 20)
        #expect(walletEntries.count == 1)
        #expect(walletEntries.first?.sourceModelName == "StreakRewardManager")
        #expect(budgetEvents.filter { $0.actionKey == "streak_7" }.isEmpty)
        #expect((defaults.dictionary(forKey: "streakRewards_claimed") ?? [:])["family_7"] != nil)
    }

    @MainActor
    @Test func streakMilestoneWithoutActiveHumanDoesNotCreateSystemWallet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.currentStreak = 7
        context.insert(pet)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldClaimed = defaults.object(forKey: "streakRewards_claimed")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldClaimed {
                defaults.set(oldClaimed, forKey: "streakRewards_claimed")
            } else {
                defaults.removeObject(forKey: "streakRewards_claimed")
            }
        }
        defaults.removeObject(forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: "streakRewards_claimed")

        StreakRewardManager().checkAndAward(pet: pet, questManager: makeQuestManager(), context: context)

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        #expect(walletEntries.isEmpty)
        #expect(accounts.isEmpty)
        #expect((defaults.dictionary(forKey: "streakRewards_claimed") ?? [:])["family_7"] == nil)
    }

    @MainActor
    @Test func streakLargeMilestoneIgnoresDailyBudgetLimit() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Li")
        let pet = Pet(name: "Momo", species: "猫")
        pet.currentStreak = 365
        context.insert(human)
        context.insert(pet)
        try context.save()

        let now = Date()
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldClaimed = defaults.object(forKey: "streakRewards_claimed")
        let questManager = makeQuestManager()
        let careObjectKeys = questManager.careObjectKeys(for: pet)
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldClaimed {
                defaults.set(oldClaimed, forKey: "streakRewards_claimed")
            } else {
                defaults.removeObject(forKey: "streakRewards_claimed")
            }
            EconomyDailyBudgetStore.reset(
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: human.id.uuidString,
                careObjectKeys: careObjectKeys,
                date: Date()
            )
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.set([
            "family_7": now.timeIntervalSince1970,
            "family_30": now.timeIntervalSince1970,
            "family_100": now.timeIntervalSince1970
        ], forKey: "streakRewards_claimed")
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            memberKey: human.id.uuidString,
            careObjectKeys: careObjectKeys,
            date: now
        )
        let budgetFiller = EconomyRewardResult(
            growthXP: 0,
            humanCoconuts: 56,
            petCoconuts: 0,
            bonusCoconuts: 0,
            luckyCoconuts: 0,
            budgetMultiplier: 1,
            budgetStage: .normal,
            reason: "test",
            actionKey: "test_budget_fill",
            isOnCooldown: false,
            baseGrowthXP: 0,
            baseCoconuts: 56,
            luck: .none
        )
        EconomyDailyBudgetStore.commit(
            budgetFiller,
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            memberKey: human.id.uuidString,
            careObjectKeys: careObjectKeys,
            date: now,
            context: context
        )
        let budgetEventCountBefore = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).count

        StreakRewardManager().checkAndAward(pet: pet, questManager: questManager, context: context)

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        let claimed = defaults.dictionary(forKey: "streakRewards_claimed") ?? [:]
        #expect(human.coconutBalance == 2000)
        #expect(walletEntries.count == 1)
        #expect(walletEntries.first?.sourceModelId == "family_365")
        #expect(budgetEvents.count == budgetEventCountBefore)
        #expect(budgetEvents.filter { $0.actionKey == "streak_365" }.isEmpty)
        #expect(claimed["family_365"] != nil)
    }

    @MainActor
    @Test func economyBudgetUsagePruneKeepsRecentRows() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 6, day: 10)
        let oldDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -60, to: now) ?? now
        let recentDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -10, to: now) ?? now
        let defaults = UserDefaults.standard
        let pruneKey = "economyV2.dailyBudget.usagePrune.lastDay"
        let oldPruneDay = defaults.object(forKey: pruneKey)
        defer {
            if let oldPruneDay {
                defaults.set(oldPruneDay, forKey: pruneKey)
            } else {
                defaults.removeObject(forKey: pruneKey)
            }
        }
        defaults.removeObject(forKey: pruneKey)
        let oldEventID = UUID()
        let recentEventID = UUID()
        context.insert(EconomyBudgetUsageEvent(
            id: oldEventID,
            dayKey: EconomyDailyBudgetStore.dayKey(for: oldDate),
            householdKey: "household.local",
            memberKey: "member",
            scope: .household,
            scopeKey: "household.local",
            growthXPUsed: 1,
            coconutUsed: 1,
            actionKey: "old",
            source: "test"
        ))
        context.insert(EconomyBudgetUsageEvent(
            id: recentEventID,
            dayKey: EconomyDailyBudgetStore.dayKey(for: recentDate),
            householdKey: "household.local",
            memberKey: "member",
            scope: .household,
            scopeKey: "household.local",
            growthXPUsed: 1,
            coconutUsed: 1,
            actionKey: "recent",
            source: "test"
        ))
        try context.save()

        let deleted = EconomyDailyBudgetStore.pruneOldUsageEvents(
            context: context,
            retainingDays: 45,
            now: now,
            defaults: defaults
        )
        let remaining = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(deleted == 1)
        #expect(remaining.count == 1)
        #expect(remaining.first?.actionKey == "recent")
        #expect(remaining.first?.id == recentEventID)
        #expect(try cloudSyncState(entityName: String(describing: EconomyBudgetUsageEvent.self), id: oldEventID, context: context)?.isDeletionTombstone == true)
    }

    @MainActor
    @Test func petCardAppearanceServiceEnablesAndRestoresPopout() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        let enabled = PetCardAppearanceCommandService.enablePopout(
            pet: pet,
            imageData: Data([1, 2, 3]),
            sourceRaw: "avatar2d",
            context: context
        )

        #expect(enabled.petID == pet.id)
        #expect(enabled.action == "enablePopout")
        #expect(pet.cardStyleRaw == "popout")
        #expect(pet.cardPopoutImageData == Data([1, 2, 3]))
        #expect(pet.hasCardPopoutImageAttachment == true)
        #expect(pet.cardPopoutImageSignature == MediaPayloadSignature.signature(for: Data([1, 2, 3])))
        #expect(pet.cardPopoutSourceRaw == "avatar2d")

        let restored = PetCardAppearanceCommandService.restoreClassic(pet: pet, context: context)

        #expect(restored.petID == pet.id)
        #expect(restored.action == "restoreClassic")
        #expect(pet.cardStyleRaw == "classic")
    }

    @MainActor
    @Test func avatar2DUpgradeCommandServiceConsumesPassAndUpdatesHuman() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(
            name: "Guan",
            birthday: makeDate(year: 1996, month: 5, day: 8)
        )
        human.notes = "性别:女"
        let defaults = UserDefaults.standard
        let oldPassRaw = defaults.object(forKey: Avatar2DAccess.extraPassInventoryKey)
        defer {
            if let oldPassRaw {
                defaults.set(oldPassRaw, forKey: Avatar2DAccess.extraPassInventoryKey)
            } else {
                defaults.removeObject(forKey: Avatar2DAccess.extraPassInventoryKey)
            }
        }
        defaults.set(1, forKey: Avatar2DAccess.extraPassInventoryKey)
        context.insert(human)
        try context.save()

        let result = Avatar2DUpgradeCommandService.upgradeHuman(human, context: context)

        #expect(result.entityID == human.id)
        #expect(result.kind == EntityKind.human.rawValue)
        #expect(result.didUpgrade == true)
        #expect(result.failure == nil)
        #expect(Avatar2DAccess.extraPassCount == 0)
        #expect(human.avatarImageData != nil)
        #expect(human.hasAvatarImageAttachment == true)
        #expect(!human.avatarImageSignature.isEmpty)
        #expect(human.avatarEmoji == HumanGenderIdentity.fallbackAvatarEmoji(for: "女"))
    }

    @MainActor
    @Test func rewardEconomyCommandExecutorPublishesPurchaseRewardBackdateAndBondRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "猫")
        human.coconutBalance = 500
        context.insert(human)
        context.insert(pet)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldClaimedRaw = defaults.object(forKey: "achievement_claimedRewardIDs")
        let oldBoostDouble = defaults.object(forKey: "shop_boostDoubleActive")
        let bondItem = try #require(PetBondVaultCatalog.items.first)
        let unlockKey = "petBondVaultUnlocked_\(pet.id.uuidString)"
        let oldUnlockRaw = defaults.object(forKey: unlockKey)
        let oldBondRevision = defaults.object(forKey: PetBondVaultStore.revisionKey)
        let questManager = TestQuestManagerProjection.manager
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldClaimedRaw {
                defaults.set(oldClaimedRaw, forKey: "achievement_claimedRewardIDs")
            } else {
                defaults.removeObject(forKey: "achievement_claimedRewardIDs")
            }
            if let oldBoostDouble {
                defaults.set(oldBoostDouble, forKey: "shop_boostDoubleActive")
            } else {
                defaults.removeObject(forKey: "shop_boostDoubleActive")
            }
            if let oldUnlockRaw {
                defaults.set(oldUnlockRaw, forKey: unlockKey)
            } else {
                defaults.removeObject(forKey: unlockKey)
            }
            if let oldBondRevision {
                defaults.set(oldBondRevision, forKey: PetBondVaultStore.revisionKey)
            } else {
                defaults.removeObject(forKey: PetBondVaultStore.revisionKey)
            }
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.persistQuestFlags()
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: "achievement_claimedRewardIDs")
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        defaults.removeObject(forKey: unlockKey)
        questManager.coconutCount = 500
        questManager.coconutLogs = []
        let wallet = SwiftDataCoconutWalletManager()

        let executor = RewardEconomyCommandExecutor(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: questManager,
            wallet: wallet,
            careLedger: CareLedgerService(),
            activeHumanSelection: UserDefaultsActiveHumanSelection()
        )
        let beforeRevision = revisionCenter.homeRevision.value
        let shopItem = try #require(ShopCatalog.item(id: "fx_lime_glow"))
        let purchase = executor.purchase(
            item: shopItem,
            buyer: human,
            itemName: "Redeemed Lime Glow",
            note: "test.reward.purchase"
        )
        var mutation = try #require(revisionCenter.lastMutation)
        #expect(purchase.didPurchase == true)
        #expect(mutation.command == .shopPurchase(humanID: human.id, itemID: shopItem.id))
        #expect(mutation.note == "test.reward.purchase")

        let claim = AchievementRewardClaim(
            badgeID: "human_first_record",
            rewardKey: "\(human.id.uuidString)_human_first_record",
            emoji: "🏅",
            logTitle: "Badge reward · First record",
            isUnlocked: true
        )
        let reward = executor.claimAchievementRewards(
            [claim],
            claimedRewardRaw: "",
            amountPerBadge: 10,
            human: human,
            pet: pet,
            questManager: questManager,
            note: "test.reward.achievement"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(reward.didClaim == true)
        #expect(mutation.command == .achievementReward(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            badgeIDs: ["human_first_record"]
        ))
        #expect(mutation.note == "test.reward.achievement")

        let backdate = executor.awardBackdateCheckIn(
            action: .milestone,
            actionKey: "milestone",
            pet: pet,
            questManager: questManager,
            note: "test.reward.backdate"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(backdate.didAward == true)
        #expect(mutation.command == .backdateCheckIn(petID: pet.id, action: "milestone"))
        #expect(mutation.note == "test.reward.backdate")

        _ = try wallet.apply(
            deltas: [
                .pet(
                    pet,
                    delta: bondItem.cost + 20,
                    entryKind: .adjustment,
                    source: .service,
                    title: "Seed bond vault balance",
                    emoji: "🧪",
                    actorId: pet.id.uuidString,
                    actorName: pet.name,
                    subjectKind: .pet,
                    subjectId: pet.id.uuidString,
                    transactionKey: "test:bondVault:seed:\(pet.id.uuidString)"
                )
            ],
            context: context,
            save: true,
            postsRewardFeedback: false,
            updatesProjection: false,
            projectionManager: nil
        )
        let bond = executor.unlockBondVaultItem(
            bondItem,
            pet: pet,
            title: "Unlocked \(bondItem.id)",
            note: "test.reward.bond"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(bond.didUnlock == true)
        #expect(mutation.command == .petBondVaultUnlock(petID: pet.id, itemID: bondItem.id))
        #expect(mutation.note == "test.reward.bond")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 4)
    }

    @MainActor
    @Test func rewardEconomyCommandExecutorPublishesAppearanceAndAvatarRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(
            name: "Guan",
            birthday: makeDate(year: 1996, month: 5, day: 8)
        )
        human.notes = "性别:女"
        context.insert(pet)
        context.insert(human)
        try context.save()

        let defaults = UserDefaults.standard
        let oldPassRaw = defaults.object(forKey: Avatar2DAccess.extraPassInventoryKey)
        defer {
            if let oldPassRaw {
                defaults.set(oldPassRaw, forKey: Avatar2DAccess.extraPassInventoryKey)
            } else {
                defaults.removeObject(forKey: Avatar2DAccess.extraPassInventoryKey)
            }
        }
        defaults.set(1, forKey: Avatar2DAccess.extraPassInventoryKey)

        let executor = RewardEconomyCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let enabled = executor.enablePetPopoutCard(
            pet: pet,
            imageData: Data([1, 2, 3]),
            sourceRaw: "avatar2d",
            note: "test.reward.appearance.enable"
        )
        var mutation = try #require(revisionCenter.lastMutation)
        #expect(enabled.action == "enablePopout")
        #expect(mutation.command == .petCardAppearance(petID: pet.id, action: "enablePopout"))
        #expect(mutation.note == "test.reward.appearance.enable")

        let restored = executor.restoreClassicPetCard(
            pet: pet,
            note: "test.reward.appearance.restore"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(restored.action == "restoreClassic")
        #expect(mutation.command == .petCardAppearance(petID: pet.id, action: "restoreClassic"))
        #expect(mutation.note == "test.reward.appearance.restore")

        let upgraded = executor.upgradeHumanTo2DAvatar(
            human,
            note: "test.reward.avatar.human"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(upgraded.didUpgrade == true)
        #expect(human.avatarImageData != nil)
        #expect(human.hasAvatarImageAttachment == true)
        #expect(!human.avatarImageSignature.isEmpty)
        #expect(mutation.command == .avatar2DUpgrade(entityID: human.id, kind: EntityKind.human.rawValue))
        #expect(mutation.note == "test.reward.avatar.human")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 3)
    }

    @MainActor
    @Test func catCareCommandServiceRecordsAndUndoesLitterCare() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let result = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "铲猫砂",
                emoji: "🧹",
                recordsHygiene: true,
                occurredAt: makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 30),
                executorId: executorHuman.id.uuidString
            ),
            context: context
        )

        var events = try context.fetch(FetchDescriptor<Event>())
        var hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        #expect(result.petID == pet.id)
        #expect(result.actionRaw == "铲猫砂")
        #expect(events.count == 1)
        #expect(hygieneLogs.count == 1)
        #expect(events.first?.id == result.eventID)
        #expect(events.first?.relatedEntityId == pet.id.uuidString)
        #expect(events.first?.eventType == EventType.litterBox.rawValue)
        #expect(hygieneLogs.first?.id == result.hygieneLogID)
        #expect(hygieneLogs.first?.pet?.id == pet.id)

        let undoResult = CatCareCommandService.undo(
            pet: pet,
            eventID: result.eventID,
            hygieneLogID: result.hygieneLogID,
            context: context
        )

        events = try context.fetch(FetchDescriptor<Event>())
        hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        #expect(undoResult.petID == pet.id)
        #expect(undoResult.eventID == result.eventID)
        #expect(undoResult.hygieneLogID == result.hygieneLogID)
        #expect(events.isEmpty)
        #expect(hygieneLogs.isEmpty)
    }

    @MainActor
    @Test func catCareCommandServiceRecordsFeedWithoutHygieneFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let result = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "喂食",
                emoji: "🥩",
                recordsHygiene: false,
                occurredAt: makeDate(year: 2026, month: 6, day: 8, hour: 9, minute: 0),
                executorId: executorHuman.id.uuidString
            ),
            context: context
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        #expect(result.petID == pet.id)
        #expect(result.hygieneLogID == nil)
        #expect(events.count == 1)
        #expect(events.first?.title == "🥩 喂食")
        #expect(hygieneLogs.isEmpty)
    }

    @MainActor
    @Test func petCareCommandExecutorPublishesCatCareRecordAndUndoRevisions() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        try context.save()

        let executor = PetCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let recorded = executor.recordCatCare(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "铲猫砂",
                emoji: "🧹",
                recordsHygiene: true,
                occurredAt: makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 30),
                executorId: executorHuman.id.uuidString
            ),
            note: "test.cat.record"
        )
        var mutation = try #require(revisionCenter.lastMutation)
        let hygieneLogID = try #require(recorded.hygieneLogID)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.legacyModelName == "PetHygieneLog" && $0.legacyModelId == hygieneLogID.uuidString
        })
        #expect(mutation.command == .catCareRecord(petID: pet.id, action: "铲猫砂"))
        #expect(mutation.affectedEntityIDs == [pet.id, recorded.eventID, hygieneLogID])
        #expect(mutation.note == "test.cat.record")

        let undone = executor.undoCatCare(
            pet: pet,
            eventID: recorded.eventID,
            hygieneLogID: recorded.hygieneLogID,
            note: "test.cat.undo"
        )
        mutation = try #require(revisionCenter.lastMutation)
        #expect(undone.eventID == recorded.eventID)
        #expect(undone.didDelete)
        #expect(undone.removedLedgerEventIDs == [ledger.id])
        #expect(mutation.command == .catCareUndo(petID: pet.id, eventID: recorded.eventID))
        #expect(mutation.affectedEntityIDs == [pet.id, recorded.eventID, hygieneLogID, ledger.id])
        #expect(mutation.note == "test.cat.undo")
        #expect(revisionCenter.homeRevision.value == beforeRevision + 2)
    }

    @MainActor
    @Test func petCareCommandExecutorDoesNotPublishCatCareUndoRevisionWhenNothingDeleted() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "猫")
        let executorHuman = insertExecutorHuman(in: context)
        context.insert(pet)
        context.insert(otherPet)
        try context.save()
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(executorHuman.id.uuidString, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()

        let executor = PetCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let recorded = executor.recordCatCare(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "铲猫砂",
                emoji: "🧹",
                recordsHygiene: true,
                occurredAt: makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 30),
                executorId: executorHuman.id.uuidString
            ),
            note: "test.cat.record"
        )
        let recordMutation = try #require(revisionCenter.lastMutation)
        let hygieneLogID = try #require(recorded.hygieneLogID)
        let beforeUndoRevision = revisionCenter.homeRevision.value

        let undo = executor.undoCatCare(
            pet: otherPet,
            eventID: recorded.eventID,
            hygieneLogID: hygieneLogID,
            note: "test.cat.undo.wrongPet"
        )

        #expect(undo.didDelete == false)
        #expect(undo.removedLedgerEventIDs.isEmpty)
        #expect(revisionCenter.lastMutation == recordMutation)
        #expect(revisionCenter.homeRevision.value == beforeUndoRevision)
        #expect(try context.fetch(FetchDescriptor<Event>()).map(\.id) == [recorded.eventID])
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).map(\.id) == [hygieneLogID])
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
    }

    @MainActor
    @Test func petCareCommandExecutorPublishesCatCareRevisionForDeceasedExecutorFallbackOwner() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executorHuman = Human(name: "Former caretaker")
        executorHuman.passedAwayDate = makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 0)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(activeHuman)
        context.insert(executorHuman)
        context.insert(pet)
        try context.save()
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        defer {
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.resetAll()
        }
        defaults.set(activeHuman.id.uuidString, forKey: "currentActiveHumanId")
        EconomyDailyBudgetStore.resetAll()

        let executor = PetCareCommandExecutor(context: context, revisionCenter: revisionCenter)
        let beforeRevision = revisionCenter.homeRevision.value
        let recorded = executor.recordCatCare(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "铲猫砂",
                emoji: "🧹",
                recordsHygiene: true,
                occurredAt: makeDate(year: 2026, month: 6, day: 8, hour: 8, minute: 30),
                executorId: executorHuman.id.uuidString
            ),
            note: "test.cat.record.fallback"
        )

        #expect(recorded.didRecord)
        #expect(revisionCenter.lastMutation != nil)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).count == 1)
    }

    @MainActor
    @Test func quickFeedExecutorStockSavePublishesFeedStockRevision() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        let beforeRevision = revisionCenter.homeRevision.value
        let executor = QuickFeedCommandExecutor(context: context, revisionCenter: revisionCenter)
        let result = executor.saveStock(
            pet: pet,
            brand: "Royal Canin",
            totalGrams: 1200,
            purchaseDate: makeDate(year: 2026, month: 6, day: 8),
            openDate: makeDate(year: 2026, month: 6, day: 8),
            foodKind: .dry,
            calculationMode: .manualOrPlan,
            reminderEnabled: false,
            reminderAdvanceDays: 3,
            executorId: "human-1",
            allEvents: [],
            recordToUpdate: nil,
            previousExpenseId: nil,
            expenseAmount: nil,
            expensePayerId: nil,
            expenseDate: makeDate(year: 2026, month: 6, day: 8),
            expenseNote: "restock"
        )

        let records = try context.fetch(FetchDescriptor<PetFoodRecord>())
        let record = try #require(result.record)
        let mutation = try #require(revisionCenter.lastMutation)
        #expect(records.count == 1)
        #expect(records.first?.id == record.id)
        #expect(records.first?.pet?.id == pet.id)
        #expect(records.first?.brand == "Royal Canin")
        #expect(records.first?.totalGrams == 1200)
        #expect(records.first?.foodKind == .dry)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(mutation.command == .feedStock(petID: pet.id, action: "create"))
        #expect(mutation.affectedEntityIDs == [pet.id])
        #expect(mutation.wroteBusinessFact == true)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private struct FixedActiveHumanSelection: ActiveHumanSelecting {
        let currentHumanId: String?

        var currentHumanIdRaw: String {
            currentHumanId ?? ""
        }
    }

    private final class MedicationReminderManagerSpy: MedicationReminderManaging {
        private(set) var recordedMedicationIDs: [UUID] = []
        private(set) var scheduledPetIDs: [UUID] = []

        func dosesTakenToday(for _: UUID) -> Int {
            0
        }

        func recordDose(for medicationId: UUID) {
            recordedMedicationIDs.append(medicationId)
        }

        func undoDose(for _: UUID) {}

        func scheduleMedicationReminders(for pet: Pet, context _: ModelContext?) {
            scheduledPetIDs.append(pet.id)
        }

        func scheduleHumanMedicationReminders(for _: Human, meds _: [HumanMedication], context _: ModelContext?) {}
    }

    private final class RecordingNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var cancelledIds: [String] = []
        private(set) var scheduledIds: [String] = []

        func schedule(reminder: Reminder) {
            scheduledIds.append(reminder.notificationId)
        }

        func schedule(
            reminder: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            scheduledIds.append(reminder.notificationId)
            completion?(.scheduled)
        }

        func schedule(
            reminder: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            scheduledIds.append(reminder.notificationId)
            completion?(.scheduled)
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId: String) { cancelledIds.append(notificationId) }
        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    private func stockReminderEvents(for pet: Pet, context: ModelContext) -> [Event] {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return FeedingPlanWriter.stockReminderEvents(pet: pet, allEvents: events)
    }

    @MainActor
    private func makeQuestManager() -> QuestManager {
        QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
    }

    @discardableResult
    private func insertExecutorHuman(in context: ModelContext, name: String = "Executor") -> Human {
        let human = Human(name: name)
        context.insert(human)
        return human
    }

    @MainActor
    private final class FailingCoconutWalletManager: CoconutWalletManaging {
        enum Failure: Error {
            case forced
        }

        func apply(
            deltas _: [CoconutWalletDelta],
            context _: ModelContext,
            save _: Bool,
            postsRewardFeedback _: Bool,
            updatesProjection _: Bool,
            projectionManager _: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            throw Failure.forced
        }

        func applyActorDelta(
            amount _: Int,
            emoji _: String,
            title _: String,
            actorId _: String?,
            actorName _: String?,
            entryKind _: CoconutWalletEntryKind,
            source _: CoconutWalletSource,
            context _: ModelContext,
            save _: Bool,
            postsRewardFeedback _: Bool,
            projectionManager _: CoconutProjectionManaging?
        ) throws -> [CoconutLedgerEntry] {
            throw Failure.forced
        }

        func totalBalance(context _: ModelContext) -> Int {
            0
        }

        func balance(accountKey _: String, context _: ModelContext, fallback: Int) -> Int {
            fallback
        }

        func balance(for human: Human, context _: ModelContext) -> Int {
            human.coconutBalance
        }

        func balance(for pet: Pet, context _: ModelContext) -> Int {
            pet.coconutBalance
        }

        func legacySystemBalance(context _: ModelContext, fallback: Int) -> Int {
            fallback
        }

        func setDeveloperOverrideBalance(amount _: Int, for _: Human?, displayName _: String, context _: ModelContext) {}

        func refreshQuestProjection(context _: ModelContext, manager _: CoconutProjectionManaging?) {}

        func bootstrapIfNeeded(context _: ModelContext, projectionManager _: CoconutProjectionManaging?) throws {}
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func cloudSyncState(entityName: String, id: UUID, context: ModelContext) throws -> CloudSyncRecordState? {
        try context.fetch(FetchDescriptor<CloudSyncRecordState>()).first {
            $0.entityName == entityName && $0.localRecordId == CloudSyncRecordState.normalizedRecordId(id)
        }
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        ) ?? .distantPast
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
