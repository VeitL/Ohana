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
    static let ceremonyRequested = "ohanaStarterCeremonyRequestedV1"
    static let oasisTabPromptPending = "ohanaStarterOasisTabPromptPendingV1"
}

enum StarterGiftService {
    static let giftAmount = StarterGiftPolicy.giftAmount

    enum Recipient: Equatable, Sendable {
        case island
        case human(UUID)
        case pet(UUID)
    }

    enum Result: Equatable, Sendable {
        case alreadyHandled
        case markedExistingUser
        case pendingFirstPet
        case readyToClaim(recipient: Recipient, amount: Int)
        case claimed(recipient: Recipient, amount: Int)
        case persistenceFailed

        var completesClaimRequest: Bool {
            switch self {
            case .alreadyHandled, .claimed:
                true
            case .markedExistingUser, .pendingFirstPet, .readyToClaim, .persistenceFailed:
                false
            }
        }
    }

    private enum LegacyGiftTransferSource {
        case human(Human, balance: Int)
        case pet(Pet, balance: Int)

        var balance: Int {
            switch self {
            case let .human(_, balance), let .pet(_, balance):
                balance
            }
        }

        func debitDelta(
            amount: Int,
            title: String,
            emoji: String,
            sourceModelName: String,
            sourceModelId: String,
            metadataJSON: String,
            transactionKey: String
        ) -> CoconutWalletDelta {
            switch self {
            case let .human(human, _):
                .human(
                    human,
                    delta: -amount,
                    entryKind: .transferOut,
                    source: .starterGift,
                    title: title,
                    emoji: emoji,
                    subjectKind: .household,
                    subjectId: "island",
                    sourceModelName: sourceModelName,
                    sourceModelId: sourceModelId,
                    metadataJSON: metadataJSON,
                    transactionKey: transactionKey
                )
            case let .pet(pet, _):
                .pet(
                    pet,
                    delta: -amount,
                    entryKind: .transferOut,
                    source: .starterGift,
                    title: title,
                    emoji: emoji,
                    subjectKind: .household,
                    subjectId: "island",
                    sourceModelName: sourceModelName,
                    sourceModelId: sourceModelId,
                    metadataJSON: metadataJSON,
                    transactionKey: transactionKey
                )
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
        defaults.set(false, forKey: StarterGiftStorageKey.ceremonyRequested)
        AppPerformanceMonitor.shared.record("starter_gift_pending", valueMS: 0)
        return true
    }

    @MainActor
    static func evaluateEligibility(
        activeHumanID: String?,
        context: ModelContext,
        defaults: UserDefaults = .standard,
        wallet providedWallet: CoconutWalletManaging? = nil,
        projectionManager: QuestManager? = nil
    ) -> Result {
        _ = activeHumanID
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        guard prepareEligibilityState(
            context: context,
            defaults: defaults,
            wallet: wallet,
            projectionManager: projectionManager
        ) else {
            return .persistenceFailed
        }
        if defaults.bool(forKey: StarterGiftStorageKey.claimed) {
            return .alreadyHandled
        }

        do {
            if try hasPersistedStarterGift(context: context) {
                // The SwiftData save contains both the gift event and wallet write.
                // Recovering the defaults after a termination must reveal that
                // committed transaction, never mint the gift a second time.
                defaults.set(true, forKey: StarterGiftStorageKey.claimed)
                defaults.set(false, forKey: StarterGiftStorageKey.pending)
                return .alreadyHandled
            }
        } catch {
            OhanaLog.warning(
                "StarterGiftService failed to recover persisted starter gift: \(error.localizedDescription)",
                category: "Economy"
            )
            return .persistenceFailed
        }

        // Only the first-run onboarding surface may begin a fresh journey.
        // Eligibility can also run for users who completed an older onboarding
        // version, including users whose local household is currently empty;
        // treating that read as a new install would incorrectly backfill a gift.
        guard defaults.bool(forKey: StarterGiftStorageKey.pending) else {
            markExistingUser(defaults: defaults)
            return .markedExistingUser
        }

        guard firstActivePet(context: context) != nil else {
            AppPerformanceMonitor.shared.record("starter_gift_waiting_for_first_pet", valueMS: 0)
            return .pendingFirstPet
        }

        return .readyToClaim(recipient: .island, amount: giftAmount)
    }

    /// The only new-journey starter-gift write path. Eligibility evaluation is
    /// intentionally read-mostly so presenting the reward cannot mint coconuts
    /// before the person confirms the action.
    @MainActor
    static func claimStarterGift(
        activeHumanID: String?,
        context: ModelContext,
        defaults: UserDefaults = .standard,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        wallet providedWallet: CoconutWalletManaging? = nil,
        projectionManager: QuestManager? = nil
    ) -> Result {
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let eligibility = evaluateEligibility(
            activeHumanID: activeHumanID,
            context: context,
            defaults: defaults,
            wallet: wallet,
            projectionManager: projectionManager
        )
        guard case .readyToClaim = eligibility else { return eligibility }

        return claim(
            context: context,
            defaults: defaults,
            careLedger: providedCareLedger ?? CareLedgerService(),
            wallet: wallet,
            projectionManager: projectionManager
        )
    }

    @MainActor
    static func markCeremonySeen(defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: StarterGiftStorageKey.claimed) else { return }
        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.set(false, forKey: StarterGiftStorageKey.ceremonyRequested)
        defaults.set(true, forKey: StarterGiftStorageKey.oasisTabPromptPending)
        AppPerformanceMonitor.shared.record("starter_ceremony_seen", valueMS: 0)
    }

    @MainActor
    static func shouldShowCeremony(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: StarterGiftStorageKey.claimed) && !defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen)
    }

    static func isOasisHomeTabUnlocked(defaults: UserDefaults = .standard) -> Bool {
        if defaults.bool(forKey: StarterGiftStorageKey.pending) {
            return false
        }
        if defaults.bool(forKey: StarterGiftStorageKey.claimed) {
            return defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen)
        }
        // Users from before the starter journey have neither flag. Preserve
        // their already-visible Oasis instead of treating them as a new install.
        return true
    }

    @MainActor
    static func resetForDebug(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: StarterGiftStorageKey.claimed)
        defaults.removeObject(forKey: StarterGiftStorageKey.pending)
        defaults.removeObject(forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.removeObject(forKey: StarterGiftStorageKey.ceremonyRequested)
        defaults.removeObject(forKey: StarterGiftStorageKey.oasisTabPromptPending)
    }

    @MainActor
    private static func claim(
        context: ModelContext,
        defaults: UserDefaults,
        careLedger: CareLedgerRecording,
        wallet: CoconutWalletManaging,
        projectionManager: QuestManager?
    ) -> Result {
        let title = localizedGiftTitle()
        let occurredAt = Date()
        let ledger = careLedger.record(
            occurredAt: occurredAt,
            actorKind: .system,
            actorId: nil,
            subjectKind: .household,
            subjectId: nil,
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
            metadataJSON: "{\"economyVersion\":3,\"starterGift\":true,\"walletScope\":\"island\",\"growthXP\":0,\"coconutBase\":\(giftAmount),\"coconutBonus\":0}",
            context: context,
            save: false
        )
        do {
            try wallet.apply(
                deltas: [
                    .island(
                        delta: giftAmount,
                        entryKind: .reward,
                        source: .starterGift,
                        title: title,
                        emoji: "🎁",
                        sourceModelName: "CareLedgerEvent",
                        sourceModelId: ledger.id.uuidString,
                        careLedgerEventId: ledger.id.uuidString,
                        metadataJSON: "{\"starterGift\":true,\"walletScope\":\"island\"}",
                        occurredAt: occurredAt,
                        transactionKey: "starterGift:v3:\(CoconutAccountKey.islandReserve)"
                    )
                ],
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
        return .claimed(recipient: .island, amount: giftAmount)
    }

    @MainActor
    private static func migrateLegacyRecipientGiftIfNeeded(
        context: ModelContext,
        wallet: CoconutWalletManaging,
        projectionManager: QuestManager?
    ) throws {
        let starterGiftSource = CoconutWalletSource.starterGift.rawValue
        var legacyDescriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { entry in
                entry.sourceRaw == starterGiftSource && entry.delta > 0
            },
            sortBy: [SortDescriptor(\CoconutLedgerEntry.occurredAt, order: .forward)]
        )
        legacyDescriptor.fetchLimit = 8
        guard let legacyGift = try context.fetch(legacyDescriptor).first(where: {
            $0.ownerKind != .system && $0.transactionKey.hasPrefix("starterGift:v2:")
        }) else {
            return
        }

        let migrationModelName = "StarterGiftOwnershipMigration"
        let migrationModelID = legacyGift.id.uuidString
        var migrationDescriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { entry in
                entry.sourceModelName == migrationModelName && entry.sourceModelId == migrationModelID
            }
        )
        migrationDescriptor.fetchLimit = 1
        guard try context.fetch(migrationDescriptor).isEmpty else { return }

        let migrationKey = "starterGift:v3:reclassify:\(migrationModelID)"
        let metadataJSON = "{\"starterGiftOwnershipMigration\":true,\"fromAccountKey\":\"\(legacyGift.accountKey)\",\"toAccountKey\":\"\(CoconutAccountKey.islandReserve)\"}"
        var deltas: [CoconutWalletDelta] = []
        if let source = legacyGiftTransferSource(for: legacyGift, context: context) {
            let transferAmount = min(max(0, legacyGift.delta), source.balance)
            if transferAmount > 0 {
                deltas.append(source.debitDelta(
                    amount: transferAmount,
                    title: legacyGift.title,
                    emoji: legacyGift.emoji,
                    sourceModelName: migrationModelName,
                    sourceModelId: migrationModelID,
                    metadataJSON: metadataJSON,
                    transactionKey: "\(migrationKey):out"
                ))
                deltas.append(.island(
                    delta: transferAmount,
                    entryKind: .transferIn,
                    source: .starterGift,
                    title: legacyGift.title,
                    emoji: legacyGift.emoji,
                    sourceModelName: migrationModelName,
                    sourceModelId: migrationModelID,
                    metadataJSON: metadataJSON,
                    occurredAt: legacyGift.occurredAt,
                    transactionKey: "\(migrationKey):in"
                ))
            }
        }
        deltas.append(.island(
            delta: 0,
            entryKind: .legacyHistory,
            source: .starterGift,
            title: legacyGift.title,
            emoji: legacyGift.emoji,
            sourceModelName: migrationModelName,
            sourceModelId: migrationModelID,
            metadataJSON: metadataJSON,
            occurredAt: legacyGift.occurredAt,
            transactionKey: "\(migrationKey):marker",
            affectsBalance: false
        ))

        try wallet.apply(
            deltas: deltas,
            context: context,
            save: false,
            postsRewardFeedback: false,
            updatesProjection: true,
            projectionManager: projectionManager
        )
        try saveStarterGiftChanges(context: context)
    }

    @MainActor
    private static func legacyGiftTransferSource(
        for entry: CoconutLedgerEntry,
        context: ModelContext
    ) -> LegacyGiftTransferSource? {
        guard let ownerID = UUID(uuidString: entry.ownerId) else { return nil }
        switch entry.ownerKind {
        case .human:
            var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == ownerID })
            descriptor.fetchLimit = 1
            guard let humans = try? context.fetch(descriptor),
                  let human = humans.first,
                  EconomyWalletWritePolicy.canWrite(human) else { return nil }
            return .human(human, balance: CoconutWalletService.balance(for: human, context: context))
        case .pet:
            var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == ownerID })
            descriptor.fetchLimit = 1
            guard let pets = try? context.fetch(descriptor),
                  let pet = pets.first,
                  EconomyWalletWritePolicy.canWrite(pet) else { return nil }
            return .pet(pet, balance: CoconutWalletService.balance(for: pet, context: context))
        case .system:
            return nil
        }
    }

    @MainActor
    private static func saveStarterGiftChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            throw StarterGiftPersistenceError.persistenceFailed(saveResult.errorDescription)
        }
    }

    @MainActor
    private static func prepareEligibilityState(
        context: ModelContext,
        defaults: UserDefaults,
        wallet: CoconutWalletManaging,
        projectionManager: QuestManager?
    ) -> Bool {
        do {
            try migrateLegacyRecipientGiftIfNeeded(
                context: context,
                wallet: wallet,
                projectionManager: projectionManager
            )
            return true
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: projectionManager)
            OhanaLog.error(
                "[StarterGiftService] legacy gift ownership migration failed: \(error.localizedDescription)",
                category: "Economy"
            )
            return false
        }
    }

    @MainActor
    private static func markExistingUser(defaults: UserDefaults) {
        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.set(false, forKey: StarterGiftStorageKey.pending)
        defaults.set(false, forKey: StarterGiftStorageKey.ceremonyRequested)
        defaults.set(false, forKey: StarterGiftStorageKey.oasisTabPromptPending)
    }

    @MainActor
    private static func dataCounts(context: ModelContext) -> StarterGiftDataCounts {
        let humans = fetchCountOrLog(FetchDescriptor<Human>(), context: context, operation: "fetch human count")
        let pets = fetchCountOrLog(FetchDescriptor<Pet>(), context: context, operation: "fetch pet count")
        let ledger = fetchCountOrLog(FetchDescriptor<CareLedgerEvent>(), context: context, operation: "fetch care ledger count")
        return StarterGiftDataCounts(humans: humans, pets: pets, ledger: ledger)
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
    private static func hasPersistedStarterGift(context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.actionType == "starterGift"
            }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
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

    var isPristine: Bool {
        humans == 0 && pets == 0 && ledger == 0
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
