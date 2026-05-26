import Foundation
import Testing
@testable import Ohana

struct HomeSnapshotBuilderTests {
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
        let now = Date(timeIntervalSince1970: 10_000)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "喂食",
            startDate: now.addingTimeInterval(-3_600),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: "pet",
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: now.addingTimeInterval(-1_800))
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
}
