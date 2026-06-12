//
//  MemberCreationService.swift
//  Ohana
//
//  Persistence commands for creating pet and human member cards.
//

import Foundation
import SwiftData

struct MemberCreationSaveResult {
    let pet: Pet?
    let human: Human?
}

enum MemberCreationError: LocalizedError {
    case emptyName
    case duplicateName
    case avatarPassRequired
    case insufficientCoconuts(missing: Int)
    case missingActiveHuman
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Name is required."
        case .duplicateName:
            "Name already exists."
        case .avatarPassRequired:
            "A 2.5D avatar pass is required."
        case let .insufficientCoconuts(missing):
            "Need \(missing) more coconuts."
        case .missingActiveHuman:
            "No active human member."
        case let .saveFailed(message):
            message
        }
    }
}

@MainActor
final class MemberCreationService: MemberCreating {
    typealias SaveResult = MemberCreationSaveResult
    typealias ServiceError = MemberCreationError

    private let activeHumanSelection: ActiveHumanSelecting
    private let wallet: CoconutWalletManaging
    private let careLedger: CareLedgerRecording
    private let revisions: DomainRevisionPublishing
    private let questManager: QuestManager

    init(
        activeHumanSelection: ActiveHumanSelecting,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager
    ) {
        self.activeHumanSelection = activeHumanSelection
        self.wallet = wallet
        self.careLedger = careLedger
        self.revisions = revisions
        self.questManager = questManager
    }

    var avatarPassCost: Int {
        ShopCatalog.item(id: Avatar2DAccess.shopItemId)?.cost ?? 1500
    }

    func currentHuman(in humans: [Human]) -> Human? {
        if let activeId = activeHumanSelection.currentHumanId,
           let match = humans.first(where: { $0.id.uuidString == activeId }) {
            return match
        }
        return humans.first
    }

    func purchaseAvatarPassForCurrentDraft(
        humans: [Human],
        context: ModelContext,
        l: L10n
    ) throws {
        let cost = avatarPassCost
        guard let human = currentHuman(in: humans) else {
            throw ServiceError.missingActiveHuman
        }
        let humanBalance = CoconutWalletService.balance(for: human, context: context)
        guard humanBalance >= cost else {
            throw ServiceError.insufficientCoconuts(missing: max(0, cost - humanBalance))
        }
        let purchaseId = UUID().uuidString
        let metadataJSON = "{\"shopItemId\":\"\(Avatar2DAccess.shopItemId)\",\"surface\":\"memberCreation\",\"purchaseId\":\"\(purchaseId)\"}"
        let title = l.tr(zh: "兑换「2.5D 头像券」", en: "Redeemed 2.5D Avatar Pass", de: "2,5D-Avatarpass eingelöst")
        let ledger = careLedger.record(
            occurredAt: Date(),
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "memberCreationAvatarPassPurchase",
            amountValue: 0,
            amountUnit: "",
            note: l.tr(zh: "2.5D 头像券", en: "2.5D Avatar Pass", de: "2,5D-Avatarpass"),
            source: .economy,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: -cost,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: false
        )
        do {
            try wallet.apply(
                deltas: [
                    .human(
                        human,
                        delta: -cost,
                        entryKind: .spend,
                        source: .shop,
                        title: title,
                        emoji: "2.5D",
                        actorId: human.id.uuidString,
                        actorName: human.name,
                        subjectKind: .system,
                        subjectId: nil,
                        sourceModelName: "Avatar2DAccess",
                        sourceModelId: Avatar2DAccess.shopItemId,
                        careLedgerEventId: ledger.id.uuidString,
                        metadataJSON: metadataJSON,
                        transactionKey: "shop:memberCreation:\(Avatar2DAccess.shopItemId):\(human.id.uuidString):\(purchaseId)"
                    )
                ],
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: questManager
            )
            try context.save()
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            throw error
        }
        Avatar2DAccess.addExtraPasses(1)
    }

    func save(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext,
        countryCode: String
    ) throws -> SaveResult {
        let trimmed = draft.trimmedName
        guard !trimmed.isEmpty else { throw ServiceError.emptyName }
        let candidate = trimmed.lowercased()
        let names = existingPets.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            + existingHumans.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard !names.contains(candidate) else { throw ServiceError.duplicateName }

        switch draft.kind {
        case .pet:
            return try savePet(
                draft: draft,
                existingPets: existingPets,
                existingHumans: existingHumans,
                context: context
            )
        case .human:
            return try saveHuman(
                draft: draft,
                existingPets: existingPets,
                existingHumans: existingHumans,
                context: context,
                countryCode: countryCode
            )
        }
    }

    private func savePet(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext
    ) throws -> SaveResult {
        let existingCount = existingPets.count
        let shouldUse2D = draft.avatarSource == .avatar2D && draft.avatarImageData != nil
        if shouldUse2D, !Avatar2DAccess.hasAccess(kind: .pet, existingCount: existingCount) {
            throw ServiceError.avatarPassRequired
        }
        let pet = Pet(
            name: draft.trimmedName,
            species: draft.species,
            breed: draft.resolvedBreed,
            birthday: draft.hasBirthday ? draft.birthday : nil,
            gender: draft.petGender,
            isNeutered: draft.isNeutered,
            avatarEmoji: speciesEmoji(draft.species),
            themeColorHex: draft.normalizedThemeHex,
            homeDate: draft.hasHomeDate ? draft.homeDate : nil
        )
        pet.avatarImageData = draft.avatarImageData
        pet.coatColor = draft.coatColor
        pet.eyeColor = draft.eyeColor
        pet.personalityTagsRaw = draft.personalityTagIds.joined(separator: ",")
        let previousHiddenHomePetIDsRaw = HomeCardVisibility.storedHiddenPetIDsRawIfPresent()
        let currentHiddenHomePetIDsRaw = previousHiddenHomePetIDsRaw ?? ""
        let shouldShowOnHome = shouldShowNewMemberOnHome(
            existingPets: existingPets,
            existingHumans: existingHumans,
            hiddenPetIDsRaw: currentHiddenHomePetIDsRaw
        )
        if !shouldShowOnHome {
            HomeCardVisibility.setPetVisible(
                pet,
                visible: false,
                raw: currentHiddenHomePetIDsRaw
            )
        }
        context.insert(pet)
        CloudSyncMutationRecorder.markModified(pet, context: context)
        do {
            try context.save()
        } catch {
            if !shouldShowOnHome {
                HomeCardVisibility.restoreHiddenPetIDsRaw(previousHiddenHomePetIDsRaw)
            }
            context.delete(pet)
            throw ServiceError.saveFailed(error.localizedDescription)
        }

        if shouldUse2D {
            Avatar2DAccess.consumeIfNeeded(kind: .pet, existingCount: existingCount)
        }
        recordThemeColorIfNeeded(
            draft: draft,
            questManager: questManager,
            actorId: pet.id.uuidString,
            actorName: pet.name,
            context: context
        )
        insertPetRelatedRecords(pet: pet, draft: draft, context: context)
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: context)
        context.safeSave()

        let isFirstPet = !questManager.isPetWizardCompleted
        if isFirstPet {
            questManager.isPetWizardCompleted = true
            questManager.persistQuestFlags()
            if let welcomeHuman = activeHumanForWelcomeReward(existingHumans: existingHumans, context: context) {
                do {
                    try wallet.applyActorDelta(
                        amount: 50,
                        emoji: "🎉",
                        title: "新家人入住欢迎奖励",
                        actorId: welcomeHuman.id.uuidString,
                        actorName: welcomeHuman.name,
                        entryKind: .reward,
                        source: .onboarding,
                        context: context,
                        save: false,
                        postsRewardFeedback: true,
                        projectionManager: questManager
                    )
                    careLedger.recordCoconut(
                        delta: 50,
                        title: "新家人入住欢迎奖励",
                        actorId: welcomeHuman.id.uuidString,
                        actorName: welcomeHuman.name,
                        source: .economy,
                        context: context
                    )
                } catch {
                    AppPerformanceMonitor.shared.record(
                        "memberCreation.welcomeReward.walletFailed",
                        valueMS: 0,
                        note: error.localizedDescription
                    )
                }
            } else {
                AppPerformanceMonitor.shared.record(
                    "memberCreation.welcomeReward.noActiveHuman",
                    valueMS: 0,
                    note: "Skipped first-pet welcome wallet reward because no active human wallet is available."
                )
            }
        }
        revisions.publishMemberProfileChange(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            note: "memberCreation.pet.profile"
        )
        publishMemberCreation(id: pet.id, kind: "pet", revisions: revisions)
        return SaveResult(pet: pet, human: nil)
    }

    private func saveHuman(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext,
        countryCode: String
    ) throws -> SaveResult {
        let existingCount = existingHumans.count
        let shouldUse2D = draft.avatarSource == .avatar2D && draft.avatarImageData != nil
        if shouldUse2D, !Avatar2DAccess.hasAccess(kind: .human, existingCount: existingCount) {
            throw ServiceError.avatarPassRequired
        }
        let human = Human(
            name: draft.trimmedName,
            birthday: draft.hasBirthday ? draft.birthday : nil,
            bloodType: draft.bloodType,
            avatarEmoji: HumanGenderIdentity.fallbackAvatarEmoji(for: draft.humanGender),
            role: existingCount == 0 || draft.usesExplicitHumanRole
                ? HumanProfileOptions.normalizedRole(draft.role)
                : "member",
            nationality: draft.nationality,
            city: residenceText(country: draft.residenceCountry, city: draft.residenceCity)
        )
        human.avatarImageData = draft.avatarImageData
        human.themeColorHex = draft.normalizedThemeHex
        human.genderIdentityRaw = HumanProfileOptions.storedGenderIdentity(draft.humanGender)
        human.shouldShowOnHome = shouldShowNewMemberOnHome(
            existingPets: existingPets,
            existingHumans: existingHumans,
            hiddenPetIDsRaw: HomeCardVisibility.storedHiddenPetIDsRaw()
        )
        human.mbti = draft.mbti.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        human.notes = humanNotes(draft: draft)
        if let height = CountryDecimalInput.parse(draft.heightText, countryCode: countryCode), height > 0 {
            human.heightCm = height
        }
        human.setPrivate(.weight, draft.privateWeight)
        human.setPrivate(.workout, draft.privateWorkout)
        human.setPrivate(.medication, draft.privateMedication)
        human.setPrivate(.wishlist, draft.privateWishlist)
        human.setPrivate(.expense, draft.privateExpense)
        context.insert(human)
        CloudSyncMutationRecorder.markModified(human, context: context)
        if let weight = CountryDecimalInput.parse(draft.weightText, countryCode: countryCode), weight > 0 {
            let executorId = activeHumanSelection.currentHumanId
            context.insert(HumanWeightLog(date: Date(), weight: weight, human: human, executorId: executorId))
            IslandQuestEngine.markInitialHumanWeightRecorded(humanId: human.id)
        }
        if draft.hasBirthday {
            let event = Event(
                title: "\(draft.trimmedName)\(L10n.current.humanWizBirthdayEventSuffix)",
                startDate: draft.birthday,
                isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: "Human",
                relatedEntityId: human.id.uuidString
            )
            event.recurrenceDays = 365
            context.insert(event)
            CloudSyncMutationRecorder.markModified(event, context: context)
        }
        do {
            try context.save()
        } catch {
            context.delete(human)
            throw ServiceError.saveFailed(error.localizedDescription)
        }

        if shouldUse2D {
            Avatar2DAccess.consumeIfNeeded(kind: .human, existingCount: existingCount)
        }
        recordThemeColorIfNeeded(
            draft: draft,
            questManager: questManager,
            actorId: human.id.uuidString,
            actorName: human.name,
            context: context
        )
        revisions.publishMemberProfileChange(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            note: "memberCreation.human.profile"
        )
        publishMemberCreation(id: human.id, kind: "human", revisions: revisions)
        return SaveResult(pet: nil, human: human)
    }

    private func shouldShowNewMemberOnHome(
        existingPets: [Pet],
        existingHumans: [Human],
        hiddenPetIDsRaw: String
    ) -> Bool {
        HomeCardVisibility.visibleCardCount(
            pets: existingPets,
            humans: existingHumans,
            raw: hiddenPetIDsRaw
        ) < HomeCardVisibility.maxVisibleCards
    }

    private func insertPetRelatedRecords(pet: Pet, draft: MemberCreationDraft, context: ModelContext) {
        if draft.hasBirthday {
            let birthdayEvent = Event(
                title: "\(draft.trimmedName) 的生日 🎂",
                startDate: draft.birthday,
                isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: "Pet",
                relatedEntityId: pet.id.uuidString
            )
            birthdayEvent.recurrenceDays = 365
            context.insert(birthdayEvent)
            CloudSyncMutationRecorder.markModified(birthdayEvent, context: context)
            let reminder = Reminder(event: birthdayEvent, scheduledAt: draft.birthday)
            context.insert(reminder)
            CloudSyncMutationRecorder.markModified(reminder, context: context)
        }
        if draft.hasHomeDate {
            let event = Event(
                title: "\(draft.trimmedName) 的到家纪念日 🏠",
                startDate: draft.homeDate,
                isAllDay: true,
                eventType: EventType.anniversary.rawValue,
                relatedEntityType: "Pet",
                relatedEntityId: pet.id.uuidString
            )
            event.recurrenceDays = 365
            context.insert(event)
            CloudSyncMutationRecorder.markModified(event, context: context)
        }
        if draft.hasHomeDate {
            let milestones = [100, 365, 500, 730, 1000, 1095]
            for days in milestones {
                if let date = Calendar.current.date(byAdding: .day, value: days, to: draft.homeDate) {
                    context.insert(PetMilestone(
                        date: date,
                        title: L10n.current.petWizMilestoneTogether(days),
                        emoji: days >= 1000 ? "🏆" : "🎉",
                        pet: pet
                    ))
                }
            }
        }
    }

    private func recordThemeColorIfNeeded(
        draft: MemberCreationDraft,
        questManager: QuestManager,
        actorId: String?,
        actorName: String?,
        context: ModelContext
    ) {
        guard draft.normalizedThemeHex != draft.kind.fallbackThemeHex else { return }
        questManager.recordThemeColorSet(actorId: actorId, actorName: actorName, context: context)
    }

    private func activeHumanForWelcomeReward(existingHumans: [Human], context: ModelContext) -> Human? {
        guard let activeId = activeHumanSelection.currentHumanId,
              let uuid = UUID(uuidString: activeId) else {
            return nil
        }
        if let existing = existingHumans.first(where: { $0.id == uuid }) {
            return EconomyWalletWritePolicy.canWrite(existing) ? existing : nil
        }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == uuid
            }
        )
        descriptor.fetchLimit = 1
        do {
            guard let human = try context.fetch(descriptor).first,
                  EconomyWalletWritePolicy.canWrite(human) else {
                return nil
            }
            return human
        } catch {
            OhanaLog.warning(
                "[MemberCreationService] failed to fetch active human for welcome reward: \(error.localizedDescription)",
                category: "Economy"
            )
            return nil
        }
    }

    private func publishMemberCreation(id: UUID, kind: String, revisions: DomainRevisionPublishing) {
        revisions.publish(
            DomainMutationResult(
                command: .memberCreation(entityID: id, kind: kind),
                affectedEntityIDs: [id],
                note: kind
            )
        )
    }

    private func speciesEmoji(_ species: String) -> String {
        switch species {
        case "狗": "🐕"
        case "猫": "🐈"
        case "兔子": "🐇"
        case "鱼": "🐟"
        case "鸟": "🦜"
        case "爬宠": "🦎"
        case "仓鼠": "🐹"
        default: "🐾"
        }
    }

    private func residenceText(country: String, city: String) -> String {
        if country.isEmpty { return city }
        if city.isEmpty { return country }
        return "\(country)·\(city)"
    }

    private func humanNotes(draft: MemberCreationDraft) -> String {
        draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
