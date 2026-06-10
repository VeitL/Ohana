import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct DenseDataSnapshotPerformanceTests {
    @Test func denseDataSnapshotBuildersStayWithinWallClockBudgets() throws {
        let fixture = DenseFixture.make()

        expectFixtureShape(fixture)

        let homeSnapshot = buildHomeSnapshot(fixture)
        #expect(homeSnapshot.cards.count >= 6)
        #expect(!homeSnapshot.todayFocus.refreshedQuests.isEmpty)

        let todayFocusSnapshot = buildTodayFocusSnapshot(fixture)
        #expect(todayFocusSnapshot.pets.count == 3)
        #expect(!todayFocusSnapshot.assignedFamilyTasks.isEmpty)

        let calendarSnapshot = buildCalendarSnapshot(fixture)
        let hasOccurrences = !calendarSnapshot.expandedOccurrences.isEmpty
        let hasTodaySection = calendarSnapshot.sections.contains { section in
            Calendar.current.isDate(section.date, inSameDayAs: fixture.now)
        }
        #expect(hasOccurrences)
        #expect(hasTodaySection)
    }

    private func expectFixtureShape(_ fixture: DenseFixture) {
        let hasMemorialPet = fixture.pets.contains { pet in pet.hasPassedAway }
        let hasMemorialHuman = fixture.humans.contains { human in human.hasPassedAway }
        let viewerId = fixture.humans.first?.id
        let hasPrivacyLockedHuman = fixture.humans.contains { human in
            human.isPrivate(.weight, viewedBy: viewerId)
        }

        #expect(fixture.pets.count == 4)
        #expect(fixture.humans.count == 4)
        #expect(fixture.electronicPets.count == 2)
        #expect(fixture.events.count >= 18000)
        #expect(fixture.reminders.count >= 200)
        #expect(fixture.familyTasks.count >= 100)
        #expect(fixture.ledgerEntries.count >= 500)
        #expect(fixture.photoLogs.count >= 50)
        #expect(hasMemorialPet)
        #expect(hasMemorialHuman)
        #expect(hasPrivacyLockedHuman)
    }

    private func buildHomeSnapshot(_ fixture: DenseFixture) -> VerticalSolidHomeSnapshot {
        let homeSource = fixture.homeSource
        let privacy = DenseFixtureHumanPrivacyManager()
        let todayFocus = DenseFixtureTodayFocusManager()
        let healthAlerts = DenseFixturePetHealthAlertEngine()

        return measureWallClockBudget("Home vertical snapshot", budgetMilliseconds: 3000) {
            VerticalSolidHomeSnapshotBuilder.build(
                from: homeSource,
                now: fixture.now,
                privacy: privacy,
                todayFocus: todayFocus,
                healthAlerts: healthAlerts
            )
        }
    }

    private func buildTodayFocusSnapshot(_ fixture: DenseFixture) -> TodayFocusSnapshot {
        let livingPets = fixture.pets.filter { pet in !pet.hasPassedAway }
        let activeHumanId = fixture.humans[0].id.uuidString
        let todayFocus = DenseFixtureTodayFocusManager()
        let healthAlerts = DenseFixturePetHealthAlertEngine()

        return measureWallClockBudget("Today Focus snapshot", budgetMilliseconds: 2500) {
            TodayFocusSnapshot.make(
                pets: livingPets,
                plants: fixture.plants,
                reminders: fixture.reminders,
                events: fixture.events,
                humans: fixture.humans,
                activeHumanId: activeHumanId,
                careLogs: fixture.careLogs,
                walkLogs: fixture.walkLogs,
                pottyLogs: fixture.pottyLogs,
                humanWeightLogs: fixture.humanWeightLogs,
                familyTasks: fixture.familyTasks,
                exchangeRequests: fixture.exchangeRequests,
                todayFocus: todayFocus,
                healthAlerts: healthAlerts
            )
        }
    }

    private func buildCalendarSnapshot(_ fixture: DenseFixture) -> CalendarTimelineSnapshot {
        let events = fixture.events
        let pets = fixture.pets

        return measureWallClockBudget("Calendar timeline snapshot", budgetMilliseconds: 1500) {
            CalendarSnapshotBuilder.buildTimeline(
                events: events,
                allEvents: events,
                pets: pets,
                now: fixture.now
            )
        }
    }

    private func measureWallClockBudget<T>(
        _ label: String,
        budgetMilliseconds: Double,
        operation: () throws -> T
    ) rethrows -> T {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let value = try operation()
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
        #expect(
            elapsedMilliseconds <= budgetMilliseconds,
            "\(label) took \(Int(elapsedMilliseconds))ms; budget \(Int(budgetMilliseconds))ms"
        )
        return value
    }
}

@MainActor
private struct DenseFixture {
    let now: Date
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    let electronicPets: [OasisElectronicPet]
    let events: [Event]
    let reminders: [Reminder]
    let careLogs: [PetCareLog]
    let walkLogs: [PetWalkLog]
    let pottyLogs: [PetPottyLog]
    let humanWeightLogs: [HumanWeightLog]
    let familyTasks: [FamilyCollaborationTask]
    let exchangeRequests: [CoconutExchangeRequest]
    let ledgerEntries: [CoconutLedgerEntry]
    let photoLogs: [PetPhotoLog]

    var homeSource: VerticalSolidHomeSourceState {
        VerticalSolidHomeSourceState(
            pets: pets,
            humans: humans,
            plants: plants,
            electronicPets: electronicPets,
            events: events,
            pendingReminders: reminders,
            humanMedications: [],
            humanMedicationLogs: [],
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            familyTasks: familyTasks,
            exchangeRequests: exchangeRequests,
            activeHumanIdRaw: humans[0].id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            petBondVaultRevision: 0,
            equippedTitleRaw: "",
            language: AppLanguage.code
        )
    }

    static func make(now: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> DenseFixture {
        let humans = makeHumans(now: now)
        let pets = makePets(now: now)
        let plants = makePlants(now: now)
        let electronicPets = makeElectronicPets(now: now)
        let events = makeEvents(pets: pets, humans: humans, now: now)
        let reminders = attachReminders(to: events, now: now)

        return DenseFixture(
            now: now,
            pets: pets,
            humans: humans,
            plants: plants,
            electronicPets: electronicPets,
            events: events,
            reminders: reminders,
            careLogs: makeCareLogs(pets: pets, humans: humans, now: now),
            walkLogs: makeWalkLogs(pets: pets, humans: humans, now: now),
            pottyLogs: makePottyLogs(pets: pets, humans: humans, now: now),
            humanWeightLogs: makeHumanWeightLogs(humans: humans, now: now),
            familyTasks: makeFamilyTasks(humans: humans, pets: pets, now: now),
            exchangeRequests: makeExchangeRequests(humans: humans, now: now),
            ledgerEntries: makeLedgerEntries(humans: humans, pets: pets, now: now),
            photoLogs: makePhotoLogs(pets: pets, now: now)
        )
    }

    private static func makeHumans(now: Date) -> [Human] {
        (0 ..< 4).map { index in
            let human = Human(name: "Human \(index)")
            human.createdAt = now.addingTimeInterval(TimeInterval(-index * 20000))
            human.coconutBalance = 100 + index * 25
            if index == 2 {
                human.setPrivate(.weight, true)
            }
            if index == 3 {
                human.passedAwayDate = now.addingTimeInterval(-86400 * 30)
            }
            return human
        }
    }

    private static func makePets(now: Date) -> [Pet] {
        (0 ..< 4).map { index in
            let pet = Pet(name: "Pet \(index)", species: index.isMultiple(of: 2) ? "Dog" : "Cat")
            pet.createdAt = now.addingTimeInterval(TimeInterval(-index * 10000))
            pet.currentStreak = 2 + index
            pet.coconutBalance = 80 + index * 20
            if index == 3 {
                pet.passedAwayDate = now.addingTimeInterval(-86400 * 45)
            }
            return pet
        }
    }

    private static func makePlants(now: Date) -> [Plant] {
        (0 ..< 6).map { index in
            let plant = Plant(
                name: "Plant \(index)",
                species: "Species \(index)",
                location: "Shelf \(index)",
                wateringIntervalDays: 3 + index,
                fertilizingIntervalDays: 20 + index
            )
            plant.createdAt = now.addingTimeInterval(TimeInterval(-index * 3600))
            plant.lastWateredDate = now.addingTimeInterval(TimeInterval(-86400 * (index + 1)))
            return plant
        }
    }

    private static func makeElectronicPets(now: Date) -> [OasisElectronicPet] {
        (0 ..< 2).map { index in
            OasisElectronicPet(
                catalogId: "dense-critter-\(index)",
                nameZh: "电子伙伴\(index)",
                nameEn: "Critter \(index)",
                nameDe: "Critter \(index)",
                emoji: index == 0 ? "*" : "+",
                rarity: index == 0 ? .common : .rare,
                isFeaturedOnOasis: true,
                sourceLevel: index + 1,
                obtainedAt: now.addingTimeInterval(TimeInterval(-index * 7200))
            )
        }
    }

    private static func makeEvents(pets: [Pet], humans: [Human], now: Date) -> [Event] {
        let dailyKinds: [(String, EventType)] = [
            ("feeding", .foodChange),
            ("water", .daily),
            ("potty", .litterBox),
            ("walk", .daily),
            ("grooming", .grooming)
        ]
        var events: [Event] = []
        events.reserveCapacity(pets.count * 1095 * dailyKinds.count + 120)

        for pet in pets {
            for dayOffset in 0 ..< 1095 {
                let day = now.addingTimeInterval(TimeInterval(-dayOffset * 86400))
                for (kindIndex, kind) in dailyKinds.enumerated() {
                    let event = Event(
                        title: "\(pet.name) \(kind.0) \(dayOffset)",
                        startDate: day.addingTimeInterval(TimeInterval(kindIndex * 900)),
                        eventType: kind.1.rawValue,
                        relatedEntityType: "pet",
                        relatedEntityId: pet.id.uuidString
                    )
                    if dayOffset.isMultiple(of: 180), kindIndex == 0 {
                        event.recurrenceDays = 7
                        event.recurrenceEndDate = now.addingTimeInterval(86400 * 90)
                    }
                    events.append(event)
                }
            }
        }

        for index in 0 ..< 120 {
            let human = humans[index % humans.count]
            let event = Event(
                title: "Human task \(index)",
                startDate: now.addingTimeInterval(TimeInterval((index - 60) * 3600)),
                eventType: EventType.task.rawValue,
                relatedEntityType: "human",
                relatedEntityId: human.id.uuidString
            )
            event.assigneeId = human.id.uuidString
            events.append(event)
        }

        return events
    }

    private static func attachReminders(to events: [Event], now: Date) -> [Reminder] {
        events.prefix(240).enumerated().map { index, event in
            let reminder = Reminder(
                event: event,
                scheduledAt: now.addingTimeInterval(TimeInterval((index - 180) * 900))
            )
            if index.isMultiple(of: 11) {
                reminder.statusEnum = .failed
            }
            event.reminders = [reminder]
            return reminder
        }
    }

    private static func makeCareLogs(pets: [Pet], humans: [Human], now: Date) -> [PetCareLog] {
        (0 ..< 720).map { index in
            PetCareLog(
                date: now.addingTimeInterval(TimeInterval(-index * 7200)),
                type: index.isMultiple(of: 2) ? .feeding : .watering,
                amountGrams: Double(20 + index % 40),
                amountMl: Double(80 + index % 120),
                pet: pets[index % pets.count],
                executorId: humans[index % humans.count].id.uuidString
            )
        }
    }

    private static func makeWalkLogs(pets: [Pet], humans: [Human], now: Date) -> [PetWalkLog] {
        (0 ..< 240).map { index in
            let log = PetWalkLog(
                startDate: now.addingTimeInterval(TimeInterval(-index * 10800)),
                pet: pets[index % pets.count],
                executorId: humans[index % humans.count].id.uuidString
            )
            log.endDate = log.startDate.addingTimeInterval(1800)
            log.distanceMeters = Double(500 + index * 12)
            return log
        }
    }

    private static func makePottyLogs(pets: [Pet], humans: [Human], now: Date) -> [PetPottyLog] {
        (0 ..< 360).map { index in
            PetPottyLog(
                date: now.addingTimeInterval(TimeInterval(-index * 5400)),
                type: PottyType.allCases[index % PottyType.allCases.count],
                pet: pets[index % pets.count],
                executorId: humans[index % humans.count].id.uuidString
            )
        }
    }

    private static func makeHumanWeightLogs(humans: [Human], now: Date) -> [HumanWeightLog] {
        var logs: [HumanWeightLog] = []
        logs.reserveCapacity(120)

        for index in 0 ..< 120 {
            let human = humans[index % humans.count]
            let date = now.addingTimeInterval(TimeInterval(-index * 86400 * 7))
            let weight = 60 + Double(index % 20)
            let log = HumanWeightLog(
                date: date,
                weight: weight,
                human: human,
                executorId: human.id.uuidString
            )
            logs.append(log)
        }

        return logs
    }

    private static func makeFamilyTasks(humans: [Human], pets: [Pet], now: Date) -> [FamilyCollaborationTask] {
        var tasks: [FamilyCollaborationTask] = []
        tasks.reserveCapacity(120)

        for index in 0 ..< 120 {
            let status: FamilyCollaborationTaskStatus = switch index % 5 {
            case 0: .active
            case 1: .claimed
            case 2: .pendingReview
            case 3: .completed
            default: .cancelled
            }
            let relatedPetId = pets[index % pets.count].id.uuidString
            let creator = humans[index % humans.count]
            let assignee = humans[0]
            let task = FamilyCollaborationTask(
                title: "Dense task \(index)",
                kind: index.isMultiple(of: 3) ? .bounty : .careReminder,
                status: status,
                relatedPetId: relatedPetId,
                createdById: creator.id.uuidString,
                createdByName: creator.name,
                assignedToId: assignee.id.uuidString,
                assignedToName: assignee.name,
                rewardCoconuts: index.isMultiple(of: 3) ? 5 : 0,
                dueAt: now.addingTimeInterval(TimeInterval((index - 40) * 3600)),
                createdAt: now.addingTimeInterval(TimeInterval(-index * 1800))
            )
            tasks.append(task)
        }

        return tasks
    }

    private static func makeExchangeRequests(humans: [Human], now: Date) -> [CoconutExchangeRequest] {
        var requests: [CoconutExchangeRequest] = []
        requests.reserveCapacity(24)

        for index in 0 ..< 24 {
            let sender = humans[(index + 1) % humans.count]
            let receiver = humans[0]
            let request = CoconutExchangeRequest(
                senderId: sender.id.uuidString,
                senderName: sender.name,
                receiverId: receiver.id.uuidString,
                receiverName: receiver.name,
                coconutCost: 500 + index * 10,
                currencyCode: "USD",
                localAmount: Double(index + 1),
                status: index.isMultiple(of: 4) ? .confirmed : .pending,
                createdAt: now.addingTimeInterval(TimeInterval(-index * 2400))
            )
            requests.append(request)
        }

        return requests
    }

    private static func makeLedgerEntries(humans: [Human], pets: [Pet], now: Date) -> [CoconutLedgerEntry] {
        var entries: [CoconutLedgerEntry] = []
        entries.reserveCapacity(520)

        for index in 0 ..< 520 {
            let ownerKind: CoconutWalletOwnerKind = index.isMultiple(of: 2) ? .human : .pet
            let ownerId = ownerKind == .human
                ? humans[index % humans.count].id.uuidString
                : pets[index % pets.count].id.uuidString
            let ownerName = ownerKind == .human
                ? humans[index % humans.count].name
                : pets[index % pets.count].name
            let accountKey = CoconutAccountKey.key(ownerKind: ownerKind, ownerId: ownerId)
            let entry = CoconutLedgerEntry(
                transactionKey: "dense-ledger-\(index)",
                accountKey: accountKey,
                ownerKind: ownerKind,
                ownerId: ownerId,
                ownerName: ownerName,
                delta: 1,
                balanceBefore: index,
                balanceAfter: index + 1,
                entryKind: .reward,
                source: .careEvent,
                title: "Dense reward \(index)",
                emoji: "+",
                occurredAt: now.addingTimeInterval(TimeInterval(-index * 600))
            )
            entries.append(entry)
        }

        return entries
    }

    private static func makePhotoLogs(pets: [Pet], now: Date) -> [PetPhotoLog] {
        (0 ..< 56).map { index in
            PetPhotoLog(
                imageData: index.isMultiple(of: 7) ? Data() : Data([UInt8(index % 255)]),
                date: now.addingTimeInterval(TimeInterval(-index * 12000)),
                note: "dense photo \(index)",
                pet: pets[index % pets.count]
            )
        }
    }
}

@MainActor
private final class DenseFixtureHumanPrivacyManager: HumanPrivacyManaging {
    func field(forHumanAction _: String) -> HumanPrivateField? {
        nil
    }

    func isLocked(_ field: HumanPrivateField, for human: Human, viewedBy viewerId: UUID?) -> Bool {
        human.isPrivate(field, viewedBy: viewerId)
    }

    func unlockedHumans(for field: HumanPrivateField, from humans: [Human], viewedBy viewerId: UUID?) -> [Human] {
        humans.filter { !isLocked(field, for: $0, viewedBy: viewerId) }
    }

    func publicHumans(for field: HumanPrivateField, from humans: [Human]) -> [Human] {
        humans.filter { !$0.privateFields.contains(field.rawValue) }
    }

    func isPubliclyHidden(_ field: HumanPrivateField, for human: Human) -> Bool {
        human.privateFields.contains(field.rawValue)
    }

    func isPubliclyHidden(_ field: HumanPrivateField, humanId: String?, in humans: [Human]) -> Bool {
        guard let humanId, let human = humans.first(where: { $0.id.uuidString == humanId }) else { return false }
        return isPubliclyHidden(field, for: human)
    }

    func isLocked(_ field: HumanPrivateField, humanId: String?, in humans: [Human], viewedBy viewerId: UUID?) -> Bool {
        guard let humanId, let human = humans.first(where: { $0.id.uuidString == humanId }) else { return false }
        return isLocked(field, for: human, viewedBy: viewerId)
    }

    func isHumanQuickActionLocked(_: QuickActionItem, human: Human?, viewedBy viewerId: UUID?) -> Bool {
        guard let human else { return false }
        return human.isPrivate(.medication, viewedBy: viewerId)
    }

    func badgeText(for field: HumanPrivateField, human: Human, viewedBy viewerId: UUID?) -> String {
        isLocked(field, for: human, viewedBy: viewerId) ? "Locked" : ""
    }

    func lockedMessage(for _: HumanPrivateField) -> String {
        "Locked"
    }
}

@MainActor
private final class DenseFixtureTodayFocusManager: TodayFocusManaging {
    func refreshedQuests(
        _ quests: [IslandQuest],
        pets _: [Pet],
        humans _: [Human],
        events _: [Event],
        careLogs _: [PetCareLog],
        walkLogs _: [PetWalkLog],
        pottyLogs _: [PetPottyLog],
        humanWeightLogs _: [HumanWeightLog],
        calendar _: Calendar,
        now _: Date
    ) -> [IslandQuest] {
        quests
    }

    func quest(_: IslandQuest, matchesCompletedEntity _: UUID) -> Bool {
        false
    }

    func completeEvent(_ event: Event, on _: Date, context _: ModelContext) -> TodayFocusEventCompletionCommandResult {
        TodayFocusEventCompletionCommandResult(eventID: event.id, isCompleted: true, didChange: true)
    }

    func awardDailyCompletionIfNeeded(
        context _: ModelContext,
        executorId _: String?,
        visibleQuests _: [IslandQuest],
        visibleSnapshot _: TodayFocusSnapshot?
    ) -> EconomyRewardResult? {
        nil
    }

    func currentStreak(activeHumanId _: String) -> Int {
        0
    }
}

@MainActor
private final class DenseFixturePetHealthAlertEngine: PetHealthAlerting {
    func scanAlerts(pets _: [Pet]) -> [HealthAlert] {
        []
    }
}
