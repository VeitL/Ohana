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
        projectionManager: QuestManager
    ) -> SettingsCoconutBalanceCommandResult {
        let amount = max(0, rawAmount)
        let accountKey = human.map { CoconutAccountKey.human($0.id) } ?? CoconutAccountKey.legacySystem
        let existingAccount = coconutAccount(accountKey: accountKey, context: context)
        let current = existingAccount?.balance ?? human?.coconutBalance ?? wallet.totalBalance(context: context)
        let delta = amount - current
        let displayName = actorName ?? human?.name ?? "Legacy island total"
        // Developer overrides must not create wallet ledger entries or reward feedback.
        upsertCoconutAccount(
            accountKey: accountKey,
            ownerKind: human == nil ? .system : .human,
            ownerId: human?.id.uuidString ?? "",
            displayName: displayName,
            amount: amount,
            context: context
        )
        human?.coconutBalance = amount
        context.safeSave()
        projectionManager.replaceCoconutProjection(
            count: amount,
            logs: projectionManager.coconutLogs
        )

        return SettingsCoconutBalanceCommandResult(
            humanID: human?.id,
            amount: amount,
            legacyDelta: delta
        )
    }

    private static func coconutAccount(accountKey: String, context: ModelContext) -> CoconutAccount? {
        var descriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == accountKey }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func upsertCoconutAccount(
        accountKey: String,
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        displayName: String,
        amount: Int,
        context: ModelContext
    ) {
        let now = Date()
        if let account = coconutAccount(accountKey: accountKey, context: context) {
            account.ownerKindRaw = ownerKind.rawValue
            account.ownerId = ownerId
            account.displayName = displayName
            account.balance = amount
            account.updatedAt = now
        } else {
            context.insert(CoconutAccount(
                accountKey: accountKey,
                ownerKind: ownerKind,
                ownerId: ownerId,
                displayName: displayName,
                balance: amount,
                createdAt: now,
                updatedAt: now,
                metadataJSON: "{\"source\":\"settings.coconut.test\"}"
            ))
        }
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
        note: String
    ) -> SettingsCoconutBalanceCommandResult {
        let result = SettingsCommandService.applyCoconutBalanceTest(
            amount: amount,
            human: human,
            title: title,
            actorName: actorName,
            context: context,
            wallet: wallet,
            projectionManager: questManager
        )
        revisions.publishSettingsCoconutBalance(result, note: note)
        return result
    }
}
