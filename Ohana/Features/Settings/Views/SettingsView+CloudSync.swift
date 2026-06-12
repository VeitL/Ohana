//
//  SettingsView+CloudSync.swift
//  Ohana
//
//  Low-frequency household sharing controls.
//

import CloudKit
import SwiftData
import SwiftUI
import UIKit

struct CloudSyncHouseholdSharePresentation: Identifiable {
    let id = UUID()
    let householdId: UUID
    let title: String
    let share: CKShare
    let container: CKContainer
}

extension SettingsView {
    @ViewBuilder
    var householdSyncSection: some View {
        if OnlineFeatureGate.allows(.onlineCollaboration) {
            settingsSection(title: l.tr(zh: "家庭同步", en: "Family Sync", de: "Familiensynchronisierung")) {
                VStack(spacing: 0) {
                    householdSyncSectionContent
                }
            }
        }
    }

    @ViewBuilder
    private var householdSyncSectionContent: some View {
        VStack(spacing: 0) {
            settingsRow(
                icon: householdHasPreparedShare ? "person.2.wave.2.fill" : "person.2.badge.plus.fill",
                title: l.tr(zh: "邀请家人加入", en: "Invite Family", de: "Familie einladen"),
                subtitle: householdShareSubtitle,
                iconColor: Color.goPrimary
            ) {
                prepareHouseholdShare()
            }
            .disabled(isPreparingHouseholdShare)

            if isPreparingHouseholdShare {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.goPrimary)
                        .scaleEffect(0.8)
                    Text(l.tr(zh: "正在准备 iCloud 分享...", en: "Preparing iCloud share...", de: "iCloud-Freigabe wird vorbereitet..."))
                        .font(OhanaFont.footnote())
                        .foregroundStyle(tertiaryText)
                    Spacer()
                }
                .padding(.leading, 44)
                .padding(.top, 8)
            }

            OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

            settingsRow(
                icon: activeHumanForCloudIdentity?.appleUserIdentifier.isEmpty == false ? "person.badge.shield.checkmark.fill" : "person.badge.key.fill",
                title: l.tr(zh: "绑定本机 iCloud 身份", en: "Bind This iCloud Identity", de: "Diese iCloud-Identität binden"),
                subtitle: cloudIdentitySubtitle,
                iconColor: Color.goTeal
            ) {
                bindCurrentCloudIdentity()
            }
            .disabled(isBindingCloudIdentity || activeHumanForCloudIdentity == nil)

            if isBindingCloudIdentity {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.goTeal)
                        .scaleEffect(0.8)
                    Text(l.tr(zh: "正在读取当前 iCloud 身份...", en: "Reading current iCloud identity...", de: "Aktuelle iCloud-Identität wird gelesen..."))
                        .font(OhanaFont.footnote())
                        .foregroundStyle(tertiaryText)
                    Spacer()
                }
                .padding(.leading, 44)
                .padding(.top, 8)
            }

            if hasCloudSyncTransientRetry, !hasCloudSyncSharedZoneAccessRevokedNotice {
                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill") // a11y: allow decorative status icon covered by adjacent text
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(Color.goTeal)
                        .accessibilityHidden(true)
                    Text(cloudSyncTransientRetryMessage)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if isRetryingCloudSyncNow {
                        ProgressView()
                            .tint(Color.goTeal)
                            .scaleEffect(0.75)
                    } else {
                        Button {
                            retryCloudSyncNow()
                        } label: {
                            Image(systemName: "arrow.clockwise") // a11y: allow button has explicit accessibilityLabel
                                .font(OhanaFont.footnote(.semibold))
                                .foregroundStyle(Color.goTeal)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel(l.tr(zh: "立即重试家庭同步", en: "Retry family sync now", de: "Familiensynchronisierung jetzt erneut versuchen"))
                    }
                }
                .padding(.leading, 44)
                .padding(.top, 4)
            }

            if hasCloudSyncSharedZoneAccessRevokedNotice {
                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.icloud.fill") // a11y: allow decorative status icon covered by adjacent text
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(Color.goOrange)
                        .accessibilityHidden(true)
                    Text(l.tr(
                        zh: "家庭共享权限已失效，同步已暂停。重新接受邀请或重新发起家庭分享后会恢复。",
                        en: "Family sharing access changed, so sync is paused. Accept a new invite or start sharing again to resume.",
                        de: "Der Zugriff auf die Familienfreigabe hat sich geändert; die Synchronisierung ist pausiert."
                    ))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button {
                        appServices.cloudSync.clearSharedZoneAccessRevokedNotice()
                        hasCloudSyncSharedZoneAccessRevokedNotice = false
                    } label: {
                        Image(systemName: "xmark.circle.fill") // a11y: allow button has explicit accessibilityLabel
                            .font(OhanaFont.footnote(.semibold))
                            .foregroundStyle(tertiaryText)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "关闭共享状态提示", en: "Dismiss sharing status notice", de: "Freigabehinweis schließen"))
                }
                .padding(.leading, 44)
                .padding(.top, 4)
            }

            if let householdSyncStatusMessage {
                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative status icon covered by adjacent text
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(Color.goPrimary)
                        .accessibilityHidden(true)
                    Text(householdSyncStatusMessage)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.leading, 44)
                .padding(.top, 4)
            }
        }
    }

    var householdHasPreparedShare: Bool {
        if hasCloudSyncSharedZoneAccessRevokedNotice {
            return false
        }
        return !(homeHouseholds?.first?.ckShareRecordName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var householdShareSubtitle: String {
        if householdHasPreparedShare {
            return l.tr(zh: "管理邀请", en: "Manage invite", de: "Einladung verwalten")
        }
        if hasCloudSyncSharedZoneAccessRevokedNotice {
            return l.tr(zh: "保留本机副本，可重新分享", en: "Local copy kept; share again to resume", de: "Lokale Kopie bleibt erhalten")
        }
        return l.tr(zh: "通过系统 iCloud 邀请", en: "Use the system iCloud invite", de: "Über iCloud-Systemeinladung")
    }

    var hasCloudSyncTransientRetry: Bool {
        cloudSyncRetryAttempt > 0 && cloudSyncNextRetryAtReferenceDate > 0
    }

    var cloudSyncTransientRetryMessage: String {
        let retryDate = Date(timeIntervalSinceReferenceDate: cloudSyncNextRetryAtReferenceDate)
        let retryTime = retryDate.formatted(date: .omitted, time: .shortened)
        if retryDate <= Date() {
            return l.tr(
                zh: "家庭同步暂时不可用，系统正在等待下一次自动重试。",
                en: "Family sync is temporarily unavailable and is waiting for the next automatic retry.",
                de: "Die Familiensynchronisierung ist vorübergehend nicht verfügbar."
            )
        }
        return l.tr(
            zh: "家庭同步暂时不可用，将在 \(retryTime) 自动重试。",
            en: "Family sync is temporarily unavailable and will retry at \(retryTime).",
            de: "Die Familiensynchronisierung wird um \(retryTime) erneut versucht."
        )
    }

    var activeHumanForCloudIdentity: Human? {
        guard let homeHumans else { return nil }
        if let activeId = UUID(uuidString: currentActiveHumanId),
           let active = homeHumans.first(where: { $0.id == activeId }) {
            return active
        }
        return homeHumans.first
    }

    var cloudIdentitySubtitle: String {
        guard let human = activeHumanForCloudIdentity else {
            return l.tr(zh: "先创建家庭成员", en: "Create a family member first", de: "Zuerst ein Familienmitglied erstellen")
        }
        if human.appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return l.tr(zh: "将本机 iCloud 关联到 \(human.name)", en: "Link this iCloud account to \(human.name)", de: "Dieses iCloud-Konto mit \(human.name) verknüpfen")
        }
        return l.tr(zh: "已关联到 \(human.name)", en: "Linked to \(human.name)", de: "Mit \(human.name) verknüpft")
    }

    func ensureCloudSyncAccountAvailable() async -> Bool {
        switch await CloudSyncAccountPreflight.availability() {
        case .available:
            return true
        case let .unavailable(reason):
            householdSyncErrorMessage = cloudSyncAccountUnavailableMessage(for: reason)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return false
        }
    }

    func cloudSyncAccountUnavailableMessage(for reason: CloudSyncAccountUnavailableReason) -> String {
        switch reason {
        case .couldNotDetermine:
            l.tr(
                zh: "暂时无法确认 iCloud 状态。请稍后再试，或在系统设置中检查 iCloud。",
                en: "Ohana cannot confirm iCloud status right now. Try again later or check iCloud in Settings.",
                de: "Ohana kann den iCloud-Status gerade nicht prüfen."
            )
        case .noAccount:
            l.tr(
                zh: "这台设备还没有登录 iCloud。请先登录 iCloud，再开启家庭同步。",
                en: "This device is not signed into iCloud. Sign in before turning on family sync.",
                de: "Dieses Gerät ist nicht bei iCloud angemeldet."
            )
        case .restricted:
            l.tr(
                zh: "这台设备的 iCloud 访问受限。请检查屏幕使用时间、家长控制或设备管理设置。",
                en: "iCloud access is restricted on this device. Check Screen Time, parental controls, or device management.",
                de: "Der iCloud-Zugriff ist auf diesem Gerät eingeschränkt."
            )
        case .temporarilyUnavailable:
            l.tr(
                zh: "iCloud 暂时不可用。请稍后重试，Ohana 会保留本机数据。",
                en: "iCloud is temporarily unavailable. Try again later; Ohana will keep local data.",
                de: "iCloud ist vorübergehend nicht verfügbar."
            )
        }
    }

    func prepareHouseholdShare() {
        guard canUseOnlineCollaborationForSettings() else { return }
        guard !isPreparingHouseholdShare else { return }
        isPreparingHouseholdShare = true
        householdSyncErrorMessage = nil
        householdSyncStatusMessage = nil

        Task { @MainActor in
            defer { isPreparingHouseholdShare = false }
            guard await ensureCloudSyncAccountAvailable() else { return }
            do {
                let household = try householdForSharing()
                CloudSyncMutationRecorder.markModified(household, context: modelContext)
                try modelContext.save()

                let shareService = CloudSyncHouseholdShareService()
                let share = try await shareService.ensureShare(
                    householdId: household.id,
                    householdName: household.name
                )
                _ = try CloudSyncHouseholdShareStateUpdater.markSharePrepared(
                    householdId: household.id,
                    share: share,
                    context: modelContext
                )
                let mergeSummary = try CloudSyncInitialHouseholdMergeRuntime.stageLocalSnapshotForHouseholdShare(
                    householdId: household.id,
                    context: modelContext
                )
                try modelContext.save()

                appServices.cloudSync.setEnabled(true)
                appServices.cloudSync.setDatabaseScope(.privateCloudDatabase, zoneOwnerName: nil)
                appServices.cloudSync.clearSharedZoneAccessRevokedNotice()
                await appServices.cloudSync.startIfNeeded(modelContainer: modelContext.container)
                await appServices.cloudSync.registerDirtyLocalChanges()
                await appServices.cloudSync.sendPendingLocalChanges()

                householdSharePresentation = CloudSyncHouseholdSharePresentation(
                    householdId: household.id,
                    title: household.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? CloudSyncShareRuntime.fallbackTitle : household.name,
                    share: share,
                    container: shareService.cloudKitContainer
                )
                householdSyncStatusMessage = l.tr(
                    zh: "家庭分享已准备好，已排队 \(mergeSummary.stagedRecordCount) 条本机记录。",
                    en: "Family sharing is ready with \(mergeSummary.stagedRecordCount) local records queued.",
                    de: "Familienfreigabe ist bereit; \(mergeSummary.stagedRecordCount) lokale Einträge sind vorgemerkt."
                )
            } catch {
                householdSyncErrorMessage = error.localizedDescription
            }
        }
    }

    func bindCurrentCloudIdentity() {
        guard canUseOnlineCollaborationForSettings() else { return }
        guard !isBindingCloudIdentity,
              let human = activeHumanForCloudIdentity else { return }
        isBindingCloudIdentity = true
        householdSyncErrorMessage = nil
        householdSyncStatusMessage = nil

        Task { @MainActor in
            defer { isBindingCloudIdentity = false }
            guard await ensureCloudSyncAccountAvailable() else { return }
            do {
                let didBind = try await CloudSyncHumanIdentityBinder.bindCurrentCloudKitUser(
                    toHumanId: human.id,
                    context: modelContext
                )
                guard didBind else { return }
                try modelContext.save()
                householdSyncStatusMessage = l.tr(
                    zh: "本机 iCloud 身份已绑定到 \(human.name)。",
                    en: "This iCloud identity is linked to \(human.name).",
                    de: "Diese iCloud-Identität ist mit \(human.name) verknüpft."
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                householdSyncErrorMessage = error.localizedDescription
            }
        }
    }

    func retryCloudSyncNow() {
        guard canUseOnlineCollaborationForSettings() else { return }
        guard !isRetryingCloudSyncNow else { return }
        isRetryingCloudSyncNow = true
        householdSyncErrorMessage = nil
        householdSyncStatusMessage = nil

        Task { @MainActor in
            defer { isRetryingCloudSyncNow = false }
            guard await ensureCloudSyncAccountAvailable() else { return }
            await appServices.cloudSync.retryPendingSyncNow(modelContainer: modelContext.container)
            if appServices.cloudSync.hasPendingTransientRetry {
                householdSyncStatusMessage = l.tr(
                    zh: "已重新尝试同步；网络恢复后会继续自动重试。",
                    en: "Sync was retried and will keep retrying automatically when the network recovers.",
                    de: "Die Synchronisierung wurde erneut versucht und wird automatisch fortgesetzt."
                )
            } else {
                householdSyncStatusMessage = l.tr(
                    zh: "已重新尝试家庭同步。",
                    en: "Family sync was retried.",
                    de: "Familiensynchronisierung wurde erneut versucht."
                )
            }
        }
    }

    func handleHouseholdShareSaved(_ share: CKShare?) {
        guard canUseOnlineCollaborationForSettings() else { return }
        guard let share,
              let householdId = CloudSyncAcceptedShareStateUpdater.householdId(from: share.recordID.zoneID) else {
            return
        }
        do {
            _ = try CloudSyncHouseholdShareStateUpdater.markSharePrepared(
                householdId: householdId,
                share: share,
                context: modelContext
            )
            try modelContext.save()
        } catch {
            householdSyncErrorMessage = error.localizedDescription
        }
    }

    func handleHouseholdShareStopped(_ presentation: CloudSyncHouseholdSharePresentation) {
        guard canUseOnlineCollaborationForSettings() else { return }
        do {
            let summary = try CloudSyncHouseholdShareStopRuntime.stopSharingLocally(
                householdId: presentation.householdId,
                context: modelContext,
                cloudSync: appServices.cloudSync
            )
            try modelContext.save()
            householdSyncStatusMessage = l.tr(
                zh: "家庭分享已停止，已将 \(summary.stagedRecordCount) 条本机记录切回私人同步队列。",
                en: "Family sharing stopped and \(summary.stagedRecordCount) local records were queued for private sync.",
                de: "Die Familienfreigabe wurde beendet; \(summary.stagedRecordCount) lokale Einträge wurden für private Synchronisierung vorgemerkt."
            )
            Task { @MainActor in
                guard await ensureCloudSyncAccountAvailable() else { return }
                await appServices.cloudSync.startIfNeeded(modelContainer: modelContext.container)
                await appServices.cloudSync.registerDirtyLocalChanges()
                await appServices.cloudSync.sendPendingLocalChanges()
            }
        } catch {
            householdSyncErrorMessage = error.localizedDescription
        }
    }

    private func householdForSharing() throws -> Household {
        if let household = homeHouseholds?.first {
            return household
        }

        let household = Household()
        modelContext.insert(household)
        return household
    }

    private func canUseOnlineCollaborationForSettings() -> Bool {
        guard OnlineFeatureGate.allows(.onlineCollaboration) else {
            householdSharePresentation = nil
            OnlineFeatureGateNoticeCenter.post(.cloudShareInviteBlocked)
            return false
        }
        return true
    }
}

struct CloudSyncHouseholdSharingController: UIViewControllerRepresentable {
    let presentation: CloudSyncHouseholdSharePresentation
    let onSaved: (CKShare?) -> Void
    let onStoppedSharing: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(
            share: presentation.share,
            container: presentation.container
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: UICloudSharingController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            title: presentation.title,
            onSaved: onSaved,
            onStoppedSharing: onStoppedSharing,
            onError: onError
        )
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let title: String
        let onSaved: (CKShare?) -> Void
        let onStoppedSharing: () -> Void
        let onError: (Error) -> Void

        init(
            title: String,
            onSaved: @escaping (CKShare?) -> Void,
            onStoppedSharing: @escaping () -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.title = title
            self.onSaved = onSaved
            self.onStoppedSharing = onStoppedSharing
            self.onError = onError
        }

        func itemTitle(for _: UICloudSharingController) -> String? {
            title
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onSaved(csc.share)
        }

        func cloudSharingControllerDidStopSharing(_: UICloudSharingController) {
            onStoppedSharing()
        }

        func cloudSharingController(
            _: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            onError(error)
        }
    }
}
