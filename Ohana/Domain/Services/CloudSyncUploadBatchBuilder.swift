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
        try states.map { state in
            if state.isDeleted {
                return try CloudSyncRecordSerializer.tombstonePayload(for: state)
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
            return try CloudSyncRecordSerializer.payload(for: model, state: state)
        }
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
        case String(describing: PetCareLog.self):
            try fetchPetCareLog(id: localRecordId, context: context)
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

    private static func fetchPetCareLog(id: UUID, context: ModelContext) throws -> PetCareLog? {
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { $0.id == id }
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
