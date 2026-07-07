//
//  DomainGeneralRehydrateWriter+Lookup.swift
//  Ohana
//
//  Fetch helpers for the general rehydrate writer.
//

import Foundation
import SwiftData

extension DomainGeneralRehydrateWriter {
    nonisolated static func fetchHousehold(id: UUID, context: ModelContext) throws -> Household? {
        var descriptor = FetchDescriptor<Household>(predicate: #Predicate<Household> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchPet(id: UUID, context: ModelContext) throws -> Pet? {
        var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchHuman(id: UUID, context: ModelContext) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchPlant(id: UUID, context: ModelContext) throws -> Plant? {
        var descriptor = FetchDescriptor<Plant>(predicate: #Predicate<Plant> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchPetRelationship(id: UUID, context: ModelContext) throws -> PetRelationship? {
        var descriptor = FetchDescriptor<PetRelationship>(predicate: #Predicate<PetRelationship> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchWaterLog(id: UUID, context: ModelContext) throws -> WaterLog? {
        var descriptor = FetchDescriptor<WaterLog>(predicate: #Predicate<WaterLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchWishlistItem(id: UUID, context: ModelContext) throws -> WishlistItem? {
        var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate<WishlistItem> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchCoconutAccount(id: UUID, context: ModelContext) throws -> CoconutAccount? {
        var descriptor = FetchDescriptor<CoconutAccount>(predicate: #Predicate<CoconutAccount> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchCoconutLedgerEntry(id: UUID, context: ModelContext) throws -> CoconutLedgerEntry? {
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(predicate: #Predicate<CoconutLedgerEntry> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchEconomyBudgetUsageEvent(
        id: UUID,
        context: ModelContext
    ) throws -> EconomyBudgetUsageEvent? {
        var descriptor = FetchDescriptor<EconomyBudgetUsageEvent>(
            predicate: #Predicate<EconomyBudgetUsageEvent> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchFamilyCollaborationTask(id: UUID, context: ModelContext) throws -> FamilyCollaborationTask? {
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(predicate: #Predicate<FamilyCollaborationTask> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchCoconutExchangeRequest(id: UUID, context: ModelContext) throws -> CoconutExchangeRequest? {
        var descriptor = FetchDescriptor<CoconutExchangeRequest>(predicate: #Predicate<CoconutExchangeRequest> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchOasisUpgradeCoconut(id: UUID, context: ModelContext) throws -> OasisUpgradeCoconut? {
        var descriptor = FetchDescriptor<OasisUpgradeCoconut>(predicate: #Predicate<OasisUpgradeCoconut> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchOasisElectronicPet(id: UUID, context: ModelContext) throws -> OasisElectronicPet? {
        var descriptor = FetchDescriptor<OasisElectronicPet>(predicate: #Predicate<OasisElectronicPet> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchOasisCritterFragment(id: UUID, context: ModelContext) throws -> OasisCritterFragmentBalance? {
        var descriptor = FetchDescriptor<OasisCritterFragmentBalance>(
            predicate: #Predicate<OasisCritterFragmentBalance> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchOasisUnlock(id: UUID, context: ModelContext) throws -> OasisUnlock? {
        var descriptor = FetchDescriptor<OasisUnlock>(predicate: #Predicate<OasisUnlock> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchOasisCritterActionLog(id: UUID, context: ModelContext) throws -> OasisCritterActionLog? {
        var descriptor = FetchDescriptor<OasisCritterActionLog>(predicate: #Predicate<OasisCritterActionLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchGachaOwnedItem(id: UUID, context: ModelContext) throws -> GachaOwnedItem? {
        var descriptor = FetchDescriptor<GachaOwnedItem>(predicate: #Predicate<GachaOwnedItem> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchGachaDrawLog(id: UUID, context: ModelContext) throws -> GachaDrawLog? {
        var descriptor = FetchDescriptor<GachaDrawLog>(predicate: #Predicate<GachaDrawLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchShopPurchaseRecord(id: UUID, context: ModelContext) throws -> ShopPurchaseRecord? {
        var descriptor = FetchDescriptor<ShopPurchaseRecord>(predicate: #Predicate<ShopPurchaseRecord> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func fetchShopPurchaseRecord(transactionKey: String, context: ModelContext) throws -> ShopPurchaseRecord? {
        let trimmed = transactionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var descriptor = FetchDescriptor<ShopPurchaseRecord>(
            predicate: #Predicate<ShopPurchaseRecord> { $0.transactionKey == trimmed }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
