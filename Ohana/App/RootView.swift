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

private enum SupporterIconAccessNotice: Equatable {
    case requiresDefault
    case applyFailed(String)
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
    @State private var supporterIconAccessNotice: SupporterIconAccessNotice?
    @StateObject private var startupMaintenance = StartupMaintenanceCoordinator()
    @StateObject private var sharedCareUndo = SharedCareUndoCoordinator.shared
    @State private var plantBatchCareRewardSettlementTask: Task<Void, Never>?
    @State private var plantBatchCareRewardRetryAfterFailure: Date?
    @State private var automaticBackupReminderTask: Task<Void, Never>?
    @State private var lastPersistenceFailureToastDate: Date?
    @State private var showingZenSettings = false
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    var body: some View {
        AppRuntimeHost { experienceController in
            rootContent(experienceController)
        }
    }

    private func rootContent(_ experienceController: AppExperienceController) -> some View {
        rootStack(experienceController)
            .buttonStyle(ScaleButtonStyle())
            .toggleStyle(OhanaPillToggleStyle())
            .environment(\.hasSupporterPackEntitlement, appServices.commerce.allows(.supporterAppearance))
            .islandToastOverlay()
            .onAppear {
                sharedCareUndo.configure(context: modelContext, appServices: appServices)
                startupMaintenance.startAfterFirstRender(context: modelContext, services: appServices)
                schedulePlantBatchCareRewardSettlement()
                scheduleAutomaticBackupFailureReminder()
                resumeOnboardingHomeSnapshotRecoveryIfNeeded()
                evaluateSupporterIconAccessAfterVerification()
            }
            .onChange(of: appServices.commerce.entitlementStatus) { _, status in
                if status == .notOwnedVerified {
                    evaluateSupporterIconAccessAfterVerification()
                } else if status == .ownedVerified,
                          case .requiresDefault? = supporterIconAccessNotice {
                    supporterIconAccessNotice = nil
                }
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
            .onChange(of: experienceController.mode) { previousMode, currentMode in
                handleExperienceModeChange(from: previousMode, to: currentMode)
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
                appServices.notificationRoutes.acknowledgeReminderActionEvent(id: event.id)
                if handlePresenceReminderAction(event, experienceController: experienceController) {
                    return
                }
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
            .alert(Text(supporterIconAccessNoticeTitle), isPresented: supporterIconAccessNoticeBinding) {
                supporterIconAccessNoticeButtons
            } message: {
                Text(supporterIconAccessNoticeMessage)
            }
            .sheet(isPresented: $showingZenSettings) {
                AppSettingsSheetRouteContainer {
                    showingZenSettings = false
                }
                .ohanaSheetPagePresentation()
            }
    }

    private func rootStack(_ experienceController: AppExperienceController) -> some View {
        ZStack {
            if !experienceController.requiresInitialSelection,
               hasOnboarded || (experienceController.mode == .standard && isOnboardingHomePreflightMounted) {
                experienceShell(experienceController)
                    .id(experienceController.shellIdentity)
            }

            if !experienceController.requiresInitialSelection, !hasOnboarded {
                OnboardingView(
                    experienceMode: experienceController.mode,
                    onFirstHumanSaved: { humanID in
                        currentActiveHumanId = humanID.uuidString
                        if experienceController.mode == .zen {
                            experienceController.bindZenOwner(humanID)
                        } else {
                            appServices.onboardingJourney.markFirstHumanCreated(humanID)
                        }
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

            if experienceController.requiresInitialSelection {
                AppExperienceSelectionView(appLanguage: appLanguage) { mode in
                    experienceController.selectInitialMode(mode)
                }
                .zIndex(110)
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

            if hasOnboarded,
               experienceController.mode == .standard,
               experienceController.shouldOfferZenIntroduction {
                VStack {
                    AppExperienceIntroductionBanner(appLanguage: appLanguage) {
                        experienceController.dismissZenIntroduction()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer(minLength: 0)
                }
                .zIndex(850)
            }

            if shouldShowPrivacySnapshotCover {
                AppPrivacySnapshotCover()
                    .zIndex(1000)
            }
        }
    }

    @ViewBuilder
    private var supporterIconAccessNoticeButtons: some View {
        if case .requiresDefault? = supporterIconAccessNotice {
            Button(l.tr(
                zh: "恢复默认图标",
                en: "Use default icon",
                de: "Standardsymbol verwenden"
            )) {
                applyDefaultIconAfterSupporterRevocation()
            }
        } else {
            Button(l.tr(zh: "知道了", en: "Got it", de: "Verstanden"), role: .cancel) {
                supporterIconAccessNotice = nil
            }
        }
    }

    @ViewBuilder
    private func experienceShell(_ experienceController: AppExperienceController) -> some View {
        switch experienceController.mode {
        case .standard:
            ContentView(
                showsEmbeddedOnboarding: false,
                onboardingFirstPetID: onboardingFirstPetID,
                routeLanguageCode: appLanguage,
                requiredPetHomeSnapshotRefreshRequest: onboardingHomeSnapshotRefreshGeneration,
                onRequiredPetHomeSnapshotReady: markOnboardingPetHomeSnapshotReady
            )
            .allowsHitTesting(hasOnboarded)
            .accessibilityHidden(!hasOnboarded)
        case .zen:
            zenExperienceShell(experienceController)
        }
    }

    @ViewBuilder
    private func zenExperienceShell(_ experienceController: AppExperienceController) -> some View {
        switch experienceController.zenOwnerBindingState {
        case .unresolved:
            ZenOwnerResolutionView(appLanguage: appLanguage)
        case .ready:
            ZenExperienceContainer {
                showingZenSettings = true
            }
        case let .requiresSelection(humans):
            ZenOwnerSelectionView(
                appLanguage: appLanguage,
                humans: humans,
                onSelect: experienceController.bindZenOwner
            )
        case .unavailable:
            ZenOwnerUnavailableView(appLanguage: appLanguage) {
                showingZenSettings = true
            }
        }
    }

    private func handleExperienceModeChange(
        from previousMode: AppExperienceMode,
        to currentMode: AppExperienceMode
    ) {
        guard previousMode != currentMode else { return }
        showingZenSettings = false
        cancelOnboardingHomeSnapshotRecovery()
        onboardingFirstPetID = nil
        isOnboardingHomePreflightMounted = false
    }

    @discardableResult
    private func handlePresenceReminderAction(
        _ event: ReminderNotificationActionEvent,
        experienceController: AppExperienceController
    ) -> Bool {
        guard event.userInfo["presenceAction"] as? String == "checkInOwner",
              event.userInfo["action"] as? String == PresenceReminderRequestFactory.okayActionIdentifier
        else { return false }

        guard experienceController.mode == .zen,
              UUID(uuidString: experienceController.zenOwnerHumanID) != nil else {
            return true
        }

        do {
            let service = PresenceCheckInCommandService(
                context: modelContext,
                wallet: appServices.coconutWallet,
                projectionManager: appServices.questManager
            )
            let result = try service.checkInOwner(source: .notificationAction)
            if let ownerCheckIn = result.checkIns.first(where: \.isOwner) {
                Task { @MainActor in
                    await SystemPresenceReminderScheduler().cancelToday(now: ownerCheckIn.checkedInAt)
                }
            }
        } catch {
            OhanaLog.warning(
                "Presence notification action could not check in the owner: \(error.localizedDescription)",
                category: "Notifications"
            )
        }
        return true
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

    private var supporterIconAccessNoticeBinding: Binding<Bool> {
        Binding(
            get: { supporterIconAccessNotice != nil },
            set: { isPresented in
                if !isPresented {
                    supporterIconAccessNotice = nil
                }
            }
        )
    }

    private var supporterIconAccessNoticeTitle: String {
        switch supporterIconAccessNotice {
        case .requiresDefault:
            l.tr(
                zh: "Personal 图标权益已变化",
                en: "Personal icon access changed",
                de: "Zugriff auf Personal-Symbol geändert"
            )
        case .applyFailed:
            l.tr(
                zh: "无法恢复默认图标",
                en: "Could not restore the default icon",
                de: "Standardsymbol konnte nicht wiederhergestellt werden"
            )
        case nil:
            ""
        }
    }

    private var supporterIconAccessNoticeMessage: String {
        switch supporterIconAccessNotice {
        case .requiresDefault:
            l.tr(
                zh: "App Store 已确认 Ohana Personal 权益不再有效，且霓虹笑脸没有椰子购买记录。你的照护数据不会受到影响；请在方便时恢复默认图标。",
                en: "The App Store no longer reports an active Ohana Personal entitlement, and Neon Smile was not earned with coconuts. Your care data is unaffected; switch to the default icon when convenient.",
                de: "Der App Store meldet keinen aktiven Ohana-Personal-Anspruch mehr, und Neon Smile wurde nicht mit Kokosnüssen verdient. Deine Pflegedaten bleiben unverändert; wechsle bei Gelegenheit zum Standardsymbol."
            )
        case let .applyFailed(message):
            message
        case nil:
            ""
        }
    }

    private func evaluateSupporterIconAccessAfterVerification() {
        guard appServices.commerce.entitlementStatus == .notOwnedVerified,
              appServices.appIcons.currentDescriptor.itemId == SupporterPackCatalog.supporterIconItemID
        else { return }

        do {
            let hasSwiftDataOwnership = try ShopPurchaseRecordStore.isOwned(
                itemID: SupporterPackCatalog.supporterIconItemID,
                context: modelContext
            )
            let legacyIDs = Set(ShopPurchaseRecordStore.legacyPurchasedItemIDs(
                raw: UserDefaults.standard.string(
                    forKey: SupporterPackCatalog.supporterIconLegacyOwnershipKey
                ) ?? ""
            ))
            let hasCoconutOwnership = hasSwiftDataOwnership ||
                legacyIDs.contains(SupporterPackCatalog.supporterIconItemID)
            guard SupporterPackAccessPolicy.shouldOfferDefaultIconAfterEntitlementRefresh(
                status: appServices.commerce.entitlementStatus,
                currentIconItemID: appServices.appIcons.currentDescriptor.itemId,
                hasCoconutOwnership: hasCoconutOwnership
            )
            else { return }
            supporterIconAccessNotice = .requiresDefault
        } catch {
            // A failed local ownership read is inconclusive. Preserve the icon
            // and try again at the next verified entitlement refresh.
        }
    }

    private func applyDefaultIconAfterSupporterRevocation() {
        guard let descriptor = AppIconCatalog.descriptor(forItemId: AppIconCatalog.defaultItemId)
        else { return }
        supporterIconAccessNotice = nil
        appServices.appIcons.setIcon(descriptor) { result in
            if case let .failure(error) = result {
                supporterIconAccessNotice = .applyFailed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    if let modelContainer = try? SharedModelContainer.makePreview() {
        RootView()
            .modelContainer(modelContainer)
    }
}
