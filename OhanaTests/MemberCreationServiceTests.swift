import Foundation
import SwiftData
import Testing
import UIKit
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
        #expect(result.pet?.hasAvatarImageAttachment == true)
        #expect(result.pet?.avatarImageSignature == MediaPayloadSignature.signature(for: avatarData))
        #expect(result.pet?.hasTransparentAvatarImage == false)
        #expect(Avatar2DAccess.extraPassCount == 0)
        #expect(try context.fetch(FetchDescriptor<Pet>()).count == 1)
    }

    @Test func petCreationSanitizesLargeAvatarBeforePersistence() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let originalAvatar = largeOpaqueAvatarData(width: 1800, height: 1400)
        var draft = petDraft(name: "Momo", source: .customImage)
        draft.avatarImageData = originalAvatar

        let result = try saveMember(
            draft: draft,
            existingPets: [],
            existingHumans: [],
            context: context,
            countryCode: "CN"
        )

        let persistedAvatar = try #require(result.pet?.avatarImageData)
        let persistedImage = try #require(UIImage(data: persistedAvatar))
        let longestPixel = max(
            persistedImage.size.width * persistedImage.scale,
            persistedImage.size.height * persistedImage.scale
        )
        #expect(persistedAvatar != originalAvatar)
        #expect(longestPixel <= 1200)
        #expect(result.pet?.avatarImageSignature == MediaPayloadSignature.signature(for: persistedAvatar))
    }

    @Test func memberMediaAttachmentRepairIndexesLegacyAvatarBlobs() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let avatarData = transparentPNGData()
        let popoutData = Data([5, 6, 7, 8])
        let petPhotoData = Data([9, 10, 11, 12, 13, 14, 15, 16, 17])
        let documentData = Data([21, 22, 23, 24])
        let attachmentData = Data([31, 32, 33, 34])
        let pet = Pet(name: "Momo", species: "猫")
        pet.avatarImageData = avatarData
        pet.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        pet.avatarImageSignature = ""
        pet.avatarTransparencyStateRaw = MemberAvatarTransparencyState.unknown.rawValue
        pet.cardPopoutImageData = popoutData
        pet.cardPopoutAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        pet.cardPopoutImageSignature = ""
        let photoLog = PetPhotoLog(imageData: petPhotoData, pet: pet)
        photoLog.imageAttachmentStateRaw = PetPhotoAttachmentState.unknown.rawValue
        photoLog.imageSignature = ""
        let document = PetDocument(title: "Passport", category: .passport, pet: pet)
        document.attachmentData = documentData
        document.attachmentFilename = "passport.jpg"
        document.legacyAttachmentStateRaw = PetDocumentAttachmentState.unknown.rawValue
        document.legacyAttachmentSignature = ""
        let documentAttachment = PetDocumentAttachment(data: attachmentData, filename: "scan.jpg", isImage: true)
        documentAttachment.dataAttachmentStateRaw = PetDocumentAttachmentState.unknown.rawValue
        documentAttachment.dataSignature = ""
        document.attachments.append(documentAttachment)
        let human = Human(name: "Nico")
        human.avatarImageData = avatarData
        human.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        human.avatarImageSignature = ""
        context.insert(pet)
        context.insert(photoLog)
        context.insert(document)
        context.insert(documentAttachment)
        context.insert(human)
        try context.save()

        let repaired = MemberMediaAttachmentIndexRepair.repair(modelContext: context, maxBlobReads: 6)

        #expect(repaired == true)
        #expect(pet.hasAvatarImageAttachment == true)
        #expect(pet.avatarImageSignature == MediaPayloadSignature.signature(for: avatarData))
        #expect(pet.hasTransparentAvatarImage == true)
        #expect(pet.shouldShowAvatarBackground == false)
        #expect(pet.hasCardPopoutImageAttachment == true)
        #expect(pet.cardPopoutImageSignature == MediaPayloadSignature.signature(for: popoutData))
        #expect(photoLog.hasImageAttachment == true)
        #expect(photoLog.imageSignature == MediaPayloadSignature.signature(for: petPhotoData))
        #expect(document.hasLegacyAttachment == true)
        #expect(document.legacyAttachmentSignature == MediaPayloadSignature.signature(for: documentData))
        #expect(documentAttachment.hasDataAttachment == true)
        #expect(documentAttachment.dataSignature == MediaPayloadSignature.signature(for: attachmentData))
        #expect(human.hasAvatarImageAttachment == true)
        #expect(human.avatarImageSignature == MediaPayloadSignature.signature(for: avatarData))
    }

    @Test func firstPetDoesNotAwardStarterGiftBeforeFirstCare() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        context.insert(human)
        try context.save()
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        TestQuestManagerProjection.manager.isPetWizardCompleted = false

        _ = try saveMember(
            draft: petDraft(name: "Momo", source: .placeholder),
            existingPets: [],
            existingHumans: [human],
            context: context,
            countryCode: "CN"
        )

        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(human.coconutBalance == 0)
        #expect(accounts.isEmpty)
        #expect(!accounts.contains { $0.ownerKind == .system })
        #expect(walletEntries.allSatisfy { $0.ownerKind != .system })
        #expect(ledgerEvents.isEmpty)
    }

    @Test func firstPetInitialWeightRecordsCareFactWithoutWalletReward() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        context.insert(human)
        try context.save()
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")
        TestQuestManagerProjection.manager.isPetWizardCompleted = false

        var draft = petDraft(name: "Momo", source: .placeholder)
        draft.weightText = "4.2"
        _ = try saveMember(
            draft: draft,
            existingPets: [],
            existingHumans: [human],
            context: context,
            countryCode: "CN"
        )

        let weightLogs = try context.fetch(FetchDescriptor<PetWeightLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(weightLogs.count == 1)
        #expect(weightLogs.first?.weight == 4.2)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.actionType == "petWeight")
        #expect(ledgerEvents.first?.coconutDelta == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutAccount>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func firstPetWelcomeRewardSkipsWalletWhenNoActiveHumanExists() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")
        TestQuestManagerProjection.manager.isPetWizardCompleted = false

        _ = try saveMember(
            draft: petDraft(name: "Momo", source: .placeholder),
            existingPets: [],
            existingHumans: [],
            context: context,
            countryCode: "CN"
        )

        #expect(try context.fetch(FetchDescriptor<CoconutAccount>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
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
        #expect(result.human?.hasAvatarImageAttachment == true)
        #expect(result.human?.avatarImageSignature == MediaPayloadSignature.signature(for: avatarData))
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
                // Expected: 2D avatar creation requires an avatar pass.
            } else {
                Issue.record("Expected avatar pass requirement")
            }
        }
        #expect(Avatar2DAccess.extraPassCount == 0)
    }

    @Test func duplicateHumanNameIsRejectedWhenViewSnapshotIsStale() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        let existing = Human(name: "Ava")
        context.insert(existing)
        try context.save()

        do {
            _ = try saveMember(
                draft: humanDraft(name: " ava ", source: .placeholder),
                existingPets: [],
                existingHumans: [],
                context: context,
                countryCode: "CN"
            )
            Issue.record("Expected duplicate name rejection from context-backed member snapshot")
        } catch let error as MemberCreationService.ServiceError {
            if case .duplicateName = error {
                // Expected: the service must not trust a stale view snapshot.
            } else {
                Issue.record("Expected duplicate name rejection")
            }
        }

        #expect(try context.fetch(FetchDescriptor<Human>()).count == 1)
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
        #expect(ledgers.first?.actionType == "shopPurchase")
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

    @Test func focusHomeCardUsesExplicitWalkDistanceInsteadOfPetWalkRelationship() throws {
        resetGlobalState()
        let pet = Pet(name: "Momo", species: "Dog")
        pet.walkLogs.append(PetWalkLog(pet: pet))
        pet.walkLogs[0].distanceMeters = 1500

        let implicitCard = FocusCard.from(pet, includeAvatarData: false)
        let explicitCard = FocusCard.from(pet, includeAvatarData: false, homeWalkDistanceMeters: 1500)

        #expect(implicitCard.homeWalkDistanceMeters == 0)
        #expect(explicitCard.homeWalkDistanceMeters == 1500)
    }

    @Test func homeCardSelectionReconciliationClearsDeletedSelectedCard() throws {
        resetGlobalState()
        let remaining = FocusCard.from(Human(name: "Remaining"))
        let deletedID = UUID()

        let staleSelection = FocusHomeCardDataSource.selectionReconciliation(
            cards: [remaining],
            selectedCardId: deletedID,
            headerContextCardId: deletedID
        )
        let validSelection = FocusHomeCardDataSource.selectionReconciliation(
            cards: [remaining],
            selectedCardId: remaining.id,
            headerContextCardId: remaining.id
        )

        #expect(staleSelection.clearsSelectedCard)
        #expect(staleSelection.clearsHeaderContext)
        #expect(!validSelection.clearsSelectedCard)
        #expect(!validSelection.clearsHeaderContext)
    }

    @Test func crewRosterInlineAddCompletionTargetsHomeInsteadOfSelection() throws {
        resetGlobalState()
        let pet = Pet(name: "Inline Pet", species: "Dog")
        let human = Human(name: "Inline Human")

        #expect(CrewRosterInlineAddCompletion.target(savedPet: pet, savedHuman: nil) == .pet(pet.id))
        #expect(CrewRosterInlineAddCompletion.target(savedPet: nil, savedHuman: human) == .human(human.id))
        #expect(CrewRosterInlineAddCompletion.target(savedPet: nil, savedHuman: nil) == nil)
    }

    @Test func deceasedHumanDoesNotAppearOnHomeCards() throws {
        resetGlobalState()
        let livingHuman = Human(name: "Living")
        let memorialHuman = Human(name: "Memorial")
        memorialHuman.passedAwayDate = Date()

        let cards = FocusHomeCardDataSource.buildSnapshot(
            pets: [],
            humans: [livingHuman, memorialHuman],
            electronicPets: [],
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false
        )

        #expect(cards.contains { $0.id == livingHuman.id })
        #expect(!cards.contains { $0.id == memorialHuman.id })
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
        #expect(try cloudSyncState(for: birthdayEvent, context: context)?.hasPendingLocalChanges == true)
        #expect(try cloudSyncState(for: anniversaryEvent, context: context)?.hasPendingLocalChanges == true)
        #expect(try reminders.first.flatMap { try cloudSyncState(for: $0, context: context) }?.hasPendingLocalChanges == true)
        #expect(TestQuestManagerProjection.manager.isThemeColorSet == true)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 2)
        #expect(mutation.command == .memberCreation(entityID: pet.id, kind: "pet"))
        #expect(mutation.affectedEntityIDs == [pet.id])
    }

    @Test func humanCreationWritesBirthdayEventCloudSyncState() throws {
        resetGlobalState()
        let container = try makeContainer()
        let context = container.mainContext
        var draft = humanDraft(name: "Ava", source: .placeholder)
        draft.avatarImageData = nil
        draft.hasBirthday = true
        draft.birthday = makeDate(year: 1992, month: 4, day: 12)

        let result = try saveMember(
            draft: draft,
            existingPets: [],
            existingHumans: [],
            context: context,
            countryCode: "CN"
        )

        let human = try #require(result.human)
        let event = try #require(try context.fetch(FetchDescriptor<Event>()).first)
        #expect(event.relatedEntityType == EntityKind.human.rawValue)
        #expect(event.relatedEntityId == human.id.uuidString)
        #expect(event.recurrenceDays == 365)
        #expect(try cloudSyncState(for: event, context: context)?.hasPendingLocalChanges == true)
    }

    private var avatarData: Data { Data([0x89, 0x50, 0x4E, 0x47]) }
    private var avatarPassCost: Int { makeMemberCreationService().avatarPassCost }

    private func transparentPNGData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: format).pngData { _ in }
    }

    private func largeOpaqueAvatarData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: width * 0.12, y: height * 0.18, width: width * 0.54, height: height * 0.42))
        }
        return image.jpegData(compressionQuality: 1) ?? Data()
    }

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
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func cloudSyncState(for event: Event, context: ModelContext) throws -> CloudSyncRecordState? {
        try context.fetch(FetchDescriptor<CloudSyncRecordState>()).first {
            $0.entityName == String(describing: Event.self)
                && $0.localRecordId == event.id.uuidString.lowercased()
        }
    }

    private func cloudSyncState(for reminder: Reminder, context: ModelContext) throws -> CloudSyncRecordState? {
        try context.fetch(FetchDescriptor<CloudSyncRecordState>()).first {
            $0.entityName == String(describing: Reminder.self)
                && $0.localRecordId == reminder.id.uuidString.lowercased()
        }
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
            StarterGiftStorageKey.claimed,
            StarterGiftStorageKey.pending,
            StarterGiftStorageKey.ceremonySeen,
            StarterGiftStorageKey.oasisTabPromptPending,
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
