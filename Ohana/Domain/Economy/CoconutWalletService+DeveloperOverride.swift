//
//  CoconutWalletService+DeveloperOverride.swift
//  Ohana
//
//  Developer-only balance adjustments, replayable without care rewards or feedback.
//

import Foundation
import SwiftData

#if DEBUG
extension CoconutWalletService {
    static func setDeveloperOverrideBalance(
        amount rawAmount: Int,
        for human: Human?,
        displayName: String,
        context: ModelContext
    ) throws {
        let amount = max(0, rawAmount)
        let accountKey = human.map { CoconutAccountKey.human($0.id) } ?? CoconutAccountKey.legacySystem
        let ownerKind: CoconutWalletOwnerKind = human == nil ? .system : .human
        let ownerId = human?.id.uuidString ?? ""
        let now = Date()
        let replayedBalance = try replayedBalance(accountKey: accountKey, context: context)

        if let account = try account(accountKey: accountKey, context: context) {
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

        human?.coconutBalance = amount
        stageDeveloperAdjustment(
            accountKey: accountKey, ownerKind: ownerKind, ownerId: ownerId,
            displayName: displayName, balanceBefore: replayedBalance, balanceAfter: amount,
            context: context
        )
    }

    static func setDeveloperOverrideBalance(
        amount rawAmount: Int,
        for pet: Pet,
        displayName: String,
        context: ModelContext
    ) throws {
        let amount = max(0, rawAmount)
        let accountKey = CoconutAccountKey.pet(pet.id)
        let now = Date()
        let replayedBalance = try replayedBalance(accountKey: accountKey, context: context)

        if let account = try account(accountKey: accountKey, context: context) {
            account.ownerKindRaw = CoconutWalletOwnerKind.pet.rawValue
            account.ownerId = pet.id.uuidString
            account.displayName = displayName
            account.balance = amount
            account.updatedAt = now
        } else {
            context.insert(CoconutAccount(
                accountKey: accountKey,
                ownerKind: .pet,
                ownerId: pet.id.uuidString,
                displayName: displayName,
                balance: amount,
                createdAt: now,
                updatedAt: now,
                metadataJSON: "{\"source\":\"settings.coconut.test\"}"
            ))
        }

        pet.coconutBalance = amount
        stageDeveloperAdjustment(
            accountKey: accountKey, ownerKind: .pet, ownerId: pet.id.uuidString,
            displayName: displayName, balanceBefore: replayedBalance, balanceAfter: amount,
            context: context
        )
    }

    private static func account(accountKey: String, context: ModelContext) throws -> CoconutAccount? {
        var descriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == accountKey }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func replayedBalance(accountKey: String, context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<CoconutLedgerEntry>(predicate: #Predicate {
            $0.accountKey == accountKey && $0.affectsBalance
        })
        return try context.fetch(descriptor).reduce(0) { $0 + $1.delta }
    }

    private static func stageDeveloperAdjustment(
        accountKey: String, ownerKind: CoconutWalletOwnerKind, ownerId: String,
        displayName: String, balanceBefore: Int, balanceAfter: Int, context: ModelContext
    ) {
        let delta = balanceAfter - balanceBefore
        guard delta != 0 else { return }
        // Use the ledger total, rather than the mutable account cache, so an
        // earlier unlogged Debug override is repaired too. The settings command
        // commits this adjustment, account and member cache together.
        let entry = CoconutLedgerEntry(
            transactionKey: "settings.coconut.test:\(UUID().uuidString)",
            accountKey: accountKey, ownerKind: ownerKind, ownerId: ownerId, ownerName: displayName,
            delta: delta, balanceBefore: balanceBefore, balanceAfter: balanceAfter,
            entryKind: .adjustment, source: .service,
            title: L10n(AppLanguage.code).tr(
                zh: "调试余额调整", en: "Debug balance adjustment", de: "Debug-Kontostand anpassen",
                es: "Ajuste de saldo de depuración", pt: "Ajuste de saldo de depuração",
                fr: "Ajustement du solde de débogage", ja: "デバッグ残高調整",
                ko: "디버그 잔액 조정", it: "Rettifica saldo di debug"
            ),
            emoji: "🛠️",
            sourceModelName: "SettingsCoconutBalanceTest",
            metadataJSON: "{\"source\":\"settings.coconut.test\",\"debug\":true}"
        )
        context.insert(entry)
        CloudSyncMutationRecorder.markModified([entry], context: context)
    }
}
#endif
