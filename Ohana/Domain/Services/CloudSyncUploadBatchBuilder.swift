//
//  CloudSyncUploadBatchBuilder.swift
//  Ohana
//
//  Builds upload payloads from the local dirty sync-state queue.
//

import Foundation
import SwiftData

nonisolated enum CloudSyncUploadBatchError: LocalizedError, Equatable {
    case invalidLocalRecordId(recordKey: String, localRecordId: String)
    case missingLocalModel(entityName: String, localRecordId: String)

    var errorDescription: String? {
        switch self {
        case let .invalidLocalRecordId(recordKey, localRecordId):
            "Cloud sync state \(recordKey) has an invalid local record id: \(localRecordId)."
        case let .missingLocalModel(entityName, localRecordId):
            "\(entityName) \(localRecordId) is marked dirty, but the local model no longer exists."
        }
    }
}

nonisolated enum CloudSyncUploadBatchBuilder {
    static func dirtyPayloads(context: ModelContext) throws -> [CloudSyncRecordPayload] {
        try payloads(for: CloudSyncMetadataService.dirtyStates(context: context), context: context)
    }

    static func payloads(
        for states: [CloudSyncRecordState],
        context: ModelContext
    ) throws -> [CloudSyncRecordPayload] {
        var payloads: [CloudSyncRecordPayload] = []
        for state in states {
            guard CloudSyncEntityRegistry.descriptor(for: state.entityName)?.uploadsToCloudKit == true,
                  CloudSyncEntityRegistry.supportsUploadPipeline(for: state.entityName) else {
                continue
            }
            if state.isDeletionTombstone {
                try payloads.append(CloudSyncRecordSerializer.tombstonePayload(for: state))
                continue
            }

            guard let recordId = UUID(uuidString: state.localRecordId) else {
                throw CloudSyncUploadBatchError.invalidLocalRecordId(
                    recordKey: state.recordKey,
                    localRecordId: state.localRecordId
                )
            }
            guard let model = try localModel(
                entityName: state.entityName,
                localRecordId: recordId,
                context: context
            ) else {
                throw CloudSyncUploadBatchError.missingLocalModel(
                    entityName: state.entityName,
                    localRecordId: state.localRecordId
                )
            }
            try payloads.append(CloudSyncRecordSerializer.payload(for: model, state: state))
        }
        return payloads
    }

    private static func localModel(
        entityName: String,
        localRecordId: UUID,
        context: ModelContext
    ) throws -> Any? {
        switch CloudSyncRecordState.normalizedEntityName(entityName) {
        case String(describing: Household.self):
            try fetchHousehold(id: localRecordId, context: context)
        case String(describing: Pet.self):
            try fetchPet(id: localRecordId, context: context)
        case String(describing: Human.self):
            try fetchHuman(id: localRecordId, context: context)
        case String(describing: Event.self):
            try fetchEvent(id: localRecordId, context: context)
        case String(describing: PetCareLog.self):
            try fetchPetCareLog(id: localRecordId, context: context)
        case String(describing: PetPottyLog.self):
            try fetchPetPottyLog(id: localRecordId, context: context)
        case String(describing: PetHygieneLog.self):
            try fetchPetHygieneLog(id: localRecordId, context: context)
        case String(describing: PetHealthLog.self):
            try fetchPetHealthLog(id: localRecordId, context: context)
        case String(describing: PetWalkLog.self):
            try fetchPetWalkLog(id: localRecordId, context: context)
        case String(describing: PetExpenseLog.self):
            try fetchPetExpenseLog(id: localRecordId, context: context)
        case String(describing: PetFoodRecord.self):
            try fetchPetFoodRecord(id: localRecordId, context: context)
        case String(describing: PetWeightLog.self):
            try fetchPetWeightLog(id: localRecordId, context: context)
        case String(describing: SharedCareSession.self):
            try fetchSharedCareSession(id: localRecordId, context: context)
        case String(describing: CareLedgerEvent.self):
            try fetchCareLedgerEvent(id: localRecordId, context: context)
        case String(describing: CoconutLedgerEntry.self):
            try fetchCoconutLedgerEntry(id: localRecordId, context: context)
        default:
            nil
        }
    }

    private static func fetchHousehold(id: UUID, context: ModelContext) throws -> Household? {
        var descriptor = FetchDescriptor<Household>(
            predicate: #Predicate<Household> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPet(id: UUID, context: ModelContext) throws -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHuman(id: UUID, context: ModelContext) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchEvent(id: UUID, context: ModelContext) throws -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetCareLog(id: UUID, context: ModelContext) throws -> PetCareLog? {
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetPottyLog(id: UUID, context: ModelContext) throws -> PetPottyLog? {
        var descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetHygieneLog(id: UUID, context: ModelContext) throws -> PetHygieneLog? {
        var descriptor = FetchDescriptor<PetHygieneLog>(
            predicate: #Predicate<PetHygieneLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetHealthLog(id: UUID, context: ModelContext) throws -> PetHealthLog? {
        var descriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetWalkLog(id: UUID, context: ModelContext) throws -> PetWalkLog? {
        var descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetExpenseLog(id: UUID, context: ModelContext) throws -> PetExpenseLog? {
        var descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetFoodRecord(id: UUID, context: ModelContext) throws -> PetFoodRecord? {
        var descriptor = FetchDescriptor<PetFoodRecord>(
            predicate: #Predicate<PetFoodRecord> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetWeightLog(id: UUID, context: ModelContext) throws -> PetWeightLog? {
        var descriptor = FetchDescriptor<PetWeightLog>(
            predicate: #Predicate<PetWeightLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchSharedCareSession(id: UUID, context: ModelContext) throws -> SharedCareSession? {
        var descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchCareLedgerEvent(id: UUID, context: ModelContext) throws -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchCoconutLedgerEntry(id: UUID, context: ModelContext) throws -> CoconutLedgerEntry? {
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
