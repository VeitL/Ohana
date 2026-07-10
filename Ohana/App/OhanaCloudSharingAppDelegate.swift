//
//  OhanaCloudSharingAppDelegate.swift
//  Ohana
//
//  Handles system CloudKit share acceptance outside the SwiftUI route tree.
//

import SwiftData
import UIKit

#if OHANA_FAMILY_CAPABILITIES
import CloudKit
#endif

final class OhanaCloudSharingAppDelegate: NSObject, UIApplicationDelegate {
#if OHANA_FAMILY_CAPABILITIES
    private var modelContainer: ModelContainer?
    private var cloudSync: (any CloudSyncManaging)?
    private var accountChangedObserver: NSObjectProtocol?
    private let shareService = CloudSyncHouseholdShareService()
#endif

    @MainActor
    func configure(
        modelContainer: ModelContainer,
        cloudSync: any CloudSyncManaging
    ) {
#if OHANA_FAMILY_CAPABILITIES
        guard AppCapabilityProfile.permitsCloudSyncRuntime else { return }
        self.modelContainer = modelContainer
        self.cloudSync = cloudSync
        startObservingCloudKitAccountChanges()
#else
        _ = modelContainer
        _ = cloudSync
#endif
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
#if OHANA_FAMILY_CAPABILITIES
        if AppCapabilityProfile.permitsCloudSyncRuntime {
            application.registerForRemoteNotifications()
        }
#endif
        return true
    }

#if OHANA_FAMILY_CAPABILITIES
    func application(
        _: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        guard OnlineFeatureGate.allows(.onlineCollaboration) else {
            Task { @MainActor in
                OnlineFeatureGateNoticeCenter.post(.cloudShareInviteBlocked)
            }
            OhanaLog.info(
                "Cloud sync share acceptance blocked by OnlineFeatureGate.",
                category: "CloudSync"
            )
            return
        }

        Task { @MainActor in
            guard let modelContainer else { return }
            do {
                let share = try await shareService.acceptShare(metadata: cloudKitShareMetadata)
                let context = ModelContext(modelContainer)
                guard let householdId = try CloudSyncAcceptedShareStateUpdater.markAcceptedShare(share, context: context) else {
                    OhanaLog.warning(
                        "Cloud sync ignored a CloudKit share that was not an Ohana household share.",
                        category: "CloudSync"
                    )
                    return
                }
                let summary = try CloudSyncInitialHouseholdMergeRuntime.stageLocalSnapshotForHouseholdShare(
                    householdId: householdId,
                    context: context
                )
                OhanaLog.info(
                    "Cloud sync staged \(summary.stagedRecordCount) local records after accepting household share",
                    category: "CloudSync"
                )
                try Self.saveCloudShareAcceptanceChanges(context: context)

                cloudSync?.setEnabled(true)
                cloudSync?.setDatabaseScope(
                    .sharedCloudDatabase,
                    zoneOwnerName: share.recordID.zoneID.ownerName
                )
                cloudSync?.clearSharedZoneAccessRevokedNotice()
                await cloudSync?.startIfNeeded(modelContainer: modelContainer)
                _ = await cloudSync?.registerDirtyLocalChanges()
                await cloudSync?.sendPendingLocalChanges()
                await cloudSync?.fetchRemoteChanges()
            } catch {
                OhanaLog.error("Cloud sync failed to accept household share: \(error)", category: "CloudSync")
            }
        }
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard shouldHandleCloudSyncRemoteNotification(userInfo) else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            guard let modelContainer, let cloudSync else {
                completionHandler(.failed)
                return
            }
            let result = await cloudSync.handleRemoteNotification(modelContainer: modelContainer)
            completionHandler(backgroundFetchResult(for: result))
        }
    }

    private func shouldHandleCloudSyncRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return false
        }
        return notification.subscriptionID == CloudSyncEngineRuntime.defaultSubscriptionID
    }

    private func backgroundFetchResult(for result: CloudSyncRemoteNotificationResult) -> UIBackgroundFetchResult {
        switch result {
        case .ignored:
            .noData
        case .fetched:
            .newData
        case .failed:
            .failed
        }
    }

    private func startObservingCloudKitAccountChanges() {
        guard accountChangedObserver == nil else { return }
        accountChangedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CKAccountChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleCloudKitAccountChanged()
            }
        }
    }

    @MainActor
    private func handleCloudKitAccountChanged() async {
        guard let modelContainer, let cloudSync else { return }
        let availability = await CloudSyncAccountPreflight.availability()
        let result = await cloudSync.handleAccountChanged(
            availability: availability,
            modelContainer: modelContainer
        )
        logCloudKitAccountChangeResult(result)
    }

    private func logCloudKitAccountChangeResult(_ result: CloudSyncAccountChangeResult) {
        switch result {
        case .ignored:
            break
        case .resynced:
            OhanaLog.info("Cloud sync restarted after iCloud account changed.", category: "CloudSync")
        case .failed:
            OhanaLog.warning("Cloud sync could not restart after iCloud account changed.", category: "CloudSync")
        case let .paused(reason):
            OhanaLog.warning(
                "Cloud sync paused after iCloud account changed: \(reason).",
                category: "CloudSync"
            )
        }
    }

    private static func saveCloudShareAcceptanceChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw OhanaCloudSharingPersistenceError.persistenceFailed(saveResult.errorDescription)
        }
    }
#endif
}

#if OHANA_FAMILY_CAPABILITIES
enum OhanaCloudSharingPersistenceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "cloud.share.accept.persistence.failed",
                defaultValue: "Unable to save the accepted shared household.",
                comment: "Shown when accepting a shared CloudKit household cannot be saved."
            )
        }
    }
}
#endif
