//
//  CloudSyncEngineRuntime.swift
//  Ohana
//
//  CKSyncEngine delegate shell for the local SwiftData sync pipeline.
//

import CloudKit
import Foundation
import SwiftData

protocol CloudSyncEngineUploadPayloadProviding {
    func uploadPayloads() async throws -> [CloudSyncRecordPayload]
}

protocol CloudSyncEngineStateSerializationPersisting {
    func loadStateSerialization() async throws -> CKSyncEngine.State.Serialization?
    func saveStateSerialization(_ serialization: CKSyncEngine.State.Serialization) async throws
}

protocol CloudSyncEngineSentRecordMarking {
    func markSavedRecords(_ records: [CKRecord]) async throws
}

protocol CloudSyncEngineFetchedRecordApplying {
    func applyFetchedRecords(_ records: [CKRecord]) async throws -> CloudSyncRecordApplySummary
}

@MainActor
protocol CloudSyncManaging {
    var isEnabled: Bool { get }
    var isStarted: Bool { get }

    func setEnabled(_ enabled: Bool)
    func startAfterFirstRender(modelContainer: ModelContainer)
    func startIfNeeded(modelContainer: ModelContainer) async
    @discardableResult
    func registerDirtyLocalChanges() async -> CloudSyncPendingChangeSummary
    func sendPendingLocalChanges() async
    func fetchRemoteChanges() async
    func cancel()
}

nonisolated enum CloudSyncEngineRuntime {
    static let containerIdentifier = "iCloud.HT.Ohana"
    static let defaultSubscriptionID = "ohana-cloud-sync-engine"
    static let enabledDefaultsKey = "ohana_cloud_sync_enabled"
    static let firstRenderStartDelayMilliseconds: UInt64 = 6000
}

nonisolated struct CloudSyncPendingChangeSummary: Equatable {
    static let empty = CloudSyncPendingChangeSummary(databaseChanges: 0, recordZoneChanges: 0)

    let databaseChanges: Int
    let recordZoneChanges: Int

    var hasChanges: Bool {
        databaseChanges > 0 || recordZoneChanges > 0
    }
}

nonisolated enum CloudSyncEnginePendingChangeBuilder {
    static func pendingDatabaseChanges(
        for payloads: [CloudSyncRecordPayload],
        ownerName: String = CKCurrentUserDefaultName
    ) -> [CKSyncEngine.PendingDatabaseChange] {
        var seenZoneNames = Set<String>()
        return payloads.compactMap { payload in
            guard seenZoneNames.insert(payload.zoneName).inserted else { return nil }
            let zoneID = CKRecordZone.ID(zoneName: payload.zoneName, ownerName: ownerName)
            return .saveZone(CKRecordZone(zoneID: zoneID))
        }
    }
}

@ModelActor
actor CloudSyncLocalStoreActor: CloudSyncEngineUploadPayloadProviding, CloudSyncEngineSentRecordMarking, CloudSyncEngineFetchedRecordApplying {
    func uploadPayloads() async throws -> [CloudSyncRecordPayload] {
        try CloudSyncUploadBatchBuilder.dirtyPayloads(context: modelContext)
    }

    func markSavedRecords(_ records: [CKRecord]) async throws {
        let updatedCount = try CloudSyncSentRecordStateUpdater.markSavedRecords(records, context: modelContext)
        guard updatedCount > 0 else { return }
        try modelContext.save()
    }

    func applyFetchedRecords(_ records: [CKRecord]) async throws -> CloudSyncRecordApplySummary {
        var summary = CloudSyncRecordApplySummary.empty
        for record in records {
            do {
                try summary.record(CloudSyncRecordApplier.apply(record, context: modelContext))
            } catch {
                summary.failed += 1
                OhanaLog.warning(
                    "Cloud sync failed to apply fetched \(record.recordID.recordName): \(error)",
                    category: "CloudSync"
                )
            }
        }
        guard summary.hasMutations else { return summary }
        try modelContext.save()
        return summary
    }
}

@MainActor
final class CloudSyncEngineService: CloudSyncManaging {
    private let userDefaults: UserDefaults
    private let containerIdentifier: String
    private let stateStore: any CloudSyncEngineStateSerializationPersisting
    private let assetFileStore: CloudSyncAssetFileStore
    private let ownerName: String
    private let atomicByZone: Bool
    private let automaticallySync: Bool
    private var startTask: Task<Void, Never>?
    private var engine: CKSyncEngine?
    private var delegateAdapter: CloudSyncEngineDelegateAdapter?
    private var localStore: CloudSyncLocalStoreActor?

    init(
        userDefaults: UserDefaults = .standard,
        containerIdentifier: String = CloudSyncEngineRuntime.containerIdentifier,
        stateStore: any CloudSyncEngineStateSerializationPersisting = UserDefaultsCloudSyncEngineStateStore(),
        assetFileStore: CloudSyncAssetFileStore = CloudSyncAssetFileStore(),
        ownerName: String = CKCurrentUserDefaultName,
        atomicByZone: Bool = false,
        automaticallySync: Bool = true
    ) {
        self.userDefaults = userDefaults
        self.containerIdentifier = containerIdentifier
        self.stateStore = stateStore
        self.assetFileStore = assetFileStore
        self.ownerName = ownerName
        self.atomicByZone = atomicByZone
        self.automaticallySync = automaticallySync
    }

    var isEnabled: Bool {
        userDefaults.bool(forKey: CloudSyncEngineRuntime.enabledDefaultsKey)
    }

    var isStarted: Bool {
        engine != nil
    }

    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: CloudSyncEngineRuntime.enabledDefaultsKey)
        if !enabled {
            cancel()
        }
    }

    func startAfterFirstRender(modelContainer: ModelContainer) {
        guard isEnabled, startTask == nil, engine == nil else { return }
        startTask = Task { @MainActor [weak self] in
            await OhanaFrameScheduler.waitAfterNextFrame(
                milliseconds: CloudSyncEngineRuntime.firstRenderStartDelayMilliseconds
            )
            guard !Task.isCancelled else { return }
            await self?.startIfNeeded(modelContainer: modelContainer)
            self?.startTask = nil
        }
    }

    func startIfNeeded(modelContainer: ModelContainer) async {
        guard isEnabled, engine == nil else { return }
        assetFileStore.pruneFiles()
        let store = CloudSyncLocalStoreActor(modelContainer: modelContainer)
        let adapter = CloudSyncEngineDelegateAdapter(
            uploadPayloadProvider: store,
            stateStore: stateStore,
            sentRecordMarker: store,
            fetchedRecordApplier: store,
            ownerName: ownerName,
            atomicByZone: atomicByZone,
            assetFileURLProvider: assetFileStore.assetFileURLProvider()
        )

        do {
            let serialization = try await stateStore.loadStateSerialization()
            let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
            engine = adapter.makeEngine(
                database: database,
                stateSerialization: serialization,
                automaticallySync: automaticallySync
            )
            delegateAdapter = adapter
            localStore = store
            OhanaLog.info("Cloud sync engine started", category: "CloudSync")
        } catch {
            OhanaLog.error("Cloud sync failed to start: \(error)", category: "CloudSync")
        }
    }

    @discardableResult
    func registerDirtyLocalChanges() async -> CloudSyncPendingChangeSummary {
        guard let engine, let localStore else { return .empty }
        do {
            let payloads = try await localStore.uploadPayloads()
            let databaseChanges = CloudSyncEnginePendingChangeBuilder.pendingDatabaseChanges(
                for: payloads,
                ownerName: ownerName
            )
            let recordChanges = CloudSyncEngineBatchBuilder.pendingSaveChanges(
                for: payloads,
                ownerName: ownerName
            )
            let newDatabaseChanges = databaseChanges.filter { !engine.state.pendingDatabaseChanges.contains($0) }
            let newRecordChanges = recordChanges.filter { !engine.state.pendingRecordZoneChanges.contains($0) }

            if !newDatabaseChanges.isEmpty {
                engine.state.add(pendingDatabaseChanges: newDatabaseChanges)
            }
            if !newRecordChanges.isEmpty {
                engine.state.add(pendingRecordZoneChanges: newRecordChanges)
            }
            return CloudSyncPendingChangeSummary(
                databaseChanges: newDatabaseChanges.count,
                recordZoneChanges: newRecordChanges.count
            )
        } catch {
            OhanaLog.error("Cloud sync failed to register dirty changes: \(error)", category: "CloudSync")
            return .empty
        }
    }

    func sendPendingLocalChanges() async {
        guard let engine else { return }
        _ = await registerDirtyLocalChanges()
        do {
            try await engine.sendChanges()
        } catch {
            OhanaLog.error("Cloud sync failed to send local changes: \(error)", category: "CloudSync")
        }
    }

    func fetchRemoteChanges() async {
        guard let engine else { return }
        do {
            try await engine.fetchChanges()
        } catch {
            OhanaLog.error("Cloud sync failed to fetch remote changes: \(error)", category: "CloudSync")
        }
    }

    func cancel() {
        startTask?.cancel()
        startTask = nil
        guard let engine else {
            delegateAdapter = nil
            localStore = nil
            return
        }
        Task { await engine.cancelOperations() }
        self.engine = nil
        delegateAdapter = nil
        localStore = nil
    }
}

final nonisolated class CloudSyncEngineDelegateAdapter: NSObject, CKSyncEngineDelegate, @unchecked Sendable {
    private let uploadPayloadProvider: any CloudSyncEngineUploadPayloadProviding
    private let stateStore: (any CloudSyncEngineStateSerializationPersisting)?
    private let sentRecordMarker: (any CloudSyncEngineSentRecordMarking)?
    private let fetchedRecordApplier: (any CloudSyncEngineFetchedRecordApplying)?
    private let ownerName: String
    private let atomicByZone: Bool
    private let assetFileURLProvider: CloudSyncRecordPayload.AssetFileURLProvider?

    init(
        uploadPayloadProvider: any CloudSyncEngineUploadPayloadProviding,
        stateStore: (any CloudSyncEngineStateSerializationPersisting)? = nil,
        sentRecordMarker: (any CloudSyncEngineSentRecordMarking)? = nil,
        fetchedRecordApplier: (any CloudSyncEngineFetchedRecordApplying)? = nil,
        ownerName: String = CKCurrentUserDefaultName,
        atomicByZone: Bool = false,
        assetFileURLProvider: CloudSyncRecordPayload.AssetFileURLProvider? = nil
    ) {
        self.uploadPayloadProvider = uploadPayloadProvider
        self.stateStore = stateStore
        self.sentRecordMarker = sentRecordMarker
        self.fetchedRecordApplier = fetchedRecordApplier
        self.ownerName = ownerName
        self.atomicByZone = atomicByZone
        self.assetFileURLProvider = assetFileURLProvider
        super.init()
    }

    func makeEngine(
        database: CKDatabase,
        stateSerialization: CKSyncEngine.State.Serialization? = nil,
        automaticallySync: Bool = true,
        subscriptionID: String = CloudSyncEngineRuntime.defaultSubscriptionID
    ) -> CKSyncEngine {
        var configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: stateSerialization,
            delegate: self
        )
        configuration.automaticallySync = automaticallySync
        configuration.subscriptionID = subscriptionID
        return CKSyncEngine(configuration)
    }

    func recordZoneChangeBatch(
        sendScope: CKSyncEngine.SendChangesOptions.Scope? = nil
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        do {
            let payloads = try await uploadPayloadProvider.uploadPayloads()
            return try CloudSyncEngineBatchBuilder.recordZoneChangeBatch(
                for: payloads,
                ownerName: ownerName,
                sendScope: sendScope,
                atomicByZone: atomicByZone,
                assetFileURLProvider: assetFileURLProvider
            )
        } catch {
            OhanaLog.error("Cloud sync failed to build send batch: \(error)", category: "CloudSync")
            return nil
        }
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine _: CKSyncEngine) async {
        switch event {
        case let .stateUpdate(update):
            await persistStateSerialization(update.stateSerialization)
        case let .fetchedRecordZoneChanges(changes):
            await applyFetchedRecords(changes.modifications.map(\.record))
            logFetchedRecordDeletions(changes.deletions)
        case let .sentRecordZoneChanges(changes):
            await markSavedRecords(changes.savedRecords)
            logFailedRecordSaves(changes.failedRecordSaves)
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine _: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await recordZoneChangeBatch(sendScope: context.options.scope)
    }

    private func persistStateSerialization(_ serialization: CKSyncEngine.State.Serialization) async {
        guard let stateStore else { return }
        do {
            try await stateStore.saveStateSerialization(serialization)
        } catch {
            OhanaLog.error("Cloud sync failed to persist engine state: \(error)", category: "CloudSync")
        }
    }

    private func markSavedRecords(_ records: [CKRecord]) async {
        guard !records.isEmpty, let sentRecordMarker else { return }
        do {
            try await sentRecordMarker.markSavedRecords(records)
        } catch {
            OhanaLog.error("Cloud sync failed to mark saved records: \(error)", category: "CloudSync")
        }
    }

    private func applyFetchedRecords(_ records: [CKRecord]) async {
        guard !records.isEmpty, let fetchedRecordApplier else { return }
        do {
            let summary = try await fetchedRecordApplier.applyFetchedRecords(records)
            if summary.hasMutations || summary.failed > 0 {
                OhanaLog.info(
                    "Cloud sync applied fetched records: inserted=\(summary.inserted), updated=\(summary.updated), deleted=\(summary.deleted), stale=\(summary.skippedStale), unsupported=\(summary.skippedUnsupported), failed=\(summary.failed)",
                    category: "CloudSync"
                )
            }
        } catch {
            OhanaLog.error("Cloud sync failed to apply fetched records: \(error)", category: "CloudSync")
        }
    }

    private func logFailedRecordSaves(
        _ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave]
    ) {
        for failure in failures {
            OhanaLog.warning(
                "Cloud sync failed to save \(failure.record.recordID.recordName): \(failure.error.localizedDescription)",
                category: "CloudSync"
            )
        }
    }

    private func logFetchedRecordDeletions(_ deletions: [CKDatabase.RecordZoneChange.Deletion]) {
        guard !deletions.isEmpty else { return }
        OhanaLog.warning(
            "Cloud sync received \(deletions.count) hard record deletions; Ohana expects tombstone records for model deletes.",
            category: "CloudSync"
        )
    }
}

nonisolated struct UserDefaultsCloudSyncEngineStateStore: CloudSyncEngineStateSerializationPersisting {
    static let defaultKey = "Ohana.CloudSyncEngine.StateSerialization"

    private let userDefaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        key: String = Self.defaultKey,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.encoder = encoder
        self.decoder = decoder
    }

    func loadStateSerialization() async throws -> CKSyncEngine.State.Serialization? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try decoder.decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    func saveStateSerialization(_ serialization: CKSyncEngine.State.Serialization) async throws {
        let data = try encoder.encode(serialization)
        userDefaults.set(data, forKey: key)
    }
}

nonisolated enum CloudSyncSentRecordStateUpdater {
    @discardableResult
    static func markSavedRecords(
        _ records: [CKRecord],
        syncedAt: Date = Date(),
        context: ModelContext
    ) throws -> Int {
        var updatedCount = 0
        for record in records {
            guard let recordKey = record[CloudSyncRecordFieldKey.recordKey] as? String,
                  let state = try CloudSyncMetadataService.state(recordKey: recordKey, context: context) else {
                continue
            }
            CloudSyncMetadataService.markSynced(
                state,
                ckRecordName: record.recordID.recordName,
                ckChangeTag: record.recordChangeTag ?? "",
                ckZoneName: record.recordID.zoneID.zoneName,
                syncedAt: syncedAt
            )
            updatedCount += 1
        }
        return updatedCount
    }
}
