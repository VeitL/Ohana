//
//  OhanaCloudSharingAppDelegate.swift
//  Ohana
//
//  Handles system CloudKit share acceptance outside the SwiftUI route tree.
//

import CloudKit
import SwiftData
import UIKit

final class OhanaCloudSharingAppDelegate: NSObject, UIApplicationDelegate {
    private var modelContainer: ModelContainer?
    private var cloudSync: (any CloudSyncManaging)?
    private var accountChangedObserver: NSObjectProtocol?
    #if !OHANA_LOCAL_DEVICE
        private let shareService = CloudSyncHouseholdShareService()
    #endif

    @MainActor
    func configure(
        modelContainer: ModelContainer,
        cloudSync: any CloudSyncManaging
    ) {
        self.modelContainer = modelContainer
        self.cloudSync = cloudSync
        #if !OHANA_LOCAL_DEVICE
            startObservingCloudKitAccountChanges()
        #endif
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if !OHANA_LOCAL_DEVICE
            application.registerForRemoteNotifications()
        #endif
        return true
    }

    func application(
        _: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        guard OnlineFeatureGate.allows(.onlineCollaboration) else {
            OnlineFeatureGateNoticeCenter.post(.cloudShareInviteBlocked)
            OhanaLog.info(
                "Cloud sync share acceptance blocked by OnlineFeatureGate.",
                category: "CloudSync"
            )
            return
        }

        #if OHANA_LOCAL_DEVICE
            OhanaLog.info(
                "Cloud sync share acceptance skipped in local device build.",
                category: "CloudSync"
            )
        #else
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
                    try context.save()

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
        #endif
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        #if OHANA_LOCAL_DEVICE
            completionHandler(.noData)
        #else
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
        #endif
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
}
