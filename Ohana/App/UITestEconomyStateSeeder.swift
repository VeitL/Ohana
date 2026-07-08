//
//  UITestEconomyStateSeeder.swift
//  Ohana
//
//  DEBUG-only launch seeding for economy UI tests.
//

import Foundation
import SwiftData

#if DEBUG
@MainActor
enum UITestEconomyStateSeeder {
    private static var didResetEconomyBudget = false
    private static var didUnlockRewardTier = false
    private static var seededHumanIDs: Set<UUID> = []
    private static var seededPetIDs: Set<UUID> = []

    @discardableResult
    static func applyIfRequested(
        modelContext: ModelContext,
        services: AppServices,
        currentActiveHumanId: String,
        revisionNote: String
    ) -> UUID? {
        guard OhanaUITestLaunchOptions.isRunningUITests else { return nil }

        if OhanaUITestLaunchOptions.requestsEconomyBudgetReset {
            resetEconomyBudgetIfNeeded(modelContext: modelContext)
        }

        if OhanaUITestLaunchOptions.requestsRewardTierUnlock {
            unlockRewardTierIfNeeded(services: services)
        }

        guard let amount = OhanaUITestLaunchOptions.requestedCoconutBalanceSeedAmount else {
            return nil
        }
        return seedCoconutBalances(
            modelContext: modelContext,
            services: services,
            amount: amount,
            currentActiveHumanId: currentActiveHumanId,
            revisionNote: revisionNote
        )
    }

    @discardableResult
    static func seedCoconutBalances(
        modelContext: ModelContext,
        services: AppServices,
        amount: Int,
        currentActiveHumanId: String,
        revisionNote: String
    ) -> UUID? {
        let humans = fetchHumans(modelContext: modelContext).filter(EconomyWalletWritePolicy.canWrite)
        let pets = fetchPets(modelContext: modelContext).filter(EconomyWalletWritePolicy.canWrite)
        guard !humans.isEmpty || !pets.isEmpty else { return nil }

        let selectedHumanID = UUID(uuidString: currentActiveHumanId)
        let preferredHuman = selectedHumanID.flatMap { id in
            humans.first { $0.id == id }
        } ?? humans.first

        let executor = SettingsCommandExecutor(context: modelContext, services: services)
        for human in humans where !seededHumanIDs.contains(human.id) {
            let result = executor.applyCoconutBalanceTest(
                amount: amount,
                human: human,
                title: "UI test coconut balance seed",
                actorName: displayName(for: human, fallback: "Member"),
                note: "\(revisionNote).human",
                updatesProjection: false,
                publishesRevision: false
            )
            if result.didApply {
                seededHumanIDs.insert(human.id)
            }
        }

        for pet in pets where !seededPetIDs.contains(pet.id) {
            let result = executor.applyPetCoconutBalanceTest(
                amount: amount,
                pet: pet,
                actorName: displayName(for: pet, fallback: "Pet"),
                note: "\(revisionNote).pet"
            )
            if result.didApply {
                seededPetIDs.insert(pet.id)
            }
        }

        return preferredHuman?.id
    }

    static func resetSessionTrackingForTests() {
        didResetEconomyBudget = false
        didUnlockRewardTier = false
        seededHumanIDs.removeAll()
        seededPetIDs.removeAll()
    }

    private static func resetEconomyBudgetIfNeeded(modelContext: ModelContext) {
        guard !didResetEconomyBudget else { return }
        EconomyDailyBudgetStore.resetAllForTesting(context: modelContext)
        didResetEconomyBudget = true
    }

    private static func unlockRewardTierIfNeeded(services: AppServices) {
        guard !didUnlockRewardTier else { return }
        OasisTreeManagerRegistry.current.setEnergyForTesting(
            injectedEnergy: services.oasisTree.levelStartThreshold(forRawLevel: 6)
        )
        didUnlockRewardTier = true
    }

    private static func fetchHumans(modelContext: ModelContext) -> [Human] {
        do {
            return try modelContext.fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)])
            )
        } catch {
            OhanaLog.warning(
                "UI test economy seed failed to fetch humans: \(error.localizedDescription)",
                category: "Startup"
            )
            return []
        }
    }

    private static func fetchPets(modelContext: ModelContext) -> [Pet] {
        do {
            return try modelContext.fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)])
            )
        } catch {
            OhanaLog.warning(
                "UI test economy seed failed to fetch pets: \(error.localizedDescription)",
                category: "Startup"
            )
            return []
        }
    }

    private static func displayName(for human: Human, fallback: String) -> String {
        let trimmed = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func displayName(for pet: Pet, fallback: String) -> String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
#endif
