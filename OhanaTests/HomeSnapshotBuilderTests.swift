import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct HomeSnapshotBuilderTests {
    @Test func pottyDashboardLedgerEntriesFilterPetPottyEvents() {
        let petId = UUID()
        let otherPetId = UUID()
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let olderEvent = CareLedgerEvent(
            id: UUID(),
            occurredAt: older,
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .potty,
            actionType: PottyType.pee.rawValue
        )
        let newerEvent = CareLedgerEvent(
            id: UUID(),
            occurredAt: newer,
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .potty,
            actionType: PottyType.softPoop.rawValue
        )
        let otherPetEvent = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: otherPetId.uuidString,
            eventKind: .potty,
            actionType: PottyType.perfectPoop.rawValue
        )
        let wrongKindEvent = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .care,
            actionType: CareType.litter.rawValue
        )
        let invalidTypeEvent = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .potty,
            actionType: "not-a-potty-type"
        )

        let entries = IslandPottyDashboardLedgerEntry.entries(
            from: [olderEvent, otherPetEvent, wrongKindEvent, invalidTypeEvent, newerEvent],
            petIds: [petId]
        )

        #expect(entries.map(\.id) == [newerEvent.id, olderEvent.id])
        #expect(entries.map(\.pottyType) == [.softPoop, .pee])
        #expect(entries.allSatisfy { $0.petId == petId })
    }

    @Test func petWeightLedgerEntriesFilterPetWeightEvents() {
        let petId = UUID()
        let otherPetId = UUID()
        let legacyLogId = UUID()
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let olderEvent = CareLedgerEvent(
            id: UUID(),
            occurredAt: older,
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.2,
            amountUnit: "kg",
            legacyModelName: "PetWeightLog",
            legacyModelId: legacyLogId.uuidString
        )
        let newerEvent = CareLedgerEvent(
            id: UUID(),
            occurredAt: newer,
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.8,
            amountUnit: "kg"
        )
        let otherPetEvent = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: otherPetId.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 6.1,
            amountUnit: "kg"
        )
        let wrongKindEvent = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .expense,
            actionType: "petWeight",
            amountValue: 12,
            amountUnit: "currency"
        )
        let wrongActionEvent = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .weight,
            actionType: "humanWeight",
            amountValue: 70,
            amountUnit: "kg"
        )
        let zeroEvent = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: petId.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 0,
            amountUnit: "kg"
        )

        let entries = PetWeightLedgerEntry.entries(
            from: [olderEvent, otherPetEvent, wrongKindEvent, wrongActionEvent, zeroEvent, newerEvent],
            petId: petId
        )

        #expect(entries.map(\.id) == [newerEvent.id, olderEvent.id])
        #expect(entries.map(\.weightKilograms) == [4.8, 4.2])
        #expect(entries.last?.legacyLogId == legacyLogId)
    }

    @Test func snapshotOrdersVisiblePetsHumansAndCrittersByCreationDate() throws {
        let olderPet = Pet(name: "Momo", species: "猫")
        olderPet.createdAt = Date(timeIntervalSince1970: 10)

        let human = Human(name: "Guan")
        human.createdAt = Date(timeIntervalSince1970: 20)

        let critter = OasisElectronicPet(
            catalogId: "test-critter",
            nameZh: "小岛灵",
            nameEn: "Islandling",
            nameDe: "Inselchen",
            emoji: "✨",
            rarity: .common,
            sourceLevel: 1,
            obtainedAt: Date(timeIntervalSince1970: 30)
        )
        critter.isFeaturedOnOasis = true

        let cards = HomeSnapshotBuilder.buildCards(
            pets: [olderPet],
            humans: [human],
            electronicPets: [critter],
            events: [],
            humanMedications: [],
            humanMedicationLogs: [],
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            now: Date(timeIntervalSince1970: 100)
        )

        #expect(cards.map(\.id) == [critter.id, human.id, olderPet.id])
        #expect(cards[0].isElectronicPet)
        #expect(cards[1].isHuman)
        #expect(cards[2].isReal)
    }

    @Test func snapshotHonorsHiddenPetsAndHiddenHumans() {
        let visiblePet = Pet(name: "Visible", species: "狗")
        let hiddenPet = Pet(name: "Hidden", species: "猫")
        let hiddenHuman = Human(name: "Private")
        hiddenHuman.shouldShowOnHome = false

        let cards = HomeSnapshotBuilder.buildCards(
            pets: [visiblePet, hiddenPet],
            humans: [hiddenHuman],
            electronicPets: [],
            events: [],
            humanMedications: [],
            humanMedicationLogs: [],
            hiddenPetIDsRaw: hiddenPet.id.uuidString,
            homeCardOrderRaw: "",
            showDummyCards: false
        )

        #expect(cards.map(\.id) == [visiblePet.id])
    }

    @Test func snapshotAppliesPreferredCardOrder() {
        let first = Pet(name: "First", species: "狗")
        let second = Pet(name: "Second", species: "猫")
        first.createdAt = Date(timeIntervalSince1970: 20)
        second.createdAt = Date(timeIntervalSince1970: 10)

        let cards = HomeSnapshotBuilder.buildCards(
            pets: [first, second],
            humans: [],
            electronicPets: [],
            events: [],
            humanMedications: [],
            humanMedicationLogs: [],
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: second.id.uuidString,
            showDummyCards: false
        )

        #expect(cards.map(\.id) == [second.id, first.id])
    }

    @Test func snapshotDecoratesOverduePetStatus() throws {
        let now = Date(timeIntervalSince1970: 10000)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "喂食",
            startDate: now.addingTimeInterval(-3600),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: "pet",
            relatedEntityId: pet.id.uuidString
        )
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        let reminder = Reminder(event: event, scheduledAt: now.addingTimeInterval(-1800))
        event.reminders = [reminder]

        let card = try #require(HomeSnapshotBuilder.buildCards(
            pets: [pet],
            humans: [],
            electronicPets: [],
            events: [event],
            humanMedications: [],
            humanMedicationLogs: [],
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            now: now
        ).first)

        #expect(card.statusBadgeText == "喂食")
        #expect(card.statusBadgeIsWarning)
    }

    @Test func verticalSnapshotPrecomputesHeroPreparationRevision() {
        let now = Date(timeIntervalSince1970: 20000)
        let pet = Pet(name: "Momo", species: "猫")

        let first = makeVerticalSnapshot(
            from: makeVerticalSource(pets: [pet]),
            now: now
        )
        pet.name = "Nori"
        let second = makeVerticalSnapshot(
            from: makeVerticalSource(pets: [pet]),
            now: now
        )

        #expect(!first.heroPreparationRevision.isEmpty)
        #expect(first.heroPreparationRevision != second.heroPreparationRevision)
    }

    @Test func avatarPreloadSignatureUsesPreparedSnapshotCardsOnly() {
        let visiblePet = Pet(name: "Momo", species: "猫")
        visiblePet.avatarImageData = Data([1, 2, 3, 4])
        let hiddenPet = Pet(name: "Hidden", species: "狗")
        hiddenPet.avatarImageData = Data([8, 7, 6, 5])

        let snapshot = makeVerticalSnapshot(
            from: makeVerticalSource(
                pets: [visiblePet, hiddenPet],
                hiddenPetIDsRaw: hiddenPet.id.uuidString
            )
        )
        let payloads = VerticalSolidHomePreloadPlanner.avatarPayloads(snapshot: snapshot)
        let signature = VerticalSolidHomePreloadPlanner.avatarSignature(for: payloads)

        #expect(payloads.map(\.id) == [visiblePet.id])
        #expect(signature.contains(visiblePet.id.uuidString))
        #expect(!signature.contains(hiddenPet.id.uuidString))
    }

    @Test func verticalSnapshotCardsCarryAvatarSignature() throws {
        let avatarData = Data([2, 4, 6, 8, 10])
        let pet = Pet(name: "Momo", species: "猫")
        pet.avatarImageData = avatarData

        let snapshot = makeVerticalSnapshot(
            from: makeVerticalSource(pets: [pet])
        )
        let card = try #require(snapshot.cards.first)

        #expect(card.avatarImageSignature == FocusWalletAvatarCache.signature(for: avatarData))
    }

    @Test func popoutPreloadSignatureUsesPreparedSnapshotCardsOnly() {
        let visiblePet = Pet(name: "Momo", species: "猫")
        visiblePet.cardStyleRaw = "popout"
        visiblePet.cardPopoutImageData = Data([1, 3, 5, 7])
        let hiddenPet = Pet(name: "Hidden", species: "狗")
        hiddenPet.cardStyleRaw = "popout"
        hiddenPet.cardPopoutImageData = Data([2, 4, 6, 8])

        let snapshot = makeVerticalSnapshot(
            from: makeVerticalSource(
                pets: [visiblePet, hiddenPet],
                hiddenPetIDsRaw: hiddenPet.id.uuidString
            )
        )
        let payloads = VerticalSolidHomePreloadPlanner.popoutPayloads(snapshot: snapshot)
        let signature = VerticalSolidHomePreloadPlanner.popoutSignature(for: payloads)

        #expect(payloads.map(\.id) == [visiblePet.id])
        #expect(signature.contains(visiblePet.id.uuidString))
        #expect(!signature.contains(hiddenPet.id.uuidString))
    }

    @Test func verticalSnapshotCardsCarryPopoutSignature() throws {
        let popoutData = Data([9, 7, 5, 3])
        let pet = Pet(name: "Momo", species: "猫")
        pet.cardStyleRaw = "popout"
        pet.cardPopoutImageData = popoutData

        let snapshot = makeVerticalSnapshot(
            from: makeVerticalSource(pets: [pet])
        )
        let card = try #require(snapshot.cards.first)

        #expect(card.cardPopoutImageSignature == FocusWalletAvatarCache.signature(for: popoutData))
    }

    @Test func verticalSourceSignatureIncludesPetBondRevision() {
        let pet = Pet(name: "Momo", species: "猫")
        let first = VerticalSolidHomeSnapshotBuilder.signature(
            for: makeVerticalSource(pets: [pet], petBondVaultRevision: 1)
        )
        let second = VerticalSolidHomeSnapshotBuilder.signature(
            for: makeVerticalSource(pets: [pet], petBondVaultRevision: 2)
        )

        #expect(first != second)
    }

    @Test func verticalSnapshotCardsCarryPetBondAppearanceFlags() throws {
        let pet = Pet(name: "Momo", species: "猫")
        PetBondVaultStore.unlock(.cardBorder, for: pet.id)
        PetBondVaultStore.unlock(.nameplate, for: pet.id)

        let snapshot = makeVerticalSnapshot(
            from: makeVerticalSource(
                pets: [pet],
                petBondVaultRevision: UserDefaults.standard.integer(forKey: PetBondVaultStore.revisionKey)
            )
        )
        let card = try #require(snapshot.cards.first)

        #expect(card.petBondCardBorderActive)
        #expect(card.petBondNameplateActive)
    }

    @Test func verticalSnapshotActiveHumanCarriesEquippedTitleBadge() throws {
        let human = Human(name: "Owner")

        let snapshot = makeVerticalSnapshot(
            from: makeVerticalSource(
                humans: [human],
                activeHumanIdRaw: human.id.uuidString,
                equippedTitleRaw: "title_guardian"
            )
        )
        let card = try #require(snapshot.cards.first)

        #expect(card.equippedTitleBadgeText == "🛡️ 守护者")
    }

    @Test func focusCardCarriesTogetherHeadlineText() {
        let pet = Pet(name: "Momo", species: "猫")
        pet.createdAt = Date(timeIntervalSince1970: 1000)
        pet.homeDate = Date(timeIntervalSince1970: 1000)

        let card = FocusCard.from(pet, includeAvatarData: false)

        #expect(card.togetherHeadlineText?.isEmpty == false)
    }

    @MainActor
    @Test func liveAvatarSourceDoesNotCreateEntryFromRawCardData() {
        let pet = Pet(name: "Momo", species: "猫")
        pet.avatarImageData = Data([3, 1, 4, 1, 5, 9])
        let card = FocusCard.from(pet)

        let source = FocusHomeFrozenAvatarSource.live(for: card)

        #expect(source.image == nil)
    }

    private func makeVerticalSource(
        pets: [Pet] = [],
        humans: [Human] = [],
        plants: [Plant] = [],
        electronicPets: [OasisElectronicPet] = [],
        hiddenPetIDsRaw: String = "",
        activeHumanIdRaw: String = "",
        petBondVaultRevision: Int = 0,
        equippedTitleRaw: String = ""
    ) -> VerticalSolidHomeSourceState {
        VerticalSolidHomeSourceState(
            pets: pets,
            humans: humans,
            plants: plants,
            electronicPets: electronicPets,
            events: [],
            pendingReminders: [],
            humanMedications: [],
            humanMedicationLogs: [],
            todayFocusCareLedgerEntries: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
            humanWeightLogs: [],
            familyTasks: [],
            exchangeRequests: [],
            activeHumanIdRaw: activeHumanIdRaw,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: "",
            showDummyCards: false,
            petBondVaultRevision: petBondVaultRevision,
            equippedTitleRaw: equippedTitleRaw,
            language: AppLanguage.code
        )
    }

    private func makeVerticalSnapshot(
        from source: VerticalSolidHomeSourceState,
        now: Date = Date()
    ) -> VerticalSolidHomeSnapshot {
        VerticalSolidHomeSnapshotBuilder.build(
            from: source,
            now: now,
            privacy: TestHumanPrivacyManager(),
            todayFocus: TestTodayFocusManager(),
            healthAlerts: TestPetHealthAlertEngine()
        )
    }
}

@MainActor
private final class TestHumanPrivacyManager: HumanPrivacyManaging {
    func field(forHumanAction _: String) -> HumanPrivateField? {
        nil
    }

    func isLocked(_: HumanPrivateField, for _: Human, viewedBy _: UUID?) -> Bool {
        false
    }

    func unlockedHumans(for _: HumanPrivateField, from humans: [Human], viewedBy _: UUID?) -> [Human] {
        humans
    }

    func publicHumans(for _: HumanPrivateField, from humans: [Human]) -> [Human] {
        humans
    }

    func isPubliclyHidden(_: HumanPrivateField, for _: Human) -> Bool {
        false
    }

    func isPubliclyHidden(_: HumanPrivateField, humanId _: String?, in _: [Human]) -> Bool {
        false
    }

    func isLocked(_: HumanPrivateField, humanId _: String?, in _: [Human], viewedBy _: UUID?) -> Bool {
        false
    }

    func isHumanQuickActionLocked(_: QuickActionItem, human _: Human?, viewedBy _: UUID?) -> Bool {
        false
    }

    func badgeText(for _: HumanPrivateField, human _: Human, viewedBy _: UUID?) -> String {
        ""
    }

    func lockedMessage(for _: HumanPrivateField) -> String {
        ""
    }
}

@MainActor
private final class TestTodayFocusManager: TodayFocusManaging {
    func refreshedQuests(
        _ quests: [IslandQuest],
        pets _: [Pet],
        humans _: [Human],
        events _: [Event],
        careLedgerEntries _: [TodayFocusCareLedgerEntry],
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
private final class TestPetHealthAlertEngine: PetHealthAlerting {
    func scanAlerts(pets _: [Pet]) -> [HealthAlert] {
        []
    }
}
