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

nonisolated struct OnboardingPetSnapshotHandoffState: Equatable {
    private(set) var requiredPetID: UUID?
    private(set) var completionRequestedPetID: UUID?
    private(set) var homeSnapshotReadyPetID: UUID?

    var completedPetID: UUID? {
        guard let requiredPetID,
              completionRequestedPetID == requiredPetID,
              homeSnapshotReadyPetID == requiredPetID else { return nil }
        return requiredPetID
    }

    mutating func stage(_ petID: UUID) {
        guard requiredPetID != petID else { return }
        requiredPetID = petID
        completionRequestedPetID = nil
        homeSnapshotReadyPetID = nil
    }

    mutating func requestCompletion(for petID: UUID) {
        stage(petID)
        completionRequestedPetID = petID
    }

    mutating func markHomeSnapshotReady(for petID: UUID) {
        guard requiredPetID == petID else { return }
        homeSnapshotReadyPetID = petID
    }

    mutating func resetAfterCompletion() {
        requiredPetID = nil
        completionRequestedPetID = nil
        homeSnapshotReadyPetID = nil
    }
}

struct RootView: View {
    var appLanguage: String = AppLanguage.code

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @AppStorage(AppPrivacySnapshotProtectionStore.hideSnapshotKey) private var hideAppSwitcherSnapshot = AppPrivacySnapshotProtectionStore.defaultHideSnapshot
    @State private var appSwitcherSnapshotCoverRequested = false
    @State private var onboardingFirstPetID: String?
    @State private var isOnboardingHomePreflightMounted = false
    @State private var onboardingPetSnapshotHandoff = OnboardingPetSnapshotHandoffState()
    @State private var onboardingHomeSnapshotRefreshGeneration = 0
    @State private var onboardingHomeSnapshotRecoveryTask: Task<Void, Never>?
    @State private var onboardingHomePreparationFailedPetID: UUID?
    @State private var onlineGateNoticeReason: OnlineFeatureGateNoticeReason?
    @StateObject private var startupMaintenance = StartupMaintenanceCoordinator()
    @StateObject private var sharedCareUndo = SharedCareUndoCoordinator.shared
    @State private var plantBatchCareRewardSettlementTask: Task<Void, Never>?
    @State private var plantBatchCareRewardRetryAfterFailure: Date?
    @State private var automaticBackupReminderTask: Task<Void, Never>?
    @State private var lastPersistenceFailureToastDate: Date?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    var body: some View {
        ZStack {
            if hasOnboarded || isOnboardingHomePreflightMounted {
                ContentView(
                    showsEmbeddedOnboarding: false,
                    onboardingFirstPetID: onboardingFirstPetID,
                    routeLanguageCode: appLanguage,
                    requiredPetHomeSnapshotRefreshRequest: onboardingHomeSnapshotRefreshGeneration,
                    onRequiredPetHomeSnapshotReady: markOnboardingPetHomeSnapshotReady
                )
                .allowsHitTesting(hasOnboarded)
                .accessibilityHidden(!hasOnboarded)
            }

            if !hasOnboarded {
                OnboardingView(
                    onFirstHumanSaved: { humanID in
                        currentActiveHumanId = humanID.uuidString
                        appServices.onboardingJourney.markFirstHumanCreated(humanID)
                    },
                    onPetDeferred: {
                        appServices.onboardingJourney.markPetDeferred()
                        showDeferredPetTaskToastAfterHomeHandoff()
                    },
                    onPetCreationStarted: {
                        appServices.onboardingJourney.markPetCreationStarted()
                    },
                    onCompletionRequested: requestOnboardingCompletion,
                    onFirstPetRecovered: { petID in
                        stageOnboardingPetHomeHandoff(petID)
                    },
                    onFirstPetSaved: { pet in
                        stageOnboardingPetHomeHandoff(pet.id)
                    },
                    onHomeJoinHandoffPreflight: beginOnboardingHomePreflight,
                    homePreparationRecoveryNeeded: onboardingHomePreparationFailedPetID != nil
                        && onboardingHomePreparationFailedPetID == onboardingPetSnapshotHandoff.requiredPetID,
                    onRetryHomePreparation: retryOnboardingHomePreparation
                )
                .zIndex(100)
            }

            if let snapshot = sharedCareUndo.banner {
                VStack {
                    Spacer()
                    SharedCareUndoBannerView(
                        snapshot: snapshot,
                        undo: sharedCareUndo.undoCurrent
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(900)
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
            sharedCareUndo.configure(context: modelContext, appServices: appServices)
            startupMaintenance.startAfterFirstRender(context: modelContext)
            schedulePlantBatchCareRewardSettlement()
            scheduleAutomaticBackupFailureReminder()
            resumeOnboardingHomeSnapshotRecoveryIfNeeded()
        }
        .onChange(of: hasOnboarded) { _, isComplete in
            guard isComplete else { return }
            cancelOnboardingHomeSnapshotRecovery()
            guard isOnboardingHomePreflightMounted else { return }
            var handoff = onboardingPetSnapshotHandoff
            handoff.resetAfterCompletion()
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onboardingPetSnapshotHandoff = handoff
                isOnboardingHomePreflightMounted = false
            }
        }
        .onDisappear {
            sharedCareUndo.pauseDeadlineTimer()
            startupMaintenance.cancel()
            plantBatchCareRewardSettlementTask?.cancel()
            plantBatchCareRewardSettlementTask = nil
            automaticBackupReminderTask?.cancel()
            automaticBackupReminderTask = nil
            cancelOnboardingHomeSnapshotRecovery()
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
            sharedCareUndo.pauseDeadlineTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            appSwitcherSnapshotCoverRequested = false
            sharedCareUndo.recover()
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
        guard !isOnboardingHomePreflightMounted else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isOnboardingHomePreflightMounted = true
        }
    }

    private func stageOnboardingPetHomeHandoff(_ petID: UUID) {
        if onboardingPetSnapshotHandoff.requiredPetID != petID {
            cancelOnboardingHomeSnapshotRecovery()
        }
        onboardingHomePreparationFailedPetID = nil
        var handoff = onboardingPetSnapshotHandoff
        handoff.stage(petID)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            onboardingPetSnapshotHandoff = handoff
            onboardingFirstPetID = petID.uuidString
            isOnboardingHomePreflightMounted = true
        }
        completeOnboardingPetHandoffIfReady()
    }

    private func requestOnboardingCompletion(_ petID: UUID) {
        var handoff = onboardingPetSnapshotHandoff
        handoff.requestCompletion(for: petID)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            onboardingPetSnapshotHandoff = handoff
            onboardingFirstPetID = petID.uuidString
            isOnboardingHomePreflightMounted = true
        }
        completeOnboardingPetHandoffIfReady()
        if !hasOnboarded {
            scheduleOnboardingHomeSnapshotRecovery(for: petID)
        }
    }

    private func markOnboardingPetHomeSnapshotReady(_ petID: UUID) {
        var handoff = onboardingPetSnapshotHandoff
        handoff.markHomeSnapshotReady(for: petID)
        guard handoff != onboardingPetSnapshotHandoff else { return }
        cancelOnboardingHomeSnapshotRecovery()
        onboardingPetSnapshotHandoff = handoff
        completeOnboardingPetHandoffIfReady()
    }

    private func completeOnboardingPetHandoffIfReady() {
        guard !hasOnboarded,
              onboardingPetSnapshotHandoff.completedPetID != nil else { return }
        cancelOnboardingHomeSnapshotRecovery()
        var completedHandoff = onboardingPetSnapshotHandoff
        completedHandoff.resetAfterCompletion()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            onboardingPetSnapshotHandoff = completedHandoff
            hasOnboarded = true
            isOnboardingHomePreflightMounted = false
        }
    }

    private func scheduleOnboardingHomeSnapshotRecovery(for petID: UUID) {
        cancelOnboardingHomeSnapshotRecovery()
        onboardingHomePreparationFailedPetID = nil
        onboardingHomeSnapshotRecoveryTask = OhanaFrameScheduler.runAfterNextFrame(
            milliseconds: OnboardingHomeJoinHandoffGate.homeSnapshotRecoveryInitialDelayMilliseconds
        ) {
            guard isOnboardingHomeSnapshotPending(for: petID) else {
                onboardingHomeSnapshotRecoveryTask = nil
                return
            }
            onboardingHomeSnapshotRefreshGeneration &+= 1
            onboardingHomeSnapshotRecoveryTask = OhanaFrameScheduler.runAfterNextFrame(
                milliseconds: OnboardingHomeJoinHandoffGate.homeSnapshotRecoveryRetryDelayMilliseconds
            ) {
                guard isOnboardingHomeSnapshotPending(for: petID) else {
                    onboardingHomeSnapshotRecoveryTask = nil
                    return
                }
                onboardingHomeSnapshotRefreshGeneration &+= 1
                onboardingHomeSnapshotRecoveryTask = OhanaFrameScheduler.runAfterNextFrame(
                    milliseconds: OnboardingHomeJoinHandoffGate.homeSnapshotRecoveryFailureDelayMilliseconds
                ) {
                    guard isOnboardingHomeSnapshotPending(for: petID) else {
                        onboardingHomeSnapshotRecoveryTask = nil
                        return
                    }
                    onboardingHomePreparationFailedPetID = petID
                    onboardingHomeSnapshotRecoveryTask = nil
                }
            }
        }
    }

    private func retryOnboardingHomePreparation() {
        guard let petID = onboardingPetSnapshotHandoff.requiredPetID,
              isOnboardingHomeSnapshotPending(for: petID) else { return }
        onboardingHomePreparationFailedPetID = nil
        onboardingHomeSnapshotRefreshGeneration &+= 1
        scheduleOnboardingHomeSnapshotRecovery(for: petID)
    }

    private func resumeOnboardingHomeSnapshotRecoveryIfNeeded() {
        guard let petID = onboardingPetSnapshotHandoff.requiredPetID,
              onboardingPetSnapshotHandoff.completionRequestedPetID == petID,
              isOnboardingHomeSnapshotPending(for: petID) else { return }
        scheduleOnboardingHomeSnapshotRecovery(for: petID)
    }

    private func isOnboardingHomeSnapshotPending(for petID: UUID) -> Bool {
        !hasOnboarded
            && onboardingPetSnapshotHandoff.requiredPetID == petID
            && onboardingPetSnapshotHandoff.completedPetID == nil
    }

    private func cancelOnboardingHomeSnapshotRecovery() {
        onboardingHomeSnapshotRecoveryTask?.cancel()
        onboardingHomeSnapshotRecoveryTask = nil
        onboardingHomePreparationFailedPetID = nil
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

    private func showDeferredPetTaskToastAfterHomeHandoff() {
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 360) {
            appServices.islandToasts.show(l.tr(
                zh: "已放入待办，随时可以继续建立宠物",
                en: "Added to To-dos. You can add your pet anytime.",
                de: "Zu Aufgaben hinzugefügt. Du kannst dein Tier jederzeit anlegen."
            ))
        }
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
    if let modelContainer = try? SharedModelContainer.makePreview() {
        RootView()
            .modelContainer(modelContainer)
    }
}
