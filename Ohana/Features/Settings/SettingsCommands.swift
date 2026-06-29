//
//  SettingsCommands.swift
//  Ohana
//
//  Domain write boundaries for settings mutations.
//

import Foundation
import SwiftData

struct SettingsActiveHumanSwitchCommandResult: Equatable {
    let humanID: UUID
    let didSyncHomeStack: Bool
    let updatedHomeCardOrderRaw: String
}

struct SettingsCoconutBalanceCommandResult: Equatable {
    let humanID: UUID?
    let amount: Int
    let legacyDelta: Int
}

struct SettingsPetCoconutBalanceCommandResult: Equatable {
    let petID: UUID
    let amount: Int
    let delta: Int
    let didApply: Bool
}

enum SettingsCommandService {
    @discardableResult
    @MainActor
    static func syncHomeCardStackAfterActiveHumanSwitch(
        from oldHumanIdRaw: String,
        to human: Human,
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        context: ModelContext
    ) -> SettingsActiveHumanSwitchCommandResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .presentationPreference).writesContent else {
            return SettingsActiveHumanSwitchCommandResult(
                humanID: human.id,
                didSyncHomeStack: false,
                updatedHomeCardOrderRaw: homeCardOrderRaw
            )
        }
        var updatedOrderRaw = homeCardOrderRaw
        let didChange = HomeActiveHumanCardSync.applyAfterAccountSwitch(
            from: oldHumanIdRaw,
            to: human,
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: &updatedOrderRaw
        )
        if didChange {
            context.safeSave()
        }
        return SettingsActiveHumanSwitchCommandResult(
            humanID: human.id,
            didSyncHomeStack: didChange,
            updatedHomeCardOrderRaw: updatedOrderRaw
        )
    }

    @discardableResult
    @MainActor
    static func applyCoconutBalanceTest(
        amount rawAmount: Int,
        human: Human?,
        title _: String,
        actorName: String?,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        projectionManager: QuestManager,
        updatesProjection: Bool = true
    ) -> SettingsCoconutBalanceCommandResult {
        let amount = max(0, rawAmount)
        let current = if let human {
            wallet.balance(for: human, context: context)
        } else {
            wallet.legacySystemBalance(
                context: context,
                fallback: wallet.totalBalance(context: context)
            )
        }
        if let human, !EconomyWalletWritePolicy.canWrite(human) {
            return SettingsCoconutBalanceCommandResult(
                humanID: human.id,
                amount: current,
                legacyDelta: 0
            )
        }
        let delta = amount - current
        let displayName = actorName ?? human?.name ?? "Legacy island total"
        // Developer overrides must not create wallet ledger entries or reward feedback.
        wallet.setDeveloperOverrideBalance(
            amount: amount,
            for: human,
            displayName: displayName,
            context: context
        )
        context.safeSave()
        if updatesProjection {
            projectionManager.replaceCoconutProjection(
                count: amount,
                logs: projectionManager.coconutLogs
            )
        }

        return SettingsCoconutBalanceCommandResult(
            humanID: human?.id,
            amount: amount,
            legacyDelta: delta
        )
    }

    @discardableResult
    @MainActor
    static func applyPetCoconutBalanceTest(
        amount rawAmount: Int,
        pet: Pet,
        actorName: String?,
        context: ModelContext,
        wallet: CoconutWalletManaging
    ) -> SettingsPetCoconutBalanceCommandResult {
        let current = wallet.balance(for: pet, context: context)
        guard EconomyWalletWritePolicy.canWrite(pet) else {
            return SettingsPetCoconutBalanceCommandResult(
                petID: pet.id,
                amount: current,
                delta: 0,
                didApply: false
            )
        }

        let amount = max(0, rawAmount)
        let delta = amount - current
        CoconutWalletService.setDeveloperOverrideBalance(
            amount: amount,
            for: pet,
            displayName: actorName ?? pet.name,
            context: context
        )
        context.safeSave()

        return SettingsPetCoconutBalanceCommandResult(
            petID: pet.id,
            amount: amount,
            delta: delta,
            didApply: true
        )
    }
}

@MainActor
struct SettingsCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let wallet: CoconutWalletManaging
    let questManager: QuestManager

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: QuestManager()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: QuestManager()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            wallet: services.coconutWallet,
            questManager: services.questManager
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        wallet: CoconutWalletManaging,
        questManager: QuestManager
    ) {
        self.context = context
        self.revisions = revisions
        self.wallet = wallet
        self.questManager = questManager
    }

    @discardableResult
    func syncHomeCardStackAfterActiveHumanSwitch(
        from oldHumanIdRaw: String,
        to human: Human,
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        note: String
    ) -> SettingsActiveHumanSwitchCommandResult {
        let result = SettingsCommandService.syncHomeCardStackAfterActiveHumanSwitch(
            from: oldHumanIdRaw,
            to: human,
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            context: context
        )
        revisions.publishSettingsActiveHumanSwitch(result, note: note)
        return result
    }

    @discardableResult
    func applyCoconutBalanceTest(
        amount: Int,
        human: Human?,
        title: String,
        actorName: String?,
        note: String,
        updatesProjection: Bool = true,
        publishesRevision: Bool = true
    ) -> SettingsCoconutBalanceCommandResult {
        let result = SettingsCommandService.applyCoconutBalanceTest(
            amount: amount,
            human: human,
            title: title,
            actorName: actorName,
            context: context,
            wallet: wallet,
            projectionManager: questManager,
            updatesProjection: updatesProjection
        )
        if publishesRevision {
            revisions.publishSettingsCoconutBalance(result, note: note)
        }
        return result
    }

    @discardableResult
    func applyPetCoconutBalanceTest(
        amount: Int,
        pet: Pet,
        actorName: String?,
        note _: String
    ) -> SettingsPetCoconutBalanceCommandResult {
        SettingsCommandService.applyPetCoconutBalanceTest(
            amount: amount,
            pet: pet,
            actorName: actorName,
            context: context,
            wallet: wallet
        )
    }
}
