//
//  RootView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Combine
import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    var appLanguage: String = AppLanguage.code

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @AppStorage(AppPrivacySnapshotProtectionStore.hideSnapshotKey) private var hideAppSwitcherSnapshot = AppPrivacySnapshotProtectionStore.defaultHideSnapshot
    // F3: 数据库降级警告
    @State private var showDBFallbackAlert = DatabaseFallbackPreferenceStore.isFallbackActive()
    @State private var appSwitcherSnapshotCoverRequested = false
    @State private var onboardingPrimaryHumanID: String?
    @State private var onlineGateNoticeReason: OnlineFeatureGateNoticeReason?
    @StateObject private var startupMaintenance = StartupMaintenanceCoordinator()
    @State private var plantBatchCareRewardSettlementTask: Task<Void, Never>?
    @State private var plantBatchCareRewardRetryAfterFailure: Date?
    @State private var automaticBackupReminderTask: Task<Void, Never>?
    @State private var lastPersistenceFailureToastDate: Date?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    var body: some View {
        ZStack {
            if hasOnboarded {
                ContentView(
                    showsEmbeddedOnboarding: false,
                    onboardingPrimaryHumanID: onboardingPrimaryHumanID,
                    routeLanguageCode: appLanguage
                )
            }

            if !hasOnboarded {
                OnboardingView(
                    onPrimaryHumanSaved: { human in
                        onboardingPrimaryHumanID = human.id.uuidString
                    },
                    onHomeJoinHandoffPreflight: beginOnboardingHomePreflight
                )
                .zIndex(100)
            }

            if shouldShowPrivacySnapshotCover {
                AppPrivacySnapshotCover()
                    .zIndex(1000)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .toggleStyle(OhanaPillToggleStyle())
        .islandToastOverlay()
        .onAppear {
            startupMaintenance.startAfterFirstRender(context: modelContext)
            schedulePlantBatchCareRewardSettlement()
            scheduleAutomaticBackupFailureReminder()
        }
        .onDisappear {
            startupMaintenance.cancel()
            plantBatchCareRewardSettlementTask?.cancel()
            plantBatchCareRewardSettlementTask = nil
            automaticBackupReminderTask?.cancel()
            automaticBackupReminderTask = nil
        }
        .onReceive(appServices.notificationRoutes.reminderActionEvents) { event in
            appServices.reminderActions.handle(
                userInfo: event.userInfo,
                currentActiveHumanId: currentActiveHumanId,
                context: modelContext,
                careEvents: appServices.careEvents,
                reminderCompletion: appServices.reminderCompletion,
                careLedger: appServices.careLedger,
                questManager: appServices.questManager,
                medicationReminders: appServices.medicationReminders,
                domainRevisions: appServices.domainRevisions
            )
        }
        .onReceive(PersistenceSaveFailureCenter.events.receive(on: RunLoop.main)) { event in
            showPersistenceSaveFailureToast(event)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            appSwitcherSnapshotCoverRequested = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            appSwitcherSnapshotCoverRequested = false
            schedulePlantBatchCareRewardSettlement()
            scheduleAutomaticBackupFailureReminder()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { revision in
            if PlantBatchCareRewardSettlementPolicy.shouldSchedule(for: revision) {
                schedulePlantBatchCareRewardSettlement()
            }
        }
        .onReceive(OnlineFeatureGateNoticeCenter.notices) { reason in
            onlineGateNoticeReason = reason
        }
        .alert(Text(l.tr(zh: "数据异常", en: "Data issue", de: "Datenproblem")), isPresented: $showDBFallbackAlert) {
            Button(l.tr(zh: "我知道了", en: "Got it", de: "Verstanden"), role: .cancel) {
                DatabaseFallbackPreferenceStore.clearFallbackActive()
            }
        } message: {
            Text(l.tr(
                zh: "数据库加载失败，当前为临时模式。本次会话的数据不会被保存。请尝试重启 App，如问题持续请联系开发者。",
                en: "The database could not be loaded, so Ohana is running in temporary mode. Data from this session will not be saved. Please restart the app, and contact the developer if the issue continues.",
                de: "Die Datenbank konnte nicht geladen werden. Ohana läuft vorübergehend im temporären Modus. Daten aus dieser Sitzung werden nicht gespeichert. Bitte starte die App neu und kontaktiere den Entwickler, falls das Problem weiterhin besteht."
            ))
        }
        .alert(Text(onlineGateNoticeTitle), isPresented: onlineGateNoticeBinding) {
            Button(l.tr(zh: "知道了", en: "Got it", de: "Verstanden"), role: .cancel) {
                onlineGateNoticeReason = nil
            }
        } message: {
            Text(onlineGateNoticeMessage)
        }
    }

    private var shouldShowPrivacySnapshotCover: Bool {
        guard hideAppSwitcherSnapshot else { return false }
        return appSwitcherSnapshotCoverRequested || AppPrivacySnapshotProtectionStore.shouldShowProtection(
            isEnabled: true,
            scenePhase: scenePhase
        )
    }

    private func beginOnboardingHomePreflight() {
        // Onboarding owns the visual handoff. Mounting the full Home stack before
        // the member save commits pulls navigation and read-model work into the
        // tap frame on real devices with retained data.
    }

    private func schedulePlantBatchCareRewardSettlement(now: Date = Date()) {
        plantBatchCareRewardSettlementTask?.cancel()
        let expiredTokens = PlantBatchCarePendingRewardStore.expiredTokens(now: now)
        guard let nextDate = PlantBatchCareRewardSettlementPolicy.nextRunDate(
            now: now,
            hasExpiredTokens: !expiredTokens.isEmpty,
            nextSettlementDate: PlantBatchCarePendingRewardStore.nextSettlementDate(now: now),
            retryAfterFailure: plantBatchCareRewardRetryAfterFailure
        ) else {
            plantBatchCareRewardSettlementTask = nil
            return
        }
        let delayNanoseconds = UInt64(max(0.1, nextDate.timeIntervalSince(now) + 0.1) * 1_000_000_000)
        plantBatchCareRewardSettlementTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            settleExpiredPlantBatchCareRewards()
        }
    }

    private func settleExpiredPlantBatchCareRewards(now: Date = Date()) {
        let tokens = PlantBatchCarePendingRewardStore.expiredTokens(now: now)
        guard !tokens.isEmpty else {
            plantBatchCareRewardRetryAfterFailure = nil
            schedulePlantBatchCareRewardSettlement(now: now)
            return
        }
        let executor = HomeCommandExecutor(modelContext: modelContext, services: appServices)
        var sawPersistenceFailure = false
        for token in tokens {
            let result = executor.commitPlantBatchCareRewards(for: token)
            guard PlantBatchCareRewardSettlementPolicy.shouldRemovePendingToken(after: result) else {
                sawPersistenceFailure = true
                continue
            }
            PlantBatchCarePendingRewardStore.remove(batchID: token.batchID)
        }
        plantBatchCareRewardRetryAfterFailure = sawPersistenceFailure
            ? PlantBatchCareRewardSettlementPolicy.retryAfterFailedCommit(now: now)
            : nil
        schedulePlantBatchCareRewardSettlement(now: now)
    }

    private func showPersistenceSaveFailureToast(_ event: ModelContextSaveFailureEvent, now: Date = Date()) {
        if let lastPersistenceFailureToastDate,
           now.timeIntervalSince(lastPersistenceFailureToastDate) < 1.5 {
            return
        }
        lastPersistenceFailureToastDate = now
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        appServices.islandToasts.show(l.tr(
            zh: "保存失败，请检查存储空间后重试",
            en: "Save failed. Check storage and try again.",
            de: "Speichern fehlgeschlagen. Prüfe den Speicher und versuche es erneut."
        ))
    }

    private func scheduleAutomaticBackupFailureReminder(now: Date = Date()) {
        automaticBackupReminderTask?.cancel()
        let status = appServices.automaticBackups.snapshot(now: now)
        guard status.shouldShowGentleReminder(now: now) else {
            automaticBackupReminderTask = nil
            return
        }
        automaticBackupReminderTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 720) {
            showAutomaticBackupFailureReminder(now: Date())
        }
    }

    private func showAutomaticBackupFailureReminder(now: Date = Date()) {
        let status = appServices.automaticBackups.snapshot(now: now)
        guard status.shouldShowGentleReminder(now: now) else { return }
        appServices.islandToasts.show(l.tr(
            zh: "自动备份连续失败，请在设置里检查 iCloud Drive",
            en: "Automatic backup keeps failing. Check iCloud Drive in Settings.",
            de: "Automatisches Backup schlägt weiter fehl. Prüfe iCloud Drive in den Einstellungen."
        ))
        appServices.automaticBackups.markReminderShown(now: now)
    }

    private var l: L10n {
        L10n(AppLanguage.code)
    }

    private var onlineGateNoticeBinding: Binding<Bool> {
        Binding(
            get: { onlineGateNoticeReason != nil },
            set: { isPresented in
                if !isPresented {
                    onlineGateNoticeReason = nil
                }
            }
        )
    }

    private var onlineGateNoticeTitle: String {
        onlineGateNoticeReason?.title(l) ?? ""
    }

    private var onlineGateNoticeMessage: String {
        onlineGateNoticeReason?.message(l) ?? ""
    }
}

#Preview {
    RootView()
        .modelContainer(SharedModelContainer.make())
}
