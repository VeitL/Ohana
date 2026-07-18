//
//  AppRuntimeHost.swift
//  Ohana
//
//  Process-long runtime work shared by every app experience shell.
//

import SwiftData
import SwiftUI
import UserNotifications

private struct AppPersistentBootstrapReadyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appPersistentBootstrapReady: Bool {
        get { self[AppPersistentBootstrapReadyKey.self] }
        set { self[AppPersistentBootstrapReadyKey.self] = newValue }
    }
}

@MainActor
struct AppRuntimeHost<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppServices.self) private var appServices
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanID = ""

    @State private var experienceController: AppExperienceController
    @State private var runtimeStartTask: Task<Void, Never>?
    @State private var walletBootstrapTask: Task<Void, Never>?
    @State private var achievementReconciliationTask: Task<Void, Never>?
    @State private var ownerReconciliationTask: Task<Void, Never>?
    @State private var presenceReminderTask: Task<Void, Never>?
    @State private var hasStartedRuntime = false
    @State private var hasCompletedPersistentBootstrap = false
    @State private var persistentBootstrapAttempt = 0
    @State private var activeZenParticipationOwnerID: UUID?
    @State private var pendingZenParticipationSource: PresenceParticipationSource?

    private let content: (AppExperienceController) -> Content

    init(
        experienceController: AppExperienceController? = nil,
        @ViewBuilder content: @escaping (AppExperienceController) -> Content
    ) {
        _experienceController = State(initialValue: experienceController ?? AppExperienceController())
        self.content = content
    }

    var body: some View {
        content(experienceController)
            .environment(experienceController)
            .environment(\.appPersistentBootstrapReady, hasCompletedPersistentBootstrap)
            .onAppear {
                scheduleRuntimeStartIfNeeded()
                if hasStartedRuntime {
                    scheduleWalletBootstrap()
                }
                scheduleOwnerReconciliation()
            }
            .onDisappear {
                runtimeStartTask?.cancel()
                runtimeStartTask = nil
                walletBootstrapTask?.cancel()
                walletBootstrapTask = nil
                achievementReconciliationTask?.cancel()
                achievementReconciliationTask = nil
                ownerReconciliationTask?.cancel()
                ownerReconciliationTask = nil
                presenceReminderTask?.cancel()
                presenceReminderTask = nil
            }
            .onChange(of: hasOnboarded) { wasComplete, isComplete in
                if isComplete {
                    if experienceController.mode == .zen {
                        pendingZenParticipationSource = .onboarding
                    }
                    scheduleRuntimeStartIfNeeded()
                    scheduleOwnerReconciliation()
                } else if wasComplete {
                    runtimeStartTask?.cancel()
                    runtimeStartTask = nil
                    walletBootstrapTask?.cancel()
                    walletBootstrapTask = nil
                    achievementReconciliationTask?.cancel()
                    achievementReconciliationTask = nil
                    hasStartedRuntime = false
                    hasCompletedPersistentBootstrap = false
                    persistentBootstrapAttempt = 0
                    experienceController.prepareForFreshOnboardingAfterReset()
                }
            }
            .onChange(of: experienceController.mode) { previousMode, currentMode in
                if previousMode == .zen, currentMode != .zen {
                    endZenParticipation()
                }
                if currentMode == .zen {
                    pendingZenParticipationSource = .settings
                }
                scheduleOwnerReconciliation()
            }
            .onChange(of: experienceController.zenOwnerHumanID) { oldValue, newValue in
                guard experienceController.mode == .zen else { return }
                if !newValue.isEmpty {
                    currentActiveHumanID = newValue
                    if let ownerID = UUID(uuidString: newValue) {
                        startZenParticipationIfNeeded(ownerID: ownerID)
                    }
                } else {
                    if currentActiveHumanID == oldValue {
                        currentActiveHumanID = ""
                    }
                    endZenParticipation()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                appServices.lifecycle.handle(.scenePhaseChanged(phase))
                guard phase == .active else { return }
                if experienceController.mode == .zen {
                    reconcileActiveHumanSelection()
                }
                if hasStartedRuntime {
                    scheduleWalletBootstrap()
                }
                if hasCompletedPersistentBootstrap {
                    scheduleAchievementReconciliation(reason: .foreground)
                }
                scheduleOwnerReconciliation()
            }
            .onReceive(appServices.domainRevisions.domainMutationEvents) { mutation in
                if hasOnboarded, hasCompletedPersistentBootstrap {
                    scheduleAchievementReconciliation(
                        reason: .domainRevision,
                        affectedScopes: achievementScopes(for: mutation),
                        delayMilliseconds: 260
                    )
                }
            }
            .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
                guard experienceController.mode == .zen, hasOnboarded else { return }
                scheduleOwnerReconciliation(delayMilliseconds: 140)
            }
    }

    private func scheduleRuntimeStartIfNeeded() {
        guard hasOnboarded, !hasStartedRuntime, runtimeStartTask == nil else { return }
        let delay = OnboardingHomeJoinHandoffGate.remainingRootBootstrapDelayMilliseconds()
        runtimeStartTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delay) {
            guard hasOnboarded, !hasStartedRuntime else {
                runtimeStartTask = nil
                return
            }
            hasStartedRuntime = true
            appServices.lifecycle.handle(.rootAppeared(scenePhase: scenePhase))
            appServices.cloudSync.startAfterFirstRender(modelContainer: modelContext.container)
            reconcileActiveHumanSelection()
            scheduleOwnerReconciliation()
            scheduleWalletBootstrap()
            runtimeStartTask = nil
        }
    }

    private func scheduleWalletBootstrap(delayMilliseconds: UInt64 = 180) {
        guard !hasCompletedPersistentBootstrap, walletBootstrapTask == nil else { return }
        walletBootstrapTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            persistentBootstrapAttempt += 1
            let attempt = persistentBootstrapAttempt
            do {
                try appServices.coconutWallet.bootstrapIfNeeded(
                    context: modelContext,
                    projectionManager: appServices.questManager
                )
                EconomyDailyBudgetStore.pruneOldUsageEvents(context: modelContext)
                _ = try AchievementLegacyMigrationService.migrateIfNeeded(context: modelContext)
                _ = try AchievementProgressionEngine.reconcile(
                    AchievementProgressionRequest(reason: .launch),
                    context: modelContext
                )
                _ = try PresenceLegacyMigrationService.migrateIfNeeded(context: modelContext)
                hasCompletedPersistentBootstrap = true
                persistentBootstrapAttempt = 0
                walletBootstrapTask = nil
            } catch {
                walletBootstrapTask = nil
                OhanaLog.error(
                    "AppRuntimeHost persistent bootstrap attempt \(attempt) failed: \(error.localizedDescription)",
                    category: "Startup"
                )
                if attempt < 3, hasOnboarded {
                    scheduleWalletBootstrap(delayMilliseconds: UInt64(attempt) * 400)
                }
            }
        }
    }

    private func scheduleAchievementReconciliation(
        reason: AchievementReconcileReason,
        affectedScopes: [AchievementScopeReference] = [],
        delayMilliseconds: UInt64 = 120
    ) {
        achievementReconciliationTask?.cancel()
        guard hasOnboarded, hasCompletedPersistentBootstrap else {
            achievementReconciliationTask = nil
            return
        }
        let container = modelContext.container
        achievementReconciliationTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else { return }
            do {
                let actor = AchievementProgressionActor(modelContainer: container)
                _ = try await actor.reconcile(
                    AchievementProgressionRequest(
                        affectedScopes: affectedScopes,
                        reason: reason
                    )
                )
            } catch {
                OhanaLog.warning(
                    "Achievement reconciliation failed after \(reason.rawValue): \(error.localizedDescription)",
                    category: "Achievements"
                )
            }
            achievementReconciliationTask = nil
        }
    }

    private func achievementScopes(for mutation: DomainMutationResult) -> [AchievementScopeReference] {
        var scopes: Set<AchievementScopeReference> = [.island]
        if let activeHumanID = UUID(uuidString: currentActiveHumanID) {
            scopes.insert(.human(activeHumanID))
        }
        for entityID in mutation.affectedEntityIDs.prefix(64) {
            var petDescriptor = FetchDescriptor<Pet>(
                predicate: #Predicate<Pet> { $0.id == entityID && $0.passedAwayDate == nil }
            )
            petDescriptor.fetchLimit = 1
            if (try? modelContext.fetch(petDescriptor).first) != nil {
                scopes.insert(.pet(entityID))
            }
            var humanDescriptor = FetchDescriptor<Human>(
                predicate: #Predicate<Human> { $0.id == entityID && $0.passedAwayDate == nil }
            )
            humanDescriptor.fetchLimit = 1
            if (try? modelContext.fetch(humanDescriptor).first) != nil {
                scopes.insert(.human(entityID))
            }
        }
        return scopes.sorted {
            if $0.kind.rawValue != $1.kind.rawValue {
                return $0.kind.rawValue < $1.kind.rawValue
            }
            return $0.id < $1.id
        }
    }

    private func reconcileActiveHumanSelection() {
        guard hasOnboarded else { return }
        let resolution = appServices.humanRequirements.resolve(
            hasOnboarded: true,
            currentActiveHumanId: currentActiveHumanID,
            isAccountSwitchPresented: false,
            context: modelContext
        )
        if case let .activateHuman(humanID) = resolution {
            currentActiveHumanID = humanID
        }
    }

    private func scheduleOwnerReconciliation(delayMilliseconds: UInt64 = 0) {
        ownerReconciliationTask?.cancel()
        guard hasOnboarded, experienceController.mode == .zen else {
            ownerReconciliationTask = nil
            experienceController.reconcileZenOwner(with: [])
            return
        }
        ownerReconciliationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            reconcileZenOwner()
            ownerReconciliationTask = nil
        }
    }

    private func reconcileZenOwner() {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.passedAwayDate == nil
            },
            sortBy: [SortDescriptor(\Human.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 201
        do {
            let choices = try modelContext.fetch(descriptor).map {
                AppExperienceHumanChoice(
                    id: $0.id,
                    name: $0.name,
                    avatarEmoji: $0.avatarEmoji,
                    createdAt: $0.createdAt
                )
            }
            experienceController.reconcileZenOwner(with: choices)
            switch experienceController.zenOwnerBindingState {
            case let .ready(ownerID):
                currentActiveHumanID = ownerID.uuidString
                startZenParticipationIfNeeded(ownerID: ownerID)
            case .requiresSelection, .unavailable:
                endZenParticipation()
            case .unresolved:
                break
            }
        } catch {
            OhanaLog.warning(
                "AppRuntimeHost failed to reconcile the Zen owner: \(error.localizedDescription)",
                category: "Startup"
            )
        }
    }

    private func startZenParticipationIfNeeded(ownerID: UUID) {
        guard hasOnboarded,
              experienceController.mode == .zen,
              activeZenParticipationOwnerID != ownerID else { return }
        do {
            let service = makePresenceCommandService()
            try service.startParticipation(
                ownerHumanId: ownerID,
                source: pendingZenParticipationSource ?? .settings
            )
            activeZenParticipationOwnerID = ownerID
            pendingZenParticipationSource = nil
            resumePresenceRemindersIfAuthorized()
        } catch {
            activeZenParticipationOwnerID = nil
            OhanaLog.warning(
                "AppRuntimeHost could not start Zen participation: \(error.localizedDescription)",
                category: "Startup"
            )
        }
    }

    private func endZenParticipation() {
        cancelPresenceReminders()
        guard hasOnboarded else {
            activeZenParticipationOwnerID = nil
            return
        }
        do {
            try makePresenceCommandService().endParticipation()
        } catch {
            OhanaLog.warning(
                "AppRuntimeHost could not end Zen participation: \(error.localizedDescription)",
                category: "Startup"
            )
        }
        activeZenParticipationOwnerID = nil
        pendingZenParticipationSource = nil
    }

    /// Re-entering Zen restores an already-authorized local schedule without
    /// presenting a permission prompt. Permission is requested only from the
    /// explicit Save/Enable action in Presence Safety settings.
    private func resumePresenceRemindersIfAuthorized() {
        presenceReminderTask?.cancel()
        presenceReminderTask = Task { @MainActor in
            defer { presenceReminderTask = nil }
            let configuration = PresenceReminderConfigurationStore().load()
            guard configuration.isEnabled else { return }
            switch await appServices.userNotifications.authorizationStatus() {
            case .authorized, .provisional, .ephemeral:
                let l = L10n.current
                let requests = PresenceReminderRequestFactory.makeRequests(
                    configuration: configuration,
                    title: l.tr(
                        zh: "佛系打卡提醒",
                        en: "Zen check-in reminder",
                        de: "Zen-Check-in-Erinnerung",
                        es: "Recordatorio de check-in zen",
                        pt: "Lembrete de check-in zen",
                        fr: "Rappel de check-in Zen",
                        ja: "佛系チェックインのリマインダー",
                        ko: "마음 편한 체크인 알림",
                        it: "Promemoria check-in Zen"
                    ),
                    body: l.tr(
                        zh: "今天还没有收到你的打卡。",
                        en: "We haven't received your check-in today.",
                        de: "Dein Check-in für heute fehlt noch.",
                        es: "Aún no hemos recibido tu check-in de hoy.",
                        pt: "Ainda não recebemos seu check-in de hoje.",
                        fr: "Nous n’avons pas encore reçu votre check-in aujourd’hui.",
                        ja: "今日のチェックインがまだ届いていません。",
                        ko: "오늘 체크인을 아직 받지 못했어요.",
                        it: "Non abbiamo ancora ricevuto il tuo check-in di oggi."
                    )
                )
                let scheduler = SystemPresenceReminderScheduler()
                do {
                    try await scheduler.replaceRequests(requests)
                    let now = Date()
                    if let ownerID = activeZenParticipationOwnerID,
                       ownerIsCheckedInToday(ownerID: ownerID, now: now) {
                        await scheduler.cancelToday(now: now)
                    }
                } catch {
                    OhanaLog.warning(
                        "AppRuntimeHost could not restore Zen reminders: \(error.localizedDescription)",
                        category: "Notifications"
                    )
                }
            case .notDetermined, .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func cancelPresenceReminders() {
        presenceReminderTask?.cancel()
        presenceReminderTask = Task { @MainActor in
            await SystemPresenceReminderScheduler().cancelAll()
            presenceReminderTask = nil
        }
    }

    private func ownerIsCheckedInToday(ownerID: UUID, now: Date) -> Bool {
        do {
            let snapshot = try PresenceCheckInReadService.homeSnapshot(
                context: modelContext,
                ownerHumanId: ownerID,
                now: now
            )
            return snapshot.subjects.first(where: \.isOwner)?.isCheckedInToday == true
        } catch {
            OhanaLog.warning(
                "AppRuntimeHost could not read today's Zen check-in: \(error.localizedDescription)",
                category: "Notifications"
            )
            return false
        }
    }

    private func makePresenceCommandService() -> PresenceCheckInCommandService {
        PresenceCheckInCommandService(
            context: modelContext,
            wallet: appServices.coconutWallet,
            projectionManager: appServices.questManager
        )
    }
}
