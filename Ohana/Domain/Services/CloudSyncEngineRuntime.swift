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

protocol CloudSyncEngineStateSerializationClearing {
    func clearStateSerialization()
}

protocol CloudSyncEngineSentRecordMarking {
    func markSavedRecords(_ records: [CKRecord]) async throws
}

protocol CloudSyncEngineFetchedRecordApplying {
    func applyFetchedRecords(_ records: [CKRecord]) async throws -> CloudSyncRecordApplySummary
}

nonisolated struct CloudSyncFetchedRecordDeletion: Equatable, Sendable {
    let recordID: CKRecord.ID
    let recordType: CKRecord.RecordType

    init(recordID: CKRecord.ID, recordType: CKRecord.RecordType) {
        self.recordID = recordID
        self.recordType = recordType
    }

    init(_ deletion: CKDatabase.RecordZoneChange.Deletion) {
        recordID = deletion.recordID
        recordType = deletion.recordType
    }
}

protocol CloudSyncEngineFetchedRecordDeletionApplying {
    func applyFetchedRecordDeletions(
        _ deletions: [CloudSyncFetchedRecordDeletion]
    ) async throws -> CloudSyncRecordApplySummary
}

@MainActor
protocol CloudSyncManaging {
    var isEnabled: Bool { get }
    var isStarted: Bool { get }
    var databaseScope: CloudSyncDatabaseScope { get }
    var hasSharedZoneAccessRevokedNotice: Bool { get }
    var hasPendingTransientRetry: Bool { get }
    var nextTransientRetryAt: Date? { get }

    func setEnabled(_ enabled: Bool)
    func setDatabaseScope(_ scope: CloudSyncDatabaseScope, zoneOwnerName: String?)
    func clearSharedZoneAccessRevokedNotice()
    func startAfterFirstRender(modelContainer: ModelContainer)
    func startIfNeeded(modelContainer: ModelContainer) async
    @discardableResult
    func registerDirtyLocalChanges() async -> CloudSyncPendingChangeSummary
    @discardableResult
    func sendPendingLocalChanges() async -> Bool
    @discardableResult
    func fetchRemoteChanges() async -> Bool
    func handleRemoteNotification(modelContainer: ModelContainer) async -> CloudSyncRemoteNotificationResult
    func handleAccountChanged(
        availability: CloudSyncAccountAvailability,
        modelContainer: ModelContainer
    ) async -> CloudSyncAccountChangeResult
    func retryPendingSyncNow(modelContainer: ModelContainer) async
    func cancel()
}

nonisolated enum CloudSyncEngineRuntime {
    static let containerIdentifier = "iCloud.HT.Ohana"
    static let defaultSubscriptionID = "ohana-cloud-sync-engine"
    static let enabledDefaultsKey = "ohana_cloud_sync_enabled"
    static let databaseScopeDefaultsKey = "ohana_cloud_sync_database_scope"
    static let sharedZoneOwnerNameDefaultsKey = "ohana_cloud_sync_shared_zone_owner_name"
    static let sharedZoneAccessRevokedDefaultsKey = "ohana_cloud_sync_shared_zone_access_revoked"
    static let retryAttemptDefaultsKey = "ohana_cloud_sync_retry_attempt"
    static let nextRetryAtDefaultsKey = "ohana_cloud_sync_next_retry_at"
    static let retryOperationDefaultsKey = "ohana_cloud_sync_retry_operation"
    static let firstRenderStartDelayMilliseconds: UInt64 = 6000
    static let retryBaseDelaySeconds: TimeInterval = 5
    static let retryMaxDelaySeconds: TimeInterval = 300
}

nonisolated enum CloudSyncDatabaseScope: String, Codable, Sendable {
    case privateCloudDatabase
    case sharedCloudDatabase

    func database(in container: CKContainer) -> CKDatabase {
        switch self {
        case .privateCloudDatabase:
            container.privateCloudDatabase
        case .sharedCloudDatabase:
            container.sharedCloudDatabase
        }
    }
}

nonisolated struct CloudSyncPendingChangeSummary: Equatable {
    static let empty = CloudSyncPendingChangeSummary(databaseChanges: 0, recordZoneChanges: 0)

    let databaseChanges: Int
    let recordZoneChanges: Int

    var hasChanges: Bool {
        databaseChanges > 0 || recordZoneChanges > 0
    }
}

nonisolated enum CloudSyncRemoteNotificationResult: Equatable {
    case ignored
    case fetched
    case failed
}

nonisolated enum CloudSyncAccountChangeResult: Equatable {
    case ignored
    case paused(CloudSyncAccountUnavailableReason)
    case resynced
    case failed
}

nonisolated enum CloudSyncNestedErrorScanner {
    static func errors(from value: Any) -> [Error] {
        if let nested = value as? Error {
            return [nested]
        }
        return keyedErrors(from: value).map(\.1)
    }

    static func keyedErrors(from value: Any) -> [(AnyHashable, Error)] {
        if let nested = value as? [AnyHashable: Error] {
            return nested.map { ($0.key, $0.value) }
        }
        if let nested = value as? [CKRecord.ID: Error] {
            return nested.map { (AnyHashable($0.key), $0.value) }
        }
        if let nested = value as? [AnyHashable: Any] {
            return nested.compactMap { key, value in
                guard let error = value as? Error else { return nil }
                return (key, error)
            }
        }
        return []
    }
}

nonisolated enum CloudSyncSharedZoneAccessFailureClassifier {
    private static let accessLossCodes: Set<CKError.Code> = [
        .permissionFailure,
        .userDeletedZone,
        .zoneNotFound
    ]

    static func isSharedZoneAccessLoss(_ error: Error) -> Bool {
        if let ckError = error as? CKError {
            return isSharedZoneAccessLoss(ckError)
        }

        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain,
           let code = CKError.Code(rawValue: nsError.code),
           accessLossCodes.contains(code) {
            return true
        }

        return nsError.userInfo.values.contains { value in
            CloudSyncNestedErrorScanner.errors(from: value)
                .contains(where: isSharedZoneAccessLoss)
        }
    }

    private static func isSharedZoneAccessLoss(_ error: CKError) -> Bool {
        if accessLossCodes.contains(error.code) {
            return true
        }
        guard error.code == .partialFailure,
              let partialErrors = error.partialErrorsByItemID else {
            return false
        }
        return partialErrors.values.contains(where: isSharedZoneAccessLoss)
    }
}

nonisolated enum CloudSyncRetryOperation: String, Sendable {
    case send
    case fetch
}

nonisolated struct CloudSyncFailedRecordSaveContext {
    let recordName: String
    let error: Error
}

nonisolated enum CloudSyncServerRecordChangedResolver {
    static func serverRecord(from error: Error, matching recordName: String? = nil) -> CKRecord? {
        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain,
           CKError.Code(rawValue: nsError.code) == .serverRecordChanged,
           let serverRecord = nsError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
           matches(serverRecord, recordName: recordName) {
            return serverRecord
        }

        for (key, value) in nsError.userInfo {
            if let nested = value as? Error,
               let serverRecord = serverRecord(from: nested, matching: recordName) {
                return serverRecord
            }
            let nestedErrors = CloudSyncNestedErrorScanner.keyedErrors(from: value)
            if !nestedErrors.isEmpty,
               let serverRecord = serverRecord(
                   in: nestedErrors,
                   matching: recordName,
                   requiresKeyMatch: key == CKPartialErrorsByItemIDKey
               ) {
                return serverRecord
            }
        }
        return nil
    }

    private static func serverRecord(
        in nestedErrors: [(AnyHashable, Error)],
        matching recordName: String?,
        requiresKeyMatch: Bool
    ) -> CKRecord? {
        if let recordName {
            let matchingErrors = nestedErrors.filter { keyMatches($0.0, recordName: recordName) }
            if !matchingErrors.isEmpty {
                for (_, error) in matchingErrors {
                    if let serverRecord = serverRecord(from: error, matching: recordName) {
                        return serverRecord
                    }
                }
                return nil
            }
            if requiresKeyMatch {
                return nil
            }
        }

        for (_, error) in nestedErrors {
            if let serverRecord = serverRecord(from: error, matching: recordName) {
                return serverRecord
            }
        }
        return nil
    }

    private static func matches(_ record: CKRecord, recordName: String?) -> Bool {
        guard let recordName else { return true }
        return record.recordID.recordName == recordName
    }

    private static func keyMatches(_ key: AnyHashable, recordName: String) -> Bool {
        if let recordID = key.base as? CKRecord.ID {
            return recordID.recordName == recordName
        }
        if let string = key.base as? String {
            return string == recordName
        }
        if let nsString = key.base as? NSString {
            return nsString as String == recordName
        }
        return false
    }
}

nonisolated struct CloudSyncTransientRetryPlan: Equatable {
    let operation: CloudSyncRetryOperation
    let attempt: Int
    let delaySeconds: TimeInterval
    let nextRetryAt: Date
}

nonisolated enum CloudSyncTransientErrorRetryPolicy {
    private static let transientCodes: Set<CKError.Code> = [
        .batchRequestFailed,
        .limitExceeded,
        .networkFailure,
        .networkUnavailable,
        .requestRateLimited,
        .serviceUnavailable,
        .zoneBusy
    ]

    static func isTransient(_ error: Error) -> Bool {
        if let ckError = error as? CKError {
            return isTransient(ckError)
        }

        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain,
           let code = CKError.Code(rawValue: nsError.code),
           transientCodes.contains(code) {
            return true
        }

        return nsError.userInfo.values.contains { value in
            CloudSyncNestedErrorScanner.errors(from: value)
                .contains(where: isTransient)
        }
    }

    private static func isTransient(_ error: CKError) -> Bool {
        if transientCodes.contains(error.code) {
            return true
        }
        guard error.code == .partialFailure,
              let partialErrors = error.partialErrorsByItemID else {
            return false
        }
        return partialErrors.values.contains(where: isTransient)
    }

    static func plan(
        for error: Error,
        operation: CloudSyncRetryOperation,
        previousAttempt: Int,
        now: Date = Date()
    ) -> CloudSyncTransientRetryPlan? {
        guard isTransient(error) else { return nil }
        let attempt = min(max(previousAttempt + 1, 1), 10)
        let systemDelay = retryAfterSeconds(in: error)
        let fallbackDelay = fallbackDelaySeconds(attempt: attempt)
        let delay = min(
            max(systemDelay ?? fallbackDelay, 1),
            CloudSyncEngineRuntime.retryMaxDelaySeconds
        )
        return CloudSyncTransientRetryPlan(
            operation: operation,
            attempt: attempt,
            delaySeconds: delay,
            nextRetryAt: now.addingTimeInterval(delay)
        )
    }

    private static func fallbackDelaySeconds(attempt: Int) -> TimeInterval {
        let exponent = min(max(attempt - 1, 0), 6)
        return min(
            CloudSyncEngineRuntime.retryBaseDelaySeconds * pow(2, Double(exponent)),
            CloudSyncEngineRuntime.retryMaxDelaySeconds
        )
    }

    private static func retryAfterSeconds(in error: Error) -> TimeInterval? {
        if let ckError = error as? CKError,
           let retryAfter = ckError.retryAfterSeconds {
            return retryAfter
        }

        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain,
           let retryAfter = nsError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return retryAfter
        }
        if nsError.domain == CKError.errorDomain,
           let retryAfter = nsError.userInfo[CKErrorRetryAfterKey] as? NSNumber {
            return retryAfter.doubleValue
        }

        for value in nsError.userInfo.values {
            for error in CloudSyncNestedErrorScanner.errors(from: value) {
                if let retryAfter = retryAfterSeconds(in: error) {
                    return retryAfter
                }
            }
        }
        return nil
    }
}

nonisolated enum CloudSyncEnginePendingChangeBuilder {
    static func pendingDatabaseChanges(
        for payloads: [CloudSyncRecordPayload],
        ownerName: String = CKCurrentUserDefaultName,
        databaseScope: CloudSyncDatabaseScope = .privateCloudDatabase
    ) -> [CKSyncEngine.PendingDatabaseChange] {
        guard databaseScope == .privateCloudDatabase else {
            return []
        }
        var seenZoneNames = Set<String>()
        return payloads.compactMap { payload in
            guard seenZoneNames.insert(payload.zoneName).inserted else { return nil }
            let zoneID = CKRecordZone.ID(zoneName: payload.zoneName, ownerName: ownerName)
            return .saveZone(CKRecordZone(zoneID: zoneID))
        }
    }
}

@ModelActor
actor CloudSyncLocalStoreActor: CloudSyncEngineUploadPayloadProviding, CloudSyncEngineSentRecordMarking, CloudSyncEngineFetchedRecordApplying, CloudSyncEngineFetchedRecordDeletionApplying {
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

    func applyFetchedRecordDeletions(_ deletions: [CloudSyncFetchedRecordDeletion]) async throws -> CloudSyncRecordApplySummary {
        var summary = CloudSyncRecordApplySummary.empty
        for deletion in deletions {
            do {
                try summary.record(CloudSyncRecordApplier.applyHardDeletedRecord(
                    recordID: deletion.recordID,
                    recordType: deletion.recordType,
                    context: modelContext
                ))
            } catch {
                summary.failed += 1
                OhanaLog.warning(
                    "Cloud sync failed to apply hard deletion \(deletion.recordID.recordName): \(error)",
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
    private var retryTask: Task<Void, Never>?
    private var engine: CKSyncEngine?
    private var delegateAdapter: CloudSyncEngineDelegateAdapter?
    private var localStore: CloudSyncLocalStoreActor?

    init(
        userDefaults: UserDefaults = .standard,
        containerIdentifier: String = CloudSyncEngineRuntime.containerIdentifier,
        stateStore: (any CloudSyncEngineStateSerializationPersisting)? = nil,
        assetFileStore: CloudSyncAssetFileStore = CloudSyncAssetFileStore(),
        ownerName: String = CKCurrentUserDefaultName,
        atomicByZone: Bool = false,
        automaticallySync: Bool = true
    ) {
        self.userDefaults = userDefaults
        self.containerIdentifier = containerIdentifier
        self.stateStore = stateStore ?? UserDefaultsCloudSyncEngineStateStore(userDefaults: userDefaults)
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

    var databaseScope: CloudSyncDatabaseScope {
        guard let rawValue = userDefaults.string(forKey: CloudSyncEngineRuntime.databaseScopeDefaultsKey),
              let scope = CloudSyncDatabaseScope(rawValue: rawValue) else {
            return .privateCloudDatabase
        }
        return scope
    }

    var recordZoneOwnerName: String {
        guard databaseScope == .sharedCloudDatabase else {
            return ownerName
        }
        let persisted = userDefaults
            .string(forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return persisted.isEmpty ? ownerName : persisted
    }

    var hasSharedZoneAccessRevokedNotice: Bool {
        userDefaults.bool(forKey: CloudSyncEngineRuntime.sharedZoneAccessRevokedDefaultsKey)
    }

    var hasPendingTransientRetry: Bool {
        pendingTransientRetryPlan() != nil
    }

    var nextTransientRetryAt: Date? {
        let rawValue = userDefaults.double(forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey)
        guard rawValue > 0 else { return nil }
        return Date(timeIntervalSinceReferenceDate: rawValue)
    }

    var pendingTransientRetryOperation: CloudSyncRetryOperation? {
        guard let rawValue = userDefaults.string(forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey) else {
            return nil
        }
        return CloudSyncRetryOperation(rawValue: rawValue)
    }

    func pendingTransientRetryPlan(now: Date = Date()) -> CloudSyncTransientRetryPlan? {
        let attempt = userDefaults.integer(forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey)
        guard attempt > 0,
              let operation = pendingTransientRetryOperation,
              let nextRetryAt = nextTransientRetryAt else {
            return nil
        }
        return CloudSyncTransientRetryPlan(
            operation: operation,
            attempt: attempt,
            delaySeconds: max(nextRetryAt.timeIntervalSince(now), 0),
            nextRetryAt: nextRetryAt
        )
    }

    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: CloudSyncEngineRuntime.enabledDefaultsKey)
        if !enabled {
            clearTransientRetryState()
            cancel()
        }
    }

    func setDatabaseScope(_ scope: CloudSyncDatabaseScope, zoneOwnerName: String? = nil) {
        let previousScope = databaseScope
        let previousOwnerName = recordZoneOwnerName

        userDefaults.set(scope.rawValue, forKey: CloudSyncEngineRuntime.databaseScopeDefaultsKey)
        switch scope {
        case .privateCloudDatabase:
            userDefaults.removeObject(forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey)
        case .sharedCloudDatabase:
            let trimmed = zoneOwnerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                userDefaults.set(trimmed, forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey)
            } else {
                userDefaults.removeObject(forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey)
            }
        }

        if engine != nil, previousScope != databaseScope || previousOwnerName != recordZoneOwnerName {
            (stateStore as? any CloudSyncEngineStateSerializationClearing)?.clearStateSerialization()
            clearTransientRetryState()
            cancel()
        } else if previousScope != databaseScope || previousOwnerName != recordZoneOwnerName {
            (stateStore as? any CloudSyncEngineStateSerializationClearing)?.clearStateSerialization()
            clearTransientRetryState()
        }
    }

    func clearSharedZoneAccessRevokedNotice() {
        userDefaults.set(false, forKey: CloudSyncEngineRuntime.sharedZoneAccessRevokedDefaultsKey)
    }

    @discardableResult
    func handleSharedZoneAccessLossIfNeeded(_ error: Error) -> Bool {
        guard databaseScope == .sharedCloudDatabase,
              CloudSyncSharedZoneAccessFailureClassifier.isSharedZoneAccessLoss(error) else {
            return false
        }

        userDefaults.set(true, forKey: CloudSyncEngineRuntime.sharedZoneAccessRevokedDefaultsKey)
        OhanaLog.warning(
            "Cloud sync shared zone access was revoked; pausing shared sync and clearing shared database scope.",
            category: "CloudSync"
        )
        setEnabled(false)
        setDatabaseScope(.privateCloudDatabase, zoneOwnerName: nil)
        return true
    }

    @discardableResult
    func handleTransientSyncFailureIfNeeded(
        _ error: Error,
        operation: CloudSyncRetryOperation,
        now: Date = Date()
    ) -> Bool {
        guard let plan = CloudSyncTransientErrorRetryPolicy.plan(
            for: error,
            operation: operation,
            previousAttempt: userDefaults.integer(forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey),
            now: now
        ) else {
            return false
        }

        userDefaults.set(plan.attempt, forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey)
        userDefaults.set(plan.nextRetryAt.timeIntervalSinceReferenceDate, forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey)
        userDefaults.set(plan.operation.rawValue, forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey)
        scheduleTransientRetry(plan)
        OhanaLog.warning(
            "Cloud sync transient \(operation.rawValue) failure; retrying in \(Int(plan.delaySeconds))s.",
            category: "CloudSync"
        )
        return true
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
        let activeScope = databaseScope
        let activeOwnerName = recordZoneOwnerName
        let adapter = CloudSyncEngineDelegateAdapter(
            uploadPayloadProvider: store,
            stateStore: stateStore,
            sentRecordMarker: store,
            fetchedRecordApplier: store,
            ownerName: activeOwnerName,
            atomicByZone: atomicByZone,
            assetFileURLProvider: assetFileStore.assetFileURLProvider()
        )

        do {
            let serialization = try await stateStore.loadStateSerialization()
            let container = CKContainer(identifier: containerIdentifier)
            let database = activeScope.database(in: container)
            engine = adapter.makeEngine(
                database: database,
                stateSerialization: serialization,
                automaticallySync: automaticallySync
            )
            delegateAdapter = adapter
            localStore = store
            schedulePersistedTransientRetryIfNeeded()
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
            let activeOwnerName = recordZoneOwnerName
            let databaseChanges = CloudSyncEnginePendingChangeBuilder.pendingDatabaseChanges(
                for: payloads,
                ownerName: activeOwnerName,
                databaseScope: databaseScope
            )
            let recordChanges = CloudSyncEngineBatchBuilder.pendingSaveChanges(
                for: payloads,
                ownerName: activeOwnerName
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

    @discardableResult
    func sendPendingLocalChanges() async -> Bool {
        guard let engine else { return false }
        _ = await registerDirtyLocalChanges()
        do {
            try await engine.sendChanges()
            clearTransientRetryState()
            return true
        } catch {
            if handleSharedZoneAccessLossIfNeeded(error) {
                return false
            }
            if !handleTransientSyncFailureIfNeeded(error, operation: .send) {
                OhanaLog.error("Cloud sync failed to send local changes: \(error)", category: "CloudSync")
            }
            return false
        }
    }

    @discardableResult
    func fetchRemoteChanges() async -> Bool {
        guard let engine else { return false }
        do {
            try await engine.fetchChanges()
            clearTransientRetryState()
            return true
        } catch {
            if handleSharedZoneAccessLossIfNeeded(error) {
                return false
            }
            if !handleTransientSyncFailureIfNeeded(error, operation: .fetch) {
                OhanaLog.error("Cloud sync failed to fetch remote changes: \(error)", category: "CloudSync")
            }
            return false
        }
    }

    func handleRemoteNotification(modelContainer: ModelContainer) async -> CloudSyncRemoteNotificationResult {
        guard isEnabled else { return .ignored }
        await startIfNeeded(modelContainer: modelContainer)
        guard engine != nil else { return .failed }
        return await fetchRemoteChanges() ? .fetched : .failed
    }

    func handleAccountChanged(
        availability: CloudSyncAccountAvailability,
        modelContainer: ModelContainer
    ) async -> CloudSyncAccountChangeResult {
        guard isEnabled else { return .ignored }

        resetEngineAfterAccountChange()

        switch availability {
        case .available:
            await startIfNeeded(modelContainer: modelContainer)
            guard engine != nil else { return .failed }
            let didSend = await sendPendingLocalChanges()
            let didFetch = await fetchRemoteChanges()
            return didSend || didFetch ? .resynced : .failed
        case let .unavailable(reason):
            return .paused(reason)
        }
    }

    func retryPendingSyncNow(modelContainer: ModelContainer) async {
        retryTask?.cancel()
        retryTask = nil
        clearTransientRetryState()
        setEnabled(true)
        await startIfNeeded(modelContainer: modelContainer)
        _ = await sendPendingLocalChanges()
        _ = await fetchRemoteChanges()
    }

    func cancel() {
        startTask?.cancel()
        startTask = nil
        retryTask?.cancel()
        retryTask = nil
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

    private func scheduleTransientRetry(_ plan: CloudSyncTransientRetryPlan) {
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(plan.delaySeconds * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard let self, self.isEnabled, self.engine != nil else { return }
            switch plan.operation {
            case .send:
                _ = await self.sendPendingLocalChanges()
            case .fetch:
                _ = await self.fetchRemoteChanges()
            }
        }
    }

    private func schedulePersistedTransientRetryIfNeeded(now: Date = Date()) {
        guard retryTask == nil,
              engine != nil,
              let plan = pendingTransientRetryPlan(now: now) else {
            return
        }
        scheduleTransientRetry(plan)
    }

    private func clearTransientRetryState() {
        retryTask?.cancel()
        retryTask = nil
        userDefaults.removeObject(forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey)
        userDefaults.removeObject(forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey)
        userDefaults.removeObject(forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey)
    }

    private func resetEngineAfterAccountChange() {
        (stateStore as? any CloudSyncEngineStateSerializationClearing)?.clearStateSerialization()
        clearTransientRetryState()
        cancel()
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
            await applyFetchedRecordDeletions(changes.deletions.map(CloudSyncFetchedRecordDeletion.init))
        case let .sentRecordZoneChanges(changes):
            await markSavedRecords(changes.savedRecords)
            let resolvedRecordNames = await resolveFailedRecordSaveConflicts(
                changes.failedRecordSaves.map {
                    CloudSyncFailedRecordSaveContext(
                        recordName: $0.record.recordID.recordName,
                        error: $0.error
                    )
                }
            )
            logFailedRecordSaves(
                changes.failedRecordSaves,
                resolvedRecordNames: resolvedRecordNames
            )
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

    private func applyFetchedRecordDeletions(_ deletions: [CloudSyncFetchedRecordDeletion]) async {
        guard !deletions.isEmpty else { return }
        guard let deletionApplier = fetchedRecordApplier as? any CloudSyncEngineFetchedRecordDeletionApplying else {
            logFetchedRecordDeletions(deletions)
            return
        }
        do {
            let summary = try await deletionApplier.applyFetchedRecordDeletions(deletions)
            if summary.hasMutations || summary.failed > 0 {
                OhanaLog.info(
                    "Cloud sync applied hard deletions: deleted=\(summary.deleted), unsupported=\(summary.skippedUnsupported), failed=\(summary.failed)",
                    category: "CloudSync"
                )
            }
        } catch {
            OhanaLog.error("Cloud sync failed to apply hard deletions: \(error)", category: "CloudSync")
        }
    }

    @discardableResult
    func resolveFailedRecordSaveConflicts(
        _ failures: [CloudSyncFailedRecordSaveContext]
    ) async -> Set<String> {
        guard !failures.isEmpty, let fetchedRecordApplier else { return [] }
        let serverRecordPairs = failures.compactMap { failure -> (String, CKRecord)? in
            guard let serverRecord = CloudSyncServerRecordChangedResolver.serverRecord(
                from: failure.error,
                matching: failure.recordName
            ),
                serverRecord[CloudSyncRecordFieldKey.recordKey] as? String != nil else {
                return nil
            }
            return (failure.recordName, serverRecord)
        }
        guard !serverRecordPairs.isEmpty else { return [] }

        var resolvedRecordNames: Set<String> = []
        var aggregateSummary = CloudSyncRecordApplySummary.empty
        for (recordName, serverRecord) in serverRecordPairs {
            do {
                let summary = try await fetchedRecordApplier.applyFetchedRecords([serverRecord])
                aggregateSummary.inserted += summary.inserted
                aggregateSummary.updated += summary.updated
                aggregateSummary.deleted += summary.deleted
                aggregateSummary.skippedStale += summary.skippedStale
                aggregateSummary.skippedUnsupported += summary.skippedUnsupported
                aggregateSummary.failed += summary.failed
                if summary.hasMutations,
                   summary.skippedUnsupported == 0,
                   summary.failed == 0 {
                    resolvedRecordNames.insert(recordName)
                }
            } catch {
                aggregateSummary.failed += 1
                OhanaLog.error("Cloud sync failed to resolve server-record conflict for \(recordName): \(error)", category: "CloudSync")
            }
        }
        OhanaLog.info(
            "Cloud sync resolved \(resolvedRecordNames.count)/\(serverRecordPairs.count) server-record conflict(s): inserted=\(aggregateSummary.inserted), updated=\(aggregateSummary.updated), deleted=\(aggregateSummary.deleted), stale=\(aggregateSummary.skippedStale), unsupported=\(aggregateSummary.skippedUnsupported), failed=\(aggregateSummary.failed)",
            category: "CloudSync"
        )
        return resolvedRecordNames
    }

    private func logFailedRecordSaves(
        _ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave],
        resolvedRecordNames: Set<String>
    ) {
        for failure in failures {
            let recordName = failure.record.recordID.recordName
            guard !resolvedRecordNames.contains(recordName) else { continue }
            OhanaLog.warning(
                "Cloud sync failed to save \(recordName): \(failure.error.localizedDescription)",
                category: "CloudSync"
            )
        }
    }

    private func logFetchedRecordDeletions(_ deletions: [CloudSyncFetchedRecordDeletion]) {
        guard !deletions.isEmpty else { return }
        OhanaLog.warning(
            "Cloud sync received \(deletions.count) hard record deletions; Ohana expects tombstone records for model deletes.",
            category: "CloudSync"
        )
    }
}

nonisolated struct UserDefaultsCloudSyncEngineStateStore: CloudSyncEngineStateSerializationPersisting, CloudSyncEngineStateSerializationClearing {
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

    func clearStateSerialization() {
        userDefaults.removeObject(forKey: key)
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
