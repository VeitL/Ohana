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

private struct MemberCreationExistingMembers {
    let pets: [Pet]
    let humans: [Human]

    var normalizedNames: Set<String> {
        Set((pets.map(\.name) + humans.map(\.name)).map(Self.normalizedName))
    }

    private nonisolated static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum MemberCreationError: LocalizedError {
    case emptyName
    case duplicateName
    case avatarPassRequired
    case insufficientCoconuts(missing: Int)
    case missingActiveHuman
    case walletFrozen
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
        case .walletFrozen:
            "This wallet is frozen."
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
        return humans.first(where: EconomyWalletWritePolicy.canWrite)
    }

    func purchaseAvatarPassForCurrentDraft(
        humans: [Human],
        context: ModelContext,
        l: L10n
    ) throws {
        guard let human = currentHuman(in: humans) else {
            throw ServiceError.missingActiveHuman
        }
        guard let item = ShopCatalog.item(id: Avatar2DAccess.shopItemId) else {
            throw ServiceError.saveFailed("2.5D Avatar Pass is missing from the shop catalog.")
        }
        let title = l.tr(zh: "兑换「2.5D 头像券」", en: "Redeemed 2.5D Avatar Pass", de: "2,5D-Avatarpass eingelöst")
        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: title,
            context: context,
            questManager: questManager,
            wallet: wallet,
            careLedger: careLedger
        )
        guard result.didPurchase else {
            switch result.failure {
            case .missingActiveHuman:
                throw ServiceError.missingActiveHuman
            case let .insufficientBalance(missing):
                throw ServiceError.insufficientCoconuts(missing: missing)
            case .walletFrozen:
                throw ServiceError.walletFrozen
            case .persistenceFailed, nil:
                throw ServiceError.saveFailed("2.5D Avatar Pass purchase was not saved.")
            }
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
        let currentMembers = try existingMembers(
            existingPets: existingPets,
            existingHumans: existingHumans,
            context: context
        )
        guard !currentMembers.normalizedNames.contains(candidate) else { throw ServiceError.duplicateName }

        switch draft.kind {
        case .pet:
            return try savePet(
                draft: draft,
                existingPets: currentMembers.pets,
                existingHumans: currentMembers.humans,
                context: context,
                countryCode: countryCode
            )
        case .human:
            return try saveHuman(
                draft: draft,
                existingPets: currentMembers.pets,
                existingHumans: currentMembers.humans,
                context: context,
                countryCode: countryCode
            )
        }
    }

    private func existingMembers(
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext
    ) throws -> MemberCreationExistingMembers {
        do {
            let fetchedPets = try context.fetch(FetchDescriptor<Pet>())
            let fetchedHumans = try context.fetch(FetchDescriptor<Human>())
            let pets = mergePetsByID(existingPets + fetchedPets)
            let humans = mergeHumansByID(existingHumans + fetchedHumans)
            return MemberCreationExistingMembers(pets: pets, humans: humans)
        } catch {
            throw ServiceError.saveFailed("Could not verify existing member names: \(error.localizedDescription)")
        }
    }

    private func mergePetsByID(_ pets: [Pet]) -> [Pet] {
        var seen = Set<UUID>()
        var merged: [Pet] = []
        for pet in pets {
            guard seen.insert(pet.id).inserted else { continue }
            merged.append(pet)
        }
        return merged
    }

    private func mergeHumansByID(_ humans: [Human]) -> [Human] {
        var seen = Set<UUID>()
        var merged: [Human] = []
        for human in humans {
            guard seen.insert(human.id).inserted else { continue }
            merged.append(human)
        }
        return merged
    }

    private func savePet(
        draft: MemberCreationDraft,
        existingPets: [Pet],
        existingHumans: [Human],
        context: ModelContext,
        countryCode: String
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
        pet.updateAvatarImageData(draft.avatarImageData)
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
        insertInitialPetWeightIfNeeded(
            pet: pet,
            draft: draft,
            context: context,
            countryCode: countryCode
        )
        do {
            try context.save()
        } catch {
            if !shouldShowOnHome {
                HomeCardVisibility.restoreHiddenPetIDsRaw(previousHiddenHomePetIDsRaw)
            }
            context.delete(pet) // derived-state: allow local rollback after failed first save; no persisted record or sync deletion exists yet
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
        }
        revisions.publishMemberProfileChange(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            note: "memberCreation.pet.profile"
        )
        publishMemberCreation(id: pet.id, kind: "pet", revisions: revisions)
        return SaveResult(pet: pet, human: nil)
    }

    private func insertInitialPetWeightIfNeeded(
        pet: Pet,
        draft: MemberCreationDraft,
        context: ModelContext,
        countryCode: String
    ) {
        guard let weight = CountryDecimalInput.parse(draft.weightText, countryCode: countryCode),
              weight > 0 else { return }
        let now = Date()
        let executorId = activeHumanSelection.currentHumanId
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: now,
            writeKind: .care,
            executorId: executorId,
            context: context,
            logPrefix: "MemberCreationService.savePet.initialWeight"
        ) else { return }
        let bcsScore = PetBodyConditionEstimator.suggestedBCS(for: pet, weightKg: weight)
        let log = DomainMemberFactWriter.createPetWeightLog(
            plan: write,
            pet: pet,
            weight: weight,
            weightUnit: "kg",
            bcsScore: bcsScore,
            context: context
        )
        careLedger.record(
            occurredAt: log.date,
            actorKind: write.actor.effectiveExecutorId == nil ? .unknown : .human,
            actorId: write.actor.effectiveExecutorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: log.weightInKg,
            amountUnit: "kg",
            note: "",
            source: .detail,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: "PetWeightLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "{\"starterFirstCare\":true}",
            context: context,
            save: false
        )
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
        human.updateAvatarImageData(draft.avatarImageData)
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
            let now = Date()
            if let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
                human: human,
                occurredAt: now,
                writeKind: .care,
                executorId: executorId,
                context: context,
                logPrefix: "MemberCreationService.saveHuman.weight"
            ) {
                _ = DomainMemberFactWriter.createHumanWeightLog(
                    plan: write,
                    human: human,
                    weight: weight,
                    context: context
                )
                IslandQuestEngine.markInitialHumanWeightRecorded(humanId: human.id)
            }
        }
        if draft.hasBirthday {
            createMemberSchedule(
                title: "\(draft.trimmedName)\(L10n.current.humanWizBirthdayEventSuffix)",
                startDate: draft.birthday,
                isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: human.id.uuidString,
                recurrenceDays: 365,
                context: context
            )
        }
        do {
            try context.save()
        } catch {
            context.delete(human) // derived-state: allow local rollback after failed first save; no persisted record or sync deletion exists yet
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
            createMemberSchedule(
                title: "\(draft.trimmedName) 的生日 🎂",
                startDate: draft.birthday,
                isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString,
                recurrenceDays: 365,
                reminderDates: [draft.birthday],
                context: context
            )
        }
        if draft.hasHomeDate {
            createMemberSchedule(
                title: "\(draft.trimmedName) 的到家纪念日 🏠",
                startDate: draft.homeDate,
                isAllDay: true,
                eventType: EventType.anniversary.rawValue,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString,
                recurrenceDays: 365,
                context: context
            )
        }
        if draft.hasHomeDate {
            let milestones = [100, 365, 500, 730, 1000, 1095]
            for days in milestones {
                if let date = Calendar.current.date(byAdding: .day, value: days, to: draft.homeDate) {
                    guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
                        pet: pet,
                        occurredAt: date,
                        writeKind: .memorial,
                        context: context,
                        logPrefix: "MemberCreationService.insertPetRelatedRecords.milestone"
                    ) else { continue }
                    _ = DomainMemberFactWriter.createPetMilestone(
                        plan: write,
                        date: date,
                        title: L10n.current.petWizMilestoneTogether(days),
                        emoji: days >= 1000 ? "🏆" : "🎉",
                        notes: "",
                        pet: pet,
                        context: context
                    )
                }
            }
        }
    }

    @discardableResult
    private func createMemberSchedule(
        title: String,
        startDate: Date,
        isAllDay: Bool,
        eventType: String,
        relatedEntityType: String,
        relatedEntityId: String,
        recurrenceDays: Int,
        reminderDates: [Date] = [],
        context: ModelContext
    ) -> DomainScheduleWriteResult? {
        let intent = DomainScheduleCreateIntent(
            title: title,
            startDate: startDate,
            isAllDay: isAllDay,
            eventType: eventType,
            relatedEntityType: relatedEntityType,
            relatedEntityId: relatedEntityId,
            recurrenceDays: recurrenceDays,
            reminderDates: reminderDates,
            writeKind: .memorialContentWithOptionalDerivations,
            source: .domainService
        )
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return nil
        }
        let result = DomainScheduleWriter.createEvent(plan: plan, context: context)
        CloudSyncMutationRecorder.markModified(result.event, context: context)
        for reminder in result.reminders {
            CloudSyncMutationRecorder.markModified(reminder, context: context)
        }
        return result
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

    private func publishMemberCreation(id: UUID, kind: String, revisions: DomainRevisionPublishing) {
        revisions.publishMemberCreation(entityID: id, kind: kind, note: kind)
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
