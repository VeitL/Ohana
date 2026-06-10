//
//  StarterGiftService.swift
//  Ohana
//
//  First-run coconut gift and Lv0 -> Lv1 ceremony state.
//

import Foundation
import SwiftData

enum StarterGiftPolicy {
    static let giftAmount = 50
}

enum StarterGiftService {
    static let giftAmount = StarterGiftPolicy.giftAmount

    enum Key {
        static let claimed = "ohanaStarterGiftClaimedV1"
        static let pending = "ohanaStarterGiftPendingV1"
        static let ceremonySeen = "ohanaStarterLv0CeremonySeenV1"
    }

    enum Result: Equatable {
        case alreadyHandled
        case markedExistingUser
        case pendingHuman
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
        if defaults.bool(forKey: Key.claimed) {
            return .alreadyHandled
        }

        let hasPendingGift = defaults.bool(forKey: Key.pending)
        let counts = dataCounts(context: context)

        if let activeHumanID, let human = activeHuman(matching: activeHumanID, context: context) {
            if hasPendingGift {
                return claim(for: human, context: context, defaults: defaults, careLedger: careLedger, wallet: wallet, projectionManager: projectionManager)
            }

            if counts.humans == 1, counts.pets == 0, counts.ledger == 0 {
                defaults.set(true, forKey: Key.pending)
                return claim(for: human, context: context, defaults: defaults, careLedger: careLedger, wallet: wallet, projectionManager: projectionManager)
            }

            markExistingUser(defaults: defaults)
            return .markedExistingUser
        }

        if counts.humans == 0, counts.pets == 0, counts.ledger == 0 {
            defaults.set(true, forKey: Key.pending)
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
        defaults.set(true, forKey: Key.ceremonySeen)
        AppPerformanceMonitor.shared.record("starter_ceremony_seen", valueMS: 0)
    }

    @MainActor
    static func shouldShowCeremony(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.claimed) && !defaults.bool(forKey: Key.ceremonySeen)
    }

    @MainActor
    static func resetForDebug(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Key.claimed)
        defaults.removeObject(forKey: Key.pending)
        defaults.removeObject(forKey: Key.ceremonySeen)
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
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: projectionManager
            )
            try context.save()
        } catch {
            context.rollback()
            #if DEBUG
            print("❌ [StarterGiftService] wallet write failed: \(error.localizedDescription)")
            #endif
            return .missingHuman
        }

        defaults.set(true, forKey: Key.claimed)
        defaults.set(false, forKey: Key.pending)
        AppPerformanceMonitor.shared.record("starter_gift_claimed", valueMS: 0, note: "amount=\(giftAmount)")
        return .claimed(humanID: human.id, amount: giftAmount)
    }

    @MainActor
    private static func markExistingUser(defaults: UserDefaults) {
        defaults.set(true, forKey: Key.claimed)
        defaults.set(true, forKey: Key.ceremonySeen)
    }

    @MainActor
    private static func dataCounts(context: ModelContext) -> (humans: Int, pets: Int, ledger: Int) {
        let humans = (try? context.fetchCount(FetchDescriptor<Human>())) ?? 0
        let pets = (try? context.fetchCount(FetchDescriptor<Pet>())) ?? 0
        let ledger = (try? context.fetchCount(FetchDescriptor<CareLedgerEvent>())) ?? 0
        return (humans, pets, ledger)
    }

    @MainActor
    private static func activeHuman(matching id: String, context: ModelContext) -> Human? {
        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? []
        return humans.first { $0.id.uuidString == id } ?? humans.first
    }

    private static func localizedGiftTitle() -> String {
        L10n(UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.code).tr(
            zh: "新人椰子礼包",
            en: "Starter coconut gift",
            de: "Starter-Kokosgeschenk"
        )
    }
}
