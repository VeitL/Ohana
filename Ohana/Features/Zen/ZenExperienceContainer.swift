//
//  ZenExperienceContainer.swift
//  Ohana
//
//  Production adapter between the value-only Zen shell and existing domain
//  services. The shell never receives live SwiftData models.
//

import SwiftData
import SwiftUI

private nonisolated struct ZenAvatarLoadRequest: Sendable {
    let subject: PresenceSubjectRef
    let modelID: PersistentIdentifier
    let signature: String
}

@MainActor
struct ZenExperienceContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(AppExperienceController.self) private var experienceController
    @Environment(\.appPersistentBootstrapReady) private var persistentBootstrapReady
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Namespace private var profileTransitionNamespace

    @State private var snapshot = ZenPresenceSnapshot.empty
    @State private var oasisSnapshot = ZenOasisSnapshot.empty
    @State private var presentedRoute: ZenExperienceRoute?
    @State private var refreshTask: Task<Void, Never>?
    @State private var avatarLoadTask: Task<Void, Never>?
    @State private var didLoadStreak = false
    @State private var didLoadOasis = false
    @State private var errorMessage: String?

    let onRequestModeSwitch: () -> Void

    init(onRequestModeSwitch: @escaping () -> Void) {
        self.onRequestModeSwitch = onRequestModeSwitch
    }

    var body: some View {
        ZenShell(
            snapshot: $snapshot,
            oasisSnapshot: $oasisSnapshot,
            actions: actions,
            profileTransitionNamespace: profileTransitionNamespace
        )
        .task(id: "\(experienceController.zenOwnerHumanID):\(persistentBootstrapReady):\(appLanguage)") {
            await prepareExperience()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRefresh()
        }
        .onChange(of: appServices.commerce.personalAccessLevel) { _, _ in
            scheduleRefresh(delayMilliseconds: 0)
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
            avatarLoadTask?.cancel()
            avatarLoadTask = nil
        }
        .sheet(item: $presentedRoute) { route in
            transitionedRouteDestination(route)
                .ohanaSheetPagePresentation()
        }
        .alert(
            L10n.current.tr(
                zh: "暂时无法完成",
                en: "Unable to complete",
                de: "Aktion nicht möglich",
                es: "No se puede completar",
                pt: "Não foi possível concluir",
                fr: "Impossible de terminer",
                ja: "完了できません",
                ko: "완료할 수 없어요",
                it: "Impossibile completare"
            ),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(L10n.current.tr(
                zh: "知道了",
                en: "OK",
                de: "OK",
                es: "Aceptar",
                pt: "OK",
                fr: "OK",
                ja: "OK",
                ko: "확인",
                it: "OK"
            ), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var commandService: PresenceCheckInCommandService {
        PresenceCheckInCommandService(
            context: modelContext,
            wallet: appServices.coconutWallet,
            projectionManager: appServices.questManager
        )
    }

    private var actions: ZenShellActions {
        ZenShellActions(
            onAutoCheckInOwner: {
                await runAutoCheckInOwner()
            },
            onCheckIn: { subjectID, kind, status in
                guard let subject = presenceSubject(id: subjectID, kind: kind) else { return }
                await runPresenceCommand {
                    try commandService.checkIn(
                        subject: subject,
                        status: status.map(presenceStatus)
                    )
                }
            },
            onUpdateStatus: { subjectID, kind, status in
                guard let subject = presenceSubject(id: subjectID, kind: kind) else { return }
                await runPresenceCommand {
                    try commandService.updateTodayStatus(
                        subject: subject,
                        status: status.map(presenceStatus)
                    )
                }
            },
            onRecordRetrospectiveStatus: { subjectID, kind, dayKey, status in
                guard let subject = presenceSubject(id: subjectID, kind: kind) else { return }
                await runRetrospectiveStatusCommand {
                    try commandService.recordRetrospectiveStatus(
                        subject: subject,
                        dayKey: dayKey,
                        status: presenceStatus(status)
                    )
                }
            },
            onUndoCheckIn: { subjectID, kind in
                guard let subject = presenceSubject(id: subjectID, kind: kind) else { return }
                await runUndoPresenceCommand {
                    try commandService.undoTodayCheckIn(subject: subject)
                }
            },
            onCheckInAll: {
                await runPresenceCommand { try commandService.checkInAll() }
            },
            onLoadStreak: {
                didLoadStreak = true
                refresh(streak: true)
            },
            onLoadOasis: {
                didLoadOasis = true
                guard persistentBootstrapReady else { return }
                refreshOasis(balance: appServices.coconutWallet.totalBalance(context: modelContext))
            },
            onAdd: { kind in
                presentedRoute = .add(entityType(kind))
            },
            onOpenProfile: { subject in
                guard let id = UUID(uuidString: subject.id) else { return }
                presentedRoute = switch subject.kind {
                case .human: .human(id)
                case .pet: .pet(id)
                case .plant: .plant(id)
                }
            },
            onOpenMembers: {
                presentedRoute = .members
            },
            onOpenCoconutLog: {
                presentedRoute = .coconutLog
            },
            onOpenSettings: onRequestModeSwitch,
            onOpenPersonalAnalytics: {
                presentedRoute = appServices.commerce.allows(.presenceLongRangeAnalytics)
                    ? .analytics
                    : .personalPlan
            },
            onOpenShop: { category in
                guard lockedLevel(for: .coconutShop(.appIcon)) == nil else { return }
                presentedRoute = .shop(category)
            },
            onOpenAchievements: {
                guard lockedLevel(for: .achievements) == nil else { return }
                presentedRoute = .achievements
            },
            onOpenGacha: {
                guard lockedLevel(for: .gacha) == nil else { return }
                presentedRoute = .gacha
            },
            onOpenCritters: {
                guard lockedLevel(for: .critterCodex) == nil else { return }
                presentedRoute = .critters
            },
            onOpenGrowthRoadmap: {
                presentedRoute = .growthRoadmap
            },
            onInjectEnergy: {
                _ = appServices.oasisTree.injectEnergy(
                    cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
                    modelContext: modelContext
                )
                refresh(streak: didLoadStreak)
            },
            onClaimStarterGift: {
                let result = StarterGiftService.claimZenStarterGift(
                    context: modelContext,
                    careLedger: appServices.careLedger,
                    wallet: appServices.coconutWallet,
                    projectionManager: appServices.questManager
                )
                if case .claimed = result {
                    StarterGiftService.markCeremonySeen()
                } else if case .persistenceFailed = result {
                    errorMessage = L10n.current.tr(
                        zh: "起航礼没有保存，请稍后重试。",
                        en: "The welcome gift was not saved. Try again.",
                        de: "Das Willkommensgeschenk wurde nicht gespeichert.",
                        es: "El regalo de bienvenida no se guardó. Inténtalo de nuevo.",
                        pt: "O presente de boas-vindas não foi salvo. Tente novamente.",
                        fr: "Le cadeau de bienvenue n’a pas été enregistré. Réessayez.",
                        ja: "スタートギフトを保存できませんでした。もう一度お試しください。",
                        ko: "시작 선물이 저장되지 않았어요. 다시 시도하세요.",
                        it: "Il regalo di benvenuto non è stato salvato. Riprova."
                    )
                }
                refresh(streak: didLoadStreak)
            }
        )
    }

    private func prepareExperience() async {
        guard persistentBootstrapReady,
              UUID(uuidString: experienceController.zenOwnerHumanID) != nil else {
            snapshot = .empty
            oasisSnapshot = .empty
            return
        }
        refresh(streak: didLoadStreak)
    }

    private func runPresenceCommand(
        _ operation: () throws -> PresenceCheckInCommandResult
    ) async {
        do {
            let result = try operation()
            if let ownerCheckIn = result.checkIns.first(where: \.isOwner) {
                await SystemPresenceReminderScheduler().cancelToday(now: ownerCheckIn.checkedInAt)
            }
        } catch {
            present(error)
        }
        refresh(streak: didLoadStreak)
    }

    private func runUndoPresenceCommand(
        _ operation: () throws -> PresenceUndoCheckInResult
    ) async {
        do {
            _ = try operation()
        } catch {
            present(error)
        }
        refresh(streak: didLoadStreak)
    }

    private func runRetrospectiveStatusCommand(
        _ operation: () throws -> PresenceRetrospectiveStatusResult
    ) async {
        do {
            _ = try operation()
        } catch {
            present(error)
        }
        refresh(streak: didLoadStreak)
    }

    private func runAutoCheckInOwner() async -> Bool {
        do {
            let result = try commandService.autoCheckInOwner()
            if let ownerCheckIn = result.checkIns.first(where: \.isOwner) {
                await SystemPresenceReminderScheduler().cancelToday(now: ownerCheckIn.checkedInAt)
            }
            refresh(streak: didLoadStreak)
            return result.didCreateCheckIn
        } catch {
            present(error)
            refresh(streak: didLoadStreak)
            return false
        }
    }

    private func scheduleRefresh(delayMilliseconds: UInt64 = 100) {
        refreshTask?.cancel()
        refreshTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            refresh(streak: didLoadStreak)
            refreshTask = nil
        }
    }

    private func refresh(streak shouldLoadStreak: Bool) {
        guard persistentBootstrapReady,
              let ownerID = UUID(uuidString: experienceController.zenOwnerHumanID) else {
            snapshot = .empty
            oasisSnapshot = .empty
            return
        }
        do {
            let home = try PresenceCheckInReadService.homeSnapshot(
                context: modelContext,
                ownerHumanId: ownerID,
                localization: L10n(appLanguage)
            )
            let todayCheckIns = try todayCheckIns(dayKey: home.dayKey)
            let todayBySubject = Dictionary(
                todayCheckIns.compactMap { item in item.subject.map { ($0, item) } },
                uniquingKeysWith: { first, _ in first }
            )
            var currentStreak = shouldLoadStreak ? 0 : snapshot.currentStreak
            var longestStreak = shouldLoadStreak ? 0 : snapshot.longestStreak
            var days = shouldLoadStreak ? [] : snapshot.days
            var streakSubjects = shouldLoadStreak ? [] : snapshot.streakSubjects
            if shouldLoadStreak {
                let historicalSubjects = try PresenceCheckInReadService.streakSubjects(
                    context: modelContext,
                    ownerHumanId: ownerID
                )
                streakSubjects = historicalSubjects.enumerated().map { index, subject in
                    ZenPresenceSubjectDTO(
                        id: subject.subject.id.uuidString,
                        kind: zenKind(subject.subject.kind),
                        name: subject.isAnonymousHistory
                            ? anonymousHistoryName(for: subject.subject.kind)
                            : subject.name,
                        avatarAssetName: nil,
                        avatarEmoji: subject.avatarEmoji,
                        avatarThumbnailSignature: subject.avatarThumbnailSignature,
                        createdAt: subject.createdAt,
                        inactiveAt: subject.inactiveAt,
                        themeHex: subject.themeColorHex,
                        isOwner: subject.isOwner,
                        sortIndex: index,
                        isActive: subject.isActive,
                        isAnonymousHistory: subject.isAnonymousHistory
                    )
                }
                for subject in historicalSubjects {
                    let value = try PresenceCheckInReadService.streakSnapshot(
                        context: modelContext,
                        ownerHumanId: ownerID,
                        subject: subject.subject
                    )
                    if subject.isOwner {
                        currentStreak = value.currentStreak
                        longestStreak = value.longestStreak
                    }
                    days += value.days.map { day in
                        ZenPresenceDayDTO(
                            subjectID: subject.subject.id.uuidString,
                            dayKey: day.dayKey,
                            checkedIn: day.isCheckedIn,
                            status: day.status.map(zenStatus),
                            isRetrospectiveStatus: day.isRetrospectiveStatus,
                            participation: day.isParticipating ? .participating : .notParticipating
                        )
                    }
                }
            }

            let balance = appServices.coconutWallet.totalBalance(context: modelContext)
            snapshot = ZenPresenceSnapshot(
                isReady: true,
                subjects: home.subjects.enumerated().map { index, subject in
                    let today = todayBySubject[subject.subject]
                    return ZenPresenceSubjectDTO(
                        id: subject.subject.id.uuidString,
                        kind: zenKind(subject.subject.kind),
                        name: subject.name,
                        avatarAssetName: nil,
                        avatarEmoji: subject.avatarEmoji,
                        avatarThumbnailSignature: subject.avatarThumbnailSignature,
                        createdAt: subject.createdAt,
                        themeHex: subject.themeColorHex,
                        isOwner: subject.isOwner,
                        sortIndex: index,
                        isActive: true,
                        isAnonymousHistory: false,
                        expandedProfile: subject.expandedProfile,
                        currentDisplayStreak: subject.currentDisplayStreak,
                        checkedToday: subject.isCheckedInToday,
                        status: subject.status.map(zenStatus),
                        checkedAt: today?.checkedInAt
                    )
                },
                streakSubjects: streakSubjects,
                ownerID: ownerID.uuidString,
                dayKey: home.dayKey,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                days: days,
                coconutBalance: balance,
                personalAccessLevel: appServices.commerce.personalAccessLevel,
                avatarCacheRevision: snapshot.avatarCacheRevision
            )
            scheduleAvatarPreload(for: home.subjects)
            if didLoadOasis {
                refreshOasis(balance: balance)
            }
        } catch {
            present(error)
        }
    }

    private func scheduleAvatarPreload(for subjects: [PresenceSubjectSnapshot]) {
        let requests = subjects.compactMap { subject -> ZenAvatarLoadRequest? in
            guard let modelID = subject.avatarModelID,
                  !subject.avatarThumbnailSignature.isEmpty,
                  FocusWalletAvatarCache.cachedEntry(
                    for: subject.subject.id,
                    signature: subject.avatarThumbnailSignature
                  ) == nil else {
                return nil
            }
            return ZenAvatarLoadRequest(
                subject: subject.subject,
                modelID: modelID,
                signature: subject.avatarThumbnailSignature
            )
        }
        guard !requests.isEmpty else { return }

        avatarLoadTask?.cancel()
        let container = modelContext.container
        avatarLoadTask = Task { @MainActor in
            let loader = SwiftDataMediaBlobLoader(modelContainer: container)
            var payloads: [FocusWalletAvatarCache.Payload] = []
            for request in requests {
                guard !Task.isCancelled else { return }
                let data: Data? = switch request.subject.kind {
                case .human:
                    await loader.humanAvatarImageData(modelID: request.modelID)
                case .pet:
                    await loader.petAvatarImageData(modelID: request.modelID)
                case .plant:
                    await loader.plantAvatarImageData(modelID: request.modelID)
                }
                guard !Task.isCancelled else { return }
                if data.map({ FocusWalletAvatarCache.signature(for: $0) }) == request.signature {
                    payloads.append(.init(id: request.subject.id, data: data))
                }
            }
            guard !Task.isCancelled else { return }
            if await FocusWalletAvatarCache.preload(payloads: payloads) {
                snapshot.avatarCacheRevision &+= 1
            }
            avatarLoadTask = nil
        }
    }

    private func refreshOasis(balance: Int) {
        _ = appServices.oasisTree.refreshLedgerEnergy(modelContext: modelContext)
        let level = appServices.oasisTree.treeLevel.rawValue
        let gift = StarterGiftService.evaluateZenEligibility(
            context: modelContext,
            wallet: appServices.coconutWallet,
            projectionManager: appServices.questManager
        )
        let giftState: ZenStarterGiftState = switch gift {
        case .readyToClaim:
            .claimable
        case .claimed, .alreadyHandled:
            .claimed
        case .markedExistingUser, .pendingFirstPet, .persistenceFailed:
            .hidden
        }
        oasisSnapshot = ZenOasisSnapshot(
            isReady: true,
            level: level,
            progressToNextLevel: appServices.oasisTree.progressToNextLevel,
            totalEnergy: appServices.oasisTree.totalEnergy,
            nextLevelThreshold: appServices.oasisTree.nextLevelThreshold,
            coconutBalance: balance,
            canInjectEnergy: balance >= OasisTreeEnergyInjectionPolicy.starterPackageCost &&
                appServices.oasisTree.canUseInjectionPackage(cost: OasisTreeEnergyInjectionPolicy.starterPackageCost),
            shopLockedLevel: lockedLevel(for: .coconutShop(.appIcon), currentLevel: level),
            achievementsLockedLevel: lockedLevel(for: .achievements, currentLevel: level),
            gachaLockedLevel: lockedLevel(for: .gacha, currentLevel: level),
            crittersLockedLevel: lockedLevel(for: .critterCodex, currentLevel: level),
            starterGiftState: giftState
        )
    }

    private func todayCheckIns(dayKey: String) throws -> [PresenceCheckIn] {
        let retrospectiveSourceRaw = PresenceCheckInSource.retrospectiveStatus.rawValue
        return try modelContext.fetch(FetchDescriptor<PresenceCheckIn>(
            predicate: #Predicate {
                $0.dayKey == dayKey && $0.sourceRaw != retrospectiveSourceRaw
            },
            sortBy: [SortDescriptor(\.checkedInAt)]
        ))
    }

    private func lockedLevel(
        for route: OasisSheetRoute,
        currentLevel: Int? = nil
    ) -> Int? {
        let level = currentLevel ?? appServices.oasisTree.treeLevel.rawValue
        guard let required = AppFeatureRouteGuard.requiredLevel(for: route), level < required else {
            return nil
        }
        return required
    }

    @ViewBuilder
    private func transitionedRouteDestination(_ route: ZenExperienceRoute) -> some View {
        if let sourceID = route.profileTransitionSourceID,
           !reduceMotion,
           !workloadPolicy.shouldReduceWork() {
            routeDestination(route)
                .environment(\.memberProfileExperienceStyle, .zen)
                .navigationTransition(.zoom(sourceID: sourceID, in: profileTransitionNamespace))
        } else {
            routeDestination(route)
                .environment(\.memberProfileExperienceStyle, .zen)
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: ZenExperienceRoute) -> some View {
        switch route {
        case let .add(type):
            NavigationStack {
                AddEntityDestinationView(
                    type: type,
                    onComplete: closeRoute,
                    onPetSaved: { _ in closeAndRefreshRoute() },
                    onHumanSaved: { _ in closeAndRefreshRoute() },
                    onPlantSaved: { _ in closeAndRefreshRoute() }
                )
            }
        case let .human(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .basicInfo,
                onMissing: closeRoute,
                onDismiss: closeAndRefreshRoute
            )
        case let .pet(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .basicInfo,
                onMissing: closeRoute,
                onDismiss: closeAndRefreshRoute
            )
        case let .plant(id):
            AppPlantRouteContainer(
                id: id,
                destination: .basicInfo,
                onDismiss: closeRoute,
                onChanged: closeAndRefreshRoute
            )
        case let .shop(category):
            NavigationStack { CoconutShopRouteContainer(initialCategory: category) }
        case .achievements:
            FunctionMenuSheet(initialDestination: .featureAggregate(.achievements))
        case .gacha:
            GachaRouteContainer(
                drawsBackground: true,
                onClose: closeRoute,
                onPresentCoconutLog: nil
            )
        case .critters:
            NavigationStack {
                OasisCritterCodexRouteContainer(mode: .codex, onClose: closeRoute)
            }
        case .growthRoadmap:
            FunctionMenuSheet(initialDestination: .growthRoadmap)
        case .analytics:
            NavigationStack { ZenPersonalAnalyticsView(snapshot: snapshot) }
        case .personalPlan:
            PersonalPlanView(prompt: PersonalUpgradePrompt(feature: .presenceLongRangeAnalytics))
        case .members:
            ZenMembersRouteContainer(
                subjects: snapshot.subjects,
                avatarCacheRevision: snapshot.avatarCacheRevision,
                onRefresh: { scheduleRefresh(delayMilliseconds: 80) }
            )
        case .coconutLog:
            CoconutLogView(
                subject: nil,
                onClose: closeRoute,
                historyContentDelayMilliseconds: 80
            )
        }
    }

    private func closeRoute() {
        presentedRoute = nil
    }

    private func closeAndRefreshRoute() {
        presentedRoute = nil
        scheduleRefresh(delayMilliseconds: 80)
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        OhanaLog.warning("Zen experience command failed: \(error.localizedDescription)", category: "Presence")
    }

    private func presenceSubject(
        id rawID: String,
        kind: ZenPresenceSubjectKind
    ) -> PresenceSubjectRef? {
        guard let id = UUID(uuidString: rawID) else { return nil }
        return PresenceSubjectRef(kind: presenceKind(kind), id: id)
    }

    private func entityType(_ kind: ZenPresenceSubjectKind) -> EntityType {
        switch kind {
        case .human: .human
        case .pet: .pet
        case .plant: .plant
        }
    }

    private func zenKind(_ kind: PresenceSubjectKind) -> ZenPresenceSubjectKind {
        ZenPresenceSubjectKind(rawValue: kind.rawValue) ?? .human
    }

    private func presenceKind(_ kind: ZenPresenceSubjectKind) -> PresenceSubjectKind {
        PresenceSubjectKind(rawValue: kind.rawValue) ?? .human
    }

    private func zenStatus(_ status: PresenceStatus) -> ZenPresenceStatus {
        (ZenPresenceStatus(rawValue: status.rawValue) ?? ZenPresenceStatus(score: status.score))
            .currentPresentationStatus
    }

    private func presenceStatus(_ status: ZenPresenceStatus) -> PresenceStatus {
        PresenceStatus(rawValue: status.rawValue) ?? PresenceStatus(score: status.score)
    }

    private func anonymousHistoryName(for kind: PresenceSubjectKind) -> String {
        switch kind {
        case .human:
            L10n.current.tr(
                zh: "已删除的成员",
                en: "Deleted person",
                de: "Gelöschte Person",
                es: "Persona eliminada",
                pt: "Pessoa excluída",
                fr: "Personne supprimée",
                ja: "削除されたメンバー",
                ko: "삭제된 구성원",
                it: "Persona eliminata"
            )
        case .pet:
            L10n.current.tr(
                zh: "已删除的宠物",
                en: "Deleted pet",
                de: "Gelöschtes Tier",
                es: "Mascota eliminada",
                pt: "Pet excluído",
                fr: "Animal supprimé",
                ja: "削除されたペット",
                ko: "삭제된 반려동물",
                it: "Animale eliminato"
            )
        case .plant:
            L10n.current.tr(
                zh: "已删除的植物",
                en: "Deleted plant",
                de: "Gelöschte Pflanze",
                es: "Planta eliminada",
                pt: "Planta excluída",
                fr: "Plante supprimée",
                ja: "削除された植物",
                ko: "삭제된 식물",
                it: "Pianta eliminata"
            )
        }
    }
}

private enum ZenExperienceRoute: Identifiable, Equatable {
    case add(EntityType)
    case human(UUID)
    case pet(UUID)
    case plant(UUID)
    case shop(ShopItem.ShopCategory)
    case achievements
    case gacha
    case critters
    case growthRoadmap
    case analytics
    case personalPlan
    case members
    case coconutLog

    var id: String {
        switch self {
        case let .add(type): "add:\(type.rawValue)"
        case let .human(id): "human:\(id.uuidString)"
        case let .pet(id): "pet:\(id.uuidString)"
        case let .plant(id): "plant:\(id.uuidString)"
        case let .shop(category): "shop:\(category.rawValue)"
        case .achievements: "achievements"
        case .gacha: "gacha"
        case .critters: "critters"
        case .growthRoadmap: "growth-roadmap"
        case .analytics: "analytics"
        case .personalPlan: "personal-plan"
        case .members: "members"
        case .coconutLog: "coconut-log"
        }
    }

    var profileTransitionSourceID: String? {
        switch self {
        case let .human(id): "profile:human:\(id.uuidString)"
        case let .pet(id): "profile:pet:\(id.uuidString)"
        case let .plant(id): "profile:plant:\(id.uuidString)"
        case .add, .shop, .achievements, .gacha, .critters, .growthRoadmap,
             .analytics, .personalPlan, .members, .coconutLog:
            nil
        }
    }
}
