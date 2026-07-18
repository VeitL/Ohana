import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct AchievementProgressionTests {
    @Test func v94AddsOnlyDurableAchievementFactsAndRemainsLightweight() {
        let v93 = Set(ArkSchemaV93.models.map { String(describing: $0) })
        let v94 = Set(ArkSchemaV94.models.map { String(describing: $0) })

        #expect(v94.subtracting(v93) == [
            String(describing: AchievementUnlock.self),
            String(describing: AchievementRewardReceipt.self)
        ])
        #expect(v93.subtracting(v94).isEmpty)
        #expect(ObjectIdentifier(ArkMigrationPlan.schemas.last!) == ObjectIdentifier(ArkSchemaV94.self))
        #expect(ArkMigrationPlan.stages.isEmpty)
    }

    @Test func catalogKeepsFiftySixStableDefinitionsAndNineLanguageSlots() {
        let definitions = AchievementDefinitionCatalog.all
        let ids = Set(definitions.map(\.id))
        let expectedStardust: [String: Int] = [
            "global_first_critter": 20,
            "global_critter_caretaker": 20,
            "global_first_blind_box": 20,
            "global_gacha_jackpot": 20,
            "global_critter_collector": 40,
            "global_critter_star": 40,
            "global_blind_box_collector": 40,
            "global_legendary_critter": 60,
            "global_secret_blind_box": 60,
            "global_gacha_series_complete": 60
        ]

        #expect(definitions.count == 56)
        #expect(ids.count == 56)
        #expect(definitions.allSatisfy { $0.reward.coconuts == 10 })
        #expect(definitions.allSatisfy { $0.title.registeredLanguageCount == 9 })
        #expect(definitions.allSatisfy { $0.condition.registeredLanguageCount == 9 })
        #expect(definitions.reduce(0) { $0 + $1.reward.stardust } == 380)
        for (id, amount) in expectedStardust {
            #expect(AchievementDefinitionCatalog.definition(id: id)?.reward.stardust == amount)
        }
    }

    @Test func nutritionistRequiresActualConsecutiveCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12)))
        let consecutive = try (0 ..< 14).map { offset in
            try #require(calendar.date(byAdding: .day, value: offset, to: start))
        }
        var gapped = consecutive
        gapped.remove(at: 7)
        gapped.append(try #require(calendar.date(byAdding: .day, value: 20, to: start)))

        #expect(AchievementCareLedgerSummary.longestConsecutiveCalendarDays(consecutive, calendar: calendar) == 14)
        #expect(AchievementCareLedgerSummary.longestConsecutiveCalendarDays(gapped, calendar: calendar) == 7)
    }

    @Test func humanProfilePolicyNeverRequiresSensitiveOptionalFields() {
        let human = Human(name: "Guan")
        human.birthday = nil
        human.heightCm = 0
        human.bloodType = ""
        human.mbti = ""
        human.nationality = ""
        human.city = ""

        #expect(HumanBasicProfileAchievementPolicy.score(human) == 3)
        #expect(HumanBasicProfileAchievementPolicy.isReady(human))
    }

    @Test func transientBalanceConditionCreatesPermanentUnlock() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.coconutBalance = 500
        context.insert(human)
        try context.save()
        let scope = AchievementScopeReference.human(human.id)

        _ = try AchievementProgressionEngine.reconcile(
            AchievementProgressionRequest(affectedScopes: [scope], reason: .explicit),
            context: context
        )
        human.coconutBalance = 0
        try context.save()
        _ = try AchievementProgressionEngine.reconcile(
            AchievementProgressionRequest(affectedScopes: [scope], reason: .explicit),
            context: context
        )

        let unlocks = try context.fetch(FetchDescriptor<AchievementUnlock>())
        #expect(unlocks.count(where: { $0.achievementID == "human_coconut_saver" }) == 1)
    }

    @Test func islandCrewCountsOneHumanAndOnePetOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Human(name: "Guan"))
        context.insert(Pet(name: "Momo", species: "cat"))
        try context.save()

        _ = try AchievementProgressionEngine.reconcile(
            AchievementProgressionRequest(affectedScopes: [.island], reason: .explicit),
            context: context
        )
        let unlocks = try context.fetch(FetchDescriptor<AchievementUnlock>())
        #expect(unlocks.count(where: { $0.achievementID == "global_island_crew" }) == 1)
        #expect(unlocks.first(where: { $0.achievementID == "global_island_crew" })?.scopeKindRaw == AchievementScopeKind.island.rawValue)
    }

    @Test func commandCommitsCoconutsStardustLedgerAndReceiptTogether() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let key = AchievementScopeReference.island.achievementKey(for: "global_first_critter")
        context.insert(human)
        context.insert(
            AchievementUnlock(
                achievementKey: key,
                achievementID: "global_first_critter",
                scopeKindRaw: AchievementScopeKind.island.rawValue,
                scopeIDRaw: AchievementScopeReference.islandID,
                unlockedAt: Date()
            )
        )
        try context.save()

        let command = AchievementCommandActor(context: context)
        let result = command.claim(keys: [key], recipientID: human.id)

        #expect(result.didClaim)
        #expect(result.coconutAmount == 10)
        #expect(result.stardustAmount == 20)
        #expect(human.coconutBalance == 10)
        #expect(try context.fetch(FetchDescriptor<AchievementRewardReceipt>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).count == 1)
        let stardust = try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>())
            .first(where: { $0.catalogId == OasisCompanionCurrency.stardustCatalogID })
        #expect(stardust?.amount == 20)

        let duplicate = command.claim(keys: [key], recipientID: human.id)
        #expect(duplicate.failure == .alreadyClaimed)
        #expect(human.coconutBalance == 10)
        #expect(stardust?.amount == 20)
    }

    @Test func missingRecipientProducesNoPartialWrites() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let key = AchievementScopeReference.island.achievementKey(for: "global_first_critter")
        context.insert(
            AchievementUnlock(
                achievementKey: key,
                achievementID: "global_first_critter",
                scopeKindRaw: AchievementScopeKind.island.rawValue,
                scopeIDRaw: AchievementScopeReference.islandID,
                unlockedAt: Date()
            )
        )
        try context.save()

        let result = AchievementCommandActor(context: context).claim(keys: [key], recipientID: nil)

        #expect(result.failure == .missingRecipient)
        #expect(try context.fetch(FetchDescriptor<AchievementRewardReceipt>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>()).isEmpty)
    }

    @Test func legacyDefaultsAndWalletEvidenceBackfillExactlyOnceWithoutRewardingAgain() throws {
        let suite = "AchievementLegacyMigrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()
        let key = "\(human.id.uuidString)_human_first_record"
        defaults.set(key, forKey: AchievementLegacyMigrationService.claimedDefaultsKey)
        let wallet = SwiftDataCoconutWalletManager()
        _ = try wallet.apply(
            deltas: [.human(
                human,
                delta: 10,
                entryKind: .reward,
                source: .service,
                title: "Legacy achievement",
                transactionKey: "achievement:\(key)"
            )],
            context: context,
            save: true,
            postsRewardFeedback: false,
            updatesProjection: false,
            projectionManager: nil
        )

        let first = try AchievementLegacyMigrationService.migrateIfNeeded(
            context: context,
            defaults: defaults
        )
        let second = try AchievementLegacyMigrationService.migrateIfNeeded(
            context: context,
            defaults: defaults
        )

        #expect(first.insertedUnlockCount == 1)
        #expect(first.insertedReceiptCount == 1)
        #expect(second.insertedUnlockCount == 0)
        #expect(try context.fetch(FetchDescriptor<AchievementUnlock>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<AchievementRewardReceipt>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).count == 1)
        #expect(human.coconutBalance == 10)
    }

    @Test func memberPrefixedLegacyGlobalClaimRemainsClaimedUnderCanonicalIslandKey() async throws {
        let suite = "AchievementLegacyGlobalTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()
        let legacyKey = "\(pet.id.uuidString)_global_first_critter"
        defaults.set(legacyKey, forKey: AchievementLegacyMigrationService.claimedDefaultsKey)

        _ = try AchievementLegacyMigrationService.migrateIfNeeded(
            context: context,
            defaults: defaults
        )

        let receipt = try #require(context.fetch(FetchDescriptor<AchievementRewardReceipt>()).first)
        #expect(receipt.achievementKey == legacyKey)
        #expect(receipt.scopeKindRaw == AchievementScopeKind.island.rawValue)
        #expect(receipt.scopeIDRaw == AchievementScopeReference.islandID)

        let snapshot = try await AchievementWallReadActor(modelContainer: container).load(scopes: [.island])
        let canonicalKey = AchievementScopeReference.island.achievementKey(for: "global_first_critter")
        #expect(snapshot.items.first(where: { $0.achievementKey == canonicalKey })?.isClaimed == true)

        let duplicate = AchievementCommandActor(context: context).claim(
            keys: [canonicalKey],
            recipientID: human.id
        )
        #expect(duplicate.failure == .alreadyClaimed)
        #expect(human.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func v33BackupRestoresAchievementFactsWithoutMintingRewardsAndRedactsHumanScope() throws {
        let suite = "AchievementBackupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let source = try makeContainer()
        let context = source.mainContext
        let human = Human(name: "Guan")
        let islandKey = AchievementScopeReference.island.achievementKey(for: "global_first_critter")
        let humanKey = AchievementScopeReference.human(human.id).achievementKey(for: "human_first_record")
        context.insert(human)
        context.insert(
            AchievementUnlock(
                achievementKey: islandKey,
                achievementID: "global_first_critter",
                scopeKindRaw: AchievementScopeKind.island.rawValue,
                scopeIDRaw: AchievementScopeReference.islandID,
                unlockedAt: Date()
            )
        )
        context.insert(
            AchievementRewardReceipt(
                receiptKey: "achievement-reward:\(islandKey)",
                achievementKey: islandKey,
                achievementID: "global_first_critter",
                scopeKindRaw: AchievementScopeKind.island.rawValue,
                scopeIDRaw: AchievementScopeReference.islandID,
                recipientHumanIDRaw: human.id.uuidString,
                claimedAt: Date(),
                awardedCoconutAmount: 10,
                awardedStardustAmount: 20,
                walletTransactionKey: "achievement:\(islandKey)"
            )
        )
        context.insert(
            AchievementUnlock(
                achievementKey: humanKey,
                achievementID: "human_first_record",
                scopeKindRaw: AchievementScopeKind.human.rawValue,
                scopeIDRaw: human.id.uuidString,
                unlockedAt: Date()
            )
        )
        let safeHumanKey = AchievementScopeReference.human(human.id).achievementKey(for: "human_profile_ready")
        context.insert(
            AchievementUnlock(
                achievementKey: safeHumanKey,
                achievementID: "human_profile_ready",
                scopeKindRaw: AchievementScopeKind.human.rawValue,
                scopeIDRaw: human.id.uuidString,
                unlockedAt: Date()
            )
        )
        context.insert(
            AchievementRewardReceipt(
                receiptKey: "achievement-reward:\(safeHumanKey)",
                achievementKey: safeHumanKey,
                achievementID: "human_profile_ready",
                scopeKindRaw: AchievementScopeKind.human.rawValue,
                scopeIDRaw: human.id.uuidString,
                recipientHumanIDRaw: human.id.uuidString,
                claimedAt: Date(),
                awardedCoconutAmount: 10,
                awardedStardustAmount: 0,
                walletTransactionKey: "achievement:\(safeHumanKey)"
            )
        )
        try context.save()

        let manager = DataBackupManager(defaults: defaults)
        let backup = try manager.buildBackup(context: context)
        #expect(backup.schemaVersion == 33)
        #expect(Set(backup.achievementUnlocks?.map(\.achievementKey) ?? []) == [islandKey, safeHumanKey])
        #expect(Set(backup.achievementRewardReceipts?.map(\.achievementKey) ?? []) == [islandKey, safeHumanKey])
        #expect(backup.achievementUnlocks?.contains { $0.achievementKey == humanKey } == false)

        let target = try makeContainer()
        for _ in 0 ..< 2 {
            try manager.applyBackup(
                backup,
                context: target.mainContext,
                projectionManager: nil,
                schedulePlantNotifications: false
            )
        }
        #expect(try target.mainContext.fetch(FetchDescriptor<AchievementUnlock>()).count == 2)
        #expect(try target.mainContext.fetch(FetchDescriptor<AchievementRewardReceipt>()).count == 2)
        let restoredLedger = try target.mainContext.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(!restoredLedger.contains { $0.transactionKey == "achievement:\(islandKey)" })
        let restoredFragments = try target.mainContext.fetch(FetchDescriptor<OasisCritterFragmentBalance>())
        #expect(!restoredFragments.contains { $0.catalogId == OasisCompanionCurrency.stardustCatalogID })
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV94.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: ArkMigrationPlan.self, configurations: [configuration])
    }
}
