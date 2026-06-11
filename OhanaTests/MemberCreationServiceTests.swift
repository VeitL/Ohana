import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct MemberCreationServiceTests {
    @Test func firstPetSaves2DAvatarWithoutConsumingInventoryPass() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext

        let result = try saveMember(
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

        let result = try saveMember(
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
            _ = try saveMember(
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
        payer.coconutBalance = avatarPassCost + 200
        context.insert(payer)
        try context.save()
        UserDefaults.standard.set(payer.id.uuidString, forKey: "currentActiveHumanId")

        try purchaseAvatarPass(
            humans: [payer],
            context: context,
            l: L10n("en")
        )

        #expect(payer.coconutBalance == 200)
        #expect(Avatar2DAccess.extraPassCount == 1)
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgers.count == 1)
        #expect(ledgers.first?.actionType == "memberCreationAvatarPassPurchase")
        #expect(ledgers.first?.coconutDelta == -avatarPassCost)

        _ = try saveMember(
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
        payer.coconutBalance = avatarPassCost
        context.insert(payer)
        try context.save()

        try purchaseAvatarPass(
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
        payer.coconutBalance = avatarPassCost - 1
        context.insert(payer)
        try context.save()

        do {
            try purchaseAvatarPass(
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

        #expect(payer.coconutBalance == avatarPassCost - 1)
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

        _ = try saveMember(
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

        let result = try saveMember(
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

        let first = try saveMember(
            draft: humanDraft(name: "Ava", source: .placeholder),
            existingPets: [],
            existingHumans: [],
            context: context,
            countryCode: "CN"
        ).human

        #expect(first?.role == "owner")

        let second = try saveMember(
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

    @Test func explicitHumanRoleDraftCanRespectWizardSelection() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let existing = Human(name: "Existing")
        existing.role = "owner"
        context.insert(existing)
        try context.save()

        var draft = humanDraft(name: "Nico", source: .placeholder)
        draft.role = "owner"
        draft.usesExplicitHumanRole = true

        let result = try saveMember(
            draft: draft,
            existingPets: [],
            existingHumans: [existing],
            context: context,
            countryCode: "CN"
        ).human

        #expect(result?.role == "owner")
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

        let result = try saveMember(
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

        let result = try saveMember(
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

    @Test func petCreationWritesBirthdayHomeMilestonesAndRevision() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let birthday = makeDate(year: 2025, month: 6, day: 8)
        let homeDate = makeDate(year: 2026, month: 1, day: 10)
        let revisionCenter = ReadModelRevisionCenter()
        let beforeRevision = revisionCenter.homeRevision.value
        var draft = petDraft(name: "Momo", source: .placeholder)
        draft.avatarImageData = nil
        draft.hasBirthday = true
        draft.birthday = birthday
        draft.hasHomeDate = true
        draft.homeDate = homeDate
        draft.themeColorHex = "00AAFF"

        let result = try saveMember(
            draft: draft,
            existingPets: [],
            existingHumans: [],
            context: context,
            countryCode: "CN",
            revisions: SharedDomainRevisionPublisher(center: revisionCenter)
        )
        let pet = try #require(result.pet)
        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let milestones = try context.fetch(FetchDescriptor<PetMilestone>())
        let mutation = try #require(revisionCenter.lastMutation)
        let birthdayEvent = try #require(events.first { $0.eventType == EventType.birthday.rawValue })
        let anniversaryEvent = try #require(events.first { $0.eventType == EventType.anniversary.rawValue })

        #expect(events.count >= 2)
        #expect(birthdayEvent.relatedEntityId == pet.id.uuidString)
        #expect(birthdayEvent.recurrenceDays == 365)
        #expect(reminders.count == 1)
        #expect(reminders.first?.event?.id == birthdayEvent.id)
        #expect(reminders.first?.scheduledAt == birthday)
        #expect(anniversaryEvent.relatedEntityId == pet.id.uuidString)
        #expect(anniversaryEvent.recurrenceDays == 365)
        #expect(milestones.count == 6)
        #expect(milestones.allSatisfy { $0.pet?.id == pet.id })
        #expect(TestQuestManagerProjection.manager.isThemeColorSet == true)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 2)
        #expect(mutation.command == .memberCreation(entityID: pet.id, kind: "pet"))
        #expect(mutation.affectedEntityIDs == [pet.id])
    }

    private var avatarData: Data { Data([0x89, 0x50, 0x4E, 0x47]) }
    private var avatarPassCost: Int { makeMemberCreationService().avatarPassCost }

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

    private func saveMember(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext,
        countryCode: String,
        revisions: DomainRevisionPublishing? = nil
    ) throws -> MemberCreationService.SaveResult {
        try makeMemberCreationService(revisions: revisions).save(
            draft: draft,
            existingPets: existingPets,
            existingHumans: existingHumans,
            context: context,
            countryCode: countryCode
        )
    }

    private func purchaseAvatarPass(
        humans: [Human],
        context: ModelContext,
        l: L10n
    ) throws {
        try makeMemberCreationService().purchaseAvatarPassForCurrentDraft(
            humans: humans,
            context: context,
            l: l
        )
    }

    private func makeMemberCreationService(
        revisions: DomainRevisionPublishing? = nil
    ) -> MemberCreationService {
        MemberCreationService(
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: revisions ?? SharedDomainRevisionPublisher(),
            questManager: TestQuestManagerProjection.manager
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV63.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
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
            HomeCardVisibility.hiddenPetIDsKey
        ].forEach { UserDefaults.standard.removeObject(forKey: $0) }

        TestQuestManagerProjection.manager.coconutCount = 0
        TestQuestManagerProjection.manager.coconutLogs = []
        TestQuestManagerProjection.manager.isPetWizardCompleted = true
        TestQuestManagerProjection.manager.isFirstMealRecorded = false
        TestQuestManagerProjection.manager.isThemeColorSet = false
        TestQuestManagerProjection.manager.persistQuestFlags()
    }
}
