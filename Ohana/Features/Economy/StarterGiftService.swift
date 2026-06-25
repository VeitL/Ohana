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

    enum Result: Equatable {
        case alreadyHandled
        case markedExistingUser
        case pendingHuman
        case pendingFirstCare(humanID: UUID)
        case claimed(humanID: UUID, amount: Int)
        case missingHuman
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

        let hasPendingGift = defaults.bool(forKey: StarterGiftStorageKey.pending)
        let counts = dataCounts(context: context)
        let hasFirstPetWeight = hasRecordedPetWeight(context: context)

        if let human = activeHuman(matching: activeHumanID ?? "", context: context) {
            if hasPendingGift || counts.humans == 1 && counts.pets == 0 && counts.ledger == 0 && counts.petWeights == 0 {
                defaults.set(true, forKey: StarterGiftStorageKey.pending)
                guard hasFirstPetWeight else {
                    AppPerformanceMonitor.shared.record("starter_gift_waiting_for_first_pet_weight", valueMS: 0)
                    return .pendingFirstCare(humanID: human.id)
                }
                return claim(for: human, context: context, defaults: defaults, careLedger: careLedger, wallet: wallet, projectionManager: projectionManager)
            }

            markExistingUser(defaults: defaults)
            return .markedExistingUser
        }

        if counts.humans == 0, counts.pets == 0, counts.ledger == 0, counts.petWeights == 0 {
            defaults.set(true, forKey: StarterGiftStorageKey.pending)
            AppPerformanceMonitor.shared.record("starter_gift_pending", valueMS: 0)
            return .pendingHuman
        }

        if hasPendingGift {
            return .missingHuman
        }

        markExistingUser(defaults: defaults)
        return .markedExistingUser
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
        for human: Human,
        context: ModelContext,
        defaults: UserDefaults,
        careLedger: CareLedgerRecording,
        wallet: CoconutWalletManaging,
        projectionManager: QuestManager?
    ) -> Result {
        let title = localizedGiftTitle()
        let ledger = careLedger.record(
            occurredAt: Date(),
            actorKind: .system,
            actorId: nil,
            subjectKind: .human,
            subjectId: human.id.uuidString,
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
                deltas: [
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
                        metadataJSON: "{\"starterGift\":true}"
                    )
                ],
                context: context,
                save: false,
                postsRewardFeedback: false,
                updatesProjection: true,
                projectionManager: projectionManager
            )
            try context.save()
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: projectionManager)
            #if DEBUG
                OhanaLog.error("[StarterGiftService] wallet write failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return .missingHuman
        }

        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(false, forKey: StarterGiftStorageKey.pending)
        AppPerformanceMonitor.shared.record("starter_gift_claimed", valueMS: 0, note: "amount=\(giftAmount)")
        return .claimed(humanID: human.id, amount: giftAmount)
    }

    @MainActor
    private static func markExistingUser(defaults: UserDefaults) {
        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.set(false, forKey: StarterGiftStorageKey.oasisTabPromptPending)
    }

    @MainActor
    private static func dataCounts(context: ModelContext) -> (humans: Int, pets: Int, ledger: Int, petWeights: Int) {
        let humans = fetchCountOrLog(FetchDescriptor<Human>(), context: context, operation: "fetch human count")
        let pets = fetchCountOrLog(FetchDescriptor<Pet>(), context: context, operation: "fetch pet count")
        let ledger = fetchCountOrLog(FetchDescriptor<CareLedgerEvent>(), context: context, operation: "fetch care ledger count")
        let petWeights = fetchCountOrLog(FetchDescriptor<PetWeightLog>(), context: context, operation: "fetch pet weight count")
        return (humans, pets, ledger, petWeights)
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
    private static func hasRecordedPetWeight(context: ModelContext) -> Bool {
        var weightDescriptor = FetchDescriptor<PetWeightLog>()
        weightDescriptor.fetchLimit = 1
        if fetchModelsOrLog(weightDescriptor, context: context, operation: "fetch starter gift pet weight").isEmpty == false {
            return true
        }
        var ledgerDescriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.eventKind == "weight" && event.actionType == "petWeight"
            }
        )
        ledgerDescriptor.fetchLimit = 1
        return fetchModelsOrLog(ledgerDescriptor, context: context, operation: "fetch starter gift pet weight ledger").isEmpty == false
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
