import Foundation
@testable import Ohana
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct MemberCreationServiceTests {
    @Test func firstPetSaves2DAvatarWithoutConsumingInventoryPass() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext

        let result = try MemberCreationService.save(
            draft: petDraft(name: "Momo", source: .avatar2D),
            existingPets: [],
            existingHumans: [],
            context: context,
            countryCode: "CN"
        )

        #expect(result.pet?.name == "Momo")
        #expect(result.pet?.avatarImageData == avatarData)
        #expect(Avatar2DAccess.extraPassCount == 0)
        #expect(try context.fetch(FetchDescriptor<Pet>()).count == 1)
    }

    @Test func secondHumanUsingInventoryPassConsumesOnePass() throws {
        resetGlobalState()
        Avatar2DAccess.addExtraPasses(1)
        let container = try makeContainer()
        let context = container.mainContext
        let existing = Human(name: "Ava")
        context.insert(existing)
        try context.save()

        let result = try MemberCreationService.save(
            draft: humanDraft(name: "Nico", source: .avatar2D),
            existingPets: [],
            existingHumans: [existing],
            context: context,
            countryCode: "CN"
        )

        #expect(result.human?.name == "Nico")
        #expect(Avatar2DAccess.extraPassCount == 0)
    }

    @Test func secondMemberCannotSave2DAvatarWithoutPass() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let existing = Human(name: "Ava")
        context.insert(existing)
        try context.save()

        do {
            _ = try MemberCreationService.save(
                draft: humanDraft(name: "Nico", source: .avatar2D),
                existingPets: [],
                existingHumans: [existing],
                context: context,
                countryCode: "CN"
            )
            #expect(Bool(false))
        } catch let error as MemberCreationService.ServiceError {
            if case .avatarPassRequired = error {
                #expect(true)
            } else {
                Issue.record("Expected avatar pass requirement")
            }
        }
        #expect(Avatar2DAccess.extraPassCount == 0)
    }

    @Test func cardPurchaseDeductsCoconutsRecordsLedgerAndSaveConsumesPass() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let payer = Human(name: "Ava")
        payer.coconutBalance = MemberCreationService.avatarPassCost + 200
        context.insert(payer)
        try context.save()
        UserDefaults.standard.set(payer.id.uuidString, forKey: "currentActiveHumanId")

        try MemberCreationService.purchaseAvatarPassForCurrentDraft(
            humans: [payer],
            context: context,
            l: L10n("en")
        )

        #expect(payer.coconutBalance == 200)
        #expect(Avatar2DAccess.extraPassCount == 1)
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgers.count == 1)
        #expect(ledgers.first?.actionType == "memberCreationAvatarPassPurchase")
        #expect(ledgers.first?.coconutDelta == -MemberCreationService.avatarPassCost)

        _ = try MemberCreationService.save(
            draft: humanDraft(name: "Nico", source: .avatar2D),
            existingPets: [],
            existingHumans: [payer],
            context: context,
            countryCode: "CN"
        )

        #expect(Avatar2DAccess.extraPassCount == 0)
    }

    @Test func purchaseThenCancelLeavesPassInInventory() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let payer = Human(name: "Ava")
        payer.coconutBalance = MemberCreationService.avatarPassCost
        context.insert(payer)
        try context.save()

        try MemberCreationService.purchaseAvatarPassForCurrentDraft(
            humans: [payer],
            context: context,
            l: L10n("en")
        )

        #expect(payer.coconutBalance == 0)
        #expect(Avatar2DAccess.extraPassCount == 1)
    }

    @Test func insufficientBalanceDoesNotChangeCoconutsLedgerOrInventory() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let payer = Human(name: "Ava")
        payer.coconutBalance = MemberCreationService.avatarPassCost - 1
        context.insert(payer)
        try context.save()

        do {
            try MemberCreationService.purchaseAvatarPassForCurrentDraft(
                humans: [payer],
                context: context,
                l: L10n("en")
            )
            #expect(Bool(false))
        } catch let error as MemberCreationService.ServiceError {
            if case let .insufficientCoconuts(missing) = error {
                #expect(missing == 1)
            } else {
                Issue.record("Expected insufficient coconuts")
            }
        }

        #expect(payer.coconutBalance == MemberCreationService.avatarPassCost - 1)
        #expect(Avatar2DAccess.extraPassCount == 0)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func customImageCreationDoesNotConsumeAvatarPass() throws {
        resetGlobalState()
        Avatar2DAccess.addExtraPasses(1)
        let container = try makeContainer()
        let context = container.mainContext
        let existing = Pet(name: "Momo", species: "狗", breed: "柴犬")
        context.insert(existing)
        try context.save()

        _ = try MemberCreationService.save(
            draft: petDraft(name: "Kiki", source: .customImage),
            existingPets: [existing],
            existingHumans: [],
            context: context,
            countryCode: "CN"
        )

        #expect(Avatar2DAccess.extraPassCount == 1)
    }

    @Test func placeholderAvatarDoesNotAutoConsumePurchasedPass() throws {
        resetGlobalState()
        Avatar2DAccess.addExtraPasses(1)
        let container = try makeContainer()
        let context = container.mainContext
        let existing = Human(name: "Ava")
        context.insert(existing)
        try context.save()

        var draft = humanDraft(name: "Nico", source: .placeholder)
        draft.avatarImageData = nil

        let result = try MemberCreationService.save(
            draft: draft,
            existingPets: [],
            existingHumans: [existing],
            context: context,
            countryCode: "CN"
        )

        #expect(result.human?.avatarImageData == nil)
        #expect(Avatar2DAccess.extraPassCount == 1)
    }

    @Test func humanRoleDefaultsRemainForPermissionsButHomeCardHidesRole() throws {
        resetGlobalState()
        UserDefaults.standard.set("zh", forKey: "appLanguage")
        let container = try makeContainer()
        let context = container.mainContext

        let first = try MemberCreationService.save(
            draft: humanDraft(name: "Ava", source: .placeholder),
            existingPets: [],
            existingHumans: [],
            context: context,
            countryCode: "CN"
        ).human

        #expect(first?.role == "owner")

        let second = try MemberCreationService.save(
            draft: humanDraft(name: "Nico", source: .placeholder),
            existingPets: [],
            existingHumans: first.map { [$0] } ?? [],
            context: context,
            countryCode: "CN"
        ).human

        #expect(second?.role == "member")
        #expect(second.map { FocusCard.from($0).kind } == "家人")
        #expect(second.map { FocusCard.from($0).kind } != second?.roleText)
    }

    @Test func homeVisibleCardsLimitToSixAndPromoteNewMember() throws {
        resetGlobalState()
        UserDefaults.standard.set("zh", forKey: "appLanguage")
        let humans = (0 ..< 7).map { index in
            let human = Human(name: "Member \(index)")
            human.createdAt = Date(timeIntervalSince1970: Double(index))
            return human
        }
        let promoted = humans[0]
        let orderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: promoted.id, currentRaw: "")
        let cards = FocusHomeCardDataSource.buildSnapshot(
            pets: [],
            humans: humans,
            electronicPets: [],
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: orderRaw,
            showDummyCards: false
        )
        let visible = FocusHomeCardDataSource.visibleCards(
            from: cards,
            rosterPreviewCard: nil,
            isExpanded: false,
            activeCardId: nil,
            avatarData: [:],
            popoutData: [:]
        )

        #expect(FocusHomeCardDataSource.maxCardsPerPage == 6)
        #expect(visible.count == 6)
        #expect(visible.first?.id == promoted.id)
    }

    @Test func newHumanDefaultsHiddenFromHomeWhenHomeStackIsFull() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let humans = makeVisibleHumans(count: HomeCardVisibility.maxVisibleCards)
        humans.forEach { context.insert($0) }
        try context.save()

        let result = try MemberCreationService.save(
            draft: humanDraft(name: "Extra Human", source: .placeholder),
            existingPets: [],
            existingHumans: humans,
            context: context,
            countryCode: "CN"
        )

        #expect(result.human?.shouldShowOnHome == false)
    }

    @Test func newPetDefaultsHiddenFromHomeWhenHomeStackIsFull() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let humans = makeVisibleHumans(count: HomeCardVisibility.maxVisibleCards)
        humans.forEach { context.insert($0) }
        try context.save()

        let result = try MemberCreationService.save(
            draft: petDraft(name: "Extra Pet", source: .placeholder),
            existingPets: [],
            existingHumans: humans,
            context: context,
            countryCode: "CN"
        )
        let pet = try #require(result.pet)
        let hiddenRaw = UserDefaults.standard.string(forKey: HomeCardVisibility.hiddenPetIDsKey) ?? ""

        #expect(HomeCardVisibility.isPetVisible(pet, raw: hiddenRaw) == false)
        #expect(HomeCardVisibility.visibleCardCount(pets: [pet], humans: humans, raw: hiddenRaw) == HomeCardVisibility.maxVisibleCards)
    }

    private var avatarData: Data { Data([0x89, 0x50, 0x4E, 0x47]) }

    private func petDraft(name: String, source: MemberAvatarSource) -> MemberCreationDraft {
        var draft = MemberCreationDraft(kind: .pet)
        draft.name = name
        draft.species = "狗"
        draft.breed = "柴犬"
        draft.avatarSource = source
        draft.avatarImageData = avatarData
        draft.hasBirthday = false
        draft.hasHomeDate = false
        return draft
    }

    private func humanDraft(name: String, source: MemberAvatarSource) -> MemberCreationDraft {
        var draft = MemberCreationDraft(kind: .human)
        draft.name = name
        draft.avatarSource = source
        draft.avatarImageData = avatarData
        draft.hasBirthday = false
        return draft
    }

    private func makeVisibleHumans(count: Int) -> [Human] {
        (0 ..< count).map { index in
            let human = Human(name: "Visible Human \(index)")
            human.createdAt = Date(timeIntervalSince1970: Double(index))
            human.shouldShowOnHome = true
            return human
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV56.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func resetGlobalState() {
        [
            "inventory_avatar2d_extra_count",
            "avatar2d_free_human_used",
            "avatar2d_free_pet_used",
            "currentActiveHumanId",
            "quest_coconutCount",
            "quest_isPetWizardCompleted",
            "quest_isFirstMealRecorded",
            "quest_isThemeColorSet",
            "quest_coconutLogs",
            HomeCardVisibility.hiddenPetIDsKey,
        ].forEach { UserDefaults.standard.removeObject(forKey: $0) }

        QuestManager.shared.coconutCount = 0
        QuestManager.shared.coconutLogs = []
        QuestManager.shared.isPetWizardCompleted = true
        QuestManager.shared.isFirstMealRecorded = false
        QuestManager.shared.isThemeColorSet = false
        QuestManager.shared.flushToDefaults()
    }
}
