//
//  StarterGiftService.swift
//  Ohana
//
//  First-run coconut gift and Lv0 starter ceremony state.
//

import Foundation
import SwiftData

enum StarterGiftPolicy {
    static let giftAmount = 50
}

nonisolated enum StarterGiftStorageKey {
    static let claimed = "ohanaStarterGiftClaimedV1"
    static let pending = "ohanaStarterGiftPendingV1"
    static let ceremonySeen = "ohanaStarterLv0CeremonySeenV1"
    static let oasisTabPromptPending = "ohanaStarterOasisTabPromptPendingV1"
}

enum StarterGiftService {
    static let giftAmount = StarterGiftPolicy.giftAmount

    enum Recipient: Equatable {
        case human(UUID)
        case pet(UUID)
    }

    enum Result: Equatable {
        case alreadyHandled
        case markedExistingUser
        case pendingFirstPet
        case pendingFirstCare(recipient: Recipient)
        case claimed(recipient: Recipient, amount: Int)
        case persistenceFailed
    }

    private enum RecipientEntity {
        case human(Human)
        case pet(Pet)

        var value: Recipient {
            switch self {
            case let .human(human): .human(human.id)
            case let .pet(pet): .pet(pet.id)
            }
        }
    }

    @discardableResult
    @MainActor
    static func beginFreshJourney(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: StarterGiftStorageKey.claimed),
              !defaults.bool(forKey: StarterGiftStorageKey.pending),
              dataCounts(context: context).isPristine else {
            return false
        }
        defaults.set(true, forKey: StarterGiftStorageKey.pending)
        AppPerformanceMonitor.shared.record("starter_gift_pending", valueMS: 0)
        return true
    }

    @MainActor
    static func prepareOrClaim(
        activeHumanID: String?,
        context: ModelContext,
        defaults: UserDefaults = .standard,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        wallet providedWallet: CoconutWalletManaging? = nil,
        projectionManager: QuestManager? = nil
    ) -> Result {
        let careLedger: CareLedgerRecording = providedCareLedger ?? CareLedgerService()
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        if defaults.bool(forKey: StarterGiftStorageKey.claimed) {
            return .alreadyHandled
        }

        if hasPersistedStarterGift(context: context) {
            // The SwiftData save contains both the gift event and wallet write.
            // Recovering the defaults after a termination must reveal that
            // committed transaction, never mint the gift a second time.
            defaults.set(true, forKey: StarterGiftStorageKey.claimed)
            defaults.set(false, forKey: StarterGiftStorageKey.pending)
            return .alreadyHandled
        }

        var hasPendingGift = defaults.bool(forKey: StarterGiftStorageKey.pending)
        if !hasPendingGift {
            hasPendingGift = beginFreshJourney(context: context, defaults: defaults)
        }
        guard hasPendingGift else {
            markExistingUser(defaults: defaults)
            return .markedExistingUser
        }

        guard let pet = firstActivePet(context: context) else {
            AppPerformanceMonitor.shared.record("starter_gift_waiting_for_first_pet", valueMS: 0)
            return .pendingFirstPet
        }

        let recipient: RecipientEntity = activeHuman(matching: activeHumanID ?? "", context: context)
            .map(RecipientEntity.human) ?? .pet(pet)
        guard hasRecordedFirstCare(context: context) else {
            AppPerformanceMonitor.shared.record("starter_gift_waiting_for_first_care", valueMS: 0)
            return .pendingFirstCare(recipient: recipient.value)
        }

        return claim(
            for: recipient,
            context: context,
            defaults: defaults,
            careLedger: careLedger,
            wallet: wallet,
            projectionManager: projectionManager
        )
    }

    @MainActor
    static func markCeremonySeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.set(true, forKey: StarterGiftStorageKey.oasisTabPromptPending)
        AppPerformanceMonitor.shared.record("starter_ceremony_seen", valueMS: 0)
    }

    @MainActor
    static func shouldShowCeremony(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: StarterGiftStorageKey.claimed) && !defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen)
    }

    static func isOasisHomeTabUnlocked(defaults: UserDefaults = .standard) -> Bool {
        !(defaults.bool(forKey: StarterGiftStorageKey.claimed) && !defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen))
    }

    @MainActor
    static func resetForDebug(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: StarterGiftStorageKey.claimed)
        defaults.removeObject(forKey: StarterGiftStorageKey.pending)
        defaults.removeObject(forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.removeObject(forKey: StarterGiftStorageKey.oasisTabPromptPending)
    }

    @MainActor
    private static func claim(
        for recipient: RecipientEntity,
        context: ModelContext,
        defaults: UserDefaults,
        careLedger: CareLedgerRecording,
        wallet: CoconutWalletManaging,
        projectionManager: QuestManager?
    ) -> Result {
        let title = localizedGiftTitle()
        let occurredAt = Date()
        let subjectKind: CareLedgerSubjectKind
        let subjectID: String
        let walletDelta: (CareLedgerEvent) -> CoconutWalletDelta
        switch recipient {
        case let .human(human):
            subjectKind = .human
            subjectID = human.id.uuidString
            walletDelta = { ledger in
                .human(
                    human,
                    delta: giftAmount,
                    entryKind: .reward,
                    source: .starterGift,
                    title: title,
                    emoji: "🎁",
                    actorId: human.id.uuidString,
                    actorName: human.name,
                    subjectKind: .human,
                    subjectId: human.id.uuidString,
                    sourceModelName: "CareLedgerEvent",
                    sourceModelId: ledger.id.uuidString,
                    careLedgerEventId: ledger.id.uuidString,
                    metadataJSON: "{\"starterGift\":true}",
                    occurredAt: occurredAt,
                    transactionKey: "starterGift:v2:\(CoconutAccountKey.human(human.id))"
                )
            }
        case let .pet(pet):
            subjectKind = .pet
            subjectID = pet.id.uuidString
            walletDelta = { ledger in
                .pet(
                    pet,
                    delta: giftAmount,
                    entryKind: .reward,
                    source: .starterGift,
                    title: title,
                    emoji: "🎁",
                    actorId: nil,
                    actorName: nil,
                    subjectKind: .pet,
                    subjectId: pet.id.uuidString,
                    sourceModelName: "CareLedgerEvent",
                    sourceModelId: ledger.id.uuidString,
                    careLedgerEventId: ledger.id.uuidString,
                    metadataJSON: "{\"starterGift\":true}",
                    occurredAt: occurredAt,
                    transactionKey: "starterGift:v2:\(CoconutAccountKey.pet(pet.id))"
                )
            }
        }
        let ledger = careLedger.record(
            occurredAt: occurredAt,
            actorKind: .system,
            actorId: nil,
            subjectKind: subjectKind,
            subjectId: subjectID,
            eventKind: .coconut,
            actionType: "starterGift",
            amountValue: Double(giftAmount),
            amountUnit: "coconut",
            note: title,
            source: .economy,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: giftAmount,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "{\"economyVersion\":2,\"starterGift\":true,\"growthXP\":0,\"coconutBase\":\(giftAmount),\"coconutBonus\":0}",
            context: context,
            save: false
        )
        do {
            try wallet.apply(
                deltas: [walletDelta(ledger)],
                context: context,
                save: false,
                postsRewardFeedback: false,
                updatesProjection: true,
                projectionManager: projectionManager
            )
            try saveStarterGiftChanges(context: context)
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: projectionManager)
            #if DEBUG
                OhanaLog.error("[StarterGiftService] wallet write failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return .persistenceFailed
        }

        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(false, forKey: StarterGiftStorageKey.pending)
        AppPerformanceMonitor.shared.record("starter_gift_claimed", valueMS: 0, note: "amount=\(giftAmount)")
        return .claimed(recipient: recipient.value, amount: giftAmount)
    }

    @MainActor
    private static func saveStarterGiftChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            throw StarterGiftPersistenceError.persistenceFailed(saveResult.errorDescription)
        }
    }

    @MainActor
    private static func markExistingUser(defaults: UserDefaults) {
        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.set(false, forKey: StarterGiftStorageKey.pending)
        defaults.set(false, forKey: StarterGiftStorageKey.oasisTabPromptPending)
    }

    @MainActor
    private static func dataCounts(context: ModelContext) -> StarterGiftDataCounts {
        let humans = fetchCountOrLog(FetchDescriptor<Human>(), context: context, operation: "fetch human count")
        let pets = fetchCountOrLog(FetchDescriptor<Pet>(), context: context, operation: "fetch pet count")
        let ledger = fetchCountOrLog(FetchDescriptor<CareLedgerEvent>(), context: context, operation: "fetch care ledger count")
        let petWeights = fetchCountOrLog(FetchDescriptor<PetWeightLog>(), context: context, operation: "fetch pet weight count")
        return StarterGiftDataCounts(humans: humans, pets: pets, ledger: ledger, petWeights: petWeights)
    }

    @MainActor
    private static func firstActivePet(context: ModelContext) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.passedAwayDate == nil
            },
            sortBy: [SortDescriptor(\Pet.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(descriptor, context: context, operation: "fetch starter gift pet").first
    }

    @MainActor
    private static func hasRecordedFirstCare(context: ModelContext) -> Bool {
        if fetchCountOrLog(
            FetchDescriptor<PetWeightLog>(),
            context: context,
            operation: "fetch starter pet weight count"
        ) > 0 {
            return true
        }
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.actionType != "starterGift" && event.eventKind != "coconut"
            }
        )
        descriptor.fetchLimit = 1
        return !fetchModelsOrLog(descriptor, context: context, operation: "fetch starter care facts").isEmpty
    }

    @MainActor
    private static func hasPersistedStarterGift(context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.actionType == "starterGift"
            }
        )
        descriptor.fetchLimit = 1
        return !fetchModelsOrLog(descriptor, context: context, operation: "recover persisted starter gift").isEmpty
    }

    @MainActor
    private static func activeHuman(matching id: String, context: ModelContext) -> Human? {
        let humans = fetchModelsOrLog(FetchDescriptor<Human>(), context: context, operation: "fetch starter gift humans")
        return humans.first { $0.id.uuidString == id } ?? humans.first
    }

    @MainActor
    private static func fetchModelsOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "StarterGiftService failed to \(operation): \(error.localizedDescription)",
                category: "Economy"
            )
            return []
        }
    }

    @MainActor
    private static func fetchCountOrLog(
        _ descriptor: FetchDescriptor<some PersistentModel>,
        context: ModelContext,
        operation: String
    ) -> Int {
        do {
            return try context.fetchCount(descriptor)
        } catch {
            OhanaLog.warning(
                "StarterGiftService failed to \(operation): \(error.localizedDescription)",
                category: "Economy"
            )
            return 0
        }
    }

    private static func localizedGiftTitle() -> String {
        L10n(UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.code).tr(
            zh: "新人椰子礼包",
            en: "Starter coconut gift",
            de: "Starter-Kokosgeschenk"
        )
    }
}

private struct StarterGiftDataCounts {
    let humans: Int
    let pets: Int
    let ledger: Int
    let petWeights: Int

    var isPristine: Bool {
        humans == 0 && pets == 0 && ledger == 0 && petWeights == 0
    }
}

enum StarterGiftPersistenceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "starter.gift.persistence.failed",
                defaultValue: "Unable to save the starter gift.",
                comment: "Shown when the first-run starter gift cannot be saved."
            )
        }
    }
}
